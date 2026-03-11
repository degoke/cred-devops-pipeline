variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "cred-devops"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = [
    "10.0.11.0/24",
    "10.0.12.0/24",
  ]
}

variable "image_name" {
  description = "Base container image name"
  type        = string
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "cred-devops"
}


