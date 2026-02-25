#!/bin/bash

##########################################################
# Azure DevOps Setup for Personal Account
# Creates variable groups for hybrid Pluralsight + Personal ADO setup
##########################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Configuration from user input or defaults
ADO_ORG="${1:-https://dev.azure.com/darockProjects}"
ADO_PROJECT="${2:-vwan-deploy}"
GITHUB_REPO="${3:-https://github.com/aoredo/deploy-vwan}"

# Pluralsight lab credentials
SUBSCRIPTION_ID="2213e8b1-dbc7-4d54-8aff-b5e315df5e5b"
STORAGE_ACCOUNT="stterraformstate1683"
STORAGE_RG="1-1b120876-playground-sandbox"

print_info "Personal Azure DevOps Setup"
print_info "Organization: $ADO_ORG"
print_info "Project: $ADO_PROJECT"
print_info "GitHub Repo: $GITHUB_REPO"
echo ""

# Get storage key
print_info "Retrieving Pluralsight storage account key..."
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$STORAGE_RG" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" -o tsv 2>/dev/null)

if [ -z "$STORAGE_KEY" ]; then
    print_error "Could not retrieve storage key"
    print_info "Make sure you're logged into the Pluralsight account:"
    print_info "  az login"
    print_info "  az account set --subscription $SUBSCRIPTION_ID"
    exit 1
fi

print_success "Storage key retrieved"
echo ""

# Configure Azure DevOps CLI
print_info "Configuring Azure DevOps CLI..."
az devops configure --defaults organization="$ADO_ORG" project="$ADO_PROJECT" 2>/dev/null || true

# Create Non-Prod Variable Group
print_info "Creating non-production variable group (vwan-nonprod-vars)..."
az pipelines variable-group create \
  --name "vwan-nonprod-vars" \
  --variables \
    AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT" \
    RESOURCE_GROUP="$STORAGE_RG" \
    STATE_RG="$STORAGE_RG" \
    STATE_KEY="vwan-nonprod/terraform.tfstate" \
    ENVIRONMENT="nonprod" \
    TERRAFORM_VERSION="1.14.5" \
  --organization "$ADO_ORG" \
  --project "$ADO_PROJECT" \
  2>/dev/null && print_success "Created vwan-nonprod-vars" || print_warning "Variable group may already exist"

# Add secret variable to Non-Prod group
print_info "Adding storage key secret to non-prod group..."
az pipelines variable-group variable create \
  --group-id $(az pipelines variable-group list --organization "$ADO_ORG" --project "$ADO_PROJECT" --query "[?name=='vwan-nonprod-vars'].id" -o tsv) \
  --name "AZURE_STORAGE_KEY" \
  --value "$STORAGE_KEY" \
  --secret true \
  --organization "$ADO_ORG" \
  --project "$ADO_PROJECT" \
  2>/dev/null && print_success "Added storage key" || print_warning "Storage key may already exist"

echo ""

# Create Prod Variable Group
print_info "Creating production variable group (vwan-prod-vars)..."
az pipelines variable-group create \
  --name "vwan-prod-vars" \
  --variables \
    AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT" \
    RESOURCE_GROUP="$STORAGE_RG" \
    STATE_RG="$STORAGE_RG" \
    STATE_KEY="vwan/terraform.tfstate" \
    ENVIRONMENT="prod" \
    TERRAFORM_VERSION="1.14.5" \
  --organization "$ADO_ORG" \
  --project "$ADO_PROJECT" \
  2>/dev/null && print_success "Created vwan-prod-vars" || print_warning "Variable group may already exist"

# Add secret variable to Prod group
print_info "Adding storage key secret to prod group..."
az pipelines variable-group variable create \
  --group-id $(az pipelines variable-group list --organization "$ADO_ORG" --project "$ADO_PROJECT" --query "[?name=='vwan-prod-vars'].id" -o tsv) \
  --name "AZURE_STORAGE_KEY" \
  --value "$STORAGE_KEY" \
  --secret true \
  --organization "$ADO_ORG" \
  --project "$ADO_PROJECT" \
  2>/dev/null && print_success "Added storage key" || print_warning "Storage key may already exist"

echo ""
echo "════════════════════════════════════════════════════"
print_success "Variable Groups Ready!"
echo "════════════════════════════════════════════════════"
echo ""
print_info "Next Steps:"
echo ""
echo "1. Push code to GitHub:"
echo "   cd /Users/aoredope/deploy-vwan"
echo "   git remote add github $GITHUB_REPO"
echo "   git push -u github main ea-np ea-prd"
echo ""
echo "2. Connect GitHub to Azure DevOps:"
echo "   $ADO_ORG/$ADO_PROJECT/_build"
echo "   → Click 'Create Pipeline'"
echo "   → Select 'GitHub'"
echo "   → Authorize and select aoredo/deploy-vwan"
echo ""
echo "3. Create Pipeline:"
echo "   → Select 'Existing Azure Pipelines YAML file'"
echo "   → Path: azure-pipelines.yml"
echo "   → Click 'Save and run'"
echo ""
echo "4. Link Variable Groups to Pipeline:"
echo "   → Pipeline Settings → Variable groups"
echo "   → Add vwan-nonprod-vars and vwan-prod-vars"
echo ""
echo "Done! Your hybrid setup is ready."
echo "════════════════════════════════════════════════════"
