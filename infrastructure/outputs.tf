output "alb_hostname" {
  description = "Load balancer hostname"
  value       = aws_alb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_alb.main.dns_name}"
}

output "jenkins_url" {
  value = "http://${aws_eip.jenkins.public_ip}:8080"
}