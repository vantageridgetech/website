resource "aws_acm_certificate" "site" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method          = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-cert" })
}

# Terraform can't add these to Cloudflare itself (domain isn't Route53-hosted
# here) — apply this file first, then add the printed validation CNAMEs in
# Cloudflare as DNS-only (grey cloud) records, wait for propagation, then
# apply again so aws_acm_certificate_validation below can complete.
output "acm_validation_records" {
  value = [
    for dvo in aws_acm_certificate.site.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn
  # No validation_record_fqdns — Cloudflare records are added out-of-band,
  # not through a Terraform-managed Route53 zone. Terraform just polls ACM
  # until it reports ISSUED once the manually-added records propagate.
}
