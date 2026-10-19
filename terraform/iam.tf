data "aws_caller_identity" "current" {}

locals {
  roles = ["jenkins", "web", "app", "monitoring"]
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each           = toset(local.roles)
  name               = "three-tier-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_instance_profile" "this" {
  for_each = aws_iam_role.this
  name     = "three-tier-${each.key}-profile"
  role     = each.value.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each   = aws_iam_role.this
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------- Jenkins: push image ----------
data "aws_iam_policy_document" "jenkins" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeRepositories",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

# ---------- Web VM: pull image web ----------
data "aws_iam_policy_document" "web" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.this["three-tier-web"].arn]
  }
}

# ---------- App VM: pull image app + đọc secret DB ----------
data "aws_iam_policy_document" "app" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.this["three-tier-app"].arn]
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "inline" {
  for_each = {
    jenkins = data.aws_iam_policy_document.jenkins.json
    web     = data.aws_iam_policy_document.web.json
    app     = data.aws_iam_policy_document.app.json
  }
  name   = "three-tier-${each.key}-access"
  role   = aws_iam_role.this[each.key].id
  policy = each.value
}