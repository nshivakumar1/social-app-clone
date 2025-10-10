# ============================================================================
# DESTROY HELPER CONFIGURATION
# Enhanced lifecycle management and destroy tactics
# ============================================================================

# Null resource to handle pre-destroy cleanup
resource "null_resource" "pre_destroy_cleanup" {
  triggers = {
    vpc_id     = aws_vpc.main.id
    cluster_id = aws_eks_cluster.main.id
    alb_arn    = aws_alb.main.arn
  }

  # This provisioner runs BEFORE resources are destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      echo "============================================"
      echo "Running pre-destroy cleanup..."
      echo "============================================"

      # Scale down ECS service to 0
      echo "Scaling down ECS service..."
      aws ecs update-service \
        --cluster ${self.triggers.cluster_id} \
        --service social-app-clone \
        --desired-count 0 \
        --region us-east-1 2>/dev/null || true

      sleep 30

      # Drain and delete ALB targets
      echo "Draining ALB targets..."
      TG_ARNS=$(aws elbv2 describe-target-groups \
        --load-balancer-arn ${self.triggers.alb_arn} \
        --query 'TargetGroups[].TargetGroupArn' \
        --output text 2>/dev/null || true)

      for TG in $TG_ARNS; do
        echo "  Deregistering targets from $TG"
        TARGETS=$(aws elbv2 describe-target-health \
          --target-group-arn $TG \
          --query 'TargetHealthDescriptions[].Target.Id' \
          --output text 2>/dev/null || true)

        for TARGET in $TARGETS; do
          aws elbv2 deregister-targets \
            --target-group-arn $TG \
            --targets Id=$TARGET 2>/dev/null || true
        done
      done

      sleep 20

      echo "Pre-destroy cleanup completed!"
    EOT
  }
}

# Local provisioner for EKS cleanup
resource "null_resource" "eks_cleanup" {
  triggers = {
    cluster_name = aws_eks_cluster.main.name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      echo "Cleaning up EKS cluster resources..."

      # Configure kubectl
      aws eks update-kubeconfig \
        --name ${self.triggers.cluster_name} \
        --region us-east-1 2>/dev/null || true

      # Delete all services of type LoadBalancer
      echo "Deleting LoadBalancer services..."
      kubectl delete svc --all-namespaces -l type=LoadBalancer --ignore-not-found=true 2>/dev/null || true

      # Delete all ingresses
      echo "Deleting ingresses..."
      kubectl delete ingress --all-namespaces --all --ignore-not-found=true 2>/dev/null || true

      # Wait for resources to be cleaned up
      sleep 30

      echo "EKS cleanup completed!"
    EOT
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}

# Network cleanup helper
resource "null_resource" "network_cleanup" {
  triggers = {
    vpc_id    = aws_vpc.main.id
    subnet_ids = join(",", aws_subnet.public[*].id)
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      echo "Cleaning up network interfaces..."

      VPC_ID=${self.triggers.vpc_id}

      # Find and detach/delete ENIs
      ENI_IDS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces[?Status!=`in-use`].NetworkInterfaceId' \
        --output text 2>/dev/null || true)

      for ENI in $ENI_IDS; do
        echo "Deleting ENI: $ENI"
        aws ec2 delete-network-interface \
          --network-interface-id $ENI 2>/dev/null || true
      done

      echo "Network cleanup completed!"
    EOT
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_ecs_service.main
  ]
}
