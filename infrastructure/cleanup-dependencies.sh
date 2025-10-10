#!/bin/bash

echo "🧹 AWS Infrastructure Cleanup Script"
echo "====================================="
echo ""
echo "⚠️  This will clean up all AWS resources blocking Terraform destroy"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION="us-east-1"

# Get VPC ID from Terraform state
VPC_ID=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_vpc") | .values.id' 2>/dev/null)

if [ -z "$VPC_ID" ]; then
    echo -e "${YELLOW}⚠️  Could not find VPC from Terraform state${NC}"
    echo "Looking for VPCs with tag Name=*social-app*"
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=*social-app*" --query 'Vpcs[0].VpcId' --output text)
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
    echo -e "${RED}❌ Could not find VPC. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found VPC: $VPC_ID${NC}"
echo ""

# Function to delete ENIs
delete_enis() {
    echo "🔍 Finding and deleting Elastic Network Interfaces..."

    ENI_IDS=$(aws ec2 describe-network-interfaces \
        --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces[?Status!=`in-use`].NetworkInterfaceId' \
        --output text)

    if [ -z "$ENI_IDS" ]; then
        echo -e "${YELLOW}ℹ️  No detached ENIs found${NC}"
    else
        for ENI_ID in $ENI_IDS; do
            echo "Deleting ENI: $ENI_ID"
            aws ec2 delete-network-interface --network-interface-id $ENI_ID --region $AWS_REGION 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Deleted ENI: $ENI_ID${NC}"
            else
                echo -e "${RED}❌ Failed to delete ENI: $ENI_ID${NC}"
            fi
        done
    fi

    # Check for in-use ENIs (need to be detached first)
    IN_USE_ENIS=$(aws ec2 describe-network-interfaces \
        --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=in-use" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text)

    if [ ! -z "$IN_USE_ENIS" ]; then
        echo -e "${YELLOW}⚠️  Found in-use ENIs (likely attached to running instances):${NC}"
        for ENI_ID in $IN_USE_ENIS; do
            echo "   - $ENI_ID"

            # Get attachment info
            ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
                --network-interface-ids $ENI_ID \
                --region $AWS_REGION \
                --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                --output text)

            if [ ! -z "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
                echo "   Detaching from attachment: $ATTACHMENT_ID"
                aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $AWS_REGION --force
                sleep 2
                aws ec2 delete-network-interface --network-interface-id $ENI_ID --region $AWS_REGION
            fi
        done
    fi
}

# Function to release Elastic IPs
release_elastic_ips() {
    echo ""
    echo "🔍 Finding and releasing Elastic IPs..."

    # Get all Elastic IPs in the VPC
    EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[].AllocationId' \
        --output text)

    if [ -z "$EIP_ALLOC_IDS" ]; then
        echo -e "${YELLOW}ℹ️  No Elastic IPs found${NC}"
    else
        for ALLOC_ID in $EIP_ALLOC_IDS; do
            # Get association ID if associated
            ASSOC_ID=$(aws ec2 describe-addresses \
                --allocation-ids $ALLOC_ID \
                --region $AWS_REGION \
                --query 'Addresses[0].AssociationId' \
                --output text)

            # Disassociate if needed
            if [ ! -z "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
                echo "Disassociating EIP: $ALLOC_ID"
                aws ec2 disassociate-address --association-id $ASSOC_ID --region $AWS_REGION
                sleep 2
            fi

            # Release the EIP
            echo "Releasing EIP: $ALLOC_ID"
            aws ec2 release-address --allocation-id $ALLOC_ID --region $AWS_REGION
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Released EIP: $ALLOC_ID${NC}"
            else
                echo -e "${RED}❌ Failed to release EIP: $ALLOC_ID (might be managed by Terraform)${NC}"
            fi
        done
    fi
}

# Function to delete NAT Gateways
delete_nat_gateways() {
    echo ""
    echo "🔍 Finding and deleting NAT Gateways..."

    NAT_GW_IDS=$(aws ec2 describe-nat-gateways \
        --region $AWS_REGION \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'NatGateways[].NatGatewayId' \
        --output text)

    if [ -z "$NAT_GW_IDS" ]; then
        echo -e "${YELLOW}ℹ️  No NAT Gateways found${NC}"
    else
        for NAT_ID in $NAT_GW_IDS; do
            echo "Deleting NAT Gateway: $NAT_ID"
            aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region $AWS_REGION
            echo -e "${GREEN}✅ Initiated deletion of NAT Gateway: $NAT_ID${NC}"
        done
        echo -e "${YELLOW}⏳ Waiting 30 seconds for NAT Gateways to delete...${NC}"
        sleep 30
    fi
}

# Function to terminate EC2 instances
terminate_instances() {
    echo ""
    echo "🔍 Finding and terminating EC2 instances in VPC..."

    INSTANCE_IDS=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)

    if [ -z "$INSTANCE_IDS" ]; then
        echo -e "${YELLOW}ℹ️  No EC2 instances found${NC}"
    else
        echo -e "${YELLOW}⚠️  Found EC2 instances:${NC}"
        for INSTANCE_ID in $INSTANCE_IDS; do
            INSTANCE_NAME=$(aws ec2 describe-instances \
                --instance-ids $INSTANCE_ID \
                --region $AWS_REGION \
                --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value' \
                --output text)
            echo "   - $INSTANCE_ID ($INSTANCE_NAME)"
        done
        echo ""
        read -p "Terminate these instances? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $AWS_REGION
            echo -e "${GREEN}✅ Initiated termination${NC}"
            echo -e "${YELLOW}⏳ Waiting 60 seconds for instances to terminate...${NC}"
            sleep 60
        fi
    fi
}

# Function to delete ECS services and tasks
delete_ecs_resources() {
    echo ""
    echo "🔍 Finding and deleting ECS resources..."

    # Find ECS cluster
    CLUSTER_NAME=$(aws ecs list-clusters --region $AWS_REGION --query 'clusterArns[?contains(@, `social-app`)]' --output text | awk -F'/' '{print $2}')

    if [ ! -z "$CLUSTER_NAME" ]; then
        echo "Found ECS Cluster: $CLUSTER_NAME"

        # List services
        SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --region $AWS_REGION --query 'serviceArns[]' --output text)

        for SERVICE_ARN in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $3}')
            echo "Scaling down service: $SERVICE_NAME to 0"
            aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION >/dev/null 2>&1

            echo "Deleting service: $SERVICE_NAME"
            aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force --region $AWS_REGION >/dev/null 2>&1
        done

        # Wait for services to drain
        if [ ! -z "$SERVICES" ]; then
            echo -e "${YELLOW}⏳ Waiting 30 seconds for services to drain...${NC}"
            sleep 30
        fi
    fi
}

# Function to delete load balancers
delete_load_balancers() {
    echo ""
    echo "🔍 Finding and deleting Load Balancers..."

    LB_ARNS=$(aws elbv2 describe-load-balancers \
        --region $AWS_REGION \
        --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
        --output text)

    if [ -z "$LB_ARNS" ]; then
        echo -e "${YELLOW}ℹ️  No Load Balancers found${NC}"
    else
        for LB_ARN in $LB_ARNS; do
            LB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerName' --output text)
            echo "Deleting Load Balancer: $LB_NAME"
            aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN --region $AWS_REGION
            echo -e "${GREEN}✅ Deleted LB: $LB_NAME${NC}"
        done
        echo -e "${YELLOW}⏳ Waiting 30 seconds for LBs to delete...${NC}"
        sleep 30
    fi
}

# Main execution
echo "Starting cleanup process..."
echo ""

delete_ecs_resources
delete_load_balancers
terminate_instances
delete_nat_gateways
release_elastic_ips
delete_enis

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "Now you can run:"
echo "  cd infrastructure"
echo "  terraform destroy -auto-approve"
echo ""
echo "If you still get errors, wait 2-3 minutes and try again."
