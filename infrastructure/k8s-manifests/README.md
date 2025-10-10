# Kubernetes Manifests for Social App Clone

This directory contains Kubernetes manifests for deploying the social-app-clone application.

## Files

- `deployment.yaml` - Deployment configuration with 2 replicas
- `service.yaml` - LoadBalancer service exposing port 80

## GitOps Workflow

These manifests are automatically updated by Jenkins CI/CD pipeline:
1. Jenkins builds and pushes Docker image to ECR
2. Jenkins updates the image tag in `deployment.yaml`
3. ArgoCD detects changes and syncs to EKS cluster

## Manual Deployment

If you want to deploy manually:

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name social-app-eks

# Apply manifests
kubectl apply -f infrastructure/k8s-manifests/

# Check deployment status
kubectl get deployments -n default
kubectl get pods -n default
kubectl get services -n default
```

## Image Updates

The Jenkins pipeline automatically updates the image tag in `deployment.yaml` on each successful build.

Current image format: `297997106614.dkr.ecr.us-east-1.amazonaws.com/social-app-clone:BUILD_NUMBER`
