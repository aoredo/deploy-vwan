# Azure DevOps Variable Groups Reference

This file defines all variable groups needed for the Terraform Azure DevOps pipelines.

## Variable Group: `terraform-common`

**Visibility:** Shared across all pipelines
**Description:** Common variables used in all environments

```hcl
terraformVersion = "1.5.0"
azureSubscriptionEndpoint = "Azure-Terraform-SP"
backendResourceGroup = "rg-terraform-state"
backendStorageAccount = "stterraformstate"
backendContainerName = "tfstate"
ciBuildAgent = "ubuntu-latest"
```

---

## Variable Group: `terraform-dev`

**Visibility:** Development environment only
**Description:** Development environment specific configuration

```hcl
environment = "dev"
location = "eastus"
resourceGroupName = "rg-vwan-dev"
vwanName = "vwan-dev-eastus"
vhubName = "vhub-dev-eastus"
firewallName = "afw-dev-eastus"
firewallSkuTier = "Standard"
backendAzureRmKey = "vwan-dev/terraform.tfstate"
enableLogging = "false"
tagsEnvironment = "development"
approvalsRequired = "0"
```

**Variable Groups Link:**
```bash
- group: 'terraform-dev'
```

---

## Variable Group: `terraform-staging`

**Visibility:** Staging environment only
**Description:** Staging environment specific configuration

```hcl
environment = "staging"
location = "eastus"
resourceGroupName = "rg-vwan-staging"
vwanName = "vwan-staging-eastus"
vhubName = "vhub-staging-eastus"
firewallName = "afw-staging-eastus"
firewallSkuTier = "Standard"
backendAzureRmKey = "vwan-staging/terraform.tfstate"
enableLogging = "true"
tagsEnvironment = "staging"
approvalsRequired = "1"
```

---

## Variable Group: `terraform-prod`

**Visibility:** Production environment only (Restricted)
**Description:** Production environment specific configuration

```hcl
environment = "prod"
location = "eastus"
resourceGroupName = "rg-vwan-prod"
vwanName = "vwan-prod-eastus"
vhubName = "vhub-prod-eastus"
firewallName = "afw-prod-eastus"
firewallSkuTier = "Premium"
backendAzureRmKey = "vwan/terraform.tfstate"
enableLogging = "true"
tagsEnvironment = "production"
approvalsRequired = "2"
```

**Security:** This group should have:
- ✅ Limited access (Project Admins only)
- ✅ Approval required for modifications
- ✅ Audit logging enabled
- ✅ Lock icon visible in UI

---

## Variable Group: `azure-credentials` (Secrets)

**Visibility:** All pipelines (use with caution)
**Description:** Azure authentication credentials

**IMPORTANT:** These should be stored as `secret` variables (marked with lock icon)

```
servicePrincipalId: <Your Service Principal App ID>
servicePrincipalSecret: <Your Service Principal Password>
servicePrincipalTenant: <Your Tenant ID>
subscriptionId: <Your Azure Subscription ID>
```

**Note:** These are automatically handled by Azure DevOps Service Connections. Do NOT create this group manually; instead use Service Connections.

---

## Variable Group: `notifications`

**Visibility:** All pipelines
**Description:** Notification endpoints and email addresses

```hcl
teamsWebhookUrl = "https://outlook.webhook.office.com/webhookb2/..." # Secret
slackWebhookUrl = "https://hooks.slack.com/services/..." # Secret
notificationEmail = "devops@company.com"
notificationOwner = "DevOps Team"
escalationEmail = "devops-lead@company.com"
```

---

## Variable Group: `cost-management`

**Visibility:** All pipelines (optional)
**Description:** Cost tracking and estimation

```hcl
infracostApiKey = "xxx" # Secret - from https://www.infracost.io
costAlertThreshold = "2000"
costAlertEmail = "finance@company.com"
enableCostTracking = "true"
```

---

## Variable Group: `security-scanning`

**Visibility:** All pipelines (optional)
**Description:** Security scanning tools

```hcl
tfsecEnabled = "true"
checkovEnabled = "true"
tribyEnabled = "false"
securityReportEmail = "security@company.com"
failOnHighSeverity = "true"
failOnCritical = "true"
```

---

## How to Create Variable Groups

### Via Azure DevOps UI

1. Go to **Pipelines** → **Library** → **Variable groups**
2. Click **+ Variable group**
3. Enter **Name**: e.g., `terraform-prod`
4. Add variables:
   - Click **+ Add**
   - Enter variable name and value
   - For secrets, click 🔒 lock icon
   - Click **OK**
5. Click **Save**

### Via Azure CLI

```bash
# Install Azure DevOps CLI extension
az extension add --name azure-devops

# Create variable group
az pipelines variable-group create \
  --organization "https://dev.azure.com/YOUR_ORG" \
  --project "YOUR_PROJECT" \
  --name "terraform-prod" \
  --variables \
    environment=prod \
    location=eastus \
    resourceGroupName=rg-vwan-prod
```

### Via REST API

```bash
curl -X POST \
  "https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/distributedtask/variablegroups?api-version=7.0" \
  -H "Authorization: Basic $(echo -n ':YOUR_PAT' | base64)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "terraform-prod",
    "variables": {
      "environment": {"value": "prod"},
      "location": {"value": "eastus"},
      "resourceGroupName": {"value": "rg-vwan-prod"}
    }
  }'
```

---

## Using Variable Groups in Pipelines

### In YAML Pipeline

```yaml
trigger:
  - main

variables:
  - group: terraform-common
  - group: terraform-prod

jobs:
  - job: Deploy
    variables:
      - name: customVar
        value: 'custom-value'
    steps:
      - script: echo $(environment) $(location)
        displayName: 'Use Variables'
```

