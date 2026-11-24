resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "three-tier-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "three-tier-igw"
  }
}

resource "aws_subnet" "public-a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "three-tier-public-subnet-a"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "three-tier-public-subnet-b"
  }
}

resource "aws_subnet" "app-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az_a

  tags = {
    Name = "three-tier-app-subnet-a"
  }
}

resource "aws_subnet" "app-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az_b

  tags = {
    Name = "three-tier-app-subnet-b"
  }
}

resource "aws_subnet" "db-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az_a

  tags = {
    Name = "three-tier-db-subnet-a"
  }
}

resource "aws_subnet" "db-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = var.az_b

  tags = {
    Name = "three-tier-db-subnet-b"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "three-tier-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-a.id

  tags = {
    Name = "gw NAT"
  }

  depends_on = [aws_internet_gateway.main]
}

