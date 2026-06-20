terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # No remote backend — state stored locally in terraform.tfstate
  # To enable S3 backend later:
  # backend "s3" {
  #   bucket         = "your-tf-state-bucket"
  #   key            = "social-app/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tf-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

# Latest Amazon Linux 2023 AMI (replaces hardcoded AMI ID)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# NETWORKING
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_vpc.main]
  tags       = { Name = "${var.project_name}-igw" }
}

# Public subnets (ALB, Jenkins, NAT gateways)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

# Private subnets (ECS tasks, EKS nodes)
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-private-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnet egress
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "${var.project_name}-nat" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-sg" }
}

resource "aws_security_group" "jenkins" {
  name_prefix = "jenkins-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH restricted to operator IP — set jenkins_allowed_cidr in tfvars
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-security-group" }
}

# ============================================================================
# ECR
# ============================================================================

resource "aws_ecr_repository" "app" {
  name         = var.project_name
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = var.project_name }
}

# ============================================================================
# ECS
# ============================================================================

resource "aws_ecs_cluster" "main" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = var.project_name }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
  tags              = { Name = var.project_name }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = { Name = var.project_name }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS tasks to read SSM parameters (for JWT_SECRET, ALLOWED_ORIGINS)
resource "aws_iam_role_policy" "ecs_task_ssm" {
  name = "${var.project_name}-ecs-ssm"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/social-app/*"
    }]
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = var.project_name
    image = "${aws_ecr_repository.app.repository_url}:latest"

    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT", value = "3000" }
    ]

    secrets = [
      {
        name      = "JWT_SECRET"
        valueFrom = aws_ssm_parameter.jwt_secret.arn
      },
      {
        name      = "ALLOWED_ORIGINS"
        valueFrom = aws_ssm_parameter.allowed_origins.arn
      }
    ]

    essential = true
  }])

  tags = { Name = var.project_name }
}

resource "aws_alb" "main" {
  name            = var.project_name
  subnets         = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]

  enable_deletion_protection = false

  tags = { Name = var.project_name }
}

resource "aws_alb_target_group" "app" {
  name        = var.project_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  deregistration_delay = 30

  health_check {
    healthy_threshold   = 3
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = 5
    path                = "/health"
    unhealthy_threshold = 2
  }

  tags = { Name = var.project_name }
}

# HTTP — redirect to HTTPS when cert is configured, else forward directly
resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.acm_certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.acm_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.acm_certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn = aws_alb_target_group.app.arn
        }
      }
    }
  }
}

resource "aws_alb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_alb.main.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.app.arn
    type             = "forward"
  }
}

resource "aws_ecs_service" "main" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  health_check_grace_period_seconds  = 60

  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = aws_subnet.private[*].id  # private subnets — no public IP
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.arn
    container_name   = var.project_name
    container_port   = 3000
  }

  depends_on = [aws_alb_listener.http]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = { Name = var.project_name }
}

# ============================================================================
# SSM PARAMETERS
# ============================================================================

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/social-app/jwt-secret"
  description = "JWT signing secret for the app"
  type        = "SecureString"
  value       = var.jwt_secret
  overwrite   = true
  tags        = { Name = "${var.project_name}-jwt-secret" }
}

resource "aws_ssm_parameter" "allowed_origins" {
  name        = "/social-app/allowed-origins"
  description = "Comma-separated allowed CORS origins"
  type        = "String"
  value       = var.allowed_origins
  overwrite   = true
  tags        = { Name = "${var.project_name}-allowed-origins" }
}

resource "aws_ssm_parameter" "jira_url" {
  name      = "/social-app/jira/url"
  type      = "String"
  value     = var.jira_url
  overwrite = true
  tags      = { Name = "${var.project_name}-jira-url" }
}

resource "aws_ssm_parameter" "jira_username" {
  name      = "/social-app/jira/username"
  type      = "String"
  value     = var.jira_username
  overwrite = true
  tags      = { Name = "${var.project_name}-jira-username" }
}

resource "aws_ssm_parameter" "jira_api_token" {
  count     = var.jira_api_token != "" ? 1 : 0
  name      = "/social-app/jira/api-token"
  type      = "SecureString"
  value     = var.jira_api_token
  overwrite = true
  tags      = { Name = "${var.project_name}-jira-api-token" }
}

resource "aws_ssm_parameter" "jira_project_key" {
  name      = "/social-app/jira/project-key"
  type      = "String"
  value     = var.jira_project_key
  overwrite = true
  tags      = { Name = "${var.project_name}-jira-project-key" }
}

resource "aws_ssm_parameter" "jira_issue_type" {
  name      = "/social-app/jira/issue-type"
  type      = "String"
  value     = var.jira_issue_type
  overwrite = true
  tags      = { Name = "${var.project_name}-jira-issue-type" }
}

# ============================================================================
# JENKINS
# ============================================================================

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "jenkins_policy" {
  name = "jenkins-policy"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSAccess"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSReadOnly"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMReadSocialApp"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/social-app/*"
      },
      {
        Sid      = "PassECSRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.ecs_task_execution_role.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  subnet_id              = aws_subnet.public[0].id
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  user_data                   = base64encode(file("jenkins-userdata-robust.sh"))
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "Jenkins-Server" }
}

resource "aws_eip" "jenkins" {
  instance   = aws_instance.jenkins.id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "${var.project_name}-jenkins-eip" }
}

# ============================================================================
# EKS
# ============================================================================

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-eks-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Fargate pod execution role (replaces EC2 node role — no idle EC2 costs)
resource "aws_iam_role" "eks_fargate_role" {
  name = "${var.project_name}-eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-eks-fargate-role" }
}

resource "aws_iam_role_policy_attachment" "eks_fargate_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_role.name
}

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = { Name = "${var.project_name}-eks-cluster" }
}

# Fargate profile — app workloads + monitoring + argocd
resource "aws_eks_fargate_profile" "app" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project_name}-app"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn
  subnet_ids             = aws_subnet.private[*].id

  selector { namespace = "default" }
  selector { namespace = "social-app" }
  selector { namespace = "monitoring" }
  selector { namespace = "argocd" }

  depends_on = [aws_iam_role_policy_attachment.eks_fargate_policy]

  tags = { Name = "${var.project_name}-fargate-app" }
}

# Fargate profile — CoreDNS only (kube-system)
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project_name}-kube-system"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
    labels    = { "k8s-app" = "kube-dns" }
  }

  depends_on = [aws_iam_role_policy_attachment.eks_fargate_policy]

  tags = { Name = "${var.project_name}-fargate-kube-system" }
}

# vpc-cni is required for cluster networking even on Fargate
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.18.1-eksbuild.3"
  depends_on    = [aws_eks_fargate_profile.app]
}

# CoreDNS — patched to run on Fargate (removes ec2 compute-type annotation)
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.11.1-eksbuild.9"

  configuration_values = jsonencode({
    computeType = "Fargate"
    replicaCount = 2
    resources = {
      limits   = { cpu = "0.25", memory = "256M" }
      requests = { cpu = "0.25", memory = "256M" }
    }
  })

  depends_on = [aws_eks_fargate_profile.kube_system]
}

# Patch CoreDNS deployment to remove ec2 annotation so Fargate can schedule it
resource "null_resource" "coredns_fargate_patch" {
  depends_on = [aws_eks_addon.coredns]

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}
      kubectl patch deployment coredns \
        -n kube-system \
        --type json \
        -p '[{"op":"remove","path":"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]' || true
    EOT
  }
}
