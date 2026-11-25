# AWS Three-tier Web Application với Terraform

Triển khai React + Nginx, Node.js và Aurora MySQL trên AWS. Terraform upload source lên S3; EC2 tự cài dependency và **build React trên EC2**, không cần build local.

## 1. Kiến trúc

```text
Internet → External ALB:80 → Web EC2 / Nginx:80
                                   ↓ /api/
                            Internal ALB:80
                                   ↓
                             App EC2:4000
                                   ↓
                            Aurora MySQL:3306
```

- VPC có 2 AZ: 2 public subnet cho Web/External ALB, 2 private subnet cho App/Internal ALB, 2 private subnet cho DB.
- Mỗi tier Web/App có ASG: Min 2, Desired ban đầu 2, Max 4; target tracking CPU trung bình 50%.
- Amazon Linux 2023, EC2 `t3.medium`; Aurora có một writer `db.t4g.medium`.
- Một NAT Gateway, S3 Gateway Endpoint, bucket chặn public access.
- EC2 dùng role `three-tier-ec2-role`, có SSM và S3 read-only; không cần SSH key.
- Chỉ External ALB mở HTTP cho Internet. Web chỉ nhận từ External ALB, App chỉ nhận từ Internal ALB, DB chỉ nhận từ App.

Đây là cấu hình lab: HTTP chưa có TLS; một NAT không dự phòng giữa AZ; Aurora chưa có replica để kiểm tra failover sang replica. Aurora, NAT, ALB, EC2 và Detailed Monitoring có thể phát sinh phí.

## 2. Cấu trúc mã nguồn

| Đường dẫn                            | Chức năng                                 |
| ------------------------------------ | ----------------------------------------- |
| `app-tier/`                          | Backend Node.js, API transaction          |
| `web-tier/`                          | Frontend React                            |
| `nginx.conf`                         | Static files, `/health`, proxy `/api/`    |
| `terraform/versions.tf`              | AWS provider, hiện chốt phiên bản 6.74.0  |
| `terraform/variables.tf`             | Region, AZ, bucket, mật khẩu              |
| `terraform/network.tf`, `routes.tf`  | VPC, subnet, NAT, route, S3 endpoint      |
| `terraform/security-groups.tf`       | Năm Security Group                        |
| `terraform/iam.tf`                   | Role, policy attachment, instance profile |
| `terraform/database.tf`              | Aurora và DB subnet group                 |
| `terraform/s3.tf`                    | Bucket và upload source                   |
| `terraform/app-alb.tf`, `web-alb.tf` | ALB, listener, target group               |
| `terraform/launch-templates.tf`      | AMI, EC2, IAM profile, user data          |
| `terraform/autoscaling.tf`           | ASG, CPU policy, rolling refresh          |
| `terraform/templates/`               | Script bootstrap App/Web                  |
| `terraform/outputs.tf`               | URL, endpoint, bucket, target group ARN   |

Các lệnh **local** bên dưới chạy trong thư mục `terraform`. Các lệnh **EC2** chạy qua Console → EC2 → chọn instance → Connect → Session Manager. Các placeholder `<...>` cần thay bằng giá trị thật.

## 3. Chuẩn bị và triển khai

### 3.1 Công cụ và tài khoản

Máy local cần Terraform, AWS CLI, Bash, curl. Tài khoản AWS cần quyền tạo các tài nguyên trong cấu hình và gắn IAM role cho EC2. Nếu dùng SSO, đăng nhập profile trước; nếu dùng profile khác mặc định, đặt `AWS_PROFILE`.

Từ thư mục `application-code`:

```bash
cd terraform
terraform version
aws --version
# Nếu dùng profile riêng:
# export AWS_PROFILE=my-profile

export AWS_REGION=ap-southeast-1
export AWS_DEFAULT_REGION="$AWS_REGION"
aws sts get-caller-identity
```

**Quan trọng:** `provider "aws"` hiện không đặt `region = var.aws_region`, nên provider lấy region từ môi trường/profile. Cần đồng bộ `AWS_REGION`, biến `aws_region` và các AZ. Mặc định trong code là Singapore, `ap-southeast-1`.

### 3.2 Khai báo biến

Chỉnh `terraform.tfvars` trong thư mục `terraform`:

```hcl
aws_region = "ap-southeast-1"
az_a       = "ap-southeast-1a"
az_b       = "ap-southeast-1b"
bucket_name = "three-tier-code-tenban-unique"
```

