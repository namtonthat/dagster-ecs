terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Backend configuration will be provided via backend config file or CLI
    # bucket = "your-tfstate-bucket"
    # key    = "terraform.tfstate"  
    # region = "ap-southeast-2"
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "dagster-ecs"
  
  tags = {
    Project     = "dagster-ecs-fargate"
    ManagedBy   = "opentofu"
  }
}