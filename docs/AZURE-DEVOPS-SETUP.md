# Azure DevOps Integration Setup Guide

## Overview

This guide walks you through setting up Continuous Integration/Continuous Deployment (CI/CD) using Azure DevOps Pipelines for automated Terraform deployments of the vWAN infrastructure.

## Architecture

```
Git Repository (Main/Develop Branches)
           ↓
    [Commit/PR Trigger]
           ↓
    Azure DevOps Pipeline
    ├─ Validate Stage (PR & Develop)
    │  ├─ Terraform Format Check
    │  ├─ Terraform Validate
    │  └─ Terraform Plan
    ├─ Security Stage (TFSec Scan)
    ├─ Apply Stage (Main Only - with Approval)
    │  └─ Terraform Apply
    └─ Post-Deployment Validation
           ↓
    Azure Resources (vWAN, Firewall, Networks)
```

## Prerequisites

1. **Azure DevOps Organization** - https://dev.azure.com
2. **Git Repository** - Azure Repos or GitHub
3. **Azure Subscription** - Same subscription for deployment
4. **Service Principal** - For Terraform authentication

## Setup Steps

### Step 1: Create Service Principal

The pipeline needs a service principal to authenticate with Azure.

```bash
# Create Service Principal with Contributor role
az ad sp create-for-rbac \
  --name "terraform-pipeline-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Output will include:
# "appId": "xxxxx",
# "password": "xxxxx",
# "tenant": "xxxxx"
```

**Save these values securely** - you'll need them in Step 3.

### Step 2: Create Azure DevOps Project

1. Go to https://dev.azure.com
2. Click "New project"
3. Fill in project details:
   - **Project name**: `vwan-infrastructure`
   - **Visibility**: Private (recommended)
   - **Version control**: Git
4. Click "Create"

### Step 3: Push Repository to Azure Repos

```bash
# Initialize git repo locally
cd /Users/aoredope/deploy-vwan
git init
git add .
git commit -m "Initial vWAN Terraform configuration"

# Add remote (get the URL from Azure Repos)
git remote add origin https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/deploy-vwan
git branch -M main
git push -u origin main

# Create develop branch
git checkout -b develop
git push -u origin develop
```

### Step 4: Create Service Connection in Azure DevOps

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager** → **Service Principal (Manual)**
3. Fill in the fields from Step 1:
   - **Subscription ID**: Your Azure subscription ID
   - **Subscription Name**: Your subscription name
   - **Service Principal Id**: appId
   - **Service Principal Key**: password
   - **Tenant ID**: tenant
   - **Service connection name**: `Azure-Terraform-SP` (must match pipeline)
4. Click **Verify** to test
5. Click **Save**

### Step 5: Create Variable Groups

Variable groups store sensitive values without exposing them in commits.

**Via Azure DevOps UI:**

1. Go to **Pipelines** → **Library** → **Variable groups**
2. Click **+ Variable group**

**Create two variable groups:**

#### Variable Group 1: `terraform-dev`
```
terraformVersion: 1.5.0
environment: dev
resourceGroupName: rg-vwan-dev
backendResourceGroup: rg-terraform-state
backendStorageAccount: stterraformstate
backendContainerName: tfstate
backendKey: vwan-dev/terraform.tfstate
```

#### Variable Group 2: `terraform-prod`
```
terraformVersion: 1.5.0
environment: prod
resourceGroupName: rg-vwan-prod
backendResourceGroup: rg-terraform-state
backendStorageAccount: stterraformstate
backendContainerName: tfstate
backendKey: vwan/terraform.tfstate
```

### Step 6: Create the Pipeline

1. Go to **Pipelines** → **Pipelines** → **New pipeline**
2. Select **Azure Repos Git**
3. Select your repository: `deploy-vwan`
4. Choose **Existing Azure Pipelines YAML file**
5. Select **Branch**: `main`
6. Select **Path**: `azure-pipelines.yml`
7. Click **Continue**
8. Review the YAML
9. Click **Save and run** or **Save**

### Step 7: Create Pipeline Approvers

Set up manual approval for production deployments:

1. Go to **Pipelines** → **Environments**
2. Click **Create environment** → Name it `Production`
3. Click ⋮ (more options) → **Approvals and checks**
4. Click **Create approval check**
5. Add team members who can approve deployments
6. Set timeout if desired
7. Click **Create**

### Step 8: Update azure-pipelines.yml

Update service connection name if different:

