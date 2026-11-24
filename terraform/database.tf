resource "aws_db_subnet_group" "main" {
  name       = "three-tier-db-subnets"
  subnet_ids = [aws_subnet.db-a.id, aws_subnet.db-b.id]

  tags = {
    Name = "three-tier-db-subnets"
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "three-tier-db"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  database_name      = "webappdb"
  master_username    = "admin"
  master_password    = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  storage_encrypted       = true
  backup_retention_period = 1

  deletion_protection = false
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "three-tier-db-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false
}
