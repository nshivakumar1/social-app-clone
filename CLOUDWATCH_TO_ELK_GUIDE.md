# 🔌 CloudWatch to ELK Stack Integration Guide

Complete guide to connect AWS CloudWatch Logs to your ELK stack for Kibana visualization.

## 📋 Table of Contents
- [Architecture Overview](#architecture-overview)
- [Method 1: Lambda Function (Recommended)](#method-1-lambda-function-recommended)
- [Method 2: Kinesis Firehose](#method-2-kinesis-firehose)
- [Method 3: Fluent Bit Sidecar](#method-3-fluent-bit-sidecar)
- [ELK Stack Setup](#elk-stack-setup)
- [Testing & Verification](#testing--verification)

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ECS Fargate   │───▶│  CloudWatch      │───▶│  Lambda/        │
│   (Your App)    │    │  Log Groups      │    │  Kinesis        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Kibana       │◀───│  Elasticsearch   │◀───│   Logstash      │
│  (Visualize)    │    │  (Store/Index)   │    │   (Process)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Flow**:
1. ECS → CloudWatch Logs (automatic)
2. CloudWatch → Lambda/Kinesis (trigger on new logs)
3. Lambda/Kinesis → Logstash (forward logs)
4. Logstash → Elasticsearch (index logs)
5. Kibana → Elasticsearch (visualize)

---

## Method 1: Lambda Function (Recommended)

### Pros:
- ✅ Serverless (no infrastructure to manage)
- ✅ Pay per use
- ✅ Easy to set up
- ✅ Automatic scaling

### Step 1: Deploy ELK Stack

First, you need an ELK stack. Add this to your `infrastructure/main.tf`:

```hcl
# ELK Stack EC2 Instance
resource "aws_instance" "elk" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t3.large"  # ELK needs more resources
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.elk.id]

  user_data = base64encode(file("elk-userdata.sh"))

  root_block_device {
    volume_size = 50  # ELK needs storage for logs
    volume_type = "gp3"
  }

  tags = {
    Name = "ELK-Stack"
  }
}

# Security Group for ELK
resource "aws_security_group" "elk" {
  name        = "elk-security-group"
  description = "Security group for ELK stack"
  vpc_id      = aws_vpc.main.id

  # Elasticsearch
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Internal only
  }

  # Kibana
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public access
  }

  # Logstash
  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For Lambda
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elk-sg"
  }
}

# Elastic IP for ELK
resource "aws_eip" "elk" {
  instance = aws_instance.elk.id
  domain   = "vpc"

  tags = {
    Name = "elk-eip"
  }
}

# Output ELK URLs
output "elk_kibana_url" {
  value = "http://${aws_eip.elk.public_ip}:5601"
}

output "elk_elasticsearch_url" {
  value = "http://${aws_eip.elk.public_ip}:9200"
}

output "elk_logstash_endpoint" {
  value = "${aws_eip.elk.public_ip}:5044"
}
```

### Step 2: Create ELK User Data Script

Create `infrastructure/elk-userdata.sh`:

```bash
#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create docker-compose.yml for ELK
cat > /home/ec2-user/docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - esdata:/usr/share/elasticsearch/data
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    ports:
      - "5044:5044"
      - "9600:9600"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    depends_on:
      - elasticsearch
    networks:
      - elk

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - elk

volumes:
  esdata:
    driver: local

networks:
  elk:
    driver: bridge
EOF

# Create Logstash configuration
cat > /home/ec2-user/logstash.conf << 'EOF'
input {
  http {
    port => 5044
    codec => json
  }
}

filter {
  # Parse CloudWatch logs
  if [messageType] == "DATA_MESSAGE" {
    json {
      source => "message"
    }
  }

  # Add timestamp
  date {
    match => [ "timestamp", "UNIX_MS" ]
    target => "@timestamp"
  }

  # Extract ECS metadata
  mutate {
    add_field => {
      "app" => "social-app-clone"
      "environment" => "production"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "social-app-logs-%{+YYYY.MM.dd}"
  }

  # Debug output
  stdout {
    codec => rubydebug
  }
}
EOF

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user

# Start ELK stack
cd /home/ec2-user
docker-compose up -d

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to start..."
sleep 30

# Create index pattern
curl -X POST "localhost:9200/_index_template/social-app-logs" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["social-app-logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    }
  }
}
'

echo "ELK Stack deployment complete!"
echo "Kibana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5601"
```

### Step 3: Create Lambda Function

Create `infrastructure/lambda-cloudwatch-to-logstash.py`:

```python
import json
import gzip
import base64
import urllib3
import os

# Logstash endpoint from environment variable
LOGSTASH_ENDPOINT = os.environ['LOGSTASH_ENDPOINT']
LOGSTASH_PORT = os.environ.get('LOGSTASH_PORT', '5044')

http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Lambda function to forward CloudWatch logs to Logstash
    """

    # Decode and decompress CloudWatch log data
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_data = json.loads(uncompressed_payload)

    print(f"Processing {len(log_data['logEvents'])} log events")

    # Process each log event
    for log_event in log_data['logEvents']:
        log_entry = {
            'timestamp': log_event['timestamp'],
            'message': log_event['message'],
            'logGroup': log_data['logGroup'],
            'logStream': log_data['logStream'],
            'messageType': 'DATA_MESSAGE'
        }

        # Send to Logstash
        try:
            response = http.request(
                'POST',
                f'http://{LOGSTASH_ENDPOINT}:{LOGSTASH_PORT}',
                body=json.dumps(log_entry).encode('utf-8'),
                headers={'Content-Type': 'application/json'}
            )

            if response.status != 200:
                print(f"Error sending to Logstash: {response.status}")
        except Exception as e:
            print(f"Exception sending to Logstash: {e}")

    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(log_data["logEvents"])} events')
    }
```

### Step 4: Add Lambda to Terraform

Add to `infrastructure/main.tf`:

```hcl
# Lambda IAM Role
resource "aws_iam_role" "lambda_cloudwatch_to_logstash" {
  name = "lambda-cloudwatch-to-logstash-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_cloudwatch_to_logstash.name
}

# Zip the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda-cloudwatch-to-logstash.py"
  output_path = "${path.module}/lambda-cloudwatch-to-logstash.zip"
}

# Lambda Function
resource "aws_lambda_function" "cloudwatch_to_logstash" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "cloudwatch-to-logstash"
  role          = aws_iam_role.lambda_cloudwatch_to_logstash.arn
  handler       = "lambda-cloudwatch-to-logstash.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      LOGSTASH_ENDPOINT = aws_eip.elk.public_ip
      LOGSTASH_PORT     = "5044"
    }
  }

  depends_on = [aws_instance.elk]
}

# CloudWatch Log Subscription Filter
resource "aws_cloudwatch_log_subscription_filter" "ecs_to_lambda" {
  name            = "ecs-logs-to-elk"
  log_group_name  = "/ecs/social-app-clone"
  filter_pattern  = ""  # Send all logs
  destination_arn = aws_lambda_function.cloudwatch_to_logstash.arn
}

# Lambda Permission for CloudWatch
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_to_logstash.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.ecs.arn}:*"
}
```

### Step 5: Deploy

```bash
cd infrastructure
terraform apply -auto-approve
```

Wait 5-10 minutes for ELK stack to start, then:

```bash
# Get Kibana URL
terraform output elk_kibana_url

# Visit Kibana
open $(terraform output -raw elk_kibana_url)
```

### Step 6: Configure Kibana

1. Open Kibana URL (from terraform output)
2. Go to **Stack Management** → **Index Patterns**
3. Create index pattern: `social-app-logs-*`
4. Select time field: `@timestamp`
5. Go to **Discover** to see your logs!

---

## Method 2: Kinesis Firehose (Alternative)

### Pros:
- Fully managed
- Built-in buffering
- Automatic retry

### Setup:

```hcl
# Kinesis Firehose to Elasticsearch
resource "aws_kinesis_firehose_delivery_stream" "logs_to_elk" {
  name        = "cloudwatch-to-elk"
  destination = "http_endpoint"

  http_endpoint_configuration {
    url                = "http://${aws_eip.elk.public_ip}:5044"
    name               = "Logstash"
    access_key         = ""  # If Logstash requires auth
    buffering_size     = 5
    buffering_interval = 60
    retry_duration     = 60

    s3_backup_mode = "FailedDataOnly"

    request_configuration {
      content_encoding = "GZIP"
    }
  }

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.firehose_backup.arn
  }
}

# CloudWatch to Kinesis
resource "aws_cloudwatch_log_subscription_filter" "ecs_to_kinesis" {
  name            = "ecs-to-kinesis"
  log_group_name  = "/ecs/social-app-clone"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_elk.arn
}
```

---

## Method 3: Fluent Bit Sidecar

For real-time streaming, add Fluent Bit as sidecar to ECS task.

Update ECS task definition in `infrastructure/main.tf`:

```hcl
container_definitions = jsonencode([
  {
    name  = "social-app-clone"
    # ... existing config ...
  },
  {
    name      = "fluent-bit"
    image     = "amazon/aws-for-fluent-bit:latest"
    essential = false

    firelensConfiguration = {
      type = "fluentbit"
      options = {
        enable-ecs-log-metadata = "true"
      }
    }

    environment = [
      {
        name  = "LOGSTASH_HOST"
        value = aws_eip.elk.public_ip
      },
      {
        name  = "LOGSTASH_PORT"
        value = "5044"
      }
    ]
  }
])
```

---

## 🧪 Testing & Verification

### Test 1: Check ELK Stack Status

```bash
# SSH to ELK instance
ELK_IP=$(terraform output -raw elk_kibana_url | cut -d'/' -f3 | cut -d':' -f1)
ssh -i your-key.pem ec2-user@$ELK_IP

# Check Docker containers
docker ps

# Should see:
# - elasticsearch
# - logstash
# - kibana
```

### Test 2: Test Elasticsearch

```bash
curl http://ELK_IP:9200/_cluster/health?pretty
```

### Test 3: Test Logstash

```bash
# Send test log
curl -X POST http://ELK_IP:5044 \
  -H "Content-Type: application/json" \
  -d '{"message":"test log","timestamp":'$(date +%s000)'}'
```

### Test 4: Check Kibana

1. Open Kibana: http://ELK_IP:5601
2. Go to Discover
3. Should see logs appearing in real-time!

### Test 5: Trigger App Logs

```bash
# Make requests to your app to generate logs
curl http://social-app-clone-1321601292.us-east-1.elb.amazonaws.com/health

# Check CloudWatch
aws logs tail /ecs/social-app-clone --follow

# Logs should appear in Kibana within 1-2 minutes
```

---

## 📊 Sample Kibana Queries

Once logs are flowing, try these queries in Kibana:

```
# All logs from social-app-clone
app: "social-app-clone"

# Error logs only
message: *ERROR*

# Health check requests
message: */health*

# Logs from last hour
@timestamp > now-1h
```

---

## 🔧 Troubleshooting

### Lambda not receiving logs:

```bash
# Check Lambda logs
aws logs tail /aws/lambda/cloudwatch-to-logstash --follow

# Check CloudWatch subscription
aws logs describe-subscription-filters --log-group-name /ecs/social-app-clone
```

### Logstash not receiving data:

```bash
# Check Logstash logs
ssh ec2-user@$ELK_IP
docker logs logstash
```

### Elasticsearch issues:

```bash
# Check Elasticsearch logs
docker logs elasticsearch

# Check indices
curl http://ELK_IP:9200/_cat/indices?v
```

---

## 💰 Cost Estimate

- **ELK EC2 (t3.large)**: ~$60/month
- **Lambda invocations**: ~$1-5/month (depends on log volume)
- **Data transfer**: ~$10-20/month
- **Total**: ~$70-85/month

### Free Alternative:
Use CloudWatch Logs Insights (no extra cost, already included with CloudWatch)

---

## 🎯 Quick Start Commands

```bash
# 1. Deploy ELK stack
cd infrastructure
terraform apply -auto-approve

# 2. Get Kibana URL
terraform output elk_kibana_url

# 3. Wait for stack to start (5-10 minutes)
# 4. Open Kibana and configure index pattern
# 5. Logs will start flowing automatically!
```

---

**Recommended**: Start with **Method 1 (Lambda)** - it's the easiest and most cost-effective.
