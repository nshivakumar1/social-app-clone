# 🔧 GitHub Webhook & Kibana Setup Guide

## 📌 GitHub Webhook Configuration

### Step 1: Configure GitHub Webhook

1. **Navigate to your GitHub repository**:
   - Go to: https://github.com/nshivakumar1/social-app-clone

2. **Access Webhook Settings**:
   - Click **Settings** (top menu)
   - Click **Webhooks** (left sidebar)
   - Click **Add webhook** button

3. **Configure Webhook**:
   ```
   Payload URL: http://34.232.207.186:8080/github-webhook/
   Content type: application/json
   Secret: (leave blank or add a secret token)
   SSL verification: Disable SSL verification (since using HTTP)
   ```

4. **Select Events**:
   - ✅ Just the push event
   - Or select "Let me select individual events" and choose:
     - ✅ Pushes
     - ✅ Pull requests (optional)

5. **Activate**:
   - ✅ Active checkbox must be checked
   - Click **Add webhook**

### Step 2: Verify Jenkins GitHub Plugin

SSH into your Jenkins server and verify:

```bash
# SSH to Jenkins EC2
ssh -i your-key.pem ec2-user@34.232.207.186

# Check if GitHub plugin is installed
sudo cat /var/lib/jenkins/plugins/github/META-INF/MANIFEST.MF | grep Version
```

If not installed, install via Jenkins UI:
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for "GitHub Integration Plugin"
3. Install and restart Jenkins

### Step 3: Configure Jenkins Project for Webhooks

1. Go to Jenkins: http://34.232.207.186:8080
2. Click on **social-app-clone-pipeline** job
3. Click **Configure**
4. Scroll to **Build Triggers** section
5. Enable: ✅ **GitHub hook trigger for GITScm polling**
6. Click **Save**

### Step 4: Test the Webhook

After configuration, test it:

1. Make a small change to README or any file
2. Commit and push to GitHub
3. Check GitHub webhook delivery:
   - Go to Settings → Webhooks
   - Click on your webhook
   - Check "Recent Deliveries" tab
   - You should see a green checkmark ✅

4. Jenkins should automatically trigger build #4

---

## 📊 Kibana & ECS Logs Integration

### Current Setup Analysis

**Your Current Architecture**: ECS Fargate → CloudWatch Logs

The filebeat.yaml you have is for **Kubernetes**, but you're using **ECS Fargate**, which sends logs to **AWS CloudWatch** by default.

### Option 1: Use CloudWatch Logs Directly (Recommended for ECS)

Your ECS tasks already send logs to CloudWatch. Access them here:

```bash
# Via AWS Console
1. Go to CloudWatch → Log groups
2. Find: /ecs/social-app-clone
3. Click to view logs

# Via AWS CLI
aws logs tail /ecs/social-app-clone --follow --region us-east-1
```

### Option 2: Setup ELK Stack for ECS (More Complex)

If you want to use Kibana with ECS Fargate:

#### A. Deploy ELK Stack on EC2 or ECS

1. **Create ELK Stack Infrastructure**:

