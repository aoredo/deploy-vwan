# Azure vWAN with Firewall - Terraform Deployment

## Overview

This Terraform configuration deploys a production-ready Azure Virtual WAN (vWAN) infrastructure with Azure Firewall, supporting multiple virtual networks with centralized security policies.

## Architecture

```
┌─────────────────────────────────────────────┐
│         Azure Virtual WAN                   │
├─────────────────────────────────────────────┤
│  ┌───────────────────────────────────────┐  │
│  │     Virtual Hub (10.0.0.0/23)       │  │
│  │  ┌─────────────────────────────────┐ │  │
│  │  │   Azure Firewall (Premium)      │ │  │
│  │  │   - Network Rules               │ │  │
│  │  │   - Application Rules           │ │  │
│  │  │   - NAT Rules                   │ │  │
│  │  └─────────────────────────────────┘ │  │
│  └───────────────────────────────────────┘  │
│  │         │         │                      │
│  └─────┬───┴────┬────┴────┬────────────────┘
│        │        │         │
│        ▼        ▼         ▼
│    vnet-001  vnet-002  vnet-003
│   10.1.0.0   10.2.0.0   10.3.0.0
│    /16       /16       /16
│   (Hub Connection - Internet Security Enabled)
│
└─────────────────────────────────────────────┘
```

## Prerequisites

