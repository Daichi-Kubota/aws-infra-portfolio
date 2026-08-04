# Nginxログを収集するロググループ
resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/${var.project_name}/nginx/access"
  retention_in_days = 30 # 30日でログ自動削除

  tags = {
    Name    = "${var.project_name}-nginx-access-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/${var.project_name}/nginx/error"
  retention_in_days = 30

  tags = {
    Name    = "${var.project_name}-nginx-error-logs"
    Project = var.project_name
  }
}

# SNSトピック：アラート発火時のメール送信先
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name    = "${var.project_name}-alerts"
    Project = var.project_name
  }
}

# メールアドレスをSNSに登録（登録後に確認メールが届く）
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CPU使用率が80%超過で5分間継続したらアラート発火
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name                = "${var.project_name}-cpu-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2 # 2回連続で閾値超過したら発火
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 300 # 5分間隔で測定
  statistic                 = "Average"
  threshold                 = 80 # 80%が閾値
  alarm_description         = "CPU使用率が80%を超えました"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                = [aws_sns_topic.alerts.arn] # 回復時も通知
  insufficient_data_actions = [aws_sns_topic.alerts.arn] # EC2停止中などデータ欠損時も通知

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Name    = "${var.project_name}-cpu-alarm"
    Project = var.project_name
  }
}

# ディスク使用率が85%超過したらアラート発火
# CloudWatch Agent がカスタムメトリクスとして送信する
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project_name}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ディスク使用率が85%を超えました（ログ肥大化の可能性）"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.web.id
    path       = "/"
    device     = "nvme0n1p1"
    fstype     = "xfs"
  }

  tags = {
    Name    = "${var.project_name}-disk-alarm"
    Project = var.project_name
  }
}

# Route53 ヘルスチェック：外形監視（サイトが応答するか確認）
# HTTP(80)を見る理由はコスト：HTTPS指定は「オプション機能」扱いで月$1.00かかり、
# さらに200応答だと本文3,868バイトを30秒ごとに全チェッカーリージョンへ送るため
# リージョン間データ転送が月$0.59発生していた。80番はHTTPSへの301（169バイト）を返し、
# Route53は3xxを正常と判定するため、ダウン検知は維持したまま両方の課金が消える。
# 証明書の期限切れ検知が必要になったら type="HTTPS" / port=443 に戻す（月$1.6）。
resource "aws_route53_health_check" "web" {
  fqdn              = var.domain_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3  # 3回連続失敗でアラート
  request_interval  = 30 # 30秒ごとにチェック

  tags = {
    Name    = "${var.project_name}-health-check"
    Project = var.project_name
  }
}

# ヘルスチェック失敗時にSNS通知（us-east-1固定：Route53の仕様）
resource "aws_cloudwatch_metric_alarm" "health_check" {
  provider            = aws.us_east_1
  alarm_name          = "${var.project_name}-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "サイトが応答していません（外形監視）"
  alarm_actions       = [aws_sns_topic.alerts_us_east_1.arn]
  ok_actions          = [aws_sns_topic.alerts_us_east_1.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.web.id
  }

  tags = {
    Name    = "${var.project_name}-health-check-alarm"
    Project = var.project_name
  }
}

# Route53ヘルスチェックのアラームはus-east-1に作る必要がある（AWSの仕様）
resource "aws_sns_topic" "alerts_us_east_1" {
  provider = aws.us_east_1
  name     = "${var.project_name}-alerts-us-east-1"

  tags = {
    Name    = "${var.project_name}-alerts-us-east-1"
    Project = var.project_name
  }
}

resource "aws_sns_topic_subscription" "email_us_east_1" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alerts_us_east_1.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
