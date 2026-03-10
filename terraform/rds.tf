resource "aws_db_subnet_group" "app" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_instance" "app" {
  identifier              = "${var.project_name}-db"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.app.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  username                = var.db_username
  password                = random_password.db.value
  db_name                 = var.db_name
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 7

  tags = {
    Name = "${var.project_name}-db"
  }
}
