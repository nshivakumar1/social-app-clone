# 🤖 Ansible Configuration Management Guide

This guide covers how to use Ansible for infrastructure provisioning and application deployment automation in the Social App Clone project.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Playbooks](#playbooks)
- [Usage](#usage)
- [Best Practices](#best-practices)

## 🎯 Overview

Ansible is used in this project for:

- **Infrastructure Provisioning**: Automated setup of Jenkins, monitoring, and application servers
- **Application Deployment**: Automated deployment to AWS ECS Fargate
- **Configuration Management**: Consistent configuration across all environments
- **Health Checks**: Automated validation and testing

## 📦 Prerequisites

### Required Software
```bash
# Install Ansible (macOS)
brew install ansible

# Install Ansible (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install ansible

# Install Ansible (RHEL/CentOS)
sudo yum install ansible
```

### Python Dependencies
```bash
pip3 install boto3 botocore
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure

# Or export environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

## 🛠️ Installation

### 1. Install Ansible Collections
```bash
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

### 2. Configure Inventory
Update the inventory file with your infrastructure details:

```bash
# Edit static inventory
vim ansible/inventory/hosts.ini

# Or use AWS dynamic inventory
vim ansible/inventory/aws_ec2.yml
```

### 3. Test Connectivity
```bash
# Test connection to all hosts
ansible all -m ping -i inventory/hosts.ini

# Test connection to Jenkins server
ansible jenkins -m ping -i inventory/hosts.ini
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the ansible directory:

```bash
# AWS Configuration
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=your-account-id

# Application Configuration
export APP_NAME=social-app-clone
export DOCKER_TAG=latest

# ECS Configuration
export ECS_CLUSTER=social-app-clone-cluster
export ECS_SERVICE=social-app-clone-service
```

### Group Variables

Modify group variables in `ansible/group_vars/`:

```yaml
# ansible/group_vars/all.yml
project_name: social-app-clone
aws_region: us-east-1
docker_image: your-ecr-registry/social-app-clone
```

## 📖 Playbooks

### Available Playbooks

| Playbook | Description | Usage |
|----------|-------------|-------|
| `site.yml` | Main playbook - runs all roles | Full infrastructure setup |
| `deploy-app.yml` | Deploy application to ECS | Application deployment |
| `setup-jenkins.yml` | Configure Jenkins CI/CD | Jenkins setup |
| `health-check.yml` | Validate deployment | Health validation |

### Playbook Details

#### 1. Deploy Application (`deploy-app.yml`)

Deploys the Social App Clone to AWS ECS Fargate.

**Features:**
- Docker image build and push to ECR
- ECS task definition registration
- ECS service update
- Deployment validation
- Health checks

**Usage:**
```bash
# Basic deployment
ansible-playbook playbooks/deploy-app.yml

# Deploy with custom image tag
ansible-playbook playbooks/deploy-app.yml -e "docker_tag=v2.0.0"

# Build and deploy
ansible-playbook playbooks/deploy-app.yml -e "build_image=true push_image=true"

# Deployment with extra logging
ansible-playbook playbooks/deploy-app.yml -v
```

**Variables:**
- `docker_tag`: Image tag to deploy (default: latest)
- `build_image`: Build Docker image (default: false)
- `push_image`: Push to ECR (default: false)
- `deployment_timeout`: Timeout in seconds (default: 600)

#### 2. Setup Jenkins (`setup-jenkins.yml`)

Configures Jenkins CI/CD server with all required tools.

**Features:**
- Jenkins installation and configuration
- Docker installation
- AWS CLI v2 setup
- Plugin installation
- Security configuration

**Usage:**
```bash
# Setup Jenkins server
ansible-playbook playbooks/setup-jenkins.yml -i inventory/hosts.ini

# Setup with specific Jenkins version
ansible-playbook playbooks/setup-jenkins.yml -e "jenkins_version=2.426.1"
```

#### 3. Health Check (`health-check.yml`)

Validates application deployment and health.

**Features:**
- Application health endpoint check
- ECS service validation
- Task health verification
- Comprehensive status report

**Usage:**
```bash
# Run health checks
ansible-playbook playbooks/health-check.yml

# With detailed output
ansible-playbook playbooks/health-check.yml -vv
```

#### 4. Main Site Playbook (`site.yml`)

Runs all playbooks in sequence for complete setup.

**Usage:**
```bash
# Full setup
ansible-playbook playbooks/site.yml -i inventory/hosts.ini

# Run specific tags
ansible-playbook playbooks/site.yml --tags "jenkins,ci-cd"
ansible-playbook playbooks/site.yml --tags "deployment"
ansible-playbook playbooks/site.yml --tags "health-check"

# Skip specific tags
ansible-playbook playbooks/site.yml --skip-tags "monitoring"
```

## 🚀 Usage

### Common Operations

#### Deploy Application
```bash
cd ansible/

# Standard deployment
ansible-playbook playbooks/deploy-app.yml

# Emergency rollback (deploy previous version)
ansible-playbook playbooks/deploy-app.yml -e "docker_tag=previous-version"
```

#### Configure Infrastructure
```bash
# Setup Jenkins
ansible-playbook playbooks/setup-jenkins.yml -i inventory/hosts.ini

# Setup everything
ansible-playbook playbooks/site.yml -i inventory/hosts.ini
```

#### Run Health Checks
```bash
# Basic health check
ansible-playbook playbooks/health-check.yml

# Continuous monitoring (run every 5 minutes)
watch -n 300 ansible-playbook playbooks/health-check.yml
```

### Advanced Usage

#### Using AWS Dynamic Inventory
```bash
# Test dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --graph

# Use dynamic inventory for deployment
ansible-playbook playbooks/site.yml -i inventory/aws_ec2.yml
```

#### Dry Run Mode
```bash
# Check what would be changed (check mode)
ansible-playbook playbooks/deploy-app.yml --check

# Show differences
ansible-playbook playbooks/deploy-app.yml --check --diff
```

#### Limit to Specific Hosts
```bash
# Run only on Jenkins
ansible-playbook playbooks/site.yml --limit jenkins

# Run on multiple hosts
ansible-playbook playbooks/site.yml --limit "jenkins,monitoring"
```

## 🔒 Security Best Practices

### 1. Secrets Management

Use Ansible Vault for sensitive data:

```bash
# Create encrypted file
ansible-vault create ansible/group_vars/vault.yml

# Edit encrypted file
ansible-vault edit ansible/group_vars/vault.yml

# Run playbook with vault
ansible-playbook playbooks/deploy-app.yml --ask-vault-pass
```

### 2. AWS Credentials

- Use IAM roles when possible
- Store credentials in AWS Systems Manager
- Never commit credentials to Git

### 3. SSH Keys

```bash
# Generate SSH key for Ansible
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible_rsa

# Update ansible.cfg
# private_key_file = ~/.ssh/ansible_rsa
```

## 📊 Monitoring & Logging

### Enable Ansible Logging
```bash
# Logs are written to ansible.log by default
tail -f ansible/ansible.log
```

### Callback Plugins
The project uses YAML output for better readability:
```ini
[defaults]
stdout_callback = yaml
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Connection Timeout
```bash
# Increase timeout in ansible.cfg
timeout = 60

# Or use -T flag
ansible all -m ping -i inventory/hosts.ini -T 60
```

#### 2. Permission Denied
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Test SSH connection
ssh -i ~/.ssh/id_rsa ec2-user@jenkins-server-ip
```

#### 3. Python Not Found
```bash
# Specify Python interpreter
ansible-playbook playbooks/deploy-app.yml -e "ansible_python_interpreter=/usr/bin/python3"
```

#### 4. AWS Credentials Not Found
```bash
# Export AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Or configure AWS CLI
aws configure
```

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [AWS Ansible Collections](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

## 🤝 Contributing

When adding new playbooks or roles:

1. Test in a non-production environment
2. Document variables and usage
3. Add error handling
4. Include rollback procedures
5. Update this guide

---

**For questions or issues, please create an issue in the GitHub repository.**
