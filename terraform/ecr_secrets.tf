resource "aws_ecr_repository" "this" {
  for_each     = toset(["three-tier-app", "three-tier-web"])
  name         = each.key
  force_delete = true # lab: cho phép destroy khi repo còn image

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Giữ 10 image mới nhất"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

resource "random_password" "db" {
  length  = 24
  special = false # tránh ký tự đặc biệt gây lỗi shell/connection string
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "three-tier/db-credentials"
  recovery_window_in_days = 0 # lab: xóa ngay khi destroy, tránh lỗi trùng tên
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.db.result
    host     = aws_rds_cluster.aurora.endpoint
    dbname   = "webappdb"
  })
}