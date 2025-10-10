#!/bin/bash

# ============================================================================
# TARGETED TERRAFORM DESTROY
# Destroy resources in the correct order to avoid dependency issues
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

destroy_target() {
    local target=$1
    local description=$2

    log_info "Destroying: $description"
    if terraform destroy -target="$target" -auto-approve; then
        log_success "  ✓ $description destroyed"
        return 0
    else
        log_warning "  ⚠ Failed to destroy $description (may not exist)"
        return 1
    fi
}

main() {
    echo ""
    echo "============================================"
    echo "  TARGETED TERRAFORM DESTROY"
    echo "============================================"
    echo ""

    read -p "This will destroy resources in the correct order. Continue? (yes/no): " -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cancelled by user"
        exit 0
    fi

    echo ""
    log_info "Starting targeted destroy in dependency order..."
    echo ""

    # Layer 1: Application Services
    log_info "=== Layer 1: Application Services ==="
    destroy_target "aws_ecs_service.main" "ECS Service"
    sleep 10

    # Layer 2: Load Balancer Components
    log_info ""
    log_info "=== Layer 2: Load Balancer Components ==="
    destroy_target "aws_alb_listener.front_end" "ALB Listener"
    destroy_target "aws_alb_target_group.app" "ALB Target Group"
    destroy_target "aws_alb.main" "Application Load Balancer"
    sleep 10

    # Layer 3: ECS Resources
    log_info ""
    log_info "=== Layer 3: ECS Resources ==="
    destroy_target "aws_ecs_task_definition.app" "ECS Task Definition"
    destroy_target "aws_ecs_cluster.main" "ECS Cluster"
    destroy_target "aws_cloudwatch_log_group.ecs" "CloudWatch Log Group"

    # Layer 4: EKS Add-ons
    log_info ""
    log_info "=== Layer 4: EKS Add-ons ==="
    destroy_target "aws_eks_addon.coredns" "EKS CoreDNS Add-on"
    destroy_target "aws_eks_addon.kube_proxy" "EKS Kube-Proxy Add-on"
    destroy_target "aws_eks_addon.vpc_cni" "EKS VPC CNI Add-on"
    sleep 10

    # Layer 5: EKS Node Group
    log_info ""
    log_info "=== Layer 5: EKS Node Group ==="
    destroy_target "aws_eks_node_group.main" "EKS Node Group"
    sleep 30

    # Layer 6: EKS Cluster
    log_info ""
    log_info "=== Layer 6: EKS Cluster ==="
    destroy_target "aws_eks_cluster.main" "EKS Cluster"
    sleep 30

    # Layer 7: Jenkins Resources
    log_info ""
    log_info "=== Layer 7: Jenkins Resources ==="
    destroy_target "aws_eip.jenkins" "Jenkins Elastic IP"
    destroy_target "aws_instance.jenkins" "Jenkins EC2 Instance"
    destroy_target "aws_iam_instance_profile.jenkins_profile" "Jenkins Instance Profile"
    destroy_target "aws_iam_role_policy.jenkins_policy" "Jenkins IAM Policy"
    destroy_target "aws_iam_role.jenkins_role" "Jenkins IAM Role"

    # Layer 8: IAM Roles and Policies
    log_info ""
    log_info "=== Layer 8: IAM Roles and Policies ==="
    destroy_target "aws_iam_role_policy_attachment.ecs_task_execution_role" "ECS Task Execution Policy Attachment"
    destroy_target "aws_iam_role.ecs_task_execution_role" "ECS Task Execution Role"
    destroy_target "aws_iam_role_policy_attachment.eks_worker_node_policy" "EKS Worker Node Policy"
    destroy_target "aws_iam_role_policy_attachment.eks_cni_policy" "EKS CNI Policy"
    destroy_target "aws_iam_role_policy_attachment.eks_container_registry_policy" "EKS Container Registry Policy"
    destroy_target "aws_iam_role.eks_node_role" "EKS Node Role"
    destroy_target "aws_iam_role_policy_attachment.eks_cluster_policy" "EKS Cluster Policy"
    destroy_target "aws_iam_role.eks_cluster_role" "EKS Cluster Role"

    # Layer 9: ECR Repository
    log_info ""
    log_info "=== Layer 9: ECR Repository ==="
    destroy_target "aws_ecr_repository.app" "ECR Repository"

    # Layer 10: SSM Parameters
    log_info ""
    log_info "=== Layer 10: SSM Parameters ==="
    destroy_target "aws_ssm_parameter.jira_url" "Jira URL Parameter"
    destroy_target "aws_ssm_parameter.jira_username" "Jira Username Parameter"
    destroy_target "aws_ssm_parameter.jira_api_token" "Jira API Token Parameter"
    destroy_target "aws_ssm_parameter.jira_project_key" "Jira Project Key Parameter"
    destroy_target "aws_ssm_parameter.jira_issue_type" "Jira Issue Type Parameter"

    # Layer 11: Security Groups
    log_info ""
    log_info "=== Layer 11: Security Groups ==="
    destroy_target "aws_security_group.ecs" "ECS Security Group"
    destroy_target "aws_security_group.alb" "ALB Security Group"
    destroy_target "aws_security_group.jenkins" "Jenkins Security Group"
    sleep 10

    # Layer 12: Network - Route Tables
    log_info ""
    log_info "=== Layer 12: Route Tables ==="
    destroy_target "aws_route_table_association.public" "Route Table Associations"
    destroy_target "aws_route_table.public" "Public Route Table"
    sleep 5

    # Layer 13: Network - Subnets
    log_info ""
    log_info "=== Layer 13: Subnets ==="
    destroy_target "aws_subnet.public" "Public Subnets"
    sleep 10

    # Layer 14: Network - Internet Gateway
    log_info ""
    log_info "=== Layer 14: Internet Gateway ==="
    destroy_target "aws_internet_gateway.main" "Internet Gateway"
    sleep 10

    # Layer 15: VPC
    log_info ""
    log_info "=== Layer 15: VPC ==="
    destroy_target "aws_vpc.main" "VPC"

    # Layer 16: Helper Resources
    log_info ""
    log_info "=== Layer 16: Helper Resources ==="
    destroy_target "null_resource.pre_destroy_cleanup" "Pre-Destroy Cleanup Resource"
    destroy_target "null_resource.eks_cleanup" "EKS Cleanup Resource"
    destroy_target "null_resource.network_cleanup" "Network Cleanup Resource"

    echo ""
    echo "============================================"
    log_success "TARGETED DESTROY COMPLETED!"
    echo "============================================"
    echo ""
    log_info "If there are any remaining resources, run:"
    log_info "  terraform destroy"
    echo ""
}

main
