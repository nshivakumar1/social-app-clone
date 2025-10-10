# 🧹 Terraform Destroy - Complete Cleanup Guide

Guide to properly destroy all AWS infrastructure when Terraform fails with dependency errors.

---

## 🚨 Common Terraform Destroy Errors

### Error 1: Subnet Dependencies
```
Error: deleting EC2 Subnet: has dependencies and cannot be deleted
```
**Cause**: ENIs (Elastic Network Interfaces) still attached to subnet

### Error 2: Internet Gateway Dependencies
```
Error: detaching EC2 Internet Gateway: has some mapped public address(es)
```
**Cause**: Elastic IPs still associated with VPC

---

## ✅ Quick Fix (Automated)

### Option 1: Use Cleanup Script

```bash
cd infrastructure
./cleanup-dependencies.sh
```

This script will:
1. ✅ Delete ECS services and tasks
2. ✅ Delete Load Balancers
3. ✅ Terminate EC2 instances
4. ✅ Delete NAT Gateways
5. ✅ Release Elastic IPs
6. ✅ Delete ENIs (Network Interfaces)

Then run:
```bash
terraform destroy -auto-approve
```

---

## 🔧 Manual Cleanup (Step-by-Step)

If the script doesn't work, follow these manual steps:

### Step 1: Delete ECS Resources

```bash
# List clusters
aws ecs list-clusters --region us-east-1

# For each cluster, list services
aws ecs list-services --cluster social-app-clone --region us-east-1

# Delete each service (example)
aws ecs delete-service \
  --cluster social-app-clone \
  --service social-app-clone \
  --force \
  --region us-east-1

# Wait for services to drain (2-3 minutes)
# Then delete cluster
aws ecs delete-cluster --cluster social-app-clone --region us-east-1
```

### Step 2: Delete Load Balancers

```bash
# List load balancers
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `social-app`)].LoadBalancerArn'

# Delete load balancer (use ARN from above)
aws elbv2 delete-load-balancer \
  --load-balancer-arn <ARN> \
  --region us-east-1

# Delete target groups
aws elbv2 describe-target-groups --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `social-app`)].TargetGroupArn'

aws elbv2 delete-target-group \
  --target-group-arn <ARN> \
  --region us-east-1
```

### Step 3: Terminate EC2 Instances

```bash
# List instances
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Name,Values=*Jenkins*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]'

# Terminate instance
aws ec2 terminate-instances \
  --instance-ids <INSTANCE_ID> \
  --region us-east-1

# Wait for termination (60-90 seconds)
aws ec2 wait instance-terminated \
  --instance-ids <INSTANCE_ID> \
  --region us-east-1
```

### Step 4: Release Elastic IPs

```bash
# List Elastic IPs
aws ec2 describe-addresses --region us-east-1

# For each EIP, disassociate if needed
aws ec2 disassociate-address \
  --association-id <ASSOCIATION_ID> \
  --region us-east-1

# Then release
aws ec2 release-address \
  --allocation-id <ALLOCATION_ID> \
  --region us-east-1
```

### Step 5: Delete NAT Gateways

```bash
# List NAT Gateways
aws ec2 describe-nat-gateways --region us-east-1 \
  --filter "Name=state,Values=available"

# Delete NAT Gateway
aws ec2 delete-nat-gateway \
  --nat-gateway-id <NAT_GW_ID> \
  --region us-east-1

# Wait for deletion (30-60 seconds)
```

### Step 6: Delete Network Interfaces (ENIs)

```bash
# List ENIs in your VPC
VPC_ID=$(aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Name,Values=*social-app*" \
  --query 'Vpcs[0].VpcId' --output text)

aws ec2 describe-network-interfaces --region us-east-1 \
  --filters "Name=vpc-id,Values=$VPC_ID"

# For each ENI (skip the ones in-use by running instances)
aws ec2 delete-network-interface \
  --network-interface-id <ENI_ID> \
  --region us-east-1
```

### Step 7: Delete Security Groups

```bash
# List security groups (except default)
aws ec2 describe-security-groups --region us-east-1 \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId'

# Delete each security group
aws ec2 delete-security-group \
  --group-id <SG_ID> \
  --region us-east-1
```

### Step 8: Run Terraform Destroy

```bash
cd infrastructure
terraform destroy -auto-approve
```

---

## 🎯 Proper Order of Deletion

**Always delete in this order** to avoid dependency errors:

1. ECS Services & Tasks
2. Load Balancers & Target Groups
3. EC2 Instances
4. NAT Gateways
5. Elastic IPs
6. Network Interfaces (ENIs)
7. Security Groups (non-default)
8. Subnets (via Terraform)
9. Internet Gateway (via Terraform)
10. Route Tables (via Terraform)
11. VPC (via Terraform)

---

