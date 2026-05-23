variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string
  default     = "portfolio"
}

variable "vpc_cidr" {
  description = "VPCのIPアドレス範囲"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "パブリックサブネットのIPアドレス範囲"
  type        = string
  default     = "10.0.1.0/24"
}

variable "alert_email" {
  description = "CloudWatchアラートの通知先メールアドレス"
  type        = string
}

variable "domain_name" {
  description = "取得したドメイン名（例: infra-portfolio.dev）"
  type        = string
  default     = "infra-portfolio.dev"
}

variable "ssh_public_key" {
  description = "EC2に登録するSSH公開鍵（CI環境ではSecretから渡す）"
  type        = string
  default     = ""
}
