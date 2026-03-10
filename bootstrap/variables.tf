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

