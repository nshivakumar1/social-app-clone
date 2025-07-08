const https = require('https');

const SLACK_CONFIG = {
  webhookUrl: process.env.SLACK_WEBHOOK_URL || 'https://hooks.slack.com/services/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',
  channel: process.env.SLACK_CHANNEL || '#social-clone-testing'
};

function sendSlackNotification(message, color = 'good') {
  // Validate webhook URL
  if (!SLACK_CONFIG.webhookUrl || SLACK_CONFIG.webhookUrl.includes('YOUR/SLACK/WEBHOOK')) {
    console.error('❌ Missing or invalid Slack webhook URL.');
    console.error('💡 Set SLACK_WEBHOOK_URL environment variable or update the default in the code.');
    console.error('📖 Get your webhook URL from: https://api.slack.com/apps');
    return;
  }

  console.log(`📡 Sending Slack notification to: ${SLACK_CONFIG.channel}`);

  const payload = {
    channel: SLACK_CONFIG.channel,
    username: 'Social App CI/CD Bot',
    icon_emoji: ':robot_face:',
    text: message,
    attachments: [
      {
        color: color,
        fields: [
          {
            title: 'Environment',
            value: process.env.NODE_ENV || 'development',
            short: true
          },
          {
            title: 'Build Number',
            value: process.env.BUILD_NUMBER || 'N/A',
            short: true
          },
          {
            title: 'Timestamp',
            value: new Date().toISOString(),
            short: true
          },
          {
            title: 'Repository',
            value: process.env.GIT_URL || 'social-app-clone',
            short: true
          }
        ],
        footer: 'Social App CI/CD',
        ts: Math.floor(Date.now() / 1000)
      }
    ]
  };

  const postData = JSON.stringify(payload);
  
  let url;
  try {
    url = new URL(SLACK_CONFIG.webhookUrl);
  } catch (error) {
    console.error('❌ Invalid webhook URL format:', SLACK_CONFIG.webhookUrl);
    return;
  }
  
  const options = {
    hostname: url.hostname,
    port: 443,
    path: url.pathname,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('✅ Slack notification sent successfully');
      } else {
        console.error(`❌ Failed to send Slack notification: ${res.statusCode} ${res.statusMessage}`);
        console.error('Response:', data);
        console.error('💡 Check if your webhook URL is correct and the channel exists');
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Error sending Slack notification:', error.message);
    console.error('💡 Troubleshooting tips:');
    console.error('  1. Check if webhook URL is correct');
    console.error('  2. Verify your internet connection');
    console.error('  3. Ensure the Slack app has proper permissions');
  });

  req.write(postData);
  req.end();
}

// Support for different notification types
function sendSuccessNotification(message) {
  sendSlackNotification(`✅ ${message}`, 'good');
}

function sendWarningNotification(message) {
  sendSlackNotification(`⚠️ ${message}`, 'warning');
}

function sendErrorNotification(message) {
  sendSlackNotification(`❌ ${message}`, 'danger');
}

// If called directly from command line
if (require.main === module) {
  const message = process.argv[2] || 'Test notification from Social App CI/CD';
  const type = process.argv[3] || 'good'; // good, warning, danger
  console.log('🚀 Testing Slack integration...');
  sendSlackNotification(message, type);
}

module.exports = { 
  sendSlackNotification, 
  sendSuccessNotification, 
  sendWarningNotification, 
  sendErrorNotification 
};