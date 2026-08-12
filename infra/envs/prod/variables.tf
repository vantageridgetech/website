variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "project" {
  type    = string
  default = "vantageridgetech-website"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "owner" {
  type    = string
  default = "enoch"
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "domain_name" {
  type    = string
  default = "vantageridgetech.com"
}

variable "container_image_tag" {
  type    = string
  default = "bootstrap"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role, as org/repo"
  type        = string
  default     = "vantageridgetech/website"
}

variable "desired_count" {
  type    = number
  default = 1
}
