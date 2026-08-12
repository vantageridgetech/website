output "alb_dns_name" {
  value = module.ecs_lite.alb_dns_name
}

output "acm_certificate_arn" {
  value = aws_acm_certificate_validation.site.certificate_arn
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs_lite.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.ecs_lite.ecs_service_name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
