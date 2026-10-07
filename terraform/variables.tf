variable "region" {
  default = "us-east-1"
}

variable "my_ip_cidr" {
  description = "171.235.190.238/32"
}

variable "db_password" {
  sensitive = true
}

variable "public_key_path" {
  default = "~/Downloads/three-tier-key.pub"
}