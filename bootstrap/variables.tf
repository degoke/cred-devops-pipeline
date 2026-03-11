variable "aws_region" {
  description = "AWS region to deploy bootstrap resources into"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform remote state"
  type        = string
  default     = "cred-devops-tf-state"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "cred-devops-tf-locks"
}

variable "project_name" {
  description = "Project name prefix (used for OIDC role name)"
  type        = string
  default     = "cred-devops-pipeline"
}

variable "github_repository" {
  description = "GitHub owner/repo for OIDC trust (e.g. myorg/my-repo)"
  type        = string
  default     = "degoke/cred-devops-pipeline"
}

variable "ghcr_username" {
  description = "GitHub username for pulling images from GHCR"
  type        = string
}

variable "ghcr_pat" {
  description = "GitHub Personal Access Token with read:packages scope"
  type        = string
  sensitive   = true
}

