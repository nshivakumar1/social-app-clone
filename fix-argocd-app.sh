#!/bin/bash

echo "🔧 Fixing ArgoCD Application Configuration"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if kubectl is configured
if ! kubectl get ns argocd &>/dev/null; then
    echo -e "${RED}❌ ArgoCD namespace not found or kubectl not configured${NC}"
    echo "Run: aws eks update-kubeconfig --region us-east-1 --name social-app-clone-eks"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is configured and ArgoCD namespace exists${NC}"
echo ""

# Check if app exists
if kubectl get application social-app-clone -n argocd &>/dev/null; then
    echo -e "${YELLOW}📋 Current ArgoCD application found${NC}"
    echo "Current path:"
    kubectl get application social-app-clone -n argocd -o jsonpath='{.spec.source.path}'
    echo ""
    echo ""

    echo -e "${YELLOW}🗑️  Deleting old application...${NC}"
    kubectl delete application social-app-clone -n argocd
    echo -e "${GREEN}✅ Old application deleted${NC}"
    echo ""
else
    echo -e "${YELLOW}ℹ️  No existing application found${NC}"
    echo ""
fi

# Create new ArgoCD application with correct path
echo -e "${GREEN}📝 Creating new ArgoCD application with correct path...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: social-app-clone
  namespace: argocd
  labels:
    app: social-app-clone
spec:
  project: default
  source:
    repoURL: https://github.com/nshivakumar1/social-app-clone.git
    targetRevision: main
    path: infrastructure/k8s-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ ArgoCD application created successfully!${NC}"
    echo ""
    echo "📋 Application details:"
    kubectl get application social-app-clone -n argocd
    echo ""
    echo "🔍 Check status:"
    echo "kubectl describe application social-app-clone -n argocd"
    echo ""
    echo "🔄 Sync manually if needed:"
    echo "kubectl patch application social-app-clone -n argocd --type merge -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"syncStrategy\":{\"hook\":{}}}}}'"
else
    echo -e "${RED}❌ Failed to create ArgoCD application${NC}"
    exit 1
fi

echo ""
echo "🎉 Done! Check ArgoCD UI to verify the application is syncing correctly."
echo "Expected path: infrastructure/k8s-manifests"