## 🔍 Troubleshooting

### Issue: ENI still attached

```bash
# Find what's using the ENI
aws ec2 describe-network-interfaces \
  --network-interface-ids <ENI_ID> \
  --region us-east-1

# Force detach
aws ec2 detach-network-interface \
  --attachment-id <ATTACHMENT_ID> \
  --force \
  --region us-east-1

# Then delete
aws ec2 delete-network-interface \
  --network-interface-id <ENI_ID> \
  --region us-east-1
```

### Issue: "Resource is in use"

Wait 2-3 minutes and try again. AWS needs time to propagate deletions.

### Issue: EIP won't release

```bash
# Check what's using it
aws ec2 describe-addresses \
  --allocation-ids <ALLOC_ID> \
  --region us-east-1

# Force disassociate
aws ec2 disassociate-address \
  --association-id <ASSOC_ID> \
  --region us-east-1

# Wait 10 seconds
sleep 10

# Release
aws ec2 release-address \
  --allocation-id <ALLOC_ID> \
  --region us-east-1
```

### Issue: Load Balancer won't delete

```bash
# Force delete
aws elbv2 delete-load-balancer \
  --load-balancer-arn <ARN> \
  --region us-east-1

# Wait 30-60 seconds
# Then check if it's gone
aws elbv2 describe-load-balancers --region us-east-1
```

---

## 💡 Prevention Tips

### 1. Use Terraform State Lock

Add to your `main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "social-app/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 2. Tag Everything

All resources should have tags:
```hcl
tags = {
  Project     = "social-app-clone"
  ManagedBy   = "Terraform"
  Environment = "production"
}
```

### 3. Use Lifecycle Rules

For critical resources:
```hcl
lifecycle {
  prevent_destroy = true
}
```

---

## 🚀 Clean Destroy Command Sequence

```bash
# 1. Run cleanup script
cd infrastructure
./cleanup-dependencies.sh

# 2. Wait for AWS to propagate changes
echo "Waiting 60 seconds..."
sleep 60

# 3. Destroy with Terraform
terraform destroy -auto-approve

# 4. If it fails, run targeted destroys
terraform destroy -target=aws_ecs_cluster.main -auto-approve
terraform destroy -target=aws_lb.main -auto-approve
terraform destroy -target=aws_instance.jenkins -auto-approve
terraform destroy -target=aws_eip.jenkins -auto-approve

# 5. Then destroy everything else
terraform destroy -auto-approve

# 6. Verify nothing is left
aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Name,Values=*social-app*"
```

---

## 📋 Post-Destroy Checklist

After successful destroy:

- [ ] No EC2 instances running
- [ ] No ECS clusters exist
- [ ] No Load Balancers
- [ ] No Elastic IPs allocated
- [ ] No NAT Gateways
- [ ] No ENIs (except default)
- [ ] No VPCs (except default)
- [ ] CloudWatch log groups deleted
- [ ] ECR repositories emptied/deleted
- [ ] IAM roles deleted (if not used elsewhere)
- [ ] S3 buckets emptied (Terraform state)
- [ ] Systems Manager parameters removed

### Verify:

```bash
# Check EC2
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=social-app-clone"

# Check ECS
aws ecs list-clusters --region us-east-1

# Check Load Balancers
aws elbv2 describe-load-balancers --region us-east-1

# Check Elastic IPs
aws ec2 describe-addresses --region us-east-1

# Check VPCs
aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Name,Values=*social-app*"
```

---

## 💰 Cost Savings After Destroy

After destroying, you'll save approximately:

- EC2 (Jenkins): ~$30/month
- ECS Fargate: ~$25-40/month
- Load Balancer: ~$20/month
- NAT Gateway: ~$30/month (if used)
- Data Transfer: ~$5-15/month

**Total savings**: ~$110-135/month

---

## 🔄 Re-Deploy After Destroy

To re-deploy:

```bash
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```

Your Terraform configuration is still intact, so you can always recreate!

---

## 🆘 Emergency: Stuck Resource

If a resource absolutely won't delete:

### Option 1: AWS Console Manual Delete

1. Go to AWS Console
2. Navigate to the service (EC2, VPC, etc.)
3. Find the resource by tag or ID
4. Force delete from console

### Option 2: Remove from Terraform State

```bash
# Remove from state (doesn't delete from AWS!)
terraform state rm aws_instance.jenkins

# Then manually delete from AWS Console
# Then continue with destroy
terraform destroy -auto-approve
```

### Option 3: Contact AWS Support

For truly stuck resources, AWS Support can force-delete them.

---

## ✅ Success Indicators

You've successfully destroyed when:

```bash
$ terraform show
No state.

$ aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=social-app-clone" \
  | jq '.Reservations'
[]
```

---

**Remember**: Always ensure you have backups before destroying infrastructure!