1. **Azure Subscription** - Active subscription with Contributor or Owner role
2. **Azure CLI** - Install from https://learn.microsoft.com/cli/azure/
3. **Terraform** - Version 1.0+ (install from https://www.terraform.io/downloads)
4. **Service Principal** (optional) - For CI/CD automation

## Files Overview

- `backend.tf` - Remote state configuration (Azure Storage)
- `provider.tf` - Azure provider configuration
- `variables.tf` - Input variables with defaults
- `outputs.tf` - Output values post-deployment
- `main.tf` - Virtual WAN and Hub resources
- `firewall.tf` - Azure Firewall and policies
- `network.tf` - Virtual networks and hub connections
- `routing.tf` - Advanced routing configuration
- `terraform.tfvars` - Variable values (customize for your environment)
- `scripts/setup_state.sh` - Initialize remote state backend

## Quick Start: Manual Deployment (5 minutes)

```bash
# 1. Authenticate with Azure
az login

# 2. Setup remote state backend
chmod +x scripts/setup_state.sh
./scripts/setup_state.sh

# 3. Deploy infrastructure
make init
make plan
make apply
```

## Quick Start: Azure DevOps CI/CD Automation (10 minutes)

### Two-Branch Strategy

This project uses **two deployment branches** for safe infrastructure changes:

- **`ea-np`** - Non-Production (Development/Testing)
  - Test new features here first
  - ✅ Auto-deploys on every push (no approval)
  - Use for: Validating rules, testing configs

- **`ea-prd`** - Production
  - ⏳ Requires manual approval before deploy
  - Only merge tested code from `ea-np`
  - Use for: Production workloads

**Workflow:**
```
1. Create feature branch → 2. Test in ea-np → 3. Merge to ea-prd → 4. Approve & Deploy
```

### Setup Azure DevOps

```bash
# 1. Setup Azure DevOps integration
chmod +x scripts/setup_devops.sh
./scripts/setup_devops.sh https://dev.azure.com/YOUR_ORG YOUR_PROJECT

# 2. Push to ea-np branch to test
git checkout -b ea-np origin/ea-np
git add .
git commit -m "Initial configuration"
git push -u origin ea-np

# 3. Creates PR to ea-prd when code tested
# 4. Requires approval before production deploy
```

**See [BRANCHING-STRATEGY.md](docs/BRANCHING-STRATEGY.md) for detailed workflow.**

---

## Setup Instructions (Manual)

### 1. Initialize Remote State Backend

The Terraform state is stored in Azure Storage (not local), enabling team collaboration and CI/CD integration.

```bash
# Make script executable
chmod +x scripts/setup_state.sh

# Run setup script with optional parameters
./scripts/setup_state.sh [resource_group_name] [storage_account_name] [container_name] [location]

# Example:
./scripts/setup_state.sh rg-terraform-state stterraformstate tfstate eastus
```

The script will:
- Create a resource group
- Create a storage account with versioning enabled
- Create a blob container
- Display configuration for backend.tf

### 2. Update Configuration

Edit `terraform.tfvars` with your specific values:

```hcl
resource_group_name = "rg-vwan-prod"
location            = "eastus"
vwan_name           = "vwan-prod-eastus"
# ... other settings
```

### 3. Set Authentication

Choose one authentication method:

**Option A: Azure CLI (Development)**
```bash
az login
# Terraform will use the authenticated context
```

**Option B: Service Principal (CI/CD)**
```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

**Option C: Environment Variables (Automation)**
```bash
export ARM_STORAGE_ACCOUNT="stterraformstate"
export ARM_STORAGE_KEY="your-storage-key"
```

### 4. Initialize Terraform

```bash
terraform init
```

Terraform will:
- Download required providers
- Initialize the remote state backend
- Create local .terraform directory

### 5. Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan for:
- Resources to be created
- No unexpected deletions
- Proper variable values

### 6. Apply Configuration

```bash
terraform apply tfplan
```

The deployment will take 10-15 minutes:
- Create resource group
- Create Virtual WAN and Hub
- Deploy Azure Firewall
- Create virtual networks
- Configure hub connections
- Set up routing and firewall policies

### 7. Verify Deployment

```bash
# Output important values
terraform output

# Check specific resource
terraform output firewall_private_ip

# Get all deployment info
terraform output deployment_summary
```

## Configuration Options

### Firewall SKU Tier

```hcl
firewall_sku_tier = "Standard"  # Standard or Premium
```

- **Standard**: Basic protection, NRU pricing
- **Premium**: Advanced threat detection, IDPS, TLS inspection

### Virtual Networks

Add or modify networks in `terraform.tfvars`:

```hcl
virtual_networks = {
  "vnet-prod-we-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true  # Route through firewall
  }
  # Add more networks as needed
}
```

### Enable Logging

```hcl
enable_logging = true
log_analytics_workspace_id = "/subscriptions/xxx/resourceGroups/yyy/providers/..."
```

## Firewall Policies

The configuration includes three rule collections:

### Network Rules
- **AllowInternalTraffic**: VNet-to-VNet communication
- **AllowDNS**: DNS queries on port 53
- **DenyInternetTraffic**: Block unauthorized internet access

### Application Rules
- **AllowMicrosoftServices**: Azure and Microsoft services

### NAT Rules
- **TranslateVnetTraffic**: Inbound traffic translation

Customize rules in `firewall.tf` based on your requirements.

## Management Commands

```bash
# View current state
terraform show

# Refresh state from Azure
terraform refresh

# Modify variable and replan
terraform plan -var="firewall_sku_tier=Premium"

# Destroy entire infrastructure
terraform destroy

# Target specific resource (advanced)
terraform apply -target=azurerm_firewall.afw
```

## Troubleshooting

### State Lock Issues

If Terraform hangs, the state may be locked:

```bash
# View lock info
terraform force-unlock <lock-id>
```

### Storage Account Issues

Verify storage account accessibility:

```bash
az storage account show --name stterraformstate --query id
az storage container exists --account-name stterraformstate --name tfstate
```

### Authentication Failures

```bash
# Verify current Azure authentication
az account show

# Switch subscriptions
az account set --subscription "your-subscription-id"

# Relogin
az login
```

### Firewall Deployment Timeout

Firewall deployment can take 15+ minutes. Check status:

```bash
az firewall show --resource-group rg-vwan-prod --name afw-prod-eastus
```

## Continuous Deployment with Azure DevOps

Deploy automatically on code changes using Azure Pipelines:

### Pipeline Workflow

```
Git Push/PR
    ↓
