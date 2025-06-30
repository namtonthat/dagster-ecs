variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dagster"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Dagster storage"
  type        = string
}

variable "dagster_auth_user" {
  description = "Username for Dagster basic authentication"
  type        = string
  default     = "admin"
}

variable "dagster_auth_password" {
  description = "Password for Dagster basic authentication"
  type        = string
  sensitive   = true
  # No default - must be provided via terraform.tfvars
}

