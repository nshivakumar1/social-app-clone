#!/bin/bash

# Force cleanup of AWS network dependencies before terraform destroy
# This script handles ENIs, NAT gateways, and other dependencies

set -e

VPC_ID="vpc-06a127144e9f55aad"
IGW_ID="igw-0ede6d9e844d4ede1"
SUBNET_IDS=("subnet-00a611c23e31b3b53" "subnet-0d8772ccadb4124fe")

echo "================================================"
echo "Force Network Cleanup Script"
echo "================================================"
echo ""

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install it first."
        exit 1
    fi
    echo "✅ AWS CLI found"
}

# Function to release Elastic IPs
release_elastic_ips() {
    echo ""
    echo "Step 1: Releasing Elastic IPs..."
    echo "-----------------------------------"

    EIP_ALLOCS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query "Addresses[?AssociationId!=null].AllocationId" --output text)

    if [ -z "$EIP_ALLOCS" ]; then
        echo "No Elastic IPs found to release"
    else
        for ALLOC_ID in $EIP_ALLOCS; do
            echo "Releasing EIP: $ALLOC_ID"
            aws ec2 release-address --allocation-id "$ALLOC_ID" 2>/dev/null || echo "  ⚠️  Could not release $ALLOC_ID (may be already released)"
        done
    fi
}

# Function to delete NAT Gateways
delete_nat_gateways() {
    echo ""
    echo "Step 2: Deleting NAT Gateways..."
    echo "-----------------------------------"

    NAT_GWS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" --query "NatGateways[].NatGatewayId" --output text)

    if [ -z "$NAT_GWS" ]; then
        echo "No NAT Gateways found"
    else
        for NAT_ID in $NAT_GWS; do
            echo "Deleting NAT Gateway: $NAT_ID"
            aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID"
        done

        echo "Waiting for NAT Gateways to be deleted (this may take a few minutes)..."
        for NAT_ID in $NAT_GWS; do
            aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID" 2>/dev/null || echo "  ⚠️  NAT Gateway $NAT_ID deletion timeout"
        done
        echo "✅ NAT Gateways deleted"
    fi
}

# Function to detach and delete network interfaces
cleanup_network_interfaces() {
    echo ""
    echo "Step 3: Cleaning up Network Interfaces..."
    echo "-----------------------------------"

    for SUBNET_ID in "${SUBNET_IDS[@]}"; do
        echo "Checking subnet: $SUBNET_ID"

        ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$SUBNET_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text)

        if [ -z "$ENI_IDS" ]; then
            echo "  No ENIs found in this subnet"
        else
            for ENI_ID in $ENI_IDS; do
                echo "  Processing ENI: $ENI_ID"

                # Check if attached
                ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)

                if [ "$ATTACHMENT_ID" != "None" ] && [ -n "$ATTACHMENT_ID" ]; then
                    echo "    Detaching ENI..."
                    aws ec2 detach-network-interface --attachment-id "$ATTACHMENT_ID" --force 2>/dev/null || echo "    ⚠️  Could not detach"
                    sleep 5
                fi

                # Try to delete
                echo "    Deleting ENI..."
                aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null || echo "    ⚠️  Could not delete (may be managed by AWS service)"
            done
        fi
    done
}

# Function to check for EKS resources
check_eks_resources() {
    echo ""
    echo "Step 4: Checking for EKS resources..."
    echo "-----------------------------------"

    EKS_CLUSTERS=$(aws eks list-clusters --query "clusters[]" --output text)

    if [ -z "$EKS_CLUSTERS" ]; then
        echo "No EKS clusters found"
    else
        echo "⚠️  Found EKS clusters: $EKS_CLUSTERS"
        echo "⚠️  You need to delete EKS clusters first using terraform or manually"
        echo ""
        read -p "Have you already deleted the EKS cluster? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Please delete EKS cluster first, then run this script again"
            exit 1
        fi
    fi
}

# Function to check for Load Balancers
cleanup_load_balancers() {
    echo ""
    echo "Step 5: Checking for Load Balancers..."
    echo "-----------------------------------"

    # Application/Network Load Balancers (ELBv2)
    LBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")

    if [ -n "$LBS" ]; then
        for LB_ARN in $LBS; do
            LB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" --query "LoadBalancers[0].LoadBalancerName" --output text)
            echo "Found ALB/NLB: $LB_NAME"
            echo "  Deleting..."
            aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN"
        done
    fi

    # Classic Load Balancers (created by Kubernetes)
    CLASSIC_LBS=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text 2>/dev/null || echo "")

    if [ -n "$CLASSIC_LBS" ]; then
        echo "Found Classic Load Balancers (likely from Kubernetes):"
        for CLB_NAME in $CLASSIC_LBS; do
            echo "  Deleting Classic LB: $CLB_NAME"
            aws elb delete-load-balancer --load-balancer-name "$CLB_NAME"
        done
    fi

    if [ -z "$LBS" ] && [ -z "$CLASSIC_LBS" ]; then
        echo "No Load Balancers found"
    else
        echo "Waiting for Load Balancers to be deleted (60 seconds)..."
        sleep 60
    fi
}

# Function to cleanup security group rules
cleanup_security_groups() {
    echo ""
    echo "Step 6: Cleaning up Security Group dependencies..."
    echo "-----------------------------------"

    SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)

    if [ -z "$SG_IDS" ]; then
        echo "No custom security groups found"
    else
        # First pass: remove all ingress rules
        for SG_ID in $SG_IDS; do
            echo "Removing ingress rules from: $SG_ID"
            aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --ip-permissions "$(aws ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].IpPermissions' --output json)" 2>/dev/null || echo "  No ingress rules to remove"
        done

        # Second pass: remove all egress rules
        for SG_ID in $SG_IDS; do
            echo "Removing egress rules from: $SG_ID"
            aws ec2 revoke-security-group-egress --group-id "$SG_ID" --ip-permissions "$(aws ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" 2>/dev/null || echo "  No egress rules to remove"
        done
    fi
}

# Function to force detach internet gateway
force_detach_igw() {
    echo ""
    echo "Step 7: Force detaching Internet Gateway..."
    echo "-----------------------------------"

    echo "Attempting to detach IGW: $IGW_ID from VPC: $VPC_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null && echo "✅ Successfully detached" || echo "⚠️  Could not detach (may already be detached)"
}

# Main execution
main() {
    check_aws_cli

    echo ""
    echo "⚠️  WARNING: This script will forcefully cleanup network resources"
    echo "VPC: $VPC_ID"
    echo "IGW: $IGW_ID"
    echo "Subnets: ${SUBNET_IDS[*]}"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi

    release_elastic_ips
    delete_nat_gateways
    cleanup_load_balancers
    check_eks_resources
    cleanup_network_interfaces
    cleanup_security_groups
    force_detach_igw

    echo ""
    echo "================================================"
    echo "✅ Cleanup complete!"
    echo "================================================"
    echo ""
    echo "You can now run: terraform destroy"
    echo ""
}

main
