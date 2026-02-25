#!/bin/bash

#######################################
# Azure DevOps Setup - Lab Variant
# Works with restricted lab accounts
#######################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Configuration
ORG_URL="${1:-https://dev.azure.com/CiscoIaac}"
PROJECT="${2:-vwan-infrastructure}"
STORAGE_ACCOUNT="stterraformstate1683"
STORAGE_RG="1-1b120876-playground-sandbox"

print_info "Azure DevOps Pipeline Setup (Lab Edition)"
print_info "Organization: $ORG_URL"
print_info "Project: $PROJECT"
print_info ""

# Get storage key
print_info "Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$STORAGE_RG" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" -o tsv)

if [ -z "$STORAGE_KEY" ]; then
    print_warning "Could not retrieve storage key. Set it manually in Azure DevOps."
    STORAGE_KEY="<paste-your-storage-key-here>"
else
    print_success "Storage key retrieved"
fi

# Enable DevOps CLI
print_info "Ensuring Azure DevOps CLI is installed..."
az extension add --name azure-devops --upgrade 2>/dev/null || true

# Set DevOps defaults
az devops configure --defaults organization=$ORG_URL project="$PROJECT"

print_info ""
print_info "Creating Variable Groups..."
print_info ""

# Create Non-Prod Variable Group
print_info "Creating vwan-nonprod-secrets variable group..."
cat > /tmp/nonprod_vars.json << 'EOF'
{
  "name": "vwan-nonprod-secrets",
  "description": "Non-Production environment variables",
  "variables": {
    "TERRAFORM_VERSION": { "value": "1.14.5", "isSecret": false },
    "AZURE_STORAGE_ACCOUNT": { "value": "stterraformstate1683", "isSecret": false },
    "STATE_RG": { "value": "1-1b120876-playground-sandbox", "isSecret": false },
    "RESOURCE_GROUP": { "value": "1-1b120876-playground-sandbox", "isSecret": false },
    "ENVIRONMENT": { "value": "nonprod", "isSecret": false },
    "AZURE_STORAGE_KEY": { "value": "PLACEHOLDER", "isSecret": true }
  }
}
EOF

# Try to create via az cli (may fail in lab, but attempt anyway)
az pipelines variable-group create --name vwan-nonprod-secrets \
  --variables TERRAFORM_VERSION=1.14.5 \
  AZURE_STORAGE_ACCOUNT=stterraformstate1683 \
  STATE_RG=1-1b120876-playground-sandbox \
  RESOURCE_GROUP=1-1b120876-playground-sandbox \
  ENVIRONMENT=nonprod 2>/dev/null || print_warning "Could not create via CLI (expected in lab)"

# Create Prod Variable Group
print_info "Creating vwan-prod-secrets variable group..."
az pipelines variable-group create --name vwan-prod-secrets \
  --variables TERRAFORM_VERSION=1.14.5 \
  AZURE_STORAGE_ACCOUNT=stterraformstate1683 \
  STATE_RG=1-1b120876-playground-sandbox \
  RESOURCE_GROUP=1-1b120876-playground-sandbox \
  ENVIRONMENT=prod 2>/dev/null || print_warning "Could not create via CLI (expected in lab)"

print_success "Setup attempted. Follow these manual steps:"
print_info ""
echo "1. Go to: $ORG_URL/$PROJECT/_build"
echo "2. Click 'New pipeline'"
echo "3. Select 'Azure Repos Git' → 'deploy-vwan'"
echo "4. Select 'Existing Azure Pipelines YAML file'"
echo "5. Choose 'azure-pipelines.yml' → Save and run"
echo ""
echo "6. Create Variable Groups Manually:"
echo "   - Go to: $ORG_URL/$PROJECT/_library"
echo "   - Name: vwan-nonprod-secrets"
echo "   - Variables:"
echo "     * TERRAFORM_VERSION = 1.14.5"
echo "     * AZURE_STORAGE_ACCOUNT = stterraformstate1683"
echo "     * STATE_RG = 1-1b120876-playground-sandbox"
echo "     * RESOURCE_GROUP = 1-1b120876-playground-sandbox"
echo "     * ENVIRONMENT = nonprod"
echo "     * AZURE_STORAGE_KEY = $STORAGE_KEY (Mark as Secret)"
echo ""
echo "7. Link variable groups to your pipeline"
echo ""
print_success "✓ Setup complete! See DEVOPS-MANUAL-SETUP.md for detailed instructions"
