output "alb_dns_name" {
  description = "Application Load Balancer DNS — your app URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "IAM Role ARN — add this as AWS_ROLE_ARN secret in GitHub"
  value       = aws_iam_role.github_actions.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}
