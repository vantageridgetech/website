data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task-exec"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The 3 real secrets (SECRET_KEY, ANTHROPIC_API_KEY, ZEPTOMAIL_API_KEY) are
# put into SSM manually (see envs/prod/secrets.tf) as SecureStrings under the
# default AWS-managed key (alias/aws/ssm) — no customer CMK needed for these.
data "aws_iam_policy_document" "ssm_read" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:*:*:parameter/${var.name_prefix}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"] # AWS-managed alias/aws/ssm key — permission is IAM-delegated, no per-key ARN needed
  }
}

resource "aws_iam_role_policy" "ecs_exec_ssm_read" {
  name   = "${var.name_prefix}-ecs-exec-ssm-read"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ssm_read.json
}

# Task role: the app itself never calls AWS APIs directly (no X-Ray, no S3,
# no DynamoDB — it only talks to Anthropic's and ZeptoMail's public HTTPS
# APIs), so this role stays empty rather than attaching an unused permission
# set "just in case."
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task-role"
  })
}
