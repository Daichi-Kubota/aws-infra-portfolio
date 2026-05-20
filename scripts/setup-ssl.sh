#!/bin/bash
# HTTPS化スクリプト
# 実行タイミング: ドメイン取得＆terraform apply完了後、DNSが浸透してから実行
# 使い方: bash scripts/setup-ssl.sh

set -euo pipefail

DOMAIN="infra-portfolio.dev"
EMAIL="fcl37881@gmail.com"
KEY="$HOME/.ssh/portfolio-key"
TERRAFORM_DIR="$(dirname "$0")/../terraform"

echo "=== SSL証明書セットアップ開始 ==="

# EC2のIPをterraform outputから取得
EC2_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw ec2_public_ip)
echo "→ EC2 IP: $EC2_IP"
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

SSH_CMD="ssh -i $KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP"

echo ""
echo "=== 1. Certbot インストール ==="
$SSH_CMD "sudo python3 -m venv /opt/certbot && \
  sudo /opt/certbot/bin/pip install -q --upgrade pip && \
  sudo /opt/certbot/bin/pip install -q certbot certbot-nginx && \
  sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot && \
  certbot --version"

echo ""
echo "=== 2. Nginx server_name 設定 ==="
$SSH_CMD "sudo sed -i 's/server_name  _;/server_name $DOMAIN www.$DOMAIN;/' /etc/nginx/nginx.conf && \
  sudo nginx -t && sudo systemctl reload nginx"

echo ""
echo "=== 3. SSL証明書取得（Let's Encrypt）==="
$SSH_CMD "sudo certbot --nginx \
  -d $DOMAIN -d www.$DOMAIN \
  --non-interactive --agree-tos \
  --email $EMAIL \
  --redirect"

echo ""
echo "=== 4. 自動更新 cron 設定 ==="
$SSH_CMD "echo '0 0,12 * * * root certbot renew -q' | sudo tee /etc/cron.d/certbot-renew > /dev/null"

echo ""
echo "✅ 完了！"
echo "   https://$DOMAIN を開いて確認してください"
