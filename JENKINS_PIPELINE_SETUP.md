# 🚀 Jenkins Pipeline Setup Guide

Complete step-by-step guide to setup your Jenkins CI/CD pipeline for automated deployments.

---

## 📋 Prerequisites

- ✅ Jenkins running on AWS EC2: http://3.211.51.8:8080
- ✅ Application deployed to ECS
- ✅ GitHub repository: https://github.com/nshivakumar1/social-app-clone
- ✅ AWS credentials available

---

## 🔐 Step 1: Get Jenkins Password

### Option A: AWS Console (Easiest!)

1. **Open AWS EC2 Console:**
   - Go to: https://console.aws.amazon.com/ec2/

2. **Find Jenkins Instance:**
   - Search for instance ID: `i-0288839d4643af968`
   - Or search for tag: `Jenkins-Server`

3. **Connect to Instance:**
   - Select the instance
   - Click: **Connect** button (top right)
   - Choose: **EC2 Instance Connect**
   - Click: **Connect**

4. **Get Password:**
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

5. **Copy the Password:**
   - It will look like: `abc123def456ghi789jkl012mno345pqr`
   - Copy this entire string

### Option B: SSH (If you have the key)

```bash
ssh -i your-key.pem ec2-user@3.211.51.8
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
exit
```

---

## 🎨 Step 2: Complete Jenkins Setup Wizard

### 2.1 Unlock Jenkins

1. **Open Jenkins:**
   - URL: http://3.211.51.8:8080

2. **Paste Password:**
   - You'll see "Unlock Jenkins" page
   - Paste the password from Step 1
   - Click: **Continue**

### 2.2 Install Plugins

1. **Choose Plugin Installation:**
   - Select: **Install suggested plugins** ✅ (Recommended)
   - Wait 5-10 minutes for installation to complete

   **Plugins being installed:**
   - Git
   - Pipeline
   - GitHub
   - Docker Pipeline
   - And many more...

2. **Wait for Completion:**
   - You'll see progress bars for each plugin
   - Don't close the browser during installation

### 2.3 Create Admin User

1. **Create First Admin User:**
   ```
   Username: admin
   Password: [Choose a strong password - save this!]
   Confirm password: [Same password]
   Full name: Your Name
   E-mail address: your-email@example.com
   ```

2. **Click:** Save and Continue

### 2.4 Instance Configuration

1. **Jenkins URL:**
   - Default: http://3.211.51.8:8080/
   - Keep as is (unless you have a domain)
   - Click: **Save and Finish**

2. **Start Using Jenkins:**
   - Click: **Start using Jenkins**
   - You'll see the Jenkins dashboard!

---

## 🔑 Step 3: Configure AWS Credentials

### 3.1 Install AWS Credentials Plugin (If Not Installed)

1. **Go to:** Manage Jenkins → Plugins → Available plugins
2. **Search:** "AWS Credentials"
3. **Install:** AWS Credentials Plugin + Amazon ECR Plugin
4. **Restart Jenkins** if prompted

### 3.2 Add AWS Credentials

1. **Navigate to Credentials:**
   - Dashboard → Manage Jenkins → Manage Credentials

2. **Add Credentials:**
   - Click: **(global)** domain
   - Click: **Add Credentials**

3. **Configure AWS Credentials:**
   ```
   Kind: AWS Credentials
   ID: aws-credentials
   Description: AWS Credentials for ECR and ECS
   Access Key ID: [Your AWS Access Key]
   Secret Access Key: [Your AWS Secret Key]
   ```

4. **Click:** Create

### 3.3 Add GitHub Credentials (Optional but Recommended)

1. **Add Another Credential:**
   - Click: **Add Credentials**

2. **Configure GitHub Token:**
   ```
   Kind: Username with password
   Username: your-github-username
   Password: [GitHub Personal Access Token]
   ID: github-credentials
   Description: GitHub Access Token
   ```

   **To create GitHub token:**
   - GitHub → Settings → Developer settings → Personal access tokens
   - Generate new token (classic)
   - Scopes: `repo`, `admin:repo_hook`

3. **Click:** Create

---

## 📦 Step 4: Create Pipeline Job

### 4.1 Create New Item

1. **From Dashboard:**
   - Click: **New Item** (left sidebar)

2. **Configure Item:**
   ```
   Item name: social-app-clone-pipeline
   Type: Pipeline ✅
   ```

3. **Click:** OK

### 4.2 Configure General Settings

1. **Description:**
   ```
   CI/CD pipeline for Social App Clone - Automated build, test, and deployment to AWS ECS
   ```

2. **Build Triggers:**
   - ✅ Check: **GitHub hook trigger for GITScm polling**
   - This enables automatic builds on git push

3. **Scroll down to Pipeline section**

### 4.3 Configure Pipeline

**Option A: Pipeline from SCM (Recommended)**

1. **Pipeline Definition:**
   - Select: **Pipeline script from SCM**

2. **SCM Configuration:**
   ```
   SCM: Git

   Repository URL: https://github.com/nshivakumar1/social-app-clone.git

   Credentials: [Select your GitHub credentials or use none if public]

   Branch Specifier: */main

   Script Path: ci-cd/Jenkinsfile
   ```

