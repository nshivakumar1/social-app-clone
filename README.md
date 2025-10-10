# 🚀 Social App Clone - Enterprise DevOps Implementation

A production-ready social media application with comprehensive CI/CD pipeline, containerized deployment, and enterprise-grade DevOps practices featuring automated Slack and Jira notifications.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](http://34.232.207.186:8080)
[![Application](https://img.shields.io/badge/app-live-blue)](http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Node.js](https://img.shields.io/badge/node.js-18.x-green)](https://nodejs.org/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20|%20ECR%20|%20ALB-orange)](https://aws.amazon.com/)
[![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-red)](https://www.jenkins.io/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Technologies](#technologies)
- [Quick Start](#quick-start)
- [Infrastructure Setup](#infrastructure-setup)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring & Observability](#monitoring--observability)
- [Known Issues](#known-issues)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project demonstrates a complete DevOps implementation for a modern social media application, featuring:

- **Real-time Social Media App** built with Node.js and Socket.IO
- **Infrastructure as Code** using Terraform (100% automated)
- **Containerized Deployment** with Docker and AWS ECS Fargate
- **Comprehensive CI/CD Pipeline** using Jenkins (8-stage pipeline)
- **Enterprise Notifications** (Slack ✅, Jira ✅)
- **Multi-platform Docker Builds** (linux/amd64)
- **Automated AWS Integration** with ECR and ECS
- **GitOps-Ready Manifests** for Kubernetes deployments

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │───▶│    GitHub        │───▶│    Jenkins      │
│   Workstation   │    │   Repository     │    │   CI/CD Server  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│     AWS ECR     │◀───│   Docker Build   │    │   AWS ECS       │
│ Container Reg.  │    │   & Push         │    │   Fargate       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS EKS       │◀───│    ArgoCD        │◀───│   GitOps        │
│  Kubernetes     │    │   GitOps         │    │  Manifests      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### AWS Infrastructure

- **VPC**: Custom VPC with public subnets across 2 availability zones
- **ECS Fargate**: Serverless container orchestration for production deployment
- **Application Load Balancer**: High availability with health checks and traffic distribution
- **ECR**: Private Docker container registry with image lifecycle policies
- **CloudWatch**: Centralized logging and monitoring
- **IAM**: Secure role-based access control with least privilege
- **Systems Manager**: Secure parameter store for secrets management
- **Jenkins EC2**: Dedicated CI/CD server (t3.medium) with automated setup

### Application Architecture

- **Frontend**: Modern HTML5/CSS3/JavaScript with real-time updates
- **Backend**: Node.js with Express.js REST API
- **WebSocket**: Socket.IO for real-time features
- **Data**: In-memory storage (ready for database integration)

## ✨ Features

### Application Features
- 📱 **Real-time Social Feed** - Live posts and interactions
- 💬 **Live Comments** - Instant comment updates
- ❤️ **Like System** - Real-time like counters
- 👥 **Online Users** - Live user presence tracking
- 📊 **Activity Feed** - Real-time activity monitoring
- 🏷️ **Hashtag Support** - Trending topics tracking
- 📱 **Responsive Design** - Mobile-first approach

### DevOps Features
- 🔄 **Automated CI/CD** - Jenkins pipeline with 8 stages (tested and working ✅)
- 🐳 **Containerization** - Docker with security best practices (non-root user, multi-stage builds)
- ☁️ **Cloud-Native** - AWS ECS Fargate serverless deployment
- 🎯 **GitOps-Ready** - Auto-generated Kubernetes manifests for ArgoCD
- 📊 **Monitoring** - CloudWatch integration with real-time logs
- 🔔 **Smart Notifications** - Slack & Jira integration with build status (fully working ✅)
- 🛡️ **Security** - IAM roles, security groups, AWS Systems Manager for secrets
- 🔧 **IaC** - 100% Terraform-managed infrastructure (one-command deployment)
- 🔄 **Auto-scaling** - ECS service with desired count and health checks
- 🧹 **Clean Pipeline** - Automatic cleanup of Docker images and workspace

## 🛠️ Technologies

### Backend Stack
- **Runtime**: Node.js 18.x
- **Framework**: Express.js
- **WebSocket**: Socket.IO
- **Security**: Helmet, CORS, Rate Limiting
- **Container**: Docker (Alpine Linux)

### Infrastructure & DevOps
- **Cloud Provider**: AWS (ECS, ECR, ALB, VPC, IAM, Systems Manager)
- **Container Orchestration**: ECS Fargate (serverless)
- **CI/CD**: Jenkins (fully automated 8-stage pipeline)
- **IaC**: Terraform (100% infrastructure as code)
- **GitOps**: ArgoCD-ready (Kubernetes manifests auto-generated)
- **Container Registry**: AWS ECR (private registry)
- **Load Balancer**: Application Load Balancer (multi-AZ)
- **Monitoring**: AWS CloudWatch (logs & metrics)
- **Notifications**: Slack ✅ + Jira ✅ (automated build notifications)
- **Secrets Management**: AWS Systems Manager Parameter Store

### Development Tools
- **Version Control**: Git, GitHub
- **Code Quality**: ESLint (ready)
- **Testing**: Jest (ready)
- **Documentation**: Markdown

### 📸 Screenshots

#### Application Interface
![Live Application Welcome Screen](./docs/images/App-WelcomeScreen.png)

#### Social Features
![First Tweet Posted](./docs/images/First-Tweet-Post.png)

#### CI/CD Pipeline
![Jenkins Successful Deployment](./docs/images/Jenkins-Successful-Deployment.png)
![ArgoCD Deployment Status](./docs/images/ArgoCD-Deployment.png)
![Slack Deployment Notification](./docs/images/Slack-Notification.png)

#### Infrastructure Monitoring
![EC2 Instance Metrics](./docs/images/EC2-Metrics.png)
![ECS Cluster Metrics](./docs/images/ECS-Cluster-Cloudwatch.png)
![Load Balancer Metrics](./docs/images/Elastic-LoadBalancing-Metrics.png)

## 🚀 Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.0
- Docker
- Git
- Node.js 18.x (for local development)

### 1. Clone Repository
```bash
git clone https://github.com/nshivakumar1/social-app-clone.git
cd social-app-clone
```

### 2. Local Development
```bash
cd app
npm install
npm start
# Visit http://localhost:3000
```

### 3. Infrastructure Deployment
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

### 4. Access Applications
- **Social App**: http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com
- **Jenkins**: http://34.232.207.186:8080
- **Health Check**: http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com/health

## 🏗️ Infrastructure Setup

### Terraform Configuration

The infrastructure is completely managed by Terraform and includes:

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply -auto-approve
```

### Resources Created
- **VPC** with public subnets (10.0.0.0/16)
- **ECS Cluster** for container orchestration
- **EKS Cluster** for Kubernetes workloads
- **ECR Repository** for container images
- **Application Load Balancer** with health checks
- **Jenkins Server** (t3.medium) with all dependencies
- **IAM Roles** with least privilege access
- **Security Groups** with appropriate rules
- **CloudWatch Log Groups** for centralized logging

### Environment Variables
Configure these in AWS Systems Manager Parameter Store (automatically created by Terraform):

```bash
# Slack Integration
/social-app/slack/webhook-url (SecureString)

# Jira Integration (✅ Terraform Managed)
/social-app/jira/url (String)
/social-app/jira/username (String)
/social-app/jira/api-token (SecureString)
/social-app/jira/project-key (String)
/social-app/jira/issue-type (String)
```

## 🔄 CI/CD Pipeline

### Jenkins Pipeline Stages (Fully Automated ✅)

1. **🔍 Checkout** - Git repository checkout with commit details and metadata
2. **🧪 Test** - Automated test execution (extensible test framework ready)
3. **🐋 Build Docker Image** - Multi-platform Docker build (linux/amd64)
4. **📤 Push to ECR** - Secure AWS ECR authentication and image push
5. **🚀 Deploy to ECS** - AWS ECS Fargate service update with health checks
6. **📝 Update GitOps** - Auto-generate and commit Kubernetes manifests
7. **🔄 ArgoCD Sync** - Kubernetes deployment automation (optional)
8. **🧪 Post-Deployment Tests** - Health endpoint validation and smoke tests

### Pipeline Features
- ✅ **Automatic Triggering** - Webhook-based CI/CD on git push to main
- ✅ **Multi-tagging Strategy** - Images tagged with build number, commit SHA, and latest
- ✅ **AWS Credentials** - Secure credential binding with AWS Systems Manager
- ✅ **Health Checks** - Automated ECS service stability validation
- ✅ **Smart Notifications** - Real-time Slack and Jira notifications with build status
- ✅ **Error Handling** - Graceful failure handling with detailed error reporting
- ✅ **Workspace Cleanup** - Automatic Docker image and workspace cleanup
- ✅ **GitOps Integration** - Kubernetes manifest generation for ArgoCD
- 🔄 **Rollback Support** - ECS service rollback on deployment failure

### Build Artifacts
- **Docker Images**: Tagged with build number and commit SHA
- **Kubernetes Manifests**: Auto-generated and updated
- **Build Reports**: Available in Jenkins UI
- **Deployment Status**: Real-time monitoring

## 📊 Monitoring & Observability

### CloudWatch Integration
- **Application Logs**: Centralized ECS logging
- **Metrics**: CPU, Memory, Network monitoring
- **Health Checks**: Automated endpoint monitoring
- **Alarms**: Ready for alerting setup

### ELK Stack (Ready)
- **Elasticsearch**: Log storage and indexing
- **Logstash**: Log processing and transformation
- **Kibana**: Visualization and dashboards

### Health Endpoints
```bash
# Application Health
curl http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com/health

# Response
{
  "status": "healthy",
  "timestamp": "2025-07-08T20:27:52.198Z",
  "users": 0,
  "posts": 2
}
```

## ⚠️ Configuration & Setup

### Jira Integration - WORKING ✅
The project includes fully functional Jira integration for automated ticket creation on build success/failure.

**Configuration Steps**:
1. Create AWS Systems Manager parameters:
   ```bash
   aws ssm put-parameter --name "/social-app/jira/username" \
     --value "your-email@company.com" --type String

   aws ssm put-parameter --name "/social-app/jira/api-token" \
     --value "your-jira-api-token" --type SecureString
   ```

2. Jenkins will automatically:
   - Fetch credentials from SSM Parameter Store
   - Create Jira tickets with build status
   - Try multiple issue types (Task, Epic) until successful
   - Provide detailed logging of the process

**Features**:
- ✅ Automatic credential retrieval from AWS Systems Manager
- ✅ Smart issue type detection (tries multiple types)
- ✅ Detailed build information in Jira tickets
- ✅ Links to Jenkins console logs
- ✅ Error handling with helpful diagnostics

### Slack Integration - WORKING ✅
Real-time build notifications sent to your Slack workspace.

**Configuration Steps**:
1. Create a Slack Incoming Webhook at https://api.slack.com/apps
2. Store webhook URL in AWS Systems Manager:
   ```bash
   aws ssm put-parameter --name "/social-app/slack/webhook-url" \
     --value "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
     --type SecureString
   ```

3. Jenkins will automatically send notifications on:
   - ✅ Successful deployments (with app URL)
   - ❌ Failed deployments (with console logs link)

### Potential Improvements
- [ ] Database integration (PostgreSQL/MongoDB)
- [ ] Redis for session management
- [ ] HTTPS/SSL certificate setup
- [ ] Automated backup strategies
- [ ] Advanced security scanning
- [ ] Performance testing integration
- [ ] Multi-region deployment

## 🛡️ Security

### Implemented Security Measures
- **IAM Roles**: Least privilege access
- **Security Groups**: Restricted network access
- **Secrets Management**: AWS Systems Manager
- **Container Security**: Non-root user, minimal attack surface
- **Rate Limiting**: API protection
- **CORS**: Cross-origin request security
- **Helmet**: Security headers

### Security Best Practices
- Regular dependency updates
- Image vulnerability scanning
- Network segmentation
- Encrypted secrets storage
- Audit logging enabled

## 📚 Additional Setup Guides

### Creating a Free Jira Account
1. Visit [Atlassian Jira Free Signup](https://www.atlassian.com/try/cloud/signup?bundle=jira-software&edition=free)
2. Create your workspace and project
3. Generate an API token from Account Settings → Security → API Tokens
4. Store credentials in AWS Systems Manager as shown above

### Setting Up Slack Workspace
1. Create a Slack workspace at [Slack Get Started](https://slack.com/get-started)
2. Create a channel for build notifications (e.g., #deployments)
3. Create a Slack App at [Slack Apps](https://api.slack.com/apps)
4. Enable Incoming Webhooks and create a webhook URL
5. Store webhook URL in AWS Systems Manager Parameter Store


## 🤝 Contributing

### Development Workflow
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

### Code Standards
- Follow Node.js best practices
- Write meaningful commit messages
- Add tests for new features
- Update documentation

### Infrastructure Changes
- Test Terraform changes in dev environment
- Follow infrastructure as code principles
- Document architectural decisions

## 📈 Performance

### Current Metrics
- **Application Load Time**: ~2s
- **Health Check Response**: ~100ms
- **WebSocket Latency**: ~50ms
- **Container Startup**: ~30s
- **Deployment Time**: ~5 minutes

### Optimization Opportunities
- CDN integration for static assets
- Database query optimization
- Caching layer implementation
- Image optimization

## 🌟 Key Achievements

This project demonstrates production-ready enterprise DevOps practices:

### Application & Architecture
- ✅ **Real-time Social Media App** with WebSocket support and live updates
- ✅ **Cloud-Native Architecture** deployed on AWS ECS Fargate
- ✅ **High Availability** with Application Load Balancer across multiple AZs
- ✅ **Containerization** with Docker security best practices

### Infrastructure & Automation
- ✅ **100% Infrastructure as Code** using Terraform
- ✅ **One-Command Deployment** (terraform apply)
- ✅ **Fully Automated CI/CD** with 8-stage Jenkins pipeline
- ✅ **GitOps-Ready** with auto-generated Kubernetes manifests

### DevOps Excellence
- ✅ **Automated Notifications** - Slack ✅ and Jira ✅ integration working
- ✅ **Secrets Management** via AWS Systems Manager Parameter Store
- ✅ **Multi-Platform Builds** (linux/amd64)
- ✅ **Health Monitoring** with automated ECS stability checks
- ✅ **Clean Pipelines** with automatic resource cleanup

### Security & Best Practices
- ✅ **IAM Role-Based Access** with least privilege principle
- ✅ **Non-root Container User** for enhanced security
- ✅ **Security Groups** with restricted network access
- ✅ **Rate Limiting & CORS** protection
- ✅ **Encrypted Secrets** in AWS Systems Manager

## 🧹 Cleanup & Resource Destruction

### Terraform Resources Cleanup
To destroy all AWS infrastructure created by Terraform:

```bash
cd infrastructure
terraform destroy -auto-approve
```

This will remove:
- ECS Cluster and Services
- ECR Repository
- Application Load Balancer
- VPC and Subnets
- Security Groups
- IAM Roles
- CloudWatch Log Groups
- Jenkins EC2 Instance
- All other AWS resources

### Kubernetes Resources Cleanup (if applicable)
If you deployed to EKS/Kubernetes:

```bash
# List all resources first (review before deletion)
kubectl get all --all-namespaces

# Delete application resources
kubectl delete all --all -n default

# Delete custom namespaces (excluding system namespaces)
kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | \
  grep -v -E "^(default|kube-system|kube-public|kube-node-lease)$" | \
  xargs -I {} kubectl delete namespace {}
```

**⚠️ Warning**: These commands will permanently delete all resources and data. Make sure you have backups if needed.

## 🔗 Quick Links

- **📱 Live Application**: [Social App Clone](http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com)
  *(URL will be different for your deployment)*

- **🔧 Jenkins Dashboard**: [Jenkins CI/CD](http://34.232.207.186:8080)
  *(URL changes based on your EC2 instance IP)*

- **💻 GitHub Repository**: [Source Code](https://github.com/nshivakumar1/social-app-clone)

- **📊 Health Check**: `http://your-alb-url.amazonaws.com/health`

## 🆘 Getting Help

- **Bug Reports**: Create an issue on GitHub
- **Questions**: Use GitHub Discussions
- **Troubleshooting**: Check CloudWatch logs for detailed error messages
- **AWS Issues**: Review Terraform state and AWS console
- **Jenkins Issues**: Check Jenkins console output and system logs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ by [Nakul Shivakumar](https://github.com/nshivakumar1)**

*A showcase of modern DevOps practices and cloud-native development*