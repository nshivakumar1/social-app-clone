#!/bin/bash

echo "🔍 GitHub Webhook Troubleshooting Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

JENKINS_URL="http://100.28.67.190:8080"
JENKINS_JOB="social-app-clone-pipeline"

echo "📋 Step 1: Check if Jenkins is accessible"
echo "----------------------------------------"
if curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" | grep -q "200\|403"; then
    echo -e "${GREEN}✅ Jenkins is accessible at $JENKINS_URL${NC}"
else
    echo -e "${RED}❌ Jenkins is not accessible${NC}"
    exit 1
fi
echo ""

echo "📋 Step 2: Check GitHub webhook endpoint"
echo "----------------------------------------"
WEBHOOK_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL/github-webhook/")
echo "Response code: $WEBHOOK_RESPONSE"

if [ "$WEBHOOK_RESPONSE" = "200" ] || [ "$WEBHOOK_RESPONSE" = "405" ]; then
    echo -e "${GREEN}✅ Webhook endpoint is responding${NC}"
else
    echo -e "${RED}❌ Webhook endpoint issue (code: $WEBHOOK_RESPONSE)${NC}"
fi
echo ""

echo "📋 Step 3: Manual webhook test"
echo "----------------------------------------"
echo "You can manually trigger a webhook test with:"
echo ""
echo "curl -X POST $JENKINS_URL/github-webhook/ \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"repository\":{\"url\":\"https://github.com/nshivakumar1/social-app-clone\"}}'"
echo ""

echo "📋 Step 4: Things to verify in Jenkins UI"
echo "----------------------------------------"
echo "1. Go to: $JENKINS_URL/job/$JENKINS_JOB/configure"
echo "2. Under 'Build Triggers' section:"
echo "   ✅ Check 'GitHub hook trigger for GITScm polling'"
echo ""
echo "3. Under 'Source Code Management' → Git:"
echo "   Repository URL: https://github.com/nshivakumar1/social-app-clone.git"
echo "   Branch: */main"
echo ""
echo "4. Check Jenkins System Configuration:"
echo "   Go to: $JENKINS_URL/configure"
echo "   Scroll to 'GitHub' section"
echo "   Verify GitHub server is configured"
echo ""

echo "📋 Step 5: Check Jenkins logs for webhook activity"
echo "----------------------------------------"
echo "SSH into Jenkins server and run:"
echo "sudo tail -f /var/log/jenkins/jenkins.log | grep -i github"
echo ""

echo "📋 Step 6: Alternative - Use Poll SCM instead of Webhook"
echo "----------------------------------------"
echo "If webhook doesn't work, you can use polling:"
echo "1. Go to job configuration"
echo "2. Under 'Build Triggers', enable 'Poll SCM'"
echo "3. Enter schedule: H/5 * * * * (poll every 5 minutes)"
echo ""

echo "📋 Step 7: Test with a simple commit"
echo "----------------------------------------"
echo "After configuration, test with:"
echo "echo '# Test webhook' >> README.md"
echo "git add README.md"
echo "git commit -m 'test: Trigger webhook'"
echo "git push origin main"
echo ""

echo "🔍 Common Issues and Solutions"
echo "=========================================="
echo ""
echo "Issue 1: GitHub Plugin not installed"
echo "Solution: Manage Jenkins → Manage Plugins → Available → Search 'GitHub Integration Plugin'"
echo ""
echo "Issue 2: Jenkins behind firewall"
echo "Solution: Your EC2 security group must allow inbound HTTP (port 8080) from GitHub IPs"
echo "GitHub Webhook IPs: https://api.github.com/meta (webhooks section)"
echo ""
echo "Issue 3: Webhook URL incorrect"
echo "Solution: Must be exactly: $JENKINS_URL/github-webhook/ (with trailing slash)"
echo ""
echo "Issue 4: Build Triggers not configured"
echo "Solution: Enable 'GitHub hook trigger for GITScm polling' in job config"
echo ""

echo "🎯 Quick Fix: Manual Build Trigger"
echo "=========================================="
echo "While debugging, you can manually trigger builds:"
echo "Go to: $JENKINS_URL/job/$JENKINS_JOB/"
echo "Click: 'Build Now'"
echo ""

echo "✅ Next Steps:"
echo "1. Check GitHub webhook 'Recent Deliveries' for errors"
echo "2. Verify Jenkins job configuration (Build Triggers)"
echo "3. Check Jenkins system logs"
echo "4. Try manual build to ensure pipeline works"
echo "5. If all else fails, use Poll SCM as a temporary solution"