3. **Additional Behaviors:**
   - You can add: "Clean before checkout" (recommended)

4. **Click:** Save

**Option B: Pipeline Script Directly**

1. **Pipeline Definition:**
   - Select: **Pipeline script**

2. **Copy Your Jenkinsfile:**
   - Go to: `ci-cd/Jenkinsfile` in your repository
   - Copy entire content
   - Paste in Pipeline Script box

3. **Click:** Save

---

## 🔗 Step 5: Configure GitHub Webhook

### 5.1 Setup Webhook in GitHub

1. **Go to Your Repository:**
   - https://github.com/nshivakumar1/social-app-clone

2. **Navigate to Settings:**
   - Click: **Settings** tab
   - Click: **Webhooks** (left sidebar)

3. **Add Webhook:**
   - Click: **Add webhook**

4. **Configure Webhook:**
   ```
   Payload URL: http://3.211.51.8:8080/github-webhook/
   Content type: application/json
   Secret: [Leave empty or add if you want]

   Which events?
   ✅ Just the push event

   ✅ Active (checked)
   ```

5. **Click:** Add webhook

6. **Verify:**
   - After creation, you should see a green checkmark
   - If red X, check the URL is accessible

### 5.2 Test Webhook (Optional)

1. **In GitHub Webhook Settings:**
   - Click on your webhook
   - Scroll to "Recent Deliveries"
   - Click: **Redeliver** to test

2. **Check Response:**
   - Should see HTTP 200 response
   - If not, check Jenkins is accessible from internet

---

## 🧪 Step 6: Test Your Pipeline

### 6.1 Manual Test First

1. **In Jenkins:**
   - Go to your pipeline job: `social-app-clone-pipeline`
   - Click: **Build Now** (left sidebar)