### Conditional Variable Groups

```yaml
stages:
  - stage: Deploy
    variables:
      ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
        - group: terraform-prod
      ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/develop') }}:
        - group: terraform-dev
```

---

## Variable Precedence

Variables are resolved in this order (later overrides earlier):

1. **Collection variables** (defined in Organization Settings)
2. **Pipeline variables** (defined in YAML `variables:` section)
3. **Variable groups** (linked in pipeline)
4. **Job variables** (defined in job `variables:` section)
5. **Step variables** (defined in step `env:` section)

**Example Priority:**

```yaml
variables:              # Priority 1
  baseVar: original

jobs:
  - job: Test
    variables:          # Priority 4
      baseVar: job-override
    steps:
      - script: echo $(baseVar)  # Uses 'job-override'
        env:
          baseVar: step-override  # Priority 5 - but env vars work differently
```

---

## Updating Variable Groups

### Add New Variable

1. Go to **Pipelines** → **Library** → **Variable groups**
2. Click the variable group
3. Click **Edit**
4. Click **+ Add**
5. Enter name and value
6. Click **Save**

### Update Existing Variable

1. Click the variable group
2. Click **Edit**
3. Click the variable value to modify
4. Click **Update**
5. Click **Save**

### Delete Variable

1. Click the variable group
2. Click **Edit**
3. Click ✕ next to the variable
4. Click **Save**

---

## Secret Handling

### Marking Variables as Secrets

1. When adding/editing a variable, click the 🔒 **lock icon**
2. The variable becomes encrypted in storage
3. Value is masked in logs (displayed as `***`)
4. Cannot be viewed after creation

### Accessing Secret Variables

In pipeline YAML:
```yaml
steps:
  - script: echo $(servicePrincipalSecret)  # Masked in logs
    displayName: 'Secret stays hidden'
```

### Never Log Secrets

```yaml
# ❌ WRONG - Secret may be exposed
- script: |
    echo "Secret: $(servicePrincipalSecret)"
    env:
      SECRET: $(servicePrincipalSecret)

# ✅ RIGHT - Secret properly masked
- script: |
    echo "Authenticating..."
    # Secret used internally by task
    env:
      SECRET: $(servicePrincipalSecret)
```

---

## Validation Checklist

Before using variable groups in production:

- [ ] All required variables are defined
- [ ] Secret variables are marked with 🔒
- [ ] Environment-specific groups are linked to correct pipelines
- [ ] Prod group has restricted access
- [ ] All credentials are unique per environment
- [ ] Variable names follow naming convention
- [ ] Groups are tested with a PR first
- [ ] Audit logging is enabled for prod group

---

## Troubleshooting

### Variable Not Found Error

```
##[error]The variable 'variableName' is not defined
```

**Solution:**
1. Check variable name spelling
2. Verify variable group is linked to pipeline
3. Check variable isn't in a restricted group

### Secret Visible in Logs

**Problem:** `$(secretVar)` shows actual value

**Solution:**
1. Mark variable as secret (lock icon)
2. Clear pipeline cache: **Pipelines** → **Settings** → **Clear caches**
3. Rerun pipeline

### Variable Group Not Available

**Problem:** Variable group doesn't appear in pipeline dropdown

**Solution:**
1. Ensure you have Project Admin role
2. Try refreshing page
3. Check project level, not organization level

### Cross-Project Variable Groups

Variable groups can be shared across projects:

1. Create in one project
2. Go to **Library** → **Share**
3. Select other projects
4. Other projects can now link the group

---

## Best Practices

### ✅ DO

- ✅ Use environment-specific variable groups
- ✅ Mark all secrets with 🔒
- ✅ Use meaningful variable names
- ✅ Document variable purposes
- ✅ Keep secrets rotated
- ✅ Use Service Connections for credentials
- ✅ Enable audit logging for prod

### ❌ DON'T

- ❌ Commit secrets to Git
- ❌ Use plaintext for sensitive values
- ❌ Share production groups too broadly
- ❌ Reuse values across environments
- ❌ Log secret variables
- ❌ Hardcode values in YAML
- ❌ Use generic names

---

## Migration from Parameter Files

If migrating from `.tfvars` files to variable groups:

**Before (Local):**
```hcl
# terraform.tfvars
environment = "prod"
location    = "eastus"
```

**After (DevOps):**
```yaml
# azure-pipelines.yml
variables:
  - group: terraform-prod

steps:
  - script: |
      terraform apply \
        -var="environment=$(environment)" \
        -var="location=$(location)"
```

---

## Example: Complete Setup Script

```bash
#!/bin/bash

# Create all variable groups
ORG="https://dev.azure.com/YOUR_ORG"
PROJECT="YOUR_PROJECT"

create_group() {
  local NAME=$1
  local VARS=$2
  
  az pipelines variable-group create \
    --organization "$ORG" \
    --project "$PROJECT" \
    --name "$NAME" \
    --variables $VARS
}

# Common group
create_group "terraform-common" \
  terraformVersion=1.5.0 \
  azureSubscriptionEndpoint=Azure-Terraform-SP

# Environment groups
create_group "terraform-dev" \
  environment=dev \
  location=eastus \
  resourceGroupName=rg-vwan-dev

create_group "terraform-prod" \
  environment=prod \
  location=eastus \
  resourceGroupName=rg-vwan-prod

echo "Variable groups created successfully!"
```

---

For more information, see:
- [Azure DevOps Variable Groups Documentation](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups)
- [AZURE-DEVOPS-SETUP.md](AZURE-DEVOPS-SETUP.md)
- [DEVOPS-EXAMPLES.md](DEVOPS-EXAMPLES.md)
