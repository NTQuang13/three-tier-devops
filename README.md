# Three-Tier Web App: CI/CD trên AWS

<!-- ![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20ALB%20%7C%20Aurora-FF9900?logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Config-Ansible-EE0000?logo=ansible&logoColor=white)
![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-D24939?logo=jenkins&logoColor=white)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker&logoColor=white)
![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus%20%7C%20Grafana-E6522C?logo=prometheus&logoColor=white) -->

Ứng dụng web 3 tầng (React, Node.js, Aurora MySQL) được triển khai trên các VM EC2 với quy trình hoàn toàn tự động: **push code, Jenkins build image, đẩy lên Docker Hub, Ansible deploy rolling lên từng VM**. Toàn bộ hạ tầng được dựng bằng Terraform và được giám sát bằng Prometheus + Grafana.

## Mục lục

- [Three-Tier Web App: CI/CD trên AWS](#three-tier-web-app-cicd-trên-aws)
  - [Mục lục](#mục-lục)
  - [Tính năng chính](#tính-năng-chính)
  - [Kiến trúc](#kiến-trúc)
    - [Mạng và phân vùng](#mạng-và-phân-vùng)
  - [Công nghệ sử dụng](#công-nghệ-sử-dụng)
  - [Cấu trúc repository](#cấu-trúc-repository)
  - [Yêu cầu trước khi bắt đầu](#yêu-cầu-trước-khi-bắt-đầu)
  - [Hướng dẫn triển khai](#hướng-dẫn-triển-khai)
    - [1. Dựng hạ tầng bằng Terraform](#1-dựng-hạ-tầng-bằng-terraform)
    - [2. Bootstrap nền tảng bằng Ansible](#2-bootstrap-nền-tảng-bằng-ansible)
    - [3. Cấu hình Jenkins](#3-cấu-hình-jenkins)
    - [4. Truy cập hệ thống](#4-truy-cập-hệ-thống)
  - [Pipeline CI/CD](#pipeline-cicd)
  - [Monitoring](#monitoring)
  - [Kiểm thử end-to-end](#kiểm-thử-end-to-end)
  - [Rollback](#rollback)
  - [Bảo mật](#bảo-mật)
  - [Chi phí](#chi-phí)
  - [Xử lý sự cố](#xử-lý-sự-cố)
  - [Dọn dẹp tài nguyên](#dọn-dẹp-tài-nguyên)
  - [Hướng phát triển](#hướng-phát-triển)

## Tính năng chính

- **Hạ tầng dưới dạng code**: VPC, subnet, security group, ALB, Aurora và 6 VM được tạo bằng một lệnh `terraform apply`.
- **Sẵn sàng cao**: 2 Availability Zone, 2 VM mỗi tầng, Aurora có writer và reader.
- **Deploy không downtime**: Ansible deploy từng VM một (`serial: 1`) và chờ health check trước khi sang VM kế tiếp.
- **Tự động hóa end-to-end**: Jenkins theo dõi repo và chạy pipeline Build, Test, Push, Deploy, Smoke test.
- **Quan sát được hệ thống**: metrics của VM (node_exporter) và container (cAdvisor) hiển thị trên Grafana.
- **Không dùng IAM Role trên VM**: truy cập qua SSH key pair, image lấy từ Docker Hub.

## Kiến trúc

![Architecture](/web-tier/src/assets/architecture.png)

**Luồng CI/CD và giám sát:**

![CICD](/web-tier/src/assets/cicd.drawio.png)

### Mạng và phân vùng

| Thành phần   | Subnet                                      | Truy cập từ                        |
| ------------ | ------------------------------------------- | ---------------------------------- |
| Public ALB   | Public (2 AZ)                               | Internet, cổng 80                  |
| Web VM       | Public (2 AZ)                               | Public ALB (80), Jenkins (SSH)     |
| Internal ALB | Private (2 AZ)                              | Web VM (80)                        |
| App VM       | Private (2 AZ)                              | Internal ALB (4000), Jenkins (SSH) |
| Aurora       | Database (2 AZ), không có route ra internet | App VM (3306)                      |
| Jenkins      | Public                                      | IP của bạn (22, 8080)              |
| Monitoring   | Public                                      | IP của bạn (3000, 9090)            |

App VM ra internet (để pull image) thông qua NAT Gateway.

## Công nghệ sử dụng

| Lớp            | Công cụ                                      | Vai trò                                          |
| -------------- | -------------------------------------------- | ------------------------------------------------ |
| Source control | Git, GitHub                                  | Quản lý mã nguồn                                 |
| CI/CD          | Jenkins                                      | Build, test, push image, gọi Ansible             |
| Container      | Docker, Docker Hub                           | Đóng gói và phân phối image                      |
| Cấu hình       | Ansible                                      | Cài Docker, exporter, monitoring, deploy rolling |
| Hạ tầng        | Terraform                                    | Dựng VPC, SG, ALB, Aurora, EC2                   |
| Cloud          | AWS                                          | EC2, ALB, Aurora MySQL, NAT Gateway              |
| Giám sát       | Prometheus, Grafana, node_exporter, cAdvisor | Metrics và dashboard                             |
| Ứng dụng       | React, nginx, Node.js                        | Web tier và App tier                             |

## Cấu trúc repository

```
three-tier-devops/
├── app-tier/                  # Node.js API (cổng 4000)
│   ├── Dockerfile
│   └── .dockerignore
├── web-tier/                  # React + nginx
│   ├── Dockerfile
│   ├── .dockerignore
│   └── nginx/default.conf.template
├── terraform/                 # Hạ tầng AWS
│   ├── provider.tf  variables.tf  network.tf  security.tf
│   ├── compute.tf   alb.tf        database.tf inventory.tf
│   └── templates/             # jenkins-userdata.sh, hosts.ini.tftpl
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml               # Nền tảng: Docker, exporter, DB init, monitoring
│   ├── deploy.yml             # Deploy ứng dụng (Jenkins gọi mỗi build)
│   ├── files/                 # init.sql, grafana-datasource.yml
│   ├── templates/             # prometheus.yml.j2
│   ├── inventory/hosts.ini    # Do Terraform sinh ra
│   └── group_vars/all.yml     # Do Terraform sinh ra
├── Jenkinsfile
└── README.md
```

## Yêu cầu trước khi bắt đầu

**Công cụ trên máy local:** `git`, `docker`, `terraform >= 1.5`, `aws cli`.

**Tài khoản:**

- AWS account, access key cho Terraform (chỉ dùng trên máy local, VM không gắn IAM role).
- GitHub account.
- Docker Hub account và **Access Token**. Tạo 2 repository public: `three-tier-app` và `three-tier-web`.

**Cấu hình ban đầu:**

```bash
aws configure                                   # region: ap-southeast-1
ssh-keygen -t rsa -f ~/.ssh/three-tier-key -N ""
```

## Hướng dẫn triển khai

### 1. Dựng hạ tầng bằng Terraform

```bash
cd terraform
export TF_VAR_db_password='<mat-khau-aurora>'
terraform init
terraform apply -var "my_ip_cidr=$(curl -s ifconfig.me)/32"
```

Mất khoảng 10 đến 15 phút. Sau khi xong:

- Ghi lại các output: `jenkins_public_ip`, `monitoring_public_ip`, `public_lb_dns`.
- Kiểm tra `ansible/inventory/hosts.ini` và `ansible/group_vars/all.yml` đã được sinh ra.
- Commit và push hai file này lên GitHub (chúng không chứa secret).

### 2. Bootstrap nền tảng bằng Ansible

App VM nằm trong private subnet nên Jenkins server được dùng làm Ansible control node.

```bash
# Từ máy local (chỉ dùng cho lab)
scp -i ~/.ssh/three-tier-key ~/.ssh/three-tier-key ec2-user@<JENKINS_PUBLIC_IP>:~/.ssh/three-tier-key
ssh -i ~/.ssh/three-tier-key ec2-user@<JENKINS_PUBLIC_IP>
```

Trên Jenkins server:

```bash
cloud-init status --wait                 # chờ: status: done
git clone https://github.com/<user>/three-tier-devops.git
cd three-tier-devops/ansible

ansible-playbook site.yml \
  --private-key ~/.ssh/three-tier-key \
  -e db_password='<mat-khau-aurora>' \
  -e grafana_password='<mat-khau-grafana>'
```

Playbook này cài Docker và node_exporter trên mọi VM, cAdvisor trên Web/App VM, khởi tạo bảng `transactions` trong Aurora, và dựng Prometheus + Grafana.

### 3. Cấu hình Jenkins

1. Mở `http://<JENKINS_PUBLIC_IP>:8080`, lấy mật khẩu ban đầu:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
2. Cài **suggested plugins** và tạo tài khoản admin.
3. Tạo các credential (Manage Jenkins, Credentials, Global):

   | ID               | Loại                          | Nội dung                                       |
   | ---------------- | ----------------------------- | ---------------------------------------------- |
   | `dockerhub-cred` | Username with password        | Docker Hub username và Access Token            |
   | `ssh-vm-key`     | SSH Username with private key | `ec2-user` và nội dung `~/.ssh/three-tier-key` |
   | `db-password`    | Secret text                   | Mật khẩu Aurora                                |

4. Tạo **Pipeline** tên `three-tier`: _Pipeline script from SCM_, Git, branch `*/main`, Script Path `Jenkinsfile`.
5. Mở `Jenkinsfile`, đổi `DOCKER_USER` thành Docker Hub username của bạn, commit và push.
6. Bấm **Build Now** cho lần chạy đầu tiên.

### 4. Truy cập hệ thống

| Dịch vụ    | URL                                                 |
| ---------- | --------------------------------------------------- |
| Ứng dụng   | `http://<PUBLIC_ALB_DNS>`                           |
| Jenkins    | `http://<JENKINS_PUBLIC_IP>:8080`                   |
| Grafana    | `http://<MONITORING_PUBLIC_IP>:3000` (user `admin`) |
| Prometheus | `http://<MONITORING_PUBLIC_IP>:9090`                |

## Pipeline CI/CD

Pipeline được định nghĩa trong `Jenkinsfile` và kích hoạt tự động khi có commit mới (poll SCM mỗi khoảng 2 phút).

| Stage               | Nội dung                                                              |
| ------------------- | --------------------------------------------------------------------- |
| Build images        | `docker build` cho `app-tier` và `web-tier`, gắn tag là số build      |
| Test                | Kiểm tra cú pháp Node (`node --check`) và cấu hình nginx (`nginx -t`) |
| Push to Docker Hub  | Đăng nhập bằng Access Token và push cả hai image                      |
| Deploy with Ansible | Chạy `deploy.yml`: app tier trước, web tier sau, từng VM một          |
| Smoke test          | Gọi `/health` và `/api/transaction` qua Public ALB                    |

Cơ chế deploy rolling: mỗi VM được cập nhật xong, vượt qua health check và chờ ALB đánh dấu healthy rồi mới sang VM tiếp theo, nên luôn còn ít nhất một VM phục vụ.

> Stage Test hiện chỉ kiểm tra cú pháp. Hãy bổ sung unit test và integration test thật của dự án.

## Monitoring

Prometheus thu thập metrics mỗi 15 giây từ:

- `node_exporter` (cổng 9100) trên mọi VM: CPU, RAM, disk, network.
- `cAdvisor` (cổng 8081) trên Web/App VM: CPU và RAM của từng container.

Các target được gắn label `tier` (`web`, `app`, `jenkins`, `monitoring`) để lọc theo tầng.

**Import dashboard trong Grafana** (Dashboards, New, Import):

| ID    | Dashboard          |
| ----- | ------------------ |
| 1860  | Node Exporter Full |
| 14282 | cAdvisor exporter  |

Datasource Prometheus đã được provision sẵn. Kiểm tra tại `http://<MONITORING_PUBLIC_IP>:9090/targets`, tất cả target phải ở trạng thái **UP**.

## Kiểm thử end-to-end

1. Sửa một dòng giao diện trong `web-tier`, commit và push.
2. Theo dõi Jenkins chạy qua các stage.
3. Mở `http://<PUBLIC_ALB_DNS>`, kiểm tra thay đổi và thêm một transaction.
4. Kiểm tra từng chặng khi cần xác định lỗi:

   | Chạy từ   | Lệnh                                           | Chặng được kiểm tra               |
   | --------- | ---------------------------------------------- | --------------------------------- |
   | Máy local | `curl http://<PUBLIC_ALB_DNS>/health`          | Public ALB tới nginx              |
   | Máy local | `curl http://<PUBLIC_ALB_DNS>/api/transaction` | nginx, Internal ALB, Node, Aurora |
   | Web VM    | `curl http://<INTERNAL_ALB_DNS>/transaction`   | Internal ALB, Node, Aurora        |
   | App VM    | `curl http://localhost:4000/transaction`       | Node, Aurora                      |

5. Thử chịu lỗi: chạy `sudo docker stop app-tier` trên một App VM. Target đó chuyển unhealthy, người dùng vẫn truy cập bình thường nhờ VM còn lại.

## Rollback

Chạy lại deploy với tag của bản build trước đó (trên Jenkins server):

```bash
cd three-tier-devops/ansible
ansible-playbook deploy.yml --private-key ~/.ssh/three-tier-key \
  -e docker_user=<dockerhub-user> \
  -e image_tag=<TAG_CU> \
  -e db_password='<mat-khau-aurora>'
```

## Bảo mật

Dự án này ưu tiên tính đơn giản cho môi trường học tập. Trước khi dùng cho production, hãy xem xét:

- **Không commit secret.** `.gitignore` đã loại trừ `*.tfvars`, `*.tfstate*`, `*.pem`. File `terraform.tfstate` chứa mật khẩu DB ở dạng rõ, hãy dùng remote state có mã hóa.
- **Private key trên Jenkins.** Bước copy private key lên Jenkins chỉ phù hợp cho lab. Production nên dùng SSH key riêng cho Jenkins hoặc bastion host.
- **Security group** chỉ mở đúng cổng cần thiết giữa các tầng; SSH, Jenkins UI, Grafana và Prometheus chỉ mở cho IP của bạn (`my_ip_cidr`).
- **Chỉ HTTP.** Production cần HTTPS (ACM certificate và listener 443 trên Public ALB).
- **Image public** trên Docker Hub. Không đưa secret vào image; mọi thông tin nhạy cảm truyền qua biến môi trường lúc chạy container.
- **Password Grafana, Aurora** truyền qua `-e` và credential của Jenkins; hãy dùng Ansible Vault hoặc secret manager khi mở rộng.

## Chi phí

Các tài nguyên sau tính tiền theo giờ khi đang chạy: 6 EC2, NAT Gateway, 2 ALB, Aurora (writer và reader). Hãy chạy `terraform destroy` khi không dùng. Dùng AWS Pricing Calculator để ước tính theo region của bạn.

## Xử lý sự cố

| Triệu chứng                                             | Nguyên nhân thường gặp                                                       | Cách xử lý                                                                       |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `terraform apply` lỗi tạo Aurora                        | Mật khẩu quá ngắn hoặc chứa ký tự không hợp lệ (`/`, `"`, `@`, khoảng trắng) | Đổi `db_password`                                                                |
| Ansible không SSH được App VM                           | Thiếu `--private-key`, hoặc SG chưa cho Jenkins vào cổng 22                  | Kiểm tra lệnh và rule `app_ssh`                                                  |
| `docker_container` báo thiếu module `docker`            | Task cài Docker SDK chưa chạy trên VM đó                                     | Chạy lại `site.yml`                                                              |
| Jenkins `permission denied` khi build                   | `jenkins` chưa thuộc group docker                                            | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`              |
| `ansible-playbook: command not found` trong Jenkins     | `user_data` chưa chạy xong hoặc lỗi                                          | Xem `/var/log/cloud-init-output.log`                                             |
| `502` ở `/api/`                                         | `INTERNAL_LB_DNS` sai hoặc App target chưa healthy                           | `docker logs app-tier` trên App VM                                               |
| Target Prometheus DOWN                                  | SG chưa mở 9100/8081 từ monitoring, hoặc exporter chưa chạy                  | Kiểm tra SG và `docker ps`                                                       |
| Public IP của Jenkins/Monitoring đổi sau khi stop/start | EC2 không có IP cố định                                                      | Dùng Elastic IP                                                                  |
| `npm run build` lỗi `ERR_OSSL_EVP_UNSUPPORTED`          | Node 18 với dependency cũ                                                    | Thêm `ENV NODE_OPTIONS=--openssl-legacy-provider` vào stage build của Dockerfile |

## Dọn dẹp tài nguyên

```bash
cd terraform
terraform destroy -var "my_ip_cidr=0.0.0.0/32"
```

Sau đó kiểm tra AWS Console để chắc chắn NAT Gateway, Elastic IP, Aurora và ALB đã bị xóa. Xóa thêm các repository trên Docker Hub nếu không dùng nữa.

## Hướng phát triển

- Terraform remote state: S3 backend kèm DynamoDB lock.
- Alertmanager gửi cảnh báo qua Slack hoặc email khi `up == 0` hoặc CPU cao.
- Jenkins plugin Prometheus metrics để theo dõi chính pipeline.
- `nginx-prometheus-exporter` và `blackbox_exporter` để đo request rate và uptime từ bên ngoài.
- HTTPS với ACM và listener 443.
- Tách Ansible thành roles (`docker`, `exporters`, `monitoring`, `app`, `web`).
- Webhook GitHub thay cho polling.
- Một NAT Gateway mỗi AZ để tăng khả năng chịu lỗi.
