# IAM User for S3 access (separate from ECS task role)
resource "aws_iam_user" "dagster_s3_user" {
  name = "${local.name_prefix}-s3-user"
  path = "/"

  tags = local.tags
}

# IAM policy for S3 access
resource "aws_iam_policy" "dagster_s3_policy" {
  name        = "${local.name_prefix}-s3-policy"
  path        = "/"
  description = "Policy for Dagster S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.dagster.arn,
          "${aws_s3_bucket.dagster.arn}/*"
        ]
      }
    ]
  })

  tags = local.tags
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "dagster_s3_user_policy" {
  user       = aws_iam_user.dagster_s3_user.name
  policy_arn = aws_iam_policy.dagster_s3_policy.arn
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

# Output the secret ARN for ECS task definition
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