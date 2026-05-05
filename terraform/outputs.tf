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
  description = "サイトURL"
  value       = "http://${aws_eip.web.public_ip}"
}

output "ssh_command" {
  description = "SSH接続コマンド"
  value       = "ssh -i ~/.ssh/portfolio-key ec2-user@${aws_eip.web.public_ip}"
}

output "s3_bucket_name" {
  description = "ログ保存用S3バケット名"
  value       = aws_s3_bucket.logs.bucket
}

output "sns_topic_arn" {
  description = "アラート通知用SNSトピックARN"
  value       = aws_sns_topic.alerts.arn
}
