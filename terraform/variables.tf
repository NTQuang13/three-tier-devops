variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "az_a" {
  type    = string
  default = "ap-southeast-1a"
}

variable "az_b" {
  type    = string
  default = "ap-southeast-1b"
}

variable "bucket_name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}