output "alb_hostname" {
  description = "Load balancer hostname"
  value       = aws_alb.main.dns_name
}

output "application_url" {
  description = "Application URL"
  value       = var.acm_certificate_arn != "" ? "https://${aws_alb.main.dns_name}" : "http://${aws_alb.main.dns_name}"
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

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_alb.main.arn
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_alb_target_group.app.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "NAT gateway public IP (egress IP for private subnets)"
  value       = aws_eip.nat.public_ip
}

output "internet_gateway_id" {
  description = "Internet gateway ID"
  value       = aws_internet_gateway.main.id
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_public_ip" {
  description = "Jenkins public IP"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "eks_fargate_profiles" {
  description = "EKS Fargate profile names"
  value       = [aws_eks_fargate_profile.app.fargate_profile_name, aws_eks_fargate_profile.kube_system.fargate_profile_name]
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "jira_ssm_parameters" {
  description = "Jira SSM parameter paths"
  value = {
    url         = aws_ssm_parameter.jira_url.name
    username    = aws_ssm_parameter.jira_username.name
    api_token   = length(aws_ssm_parameter.jira_api_token) > 0 ? aws_ssm_parameter.jira_api_token[0].name : "not set"
    project_key = aws_ssm_parameter.jira_project_key.name
    issue_type  = aws_ssm_parameter.jira_issue_type.name
  }
}
