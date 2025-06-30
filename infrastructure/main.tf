terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration provided via environment variables:
    # TF_VAR_bucket, TF_VAR_key, TF_VAR_region
    # Or via -backend-config file
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "dagster-ecs"

  tags = {
    Project   = "dagster-ecs-fargate"
    ManagedBy = "opentofu"
  }
}