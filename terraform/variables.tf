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

variable "my_ip" {
  description = "SSH接続を許可する自分のIPアドレス（例: 203.0.113.1/32）"
  type        = string
}

variable "alert_email" {
  description = "CloudWatchアラートの通知先メールアドレス"
  type        = string
  default     = "fcl37881@gmail.com"
}
