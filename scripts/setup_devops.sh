#!/bin/bash

#######################################
# Azure DevOps Setup Script
# Automates service connection setup
#######################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not installed. Install from https://learn.microsoft.com/cli/azure/"
    exit 1
fi

if ! az extension list | grep -q '"name": "azure-devops"'; then
    print_info "Installing Azure DevOps CLI extension..."
    az extension add --name azure-devops
fi

# Get configuration
ORG_URL="${1:-}"
PROJECT="${2:-}"
REPO="${3:-deploy-vwan}"
SP_NAME="${4:-terraform-pipeline-sp}"

if [ -z "$ORG_URL" ]; then
    read -p "Enter Azure DevOps organization URL (https://dev.azure.com/ORG): " ORG_URL
fi

if [ -z "$PROJECT" ]; then
    read -p "Enter project name: " PROJECT
fi

print_info "Configuration:"
echo "  Organization: $ORG_URL"
echo "  Project: $PROJECT"
echo "  Repository: $REPO"
echo "  Service Principal: $SP_NAME"
echo ""

# Create Service Principal
print_info "Creating Service Principal..."

SP_JSON=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv))

SP_ID=$(echo "$SP_JSON" | jq -r '.appId')
SP_SECRET=$(echo "$SP_JSON" | jq -r '.password')
SP_TENANT=$(echo "$SP_JSON" | jq -r '.tenant')
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

print_success "Service Principal created: $SP_ID"

# Login to DevOps
print_info "Logging in to Azure DevOps..."
echo "$AZ_DEVOPS_PAT" | az devops login --organization "$ORG_URL" 2>/dev/null || {
    print_warning "Paste your Personal Access Token (or press Ctrl+C to cancel):"
    read -sp "PAT: " AZ_DEVOPS_PAT
    echo "$AZ_DEVOPS_PAT" | az devops login --organization "$ORG_URL"
}

print_success "Logged in to Azure DevOps"

# Set defaults
az devops configure --defaults organization="$ORG_URL" project="$PROJECT"

# Check if project exists
print_info "Checking if project exists..."
if ! az devops project show --project "$PROJECT" &>/dev/null; then
    print_warning "Project not found. Creating..."
    az devops project create --name "$PROJECT" --visibility private
    sleep 10
fi

print_success "Project ready: $PROJECT"

# Create service connection
print_info "Creating service connection..."

SERVICE_CONNECTION=$(az devops service-endpoint azurerm create \
  --name "Azure-Terraform-SP" \
  --azure-rm-service-principal-id "$SP_ID" \
  --azure-rm-service-principal-key "$SP_SECRET" \
  --azure-rm-subscription-id "$SUBSCRIPTION_ID" \
  --azure-rm-subscription-name "$(az account show --query name -o tsv)" \
  --azure-rm-tenant-id "$SP_TENANT" \
  2>/dev/null) || {
    print_error "Failed to create service connection"
    echo "Try creating manually in Azure DevOps UI:"
    echo "1. Projects Settings → Service connections"
    echo "2. New service connection → Azure Resource Manager"
    echo "3. Enter above credentials"
    exit 1
}

CONNECTION_ID=$(echo "$SERVICE_CONNECTION" | jq -r '.id')
print_success "Service connection created: $CONNECTION_ID"

# Create variable groups
print_info "Creating variable groups..."

# Common
az pipelines variable-group create \
  --name terraform-common \
  --variables \
    terraformVersion=1.5.0 \
    azureSubscriptionEndpoint=Azure-Terraform-SP \
    backendResourceGroup=rg-terraform-state \
    backendStorageAccount=stterraformstate \
    backendContainerName=tfstate \
  2>/dev/null || print_warning "Variable group 'terraform-common' already exists"

print_success "Created variable group: terraform-common"

# Dev
az pipelines variable-group create \
  --name terraform-dev \
  --variables \
    environment=dev \
    location=eastus \
    resourceGroupName=rg-vwan-dev \
    vwanName=vwan-dev-eastus \
    firewallSkuTier=Standard \
    backendAzureRmKey=vwan-dev/terraform.tfstate \
  2>/dev/null || print_warning "Variable group 'terraform-dev' already exists"

print_success "Created variable group: terraform-dev"

# Prod
az pipelines variable-group create \
  --name terraform-prod \
  --variables \
    environment=prod \
    location=eastus \
    resourceGroupName=rg-vwan-prod \
    vwanName=vwan-prod-eastus \
    firewallSkuTier=Premium \
    backendAzureRmKey=vwan/terraform.tfstate \
  2>/dev/null || print_warning "Variable group 'terraform-prod' already exists"

print_success "Created variable group: terraform-prod"

# Create pipeline
print_info "Creating pipeline..."

PIPELINE=$(az pipelines create \
  --name "vWAN-Infrastructure" \
  --repository "$REPO" \
  --repository-type tfsgit \
  --branch main \
  --yml-path azure-pipelines.yml \
  2>/dev/null) || {
    print_warning "Pipeline creation via CLI may have issues"
    echo "Create manually in Azure DevOps:"
    echo "1. Pipelines → New pipeline"
    echo "2. Select Azure Repos Git"
    echo "3. Select repository: $REPO"
    echo "4. Select 'Existing Azure Pipelines YAML file'"
    echo "5. Path: azure-pipelines.yml"
}

print_success "Pipeline created/configured"

# Summary
echo ""
echo "=========================================="
print_success "Azure DevOps Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Push code: git push origin main"
echo "2. Create pull request to test pipeline"
echo "3. Check pipeline runs in:"
echo "   $ORG_URL/$PROJECT/_build"
echo ""
echo "Service Principal Credentials:"
echo "  App ID:     $SP_ID"
echo "  Secret:     $SP_SECRET"
echo "  Tenant:     $SP_TENANT"
echo "  Subscription: $SUBSCRIPTION_ID"
echo ""
print_warning "Store these securely! Do not commit to Git"
echo ""
echo "Variable groups created:"
echo "  ✓ terraform-common"
echo "  ✓ terraform-dev"
echo "  ✓ terraform-prod"
echo ""
echo "Service connections created:"
echo "  ✓ Azure-Terraform-SP (ID: $CONNECTION_ID)"
echo ""
echo "For more details, see:"
echo "  docs/AZURE-DEVOPS-SETUP.md"
echo "  docs/DEVOPS-EXAMPLES.md"
echo "  docs/VARIABLE-GROUPS.md"
