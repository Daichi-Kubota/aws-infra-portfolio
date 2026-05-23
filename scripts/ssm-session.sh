#!/bin/bash
# SSM Session Manager でEC2にアクセスするスクリプト
# SSH(22番ポート)不要・IAM認証のみでセキュアにアクセス可能
#
# 前提: aws-session-manager-plugin のインストールが必要
#   macOS: brew install --cask session-manager-plugin
#   確認:  session-manager-plugin --version
#
# 使い方: bash scripts/ssm-session.sh

set -euo pipefail

TERRAFORM_DIR="$(dirname "$0")/../terraform"

INSTANCE_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw instance_id)
echo "接続先: $INSTANCE_ID"
echo "aws ssm start-session --target $INSTANCE_ID"
aws ssm start-session --target "$INSTANCE_ID"
