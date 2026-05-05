# SSH公開鍵をAWSに登録
resource "aws_key_pair" "portfolio" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/portfolio-key.pub")

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

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

# S3への書き込み権限をアタッチ
resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
  instance_type          = "t3.micro"  # 無料枠対象
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.portfolio.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # 起動時に自動実行されるスクリプト（Nginxインストール）
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
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
  EOF

  tags = {
    Name    = "${var.project_name}-web-server"
    Project = var.project_name
  }
}
