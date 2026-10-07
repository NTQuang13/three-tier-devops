resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "three-tier-aurora"
  engine                 = "aurora-mysql"
  database_name          = "webappdb"
  master_username        = "admin"
  master_password        = var.db_password
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.this["db"].id]
  skip_final_snapshot    = true
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = 2 # instance 0 = writer (primary), instance 1 = reader
  identifier         = "three-tier-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  instance_class     = "db.t3.medium"
  availability_zone  = local.azs[count.index]
}