# ---------- Public ALB -> Web ----------
resource "aws_lb" "public" {
  name               = "web-tier-public-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.this["public-alb"].id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "web" {
  name     = "web-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "public" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group_attachment" "web" {
  count            = 2
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# ---------- Internal ALB -> App ----------
resource "aws_lb" "internal" {
  name               = "app-tier-internal-lb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.this["internal-alb"].id]
  subnets            = module.vpc.private_subnets
}

resource "aws_lb_target_group" "app" {
  name     = "app-tier-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = 2
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 4000
}