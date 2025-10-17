# GitHub Actions Workflows

## Available Workflows

### 1. Code Quality & Security Scanning

**File:** `code-quality.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Weekly schedule (Mondays at 9:00 AM)
- Manual workflow dispatch

**Jobs:**

1. **ESLint** - JavaScript code linting and style checking
2. **CodeQL** - Security vulnerability analysis
3. **Dependency Review** - Check for vulnerable dependencies (PRs only)
4. **SonarCloud** - Comprehensive code quality analysis
5. **Security Scan** - npm audit for known vulnerabilities
6. **Docker Security** - Container image scanning with Trivy
7. **Summary** - Aggregate results and quality gate status

**View Results:**
- Actions tab in GitHub repository
- Security tab for CodeQL findings
- Pull request checks
- Uploaded artifacts for detailed reports

**Setup Requirements:**

1. Add GitHub Secrets:
   ```
   SONAR_TOKEN: Your SonarCloud authentication token
   ```

2. Configure SonarCloud:
   - Create project at https://sonarcloud.io
   - Update organization in workflow file
   - Generate authentication token

**Manual Trigger:**
```
GitHub → Actions → Code Quality & Security Scanning → Run workflow
```

## Workflow Features

### Quality Gates

✅ **ESLint:** Code style and best practices
✅ **CodeQL:** Security vulnerability detection
✅ **Dependencies:** Vulnerable package detection
✅ **SonarCloud:** Code quality metrics
✅ **npm audit:** Known vulnerabilities
✅ **Trivy:** Container security

### Automated Reports

- ESLint JSON reports
- npm audit reports
- CodeQL SARIF files
- Trivy scan results
- All available as workflow artifacts

### Security Integration

- Results appear in GitHub Security tab
- SARIF upload for CodeQL and Trivy
- Automated security alerts
- Pull request status checks

## Usage

### For Developers

**Before committing:**
```bash
cd app/
npm run lint
npm test
npm audit
```

**On pull request:**
- All checks run automatically
- Review results in PR checks
- Fix any failing quality gates

### For Reviewers

**Review quality metrics:**
1. Check PR status badges
2. Review failed checks
3. Examine security findings
4. Verify test coverage

**Access detailed results:**
- Click on failed check
- View workflow logs
- Download artifacts
- Check Security tab

## Troubleshooting

### Common Issues

**Workflow not triggering:**
- Check repository permissions
- Verify branch protection rules
- Review workflow file syntax

**SonarCloud failing:**
- Verify SONAR_TOKEN secret
- Check organization name
- Review project configuration

**CodeQL timeout:**
- Check code complexity
- Review analysis queries
- Adjust timeout settings

## Best Practices

1. **Run locally first** - Test before pushing
2. **Monitor results** - Check workflow outcomes
3. **Fix issues promptly** - Don't accumulate tech debt
4. **Review security alerts** - Address vulnerabilities quickly
5. **Maintain coverage** - Keep tests up to date

---

**For detailed documentation, see [CODE_QUALITY_GUIDE.md](../../CODE_QUALITY_GUIDE.md)**
