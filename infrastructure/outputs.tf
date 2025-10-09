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

# Jira Integration Outputs
output "jira_ssm_parameters" {
  description = "Jira SSM parameter paths for Jenkins"
  value = {
    url          = aws_ssm_parameter.jira_url.name
    username     = aws_ssm_parameter.jira_username.name
    api_token    = aws_ssm_parameter.jira_api_token.name
    project_key  = aws_ssm_parameter.jira_project_key.name
    issue_type   = aws_ssm_parameter.jira_issue_type.name
  }
}