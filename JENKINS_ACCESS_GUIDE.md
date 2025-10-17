# 🔐 Jenkins Access Guide

## 🚀 How to Access Jenkins

**Jenkins URL:** http://3.211.51.8:8080

---

## 🔑 Getting Jenkins Password

Jenkins requires the initial admin password on first setup. Here are multiple ways to get it:

### Method 1: Via SSH (Recommended)

**Requirements:** SSH key pair that was used when creating the EC2 instance

```bash
# If you have the SSH key
ssh -i /path/to/your-key.pem ec2-user@3.211.51.8

# Get the password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Copy the password and exit
exit
```

**Note:** If you don't have the SSH key, use Method 2 or 3.

---

### Method 2: Via AWS Systems Manager Session Manager

```bash
# Start a session to the Jenkins EC2 instance
aws ssm start-session --target i-0288839d4643af968 --region us-east-1

# Once connected, run:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Copy the password
# Type 'exit' to close the session
```

**Note:** This requires SSM Agent to be running on the instance.

---

### Method 3: Via AWS EC2 Instance Connect (Browser-based)

1. **Open AWS Console:** https://console.aws.amazon.com/ec2/
2. **Navigate to:** EC2 → Instances
3. **Find instance:** i-0288839d4643af968 (Jenkins-Server)
4. **Click:** Connect → EC2 Instance Connect → Connect
5. **In the terminal, run:**
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
6. **Copy the password** displayed

---

### Method 4: Via CloudWatch Logs (If Available)

The Jenkins user-data script logs to `/var/log/user-data.log`. You might be able to see the password there:

```bash
# Via SSH or Session Manager
tail -100 /var/log/user-data.log | grep -A 5 "initialAdminPassword"
```

---

### Method 5: Create New SSH Key Pair (If None Exists)

If you don't have SSH access and Methods 2-4 don't work:

```bash
# 1. Generate new SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins-key

# 2. Get the public key
cat ~/.ssh/jenkins-key.pub

# 3. Add to EC2 instance via AWS Console:
# - EC2 → Instances → Select Jenkins instance
# - Actions → Security → Modify instance metadata options
# - Or use EC2 Instance Connect to add to ~/.ssh/authorized_keys

# 4. Then use Method 1 with this key
ssh -i ~/.ssh/jenkins-key ec2-user@3.211.51.8
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## 📋 Step-by-Step First Time Setup

### Step 1: Get Initial Password

Use any method above to get the password from:
```
/var/lib/jenkins/secrets/initialAdminPassword
```

### Step 2: Access Jenkins

1. Open browser: http://3.211.51.8:8080
2. You'll see "Unlock Jenkins" page
3. Paste the initial admin password
4. Click "Continue"

### Step 3: Customize Jenkins

1. **Install Plugins:**
   - Choose "Install suggested plugins" (recommended)
   - Wait for installation to complete

2. **Create Admin User:**
   ```
   Username: admin (or your choice)
   Password: [choose a strong password]
   Full name: Your Name
   Email: your-email@example.com
   ```

3. **Instance Configuration:**
   - Jenkins URL: http://3.211.51.8:8080
   - Click "Save and Finish"

4. **Start Using Jenkins!**

---

## 🔒 Security Best Practices

### After First Login:

1. **Change the admin password:**
   - Manage Jenkins → Manage Users → admin → Configure
   - Set a strong password

2. **Enable security features:**
   - Manage Jenkins → Configure Global Security
   - Enable CSRF Protection
   - Configure authorization (Role-based is recommended)

3. **Create additional users:**
   - Manage Jenkins → Manage Users → Create User
   - Give appropriate permissions

4. **Setup AWS credentials:**
   - Manage Jenkins → Manage Credentials
   - Add AWS credentials for ECR/ECS access

---

## 🛠️ Alternative: Reset Jenkins

If you can't get the password and want to start fresh:

### Via SSH/Session Manager:

```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Remove security config
sudo rm /var/lib/jenkins/config.xml

# Restart Jenkins
sudo systemctl start jenkins

# Get new password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Via Terraform (Complete Reset):

```bash
# Destroy and recreate Jenkins
cd infrastructure/
terraform destroy -target=aws_instance.jenkins -target=aws_eip.jenkins
terraform apply

# New instance will have new initial password
```

**Warning:** This will delete all Jenkins configuration, jobs, and plugins!

---

## 🔍 Troubleshooting

### Issue: "Permission denied (publickey)"

**Solution:** You need the SSH key that was used when creating the EC2 instance.

**Options:**
1. Use AWS Systems Manager Session Manager (Method 2)
2. Use EC2 Instance Connect (Method 3)
3. Create new key pair and add to instance

---

### Issue: "Connection timeout"

**Check security group:**
```bash
# Verify port 8080 is open
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=jenkins-sg*" \
  --query 'SecurityGroups[0].IpPermissions' \
  --region us-east-1
```

**Should show:**
- Port 8080 open to 0.0.0.0/0
- Port 22 open to your IP

---

### Issue: Jenkins not running

**Check Jenkins status:**
```bash
# Via SSH or Session Manager
sudo systemctl status jenkins

# If not running
sudo systemctl start jenkins

# Check logs
sudo journalctl -u jenkins -n 50
```

---

## 📊 Quick Reference

| What | Value |
|------|-------|
| **Jenkins URL** | http://3.211.51.8:8080 |
| **Instance ID** | i-0288839d4643af968 |
| **Instance Type** | t3.medium |
| **OS User** | ec2-user |
| **Password Location** | /var/lib/jenkins/secrets/initialAdminPassword |
| **Region** | us-east-1 |

---

## 🎯 Recommended Approach

**For quickest access:**

1. **Use EC2 Instance Connect (Method 3)**
   - No SSH key needed
   - Works directly from browser
   - Easiest method!

2. **Steps:**
   - Go to: https://console.aws.amazon.com/ec2/
   - Find: Jenkins-Server (i-0288839d4643af968)
   - Click: Connect → EC2 Instance Connect → Connect
   - Run: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
   - Copy password
   - Access: http://3.211.51.8:8080

---

## 📚 After Getting Password

Once you have the password and complete setup:

1. **Configure Jenkins:**
   - Install required plugins
   - Setup AWS credentials
   - Create your first job

2. **Configure GitHub webhook:**
   - Repository → Settings → Webhooks
   - Add: http://3.211.51.8:8080/github-webhook/

3. **Test CI/CD:**
   ```bash
   git add .
   git commit -m "Test Jenkins"
   git push origin main
   ```

4. **Monitor builds:**
   - http://3.211.51.8:8080/job/your-job-name/

---

## 🔐 Password Not Working?

If the initial password doesn't work:

1. **Check if setup was already completed:**
   - If Jenkins shows login page (not unlock page)
   - Setup was already done
   - You need the admin password you created

2. **Reset if needed:**
   - Use reset methods above
   - Or recreate with Terraform

---

**Need help? Check the AWS Console or contact your AWS administrator!**
