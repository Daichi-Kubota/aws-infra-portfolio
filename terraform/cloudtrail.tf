# CloudTrail：「誰が・いつ・何のAWS操作をしたか」を記録する監査ログ
# VPC Flow Logs（ネットワーク通信）と対になるAWS操作ログ

# CloudTrailログの保存先S3バケット
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-cloudtrail"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudTrailがS3に書き込むために必須のバケットポリシー
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail本体（管理イベント = IAM/EC2/S3等のAWS操作 → 最初の1トレイルは無料）
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true  # IAMなどグローバルサービスの操作も記録
  is_multi_region_trail         = false # 東京リージョンのみ（コスト最適化）
  enable_log_file_validation    = true  # ログ改ざん検知

  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = {
    Name    = "${var.project_name}-trail"
    Project = var.project_name
  }
}

output "cloudtrail_bucket" {
  description = "CloudTrailログ保存先S3バケット"
  value       = aws_s3_bucket.cloudtrail.bucket
}
