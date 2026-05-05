# トラブルシュート記録

構築中に発生した問題・原因・解決策のログ。

---

## #1 EC2インスタンスタイプエラー

**発生日:** 2026-05-05  
**エラーメッセージ:**
```
InvalidParameterCombination: The specified instance type is not eligible for Free Tier.
```

**原因:**  
新規AWSアカウントの無料プランでは `t2.micro` が対象外。

**調査手順:**
```bash
aws ec2 describe-instance-types \
  --filters "Name=free-tier-eligible,Values=true" \
  --query "InstanceTypes[].InstanceType"
```

**解決策:**  
`ec2.tf` の `instance_type` を `t2.micro` → `t3.micro` に変更。

**教訓:**  
AWSアカウントの種別（通常/無料プラン）によって無料枠対象インスタンスが異なる。

---

## #2 CloudWatch Agent タイムゾーンエラー

**発生日:** 2026-05-05  
**エラーメッセージ:**
```
logs.logs_collected.files.collect_list.0.timezone must be one of the following: "Local", "LOCAL", "UTC"
```

**原因:**  
設定ファイルに `"Asia/Tokyo"` を指定したが、CloudWatch Agentは `UTC` / `Local` のみ対応。

**解決策:**  
設定ファイルのtimezoneを `"UTC"` に変更して再起動。
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
```

**教訓:**  
設定前にAWS公式ドキュメントで許容値を確認する。

---

## #3 ブラウザからHTTPアクセスができない

**発生日:** 2026-05-05  
**症状:**  
`curl http://52.195.221.134` は200 OKなのにブラウザでタイムアウト。

**切り分け手順:**
1. curlで疎通確認 → OK（サーバー・SG側は問題なし）
2. SGのポート80ルール確認 → 0.0.0.0/0で開放済み
3. ブラウザのURLを確認 → `https://` になっていた

**原因:**  
ChromeがURLを自動的に `https://` にリダイレクトしていた。

**解決策:**  
アドレスバーに `http://52.195.221.134` と `http://` を明示入力。

**教訓:**  
「curlは通るのにブラウザは通らない」はHTTPS自動変換を疑う。
