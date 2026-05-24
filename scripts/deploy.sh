#!/bin/bash
set -e

INSTANCE_ID=$(cd terraform && terraform output -raw instance_id)

echo "=== デプロイ開始 ==="
echo "→ Instance ID: $INSTANCE_ID"

CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /opt/portfolio && git pull && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build 2>&1"]' \
  --output text --query 'Command.CommandId')

echo "→ Command ID: $CMD_ID"
echo "→ 完了確認: aws ssm get-command-invocation --command-id $CMD_ID --instance-id $INSTANCE_ID"
echo "=== デプロイ完了（反映まで1〜2分） ==="
