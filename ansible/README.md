# 🤖 Ansible Configuration Management

Infrastructure automation and configuration management for Social App Clone.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Galaxy collections and roles
├── inventory/
│   ├── hosts.ini           # Static inventory
│   └── aws_ec2.yml         # AWS dynamic inventory
├── playbooks/
│   ├── site.yml            # Main playbook
│   ├── deploy-app.yml      # Application deployment
│   ├── setup-jenkins.yml   # Jenkins configuration
│   └── health-check.yml    # Health validation
├── roles/                   # Custom Ansible roles (add as needed)
├── group_vars/
│   ├── all.yml             # Global variables
│   └── jenkins.yml         # Jenkins-specific variables
└── host_vars/              # Host-specific variables (add as needed)
```

## 🚀 Quick Start

### 1. Install Dependencies
```bash
# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Install Python dependencies
pip3 install boto3 botocore
```

### 2. Configure Inventory
```bash
# Edit static inventory
vim inventory/hosts.ini

# Test connection
ansible all -m ping -i inventory/hosts.ini
```

### 3. Run Playbooks
```bash
# Deploy application
ansible-playbook playbooks/deploy-app.yml

# Setup Jenkins
ansible-playbook playbooks/setup-jenkins.yml -i inventory/hosts.ini

# Full infrastructure setup
ansible-playbook playbooks/site.yml -i inventory/hosts.ini
```

## 📖 Available Playbooks

| Playbook | Purpose |
|----------|---------|
| `site.yml` | Complete infrastructure setup |
| `deploy-app.yml` | Deploy to AWS ECS |
| `setup-jenkins.yml` | Configure Jenkins server |
| `health-check.yml` | Validate deployment |

## 📚 Documentation

See [ANSIBLE_GUIDE.md](../ANSIBLE_GUIDE.md) for detailed documentation.

## 🔧 Configuration

### AWS Credentials
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### Variables
Customize in `group_vars/all.yml`:
- `project_name`: Project identifier
- `aws_region`: AWS region
- `docker_image`: Container image
- `ecs_cluster_name`: ECS cluster

## 🤝 Contributing

When adding playbooks:
1. Test in non-production
2. Document variables
3. Add error handling
4. Update this README

---

**For detailed instructions, see [ANSIBLE_GUIDE.md](../ANSIBLE_GUIDE.md)**
