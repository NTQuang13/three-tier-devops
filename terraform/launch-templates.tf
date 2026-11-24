data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "app" {
  name                   = "app-lt"
  image_id               = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.medium"
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile(
    "${path.module}/templates/app-user-data.sh.tftpl",
    {
      bucket      = aws_s3_bucket.code.id
      region      = var.aws_region
      db_host     = aws_rds_cluster.main.endpoint
      db_password = var.db_password
    }
  ))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "three-tier-app"
    }
  }
}

resource "aws_launch_template" "web" {
  name                   = "web-lt"
  image_id               = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.medium"
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.web.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile(
    "${path.module}/templates/web-user-data.sh.tftpl",
    {
      bucket = aws_s3_bucket.code.id
      region = var.aws_region
    }
  ))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "three-tier-web"
    }
  }
}
