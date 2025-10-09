variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "social-app-clone"
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  type        = string
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  type        = string
  default     = "512"
}

variable "app_count" {
  description = "Number of Docker containers to run"
  type        = number
  default     = 1
}

variable "aws_account_id" {
  description = "AWS Account ID for ECR repository URL"
  type        = string
  default     = ""
}

# Jira Integration Variables
variable "jira_url" {
  description = "Jira instance URL (e.g., https://yourcompany.atlassian.net)"
  type        = string
  default     = ""
}

variable "jira_username" {
  description = "Jira username/email for API authentication"
  type        = string
  default     = ""
}

variable "jira_api_token" {
  description = "Jira API token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jira_project_key" {
  description = "Jira project key (e.g., SAC)"
  type        = string
  default     = "SAC"
}

variable "jira_issue_type" {
  description = "Jira issue type (e.g., Story, Bug, Epic, Task)"
  type        = string
  default     = "Story"
}