Tên bucket phải duy nhất. Không ghi mật khẩu vào file này. Do template hiện chèn mật khẩu vào JavaScript và file cấu hình MySQL, dùng mật khẩu **16–41 ký tự gồm chữ và số** để tránh lỗi ký tự đặc biệt. Code hiện chưa có validation tự kiểm tra điều kiện này.

```bash
read -rsp "Aurora password: " TF_VAR_db_password
echo
export TF_VAR_db_password
```

Không cần sửa local `DbConfig.js`: bootstrap tạo file trên App EC2. Terraform thay placeholder DNS Internal ALB khi upload `nginx.conf` lên S3. Không upload `node_modules`, React `build`, hoặc `.env` qua các tập file hiện tại.

Mật khẩu vẫn nằm trong Terraform state, saved plan và user data; `sensitive` chỉ che hiển thị. Bảo vệ các file này. Nếu dùng Git, thêm các mẫu sau vào `.gitignore` phù hợp:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
```

Giữ `.terraform.lock.hcl` trong version control. Không commit credentials hoặc file biến có secret.

### 3.3 Tạo tài nguyên

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=deploy.tfplan
terraform apply deploy.tfplan
```

Nếu format chưa đạt, chạy `terraform fmt -recursive`, rồi kiểm tra lại. Đọc plan trước apply. Không cần chạy npm hoặc build trên local.

`apply` hoàn tất chưa bảo đảm EC2 đã bootstrap xong. Web còn cần cài package và build React; App cần cài dependency và tạo bảng.

```bash
terraform output
```

Nếu mở terminal mới, đặt lại region/profile và `TF_VAR_db_password` khi cần chạy plan/apply/destroy.

## 4. Kiểm tra trạng thái ban đầu

Local:

```bash
APP_URL=$(terraform output -raw website_url)
APP_TG=$(terraform output -raw app_target_group_arn)
WEB_TG=$(terraform output -raw web_target_group_arn)
BUCKET=$(terraform output -raw s3_bucket)
INTERNAL_ALB=$(terraform output -raw internal_alb_dns)
DB_HOST=$(terraform output -raw db_writer_endpoint)

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names app-asg web-asg \
  --query 'AutoScalingGroups[].{ASG:AutoScalingGroupName,Desired:DesiredCapacity,Instances:Instances[].{ID:InstanceId,Health:HealthStatus,State:LifecycleState}}' \
  --output json

for TG in "$APP_TG" "$WEB_TG"; do
  aws elbv2 describe-target-health \
    --target-group-arn "$TG" \
    --query 'TargetHealthDescriptions[].{ID:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --output table
done
```

Đạt khi mỗi ASG có 2 instance `InService`, target App:4000 và Web:80 đều `healthy`. Kiểm tra subnet/AZ của instance trên Console để xác nhận phân bố hai AZ.

## 5. Bộ test nhanh

Chạy theo thứ tự: API/UI → process recovery → ASG recovery → scaling. Đợi đủ target healthy trước bài tiếp theo. Không gây lỗi đồng thời cả hai máy cùng tier.

### 5.1 HTTP, API và giao diện

Local:

```bash
for ROUTE in / /health /api/health /api/transaction; do
  echo "Testing $ROUTE"
  curl -fsS --max-time 15 "$APP_URL$ROUTE"
  echo
done
```

| URL                | Kết quả mong đợi         | Phần được kiểm tra            |
| ------------------ | ------------------------ | ----------------------------- |
| `/`                | HTML React               | External ALB, Nginx           |
| `/health`          | Web Tier Health Check    | Web HTTP                      |
| `/api/health`      | This is the health check | Proxy, Internal ALB, App HTTP |
| `/api/transaction` | JSON có `result`         | Kết nối đến Aurora            |

`/api/health` không kiểm tra DB. Mở `$APP_URL` trong trình duyệt, vào DB Demo; kiểm tra JS/CSS tải thành công và refresh tại trang DB Demo không bị 404.

Tạo transaction:

```bash
TEST_DESC="quick-test-$(date +%s)"
curl -fsS --max-time 15 \
  -X POST "$APP_URL/api/transaction" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":10.25,\"desc\":\"$TEST_DESC\"}"

curl -fsS --max-time 15 "$APP_URL/api/transaction"
```

Đạt khi transaction xuất hiện trong GET và DB Demo, vẫn còn khi refresh hoặc mở cửa sổ ẩn danh. Giữ dữ liệu này để test persistence sau thay máy.

### 5.2 systemd tự phục hồi tiến trình

Trên một **App EC2**:

```bash
sudo systemctl show app-tier -p MainPID -p NRestarts
sudo systemctl kill --kill-whom=main --signal=SIGKILL app-tier
```

Sau khoảng 10 giây:

