output "website_url" {
  value = "http://${aws_lb.web.dns_name}"
}

output "internal_alb_dns" {
  value = aws_lb.app.dns_name
}

output "db_writer_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "s3_bucket" {
  value = aws_s3_bucket.code.id
}

output "app_target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web.arn
}