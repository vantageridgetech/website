# These 3 parameters must exist in SSM (SecureString) BEFORE this file's data
# sources can resolve — put them there manually first:
#
#   aws ssm put-parameter --region ca-central-1 --type SecureString \
#     --name /vantageridgetech-website-prod/secret-key --value '<generated>'
#   aws ssm put-parameter --region ca-central-1 --type SecureString \
#     --name /vantageridgetech-website-prod/anthropic-api-key --value '<real key>'
#   aws ssm put-parameter --region ca-central-1 --type SecureString \
#     --name /vantageridgetech-website-prod/zeptomail-api-key --value '<real key>'
#
# Deliberately NOT aws_ssm_parameter resources with a literal value — that
# would put these externally-issued credentials into .tfstate in plaintext.
# Terraform only ever reads them by name; it never sees or manages the value.

data "aws_ssm_parameter" "secret_key" {
  name = "/${local.name_prefix}/secret-key"
}

data "aws_ssm_parameter" "anthropic_api_key" {
  name = "/${local.name_prefix}/anthropic-api-key"
}

data "aws_ssm_parameter" "zeptomail_api_key" {
  name = "/${local.name_prefix}/zeptomail-api-key"
}