```yaml
variables:
  azureSubscriptionEndpoint: 'Azure-Terraform-SP'  # Match your service connection name
```

## Pipeline Workflow

### On Pull Request (to main)
1. ✅ **Validate** - Format, syntax, plan
2. ✅ **Security** - TFSec scan
3. 📋 **Results** - Shown on PR with plan output

### On Push to Develop
1. ✅ **Validate** - Full validation
2. ✅ **Security** - TFSec scan
3. 📋 **Artifacts** - Plan stored

### On Push to Main
1. ✅ **Validate** - Pass validation
2. ✅ **Security** - Pass security scan
3. ⏳ **Approval** - Wait for approver
4. ✅ **Apply** - Deploy infrastructure
5. ✅ **Post-Deploy** - Validation checks

## Using the Pipeline

### Workflow Example

**Development Workflow:**
```bash
# Create feature branch
git checkout -b feature/add-sql-db

# Make changes
nano firewall.tf
# ... make edits ...

# Commit and push
git add .
git commit -m "Add SQL database firewall rules"
git push -u origin feature/add-sql-db

# Create Pull Request
# - Go to Azure Repos
# - Create PR to 'main'
# - Review plan in PR
# - Request review from team
# - Address feedback
# - Code review approved
# - Merge to main
```

**Production Deployment:**
```
After merge to main:
1. Pipeline runs Validate stage
2. If successful, Apply stage awaits approval
3. Approver reviews and approves
4. Infrastructure is deployed
5. Post-deployment validation runs
```

## Monitoring Pipeline Runs

### View Pipeline Execution

1. Go to **Pipelines** → **Pipelines**
2. Click your pipeline
3. View **Runs** tab
4. Click a run to see details

### Check Pipeline Logs

1. In run details, click a stage/job
2. View real-time logs
3. Download logs if needed

### Pipeline Status in Git

Pull requests show pipeline status automatically:
- ✅ All checks pass
- ❌ Validation failed
- ⏳ Still running
- ⏸️ Awaiting approval

## Advanced Configurations

### Schedule Pipeline Runs

```yaml
schedules:
  - cron: "0 2 * * 0"  # 2 AM Sunday UTC
    displayName: Weekly validation
    branches:
      include:
        - main
```

### Matrix Build (Multiple Environments)

```yaml
strategy:
  matrix:
    dev:
      environment: dev
      tfVars: terraform-dev.tfvars
    staging:
      environment: staging
      tfVars: terraform-staging.tfvars
    prod:
      environment: prod
      tfVars: terraform-prod.tfvars
```

### Conditional Steps

```yaml
- script: echo "Running tests"
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
```

### Notifications

1. Go to **Project Settings** → **Service connections**
2. Create connection to **Slack** or **Teams**
3. Add notification step in pipeline

## Troubleshooting

### Pipeline Fails at Auth

**Problem**: `Error: retrieving subscriptions for service principal`

**Solution**:
- Verify Service Principal credentials
- Ensure SP has Contributor role on subscription
- Check Service Connection is properly configured

### Terraform Plan Shows No Changes

**Problem**: `No changes. Infrastructure is up-to-date.`

**Solution**: This is expected when infrastructure already exists and no changes were made. If you expect changes, verify terraform.tfvars values.

### State Lock Error

**Problem**: `Error acquiring the state lock: Error: resource references count.this[0] which doesn't exist in state`

**Solution**:
```bash
# Force unlock from local terminal
az storage blob lock break \
  --account-name stterraformstate \
  --container-name tfstate \
  --name "vwan/terraform.tfstate.lock"
```

### Approval Not Showing

**Problem**: Apply stage doesn't wait for approval

**Solution**:
1. Ensure pipeline targets 'main' branch only
2. Check environment is set on job
3. Verify approvers are added in environment settings

## Security Best Practices

### ✅ Recommended Practices

1. **Separate Service Principals**
   ```bash
   # Dev/Test SP
   az ad sp create-for-rbac --name "terraform-dev-sp"
   
   # Prod SP
   az ad sp create-for-rbac --name "terraform-prod-sp"
   ```

2. **Limit Service Principal Permissions**
   ```bash
   # Instead of Contributor, use custom role
   az role definition create --role-definition terraform-role.json
   az role assignment create --role "Terraform-Operator" \
     --assignee-object-id <SP_OBJECT_ID>
   ```

