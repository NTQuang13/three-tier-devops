# AWS Three-tier Web App

Ứng dụng demo quản lý giao dịch, triển khai trên AWS bằng Terraform.

```text
Trình duyệt → Public ALB → React/Nginx → Internal ALB → Node.js → Aurora MySQL
```

Web và App có Auto Scaling Group riêng, mỗi tầng ban đầu 2 EC2. Mã nguồn được lưu trên S3; App và database nằm trong private subnet.

## 1. Chuẩn bị

Cài Terraform, AWS CLI và cấu hình credentials có quyền tạo tài nguyên của project. Hạ tầng AWS có tính phí.

Từ thư mục gốc project:

```bash
export AWS_REGION=ap-southeast-1
export AWS_DEFAULT_REGION="$AWS_REGION"
aws sts get-caller-identity
cd terraform
```

Nếu dùng named profile, đặt `export AWS_PROFILE=ten-profile` trước khi chạy. Region môi trường phải trùng `aws_region` vì provider hiện chưa liên kết với biến này.

Sửa `terraform.tfvars`, đổi tên bucket thành tên duy nhất của bạn:

```hcl
aws_region  = "ap-southeast-1"
az_a        = "ap-southeast-1a"
az_b        = "ap-southeast-1b"
bucket_name = "three-tier-code-your-unique-name"
```

## 2. Triển khai

Chạy trong thư mục `terraform`:

```bash
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Nhập `db_password` khi Terraform hỏi; nhập cùng một mật khẩu cho plan/apply. Với template hiện tại, dùng 16–32 ký tự gồm chữ hoa, chữ thường, số và dấu `_` hoặc `-` để tránh lỗi chèn mật khẩu vào cấu hình.

Đọc thay đổi và nhập `yes` để xác nhận apply. Terraform tự upload code, build frontend và tạo bảng database; không cần làm thủ công. Chờ các EC2 cài đặt xong, rồi mở `website_url` từ output bằng **HTTP**.

## 3. Kiểm tra hạ tầng trên AWS Console

Chọn đúng account/region:

| Nơi kiểm tra | Kết quả cần đạt |
| --- | --- |
| EC2 → Load Balancers | `web-external-alb`, `app-internal-alb` Active |
| EC2 → Target Groups | `web-tg`, `app-tg`: mỗi group ban đầu có 2 target Healthy |
| EC2 → Auto Scaling Groups | `web-asg`, `app-asg`: desired ban đầu 2, min 2, max 4 |
| RDS → Databases | `three-tier-db` và writer Available |
| S3 → bucket code | Có `web-tier/`, `app-tier/`, `nginx.conf`; chặn public access |

## 4. Kiểm tra chức năng bằng trình duyệt

1. Mở `website_url`: thấy trang Home và hình kiến trúc.
2. Chọn menu → **DB Demo**, hoặc vào `website_url/#/db`.
3. Nhập AMOUNT `125.50`, DESC `demo-test`, bấm **ADD**: bảng phải xuất hiện dòng mới với ID, số tiền và mô tả đúng.
4. Reload trang: dữ liệu vẫn còn. Chỉ kết luận thêm thành công khi thấy bản ghi, không chỉ dựa vào response POST.
5. Bấm **DEL**: toàn bộ giao dịch bị xóa; reload để xác nhận bảng vẫn rỗng. Chỉ dùng dữ liệu thử nghiệm.

Mở các đường dẫn sau trên cùng website để kiểm tra:

| Đường dẫn | Kết quả |
| --- | --- |
| `/health` | `Web Tier Health Check` |
| `/api/health` | `"This is the health check"` |
| `/api/transaction` | JSON chứa `result` là danh sách giao dịch, rỗng sau khi DEL |

Health check không kiểm tra DB; thao tác thêm và đọc lại xác nhận toàn tuyến. Project chưa có xác thực và HTTPS.

## 5. Khi gặp lỗi

Kiểm tra Target Groups và ASG → Activity trước. Để xem log, vào **EC2 → Instances → chọn máy → Connect → Session Manager**, rồi chạy:

```bash
# Cả hai tầng: log cài đặt.
sudo tail -n 50 /var/log/cloud-init-output.log
# Chỉ App EC2.
sudo journalctl -u app-tier -n 50 --no-pager
# Chỉ Web EC2.
sudo tail -n 50 /var/log/nginx/error.log
```

Khi sửa code, chạy lại `terraform apply`, rồi vào ASG → **Instance refresh**, tắt **Skip matching** để EC2 tải code mới từ S3.

## 6. Dọn tài nguyên

Trong thư mục `terraform`, chạy `terraform destroy`, nhập mật khẩu DB khi được hỏi và xác nhận `yes`. Lệnh này **xóa database không tạo final snapshot và xóa bucket code**; sao lưu trước nếu cần. Giữ kín Terraform state vì có thể chứa mật khẩu. Kiểm tra Console sau khi dọn để tránh tài nguyên còn phát sinh phí.
