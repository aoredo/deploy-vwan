# Azure DevOps Quick Reference Guide

## 🚀 Quick Setup

### 1-Minute Setup for Impatient People

```bash
# 1. Login to Azure
az login

# 2. Create Service Principal
az ad sp create-for-rbac --name terraform-sp --role Contributor

# 3. Create DevOps Project
az devops project create --name vwan-infra --organization https://dev.azure.com/YOUR_ORG

# 4. Clone repo and create connection (do this in Azure DevOps UI)
# See AZURE-DEVOPS-SETUP.md Step 4

# 5. Create pipeline
az pipelines create --name vwan-deploy --repository deploy-vwan --branch main
```

---

## 📋 Common Commands

### Azure CLI DevOps Commands

```bash
# List projects
az devops project list

# Create project
az devops project create --name MyProject

# List pipelines
az pipelines list --project MyProject

# Run pipeline
az pipelines run --id 1 --project MyProject

# Get pipeline details
az pipelines show --id 1 --project MyProject

# List service connections
az devops service-endpoint list

# Create variable group
az pipelines variable-group create --name MyGroup --variables var1=value1 var2=value2

# Update variable group
az pipelines variable-group update --id 1 --variables var1=newvalue1
```

### Git Commands for DevOps

```bash
# Clone repository
git clone https://dev.azure.com/ORG/PROJECT/_git/REPO

# Create feature branch
git checkout -b feature/my-feature

# Commit changes
git add .
git commit -m "Add firewall rules"

# Push to remote
git push -u origin feature/my-feature

# Create pull request
git push origin HEAD:refs/pull-requests/new

# Merge branch
git checkout main
git merge feature/my-feature
git push origin main
```

---

## 🔐 Security Essentials

### Protect Production

```yaml
# Branch Policy Requirements
- Require pull request reviews ✓
- Require minimum 2 reviewers ✓
- Add build validation ✓
- Include code owners ✓
- Dismiss stale PR approvals ✓

# Environment Protection
- Manual approval on Production ✓
- Restrict approvers to admins only ✓
- Set approval timeout (6 hours) ✓
```

### Service Connection Security

```bash
# Test connection
az devops service-endpoint test --id <connection-id>

# Verify permissions
az role assignment list --assignee <sp-id>

# Rotate credentials (quarterly)
az ad sp credential reset --name terraform-sp
```

---

## 🔄 Pipeline Patterns

### Trigger Conditions

```yaml
# Trigger on specific branch
trigger:
  branches:
    include:
      - main
    exclude:
      - develop

# Run on schedule
schedules:
  - cron: "0 2 * * *"
    branches:
      include: [main]

# Trigger on file changes
paths:
  include:
    - '*.tf'
  exclude:
    - '*.md'

# Manual trigger only
trigger: none
pr: none
```

### Stage Conditions

```yaml
# Run on specific branch
condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')

# Run if previous succeeded
condition: succeeded()

# Run if pull request
condition: eq(variables['Build.Reason'], 'PullRequest')
```

---

## 📊 Pipeline Status Badges

Add to README.md:

```markdown
[![Build Status](https://dev.azure.com/ORG/PROJECT/_apis/build/status/PIPELINE_ID?branchName=main)](https://dev.azure.com/ORG/PROJECT/_build/latest?definitionId=PIPELINE_ID&branchName=main)
```

---

## 🛠️ Useful Shortcuts

### In Pipeline Run

| Key | Action |
|-----|--------|
| `L` | View logs |
| `S` | Save as template |
| `R` | Retry failed job |
| `A` | Approve pending job |
| `C` | View commits |

### In Azure DevOps

| Shortcut | Action |
|----------|--------|
| `G` + `B` | Go to branches |
| `G` + `P` | Go to pipelines |
| `G` + `R` | Go to repos |
| `/` | Search |
| `?` | Show help |

---

## 📈 Monitoring Pipelines

### Check Pipeline Health

```bash
# View recent runs
az pipelines runs list --definitions PIPELINE_ID --top 10

# Check run status
az pipelines runs show --id RUN_ID

# Get pipeline statistics
az pipelines show --id PIPELINE_ID | jq '.statistics'
```

### Common Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| ✅ | Succeeded | Deploy is good |
| ❌ | Failed | Fix errors and retry |
| ⏳ | In progress | Wait for completion |
| 🟡 | Warning | Review warnings |
| ⏸️ | Canceled | Check why stopped |
| 🔒 | Waiting | Approval needed |

---

## 🐛 Debugging Tips

### Pipeline Won't Start

```bash
# Check branch exists
git branch -a

# Check pipeline trigger
az pipelines show --id PIPELINE_ID | jq '.triggers'

# Verify file paths
git log --name-only | head -20
```

### Terraform Init Fails

```bash
# Verify backend config
terraform init -backend=false  # Skip backend

# Check storage account
az storage account show --name stterraformstate

# Verify container exists
az storage container exists --account-name stterraformstate --name tfstate
```

### Permission Denied

