resource "aws_secretsmanager_secret" "ghcr" {
  name        = "${var.project_name}-ghcr-credentials"
  description = "GitHub Container Registry credentials for ECS to pull private images"
}

resource "aws_secretsmanager_secret_version" "ghcr" {
  secret_id = aws_secretsmanager_secret.ghcr.id
  secret_string = jsonencode({
    username = var.ghcr_username
    password = var.ghcr_pat
  })
}

output "ghcr_secret_arn" {
  description = "ARN of the GHCR credentials secret"
  value       = aws_secretsmanager_secret.ghcr.arn
}
