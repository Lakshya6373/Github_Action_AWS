variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  default     = "github-actions-ecs"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  default     = "github-actions-ecs-app"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  default     = "github-actions-cluster"
}

variable "ecs_service_name" {
  description = "ECS service name"
  default     = "github-actions-service"
}

variable "github_org" {
  description = "Your GitHub username or org"
  # example: "your-github-username"
}

variable "github_repo" {
  description = "Your GitHub repository name"
  # example: "github-actions-ecs-app"
}
