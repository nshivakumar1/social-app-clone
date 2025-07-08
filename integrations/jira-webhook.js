const https = require('https');

const JIRA_CONFIG = {
  host: process.env.JIRA_HOST || 'learndevopswithkodekloud.atlassian.net',
  username: process.env.JIRA_USERNAME || 'your-email@domain.com',
  apiToken: process.env.JIRA_API_TOKEN || 'your-jira-api-token-here',
  projectKey: process.env.JIRA_PROJECT_KEY || 'SOCIAL'
};

function createJiraIncident(description) {
  // Validate and clean hostname
  let hostname = JIRA_CONFIG.host;
  hostname = hostname.replace(/^https?:\/\//, '');
  hostname = hostname.replace(/\/$/, '');
  
  console.log(`🔍 Attempting to connect to Jira host: ${hostname}`);
  
  // Validate required config
  if (!hostname || !JIRA_CONFIG.username || !JIRA_CONFIG.apiToken) {
    console.error('❌ Missing required Jira configuration:');
    console.error('  JIRA_HOST:', hostname || 'MISSING');
    console.error('  JIRA_USERNAME:', JIRA_CONFIG.username || 'MISSING');
    console.error('  JIRA_API_TOKEN:', JIRA_CONFIG.apiToken ? 'SET' : 'MISSING');
    return;
  }

  // Try different issue types in order of preference
  const issueTypesToTry = ['Task', 'Story', 'Issue', 'Bug', 'Epic'];
  
  function tryCreateIssue(issueTypeIndex = 0) {
    if (issueTypeIndex >= issueTypesToTry.length) {
      console.error('❌ All issue types failed. Please check your Jira project configuration.');
      return;
    }
    
    const currentIssueType = issueTypesToTry[issueTypeIndex];
    console.log(`📝 Trying issue type: ${currentIssueType}`);
    
    const issueData = {
      fields: {
        project: {
          key: JIRA_CONFIG.projectKey
        },
        summary: `CI/CD Issue - ${new Date().toISOString()}`,
        description: {
          type: "doc",
          version: 1,
          content: [
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: description
                }
              ]
            }
          ]
        },
        issuetype: {
          name: currentIssueType
        }
        // Removed priority to avoid another potential error
      }
    };

    const postData = JSON.stringify(issueData);
    
    const options = {
      hostname: hostname,
      port: 443,
      path: '/rest/api/3/issue',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Authorization': `Basic ${Buffer.from(`${JIRA_CONFIG.username}:${JIRA_CONFIG.apiToken}`).toString('base64')}`
      }
    };

    console.log(`📡 Making request to: https://${hostname}/rest/api/3/issue`);

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 201) {
          const issue = JSON.parse(data);
          console.log(`✅ Jira incident created successfully: ${issue.key}`);
          console.log(`📋 Issue URL: https://${hostname}/browse/${issue.key}`);
          console.log(`🎯 Successful issue type: ${currentIssueType}`);
        } else if (res.statusCode === 400) {
          console.log(`❌ Issue type '${currentIssueType}' failed: ${res.statusCode}`);
          
          try {
            const errorData = JSON.parse(data);
            if (errorData.errors && errorData.errors.issuetype) {
              console.log(`   Reason: ${errorData.errors.issuetype}`);
              console.log(`   Trying next issue type...`);
              tryCreateIssue(issueTypeIndex + 1);
              return;
            }
          } catch (e) {
            // Not JSON or different error structure
          }
          
          console.error('Response body:', data);
        } else {
          console.error(`❌ Failed to create Jira incident: ${res.statusCode} ${res.statusMessage}`);
          console.error('Response body:', data);
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Error creating Jira incident:', error.message);
    });

    req.write(postData);
    req.end();
  }
  
  // Start trying issue types
  tryCreateIssue();
}

// If called directly from command line
if (require.main === module) {
  const description = process.argv[2] || 'Test incident from command line';
  console.log('🚀 Testing Jira integration with fallback issue types...');
  createJiraIncident(description);
}

module.exports = { createJiraIncident };