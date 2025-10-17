#!/bin/bash

################################################################################
# Ansible Local Installation Script
# Installs Ansible and dependencies on your local machine (control node)
################################################################################

set -e  # Exit on error

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         Ansible Local Setup for Social App Clone             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
OS="$(uname -s)"
echo "📍 Detected OS: $OS"
echo ""

################################################################################
# macOS Installation
################################################################################
if [ "$OS" = "Darwin" ]; then
    echo "🍎 Installing Ansible on macOS..."
    echo ""

    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "✅ Homebrew is installed"
    fi

    # Install Ansible
    echo ""
    echo "📦 Installing Ansible via Homebrew..."
    brew install ansible

    # Install Python packages
    echo ""
    echo "📦 Installing Python packages (boto3, botocore)..."
    pip3 install --upgrade pip
    pip3 install boto3 botocore ansible

################################################################################
# Linux Installation
################################################################################
elif [ "$OS" = "Linux" ]; then
    echo "🐧 Installing Ansible on Linux..."
    echo ""

    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "❌ Cannot detect Linux distribution"
        exit 1
    fi

    case $DISTRO in
        ubuntu|debian)
            echo "📦 Installing Ansible on Ubuntu/Debian..."
            sudo apt-get update
            sudo apt-get install -y software-properties-common
            sudo add-apt-repository --yes --update ppa:ansible/ansible
            sudo apt-get install -y ansible python3-pip
            ;;

        rhel|centos|fedora|amzn)
            echo "📦 Installing Ansible on RHEL/CentOS/Fedora..."
            sudo yum install -y epel-release
            sudo yum install -y ansible python3-pip
            ;;

        *)
            echo "⚠️  Unsupported Linux distribution: $DISTRO"
            echo "Please install Ansible manually: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
            exit 1
            ;;
    esac

    # Install Python packages
    echo ""
    echo "📦 Installing Python packages (boto3, botocore)..."
    pip3 install --upgrade pip
    pip3 install boto3 botocore

################################################################################
# Other OS
################################################################################
else
    echo "❌ Unsupported operating system: $OS"
    echo "Please install Ansible manually: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
    exit 1
fi

################################################################################
# Install Ansible Galaxy Collections
################################################################################
echo ""
echo "📦 Installing Ansible Galaxy collections..."
cd ansible/
ansible-galaxy collection install -r requirements.yml --force
cd ..

################################################################################
# Verify Installation
################################################################################
echo ""
echo "✅ Verifying Ansible installation..."
ansible --version

echo ""
echo "✅ Verifying Python packages..."
python3 -c "import boto3, botocore; print('boto3:', boto3.__version__, '| botocore:', botocore.__version__)"

################################################################################
# Check AWS Configuration
################################################################################
echo ""
echo "🔍 Checking AWS configuration..."
if command -v aws &> /dev/null; then
    if aws sts get-caller-identity &> /dev/null; then
        echo "✅ AWS CLI is configured and working"
        aws sts get-caller-identity
    else
        echo "⚠️  AWS CLI is installed but not configured"
        echo "   Run: aws configure"
    fi
else
    echo "⚠️  AWS CLI not found. Install it for better AWS integration:"
    echo "   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
fi

################################################################################
# Test Ansible Connectivity
################################################################################
echo ""
echo "🧪 Testing Ansible connectivity..."
cd ansible/

# Test localhost connection
if ansible localhost -m ping &> /dev/null; then
    echo "✅ Ansible can connect to localhost"
else
    echo "⚠️  Ansible localhost connection failed"
fi

cd ..

################################################################################
# Summary
################################################################################
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              Ansible Setup Complete! 🎉                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 What was installed:"
echo "  ✅ Ansible ($(ansible --version | head -1))"
echo "  ✅ boto3 and botocore (AWS SDK)"
echo "  ✅ Ansible Galaxy collections (amazon.aws, community.aws, etc.)"
echo ""
echo "📚 Next Steps:"
echo ""
echo "1. Configure AWS credentials (if not done):"
echo "   aws configure"
echo ""
echo "2. Test Ansible deployment:"
echo "   cd ansible/"
echo "   ansible-playbook playbooks/health-check.yml"
echo ""
echo "3. Deploy application:"
echo "   ansible-playbook playbooks/deploy-app.yml"
echo ""
echo "4. Read documentation:"
echo "   - ANSIBLE_GUIDE.md"
echo "   - QUICK_REFERENCE.md"
echo ""
echo "🔗 Jenkins Server (with Ansible installed):"
echo "   http://100.28.67.190:8080"
echo ""
echo "⚠️  Important: Your Mac is the Ansible CONTROL NODE"
echo "   Jenkins EC2 will also have Ansible for CI/CD automation"
echo ""
