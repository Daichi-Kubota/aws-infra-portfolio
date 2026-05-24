terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform制約: backendブロック内では変数・data参照が使えないためハードコード
  # https://developer.hashicorp.com/terraform/language/settings/backends/configuration
  backend "s3" {
    bucket       = "portfolio-tfstate-508251566134"
    key          = "portfolio/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Route53ヘルスチェックのCloudWatchアラームはus-east-1に作る必要がある（AWSの仕様）
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# 現在のAWSアカウント情報（account_id）を全tfファイルで共有
data "aws_caller_identity" "current" {}