2. **Watch Build:**
   - Build will appear in "Build History"
   - Click on build number (e.g., #1)
   - Click: **Console Output**
   - Watch the logs

3. **Expected Stages:**
   ```
   1. 🔍 Checkout - Git clone
   2. 🧪 Test - Run tests
   3. 📊 Code Quality Analysis - ESLint, npm audit
   4. 🐋 Build Docker Image - Docker build
   5. 📤 Push to ECR - Push to AWS ECR
   6. 🚀 Deploy to ECS - Update ECS service
   7. 📝 Update GitOps - Update manifests
   8. 🔄 Setup ArgoCD - Configure ArgoCD
   9. 🧪 Post-Deployment Tests - Health checks
   ```

4. **Success Indicators:**
   - All stages green ✅
   - Final message: "DEPLOYMENT SUCCESSFUL!"
   - Notifications sent to Slack/Jira (if configured)

### 6.2 Test Automated Trigger (Git Push)

1. **Make a Small Change:**
   ```bash
   cd /Users/nakulshivakumar/Desktop/social-app-clone/

   # Add a comment to test
   echo "// Test Jenkins pipeline" >> app/server.js

   # Commit and push
   git add app/server.js
   git commit -m "Test Jenkins webhook trigger"
   git push origin main
   ```

2. **Watch Jenkins:**
   - Jenkins should automatically start a new build
   - If webhook is working, build starts within seconds

3. **Check Build:**
   - Go to: http://3.211.51.8:8080/job/social-app-clone-pipeline/
   - New build should appear automatically
   - Watch console output

---

## 📊 Step 7: Monitor and Verify

### 7.1 Check Pipeline Status

1. **View Pipeline:**
   - http://3.211.51.8:8080/job/social-app-clone-pipeline/

2. **Key Indicators:**
   - ✅ Green ball = Success
   - ⚠️ Yellow ball = Unstable (warnings)
   - ❌ Red ball = Failure

3. **Stage View:**
   - Shows visual representation of pipeline stages
   - Click on stages to see logs

### 7.2 Check Application

1. **Verify Deployment:**
   ```bash
   # Check ECS service
   aws ecs describe-services \
     --cluster social-app-clone \
     --services social-app-clone \
     --region us-east-1

   # Check application health
   curl http://social-app-clone-653043147.us-east-1.elb.amazonaws.com/health
   ```

2. **Access Application:**
   - URL: http://social-app-clone-653043147.us-east-1.elb.amazonaws.com
   - Should show your application
   - Should reflect latest changes

### 7.3 Check Notifications

1. **Slack (if configured):**
   - Check your Slack channel
   - Should see build success/failure messages

2. **Jira (if configured):**
   - Check Jira project
   - Should see tickets created for deployments

---

## 🔧 Step 8: Configure Additional Settings (Optional)

### 8.1 Build Retention

1. **Job Configuration:**
   - Go to: Pipeline → Configure
   - Check: **Discard old builds**
   ```
   Max # of builds to keep: 30
   ```

2. **Save**

### 8.2 Email Notifications

1. **Install Plugin:**
   - Manage Jenkins → Plugins → Email Extension Plugin

2. **Configure SMTP:**
   - Manage Jenkins → Configure System
   - E-mail Notification section
   - Configure your SMTP server

3. **Add to Pipeline:**
   - Update Jenkinsfile `post` section to send emails

### 8.3 Concurrent Builds

1. **Job Configuration:**
   - ✅ Check: **Do not allow concurrent builds**
   - Prevents conflicts during deployment

### 8.4 Parameters (Advanced)

1. **Add Build Parameters:**
   ```
   - Choice: ENVIRONMENT (dev, staging, prod)
   - String: DOCKER_TAG (default: latest)
   - Boolean: SKIP_TESTS (default: false)
   ```

2. **Use in Pipeline:**
   ```groovy
   environment {
       ENV = "${params.ENVIRONMENT}"
       TAG = "${params.DOCKER_TAG}"
   }
   ```

---

## 🐛 Troubleshooting

### Issue: Build Fails at Checkout

**Solution:**
```bash
# Check GitHub credentials
# Or use public repository URL without credentials

# In pipeline config, use:
Repository URL: https://github.com/nshivakumar1/social-app-clone.git
Credentials: none (if public repo)
```

### Issue: Docker Build Fails

**Solution:**
```bash
# SSH to Jenkins server
ssh ec2-user@3.211.51.8

# Add jenkins user to docker group (if not done)
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### Issue: AWS Credentials Not Working

**Solution:**
1. Verify credentials are correct
2. Check IAM permissions
3. Re-enter credentials in Jenkins
4. Test with AWS CLI on Jenkins server

### Issue: Webhook Not Triggering

**Solution:**
1. **Check webhook URL:**
   - Must be: http://3.211.51.8:8080/github-webhook/
   - Trailing slash is important!

2. **Check security group:**
   ```bash
   # Verify port 8080 is open to GitHub IPs
   aws ec2 describe-security-groups \
     --group-names jenkins-sg* \
     --region us-east-1
   ```

3. **Check GitHub webhook deliveries:**
   - GitHub → Settings → Webhooks
   - Click on webhook
   - Check "Recent Deliveries"
   - Should see HTTP 200 responses

### Issue: ECR Push Fails

**Solution:**
```bash
# Check AWS credentials in Jenkins
# Verify ECR repository exists
aws ecr describe-repositories \
  --repository-names social-app-clone \
  --region us-east-1

# Check IAM permissions for ECR
```

---

## 📊 Pipeline Visualization

Your pipeline stages in Jenkins:

```
┌─────────────┐
│  Checkout   │ ─┐
└─────────────┘  │
                 ├─→ ┌──────────────┐
┌─────────────┐  │   │              │
│    Test     │ ─┤   │   Success    │
└─────────────┘  │   │              │
                 ├─→ └──────────────┘
┌─────────────┐  │        │
│ Code Quality│ ─┤        │
└─────────────┘  │        ▼
                 ├─→ Notifications
┌─────────────┐  │   (Slack/Jira)
│ Build Docker│ ─┤
└─────────────┘  │
                 ├─→ Deploy to ECS
┌─────────────┐  │
│  Push ECR   │ ─┤        │
└─────────────┘  │        │
                 ├─→      ▼
┌─────────────┐  │   Application
│ Deploy ECS  │ ─┤      Live!
└─────────────┘  │
                 ├─→
┌─────────────┐  │
│Update GitOps│ ─┤
└─────────────┘  │
                 ▼
         Post-Deployment
              Tests
```

---

## 🎯 Quick Reference

### Jenkins URLs

| Purpose | URL |
|---------|-----|
| Dashboard | http://3.211.51.8:8080 |
| Pipeline Job | http://3.211.51.8:8080/job/social-app-clone-pipeline/ |
| Console Output | http://3.211.51.8:8080/job/social-app-clone-pipeline/lastBuild/console |
| Credentials | http://3.211.51.8:8080/credentials/ |
| Manage Jenkins | http://3.211.51.8:8080/manage |

### Common Commands

```bash
# Trigger build manually
curl -X POST http://3.211.51.8:8080/job/social-app-clone-pipeline/build

# Check Jenkins status
sudo systemctl status jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Jenkins accessible at http://3.211.51.8:8080
- [ ] Admin user created and can login
- [ ] AWS credentials configured
- [ ] Pipeline job created
- [ ] GitHub webhook configured
- [ ] Manual build succeeds
- [ ] Git push triggers automatic build
- [ ] All pipeline stages complete successfully
- [ ] Application deployed to ECS
- [ ] Application accessible via ALB
- [ ] Notifications working (Slack/Jira)

---

## 🎉 Next Steps

After pipeline is working:

1. **Add More Tests:**
   - Unit tests
   - Integration tests
   - Security scans

2. **Improve Pipeline:**
   - Add staging environment
   - Add approval gates
   - Add rollback capability

3. **Monitor Builds:**
   - Set up build metrics
   - Create dashboards
   - Track deployment frequency

4. **Documentation:**
   - Document deployment process
   - Create runbooks
   - Train team members

---

## 📚 Additional Resources

- [Jenkinsfile Documentation](ci-cd/Jenkinsfile) - Your pipeline code
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)

---

**Need help? Check the console output logs for detailed error messages!**

**Jenkins is ready for CI/CD! 🚀**
