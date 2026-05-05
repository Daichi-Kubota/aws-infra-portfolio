#!/bin/bash
# NginxログをS3にバックアップする（EC2上で実行するスクリプト）
# crontabに登録する場合: 0 0 * * * /home/ec2-user/backup-logs.sh

BUCKET="portfolio-logs-508251566134"
DATE=$(date +%Y-%m-%d)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "[$DATE] ログバックアップ開始"

aws s3 cp /var/log/nginx/access.log \
  "s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/access.log"

aws s3 cp /var/log/nginx/error.log \
  "s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/error.log"

echo "[$DATE] バックアップ完了: s3://$BUCKET/nginx/$INSTANCE_ID/$DATE/"
