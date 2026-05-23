resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # HTTP：全員がWebサイトにアクセスできる（CertbotのHTTP-01チャレンジにも必要）
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS：SSL証明書取得後のメインアクセス
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # SSH(22)は削除済み：SSM Session Manager で代替（インバウンドポート開放不要）

  # アウトバウンド：全通信を許可（パッケージ取得・SSM・ログ送信に必要）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
  }
}