✓ Validate: Format, Syntax, Plan
✓ Security: TFSec Scan
✓ Approve: Manual approval (main branch)
✓ Apply: Deploy infrastructure
✓ Verify: Post-deployment tests
```

### Automated Deployment Features

- **Pull Request Validation** - Terraform plan shown on PR comments
- **Environment-Specific** - Different configs for dev/staging/prod
- **Approval Gates** - Require manual approval for production
- **Audit Trail** - All deployments logged
- **Rollback Support** - Easy infrastructure rollback

### Quick Setup

```bash
# Automate setup (requires Azure DevOps CLI)
chmod +x scripts/setup_devops.sh
./scripts/setup_devops.sh https://dev.azure.com/YOUR_ORG YOUR_PROJECT
```

### Documentation

- [AZURE-DEVOPS-SETUP.md](docs/AZURE-DEVOPS-SETUP.md) - Complete setup guide
- [DEVOPS-EXAMPLES.md](docs/DEVOPS-EXAMPLES.md) - Example pipelines and scenarios
- [VARIABLE-GROUPS.md](docs/VARIABLE-GROUPS.md) - Variable group reference
- [DEVOPS-QUICK-REFERENCE.md](docs/DEVOPS-QUICK-REFERENCE.md) - Quick reference guide

## Cost Optimization

- **Virtual WAN**: ~$100/month (hub)
- **Firewall Standard**: ~$1.25/hour (~$900/month) + throughput cost
- **Firewall Premium**: ~$5/hour (~$3,600/month)
- **Virtual Network**: ~$0.08/hour (minimal)
- **Storage Account**: ~$0.50/month (state storage)

**Recommendation**: Start with Standard tier, upgrade to Premium if advanced security is needed.

## Security Best Practices

1. **State File Security**
   - Store in encrypted storage with versioning
   - Restrict access via RBAC
   - Enable soft delete and retention policies

2. **Firewall Rules**
   - Start with deny-all policy
   - Whitelist only necessary traffic
   - Review and audit rules quarterly

3. **Network Segmentation**
   - Use separate route tables per environment
   - Implement micro-segmentation with NSGs
   - Monitor firewall logs

4. **Access Control**
   - Use Service Principals with minimal permissions
   - Implement MFA for manual deployments
   - Audit all terraform apply operations

## Maintenance

### Regular Tasks

- **Weekly**: Review firewall logs and alerts
- **Monthly**: Audit firewall rules and policies
- **Quarterly**: Update Terraform provider versions
- **Annually**: Security assessment and rule review

### Update Provider Version

```bash
# Update to latest compatible version
terraform init -upgrade
```

## Project Documentation

### Getting Started
- [README.md](README.md) - This file, project overview
- [SUMMARY.md](SUMMARY.md) - Project quick reference
- [DEPLOYMENT.md](DEPLOYMENT.md) - Step-by-step deployment guide

### Azure DevOps CI/CD
- [AZURE-DEVOPS-SETUP.md](docs/AZURE-DEVOPS-SETUP.md) - DevOps setup and configuration
- [DEVOPS-EXAMPLES.md](docs/DEVOPS-EXAMPLES.md) - Pipeline examples and patterns
- [VARIABLE-GROUPS.md](docs/VARIABLE-GROUPS.md) - Variable groups reference
- [DEVOPS-QUICK-REFERENCE.md](docs/DEVOPS-QUICK-REFERENCE.md) - Quick reference guide

### Configuration Examples
- [EXAMPLES.md](EXAMPLES.md) - Terraform configuration examples

## Support and Documentation

- [Azure Virtual WAN Documentation](https://learn.microsoft.com/azure/virtual-wan/)
- [Azure Firewall Documentation](https://learn.microsoft.com/azure/firewall/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Terraform State Management](https://www.terraform.io/language/state)
- [Azure DevOps Pipelines](https://learn.microsoft.com/azure/devops/pipelines/)

## License

This configuration is provided as-is for Azure Virtual WAN deployments.

## Contributors

Created: February 25, 2026
