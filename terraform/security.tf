locals {
  sg_names = ["public-alb", "web", "internal-alb", "app", "db", "jenkins", "monitoring"]
}

resource "aws_security_group" "this" {
  for_each = toset(local.sg_names)
  name     = "${each.key}-sg"
  vpc_id   = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  sg = { for k, v in aws_security_group.this : k => v.id }

  # to = SG được mở | from = SG nguồn | cidr = nguồn dạng CIDR
  rules = {
    alb_http     = { to = "public-alb",   port = 80,   from = "",             cidr = "0.0.0.0/0" }
    web_http     = { to = "web",          port = 80,   from = "public-alb",   cidr = "" }
    web_ssh      = { to = "web",          port = 22,   from = "jenkins",      cidr = "" }
    web_node     = { to = "web",          port = 9100, from = "monitoring",   cidr = "" }
    web_cadvisor = { to = "web",          port = 8081, from = "monitoring",   cidr = "" }
    ialb_http    = { to = "internal-alb", port = 80,   from = "web",          cidr = "" }
    app_http     = { to = "app",          port = 4000, from = "internal-alb", cidr = "" }
    app_ssh      = { to = "app",          port = 22,   from = "jenkins",      cidr = "" }
    app_node     = { to = "app",          port = 9100, from = "monitoring",   cidr = "" }
    app_cadvisor = { to = "app",          port = 8081, from = "monitoring",   cidr = "" }
    db_mysql     = { to = "db",           port = 3306, from = "app",          cidr = "" }
    jenkins_ssh  = { to = "jenkins",      port = 22,   from = "",             cidr = var.my_ip_cidr }
    jenkins_ui   = { to = "jenkins",      port = 8080, from = "",             cidr = var.my_ip_cidr }
    jenkins_node = { to = "jenkins",      port = 9100, from = "monitoring",   cidr = "" }
    mon_ssh      = { to = "monitoring",   port = 22,   from = "jenkins",      cidr = "" }
    mon_grafana  = { to = "monitoring",   port = 3000, from = "",             cidr = var.my_ip_cidr }
    mon_prom     = { to = "monitoring",   port = 9090, from = "",             cidr = var.my_ip_cidr }
    mon_node     = { to = "monitoring",   port = 9100, from = "monitoring",   cidr = "" }
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each                 = local.rules
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = each.value.port
  to_port                  = each.value.port
  security_group_id        = local.sg[each.value.to]
  cidr_blocks              = each.value.cidr != "" ? [each.value.cidr] : null
  source_security_group_id = each.value.from != "" ? local.sg[each.value.from] : null
}