```bash
sudo systemctl is-active app-tier
sudo systemctl show app-tier -p MainPID -p NRestarts
curl -fsS http://localhost:4000/health
```

Đạt khi service `active`, PID đổi, số restart tăng, instance ID không đổi.

### 5.3 ASG thay máy có service lỗi

Trên cùng App EC2, sau khi bài trên đạt:

```bash
sudo systemctl stop app-tier
```

Dừng chủ động không kích hoạt `Restart=always`. Nếu máy còn trong grace period ban đầu, ASG chưa thay máy ngay.

Local, chạy lại để theo dõi:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$APP_TG" \
  --query 'TargetHealthDescriptions[].{ID:Target.Id,State:TargetHealth.State}' \
  --output table

aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name app-asg \
  --max-items 10 \
  --query 'Activities[].{Time:StartTime,Status:StatusCode,Cause:Cause}' \
  --output table
```

Đạt khi target cũ unhealthy, ASG thay bằng instance ID mới, đủ 2 target healthy và dữ liệu test vẫn còn:

```bash
curl -fsS --max-time 15 "$APP_URL/api/transaction"
```

Bài này đã kiểm tra tạo máy thay thế, không cần terminate thêm App instance trong bộ test nhanh. Để nghiệm thu Web tương tự, dừng `nginx` trên một Web EC2 và theo dõi `web-asg`/`$WEB_TG`:

```bash
sudo systemctl stop nginx
```

Nếu cần test riêng instance termination, terminate đúng một máy bằng EC2 Console, giữ Desired Capacity không đổi. Chỉ thực hiện khi tier đã ổn định; đây là bài bổ sung, không bắt buộc lặp mỗi lần.

### 5.4 Automatic scale-out

Đợi App có 2 máy healthy và qua warmup. Trên **cả hai App EC2**, chạy gần như đồng thời:

```bash
sudo dnf install -y stress-ng
stress-ng --cpu 2 --timeout 600s
```

Local:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names app-asg \
  --query 'AutoScalingGroups[].{ASG:AutoScalingGroupName,Desired:DesiredCapacity,Count:length(Instances)}' \
  --output table
```

Xem thêm ASG Activity và CPU trong CloudWatch. Ngay khi Desired tăng trên 2, nhấn `Ctrl+C` ở cả hai phiên stress; đợi máy mới healthy để kết thúc bài. Không cần đợi đủ 600 giây hoặc tăng đủ 4 máy.

Policy dùng CPU trung bình cả ASG: stress một trong hai máy có thể chỉ đạt khoảng 50%. Máy mới ít tải cũng làm trung bình giảm. Thời gian scale-out phụ thuộc metric/alarm và warmup, không có cam kết mốc vài phút cố định.

Muốn nghiệm thu policy Web, thực hiện tương tự trên cả hai Web EC2 và theo dõi `web-asg`. Chỉ test App không chứng minh policy Web hoạt động.

### 5.5 Scale-in: chọn đầy đủ hoặc kết thúc nhanh

**Kiểm tra automatic scale-in:** dừng stress rồi thực hiện các kiểm tra IAM/SG bên dưới trong lúc đợi. Đạt khi ASG tự giảm về Min 2. Không cần giữ terminal ở vòng chờ liên tục.

**Kết thúc nhanh, bỏ test automatic scale-in:** khi hết tải và các instance healthy, đặt lại Desired bằng tay:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name app-asg \
  --desired-capacity 2
```

Đây là thu nhỏ thủ công, không được tính là automatic scale-in thành công. Policy vẫn có thể điều chỉnh Desired nếu metric còn cao. Làm tương tự với `web-asg` nếu đã test Web.

## 6. Test bổ sung để nghiệm thu đầy đủ

### 6.1 Đọc một transaction và xóa dữ liệu

Lấy ID thật từ GET danh sách, chỉ chọn dữ liệu test:

```bash
TEST_ID=12 # Thay bằng ID thật

curl -i --max-time 15 \
  -X GET "$APP_URL/api/transaction/id" \
  -H 'Content-Type: application/json' \
  -d "{\"id\":$TEST_ID}"

curl -i --max-time 15 \
  -X DELETE "$APP_URL/api/transaction/id" \
  -H 'Content-Type: application/json' \
  -d "{\"id\":$TEST_ID}"

