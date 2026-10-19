terraform {
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