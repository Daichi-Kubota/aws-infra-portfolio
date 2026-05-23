#!/bin/bash
# HTTPS化スクリプト（SSM Session Manager経由で実行）
# 実行タイミング: ドメイン取得＆terraform apply完了後、DNSが浸透してから実行
# 使い方: bash scripts/setup-ssl.sh

set -euo pipefail

DOMAIN="infra-portfolio.dev"
# メールアドレスは環境変数で渡す: CERTBOT_EMAIL=you@example.com bash scripts/setup-ssl.sh
EMAIL="${CERTBOT_EMAIL:?ERROR: CERTBOT_EMAIL 環境変数を設定してください（例: CERTBOT_EMAIL=you@example.com bash $0）}"
TERRAFORM_DIR="$(dirname "$0")/../terraform"

echo "=== SSL証明書セットアップ開始 ==="

# EC2の情報をterraform outputから取得
EC2_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw ec2_public_ip)
INSTANCE_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw instance_id)
echo "→ EC2 IP: $EC2_IP"
echo "→ Instance ID: $INSTANCE_ID"
echo "→ ドメイン: $DOMAIN"

# DNS浸透確認
echo ""
echo "=== DNS確認 ==="
RESOLVED_IP=$(dig +short "$DOMAIN" | tail -1)
if [ "$RESOLVED_IP" != "$EC2_IP" ]; then
  echo "⚠️  DNS未浸透: $DOMAIN → $RESOLVED_IP (期待値: $EC2_IP)"
  echo "   Route53のネームサーバーがドメインに設定されているか確認し、数分待ってから再実行してください"
  exit 1
fi
echo "✅ DNS確認OK: $DOMAIN → $EC2_IP"

# SSMでコマンドを送信する関数
run_ssm() {
  local comment="$1"
  local commands="$2"
  echo ""
  echo "=== $comment ==="
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$commands\"]" \
    --query "Command.CommandId" \
    --output text)
  echo "CommandId: $COMMAND_ID"
  aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID"
  aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "[StandardOutputContent, StandardErrorContent]" \
    --output text
}

run_ssm "1. Certbot インストール" \
  "python3 -m venv /opt/certbot && /opt/certbot/bin/pip install -q --upgrade pip && /opt/certbot/bin/pip install -q certbot certbot-nginx && ln -sf /opt/certbot/bin/certbot /usr/bin/certbot && certbot --version"

run_ssm "2. Nginx server_name 設定" \
  "sed -i 's/server_name  _;/server_name $DOMAIN www.$DOMAIN;/' /etc/nginx/nginx.conf && nginx -t && systemctl reload nginx"

run_ssm "3. SSL証明書取得（Let's Encrypt）" \
  "certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect"

run_ssm "4. 自動更新 systemd timer 設定" \
  "cat > /etc/systemd/system/certbot-renew.service << 'EOF'
[Unit]
Description=Certbot Renewal
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew -q
EOF
cat > /etc/systemd/system/certbot-renew.timer << 'EOF'
[Unit]
Description=Certbot Renewal Timer
[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload && systemctl enable --now certbot-renew.timer && systemctl list-timers certbot-renew.timer"

echo ""
echo "✅ 完了！"
echo "   https://$DOMAIN を開いて確認してください"
