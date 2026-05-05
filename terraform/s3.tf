resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project_name}-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true  # terraform destroy時にバケットごと削除できるようにする

  tags = {
    Name    = "${var.project_name}-logs"
    Project = var.project_name
  }
}

# バケットへのパブリックアクセスを完全ブロック（セキュリティ必須設定）
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ライフサイクル設定：90日後に自動削除してコストを抑制
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}  # 全オブジェクトを対象

    expiration {
      days = 90
    }
  }
}

# 現在のAWSアカウント情報を取得（バケット名の一意性確保に使用）
data "aws_caller_identity" "current" {}
