#!/bin/bash
# 使い終わったらこのスクリプトを実行してEC2を停止する（課金停止）
# 再開: ./start-ec2.sh

PROJECT_NAME="portfolio"
REGION="ap-northeast-1"

# タグからインスタンスIDを動的取得（ハードコードしない）
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=$PROJECT_NAME" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --region "$REGION" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "起動中のインスタンスが見つかりません（既に停止中の可能性があります）"
  exit 1
fi

echo "EC2を停止します: $INSTANCE_ID"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "停止完了を待っています..."
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "停止完了"
