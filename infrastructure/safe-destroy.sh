#!/bin/bash

# ============================================================================
# SAFE TERRAFORM DESTROY WORKFLOW
# This script implements a robust destroy strategy with proper dependency handling
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Scale down EKS node group
scale_down_eks() {
    log_info "Step 1: Scaling down EKS node group..."

    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "social-app-clone-eks")
    NODE_GROUP_NAME=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[0]' --output text 2>/dev/null || echo "")

    if [ -n "$NODE_GROUP_NAME" ] && [ "$NODE_GROUP_NAME" != "None" ]; then
        log_info "  Found node group: $NODE_GROUP_NAME"
        log_info "  Scaling down to 0 nodes..."

        aws eks update-nodegroup-config \
            --cluster-name "$CLUSTER_NAME" \
            --nodegroup-name "$NODE_GROUP_NAME" \
            --scaling-config minSize=0,maxSize=3,desiredSize=0 \
            --region "$REGION" 2>/dev/null || log_warning "  Could not scale down node group"

        log_info "  Waiting for nodes to drain (60 seconds)..."
        sleep 60
        log_success "  Node group scaled down"
    else
        log_info "  No EKS node group found or already deleted"
    fi
}

# Step 2: Delete Kubernetes resources
cleanup_k8s_resources() {
    log_info "Step 2: Cleaning up Kubernetes resources..."

    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "social-app-clone-eks")

    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
        log_info "  Updating kubeconfig..."
        aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || log_warning "  Could not update kubeconfig"

        log_info "  Deleting LoadBalancer services..."
        kubectl delete svc --all-namespaces -l type=LoadBalancer --ignore-not-found=true 2>/dev/null || log_warning "  No LoadBalancer services found"

        log_info "  Deleting all ingresses..."
        kubectl delete ingress --all-namespaces --all --ignore-not-found=true 2>/dev/null || log_warning "  No ingresses found"

        log_info "  Deleting all deployments..."
        kubectl delete deployment --all-namespaces --all --ignore-not-found=true 2>/dev/null || log_warning "  No deployments found"

        log_info "  Waiting for resources to be cleaned up (30 seconds)..."
        sleep 30
        log_success "  Kubernetes resources cleaned up"
    else
        log_info "  EKS cluster not found or already deleted"
    fi
}

# Step 3: Scale down ECS service
scale_down_ecs() {
    log_info "Step 3: Scaling down ECS service..."

    CLUSTER_ARN=$(terraform output -raw ecs_cluster_arn 2>/dev/null || echo "")
    SERVICE_NAME="social-app-clone"

    if [ -n "$CLUSTER_ARN" ]; then
        log_info "  Scaling ECS service to 0 tasks..."
        aws ecs update-service \
            --cluster "$CLUSTER_ARN" \
            --service "$SERVICE_NAME" \
            --desired-count 0 \
            --region "$REGION" 2>/dev/null || log_warning "  Could not scale down ECS service"

        log_info "  Waiting for tasks to drain (45 seconds)..."
        sleep 45
        log_success "  ECS service scaled down"
    else
        log_info "  ECS cluster not found or already deleted"
    fi
}

# Step 4: Deregister ALB targets
deregister_alb_targets() {
    log_info "Step 4: Deregistering ALB targets..."

    ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || echo "")

    if [ -n "$ALB_ARN" ]; then
        TG_ARNS=$(aws elbv2 describe-target-groups \
            --load-balancer-arn "$ALB_ARN" \
            --query 'TargetGroups[].TargetGroupArn' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "")

        if [ -n "$TG_ARNS" ]; then
            for TG in $TG_ARNS; do
                log_info "  Processing target group: $TG"

                TARGETS=$(aws elbv2 describe-target-health \
                    --target-group-arn "$TG" \
                    --query 'TargetHealthDescriptions[].Target.Id' \
                    --output text \
                    --region "$REGION" 2>/dev/null || echo "")

                if [ -n "$TARGETS" ]; then
                    for TARGET in $TARGETS; do
                        log_info "    Deregistering target: $TARGET"
                        aws elbv2 deregister-targets \
                            --target-group-arn "$TG" \
                            --targets Id="$TARGET" \
                            --region "$REGION" 2>/dev/null || log_warning "    Could not deregister target"
                    done
                fi
            done

            log_info "  Waiting for target deregistration (30 seconds)..."
            sleep 30
            log_success "  ALB targets deregistered"
        else
            log_info "  No target groups found"
        fi
    else
        log_info "  ALB not found or already deleted"
    fi
}

