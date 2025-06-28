terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "dagster-${var.environment}"
  
  tags = {
    Project     = "dagster-ecs"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
}