# 🤖 Ansible Installation Guide

## 📍 Where Ansible Should Be Installed

### Two Installation Locations:

1. **Your Local Machine (Mac/Laptop)** - **CONTROL NODE** ✅
   - This is where you run Ansible commands
   - Manages remote servers via SSH and AWS API
   - **Required for manual operations**

2. **Jenkins EC2 Instance** - **CI/CD Automation** ✅
   - Automatically installed via Terraform
   - Used by Jenkins pipeline for automated deployments
   - **Already handled by infrastructure code**

## 🎯 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Ansible Architecture                      │
└─────────────────────────────────────────────────────────────┘

Your Mac (Control Node)
├── Ansible installed ✅
├── Runs playbooks manually
└── Manages infrastructure via SSH/AWS API
    │
    ├──> Jenkins EC2 (Managed Node + Control Node)
    │    ├── Ansible installed via Terraform ✅
    │    ├── Runs automated CI/CD playbooks
    │    └── NO Ansible agent needed (agentless)
    │
    └──> AWS ECS Fargate (Managed via AWS API)
         ├── NO Ansible installation needed
         └── Managed via boto3/AWS SDK
```

## 🚀 Quick Setup (Automated)

### Option 1: One-Command Setup (Recommended)

```bash
# Run the automated setup script
cd /Users/nakulshivakumar/Desktop/social-app-clone/
./setup-ansible-local.sh
```

This script will:
- ✅ Detect your OS (macOS/Linux)
- ✅ Install Ansible
- ✅ Install Python dependencies (boto3, botocore)
- ✅ Install Ansible Galaxy collections
- ✅ Verify installation
- ✅ Test connectivity

### Option 2: Manual Setup

**macOS:**
```bash
# Install Ansible via Homebrew
brew install ansible

# Install Python packages
pip3 install boto3 botocore ansible

# Install Galaxy collections
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

**Linux (Ubuntu/Debian):**
```bash
# Install Ansible
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible python3-pip

# Install Python packages
pip3 install boto3 botocore

# Install Galaxy collections
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

**Linux (RHEL/CentOS/Amazon Linux):**
```bash
# Install Ansible
sudo yum install -y epel-release
sudo yum install -y ansible python3-pip

# Install Python packages
pip3 install boto3 botocore

# Install Galaxy collections
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

## 🏗️ Jenkins EC2 Installation (Automatic)

Ansible is **automatically installed** on the Jenkins EC2 instance via Terraform user data script.

### How It Works:

1. **Terraform creates Jenkins EC2** with user data script
2. **User data script runs on first boot** and installs:
   - Python3 and pip
   - Ansible via pip
   - boto3 and botocore
   - Ansible Galaxy collections
   - Ansible configuration

3. **Jenkins can now run Ansible playbooks** in CI/CD pipeline

### Verify Jenkins Installation:

```bash
# SSH to Jenkins server
ssh -i ~/.ssh/your-key.pem ec2-user@100.28.67.190

# Check Ansible version
ansible --version

# Check Python packages
pip3 list | grep -E "ansible|boto"

# Exit SSH
exit
```

## ✅ Verify Installation

### On Your Mac:

```bash
# Check Ansible version
ansible --version

# Should show: ansible [core 2.x.x] or later

# Check Python packages
python3 -c "import boto3, botocore; print('✅ boto3 and botocore installed')"

# Test localhost connection
ansible localhost -m ping

# Expected output:
# localhost | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### Test AWS Connectivity:

```bash
# Make sure AWS is configured
aws configure list

# Test Ansible with AWS
cd ansible/
ansible-playbook playbooks/health-check.yml

# This should check your ECS deployment
```

## 🔧 Configuration

### AWS Credentials

Ansible needs AWS credentials to manage ECS:

```bash
# Option 1: AWS CLI configuration (recommended)
aws configure

# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (us-east-1)
# - Default output format (json)

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option 3: AWS credentials file
# Edit ~/.aws/credentials
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
region = us-east-1
```

### Ansible Configuration

Ansible is pre-configured in `ansible/ansible.cfg`:

```ini
[defaults]
inventory = ./inventory/hosts.ini
host_key_checking = False
remote_user = ec2-user
become = True

[inventory]
enable_plugins = ini, yaml, aws_ec2
```

## 🧪 Test Your Setup

### Test 1: Basic Connectivity

```bash
cd ansible/

# Test localhost
ansible localhost -m ping

# Should return: SUCCESS
```

### Test 2: AWS Integration

```bash
# Test health check (uses AWS API)
ansible-playbook playbooks/health-check.yml

# Should show:
# - ECS service status
# - Running tasks
# - Application health
```

### Test 3: Full Deployment

```bash
# Deploy application to ECS
ansible-playbook playbooks/deploy-app.yml

# This will:
# - Update ECS task definition
# - Update ECS service
# - Wait for deployment
# - Run health checks
```

## 🚨 Troubleshooting

### Issue: "ansible: command not found"

**Solution:**
```bash
# Make sure installation path is in PATH
echo $PATH

# For Homebrew on Mac
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Try again
ansible --version
```

### Issue: "boto3 not found"

**Solution:**
```bash
# Install boto3
pip3 install boto3 botocore

# Verify
python3 -c "import boto3; print(boto3.__version__)"
```

### Issue: "Permission denied (publickey)"

**Solution:**
```bash
# Check SSH key exists
ls -la ~/.ssh/

# Generate new key if needed
ssh-keygen -t rsa -b 4096

# Add key to SSH agent
ssh-add ~/.ssh/id_rsa
```

### Issue: "AWS credentials not found"

**Solution:**
```bash
# Configure AWS CLI
aws configure

# Test AWS access
aws sts get-caller-identity

# Should return your AWS account info
```

## 📊 Installation Summary

| Component | Local Mac | Jenkins EC2 | ECS Fargate |
|-----------|-----------|-------------|-------------|
| Ansible | **✅ Manual** | **✅ Terraform** | ❌ Not needed |
| Python/boto3 | **✅ Manual** | **✅ Terraform** | ❌ Not needed |
| SSH Access | ✅ Yes | ✅ Yes | ❌ No (API only) |
| Purpose | Manual ops | CI/CD automation | Managed service |

## 🎯 What to Do After Installation

### 1. Verify Everything Works:
```bash
cd ansible/
ansible --version
ansible localhost -m ping
ansible-playbook playbooks/health-check.yml
```

### 2. Read Documentation:
- [ANSIBLE_GUIDE.md](ANSIBLE_GUIDE.md) - Complete Ansible guide
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command reference

### 3. Try Your First Deployment:
```bash
# Deploy application
ansible-playbook playbooks/deploy-app.yml

# Monitor Jenkins (Ansible runs automatically there)
# http://100.28.67.190:8080
```

## 🔄 Terraform Integration

When you run `terraform apply`, it automatically:

1. ✅ Creates Jenkins EC2 instance
2. ✅ Runs user data script
3. ✅ Installs Ansible on Jenkins
4. ✅ Configures Ansible
5. ✅ Installs all dependencies

**No manual steps required on Jenkins!**

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible AWS Guide](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html)
- [boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

---

**Questions? Check [ANSIBLE_GUIDE.md](ANSIBLE_GUIDE.md) or [QUICK_REFERENCE.md](QUICK_REFERENCE.md)**
