# Social App Clone — Enterprise DevOps Implementation

A production-ready real-time social media application showcasing a full DevOps stack: containerized Node.js app deployed on AWS ECS Fargate, Kubernetes on EKS Fargate, and a complete CI/CD pipeline with security scanning, GitOps, and observability.

[![Node.js](https://img.shields.io/badge/node.js-18.x-green)](https://nodejs.org/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20|%20EKS%20|%20ECR%20|%20ALB-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)
[![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-red)](https://www.jenkins.io/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-black)](https://github.com/features/actions)

---

## Live Endpoints

| Service | URL |
|---------|-----|
| Social App | http://social-app-clone-245623012.us-east-1.elb.amazonaws.com |
| Health Check | http://social-app-clone-245623012.us-east-1.elb.amazonaws.com/health |
| Jenkins | http://3.215.243.131:8080 |

---

## Architecture

```
Developer → GitHub → GitHub Actions / Jenkins CI/CD
                              │
                    ┌─────────┴──────────┐
                    │                    │
               Docker Build          Code Quality
               ECR Push              ESLint, CodeQL
               ECS Deploy            Trivy, SonarQube
                    │
          ┌─────────┴──────────┐
          │                    │
     AWS ECS Fargate      AWS EKS Fargate
     (App workload)       (K8s showcase)
          │                    │
         ALB              ArgoCD GitOps
                          Grafana + Loki
                          Trivy Operator
                          SonarQube
                          K8s Dashboard
```

### AWS Infrastructure (us-east-1, account 930342219780)

| Resource | Details |
|----------|---------|
| VPC | 10.0.0.0/16, 2 public + 2 private subnets |
| ECS Fargate | Social app (1 task, 256 CPU / 512 MB) |
| EKS Fargate | K8s cluster — no idle EC2 nodes, pay per pod |
| ALB | Public-facing, health checks on `/health` |
| ECR | `930342219780.dkr.ecr.us-east-1.amazonaws.com/social-app-clone` |
| NAT Gateway | Private subnet egress |
| Jenkins | EC2 t3.medium with Elastic IP |
| SSM Parameter Store | JWT secret, Jira credentials |
| CloudWatch | 5 alarms, Container Insights, 60s metrics |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| App | Node.js 18, Express 4, Socket.IO 4 |
| Auth | JWT (jsonwebtoken ^9.0.3), 24h expiry |
| Security | Helmet.js, express-rate-limit, XSS escaping |
| Logging | Winston (structured JSON) |
| Container | Docker (node:18-alpine), non-root user |
| IaC | Terraform ~5.0 (AWS provider) |
| Compute | ECS Fargate (app) + EKS Fargate (K8s) |
| CI/CD | GitHub Actions + Jenkins |
| Secrets | AWS SSM Parameter Store |
| Monitoring | CloudWatch Alarms + Grafana + Loki |
| Code Quality | SonarQube |
| Security Scan | Trivy Operator + Policy Reporter |
| GitOps | ArgoCD (watches `infrastructure/k8s-manifests/`) |

---

## Quick Start (Local)

```bash
cd app
npm install
JWT_SECRET=dev-secret node server.js
# → http://localhost:3000
```

---

## Deploy to AWS

### Prerequisites
- AWS CLI configured (`aws sts get-caller-identity`)
- Terraform >= 1.5
- Docker

### 1. Infrastructure

```bash
cd infrastructure

# Set JWT secret (persisted in terraform.secret.auto.tfvars — gitignored)
echo 'jwt_secret = "'$(openssl rand -base64 32)'"' > terraform.secret.auto.tfvars

terraform init
terraform apply
```

### 2. Push Docker image

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 930342219780.dkr.ecr.us-east-1.amazonaws.com

cd app
docker build --platform linux/amd64 -t social-app-clone .
docker tag social-app-clone:latest 930342219780.dkr.ecr.us-east-1.amazonaws.com/social-app-clone:latest
docker push 930342219780.dkr.ecr.us-east-1.amazonaws.com/social-app-clone:latest
```

### 3. Deploy

```bash
aws ecs update-service --cluster social-app-clone --service social-app-clone \
  --force-new-deployment --region us-east-1
```

---

## CI/CD Pipelines

### GitHub Actions (`.github/workflows/`)

| Workflow | Trigger | Stages |
|----------|---------|--------|
| `code-quality.yml` | Every push/PR | ESLint → CodeQL → Trivy → Dependency Review |
| `deploy.yml` | Push to main | Test → Build → Trivy scan (blocks on CRITICAL/HIGH) → ECR push → ECS deploy → health poll → rollback on failure |

### Jenkins (`ci-cd/Jenkinsfile`)

8-stage parallel pipeline: lint/test → build → Trivy scan → ECR push → ECS deploy → health check → Jira ticket on failure.

---

## Kubernetes (EKS Fargate)

```bash
# Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name social-app-clone-eks

# Apply all K8s manifests
kubectl apply -f infrastructure/k8s-manifests/
```

### K8s Manifests (`infrastructure/k8s-manifests/`)

| Manifest | Purpose |
|----------|---------|
| `deployment.yaml` | App — 2 replicas, securityContext |
| `service.yaml` | ClusterIP |
| `ingress.yaml` | nginx ingress with WebSocket support |
| `hpa.yaml` | HPA: 2–10 replicas, CPU 70% / mem 80% |
| `pdb.yaml` | PodDisruptionBudget: minAvailable 1 |
| `network-policy.yaml` | Ingress from nginx only |
| `argocd/` | ArgoCD Namespace + Ingress config |
| `monitoring/` | Grafana + Loki + Promtail sidecar config |
| `sonarqube/` | SonarQube LTS + PostgreSQL 15 |
| `trivy/` | Trivy Operator + Policy Reporter UI |
| `k8s-dashboard/` | Kubernetes Dashboard + RBAC |

---

## Dashboard Access

### Grafana
```bash
kubectl port-forward svc/grafana -n monitoring 3000:3000
# → http://localhost:3000  (admin / changeme-use-sealed-secret)
```
Panels: 5XX rate, P95 latency, healthy hosts, ECS CPU/memory, request volume, active connections, Loki logs.

### ArgoCD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# → https://localhost:8080
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Kubernetes Dashboard
```bash
kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 8443:443
# → https://localhost:8443
kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath='{.data.token}' | base64 -d
```

### SonarQube (local)
```bash
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=<token> npm run sonar --prefix app
```

### Trivy
```bash
# Scan deployed ECR image
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 930342219780.dkr.ecr.us-east-1.amazonaws.com
trivy image 930342219780.dkr.ecr.us-east-1.amazonaws.com/social-app-clone:latest

# Scan live AWS account
trivy aws --region us-east-1
```

---

## Monitoring

5 CloudWatch alarms → SNS email:
- ECS CPU > 80%
- ECS Memory > 85%
- ALB 5XX error rate > 10
- ALB P95 latency > 2s
- ALB unhealthy host count > 0

---

## Cost Breakdown (us-east-1, ~monthly)

| Service | Cost |
|---------|------|
| EKS control plane | $73 |
| Jenkins EC2 t3.medium | $32 |
| NAT Gateway | $32 |
| ALB | $22 |
| ECS Fargate (1 task) | $9 |
| EKS Fargate pods | ~$5–10 |
| CloudWatch | $8–15 |
| ECR, SSM | ~$1 |
| **Total** | **~$182–195/month** |

---

## Security

- JWT auth on all mutating routes (POST, DELETE)
- DELETE enforces author ownership (403 if mismatch)
- Helmet.js with custom CSP
- Rate limits: 500 req/15min global + 30 writes/min per user
- XSS: `escapeHtml()` before any HTML injection
- Private subnets for ECS tasks (no public IPs)
- Non-root Docker user (uid 1001)
- Secrets via SSM Parameter Store only

---

## Teardown

```bash
cd infrastructure
terraform destroy
```

---

**Built by [Nakul Shivakumar](https://github.com/nshivakumar1)**
