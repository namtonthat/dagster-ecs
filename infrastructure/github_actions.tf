# GitHub Actions OIDC Provider and IAM Role
# This allows GitHub Actions to deploy DAGs to EFS without long-lived credentials

# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (this is stable)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-github-oidc"
  })
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_deploy" {
  name = "${local.name_prefix}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Update these variables in terraform.tfvars
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-github-actions-role"
  })
}

# Policy for GitHub Actions to deploy DAGs
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "deploy-dags-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EFS permissions
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = aws_efs_file_system.dagster_workspace.arn
      },
      # EFS mount helper needs to describe mount targets
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = "*"
      },
      # S3 permissions for archival
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dagster.arn,
          "${aws_s3_bucket.dagster.arn}/archive/*"
        ]
      },
      # SSM Parameter access
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.efs_id.arn,
          aws_ssm_parameter.s3_bucket_name.arn
        ]
      },
      # ECS service update permissions
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.dagster_fargate.name}/*"
        ]
      },
      # EC2 permissions for EFS mounting
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policy for basic ECS operations
resource "aws_iam_role_policy_attachment" "github_actions_ecs" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}