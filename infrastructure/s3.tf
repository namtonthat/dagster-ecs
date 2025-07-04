resource "aws_s3_bucket" "dagster" {
  bucket = var.s3_bucket_name
  tags   = local.tags
}


resource "aws_s3_bucket_versioning" "dagster" {
  bucket = aws_s3_bucket.dagster.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dagster" {
  bucket = aws_s3_bucket.dagster.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dagster" {
  bucket = aws_s3_bucket.dagster.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for DAG backups from EFS
resource "aws_s3_bucket" "dagster_dags_backup" {
  bucket = "${var.s3_bucket_name}-dags-backup"

  tags = merge(local.tags, {
    Name    = "${local.name_prefix}-dags-backup"
    Purpose = "Backup of DAGs from EFS for reference"
  })
}

# Enable versioning on backup bucket
resource "aws_s3_bucket_versioning" "dagster_dags_backup" {
  bucket = aws_s3_bucket.dagster_dags_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policy for backup bucket
resource "aws_s3_bucket_lifecycle_configuration" "dagster_dags_backup" {
  bucket = aws_s3_bucket.dagster_dags_backup.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
  }
}

# Block public access for backup bucket
resource "aws_s3_bucket_public_access_block" "dagster_dags_backup" {
  bucket = aws_s3_bucket.dagster_dags_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

