#!/bin/bash

echo "🔒 Remove Secrets from Git Repository"
echo "======================================"
echo ""
echo "⚠️  WARNING: This will rewrite git history!"
echo "⚠️  Make sure you have a backup before proceeding."
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "📋 Step 1: Ensure sensitive files are in .gitignore"
echo "=================================================="

# Check if .gitignore has the needed entries
if ! grep -q "terraform.tfvars" .gitignore; then
    echo "Adding terraform.tfvars to .gitignore..."
    cat >> .gitignore << 'EOF'

# Terraform sensitive files (added by cleanup script)
terraform.tfvars
terraform.tfvars.json
*.tfstate
*.tfstate.*
*.tfstate.backup
EOF
    echo -e "${GREEN}✅ Added sensitive patterns to .gitignore${NC}"
else
    echo -e "${GREEN}✅ .gitignore already has sensitive patterns${NC}"
fi

echo ""
echo "📋 Step 2: Remove sensitive files from staging"
echo "============================================="

git rm --cached infrastructure/terraform.tfvars 2>/dev/null && echo "Removed terraform.tfvars from staging" || echo "terraform.tfvars not in staging"
git rm --cached infrastructure/terraform.tfstate 2>/dev/null && echo "Removed terraform.tfstate from staging" || echo "terraform.tfstate not in staging"
git rm --cached infrastructure/terraform.tfstate.backup 2>/dev/null && echo "Removed terraform.tfstate.backup from staging" || echo "terraform.tfstate.backup not in staging"

echo ""
echo "📋 Step 3: Create terraform.tfvars.example template"
echo "================================================="

if [ -f infrastructure/terraform.tfvars ]; then
    if [ ! -f infrastructure/terraform.tfvars.example ]; then
        cat > infrastructure/terraform.tfvars.example << 'EOF'
# Terraform Variables Example
# Copy this file to terraform.tfvars and fill in your actual values
# terraform.tfvars is gitignored for security

# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "social-app-clone"

# Jira Integration
# Get these values from your Jira account
jira_url         = "https://yourcompany.atlassian.net"
jira_username    = "your-email@company.com"
jira_api_token   = "YOUR_JIRA_API_TOKEN_HERE"  # Get from https://id.atlassian.com/manage-profile/security/api-tokens
jira_project_key = "YOUR_PROJECT_KEY"
jira_issue_type  = "Task"
EOF
        echo -e "${GREEN}✅ Created terraform.tfvars.example${NC}"
    else
        echo -e "${YELLOW}ℹ️  terraform.tfvars.example already exists${NC}"
    fi
fi

echo ""
echo "📋 Step 4: Check for secrets in git history"
echo "========================================="

echo "Checking recent commits for terraform.tfvars..."
SECRET_COMMITS=$(git log --all --full-history --source -- '*terraform.tfvars' --oneline | wc -l)

if [ "$SECRET_COMMITS" -gt 0 ]; then
    echo -e "${RED}⚠️  Found $SECRET_COMMITS commits containing terraform.tfvars${NC}"
    echo ""
    echo "To remove from history, you need to use BFG Repo-Cleaner or git filter-repo"
    echo ""
    echo "Quick fix with BFG:"
    echo "1. Install: brew install bfg"
    echo "2. Run: bfg --delete-files terraform.tfvars"
    echo "3. Run: git reflog expire --expire=now --all && git gc --prune=now --aggressive"
    echo "4. Run: git push origin --force"
    echo ""
    echo "See FIX_GITHUB_SECRET_SCANNING.md for detailed instructions"
else
    echo -e "${GREEN}✅ No terraform.tfvars found in git history${NC}"
fi

echo ""
echo "📋 Step 5: Commit the changes"
echo "============================"

git add .gitignore
git add infrastructure/terraform.tfvars.example 2>/dev/null || true

if git diff --staged --quiet; then
    echo -e "${YELLOW}ℹ️  No changes to commit${NC}"
else
    echo "Changes ready to commit:"
    git status --short
    echo ""
    read -p "Commit these changes? (yes/no): " commit_confirm

    if [ "$commit_confirm" = "yes" ]; then
        git commit -m "security: Remove sensitive files from git and add to .gitignore

- Added terraform.tfvars and state files to .gitignore
- Created terraform.tfvars.example as template
- Removed sensitive files from git tracking

These files contain secrets and should not be in git history.
Use AWS Systems Manager Parameter Store for secret management."

        echo -e "${GREEN}✅ Changes committed${NC}"
        echo ""
        echo "Now you can push:"
        echo "  git push origin main"
    else
        echo "Commit skipped"
    fi
fi

echo ""
echo "🔐 IMPORTANT: Rotate Any Exposed Secrets"
echo "======================================"
echo ""
echo "If secrets were pushed to GitHub, they should be considered compromised."
echo ""
echo "Rotate Jira API Token:"
echo "1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens"
echo "2. Delete the old token"
echo "3. Create a new token"
echo "4. Update in AWS SSM:"
echo "   aws ssm put-parameter --name '/social-app/jira/api-token' \\"
echo "     --value 'NEW_TOKEN' --type SecureString --overwrite --region us-east-1"
echo ""
echo "See FIX_GITHUB_SECRET_SCANNING.md for complete guide"
echo ""
echo "✅ Cleanup complete!"
