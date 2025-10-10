# Terraform Destroy Guide

This guide provides multiple strategies for safely destroying the infrastructure with proper dependency management.

## 🚨 The Problem

AWS resources have complex dependencies. Common errors when running `terraform destroy`:

1. **Internet Gateway detachment error**: `Network has some mapped public address(es)`
2. **Subnet deletion error**: `The subnet has dependencies and cannot be deleted`
3. **Security Group dependencies**: Resources still attached
4. **ENI (Elastic Network Interface) issues**: Network interfaces not cleaned up

## ✅ Solutions (Choose One)

### Option 1: Automated Safe Destroy (Recommended)

Uses a comprehensive workflow that handles all dependencies automatically.

```bash
cd infrastructure
./safe-destroy.sh
```

**What it does:**
1. Scales down EKS node group to 0
2. Cleans up all Kubernetes resources (LoadBalancers, Ingresses, etc.)
3. Scales down ECS service to 0 tasks
4. Deregisters all ALB targets
5. Runs network cleanup (ENIs, EIPs, NAT gateways)
6. Executes `terraform destroy` with retry logic (up to 3 attempts)
7. Verifies complete cleanup

**Time:** 5-10 minutes

---

### Option 2: Manual Network Cleanup + Terraform Destroy

First clean up network dependencies, then destroy with Terraform.

```bash
cd infrastructure

# Step 1: Clean up network dependencies
./force-cleanup-network.sh

# Step 2: Run terraform destroy
terraform destroy
```

**What `force-cleanup-network.sh` does:**
- Releases Elastic IPs
- Deletes NAT Gateways
- Cleans up Load Balancers
- Detaches and deletes ENIs
- Removes security group rules
- Force detaches Internet Gateway

**Time:** 3-5 minutes

---

### Option 3: Targeted Destroy (Layer by Layer)

Destroys resources in the correct dependency order.

```bash
cd infrastructure
./targeted-destroy.sh
```

**Destroy order:**
1. Application Services (ECS, Tasks)
2. Load Balancer Components
3. EKS Add-ons
4. EKS Node Groups
5. EKS Cluster
6. Jenkins Resources
7. IAM Roles & Policies
8. ECR Repositories
9. SSM Parameters
10. Security Groups
11. Route Tables
12. Subnets
13. Internet Gateway
14. VPC

**Time:** 10-15 minutes (most thorough)

---

### Option 4: Manual Step-by-Step (Emergency Fallback)

If automated scripts fail, use AWS CLI directly:

#### Step 1: Scale Down Services
```bash
# ECS
aws ecs update-service \
  --cluster social-app-clone \
  --service social-app-clone \
  --desired-count 0

# EKS Node Group
aws eks update-nodegroup-config \
  --cluster-name social-app-clone-eks \
  --nodegroup-name social-app-clone-node-group \
  --scaling-config minSize=0,maxSize=3,desiredSize=0

sleep 60
```

#### Step 2: Clean Up Kubernetes Resources
```bash
aws eks update-kubeconfig --name social-app-clone-eks

kubectl delete svc --all-namespaces -l type=LoadBalancer
kubectl delete ingress --all-namespaces --all

sleep 30
```

#### Step 3: Clean Network Interfaces
```bash
VPC_ID="vpc-06a127144e9f55aad"  # Replace with your VPC ID

# List and delete ENIs
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | xargs -n1 aws ec2 delete-network-interface --network-interface-id
```

#### Step 4: Release Elastic IPs
```bash
aws ec2 describe-addresses \
  --filters "Name=domain,Values=vpc" \
  --query "Addresses[].AllocationId" \
  --output text | xargs -n1 aws ec2 release-address --allocation-id
```

