# ---------------------------------------------------------------------------
# Route53: public hostname -> ALB (alias A record, health-aware)
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "this" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.zone_name

  comment = "Managed by Terraform (ExamRep)"

  tags = {
    Name = var.zone_name
  }
}

data "aws_route53_zone" "this" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.zone_name
}

locals {
  zone_id = var.create_route53_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.this[0].zone_id
}

resource "aws_route53_record" "app" {
  zone_id = local.zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
