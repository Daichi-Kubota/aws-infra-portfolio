#!/bin/bash
# 使い終わったらこのスクリプトを実行してEC2を停止する（課金停止）
# 再開: ./start-ec2.sh

INSTANCE_ID="i-01fb866acd827a577"
REGION="ap-northeast-1"

echo "EC2を停止します: $INSTANCE_ID"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "停止完了を待っています..."
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "停止完了"
