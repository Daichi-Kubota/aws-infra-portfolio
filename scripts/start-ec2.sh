#!/bin/bash
# EC2を起動してIPアドレスを表示する

PROJECT_NAME="portfolio"
REGION="ap-northeast-1"

# タグからインスタンスIDを動的取得（ハードコードしない）
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=$PROJECT_NAME" \
    "Name=instance-state-name,Values=stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --region "$REGION" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "停止中のインスタンスが見つかりません（既に起動中の可能性があります）"
  exit 1
fi

echo "EC2を起動します: $INSTANCE_ID"
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "起動完了を待っています..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "起動完了"
echo "URL: https://infra-portfolio.dev"
echo "SSM: aws ssm start-session --target $INSTANCE_ID"
