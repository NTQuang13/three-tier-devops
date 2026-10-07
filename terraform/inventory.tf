resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  content = templatefile("${path.module}/templates/hosts.ini.tftpl", {
    jenkins_ip    = aws_instance.jenkins.private_ip
    monitoring_ip = aws_instance.monitoring.private_ip
    web_ips       = aws_instance.web[*].private_ip
    app_ips       = aws_instance.app[*].private_ip
  })
}

resource "local_file" "group_vars" {
  filename = "${path.module}/../ansible/group_vars/all.yml"
  content  = <<-EOT
    db_host: ${aws_rds_cluster.aurora.endpoint}
    internal_lb_dns: ${aws_lb.internal.dns_name}
    public_lb_dns: ${aws_lb.public.dns_name}
  EOT
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "monitoring_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "public_lb_dns" {
  value = aws_lb.public.dns_name
}