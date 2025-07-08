const https = require('https');

const JIRA_CONFIG = {
  host: process.env.JIRA_HOST || 'learndevopswithkodekloud.atlassian.net',
  username: process.env.JIRA_USERNAME || 'your-email@domain.com',
  apiToken: process.env.JIRA_API_TOKEN || 'your-jira-api-token-here',
  projectKey: process.env.JIRA_PROJECT_KEY || 'SOCIAL'
};

function makeJiraRequest(path, callback) {
  // Clean hostname
  let hostname = JIRA_CONFIG.host.replace(/^https?:\/\//, '').replace(/\/$/, '');
  
  const options = {
    hostname: hostname,
    port: 443,
    path: path,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${Buffer.from(`${JIRA_CONFIG.username}:${JIRA_CONFIG.apiToken}`).toString('base64')}`
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      if (res.statusCode === 200) {
        try {
          const jsonData = JSON.parse(data);
          callback(null, jsonData);
        } catch (error) {
          callback(error, null);
        }
      } else {
        callback(new Error(`HTTP ${res.statusCode}: ${data}`), null);
      }
    });
  });

  req.on('error', (error) => {
    callback(error, null);
  });

  req.end();
}

function discoverJiraProject() {
  console.log('🔍 Discovering Jira Project Information...');
  console.log('==========================================');
  
  // 1. Get project information
  console.log(`\n📋 Checking project: ${JIRA_CONFIG.projectKey}`);
  makeJiraRequest(`/rest/api/3/project/${JIRA_CONFIG.projectKey}`, (error, project) => {
    if (error) {
      console.error(`❌ Error getting project info: ${error.message}`);
      
      // If project not found, list all projects
      console.log('\n📂 Let me fetch all available projects...');
      makeJiraRequest('/rest/api/3/project', (error, projects) => {
        if (error) {
          console.error(`❌ Error getting projects: ${error.message}`);
          return;
        }
        
        console.log('\n📂 Available Projects:');
        projects.forEach(proj => {
          console.log(`  • ${proj.key} - ${proj.name}`);
        });
        console.log('\n💡 Update JIRA_PROJECT_KEY to one of the above keys.');
      });
      return;
    }
    
    console.log(`✅ Project found: ${project.name} (${project.key})`);
    
    // 2. Get issue types for the project
    console.log('\n🏷️  Getting available issue types...');
    makeJiraRequest(`/rest/api/3/issuetype/project?projectId=${project.id}`, (error, issueTypes) => {
      if (error) {
        console.error(`❌ Error getting issue types: ${error.message}`);
        
        // Fallback: get all issue types
        makeJiraRequest('/rest/api/3/issuetype', (error, allIssueTypes) => {
          if (error) {
            console.error(`❌ Error getting all issue types: ${error.message}`);
            return;
          }
          
          console.log('\n🏷️  Available Issue Types (Global):');
          allIssueTypes.forEach(type => {
            console.log(`  • ${type.name} (ID: ${type.id})`);
          });
        });
        return;
      }
      
      console.log('\n🏷️  Available Issue Types for this project:');
      issueTypes.forEach(type => {
        console.log(`  • ${type.name} (ID: ${type.id}) ${type.subtask ? '[Subtask]' : ''}`);
      });
      
      // 3. Get priorities
      console.log('\n⚡ Getting available priorities...');
      makeJiraRequest('/rest/api/3/priority', (error, priorities) => {
        if (error) {
          console.error(`❌ Error getting priorities: ${error.message}`);
          return;
        }
        
        console.log('\n⚡ Available Priorities:');
        priorities.forEach(priority => {
          console.log(`  • ${priority.name} (ID: ${priority.id})`);
        });
        
        // 4. Provide recommended configuration
        console.log('\n🔧 Recommended Configuration:');
        console.log('============================');
        
        // Find a suitable issue type (prefer Task, Story, or first non-subtask)
        const suitableType = issueTypes.find(t => 
          !t.subtask && (t.name === 'Task' || t.name === 'Story' || t.name === 'Bug')
        ) || issueTypes.find(t => !t.subtask);
        
        if (suitableType) {
          console.log(`Issue Type: "${suitableType.name}"`);
        }
        
        // Find a suitable priority (prefer Medium, High, or first one)
        const suitablePriority = priorities.find(p => 
          p.name === 'Medium' || p.name === 'High' || p.name === 'Normal'
        ) || priorities[0];
        
        if (suitablePriority) {
          console.log(`Priority: "${suitablePriority.name}"`);
        }
        
        console.log(`Project Key: "${project.key}"`);
        
        console.log('\n📝 Copy this configuration to your jira-webhook.js file!');
      });
    });
  });
}

// Run discovery
if (require.main === module) {
  discoverJiraProject();
}

module.exports = { discoverJiraProject };