terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    bucket         = "cred-devops-tf-state"
    key            = "cred-devops-pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cred-devops-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
