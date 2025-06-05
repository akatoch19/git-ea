resource "aws_db_subnet_group" "gitea" {
  name        = "gitea-db-subnet-group"
  description = "Subnet group for Gitea RDS instance"
  subnet_ids  = module.vpc-gitea.private_subnets

  tags = {
    Name = "gitea-db-subnet-group"
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier          = "gitea-db"
  engine              = "postgres"
  engine_version      = "15.10"
  family             = "postgres15"
  instance_class      = "db.t3.medium"
  allocated_storage   = 20
  db_name             = "giteadb"
  username            = "gitea"
  password            = "giteapassword"
  publicly_accessible = false
  skip_final_snapshot = true

  db_subnet_group_name = aws_db_subnet_group.gitea.name
  vpc_security_group_ids = [aws_security_group.db.id]
}