curl -fsS --max-time 15 "$APP_URL/api/transaction"
```

API hiện nhận ID trong JSON body của GET/DELETE, không phải query string. Đạt khi chỉ transaction đã chọn bị xóa.

**Chỉ chạy lệnh sau nếu toàn bộ transaction đều có thể xóa:**

```bash
curl -i --max-time 15 -X DELETE "$APP_URL/api/transaction"
curl -fsS --max-time 15 "$APP_URL/api/transaction"
```

Kỳ vọng `{"result":[]}`. App không có endpoint cập nhật transaction.

### 6.2 Aurora trực tiếp

Local lấy endpoint:

```bash
terraform output -raw db_writer_endpoint
```

Trên mỗi App EC2, kết nối bằng password prompt:

```bash
mysql -h <WRITER-ENDPOINT> -u admin -p webappdb
```

```sql
SHOW TABLES;
DESCRIBE transactions;
SELECT * FROM transactions ORDER BY id DESC LIMIT 20;
EXIT;
```

Đạt khi có bảng `transactions` với `id`, `amount`, `description` và dữ liệu khớp API. Không thể test chuyển writer sang replica vì cấu hình chỉ có một DB instance.

### 6.3 IAM, SSM, S3

Vào Session Manager trên Web và App. Trên EC2:

```bash
aws sts get-caller-identity
aws s3 ls s3://<BUCKET>/app-tier/
aws s3 ls s3://<BUCKET>/web-tier/
```

Kỳ vọng ARN có `assumed-role/three-tier-ec2-role/`, đọc được source. Local:

```bash
aws s3api get-public-access-block --bucket "$BUCKET"
```

Kỳ vọng cả bốn thuộc tính `true`. VPC Console → Endpoints: S3 endpoint `Available`, gắn với route table tương ứng và có route prefix list S3 trỏ tới endpoint. Đọc S3 thành công đơn thuần chưa chứng minh traffic đi qua endpoint.

### 6.4 Security Group

| Nguồn    | Đích                | Kỳ vọng    |
| -------- | ------------------- | ---------- |
| Internet | External ALB:80     | Thành công |
| Web EC2  | Internal ALB:80     | Thành công |
| App EC2  | Aurora:3306         | Thành công |
| Internet | Web public IP:80    | Bị chặn    |
| Web EC2  | App private IP:4000 | Bị chặn    |
| Web EC2  | Aurora:3306         | Bị chặn    |

Trên Web EC2:

```bash
curl -i --max-time 10 http://<INTERNAL-ALB-DNS>/health
curl -i --connect-timeout 5 --max-time 10 http://<APP-PRIVATE-IP>:4000/health
timeout 5 bash -c 'echo > /dev/tcp/<WRITER-ENDPOINT>/3306'
echo $?
```

Lệnh đầu trả 200; các đường trực tiếp bị chặn, TCP timeout thường trả 124. Local:

```bash
curl -i --connect-timeout 5 --max-time 10 http://<WEB-PUBLIC-IP>/health
```

Kỳ vọng bị chặn. Đối chiếu thêm SG rule vì timeout cũng có thể do nhập sai địa chỉ. Không mở rộng SG chỉ để làm các test này thành công.

## 7. Cập nhật source và rolling refresh

Sửa source local rồi chạy trong `terraform`:

```bash
terraform plan -out=update.tfplan
terraform apply update.tfplan
```

S3 object được cập nhật, nhưng EC2 đang chạy không tự tải lại source. Nếu chỉ sửa source, refresh tier tương ứng:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name app-asg \
  --preferences '{"MinHealthyPercentage":100,"MaxHealthyPercentage":150,"InstanceWarmup":30}'
```

Web dùng cùng lệnh với `--auto-scaling-group-name web-asg`. Không refresh cả hai nếu chỉ thay một tier. Nếu thay Launch Template, Terraform đã cấu hình tự rolling refresh; không khởi chạy refresh thủ công trùng lúc đó.

Theo dõi:

```bash
for ASG in app-asg web-asg; do
  aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG" \
    --max-records 1 \
    --query 'InstanceRefreshes[].{Status:Status,Progress:PercentageComplete,Reason:StatusReason}' \
    --output table
done
```

Đạt khi refresh `Successful`, target healthy, website và dữ liệu vẫn đúng. Dùng luôn lần refresh này làm bài test bootstrap; không lặp một bài refresh khác chỉ để kiểm tra cùng chức năng.

## 8. Các thiết lập giúp test nhanh