3. **Use Managed Identities** (for VMs/pods)
   ```bash
   # On Azure VM, use system-assigned MI
   # Pipeline automatically uses MI when available
   ```

4. **Enable Audit Logging**
   ```bash
   az monitor diagnostic-settings create \
     --name "pipeline-audit" \
     --resource-type "Microsoft.DevOps/Pipelines"
   ```

5. **Regularly Rotate Service Principal Secrets**
   ```bash
   # Update Service Principal password quarterly
   az ad sp credential reset --name terraform-pipeline-sp
   ```

### ✅ Branch Protection

1. Go to **Repos** → **Branches** → **main**
2. Click ⋮ → **Branch policies**
3. Enable:
   - ✓ Require pull request reviews
   - ✓ Require a minimum number of reviewers (set to 2)
   - ✓ Allow completion with rejected changes: Unchecked
4. Add build validation
5. Click **Save**

### ✅ Variable Group Protection

1. In **Library** → **Variable groups**
2. Click lock icon for sensitive groups
3. Enable **Link secrets for use in all pipelines**
4. Restrict who can edit the group

## Cost Management

### Pipeline Execution Costs

- **Free tier**: 1,800 build minutes/month
- **paid tier**: Unlimited build minutes
- **Storage**: Artifacts stored for 30 days

### Optimize Build Duration

```yaml
# Run stages in parallel where possible
stages:
  - stage: Validate
    dependsOn: []  # Runs independently
  
  - stage: Security
    dependsOn: []  # Parallel with Validate
  
  - stage: Apply
    dependsOn: [Validate, Security]  # Sequential
```

## Maintenance

### Review Pipeline Regularly

**Monthly:**
- Review failed runs
- Check cost of pipeline runs
- Update Terraform version if needed

**Quarterly:**
- Security audit of Service Principal
- Review approvers list
- Check for deprecated tasks

### Update Tasks

```bash
# Check for task updates
# Go to Pipelines → Edit → Show marketplace tasks for updates

# Pin specific versions to prevent breaking changes
- task: TerraformTaskV3@3
  inputs:
    version: '0.1.173'
```

## Troubleshooting Reference

| Issue | Solution |
|-------|----------|
| Service Connection fails | Verify SP credentials in portal |
| State lock error | Run local force-unlock or check storage |
| Plan shows errors | Check terraform.tfvars syntax |
| Apply hangs | Check Azure Portal for resource activity |
| Approval not triggered | Verify build targets main branch |
| Large plan output | Reduce VNet count in tfvars |

## Example Pipeline Runs

### Successful PR Run
```
Validate
├─ TerraformValidate ............ ✅ PASSED
├─ TFSec ......................... ✅ PASSED (No issues)
└─ TerraformPlan ................ ✅ PASSED
   Plan: 35 to add, 0 to change, 0 to destroy
```

### Failed PR Run
```
Validate
├─ TerraformValidate ............ ❌ FAILED
│  Error: Invalid resource configuration
└─ Pipeline stopped
```

### Successful Main Merge Run
```
Validate ........................ ✅ PASSED
Security ........................ ✅ PASSED
Apply (Awaiting Approval) ....... ⏳ PENDING
  [Approver reviews plan]
Apply ........................... ✅ APPROVED
├─ TerraformInit ................ ✅ PASSED
├─ TerraformApply ............... ✅ COMPLETED
└─ PostDeployValidation ......... ✅ PASSED
Deployment Time: 18 minutes
```

## Next Steps

1. ✅ Create Service Principal
2. ✅ Setup Azure DevOps Project
3. ✅ Push repository
4. ✅ Create Service Connection
5. ✅ Create Variable Groups
6. ✅ Create Pipeline
7. ✅ Test with a PR
8. ✅ Test merge to main
9. Implement branch protection
10. Setup team notifications
11. Configure monitoring
12. Document team workflows

## Resources

- [Azure Pipelines Documentation](https://learn.microsoft.com/azure/devops/pipelines/)
- [Azure Resource Manager Extension](https://marketplace.visualstudio.com/items?itemName=microsoft.vsts-rm-extensions)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure DevOps REST API](https://learn.microsoft.com/rest/api/azure/devops/)

## Support

For issues:
1. Check pipeline logs in Azure DevOps
2. Review error details in stage summary
3. Consult [DEPLOYMENT.md](../DEPLOYMENT.md) troubleshooting section
4. Check Azure Portal for resource-specific issues

---

**Last Updated:** February 25, 2026
