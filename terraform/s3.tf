locals {
  app_directory = "${path.module}/../app-tier"
  web_directory = "${path.module}/../web-tier"

  app_files = toset([
    for file in fileset(local.app_directory, "**") : file
    if !startswith(file, "node_modules/")
    && !startswith(file, ".git/")
    && !startswith(file, ".env")
    && file != "DbConfig.js"
  ])

  web_files = toset([
    for file in fileset(local.web_directory, "**") : file
    if !startswith(file, "node_modules/")
    && !startswith(file, "build/")
    && !startswith(file, ".git/")
    && !startswith(file, ".env")
  ])

  nginx_config = replace(
    file("${path.module}/../nginx.conf"),
    "[REPLACE-WITH-INTERNAL-LB-DNS]",
    aws_lb.app.dns_name
  )
}

resource "aws_s3_bucket" "code" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "code" {
  bucket = aws_s3_bucket.code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code" {
  bucket = aws_s3_bucket.code.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "app" {
  for_each    = local.app_files
  bucket      = aws_s3_bucket.code.id
  key         = "app-tier/${each.value}"
  source      = "${local.app_directory}/${each.value}"
  source_hash = filemd5("${local.app_directory}/${each.value}")
}

resource "aws_s3_object" "web" {
  for_each    = local.web_files
  bucket      = aws_s3_bucket.code.id
  key         = "web-tier/${each.value}"
  source      = "${local.web_directory}/${each.value}"
  source_hash = filemd5("${local.web_directory}/${each.value}")
}

resource "aws_s3_object" "nginx" {
  bucket       = aws_s3_bucket.code.id
  key          = "nginx.conf"
  content      = local.nginx_config
  content_type = "text/plain"
}