# Step 5: Run network cleanup script
run_network_cleanup() {
    log_info "Step 5: Running network cleanup script..."

    if [ -f "$SCRIPT_DIR/force-cleanup-network.sh" ]; then
        log_info "  Executing force-cleanup-network.sh..."
        bash "$SCRIPT_DIR/force-cleanup-network.sh" || log_warning "  Network cleanup script encountered errors (continuing anyway)"
        log_success "  Network cleanup completed"
    else
        log_warning "  force-cleanup-network.sh not found, skipping..."
    fi
}

# Step 6: Terraform destroy with retry logic
terraform_destroy() {
    log_info "Step 6: Running Terraform destroy..."

    MAX_ATTEMPTS=3
    ATTEMPT=1

    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        log_info "  Destroy attempt $ATTEMPT of $MAX_ATTEMPTS..."

        if terraform destroy -auto-approve; then
            log_success "  Terraform destroy successful!"
            return 0
        else
            log_warning "  Terraform destroy attempt $ATTEMPT failed"

            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                log_info "  Waiting 60 seconds before retry..."
                sleep 60

                # Run network cleanup between retries
                log_info "  Running network cleanup before retry..."
                bash "$SCRIPT_DIR/force-cleanup-network.sh" 2>/dev/null || true
            fi

            ATTEMPT=$((ATTEMPT + 1))
        fi
    done

    log_error "  Terraform destroy failed after $MAX_ATTEMPTS attempts"
    return 1
}

# Step 7: Final verification
verify_cleanup() {
    log_info "Step 7: Verifying cleanup..."

    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=social-app-clone-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "None")

    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        log_success "  All resources successfully destroyed!"
        return 0
    else
        log_warning "  VPC still exists: $VPC_ID"
        log_warning "  Manual cleanup may be required"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "============================================"
    echo "  SAFE TERRAFORM DESTROY WORKFLOW"
    echo "============================================"
    echo ""

    log_info "This script will:"
    log_info "  1. Scale down EKS node group"
    log_info "  2. Clean up Kubernetes resources"
    log_info "  3. Scale down ECS service"
    log_info "  4. Deregister ALB targets"
    log_info "  5. Run network cleanup"
    log_info "  6. Execute terraform destroy (with retries)"
    log_info "  7. Verify complete cleanup"
    echo ""

    read -p "Continue with destroy? (yes/no): " -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_warning "Destroy cancelled by user"
        exit 0
    fi

    echo ""
    log_info "Starting destroy workflow..."
    echo ""

    # Execute steps
    scale_down_eks
    echo ""

    cleanup_k8s_resources
    echo ""

    scale_down_ecs
    echo ""

    deregister_alb_targets
    echo ""

    run_network_cleanup
    echo ""

    terraform_destroy
    DESTROY_EXIT_CODE=$?
    echo ""

    verify_cleanup
    VERIFY_EXIT_CODE=$?
    echo ""

    # Final summary
    echo "============================================"
    if [ $DESTROY_EXIT_CODE -eq 0 ] && [ $VERIFY_EXIT_CODE -eq 0 ]; then
        log_success "DESTROY WORKFLOW COMPLETED SUCCESSFULLY!"
    else
        log_warning "DESTROY WORKFLOW COMPLETED WITH WARNINGS"
        log_info "Please check the output above for details"

        if [ $VERIFY_EXIT_CODE -ne 0 ]; then
            echo ""
            log_info "To manually clean up remaining resources, run:"
            log_info "  ./force-cleanup-network.sh"
            log_info "  terraform destroy -target=aws_vpc.main"
        fi
    fi
    echo "============================================"
    echo ""
}

# Run main function
main
