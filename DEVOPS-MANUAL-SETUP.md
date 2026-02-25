# Azure DevOps Manual Setup Guide

Due to lab environment restrictions, automatic Service Principal creation is limited. Use this manual setup instead.

## Option 1: Use Azure CLI Authentication (Recommended for Labs)

This approach uses your current Azure CLI credentials directly in the pipeline.

### Step 1: Store Storage Account Key in Variable Group

```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group 1-1b120876-playground-sandbox \
  --account-name stterraformstate1683 \
  --query "[0].value" -o tsv)

echo "Storage Key: $STORAGE_KEY"
```

### Step 2: Create Azure DevOps Variable Group

1. Go to: `https://dev.azure.com/CiscoIaac/vwan-infrastructure`
2. Navigate to **Pipelines** → **Library** → **Variable groups**
3. Click **Create variable group**

**For Non-Production (ea-np):**
- Name: `vwan-nonprod-secrets`
- Variables:
  - `TERRAFORM_VERSION`: `1.14.5`
  - `AZURE_STORAGE_ACCOUNT`: `stterraformstate1683`
  - `AZURE_STORAGE_KEY`: (paste the key from above)
  - `STATE_RG`: `1-1b120876-playground-sandbox`
  - `RESOURCE_GROUP`: `1-1b120876-playground-sandbox`
  - `ENVIRONMENT`: `nonprod`

**For Production (ea-prd):**
- Name: `vwan-prod-secrets`
- Same variables as above but with:
  - `ENVIRONMENT`: `prod`

### Step 3: Create Pipeline from YAML

1. Go to **Pipelines** → **Create Pipeline**
2. Select **Azure Repos Git** → **deploy-vwan**
3. Select **Existing Azure Pipelines YAML file**
4. Path: `azure-pipelines.yml` 
5. Click **Save and run**

### Step 4: Link Variable Groups to Pipeline

Go to Pipeline Settings and link both variable groups to the pipeline.

---

## Option 2: PAT Token Authentication

### Step 1: Create Personal Access Token (PAT)

1. Go to: `https://dev.azure.com/CiscoIaac/_usersSettings/tokens`
2. Click **New Token**
3. Configure:
   - Name: `terraform-deployment`
   - Scope: **Full access**
   - Expiration: 90 days
4. Click **Create** and copy the token

### Step 2: Store in Azure Variable Group

```bash
# In Azure DevOps Variable Group (vwan-prod-secrets):
AZURE_DEVOPS_PAT="<your-pat-token>"
AZURE_DEVOPS_ORG_URL="https://dev.azure.com/CiscoIaac"
```

---

## Two-Branch Workflow

### ea-np Branch (Non-Production - Auto Deploy)
- Triggers on push automatically
- Uses terraform state key: `vwan-nonprod/terraform.tfstate`
- Deploys to resource group: `1-1b120876-playground-sandbox`
- Firewall SKU: Standard (cost optimized)

### ea-prd Branch (Production - Manual Approval)
- Requires manual approval in Azure DevOps
- Uses terraform state key: `vwan/terraform.tfstate`
- Deploys to resource group: `1-1b120876-playground-sandbox`
- Firewall SKU: Premium (full features)

---

## Testing the Pipeline

### 1. Verify Variable Groups
```bash
az pipelines variable-group list --org https://dev.azure.com/CiscoIaac --project vwan-infrastructure
```

### 2. Push to ea-np Branch
```bash
git checkout ea-np
git add .
git commit -m "Test ea-np deployment"
git push origin ea-np
```

This will trigger the pipeline automatically.

### 3. Monitor Pipeline Execution
- Go to: `https://dev.azure.com/CiscoIaac/vwan-infrastructure/_build`
- Click on your pipeline run to see logs

### 4. Promote to Production (ea-prd)
```bash
git checkout ea-prd
git merge ea-np
git push origin ea-prd
```

This will queue a pipeline run that waits for manual approval in Azure DevOps.

---

## Pipeline Stages

| Stage | Branch | Trigger | Action |
|-------|--------|---------|--------|
| **DetermineEnvironment** | Both | Automatic | Sets vars based on branch |
| **Validate** | Both | Automatic | Runs terraform fmt & validate |
| **Security** | Both | Automatic | Runs TFSec scanning |
| **ApplyNonProd** | ea-np | Automatic | Deploys without approval |
| **ApplyProd** | ea-prd | Requires Approval | Deploys after manual approval |
| **PostDeploy** | Both | Automatic | Tests deployed resources |

---

## Troubleshooting

### Pipeline shows "Waiting for approval"
- Go to Pipeline run
- Click **Review** on the ApplyProd stage
- Select **Approve** and click **Approve**

### State lock error
```bash
# Force unlock state (if stuck)
terraform force-unlock <lock-id>
```

### Variable group not found
- Ensure variable group is linked to pipeline
- Go to Pipeline Settings → Variable groups → Link

---

## Next Steps

1. ✅ Create variable groups in Azure DevOps
2. ✅ Create pipeline from YAML
3. ✅ Push code to repository
4. Test ea-np deployment
5. Merge to ea-prd and approve production deployment

See [BRANCHING-STRATEGY.md](docs/BRANCHING-STRATEGY.md) for detailed workflow examples.
