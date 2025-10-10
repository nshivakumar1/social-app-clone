#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Jenkins Installation Started $(date) ==="

# Update system
yum update -y

# Install Docker
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Java 17 (Jenkins requires Java 11+)
yum install -y java-17-amazon-corretto

# Add Jenkins repository and install
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum install -y jenkins

# Add jenkins user to docker group
usermod -a -G docker jenkins

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
./aws/install

# Install kubectl
curl -o kubectl "https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.1/2023-04-19/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin

# Install Node.js (use version compatible with Amazon Linux 2)
curl -fsSL https://rpm.nodesource.com/setup_16.x | bash -
yum install -y nodejs || amazon-linux-extras install -y nodejs18

# Add Jenkins repository and install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo || echo "Failed to download Jenkins repo"
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key || echo "Failed to import Jenkins GPG key"
yum install -y jenkins --nogpgcheck || echo "Failed to install Jenkins"

# Add jenkins user to docker group
usermod -a -G docker jenkins

# Configure Jenkins
mkdir -p /var/lib/jenkins
chown jenkins:jenkins /var/lib/jenkins

# Set Java path for Jenkins
echo 'JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto"' >> /etc/sysconfig/jenkins

# Start and enable Jenkins
systemctl daemon-reload
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to initialize
echo "Waiting for Jenkins to start..."
for i in {1..30}; do
  if systemctl is-active jenkins >/dev/null 2>&1; then
    echo "Jenkins service is active"
    break
  fi
  echo "Waiting for Jenkins... attempt $i/30"
  sleep 10
done

# Check Jenkins status
systemctl status jenkins
journalctl -u jenkins -n 20

# Create a simple health check endpoint
echo "Jenkins installation completed at $(date)" > /var/lib/jenkins/installation-complete.txt

echo "=== Jenkins Installation Completed $(date) ==="