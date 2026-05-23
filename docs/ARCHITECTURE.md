# アーキテクチャ設計判断記録

構成の「なぜ」を記録したドキュメント。
面接等で設計意図を説明できるようにまとめている。

---

## ネットワーク設計

### なぜデフォルトVPCを使わなかったか
デフォルトVPCはCIDRやサブネット構成が固定されており、設計意図が見えない。
自分でVPCを作ることで「ネットワークを理解して設計した」ことを証明できる。

### なぜ /16 のCIDRを選んだか
- `/16` = 65,536 IPアドレス
- 実際に使うのは `/24`（256個）のサブネット1つだが、将来の拡張を考慮
- 将来 DB 等を追加する場合もサブネットを余裕を持って切り出せる

### なぜプライベートサブネットを作らなかったか
このポートフォリオは静的HTMLを配信するだけのサイトであり、DBやバックエンドが存在しない。
プライベートサブネットはその中に置くリソース（RDS等）があって初めて意味を持つ。
「将来のために」作るだけの空のサブネットは設計上の意図がなく、採用しなかった。

---

## セキュリティ設計

### なぜSSHではなくSSM Session Managerを使うか
SSHはインバウンドのポート22開放が必要で、以下のリスクがある。
- IP制限をしても接続元IPが変わるたびに `terraform apply` が必要
- 鍵ファイルの管理・紛失リスク
- ポートスキャンによるブルートフォース攻撃の対象になる

SSM Session Managerは：
- EC2からAWSへのアウトバウンドHTTPSのみで動作（インバウンドポート開放不要）
- IAM認証のみでアクセス制御（鍵ファイル不要）
- セッションログをCloudWatch/S3に記録できる

```
SSH:  自分のPC → (port 22 open) → EC2
SSM:  自分のPC → SSM Endpoint → EC2（EC2側からの outbound HTTPS）
```

### IAM Roleを使ってアクセスキーをEC2に持たせなかった理由
- EC2にアクセスキーを直接配置すると、サーバー侵害時にキーも盗まれる
- IAM Roleはトークンを一時的に発行する仕組みのため、キー流出リスクがない
- AWSのベストプラクティスに準拠

### IMDSv2を強制した理由（`http_tokens = "required"`）
IMDSv1はSSRF攻撃によりEC2のメタデータ（IAMトークンを含む）が盗まれるリスクがある。
IMDSv2はPUTリクエストでトークンを取得してからメタデータにアクセスする2段階方式のため、
単純なSSRF攻撃では悪用できない。

### なぜALBを使わなかったか
ALBの主な用途はスケールアウト（複数EC2への負荷分散）とヘルスチェックである。
このサイトは静的HTMLを配信するだけで、スケールアウトの要件がない。
実際のトラフィックに対して過剰な構成になるため採用しなかった（約$16/月のコストも不釣り合い）。

---

## CI/CD 設計

### なぜGitHub ActionsにOIDCを使うか
長期クレデンシャル（`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）をGitHub Secretsに
保存する方式には以下のリスクがある。
- キーのローテーションを忘れると永続的に有効なまま残る
- Secretsが漏洩した場合の影響範囲が広い

OIDCを使うと：
- GitHub Actionsのワークフロー実行ごとに一時的なトークンを発行
- IAM RoleのAssumeRoleWithWebIdentityで権限を取得（長期キー不要）
- `repo:Daichi-Kubota/aws-infra-portfolio:*` の条件でこのリポジトリのみに制限

```
GitHub Actions → OIDC Token → AssumeRoleWithWebIdentity → 一時クレデンシャル（15分）
```

### なぜTerraform StateをS3で管理するか
ローカルにtfstateを置くと以下の問題が生じる。
- 複数人が同時に `terraform apply` するとstateが壊れる
- `git commit` してしまうとリソースIDやIPなどの情報がリポジトリに残る

S3 remote backend + use_lockfileを使うことで：
- stateをチームで共有できる
- 同時apply時のロックで破損を防ぐ
- バージョニングで誤apply時にstateをロールバックできる

### なぜbackend-bootstrapを分離したか
tfstateを保管するS3バケット自体をTerraformで管理すると鶏と卵の問題が起きる
（S3バケットを作るためのstateをどこに置くか）。
backend-bootstrap/ を独立したTerraformプロジェクトとして分離することで：
- メインの `terraform destroy` でS3バケットが消えない
- `prevent_destroy = true` で誤削除を防止

---

## 監視・監査設計

### VPC Flow LogsとCloudTrailの使い分け

```
VPC Flow Logs = ネットワーク通信の記録（パケットレベル）
  「203.0.113.1からポート22への接続試行がREJECTされた」

CloudTrail = AWS API操作の記録（アクションレベル）
  「IAMユーザーXがEC2をStopInstancesした」
```

セキュリティインシデントが発生した場合：
1. CloudTrailで「何の操作が行われたか」を確認
2. VPC Flow Logsで「どこからどこへの通信があったか」を確認

両方を組み合わせることで原因の特定と影響範囲の把握ができる。

### CloudWatch Agentを入れた理由
- EC2のローカルログはインスタンス停止・削除で消える
- CloudWatch Logsに集約することで、EC2が消えてもログが残る

### S3のライフサイクルを90日に設定した理由
- 無期限保存するとコストが増加し続ける
- 障害調査で必要なログの参照期間は実務的に30〜90日が多い
- コストと実用性のバランスを取った判断

### なぜCloudTrailのログファイル検証を有効にしたか（`enable_log_file_validation = true`）
ログファイルの改ざんを検知するためのハッシュチェーンを生成する。
セキュリティインシデント後にログを証拠として使う場合、
「ログが改ざんされていないこと」を証明できることが重要。

---

## コスト設計

### なぜNAT Gatewayを使わなかったか
NAT Gatewayは約$32/月かかる。プライベートサブネットにEC2を置く場合、
インターネットアクセス（パッケージ取得・CloudWatch送信等）にNAT Gatewayが必要になる。
このサイトにはプライベートリソースがないため、NAT Gatewayを使う構成を採用しなかった。

### EC2を停止してコストを抑制する理由
t3.microは無料枠（750時間/月）内だが、ElasticIPは未割り当て時に課金される。
不使用時は `scripts/stop-ec2.sh` でEC2を停止しながらElasticIPを維持することで、
IPアドレスを固定したままコストを抑えている。