```bash
# Check service principal permissions
az role assignment list --assignee SERVICE_PRINCIPAL_ID

# Grant additional permissions
az role assignment create \
  --assignee SERVICE_PRINCIPAL_ID \
  --role Contributor \
  --scope /subscriptions/SUBSCRIPTION_ID
```

---

## 📝 Useful Variables

### Predefined Variables

```yaml
steps:
  - script: |
      echo "Build ID: $(Build.BuildId)"
      echo "Build Number: $(Build.BuildNumber)"
      echo "Source Branch: $(Build.SourceBranch)"
      echo "Source Version: $(Build.SourceVersion)"
      echo "Artifacts Dir: $(Build.ArtifactStagingDirectory)"
      echo "Build Reason: $(Build.Reason)"
      echo "PR Number: $(System.PullRequest.PullRequestNumber)"
```

### Custom Variables

```yaml
variables:
  # String
  myString: value

  # Template variable
  myTemplate: ${{ variables.otherVar }}

  # Secret (use in scripts)
  mySecret: $(secrets.apikey)

  # From variable group
  groupVar: $(varFromGroup)
```

---

## 🚨 Emergency Procedures

### Cancel Running Pipeline

```bash
az pipelines runs update --id RUN_ID --status cancelling
```

### Delete Failed Run (Keep State)

```bash
# Don't delete - just disable notifications
az devops service-endpoint update --id CONNECTION_ID --disable
```

### Force Unlock State

If Terraform state is locked:

```bash
# Option 1: Via Azure CLI
az storage blob lock break \
  --account-name stterraformstate \
  --container-name tfstate \
  --name "vwan/terraform.tfstate.lock"

# Option 2: Via Portal
# Navigate to storage account → Container → Select tfstate.lock → Delete
```

### Rollback Deployment

```bash
# Get previous state
az storage blob list --account-name stterraformstate --container-name tfstate

# Restore previous version (if versioning enabled)
az storage blob copy start-batch \
  --source-container tfstate \
  --destination-container tfstate-backup
```

---

## 📚 Documentation Links

### Quick Access

| Resource | Link |
|----------|------|
| **Pipeline Docs** | https://learn.microsoft.com/azure/devops/pipelines/ |
| **Terraform Task** | https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks |
| **Variable Groups** | https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups |
| **Service Connections** | https://learn.microsoft.com/azure/devops/pipelines/library/service-endpoints |
| **YAML Reference** | https://learn.microsoft.com/azure/devops/pipelines/yaml-schema |

---

## 🎯 Performance Tips

### Speed Up Pipelines

```yaml
# Parallel jobs
strategy:
  parallel: 3

# Skip unnecessary cache
- task: CacheBeta@1
  inputs:
    key: terraform | $(Agent.OS) | terraform.lock.hcl
    path: $(System.DefaultWorkingDirectory)/.terraform

# Use specific VM image
pool:
  vmImage: 'ubuntu-20.04'  # Use LTS versions

# Reduce artifact size
- task: PublishPipelineArtifact@1
  inputs:
    artifactName: 'plans'
    targetPath: 'tfplan'
    ## Not entire directory
```

### Cost Optimization

- Use free tier (1800 min/month)
- Cancel long-running pipelines
- Consolidate jobs where possible
- Use caching

---

## ✅ Checklists

### Pre-Deployment Checklist

- [ ] Service principal created
- [ ] Service connection tested
- [ ] Variable groups created
- [ ] Branch policies enabled
- [ ] Approvers assigned
- [ ] Pipeline runs on PR
- [ ] Manual approval works
- [ ] Notifications configured

### Post-Deployment Checklist

- [ ] Infrastructure deployed successfully
- [ ] All resources created
- [ ] Connectivity verified
- [ ] Logging enabled
- [ ] Alerts configured
- [ ] Documentation updated
- [ ] Team notified
- [ ] Runbooks created

---

## 🔗 Related Documentation

- [AZURE-DEVOPS-SETUP.md](AZURE-DEVOPS-SETUP.md) - Detailed setup guide
- [DEVOPS-EXAMPLES.md](DEVOPS-EXAMPLES.md) - Example pipelines
- [VARIABLE-GROUPS.md](VARIABLE-GROUPS.md) - Variable group reference
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Terraform deployment guide
- [README.md](../README.md) - Project overview

---

## 📞 Getting Help

### Where to Find Answers

1. **Check logs** - Pipeline run logs in Azure DevOps
2. **Search documentation** - Microsoft Learn docs
3. **Review examples** - See DEVOPS-EXAMPLES.md
4. **Check GitHub issues** - Terraform provider issues
5. **Contact support** - Azure or GitHub support

### Template Issues

```yaml
# If pipeline doesn't show, check:
# 1. Correct file path: azure-pipelines.yml
# 2. Correct branch: main or develop
# 3. YAML syntax: Use VS Code extension
# 4. Indentation: YAML is whitespace-sensitive
```

---

**Last Updated:** February 25, 2026

This guide covers the most common scenarios. For detailed information, see the linked documentation.
