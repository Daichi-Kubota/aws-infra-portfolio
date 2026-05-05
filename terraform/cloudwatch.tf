# Nginxログを収集するロググループ
resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/portfolio/nginx/access"
  retention_in_days = 30  # 30日でログ自動削除

  tags = {
    Name    = "${var.project_name}-nginx-access-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/portfolio/nginx/error"
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
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2      # 2回連続で閾値超過したら発火
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300    # 5分間隔で測定
  statistic           = "Average"
  threshold           = 80     # 80%が閾値
  alarm_description   = "CPU使用率が80%を超えました"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]  # 回復時も通知

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Name    = "${var.project_name}-cpu-alarm"
    Project = var.project_name
  }
}
