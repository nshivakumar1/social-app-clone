aws_region   = "us-east-1"
project_name = "social-app-clone"
environment  = "dev"

fargate_cpu    = "256"
fargate_memory = "512"
app_count      = 1

# Restrict SSH to your IP: replace with YOUR.IP.ADD.RESS/32
jenkins_allowed_cidr = "0.0.0.0/0"

# Set your ACM certificate ARN to enable HTTPS (leave empty for HTTP-only)
acm_certificate_arn = ""

# App secrets — set via environment variables instead:
#   export TF_VAR_jwt_secret="your-strong-secret"
#   export TF_VAR_jira_api_token="your-jira-token"
jwt_secret      = ""
allowed_origins = "http://localhost:3000"

# Alert email for CloudWatch alarms
alert_email = ""

# Jira Integration
jira_url         = "https://infinityloop.atlassian.net"
jira_username    = "nakul.cloudops@outlook.com"
jira_project_key = "SAD"
jira_issue_type  = "Task"
# jira_api_token — DO NOT put here; use: export TF_VAR_jira_api_token="..."
