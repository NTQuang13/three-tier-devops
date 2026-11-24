resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "three-tier-public-rt"
  }
}

resource "aws_route" "public-internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-b" {
  subnet_id      = aws_subnet.public-b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "three-tier-private-rt"
  }
}

resource "aws_route" "private-nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "app-a" {
  subnet_id      = aws_subnet.app-a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app-b" {
  subnet_id      = aws_subnet.app-b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db-a" {
  subnet_id      = aws_subnet.db-a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db-b" {
  subnet_id      = aws_subnet.db-b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = {
    Name = "three-tier-s3-endpoint"
  }
}
