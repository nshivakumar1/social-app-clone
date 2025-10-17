# 🏗️ Deployment Architecture

## Overview: Terraform vs Ansible

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT ARCHITECTURE                          │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  YOUR LAPTOP/MAC (Control Center)                                   │
│                                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐       │
│  │  Terraform   │     │   Ansible    │     │  Git/GitHub  │       │
│  │              │     │              │     │              │       │
│  │ • Creates    │     │ • Deploys    │     │ • Triggers   │       │
│  │ • Destroys   │     │ • Configures │     │ • Webhooks   │       │
│  │ • Manages    │     │ • Updates    │     │ • Commits    │       │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘       │
│         │                    │                    │                │
└─────────┼────────────────────┼────────────────────┼────────────────┘
          │                    │                    │
          │                    │                    │
          ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD                                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Jenkins EC2 Instance (t3.medium)                            │  │
│  │  ✅ Created by: Terraform                                     │  │
│  │  ✅ Ansible installed by: Terraform (user data script)       │  │
│  │                                                               │  │
│  │  Tools Installed:                                            │  │
│  │  • Jenkins CI/CD                                             │  │
│  │  • Ansible (via pip)                                         │  │
│  │  • Docker                                                    │  │
│  │  • AWS CLI                                                   │  │
│  │  • kubectl                                                   │  │
│  │  • Node.js                                                   │  │
│  │                                                               │  │
│  │  Runs: CI/CD Pipeline + Ansible Playbooks                    │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │                                           │
│                         ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  AWS ECS Fargate Cluster                                     │  │
│  │  ✅ Created by: Terraform                                     │  │
│  │  ✅ Deployed by: Ansible OR Jenkins Pipeline                 │  │
│  │                                                               │  │
│  │  • Task Definitions                                          │  │
│  │  • Services                                                  │  │
│  │  • Running Containers                                        │  │
│  │                                                               │  │
│  │  Application: Social App Clone                               │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │                                           │
│                         ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Application Load Balancer (ALB)                             │  │
│  │  ✅ Created by: Terraform                                     │  │
│  │                                                               │  │
│  │  Public URL:                                                 │  │
│  │  http://social-app-clone-xxx.us-east-1.elb.amazonaws.com   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Supporting Infrastructure                                    │  │
│  │  ✅ All created by: Terraform                                 │  │
│  │                                                               │  │
│  │  • VPC, Subnets, Security Groups                            │  │
│  │  • ECR (Container Registry)                                 │  │
│  │  • IAM Roles & Policies                                     │  │
│  │  • CloudWatch Logs                                          │  │
│  │  • Systems Manager Parameters                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 Deployment Workflows

### Workflow 1: Infrastructure Creation (Terraform)

```
Developer → Terraform → AWS
     │          │
     │          ├─→ Creates VPC, Subnets, Security Groups
     │          ├─→ Creates ECS Cluster
     │          ├─→ Creates ECR Repository
     │          ├─→ Creates ALB
     │          ├─→ Creates Jenkins EC2
     │          │      └─→ Runs user-data script
     │          │            └─→ Installs Ansible automatically
     │          └─→ Creates IAM Roles

Result: Infrastructure Ready ✅
```

### Workflow 2: Application Deployment (Ansible - Manual)

```
Developer → Ansible → AWS API
     │         │
     │         ├─→ Builds Docker image (optional)
     │         ├─→ Pushes to ECR
     │         ├─→ Updates ECS Task Definition
     │         ├─→ Updates ECS Service
     │         ├─→ Waits for deployment
     │         └─→ Runs health checks

Result: Application Updated ✅
```

### Workflow 3: CI/CD Pipeline (Git → Jenkins → Ansible)

```
Developer → Git Push → GitHub → Webhook → Jenkins
                                             │
                                             ├─→ Runs Tests
                                             ├─→ Code Quality Checks
                                             ├─→ Builds Docker
                                             ├─→ Pushes to ECR
                                             ├─→ Updates ECS
                                             └─→ Health Checks

Result: Automated Deployment ✅
```

## 📊 Tool Responsibilities

| Tool | Purpose | When to Use | What it Manages |
|------|---------|-------------|-----------------|
| **Terraform** | Infrastructure as Code | Create/destroy infrastructure | VPC, ECS Cluster, ALB, ECR, IAM, Jenkins EC2 |
| **Ansible** | Configuration & Deployment | Deploy apps, configure servers | Application deployment, server config, health checks |
| **Jenkins** | CI/CD Automation | Automated deployments | Build → Test → Deploy pipeline |
| **Git/GitHub** | Version Control | Code changes | Triggers CI/CD, version management |

## 🎯 Where Ansible Fits

### Ansible Installation Locations:

