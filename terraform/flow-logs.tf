# VPC Flow Logs：VPCを通る全トラフィックを記録（不審な通信の検知・調査に使用）

# ログの保存先
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/${var.project_name}/vpc/flow-logs"
  retention_in_days = 30

  tags = {
    Name    = "${var.project_name}-flow-logs"
    Project = var.project_name
  }
}

# Flow LogsがCloudWatch Logsに書き込むためのIAM Role
resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-flow-logs-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

# VPC Flow Log 本体
# ALL = ACCEPT（正常通信）と REJECT（ブロックされた通信）の両方を記録
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = {
    Name    = "${var.project_name}-flow-log"
    Project = var.project_name
  }
}
