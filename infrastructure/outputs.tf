output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL of the Dagster webserver"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.dagster.repository_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.dagster.endpoint
}

# S3 and IAM outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Dagster storage"
  value       = aws_s3_bucket.dagster.bucket
}


# ECS outputs
output "efs_file_system_id" {
  description = "EFS file system ID for DAGs"
  value       = aws_efs_file_system.dagster_dags.id
}

output "ecs_cluster_name" {
  description = "ECS Fargate cluster name"
  value       = aws_ecs_cluster.dagster_fargate.name
}

output "ecs_service_name" {
  description = "ECS Fargate service name"
  value       = aws_ecs_service.dagster_fargate.name
}
