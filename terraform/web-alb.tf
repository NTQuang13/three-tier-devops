resource "aws_lb_target_group" "web" {
  name                 = "web-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 15
  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "web" {
  name               = "web-external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.external-lb.id]
  subnets = [
    aws_subnet.public-a.id,
    aws_subnet.public-b.id
  ]
  depends_on = [aws_route.public-internet]
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}