| Thông số hiện tại           |      Giá trị | Vai trò                                             |
| --------------------------- | -----------: | --------------------------------------------------- |
| ALB health interval         |      10 giây | Kiểm tra thường xuyên                               |
| Healthy/unhealthy threshold |          2/2 | Số lần đạt/lỗi để chuyển trạng thái                 |
| Deregistration delay        |      15 giây | Rút ngắn draining; chỉ phù hợp request ngắn của lab |
| Refresh instance warmup     |      30 giây | Chờ ổn định thêm sau healthy khi refresh            |
| Default instance warmup     |     300 giây | Tránh scaling phản ứng với CPU bootstrap            |
| App/Web grace period        | 300/600 giây | Bảo vệ instance trong lúc cài package/build         |
| Detailed Monitoring         |          Bật | Metric EC2 theo chu kỳ một phút                     |

Grace period không phải thời gian chờ cố định mỗi lần test trên máy đã ổn định. Không giảm xuống vài chục giây khi Web còn phải build React. `wait_for_capacity_timeout = "20m"` chỉ giới hạn thời gian Terraform chờ, giảm nó không làm máy khởi động nhanh hơn.

## 9. Chẩn đoán lỗi

Trên EC2:

```bash
sudo tail -n 150 /var/log/cloud-init-output.log
```

App:

```bash
sudo systemctl status app-tier --no-pager
sudo journalctl -u app-tier -n 100 --no-pager
curl -i http://localhost:4000/health
```

Web:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo tail -n 100 /var/log/nginx/error.log
```

| Hiện tượng                         | Kiểm tra                                                    |
| ---------------------------------- | ----------------------------------------------------------- |
| Terraform báo region/AZ không khớp | `AWS_REGION`, profile, `aws_region`, `az_a`, `az_b`         |
| S3 download hoặc npm/dnf thất bại  | IAM, NAT/public route, DNS, cloud-init log                  |
| Web chưa healthy                   | Build React hoàn tất chưa, nginx config và quyền đọc build  |
| `/health` OK, `/api/health` lỗi    | Nginx proxy DNS, Internal ALB target và SG                  |
| App health OK, transaction lỗi     | Aurora endpoint/password, DB SG, bảng và journal            |
| Không scale-out                    | CPU trung bình toàn ASG, metric, warmup, policy và Activity |
| Không scale-in ngay                | Tải đã hết chưa, thời gian đánh giá policy, warmup          |
| Refresh thất bại                   | `StatusReason`, target health và bootstrap log              |

Các hạn chế source hiện tại cần phân biệt với lỗi Terraform:

- POST trả thông báo thành công trước khi INSERT hoàn tất; luôn GET lại để xác nhận dữ liệu.
- Handler GET một transaction đọc `row.desc` thay vì `row.description`, nên có thể thiếu description.
- SQL đang ghép chuỗi trực tiếp và xử lý lỗi async chưa đầy đủ; input bất thường có thể gây lỗi hoặc restart App. Không dùng bản lab này làm API public production.

## 10. Checklist nghiệm thu

- [ ] Mỗi ASG có target healthy ở hai AZ.
- [ ] React, Web health, App health và GET dữ liệu hoạt động.
- [ ] Thêm, đọc lại, xóa dữ liệu test đúng; dữ liệu còn sau thay máy.
- [ ] SSM và IAM S3 read hoạt động, bucket chặn public access.
- [ ] Các đường SG cho phép hoạt động, các đường trực tiếp bị chặn.
- [ ] systemd phục hồi tiến trình App.
- [ ] ASG thay máy có service lỗi.
- [ ] CPU policy scale-out, máy mới healthy.
- [ ] Automatic scale-in đã test, hoặc ghi rõ bỏ qua và thu nhỏ thủ công.
- [ ] Refresh triển khai source thành công, Web build trên EC2.

Sau test chạy `terraform plan` để xem thay đổi ngoài dự kiến. Desired Capacity được ignore trong lifecycle; Terraform không ép về 2 sau mỗi lần autoscaling. AMI lấy từ tham số `latest` nên một lần plan sau có thể đề xuất cập nhật Launch Template nếu AMI mới xuất hiện.

## 11. Dọn tài nguyên

Cấu hình hiện tại có `skip_final_snapshot = true` và S3 `force_destroy = true`: destroy sẽ xóa DB mà không tạo snapshot cuối, đồng thời xóa object trong bucket. Tạo snapshot hoặc xuất dữ liệu trước nếu cần giữ.

Trong `terraform`, với đúng credentials/region và mật khẩu biến môi trường:

```bash
terraform plan -destroy
terraform destroy
```

Xác nhận sau khi đọc danh sách tài nguyên. Chờ hoàn tất, kiểm tra Console còn tài nguyên tính phí hay không. Giữ state cho đến khi dọn xong để tránh mất khả năng quản lý tài nguyên.

```bash
unset TF_VAR_db_password
rm -f deploy.tfplan update.tfplan fast-tests.tfplan
```
