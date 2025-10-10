# 🔒 Fix GitHub Secret Scanning & Push Protection

Guide to resolve "Push cannot contain secrets" errors from GitHub.

## 🎯 Quick Fix (If Secrets Are in Latest Commit Only)

### Option 1: Amend Last Commit (Fastest)

If the secret is only in your most recent commit:

```bash
# Check what's in the last commit
git show HEAD

# Remove the file with secrets from staging
git restore --staged path/to/file-with-secret

# Or edit the file to remove the secret
# Then amend the commit
git add path/to/file-with-secret
git commit --amend --no-edit

# Force push (⚠️ only if you're the only one working on this branch)
git push origin main --force
```

### Option 2: Reset and Recommit

```bash
# Reset to previous commit (keeps your changes)
git reset HEAD~1

# Remove or edit files with secrets
# Make sure secrets are in .gitignore

# Recommit without the secrets
git add .
git commit -m "Your commit message"
git push origin main
```

---

## 🔍 Identify Which Files Contain Secrets

GitHub detected secrets in these common locations:

### Check Your Repository:

```bash
# 1. Check terraform.tfvars (likely culprit)
grep -i "api.*token\|password\|secret" infrastructure/terraform.tfvars

# 2. Check terraform state files
grep -i "api.*token\|password\|secret" infrastructure/terraform.tfstate

# 3. Check all files in git history
git log --all --full-history --source -- '*terraform.tfvars'
```

### Common Secret Locations:

- ❌ `infrastructure/terraform.tfvars` - Contains Jira API tokens
- ❌ `infrastructure/terraform.tfstate` - Contains all secrets
- ❌ `infrastructure/terraform.tfstate.backup`
- ❌ `.env` files
- ❌ `*.pem` key files

---

## 🛡️ Proper .gitignore Configuration

Make sure these are in `.gitignore`:

```bash
# Add to .gitignore
cat >> .gitignore << 'EOF'

# Terraform sensitive files
terraform.tfvars
terraform.tfvars.json
*.tfstate
*.tfstate.*
*.tfstate.backup

# Environment files
.env
.env.local
.env.*.local

# SSH Keys
*.pem
*.key
*.ppk

# AWS Credentials
.aws/
credentials
config

# Secrets
secrets/
*.secret
EOF
```

---

## 🧹 Remove Secrets from Git History

### Method 1: BFG Repo-Cleaner (Recommended)

**Fastest and safest way to remove secrets from history**

```bash
# 1. Install BFG
# macOS
brew install bfg

# Or download from: https://rtyley.github.io/bfg-repo-cleaner/

# 2. Clone a fresh copy
cd ..
git clone --mirror https://github.com/nshivakumar1/social-app-clone.git

# 3. Remove secrets
cd social-app-clone.git

# Remove specific file from all history
bfg --delete-files terraform.tfvars

# OR remove specific text/patterns
bfg --replace-text passwords.txt  # File containing secrets to replace

# 4. Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5. Push cleaned history
git push --force

# 6. Clone fresh repo
cd ..
rm -rf social-app-clone
git clone https://github.com/nshivakumar1/social-app-clone.git
```

### Method 2: git filter-repo (More Control)

```bash
# 1. Install git-filter-repo
pip3 install git-filter-repo

# 2. Remove file from entire history
git filter-repo --path infrastructure/terraform.tfvars --invert-paths

# 3. Force push
git push origin --force --all
```

### Method 3: Manual with git filter-branch (Slowest)

```bash
# Remove file from all commits
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch infrastructure/terraform.tfvars" \
  --prune-empty --tag-name-filter cat -- --all

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push origin --force --all
```

---

## 🔐 Secure Secret Management

### Instead of committing secrets, use:

### 1. **AWS Systems Manager Parameter Store** (Already set up!)

```bash
# Store secrets in AWS SSM
aws ssm put-parameter \
  --name "/social-app/jira/api-token" \
  --value "your-secret-token" \
  --type SecureString \
  --region us-east-1

# Retrieve in Terraform
data "aws_ssm_parameter" "jira_token" {
  name = "/social-app/jira/api-token"
}
```

### 2. **terraform.tfvars.example** (Template file)

Create `infrastructure/terraform.tfvars.example`:

```hcl
# Copy this file to terraform.tfvars and fill in your values
# terraform.tfvars is gitignored for security

# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "social-app-clone"

# Jira Configuration (Get from AWS SSM or enter manually)
jira_url         = "https://yourcompany.atlassian.net"
jira_username    = "your-email@company.com"
jira_api_token   = "YOUR_JIRA_API_TOKEN_HERE"
jira_project_key = "YOUR_PROJECT_KEY"
jira_issue_type  = "Task"
```

Then commit the `.example` file:

