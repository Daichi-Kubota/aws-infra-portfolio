# ホストゾーン：ドメインのDNS管理をRoute53で行う
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name    = "${var.project_name}-zone"
    Project = var.project_name
  }
}

# Aレコード：ドメイン → Elastic IP
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}

# www サブドメインも同じIPへ
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}
