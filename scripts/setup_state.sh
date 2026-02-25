#!/bin/bash

#######################################
# Azure Terraform State Setup Script
# Sets up Azure Storage Account for Terraform state
#######################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

print_success "Azure CLI found"

# Configuration variables
SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
RESOURCE_GROUP_NAME="${1:-rg-terraform-state}"
STORAGE_ACCOUNT_NAME="${2:-stterraformstate}"
CONTAINER_NAME="${3:-tfstate}"
LOCATION="${4:-eastus}"

print_info "Using configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Container Name: $CONTAINER_NAME"
echo "  Location: $LOCATION"

# Validate storage account name (3-24 chars, lowercase, alphanumeric only)
if ! [[ "$STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
    print_error "Invalid storage account name. Must be 3-24 chars, lowercase alphanumeric only."
    exit 1
fi

# Login to Azure
print_info "Logging in to Azure..."
az login

# Set subscription
if [ -n "$SUBSCRIPTION_ID" ]; then
    print_info "Setting subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
else
    print_warning "SUBSCRIPTION_ID not set. Using default subscription."
fi

# Get current subscription context
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
print_success "Using subscription: $SUBSCRIPTION_ID"

# Create resource group
print_info "Creating resource group '$RESOURCE_GROUP_NAME'..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags Environment=terraform ManagedBy=script CreatedDate=$(date +%Y-%m-%d)

print_success "Resource group created"

# Create storage account
print_info "Creating storage account '$STORAGE_ACCOUNT_NAME'..."
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --encryption-services blob \
    --access-tier Hot \
    --tags Environment=terraform ManagedBy=script

print_success "Storage account created"

# Enable versioning
print_info "Enabling versioning on storage account..."
az storage account blob-service-properties update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --enable-change-feed true \
    --enable-versioning true

print_success "Versioning enabled"

# Get storage account key
print_info "Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query '[0].value' \
    --output tsv)

# Create container
print_info "Creating container '$CONTAINER_NAME'..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --public-access off

print_success "Container created"

# Set container-level immutability (optional - uncomment to enable)
# print_info "Setting container-level immutability..."
# az storage container immutability-policy create \
#     --account-name "$STORAGE_ACCOUNT_NAME" \
#     --container-name "$CONTAINER_NAME" \
#     --period 7

# Display connection information
print_info "=========================================="
print_success "Terraform state backend setup complete!"
print_info "=========================================="

echo ""
echo "Use the following configuration in your backend.tf:"
echo ""
echo "terraform {"
echo "  backend \"azurerm\" {"
echo "    resource_group_name  = \"$RESOURCE_GROUP_NAME\""
echo "    storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "    container_name       = \"$CONTAINER_NAME\""
echo "    key                  = \"vwan/terraform.tfstate\""
echo "  }"
echo "}"
echo ""

echo "Environment variables to set:"
echo "export ARM_SUBSCRIPTION_ID=\"$SUBSCRIPTION_ID\""
echo "export ARM_STORAGE_ACCOUNT=$STORAGE_ACCOUNT_NAME"
echo "export ARM_STORAGE_KEY=\"$STORAGE_KEY\""
echo ""

print_warning "IMPORTANT: Store the storage account key securely!"
print_warning "Never commit credentials to version control."
print_warning ""
print_warning "To authenticate Terraform, use one of:"
print_warning "  1. Azure CLI: az login"
print_warning "  2. Service Principal: export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID"
print_warning "  3. Managed Identity (recommended for Azure resources)"
print_warning ""

print_info "Next steps:"
echo "  1. Update backend.tf with the configuration above"
echo "  2. Run: terraform init"
echo "  3. Run: terraform plan"
echo "  4. Run: terraform apply"
