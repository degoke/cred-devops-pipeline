resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-${local.environment}-db-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

locals {
  db_connection_url = "postgres://${var.db_username}:${random_password.db.result}@${aws_db_instance.app.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_secretsmanager_secret" "db_connection" {
  name                    = "${var.project_name}-${local.environment}-db-connection-url"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_connection" {
  secret_id     = aws_secretsmanager_secret.db_connection.id
  secret_string = local.db_connection_url
}

