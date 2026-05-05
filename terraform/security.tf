resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # HTTP：全員がWebサイトにアクセスできる
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # SSH：自分のIPのみ接続可能（セキュリティ最小権限の原則）
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH from my IP only"
  }

  # アウトバウンド：全通信を許可（パッケージ取得・ログ送信に必要）
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
