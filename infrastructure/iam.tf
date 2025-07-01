# IAM User for S3 access (separate from ECS task role)
resource "aws_iam_user" "dagster_s3_user" {
  name = "${local.name_prefix}-s3-user"
  path = "/"

  tags = local.tags
}

# Attach AWS managed policies to user for CI/CD operations
resource "aws_iam_user_policy_attachment" "dagster_s3_full_access" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user_policy_attachment" "dagster_ecr_full_access" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_user_policy_attachment" "dagster_ecs_full_access" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

# Custom policy for ECR authorization token (required for docker login)
resource "aws_iam_policy" "dagster_ecr_auth_token" {
  name        = "${local.name_prefix}-ecr-auth-token"
  path        = "/"
  description = "Policy to allow ECR authorization token retrieval"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Custom policy only for IAM PassRole (required for ECS task role passing)
resource "aws_iam_policy" "dagster_iam_pass_role" {
  name        = "${local.name_prefix}-iam-pass-role"
  path        = "/"
  description = "Policy to allow IAM role passing for ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${local.name_prefix}-*"
        ]
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "dagster_ecr_auth_token" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = aws_iam_policy.dagster_ecr_auth_token.arn
}

resource "aws_iam_user_policy_attachment" "dagster_iam_pass_role" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = aws_iam_policy.dagster_iam_pass_role.arn
}

# Create access keys for the user
resource "aws_iam_access_key" "dagster_s3_user_key" {
  user = aws_iam_user.dagster_s3_user.name
}

# Store credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "dagster_aws_credentials" {
  name                    = "${local.name_prefix}-aws-credentials"
  description             = "AWS credentials for Dagster S3 access"
  recovery_window_in_days = 7

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "dagster_aws_credentials" {
  secret_id = aws_secretsmanager_secret.dagster_aws_credentials.id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.dagster_s3_user_key.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.dagster_s3_user_key.secret
  })
}

# ECS IAM Roles and Policies
# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_fargate" {
  name = "${local.name_prefix}-ecs-task-execution-fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_fargate" {
  role       = aws_iam_role.ecs_task_execution_fargate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy to allow Secrets Manager access for execution role (needed for secrets retrieval)
resource "aws_iam_role_policy" "ecs_task_execution_fargate_secrets" {
  name = "${local.name_prefix}-ecs-task-execution-fargate-secrets"
  role = aws_iam_role.ecs_task_execution_fargate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.dagster_aws_credentials.arn
        ]
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_fargate" {
  name = "${local.name_prefix}-ecs-task-fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Policy to allow EFS access
resource "aws_iam_role_policy" "ecs_task_fargate_efs" {
  name = "${local.name_prefix}-ecs-task-fargate-efs"
  role = aws_iam_role.ecs_task_fargate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.dagster_workspace.arn
      }
    ]
  })
}

# Policy to allow Secrets Manager access for AWS credentials
resource "aws_iam_role_policy" "ecs_task_fargate_secrets" {
  name = "${local.name_prefix}-ecs-task-fargate-secrets"
  role = aws_iam_role.ecs_task_fargate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.dagster_aws_credentials.arn
        ]
      }
    ]
  })
}

# Policy to allow ECS task management for run launcher
resource "aws_iam_role_policy" "ecs_task_fargate_ecs_run_launcher" {
  name = "${local.name_prefix}-ecs-task-fargate-run-launcher"
  role = aws_iam_role.ecs_task_fargate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeClusters",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_fargate.arn,
          aws_iam_role.ecs_task_fargate.arn
        ]
      }
    ]
  })
}

# IAM Outputs
output "aws_credentials_secret_arn" {
  description = "ARN of the AWS credentials secret"
  value       = aws_secretsmanager_secret.dagster_aws_credentials.arn
}

output "aws_access_key_id" {
  description = "AWS Access Key ID for S3 access"
  value       = aws_iam_access_key.dagster_s3_user_key.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for S3 access"
  value       = aws_iam_access_key.dagster_s3_user_key.secret
  sensitive   = true
}

