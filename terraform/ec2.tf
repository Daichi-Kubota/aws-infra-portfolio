# IAM Role：EC2がCloudWatch・S3にアクセスするための「社員証」
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  # EC2サービスがこのロールを引き受けることを許可
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

# CloudWatchへのログ送信権限をアタッチ
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM Session Manager：SSH不要でEC2にセキュアアクセスするために必要
# AmazonSSMManagedInstanceCore = SSM Agent がAWSと通信するための最小権限
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3：ログバケット内のnginxパスへのPutObjectのみ許可（最小権限の原則）
resource "aws_iam_role_policy" "s3_logs" {
  name = "${var.project_name}-s3-logs-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.logs.arn}/nginx/*"
    }]
  })
}

# Instance Profile：IAM RoleをEC2に紐付けるための中間層
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Amazon Linux 2023の最新AMI IDを自動取得
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2インスタンス本体
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro" # 無料枠対象
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # 起動時に自動実行されるスクリプト（Nginx + CloudWatch Agent インストール）
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx amazon-cloudwatch-agent
    systemctl start nginx
    systemctl enable nginx

    # ポートフォリオ用のHTMLページを作成
    cat > /usr/share/nginx/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Portfolio - AWS Infra</title>
      <style>
        body { font-family: sans-serif; background: #0d1117; color: #c9d1d9; text-align: center; padding: 50px; }
        h1 { color: #58a6ff; }
        p { color: #8b949e; }
      </style>
    </head>
    <body>
      <h1>AWS Infrastructure Portfolio</h1>
      <p>Daichi Kubota</p>
      <p>EC2 + Nginx + VPC + Terraform</p>
    </body>
    </html>
    HTML

    # CloudWatch AgentにNginxログの収集先を設定
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/nginx/access.log",
                "log_group_name": "/${var.project_name}/nginx/access",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "/${var.project_name}/nginx/error",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s
  EOF

  # IMDSv2を強制：SSRF攻撃によるメタデータ窃取を防ぐ
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.project_name}-web-server"
    Project = var.project_name
  }
}

# Elastic IP：EC2停止・再起動後もIPが変わらないように固定
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}
