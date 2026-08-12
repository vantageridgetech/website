# The sibling project's state bucket/lock table were destroyed along with
# everything else — this is a fresh bucket, created once via the AWS CLI
# before the first `terraform init` (see infra/envs/prod/README.md).
terraform {
  backend "s3" {
    bucket         = "vantageridgetech-website-tfstate-476532114555"
    key            = "website/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "vantageridgetech-website-tflocks"
    encrypt        = true
  }
}
