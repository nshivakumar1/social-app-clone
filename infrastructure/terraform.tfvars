aws_region     = "us-east-1"
project_name   = "social-app-clone"
fargate_cpu    = "256"
fargate_memory = "512"
app_count      = 1

# Jira Integration Configuration
# Update these values with your Jira credentials
jira_url         = "https://infinityloop.atlassian.net"
jira_username    = "nakul.cloudops@outlook.com"
jira_api_token   = "ATATT3xFfGF0wQJM_LrWLoGDXf6Nq3RFFCrupOp3sj9QQhcfNM2VM5Rv5uZrne_0Zx4U75nhG5I_JdltMqwSUkqWmwNE0_BvtR19FjTADkRmm2rwwcctdCQN9u2-c1dfr4KOeWdDuNE5FWSJld3FcHdohtqgbgykD5ca5v5YmwgRjhdCvjkd9Hs=9E815254"  # Generate new token at https://id.atlassian.com/manage-profile/security/api-tokens
jira_project_key = "SAD"  # Verify this is correct after creating your Jira project
jira_issue_type  = "Task"  # Change to valid issue type for your project (Story, Bug, Epic, Task)