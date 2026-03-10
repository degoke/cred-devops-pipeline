output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "rds_endpoint" {
  value = aws_db_instance.app.endpoint
}

output "gha_oidc_role_arn" {
  value = aws_iam_role.gha_oidc.arn
}
