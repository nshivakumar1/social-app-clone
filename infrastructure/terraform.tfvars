aws_region     = "us-east-1"
project_name   = "social-app-clone"
fargate_cpu    = "256"
fargate_memory = "512"
app_count      = 1

# Jira Integration Configuration
# Update these values with your Jira credentials
jira_url         = "https://infinityloop.atlassian.net"
jira_username    = "nakul.cloudops@outlook.com"
jira_api_token   = "ATATT3xFfGF0WX6L7WwGHeih22Tp9KfjcOG2aCx_uhLIxm-95JeB_EyGAp-w6sisdvCWqL2oQtzxVNe7_YU2Vj5HLx76rXJTgRAHuLi4A3YLdHESA_JuK_YFLGU9f3_0U8bwi2xd_8dDZ791OfDmUjETzOYLtmOWa-26TTup9MWG2ycsSJagOc4=300C5BAA"  # Generate new token at https://id.atlassian.com/manage-profile/security/api-tokens
jira_project_key = "SAD"  # Verify this is correct after creating your Jira project
jira_issue_type  = "Task"  # Change to valid issue type for your project (Story, Bug, Epic, Task)