# 🚀 Quick Reference Guide

## Ansible Commands

### Deployment
```bash
# Deploy application to ECS
cd ansible/
ansible-playbook playbooks/deploy-app.yml

# Full infrastructure setup
ansible-playbook playbooks/site.yml -i inventory/hosts.ini

# Setup Jenkins
ansible-playbook playbooks/setup-jenkins.yml -i inventory/hosts.ini

# Health check
ansible-playbook playbooks/health-check.yml
```

### Testing & Debugging
```bash
# Test connectivity
ansible all -m ping -i inventory/hosts.ini

# Check what would change (dry run)
ansible-playbook playbooks/deploy-app.yml --check

# Verbose output
ansible-playbook playbooks/deploy-app.yml -vvv
```

---

## Code Quality Commands

### Local Development
```bash
cd app/

# Linting
npm run lint              # Check code quality
npm run lint:fix          # Auto-fix issues

# Testing
npm test                  # Run tests
npm test -- --coverage    # With coverage
npm run test:watch        # Watch mode

# Security
npm audit                 # Check vulnerabilities
npm audit fix             # Fix automatically

# SonarQube (optional)
npm run sonar            # Run SonarQube scan
```

### CI/CD Integration
```bash
# Jenkins pipeline runs automatically on git push
# Includes: Test → Code Quality → Build → Deploy

# GitHub Actions runs on:
# - Push to main/develop
# - Pull requests
# - Weekly schedule (Mondays 9 AM)
```

---

## Quick Setup

### Prerequisites
```bash
# Install Ansible
brew install ansible              # macOS
sudo apt-get install ansible      # Linux

# Install Python packages
pip3 install boto3 botocore

# Install Node.js dependencies
cd app/
npm install
```

### Configuration
```bash
# AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Or use AWS CLI
aws configure
```

---

## Common Tasks

### Deploy New Version
```bash
# 1. Update code
git pull origin main

# 2. Deploy with Ansible
cd ansible/
ansible-playbook playbooks/deploy-app.yml -e "docker_tag=v2.0.0"

# 3. Verify deployment
ansible-playbook playbooks/health-check.yml
```

### Code Quality Check Before Commit
```bash
cd app/

# 1. Lint code
npm run lint:fix

# 2. Run tests
npm test

# 3. Security check
npm audit

# 4. Commit if all pass
git add .
git commit -m "Your message"
git push
```

### Troubleshoot Failed Deployment
```bash
# 1. Check health
ansible-playbook ansible/playbooks/health-check.yml -vv

# 2. View logs
aws logs tail /ecs/social-app-clone-task --follow

# 3. Check ECS service
aws ecs describe-services \
  --cluster social-app-clone-cluster \
  --services social-app-clone-service
```

---

## File Locations

### Ansible
```
ansible/ansible.cfg              # Configuration
ansible/inventory/hosts.ini      # Hosts
ansible/playbooks/deploy-app.yml # Main deployment
ansible/group_vars/all.yml       # Variables
```

### Code Quality
```
app/.eslintrc.json               # ESLint config
app/package.json                 # Scripts
sonar-project.properties         # SonarQube
.github/workflows/code-quality.yml # GitHub Actions
```

### Documentation
```
README.md                        # Main docs
ANSIBLE_GUIDE.md                 # Ansible guide
CODE_QUALITY_GUIDE.md            # Quality guide
IMPROVEMENTS_SUMMARY.md          # Changes summary
```

---

## Quality Gates

### ESLint
- ✅ No critical errors
- ⚠️ Max 10 warnings

### Test Coverage
- ✅ Line coverage ≥ 70%
- ✅ Branch coverage ≥ 60%

### Security
- ✅ No critical vulnerabilities
- ✅ No high vulnerabilities
- ⚠️ Moderate < 5

### SonarQube
- ✅ Bugs: 0
- ✅ Vulnerabilities: 0
- ✅ Coverage ≥ 70%
- ✅ Rating: A or B

---

## AWS Resources

### View Application
```bash
# Application URL
http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com

# Health endpoint
http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com/health

# Jenkins
http://100.28.67.190:8080
```

### AWS CLI Commands
```bash
# ECS service status
aws ecs describe-services \
  --cluster social-app-clone-cluster \
  --services social-app-clone-service

# List running tasks
aws ecs list-tasks \
  --cluster social-app-clone-cluster \
  --service-name social-app-clone-service

# View logs
aws logs tail /ecs/social-app-clone-task --follow

# ECR images
aws ecr list-images \
  --repository-name social-app-clone
```

---

## GitHub Actions

### Trigger Workflow
```
GitHub → Actions → Code Quality & Security Scanning → Run workflow
```

### View Results
```
GitHub → Actions tab                    # Workflow runs
GitHub → Security tab                   # Security findings
GitHub → Pull request → Checks          # PR status
```

### Required Secrets
```
SONAR_TOKEN                             # SonarCloud token
GITHUB_TOKEN                            # Auto-provided
```

---

## Support & Documentation

### Help Resources
- 📖 [Main README](README.md)
- 🤖 [Ansible Guide](ANSIBLE_GUIDE.md)
- 📊 [Code Quality Guide](CODE_QUALITY_GUIDE.md)
- 📝 [Improvements Summary](IMPROVEMENTS_SUMMARY.md)

### External Links
- [Ansible Docs](https://docs.ansible.com/)
- [ESLint Rules](https://eslint.org/docs/rules/)
- [SonarQube Docs](https://docs.sonarqube.org/)
- [GitHub Actions](https://docs.github.com/actions)

### Issues & Questions
- Create an issue on GitHub
- Check documentation guides
- Review CloudWatch logs
- Consult AWS console

---

**💡 Tip:** Bookmark this page for quick access to common commands!
