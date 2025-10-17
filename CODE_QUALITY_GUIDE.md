# 📊 Code Quality & Scanning Guide

Comprehensive guide for code quality analysis, security scanning, and best practices for the Social App Clone project.

## 📋 Table of Contents

- [Overview](#overview)
- [Code Quality Tools](#code-quality-tools)
- [Setup Instructions](#setup-instructions)
- [Running Scans](#running-scans)
- [CI/CD Integration](#cicd-integration)
- [Quality Gates](#quality-gates)
- [Best Practices](#best-practices)

## 🎯 Overview

This project implements multiple layers of code quality and security scanning:

### Code Quality Tools

| Tool | Purpose | Stage |
|------|---------|-------|
| **ESLint** | JavaScript linting & style | Local + CI/CD |
| **Jest** | Unit testing & coverage | Local + CI/CD |
| **SonarQube** | Code quality & security | CI/CD |
| **npm audit** | Dependency vulnerabilities | Local + CI/CD |
| **CodeQL** | Security analysis | GitHub Actions |
| **Trivy** | Container security | GitHub Actions |

## 🛠️ Setup Instructions

### 1. Install Dependencies

```bash
cd app/
npm install
```

This installs:
- `eslint` - Code linting
- `jest` - Testing framework
- `supertest` - API testing
- `sonarqube-scanner` - SonarQube integration

### 2. Configure ESLint

ESLint is pre-configured in [app/.eslintrc.json](app/.eslintrc.json).

**Customize rules:**
```bash
# Edit ESLint configuration
vim app/.eslintrc.json
```

**Key rules:**
- Indentation: 4 spaces
- Quotes: Single quotes
- Semicolons: Required
- No unused variables (warnings)
- ES2021 syntax support

### 3. Setup SonarQube (Optional)

#### Option A: SonarCloud (Recommended)

1. Create account at [SonarCloud.io](https://sonarcloud.io)
2. Create new project
3. Get authentication token
4. Store in AWS Systems Manager:

```bash
aws ssm put-parameter \
  --name "/social-app/sonar/token" \
  --value "your-sonarcloud-token" \
  --type SecureString \
  --region us-east-1

aws ssm put-parameter \
  --name "/social-app/sonar/host" \
  --value "https://sonarcloud.io" \
  --type String \
  --region us-east-1
```

5. Add to GitHub Secrets:
   - `SONAR_TOKEN`: Your SonarCloud token

#### Option B: Self-Hosted SonarQube

```bash
# Run SonarQube with Docker
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:latest

# Access at http://localhost:9000
# Default credentials: admin/admin
```

## 🚀 Running Scans

### Local Development

#### ESLint - Code Linting
```bash
cd app/

# Run linter
npm run lint

# Auto-fix issues
npm run lint:fix

# Lint specific files
npx eslint server.js
```

#### Unit Tests
```bash
# Run tests
npm test

# Run tests with coverage
npm test -- --coverage

# Watch mode (for development)
npm run test:watch
```

#### Security Audit
```bash
# Check for vulnerabilities
npm audit

# Fix automatically (if possible)
npm audit fix

# Detailed report
npm audit --json > audit-report.json
```

#### SonarQube Analysis
```bash
# Local scan (requires SonarQube running)
npm run sonar

# Or use sonar-scanner directly
sonar-scanner \
  -Dsonar.projectKey=social-app-clone \
  -Dsonar.sources=app \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=your-token
```

### CI/CD Pipeline

Code quality checks run automatically in Jenkins pipeline:

**Stages:**
1. **Checkout** - Get latest code
2. **Test** - Run unit tests
3. **Code Quality Analysis** - ESLint + npm audit + SonarQube
4. **Build** - Docker image
5. **Deploy** - To ECS

**View results:**
```bash
# Check Jenkins console output
# Navigate to: http://your-jenkins-url:8080/job/social-app-clone/lastBuild/console
```

### GitHub Actions

Automated security scanning runs on:
- Every push to `main` or `develop`
- Every pull request
- Weekly schedule (Mondays at 9 AM)

**Workflows:**
- `.github/workflows/code-quality.yml` - Comprehensive quality checks

**View results:**
- GitHub Actions tab
- Security tab (CodeQL findings)
- Pull request checks

## 📊 Quality Gates

### ESLint Quality Gate

**Pass criteria:**
- No critical errors
- Maximum 10 warnings

**Fix before merge:**
```bash
npm run lint:fix
```

### Test Coverage Gate

**Pass criteria:**
- Line coverage: ≥ 70%
- Branch coverage: ≥ 60%
- Function coverage: ≥ 70%

**View coverage:**
```bash
npm test -- --coverage
open coverage/lcov-report/index.html
```

### Security Audit Gate

**Pass criteria:**
- No critical vulnerabilities
- No high vulnerabilities
- Moderate vulnerabilities: < 5

**Fix vulnerabilities:**
```bash
# Update dependencies
npm audit fix

# Force update (breaking changes possible)
npm audit fix --force
```

### SonarQube Quality Gate

**Pass criteria:**
- Code coverage: ≥ 70%
- Code smells: ≤ 50
- Bugs: 0
- Vulnerabilities: 0
- Security hotspots: Reviewed
- Duplications: ≤ 3%
- Maintainability rating: A or B

**View SonarQube dashboard:**
```
https://sonarcloud.io/dashboard?id=social-app-clone
```

## 🔒 Security Scanning

### 1. Dependency Scanning (npm audit)

```bash
# Check vulnerabilities
npm audit

# Generate JSON report
npm audit --json > security-report.json

# Production dependencies only
npm audit --production
```

### 2. Container Scanning (Trivy)

Runs automatically in GitHub Actions.

**Manual scan:**
```bash
# Build image
docker build -t social-app-clone:test app/

# Scan with Trivy
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image social-app-clone:test

# Generate report
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image \
  --format json \
  --output trivy-report.json \
  social-app-clone:test
```

### 3. Code Scanning (CodeQL)

Runs automatically in GitHub Actions.

**Features:**
- Detects security vulnerabilities
- Identifies code quality issues
- Supports JavaScript/TypeScript
- Results in GitHub Security tab

**Manual trigger:**
```bash
# Via GitHub Actions UI
# Actions → Code Quality & Security Scanning → Run workflow
```

### 4. Secret Scanning

Runs automatically by GitHub.

**Prevent secrets in commits:**
```bash
# Install pre-commit hooks (optional)
npm install --save-dev husky
npx husky install

# Add pre-commit hook
npx husky add .git/hooks/pre-commit "npm run lint"
```

## 🔄 CI/CD Integration

### Jenkins Pipeline Integration

Code quality is integrated in the Jenkins pipeline:

```groovy
stage('📊 Code Quality Analysis') {
    steps {
        script {
            dir('app') {
                // ESLint
                sh 'npm run lint'

                // Security audit
                sh 'npm audit --audit-level=moderate'

                // SonarQube (if configured)
                sh 'sonar-scanner'
            }
        }
    }
}
```

**Configure SonarQube in Jenkins:**

1. Store credentials in AWS Systems Manager:
```bash
aws ssm put-parameter \
  --name "/social-app/sonar/token" \
  --value "your-token" \
  --type SecureString

aws ssm put-parameter \
  --name "/social-app/sonar/host" \
  --value "https://sonarcloud.io" \
  --type String
```

2. Jenkins will automatically use these credentials

### GitHub Actions Integration

Comprehensive workflow in `.github/workflows/code-quality.yml`:

**Jobs:**
1. **ESLint** - Code linting
2. **CodeQL** - Security analysis
3. **Dependency Review** - Dependency scanning (PRs only)
4. **SonarCloud** - Code quality
5. **Security Scan** - npm audit
6. **Docker Security** - Trivy container scan
7. **Summary** - Quality gate results

## 📈 Viewing Results

### ESLint Results

```bash
# Terminal output
npm run lint

# JSON format
npm run lint -- --format json --output-file eslint-report.json

# HTML report (requires eslint-html-reporter)
npm install --save-dev eslint-html-reporter
npm run lint -- --format html --output-file eslint-report.html
```

### Test Coverage Reports

```bash
# Run tests with coverage
npm test -- --coverage

# Open HTML report
open app/coverage/lcov-report/index.html

# View text summary
cat app/coverage/lcov.info
```

### SonarQube Dashboard

**SonarCloud:**
```
https://sonarcloud.io/dashboard?id=social-app-clone
```

**Self-hosted:**
```
http://localhost:9000/dashboard?id=social-app-clone
```

### GitHub Security

**View security alerts:**
1. Navigate to repository
2. Click "Security" tab
3. Select "Code scanning alerts"

## 🎯 Best Practices

### 1. Code Quality

- **Run linter before commits:**
  ```bash
  npm run lint:fix
  ```

- **Write tests for new features:**
  ```bash
  npm test -- --watch
  ```

- **Maintain coverage ≥ 70%:**
  ```bash
  npm test -- --coverage
  ```

### 2. Security

- **Update dependencies regularly:**
  ```bash
  npm outdated
  npm update
  ```

- **Review audit findings:**
  ```bash
  npm audit
  npm audit fix
  ```

- **Scan containers before deployment:**
  ```bash
  trivy image your-image:tag
  ```

### 3. Continuous Improvement

- Review SonarQube findings weekly
- Address code smells proactively
- Refactor complex functions
- Maintain code documentation
- Follow ESLint rules

### 4. Pre-Commit Checklist

Before committing code:

- [ ] Run `npm run lint:fix`
- [ ] Run `npm test`
- [ ] Check `npm audit`
- [ ] Review code coverage
- [ ] Update documentation
- [ ] Test locally

## 🐛 Troubleshooting

### ESLint Issues

**Problem:** ESLint not finding files
```bash
# Solution: Check .eslintignore
cat app/.eslintignore

# Verify file patterns
npx eslint --debug app/**/*.js
```

**Problem:** Rules too strict
```bash
# Solution: Adjust rules in .eslintrc.json
# Change severity: "error" → "warn" → "off"
```

### SonarQube Issues

**Problem:** Connection failed
```bash
# Check SonarQube URL
curl https://sonarcloud.io/api/system/status

# Verify token
echo $SONAR_TOKEN
```

**Problem:** Analysis failed
```bash
# Check sonar-project.properties
cat sonar-project.properties

# Run with verbose logging
sonar-scanner -X
```

### npm Audit Issues

**Problem:** Can't fix vulnerabilities
```bash
# Check if fix available
npm audit fix --dry-run

# Force update (may break)
npm audit fix --force

# Manual update
npm update package-name@latest
```

## 📚 Additional Resources

- [ESLint Documentation](https://eslint.org/docs/latest/)
- [Jest Testing Guide](https://jestjs.io/docs/getting-started)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [GitHub CodeQL](https://codeql.github.com/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## 🤝 Contributing

When contributing:

1. Follow ESLint rules
2. Write unit tests
3. Maintain test coverage
4. Fix security vulnerabilities
5. Pass all quality gates
6. Update documentation

---

**For questions or issues, please create an issue in the GitHub repository.**
