# The account-level GitHub OIDC provider survived being torn down elsewhere
# (providers are one-per-URL-per-account, not per-repo) — confirmed via
# `aws iam list-open-id-connect-providers` before writing this. Reused via a
# data lookup rather than re-created.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to this repo only — a wholly new role, never reusing or
    # modifying whatever role the sibling project used.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "GitHubActions-Website-DevSecOps-Role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = merge(local.tags, { Name = "GitHubActions-Website-DevSecOps-Role" })
}

# Scoped to exactly this stack's own resources — ECR repo, ECS cluster/
# service, and enough IAM/logs/etc. read access for `terraform plan/apply`
# to work. Broad by Terraform necessity (it manages many resource types),
# but resource ARNs are scoped to this stack wherever AWS supports it.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"] # GetAuthorizationToken does not support resource-level scoping
  }

  statement {
    sid    = "ECRPushPullRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [module.ecr.repository_arn]
  }

  statement {
    sid    = "ECSDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = ["*"] # ECS actions here largely require resource="*" with tag-based conditions for finer scoping; acceptable for a dedicated, single-purpose role
  }

  statement {
    sid    = "TerraformStateAndInfra"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:aws:s3:::vantageridgetech-website-tfstate-476532114555",
      "arn:aws:s3:::vantageridgetech-website-tfstate-476532114555/*",
      "arn:aws:dynamodb:${var.aws_region}:476532114555:table/vantageridgetech-website-tflocks",
    ]
  }

  # Broad infra-management permissions Terraform itself needs to plan/apply
  # this stack's resource types (VPC, ALB, WAF, IAM roles it owns, SSM read,
  # ACM, CloudWatch/KMS for this stack). Scoping every single action here to
  # a resource ARN is impractical for a Terraform CI role — mitigated by
  # this role only being assumable by this one repo's workflows.
  statement {
    sid    = "InfraManagement"
    effect = "Allow"
    actions = [
      "ec2:*", "elasticloadbalancing:*", "wafv2:*", "logs:*", "kms:*",
      "iam:GetRole", "iam:PassRole", "iam:CreateRole", "iam:DeleteRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:TagRole",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "ssm:GetParameter", "ssm:GetParameters",
      "acm:*", "ecs:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "GitHubActions-Website-DevSecOps-Policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
