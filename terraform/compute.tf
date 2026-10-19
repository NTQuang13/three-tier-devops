data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "three-tier-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this["jenkins"].id]
  user_data              = file("${path.module}/templates/jenkins-userdata.sh")
  iam_instance_profile         = aws_iam_instance_profile.this["jenkins"].name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  root_block_device {
    volume_size = 30
  }
  tags = { Name = "jenkins" }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this["monitoring"].id]
  iam_instance_profile         = aws_iam_instance_profile.this["monitoring"].name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  root_block_device {
    volume_size = 20
  }
  tags = { Name = "monitoring" }
}

resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[count.index]
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this["web"].id]
  iam_instance_profile         = aws_iam_instance_profile.this["web"].name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  tags = { Name = "web-${count.index + 1}" }
}

resource "aws_instance" "app" {
  count                       = 2
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnets[count.index]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [aws_security_group.this["app"].id]
  iam_instance_profile         = aws_iam_instance_profile.this["app"].name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  tags = { Name = "app-${count.index + 1}" }
}