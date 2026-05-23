terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# tfstate 保存用 S3 バケット
resource "aws_s3_bucket" "tfstate" {
  bucket = "portfolio-tfstate-508251566134"

  # 誤って terraform destroy しても消えないよう保護
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "portfolio-tfstate"
    Project = "portfolio"
    Purpose = "Terraform remote state"
  }
}

# バージョニング：誤 apply 時に state をロールバック可能にする
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# パブリックアクセス完全ブロック
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB テーブル：同時 apply による state 破損を防ぐ排他ロック
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "portfolio-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "portfolio-tfstate-lock"
    Project = "portfolio"
    Purpose = "Terraform state locking"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.tfstate_lock.name
}
