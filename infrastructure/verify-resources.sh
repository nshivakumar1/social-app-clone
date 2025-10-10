#!/bin/bash

# ============================================================================
# VERIFY AWS RESOURCES BEFORE DESTROY
# Shows current state of all resources that need to be cleaned up
# ============================================================================

REGION="${AWS_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_found() {
    echo -e "${YELLOW}✓${NC}  $1"
}

log_clear() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1"
}

echo ""
echo "============================================"
echo "  AWS Resources Verification"
echo "  Region: $REGION"
echo "============================================"

# VPC
log_header "VPC Resources"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=social-app-clone-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    log_found "VPC ID: $VPC_ID"
else
    log_clear "No VPC found"
fi

# Internet Gateway
log_header "Internet Gateway"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "None")

    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        log_found "Internet Gateway: $IGW_ID"
    else
        log_clear "No Internet Gateway attached"
    fi
else
    log_clear "No VPC, skipping IGW check"
fi

# Subnets
log_header "Subnets"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    SUBNET_COUNT=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets | length(@)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")

    if [ "$SUBNET_COUNT" -gt 0 ]; then
        log_found "$SUBNET_COUNT subnet(s) found"
        aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone]' \
            --output table \
            --region "$REGION" 2>/dev/null | tail -n +3
    else
        log_clear "No subnets found"
    fi
else
    log_clear "No VPC, skipping subnet check"
fi

# Network Interfaces
log_header "Network Interfaces (ENIs)"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces | length(@)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")

    if [ "$ENI_COUNT" -gt 0 ]; then
        log_found "$ENI_COUNT ENI(s) found"
        aws ec2 describe-network-interfaces \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]' \
            --output table \
            --region "$REGION" 2>/dev/null | tail -n +3
    else
        log_clear "No ENIs found"
    fi
else
    log_clear "No VPC, skipping ENI check"
fi

# Elastic IPs
log_header "Elastic IPs"
EIP_COUNT=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses | length(@)' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "0")

if [ "$EIP_COUNT" -gt 0 ]; then
    log_found "$EIP_COUNT Elastic IP(s) allocated"
    aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[].[AllocationId,PublicIp,AssociationId]' \
        --output table \
        --region "$REGION" 2>/dev/null | tail -n +3
else
    log_clear "No Elastic IPs allocated"
fi

# NAT Gateways
log_header "NAT Gateways"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    NAT_COUNT=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'NatGateways | length(@)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")

    if [ "$NAT_COUNT" -gt 0 ]; then
        log_found "$NAT_COUNT NAT Gateway(s) found"
        aws ec2 describe-nat-gateways \
            --filter "Name=vpc-id,Values=$VPC_ID" \
            --query 'NatGateways[].[NatGatewayId,State,SubnetId]' \
            --output table \
            --region "$REGION" 2>/dev/null | tail -n +3
    else
        log_clear "No NAT Gateways found"
    fi
else
    log_clear "No VPC, skipping NAT Gateway check"
fi

# Load Balancers
log_header "Load Balancers"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    LB_COUNT=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?VpcId=='$VPC_ID'] | length(@)" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")

    if [ "$LB_COUNT" -gt 0 ]; then
        log_found "$LB_COUNT Load Balancer(s) found"
        aws elbv2 describe-load-balancers \
            --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerName,Type,State.Code]" \
            --output table \
            --region "$REGION" 2>/dev/null | tail -n +3
    else
        log_clear "No Load Balancers found"
    fi
else
    log_clear "No VPC, skipping Load Balancer check"
fi

# ECS Clusters
log_header "ECS Clusters"
ECS_CLUSTERS=$(aws ecs list-clusters \
    --query 'clusterArns[]' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ -n "$ECS_CLUSTERS" ]; then
    CLUSTER_COUNT=$(echo "$ECS_CLUSTERS" | wc -w | xargs)
    log_found "$CLUSTER_COUNT ECS cluster(s) found"

    for CLUSTER in $ECS_CLUSTERS; do
        CLUSTER_NAME=$(echo "$CLUSTER" | awk -F/ '{print $NF}')
        SERVICE_COUNT=$(aws ecs list-services \
            --cluster "$CLUSTER" \
            --query 'serviceArns | length(@)' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "0")

        TASK_COUNT=$(aws ecs list-tasks \
            --cluster "$CLUSTER" \
            --query 'taskArns | length(@)' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "0")

        echo "  • $CLUSTER_NAME: $SERVICE_COUNT service(s), $TASK_COUNT task(s)"
    done
else
    log_clear "No ECS clusters found"
fi

# EKS Clusters
log_header "EKS Clusters"
EKS_CLUSTERS=$(aws eks list-clusters \
    --query 'clusters[]' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ -n "$EKS_CLUSTERS" ]; then
    CLUSTER_COUNT=$(echo "$EKS_CLUSTERS" | wc -w | xargs)
    log_found "$CLUSTER_COUNT EKS cluster(s) found"

    for CLUSTER in $EKS_CLUSTERS; do
        STATUS=$(aws eks describe-cluster \
            --name "$CLUSTER" \
            --query 'cluster.status' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "UNKNOWN")

        NODE_GROUPS=$(aws eks list-nodegroups \
            --cluster-name "$CLUSTER" \
            --query 'nodegroups | length(@)' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "0")

        echo "  • $CLUSTER: Status=$STATUS, NodeGroups=$NODE_GROUPS"
    done
else
    log_clear "No EKS clusters found"
fi

# EC2 Instances
log_header "EC2 Instances"
INSTANCE_COUNT=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped,stopping" \
    --query 'Reservations[].Instances | length(@)' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "0")

if [ "$INSTANCE_COUNT" -gt 0 ]; then
    log_found "$INSTANCE_COUNT EC2 instance(s) found"
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running,stopped,stopping" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table \
        --region "$REGION" 2>/dev/null | tail -n +3
else
    log_clear "No EC2 instances found"
fi

# Security Groups
log_header "Security Groups"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    SG_COUNT=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?GroupName!=`default`] | length(@)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")

    if [ "$SG_COUNT" -gt 0 ]; then
        log_found "$SG_COUNT custom security group(s) found"
    else
        log_clear "No custom security groups (only default)"
    fi
else
    log_clear "No VPC, skipping security group check"
fi

# Summary
log_header "Summary"

ISSUES=0

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "VPC exists: Resources need to be destroyed"
    ISSUES=1
fi

if [ "$ENI_COUNT" -gt 0 ]; then
    log_error "ENIs exist - will block subnet deletion"
    ISSUES=1
fi

if [ "$EIP_COUNT" -gt 0 ]; then
    log_error "Elastic IPs allocated - will block IGW detachment"
    ISSUES=1
fi

if [ "$NAT_COUNT" -gt 0 ]; then
    log_error "NAT Gateways exist - will block IGW detachment"
    ISSUES=1
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    log_clear "All clear! No resources found."
    echo ""
    echo "You can safely run: terraform destroy"
else
    log_found "Resources found that need cleanup"
    echo ""
    echo "Recommended action:"
    echo "  ./safe-destroy.sh"
    echo ""
    echo "Or for quick cleanup:"
    echo "  ./force-cleanup-network.sh"
    echo "  terraform destroy"
fi

echo ""
echo "============================================"
