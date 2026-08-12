# AES256 (AWS-managed key) rather than a customer-managed KMS CMK — one
# fewer KMS key to pay for/manage for a low-traffic repo, and avoids baking
# a specific IAM role name into a key policy the way the sibling project's
# ECR module does.
resource "aws_ecr_repository" "this" {
  name                 = "${var.name_prefix}-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecr"
  })
}