```
┌─────────────────────────────────────────────────────────────┐
│                  Ansible Installation                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. YOUR MAC (Control Node)                                 │
│     ├─ Purpose: Manual operations                           │
│     ├─ Installation: ./setup-ansible-local.sh               │
│     ├─ Use Case: Testing, manual deployments                │
│     └─ Optional: Not required if using Jenkins              │
│                                                              │
│  2. JENKINS EC2 (Control Node + CI/CD)                      │
│     ├─ Purpose: Automated CI/CD                             │
│     ├─ Installation: Automatic via Terraform                │
│     ├─ Use Case: Pipeline automation                        │
│     └─ Required: YES (for automated deployments)            │
│                                                              │
│  3. ECS FARGATE (No installation)                           │
│     ├─ Purpose: Run application                             │
│     ├─ Installation: NOT NEEDED                             │
│     ├─ Management: Via AWS API (boto3)                      │
│     └─ Agentless: Ansible doesn't need to be on target      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Deployment Methods

### Method 1: Terraform Only (Infrastructure)

```bash
cd infrastructure/
terraform apply

# Creates:
# - All AWS resources
# - Jenkins EC2 with Ansible pre-installed
# - ECS cluster ready for deployment

# Does NOT deploy application code
```

**Use Case:** Initial setup, infrastructure changes

### Method 2: Ansible from Mac (Manual Deployment)

```bash
cd ansible/

# Prerequisites:
# 1. Run ./setup-ansible-local.sh
# 2. Configure AWS credentials

# Deploy application
ansible-playbook playbooks/deploy-app.yml

# Health check
ansible-playbook playbooks/health-check.yml
```

**Use Case:** Manual deployments, testing, troubleshooting

### Method 3: Jenkins Pipeline (Automated)

```bash
# Just push code
git add .
git commit -m "Update application"
git push origin main

# Jenkins automatically:
# 1. Tests code
# 2. Checks quality
# 3. Builds Docker
# 4. Pushes to ECR
# 5. Deploys to ECS
# 6. Validates deployment
```

**Use Case:** Production deployments, CI/CD

## 🔍 Current vs New Infrastructure

### Before Ansible Integration:

```
Terraform → Creates Infrastructure
Jenkins → Builds & Deploys (manual steps in pipeline)
```

### After Ansible Integration:

```
Terraform → Creates Infrastructure + Installs Ansible on Jenkins
Jenkins → Uses Ansible for deployment (automated, idempotent)
Optional: Your Mac → Uses Ansible for manual operations
```

## 🎓 Understanding the Stack

### Layer 1: Infrastructure (Terraform)
- Creates AWS resources
- Immutable infrastructure
- Version controlled
- One-time setup

### Layer 2: Configuration (Ansible)
- Configures servers
- Deploys applications
- Updates running services
- Repeatable operations

### Layer 3: CI/CD (Jenkins)
- Automates workflows
- Orchestrates pipeline
- Uses Ansible for deployments
- Continuous delivery

### Layer 4: Application (Node.js)
- Your code
- Runs in containers
- Deployed to ECS
- Served via ALB

## 🤔 Common Questions

### Q: Do I need to install Ansible on my Mac?
**A:** Only if you want to run Ansible playbooks manually. Jenkins already has Ansible for automated deployments.

### Q: Will Terraform install Ansible automatically?
**A:** Yes! When you run `terraform apply`, the Jenkins EC2 user-data script automatically installs Ansible.

### Q: Can I use just Terraform without Ansible?
**A:** Yes! Your current Jenkins pipeline works without Ansible. Ansible adds flexibility and automation options.

### Q: Can I use just Ansible without Terraform?
**A:** No, you need Terraform to create the infrastructure first (VPC, ECS, ALB, etc.). Ansible deploys to existing infrastructure.

### Q: What's the easiest way to test deployment?
**A:** Push code to GitHub. Jenkins will handle everything automatically using its built-in Ansible installation.

## 📋 Summary

| Component | Created By | Configured By | Deployed By |
|-----------|------------|---------------|-------------|
| VPC, Subnets | Terraform | Terraform | N/A |
| ECS Cluster | Terraform | Terraform | N/A |
| ECR | Terraform | Terraform | N/A |
| ALB | Terraform | Terraform | N/A |
| Jenkins EC2 | Terraform | Ansible (user-data) | N/A |
| Ansible on Jenkins | Terraform (user-data) | Terraform | N/A |
| Docker Images | Jenkins | N/A | Jenkins |
| ECS Tasks | Terraform (definition) | Ansible | Ansible/Jenkins |
| Application | Developers | Ansible | Jenkins/Ansible |

---

**Key Takeaway:**
- **Terraform** = Infrastructure
- **Ansible** = Deployment & Configuration
- **Jenkins** = Automation (uses both)
- **Your Mac** = Optional control center

Use Terraform to create resources, Jenkins to automate deployments (which uses Ansible), and optionally Ansible from your Mac for manual operations.
