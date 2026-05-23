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

  # 起動時に自動実行されるスクリプト（Docker + Nginx + CloudWatch Agent）
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y amazon-cloudwatch-agent git docker

    # Docker 起動・永続化
    systemctl start docker
    systemctl enable docker

    # docker compose v2 plugin インストール
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # CloudWatch Agent が読むログディレクトリを作成
    mkdir -p /var/log/docker-nginx

    # リポジトリをクローンして Docker コンテナ起動（port 8080 で待機）
    git clone https://github.com/Daichi-Kubota/aws-infra-portfolio.git /opt/portfolio
    cd /opt/portfolio
    docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

    # Host nginx：SSL 終端 + Docker コンテナへのリバースプロキシ
    # セキュリティヘッダーはコンテナ内の nginx.conf が設定するため、ここでは不要
    dnf install -y nginx

    cat > /etc/nginx/conf.d/portfolio.conf << 'PROXYCONF'
server {
    listen 80 default_server;
    server_name _;
    server_tokens off;

    location / {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
PROXYCONF

    # Amazon Linux 2023のnginx.confにある既定のサーバーブロックを削除（競合防止）
    sed -i '37,53d' /etc/nginx/nginx.conf

    systemctl start nginx
    systemctl enable nginx

    # CloudWatch Agent：Docker コンテナの Nginx ログ（ホストにマウント済み）を収集
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/docker-nginx/access.log",
                "log_group_name": "/${var.project_name}/nginx/access",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/docker-nginx/error.log",
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
