output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "パブリックサブネットのID"
  value       = aws_subnet.public.id
}

output "ec2_public_ip" {
  description = "EC2の固定IPアドレス（Elastic IP）"
  value       = aws_eip.web.public_ip
}

output "site_url" {
  description = "サイトURL（HTTPSはhttps_urlを参照）"
  value       = "https://${var.domain_name}"
}

output "ssm_command" {
  description = "SSM Session Manager でのEC2アクセスコマンド（SSH不要）"
  value       = "aws ssm start-session --target ${aws_instance.web.id}"
}

output "s3_bucket_name" {
  description = "ログ保存用S3バケット名"
  value       = aws_s3_bucket.logs.bucket
}

output "sns_topic_arn" {
  description = "アラート通知用SNSトピックARN"
  value       = aws_sns_topic.alerts.arn
}

output "instance_id" {
  description = "EC2インスタンスID"
  value       = aws_instance.web.id
}

output "nameservers" {
  description = "Route53ネームサーバー（ドメイン登録後にRoute53コンソールで確認・設定済みのはず）"
  value       = aws_route53_zone.main.name_servers
}

output "https_url" {
  description = "HTTPS URL（setup-ssl.sh実行後に有効）"
  value       = "https://${var.domain_name}"
}
