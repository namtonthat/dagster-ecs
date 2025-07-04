# SSM Parameters for GitHub Actions and other automation tools
# These parameters store infrastructure values that GitHub Actions needs

resource "aws_ssm_parameter" "efs_id" {
  name        = "/dagster/efs-id"
  description = "EFS file system ID for Dagster workspace"
  type        = "String"
  value       = aws_efs_file_system.dagster_workspace.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-id-param"
  })
}

resource "aws_ssm_parameter" "s3_bucket_name" {
  name        = "/dagster/s3-bucket-name"
  description = "S3 bucket name for Dagster storage and archives"
  type        = "String"
  value       = aws_s3_bucket.dagster.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-s3-bucket-param"
  })
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name        = "/dagster/ecs-cluster-name"
  description = "ECS cluster name for Dagster"
  type        = "String"
  value       = aws_ecs_cluster.dagster_fargate.name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-cluster-param"
  })
}