locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  name_prefix = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

module "network" {
  source      = "../../modules/network"
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.tags
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = local.name_prefix
  tags        = local.tags
}

module "iam" {
  source      = "../../modules/iam"
  name_prefix = local.name_prefix
  tags        = local.tags
}

# ALB access logs — plain SSE-S3 (not a dedicated KMS CMK, unlike the
# sibling project's ALB log bucket) since this is low-traffic, low-stakes
# storage; still versioned, still fully private, still lifecycle-managed.
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-logs" })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "alb-logs-lifecycle"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 90
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid    = "AllowELBAccountWrite"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb-access/*"]
  }

  statement {
    sid    = "AllowLogDeliveryServiceWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb-access/*"]
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

module "ecs_lite" {
  source      = "../../modules/ecs-lite"
  name_prefix = local.name_prefix
  tags        = local.tags

  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  public_subnet_ids  = module.network.public_subnet_ids

  ecr_repository_url   = module.ecr.repository_url
  container_image_tag  = var.container_image_tag

  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn

  acm_certificate_arn = aws_acm_certificate_validation.site.certificate_arn
  alb_log_bucket_name = aws_s3_bucket.alb_logs.id

  desired_count = var.desired_count

  container_environment = [
    { name = "SERVICE_NAME", value = "vantageridgetech-website" },
    { name = "APP_ENV", value = "production" },
    { name = "ZEPTOMAIL_API_URL", value = "https://api.zeptomail.ca/v1.1/email" },
    { name = "ZEPTOMAIL_SENDER_EMAIL", value = "hello@vantageridgetech.com" },
    { name = "ZEPTOMAIL_SENDER_NAME", value = "Vantage Ridge Technologies" },
    { name = "CONTACT_RECIPIENT_EMAIL", value = "hello@vantageridgetech.com" },
    { name = "CHAT_MODEL", value = "claude-sonnet-5" },
    { name = "CHAT_MAX_TOKENS", value = "500" },
  ]

  container_secrets = [
    { name = "SECRET_KEY", valueFrom = data.aws_ssm_parameter.secret_key.arn },
    { name = "ANTHROPIC_API_KEY", valueFrom = data.aws_ssm_parameter.anthropic_api_key.arn },
    { name = "ZEPTOMAIL_API_KEY", valueFrom = data.aws_ssm_parameter.zeptomail_api_key.arn },
  ]

  depends_on = [aws_s3_bucket_policy.alb_logs]
}
