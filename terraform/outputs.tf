output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.app.domain_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name for GitHub Actions deploy"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name for GitHub Actions deploy"
  value       = aws_ecs_service.app.name
}

output "rds_endpoint" {
  value = aws_db_instance.app.endpoint
}
