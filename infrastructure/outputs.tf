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
  description = "EFS file system ID for workspace projects (new multi-repo)"
  value       = aws_efs_file_system.dagster_workspace.id
}

output "efs_dags_id" {
  description = "EFS file system ID for DAGs (legacy - now uses workspace)"
  value       = aws_efs_file_system.dagster_workspace.id
}

output "efs_workspace_projects_ap" {
  description = "EFS access point ID for workspace projects"
  value       = aws_efs_access_point.workspace_projects.id
}

output "efs_workspace_config_ap" {
  description = "EFS access point ID for workspace configuration"
  value       = aws_efs_access_point.workspace_config.id
}

output "ecs_cluster_name" {
  description = "ECS Fargate cluster name"
  value       = aws_ecs_cluster.dagster_fargate.name
}

output "ecs_service_name" {
  description = "ECS Fargate service name"
  value       = aws_ecs_service.dagster_fargate.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "dagster_access_note" {
  description = "Instructions for accessing Dagster web UI"
  value       = <<-EOT
    Dagster is accessible via the load balancer at:
    ${aws_lb.main.dns_name}
    
    Full URL: http://${aws_lb.main.dns_name}
  EOT
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (add as AWS_DEPLOY_ROLE_ARN secret)"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.dagster_workspace.dns_name
}
