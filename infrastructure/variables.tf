variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "social-app-clone"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "fargate_cpu" {
  description = "Fargate CPU units (1 vCPU = 1024)"
  type        = string
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate memory in MiB"
  type        = string
  default     = "512"
}

variable "app_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = ""
}

variable "jenkins_allowed_cidr" {
  description = "CIDR allowed to SSH into Jenkins. CHANGE to your IP/32 before deploying."
  type        = string
  default     = "0.0.0.0/0"  # set to "YOUR.IP.ADD.RESS/32" in tfvars
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to use HTTP only."
  type        = string
  default     = ""
}

variable "jwt_secret" {
  description = "JWT signing secret for the application — set in TFC workspace variables (Terraform, sensitive)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = length(var.jwt_secret) >= 16 || var.jwt_secret == ""
    error_message = "jwt_secret must be at least 16 characters. Set it in TFC: Workspace → Variables → jwt_secret (Terraform, sensitive)."
  }
}

variable "allowed_origins" {
  description = "Comma-separated CORS allowed origins (e.g. https://your-domain.com)"
  type        = string
  default     = "http://localhost:3000"
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# Jira Integration
variable "jira_url" {
  description = "Jira instance URL"
  type        = string
  default     = ""
}

variable "jira_username" {
  description = "Jira username/email"
  type        = string
  default     = ""
}

variable "jira_api_token" {
  description = "Jira API token — set via TF_VAR_jira_api_token env var, not in tfvars"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jira_project_key" {
  description = "Jira project key"
  type        = string
  default     = "SAD"
}

variable "jira_issue_type" {
  description = "Jira issue type for pipeline notifications"
  type        = string
  default     = "Task"
}
