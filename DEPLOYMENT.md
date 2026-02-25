# Azure vWAN Deployment Guide

## Quick Start (5 minutes)

```bash
# 1. Authenticate with Azure
az login

# 2. Set your subscription
az account set --subscription "your-subscription-id"

# 3. Setup remote state backend
chmod +x scripts/setup_state.sh
./scripts/setup_state.sh

# 4. Initialize Terraform
terraform init

# 5. Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

## Detailed Deployment Steps

### Step 1: Prerequisites Setup

```bash
# Install Azure CLI (macOS)
brew install azure-cli

# Install Terraform (macOS)
brew install terraform

# Verify installations
az version
terraform version

# Login to Azure
az login

# List available subscriptions
az account list --output table

# Set default subscription
az account set --subscription "your-subscription-id"

# Verify subscription
az account show
```

### Step 2: Configure Remote State Backend

The Terraform state will be stored in Azure Storage Account, allowing team collaboration and preventing state conflicts.

```bash
# Make setup script executable
chmod +x scripts/setup_state.sh

# Run with default values
./scripts/setup_state.sh

# Or customize parameters
./scripts/setup_state.sh my-rg my-storage-account my-container eastus
```

**What the script does:**
1. Creates a resource group
2. Creates a storage account with versioning
3. Creates a blob container
4. Outputs configuration to use in terraform/backend.tf

**Note:** Save the output values and storage key for future reference.

### Step 3: Configure Terraform

#### Update backend.tf
The `backend.tf` file should already contain placeholder values. If needed, update it:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "vwan/terraform.tfstate"
  }
}
```

#### Update terraform.tfvars
Edit `terraform.tfvars` with your environment-specific values:

```hcl
# Update these values for your deployment
resource_group_name = "rg-vwan-prod"
location            = "eastus"          # Change to your region
environment         = "prod"
vwan_name           = "vwan-prod-eastus"
vhub_name           = "vhub-prod-eastus"
firewall_name       = "afw-prod-eastus"
firewall_sku_tier   = "Standard"        # Standard or Premium

# Customize virtual networks
virtual_networks = {
  "vnet-prod-we-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
  "vnet-prod-we-002" = {
    address_space   = ["10.2.0.0/16"]
    enable_firewall = true
  }
}

# Enable logging (optional)
enable_logging = true
# log_analytics_workspace_id = "your-workspace-id" # If using Log Analytics
```

### Step 4: Authenticate Terraform

Choose one method based on your use case:

#### Method A: Azure CLI (Development - Recommended)
```bash
# Ensure you're logged in
az login

# Terraform will automatically use the authenticated context
# No additional configuration needed
```

#### Method B: Service Principal (Automation/CI-CD)
```bash
# Create Service Principal
az ad sp create-for-rbac --name terraform-sp --role Contributor

# Set environment variables
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscription_id>"
export ARM_TENANT_ID="<tenant_id>"
```

#### Method C: Managed Identity (Azure VMs/Container instances)
```bash
# When running from Azure resources with managed identity
# No configuration needed - Terraform will auto-detect
```

### Step 5: Initialize Terraform

```bash
# Initialize Terraform working directory
terraform init

# Expected output:
# - Downloads Azure provider
# - Initializes backend (connects to storage account)
# - Creates .terraform directory
```

### Step 6: Validate Configuration

```bash
# Check syntax and validate configuration
terraform validate

# Format code (optional but recommended)
terraform fmt -recursive

# Or use make target
make validate
make fmt
```

### Step 7: Plan Deployment

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan carefully:
# - Check resources to be created
# - Verify quantity and names
# - Ensure no deletions are planned
# - Review firewall rules

# Save plan to file (or use -out as shown above)
```

**Output example:**
```
Plan: 35 to add, 0 to change, 0 to destroy.
```

### Step 8: Apply Configuration

```bash
# Apply the planned changes
terraform apply tfplan

# Or without saved plan (will prompt interactively)
terraform apply

# Deployment takes 10-20 minutes
# Monitor progress in terminal output
```

**Progress indicators:**
```
azurerm_resource_group.rg: Creating...
azurerm_virtual_wan.vwan: Creating...
azurerm_virtual_hub.vhub: Creating...
azurerm_firewall.afw: Creating...
azurerm_virtual_network.vnet: Creating...
azurerm_virtual_hub_connection.hub_conn: Creating...
```

### Step 9: Verify Deployment

```bash
# Display all outputs
terraform output

# Check specific values
terraform output firewall_private_ip
terraform output vwan_id

# Verify in Azure Portal or CLI
az vwan list --output table
az firewall list --output table
az network vnet list --output table

# Verify firewall is operational
az firewall show \
  --resource-group "rg-vwan-prod" \
  --name "afw-prod-eastus" \
  --query "{name:name, provisioning_state:provisioningState}" -o table
