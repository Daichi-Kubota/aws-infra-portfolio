#!/bin/bash
# EC2を起動してIPアドレスを表示する

INSTANCE_ID="i-01fb866acd827a577"
REGION="ap-northeast-1"

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
echo "URL: http://$PUBLIC_IP"
echo "SSH: ssh -i ~/.ssh/portfolio-key ec2-user@$PUBLIC_IP"
