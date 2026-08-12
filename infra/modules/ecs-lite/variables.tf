variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "ecr_repository_url" {
  type = string
}

variable "container_image_tag" {
  type    = string
  default = "bootstrap"
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "app_port" {
  type    = number
  default = 5000
}

variable "container_environment" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "container_secrets" {
  type    = list(object({ name = string, valueFrom = string }))
  default = []
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 1
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 2
}

variable "autoscaling_cpu_target" {
  type    = number
  default = 70
}

variable "waf_rate_limit" {
  type    = number
  default = 400
}

variable "acm_certificate_arn" {
  type = string
}

variable "alb_log_bucket_name" {
  type    = string
  default = ""
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "health_check_path" {
  type    = string
  default = "/health"
}