```bash
# This is safe to commit (no real secrets)
git add infrastructure/terraform.tfvars.example
git commit -m "Add terraform.tfvars template"
```

### 3. **Environment Variables**

```bash
# Set in your shell
export TF_VAR_jira_api_token="your-token"
export TF_VAR_jira_username="your-email"

# Terraform automatically picks up TF_VAR_* variables
terraform apply
```

---

## 🚨 GitHub Push Protection - Allow Secret (Not Recommended)

If you absolutely need to push a commit with a secret (⚠️ NOT RECOMMENDED):

1. GitHub will show a URL in the error message
2. Click the URL to allow the secret
3. This bypasses protection (dangerous!)

**Better approach**: Remove the secret and use AWS SSM instead.

---

## ✅ Step-by-Step: Clean Fix for Your Repo

### Current Situation:
- terraform.tfvars contains Jira API token
- terraform.tfstate contains secrets
- GitHub is blocking pushes

### Solution:

```bash
# 1. Check current status
git status

# 2. Make sure sensitive files are in .gitignore
cat >> .gitignore << 'EOF'
terraform.tfvars
terraform.tfvars.json
*.tfstate
*.tfstate.*
EOF

# 3. Remove from staging if they're there
git rm --cached infrastructure/terraform.tfvars 2>/dev/null || true
git rm --cached infrastructure/terraform.tfstate 2>/dev/null || true
git rm --cached infrastructure/terraform.tfstate.backup 2>/dev/null || true

# 4. Check if secrets are in commit history
git log --all --full-history --source -- '*terraform.tfvars' --oneline

# 5. If they're in history, use BFG to clean:
# (Follow Method 1 above)

# 6. Create example file for documentation
cp infrastructure/terraform.tfvars infrastructure/terraform.tfvars.example
# Edit terraform.tfvars.example to replace real values with placeholders

# 7. Commit the gitignore and example file
git add .gitignore infrastructure/terraform.tfvars.example
git commit -m "security: Add terraform.tfvars to gitignore and add example template"

# 8. Push
git push origin main
```

---

## 🔍 Verify Secrets Are Removed

```bash
# Check what will be pushed
git diff origin/main..HEAD

# Verify no secrets in recent commits
git log -p -5 | grep -i "api.*token\|password\|secret"

# Check if file is gitignored
git check-ignore infrastructure/terraform.tfvars
# Should output: infrastructure/terraform.tfvars
```

---

## 📋 Post-Cleanup Checklist

After cleaning:

- [ ] Secrets removed from git history
- [ ] Sensitive files in `.gitignore`
- [ ] Example/template files created
- [ ] Real secrets stored in AWS SSM
- [ ] Team notified to use SSM instead
- [ ] Old API tokens rotated (since they were exposed)

---

## 🔄 Rotate Exposed Secrets

**IMPORTANT**: If secrets were pushed to GitHub, they're compromised!

### Rotate Jira API Token:

1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens
2. Delete the old token
3. Create a new token
4. Update AWS SSM Parameter:

```bash
aws ssm put-parameter \
  --name "/social-app/jira/api-token" \
  --value "NEW_TOKEN_HERE" \
  --type SecureString \
  --overwrite \
  --region us-east-1
```

### Rotate AWS Keys (if exposed):

```bash
# 1. Create new access key in AWS IAM Console
# 2. Update Jenkins credentials
# 3. Delete old access key
```

---

## 🆘 Emergency: Secret Already Pushed

If a secret was already pushed to GitHub:

1. **Assume it's compromised** - even if you delete it
2. **Rotate immediately** - GitHub logs all pushes
3. **Check access logs** - see if it was accessed
4. **Notify security team** - if company repo
5. **Clean git history** - prevent future exposure

---

## 💡 Pro Tips

1. **Use pre-commit hooks** to scan for secrets before commit:
   ```bash
   # Install pre-commit
   pip install pre-commit

   # Add to .pre-commit-config.yaml
   repos:
     - repo: https://github.com/Yelp/detect-secrets
       rev: v1.4.0
       hooks:
         - id: detect-secrets
   ```

2. **Use AWS Secrets Manager** for production
3. **Never commit .env files**
4. **Use terraform.tfvars.example** as template
5. **Regularly scan repo** for leaked secrets

---

## 🔗 Useful Tools

- **BFG Repo-Cleaner**: https://rtyley.github.io/bfg-repo-cleaner/
- **git-filter-repo**: https://github.com/newren/git-filter-repo
- **detect-secrets**: https://github.com/Yelp/detect-secrets
- **gitleaks**: https://github.com/gitleaks/gitleaks
- **truffleHog**: https://github.com/trufflesecurity/trufflehog

---

**Remember**: Once a secret is pushed to GitHub, consider it compromised forever. Always rotate exposed credentials!