```

## Configuration Customization

### Add More Virtual Networks

Edit `terraform.tfvars`:

```hcl
virtual_networks = {
  "vnet-prod-we-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
  "vnet-prod-we-002" = {
    address_space   = ["10.2.0.0/16"]
    enable_firewall = true
  }
  "vnet-prod-we-003" = {  # New vnet
    address_space   = ["10.3.0.0/16"]
    enable_firewall = true
  }
}
```

Then:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Update Firewall Rules

Edit `firewall.tf` to modify firewall policies:

```hcl
# Add new network rules
rule {
  name                  = "CustomRule"
  protocols             = ["TCP"]
  source_addresses      = ["192.168.0.0/16"]
  destination_addresses = ["10.0.0.0/8"]
  destination_ports     = ["443"]
}
```

### Enable Premium Firewall Features

```hcl
firewall_sku_tier = "Premium"  # Change from Standard
```

Then reapply:
```bash
terraform plan
terraform apply
```

## Monitoring and Management

### View Resource Status

```bash
# Resources in resource group
az resource list --resource-group "rg-vwan-prod" --output table

# Firewall status
az firewall show --resource-group "rg-vwan-prod" --name "afw-prod-eastus"

# Virtual Hub connections
az network vhub list --output table

# Firewall rules
az network firewall policy rule collection list \
  --firewall-policy "afw-prod-eastus-policy" \
  --resource-group "rg-vwan-prod" \
  --output table
```

### Enable Diagnostics and Monitoring

```bash
# Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group "rg-vwan-prod" \
  --workspace-name "vwan-logs"

# Get workspace ID
az monitor log-analytics workspace show \
  --resource-group "rg-vwan-prod" \
  --workspace-name "vwan-logs" \
  --query id -o tsv

# Update terraform.tfvars with workspace ID
# Then reapply terraform
```

### Query Firewall Logs

```bash
# Requires Log Analytics Workspace configured

# Network rules triggered
az monitor log-analytics query \
  --workspace "/subscriptions/.../workspaces/vwan-logs" \
  --analytics-query "AzureDiagnostics | where Type == 'AzureFirewallNetworkRule'"
```

## Troubleshooting

### Issue: "Firewall provisioning timeout"
**Solution:**
```bash
# Check firewall provisioning state
az firewall show --resource-group "rg-vwan-prod" --name "afw-prod-eastus" \
  --query "provisioningState"

# Firewall can take 15+ minutes to fully provision
# Wait and check again
```

### Issue: "Hub connection fails"
**Solution:**
```bash
# Verify vnet is properly connected
az network vhub connection show \
  --resource-group "rg-vwan-prod" \
  --vhub-name "vhub-prod-eastus" \
  --name "vnet-prod-we-001-to-hub"

# Check vnet peering status
az network vnet peering list --resource-group "rg-vwan-prod" --vnet-name "vnet-prod-we-001"
```

### Issue: "Terraform state lock"
**Solution:**
```bash
# View state locks
terraform state list

# If lock is stuck
terraform force-unlock <lock-id>

# Verify storage account access
az storage account show --name "stterraformstate" --query id
```

### Issue: "Authentication failed"
**Solution:**
```bash
# Verify current authentication
az account show

# Re-authenticate
az login

# Set correct subscription
az account set --subscription "your-subscription-id"

# For Service Principal, verify environment variables are set
env | grep ARM_
```

## Updating the Infrastructure

### Minor Updates (e.g., firewall rules)
```bash
# Edit firewall.tf with new rules
nano firewall.tf

# Plan and apply
terraform plan
terraform apply
```

### Major Upgrades (e.g., new vnet)
```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Plan changes
terraform plan -out=tfplan

# Review carefully before applying
terraform apply tfplan
```

### Version Updates
```bash
# Update Terraform provider version
terraform init -upgrade

# Check for provider updates
terraform version
```

## Destruction (Cleanup)

**WARNING: This will delete all resources!**

```bash
# Plan destruction
terraform plan -destroy

# Destroy all infrastructure
terraform destroy

# Confirm the prompt with 'yes'

# Verify deletion in Azure
az group list --output table
```

## Cost Management

### Estimate Monthly Cost

```bash
# Azure pricing (as of 2026):
# - Virtual WAN: ~$100/month
# - Firewall Standard: ~$900/month + throughput
# - Virtual Networks: ~$0.08/hour each
# - Storage (state): <$1/month

# Total estimated: $1000-1500/month for this configuration
```

### Cost Optimization Tips

1. **Use Standard Firewall Tier** - if Premium features not needed
2. **Rightsize VNets** - don't create unnecessary networks
3. **Monitor throughput** - optimize firewall rules
4. **Reserved instances** - for long-term deployments
5. **Scheduled shutdown** - for non-production environments

## Support and Resources

- **Azure Documentation**: https://learn.microsoft.com/azure/
- **Terraform Docs**: https://www.terraform.io/docs/
- **Azure Firewall**: https://learn.microsoft.com/azure/firewall/
- **vWAN**: https://learn.microsoft.com/azure/virtual-wan/

## Next Steps

1. ✅ Complete initial deployment
2. ✅ Verify all resources are running
3. Configure monitoring and alerting
4. Implement backup strategy for state
5. Set up CI/CD pipeline for automated deployments
6. Document your specific requirements and customizations
7. Plan regular security audits