```bash
# Add to infrastructure/main.tf

# Elasticsearch EC2 instance
resource "aws_instance" "elasticsearch" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.public_1.id

  vpc_security_group_ids = [aws_security_group.elk.id]

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker

              # Run Elasticsearch
              docker run -d \
                --name elasticsearch \
                -p 9200:9200 \
                -p 9300:9300 \
                -e "discovery.type=single-node" \
                -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
                docker.elastic.co/elasticsearch/elasticsearch:8.11.0

              # Run Kibana
              docker run -d \
                --name kibana \
                -p 5601:5601 \
                --link elasticsearch:elasticsearch \
                -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
                docker.elastic.co/kibana/kibana:8.11.0

              # Run Logstash
              docker run -d \
                --name logstash \
                -p 5044:5044 \
                -p 9600:9600 \
                --link elasticsearch:elasticsearch \
                docker.elastic.co/logstash/logstash:8.11.0
              EOF

  tags = {
    Name = "elk-stack"
  }
}

# Security group for ELK
resource "aws_security_group" "elk" {
  name        = "elk-stack-sg"
  description = "Security group for ELK stack"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Kibana
  }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Elasticsearch (internal only)
  }

  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Logstash (internal only)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

#### B. Setup CloudWatch → Logstash Bridge

Use AWS Lambda to stream CloudWatch logs to Logstash:

```bash
# Create Lambda function that reads from CloudWatch and sends to Logstash
# Or use Fluentd/Fluent Bit as a sidecar in ECS
```

### Option 3: Use AWS CloudWatch Insights (Easiest)

CloudWatch Logs Insights provides Kibana-like querying:

1. **Go to CloudWatch Console**
2. **Click "Logs Insights"** (left menu)
3. **Select log group**: `/ecs/social-app-clone`
4. **Run queries**:

```sql
# Get all logs from last hour
fields @timestamp, @message
| sort @timestamp desc
| limit 100

# Filter error logs
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc

# Count requests by endpoint
stats count() by @message
| filter @message like /GET/

# Application health metrics
fields @timestamp, status, users, posts
| filter @message like /health/
| sort @timestamp desc
```

5. **Create Dashboards**:
   - Click "Add to dashboard"
   - Create custom visualizations
   - Similar to Kibana but AWS-native

### Option 4: Fluent Bit Sidecar (Recommended for ECS + Kibana)

Add Fluent Bit as a sidecar container to your ECS task to forward logs to Elasticsearch:

1. **Update ECS Task Definition** in Terraform:

```hcl
# In infrastructure/main.tf - Update task definition

container_definitions = jsonencode([
  {
    name      = "social-app-clone"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    # ... existing config ...
  },
  {
    name      = "fluent-bit"
    image     = "amazon/aws-for-fluent-bit:latest"
    essential = false
    firelensConfiguration = {
      type = "fluentbit"
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/fluent-bit"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "fluent-bit"
      }
    }
    environment = [
      {
        name  = "ES_HOST"
        value = "your-elasticsearch-endpoint"
      },
      {
        name  = "ES_PORT"
        value = "9200"
      }
    ]
  }
])
```

---

## 🎯 Quick Start Recommendations

### For Immediate Use (Easiest):

1. ✅ **Setup GitHub Webhook** (follow steps above)
2. ✅ **Use CloudWatch Logs Insights** for log analysis
3. ✅ **Create CloudWatch Dashboards** for metrics

### For Production (When Ready):

1. 🔄 **Deploy ELK Stack** on dedicated EC2 (t3.medium or larger)
2. 🔄 **Add Fluent Bit sidecar** to ECS tasks
3. 🔄 **Configure Logstash** to receive logs from Fluent Bit
4. 🔄 **Setup Kibana dashboards** for visualization

---

## 📝 Next Steps

1. **Configure GitHub webhook** (5 minutes)
2. **Test pipeline trigger** by pushing a commit
3. **Access CloudWatch Logs** to view application logs
4. **Decide on monitoring strategy**:
   - Start with CloudWatch (it's already working)
   - Add ELK later if you need advanced analytics

---

## 🔍 Verification Commands

### Check if webhook is working:
```bash
# After configuring webhook and pushing a commit:
# 1. GitHub: Settings → Webhooks → Recent Deliveries (should show green checkmark)
# 2. Jenkins: Should see build triggered automatically
```

### Check CloudWatch logs:
```bash
aws logs tail /ecs/social-app-clone --follow --region us-east-1
```

### Check ECS task status:
```bash
aws ecs list-tasks --cluster social-app-clone --region us-east-1
aws ecs describe-tasks --cluster social-app-clone --tasks <task-arn> --region us-east-1
```

---

**Need Help?**
- GitHub Webhooks: https://docs.github.com/en/webhooks
- CloudWatch Logs: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/
- ELK Stack: https://www.elastic.co/guide/index.html
