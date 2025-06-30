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