#### Step 5: Detach Internet Gateway
```bash
IGW_ID="igw-0ede6d9e844d4ede1"  # Replace with your IGW ID
VPC_ID="vpc-06a127144e9f55aad"  # Replace with your VPC ID

aws ec2 detach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

#### Step 6: Run Terraform Destroy
```bash
terraform destroy
```

---

## 🔧 Enhanced Terraform Configuration

The Terraform configuration has been updated with:

### 1. Lifecycle Rules
```hcl
lifecycle {
  create_before_destroy = false
}
```

Applied to:
- Internet Gateway
- Subnets
- Load Balancers
- Target Groups
- ECS Services
- EKS Node Groups
- Elastic IPs

### 2. Faster Draining
- ALB Target Group deregistration delay: 30s (reduced from default 300s)
- ECS Service deployment settings optimized for faster scaling

### 3. Disable Protections
- ALB deletion protection: `false`
- ECR force delete: `true`

### 4. Null Resources for Pre-Destroy Cleanup

See [destroy-helper.tf](./destroy-helper.tf):
- Pre-destroy provisioners that run before resources are destroyed
- Automatic ECS service scaling to 0
- Automatic ALB target deregistration
- EKS cleanup (LoadBalancer services, ingresses)
- Network interface cleanup

---

## 📊 Troubleshooting

### Error: "DependencyViolation: Network has some mapped public address(es)"

**Cause:** Elastic IPs or NAT Gateways still attached to IGW

**Solution:**
```bash
./force-cleanup-network.sh
```

### Error: "The subnet has dependencies and cannot be deleted"

**Cause:** ENIs, NAT Gateways, or other resources in the subnet

**Solution:**
```bash
# List resources in subnet
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-00a611c23e31b3b53"

# Delete ENIs
./force-cleanup-network.sh
```

### Error: "Timeout waiting for EKS cluster to delete"

**Cause:** Kubernetes resources (LoadBalancers) creating AWS resources

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name social-app-clone-eks

# Delete all LoadBalancer services
kubectl delete svc --all-namespaces -l type=LoadBalancer

# Delete all ingresses
kubectl delete ingress --all-namespaces --all

# Wait 2 minutes, then retry destroy
sleep 120
terraform destroy
```

### Error: "Security group has dependent resources"

**Cause:** ENIs or other resources still using the security group

**Solution:**
```bash
SG_ID="sg-xxxxxxxxx"  # Replace with your SG ID

# Find what's using it
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=$SG_ID"

# Delete those resources first, then retry
```

---

## 🎯 Quick Reference

| Method | Time | Automation | Recommended For |
|--------|------|------------|-----------------|
| `safe-destroy.sh` | 5-10 min | Full | **Most users** |
| `force-cleanup-network.sh` + `terraform destroy` | 3-5 min | Partial | Quick cleanup |
| `targeted-destroy.sh` | 10-15 min | Full | Troubleshooting |
| Manual CLI | Varies | None | Emergency only |

---

## 📝 Best Practices

1. **Always use a destroy script** rather than plain `terraform destroy`
2. **Wait for services to scale down** before destroying network resources
3. **Check for orphaned resources** after destroy:
   ```bash
   # Check VPCs
   aws ec2 describe-vpcs --filters "Name=tag:Name,Values=social-app-clone-vpc"

   # Check EKS clusters
   aws eks list-clusters

   # Check ECS clusters
   aws ecs list-clusters
   ```
4. **Use AWS Console** to verify all resources are deleted
5. **Check billing** after a few hours to ensure no resources are running

---

## 🆘 Getting Help

If destroy fails multiple times:

1. Run `safe-destroy.sh` first
2. If that fails, try `targeted-destroy.sh`
3. Check CloudFormation stacks for stuck resources
4. Look for orphaned Lambda functions or API Gateways
5. As a last resort, manually delete resources via AWS Console in this order:
   - ECS Services → EKS Node Groups → EKS Cluster
   - Load Balancers → Target Groups
   - EC2 Instances → ENIs → EIPs
   - NAT Gateways → Route Tables → Subnets
   - Internet Gateway → VPC

---

## 📚 Additional Resources

- [AWS VPC Deletion Guide](https://docs.aws.amazon.com/vpc/latest/userguide/delete-vpc.html)
- [Terraform Destroy Documentation](https://www.terraform.io/docs/commands/destroy.html)
- [EKS Cluster Deletion](https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html)
