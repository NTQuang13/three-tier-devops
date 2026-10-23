terraform {

  backend "s3" {
    bucket       = "three-tier-tfstate-410244642625"
    key          = "three-tier/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.67.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}

provider "aws" {
  region = var.region
}