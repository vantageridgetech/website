data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  app_port        = var.app_port
  container_image = "${var.ecr_repository_url}:${var.container_image_tag}"
}

# ----------------------------------------------------------------
# The one customer-managed KMS key in this whole stack — CloudWatch Logs
# (app logs + WAF logs). Everything else (ECR, SSM secrets) uses AWS-managed
# keys — see infra/modules/ecr and infra/modules/iam for why.
# ----------------------------------------------------------------
resource "aws_kms_key" "logs" {
  description             = "CMK for CloudWatch Logs (${var.name_prefix})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUseOfKey"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-logs-kms" })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-logs" })
}

resource "aws_cloudwatch_log_group" "waf" {
  # WAFv2 logging requires the destination log group name to be prefixed
  # aws-waf-logs- when the destination is CloudWatch Logs.
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-waf-logs" })
}

# -----------------------------
# Security Groups
# -----------------------------
#tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTPS from Internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "ALB to task in VPC on app port"
    from_port   = local.app_port
    to_port     = local.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-tasks-sg"
  description = "ECS tasks security group - inbound only from the ALB, never directly from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB SG"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  #trivy:ignore:AWS-0104  # Task runs in a public subnet (no NAT) — needs HTTPS egress to pull from ECR, write logs, and reach Anthropic/ZeptoMail APIs
  egress {
    description      = "HTTPS to Internet (ECR, CloudWatch, SSM, Anthropic, ZeptoMail)"
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tasks-sg" })
}

# ----------------------------------------------------------
# ALB + Target Group + HTTPS Listener
# ----------------------------------------------------------
#tfsec:ignore:aws-0053
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  # enabled is a plain `true` (not conditioned on the bucket name being
  # non-empty) because the bucket is created in the same apply as this ALB —
  # a computed-value comparison here caused a "provider produced inconsistent
  # final plan" error, since Terraform can't resolve `!= ""` against a value
  # that's still unknown at plan time.
  access_logs {
    bucket  = var.alb_log_bucket_name
    enabled = true
    prefix  = "alb-access"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name_prefix}-tg"
  port                 = local.app_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tg" })
}

# No CodeDeploy blue/green here (unlike the sibling bootcamp project) — a
# single low-traffic service doesn't need traffic-shifted zero-downtime
# deploys badly enough to justify the extra moving parts, so Terraform is
# the sole owner of this listener (no lifecycle.ignore_changes needed).
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-https-listener" })
}

# ------------------------------------------------------------
# WAFv2 — 2 managed rule groups + rate limit (trimmed from the sibling
# project's 3 groups; see DECISIONS.md-style reasoning in the deploy plan)
# ------------------------------------------------------------
resource "aws_wafv2_web_acl" "alb" {
  name        = "${var.name_prefix}-waf"
  description = "WAF for ${var.name_prefix} ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "RateLimitPerIp"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIp"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-waf" })
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

# WAF logging straight to CloudWatch Logs — no Firehose/S3/extra-KMS pipeline
# (supported directly by WAFv2 since 2022; the sibling project predates that
# and still uses the Firehose route).
resource "aws_wafv2_web_acl_logging_configuration" "alb" {
  resource_arn            = aws_wafv2_web_acl.alb.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  depends_on = [aws_cloudwatch_log_group.waf]
}

# ------------------------------------------------------
# ECS Cluster + Task + Service (Fargate, public subnets, no NAT)
# ------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cluster" })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn             = var.ecs_task_role_arn

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = local.container_image
      essential = true

      readonlyRootFilesystem = true

      mountPoints = [
        { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false },
        { sourceVolume = "tmp", containerPath = "/var/tmp", readOnly = false },
        { sourceVolume = "tmp", containerPath = "/usr/tmp", readOnly = false }
      ]

      portMappings = [
        { containerPort = local.app_port, protocol = "tcp" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = concat(
        var.container_environment,
        [
          { name = "TMPDIR", value = "/tmp" },
          { name = "GUNICORN_CMD_ARGS", value = "--worker-tmp-dir /tmp" },
          { name = "PYTHONUNBUFFERED", value = "1" },
          { name = "PYTHONPYCACHEPREFIX", value = "/tmp/pycache" },
        ]
      )

      # SSM SecureString values injected at container start — never appear in
      # the task definition JSON, terraform plan output, or CloudWatch.
      secrets = var.container_secrets
    }
  ])

  tags = merge(var.tags, { Name = "${var.name_prefix}-task" })
}

resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = local.app_port
  }

  depends_on = [aws_lb_listener.https]

  tags = merge(var.tags, { Name = "${var.name_prefix}-svc" })
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
