#!/bin/bash
# NginxログをS3にバックアップする（EC2上で実行するスクリプト）
# crontabに登録する場合: 0 0 * * * /home/ec2-user/backup-logs.sh

PROJECT_NAME="portfolio"
DATE=$(date +%Y-%m-%d)

# IMDSv2でインスタンスIDを取得
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/instance-id")

# AWSアカウントIDを動的取得（ハードコードしない）
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${PROJECT_NAME}-logs-${ACCOUNT_ID}"

echo "[$DATE] ログバックアップ開始"

aws s3 cp /var/log/nginx/access.log \
  "s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/access.log"

aws s3 cp /var/log/nginx/error.log \
  "s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/error.log"

echo "[$DATE] バックアップ完了: s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/"
