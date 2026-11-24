resource "aws_autoscaling_group" "app" {
  name             = "app-asg"
  max_size         = 4
  min_size         = 2
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.app-a.id,
    aws_subnet.app-b.id
  ]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300
  wait_for_capacity_timeout = "20m"

  launch_template {
    id      = aws_launch_template.app.id
    version = tostring(aws_launch_template.app.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 150
      instance_warmup        = 30
    }
  }

  tag {
    key                 = "name"
    value               = "three-tier-app"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_rds_cluster_instance.writer,
    aws_s3_object.app,
    aws_s3_bucket_public_access_block.code,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.s3,
    aws_route.public-internet,
    aws_route.private-nat,
    aws_route_table_association.public-a,
    aws_route_table_association.app-a,
    aws_route_table_association.app-b,
    aws_vpc_endpoint.s3,
    aws_lb_listener.app,
  ]
}

resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "app-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}

resource "aws_autoscaling_group" "web" {
  name             = "web-asg"
  max_size         = 4
  min_size         = 2
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.public-a.id,
    aws_subnet.public-b.id
  ]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600
  default_instance_warmup   = 300
  wait_for_capacity_timeout = "20m"

  launch_template {
    id      = aws_launch_template.web.id
    version = tostring(aws_launch_template.web.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 150
      instance_warmup        = 30
    }
  }

  tag {
    key                 = "name"
    value               = "three-tier-web"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_s3_object.web,
    aws_s3_object.nginx,
    aws_s3_bucket_public_access_block.code,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.s3,
    aws_route.public-internet,
    aws_route_table_association.public-a,
    aws_route_table_association.public-b,
    aws_vpc_endpoint.s3,
    aws_lb_listener.web,
  ]
}

resource "aws_autoscaling_policy" "web" {
  name                   = "web-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}