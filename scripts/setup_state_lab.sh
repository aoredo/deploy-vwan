#!/bin/bash
set -e

echo "[INFO] Configuring Terraform backend for Pluralsight lab environment..."

# Use the existing sandbox RG and subscription
SUBSCRIPTION_ID="2213e8b1-dbc7-4d54-8aff-b5e315df5e5b"
RESOURCE_GROUP="1-1b120876-playground-sandbox"
STORAGE_ACCOUNT="stterraformstate${RANDOM:0:4}"  # Add random suffix
CONTAINER_NAME="tfstate"
LOCATION="eastus"

echo "[INFO] Using configuration:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER_NAME"

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

echo "[INFO] Creating storage account..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --allow-blob-public-access false || true

echo "[SUCCESS] Storage account created: $STORAGE_ACCOUNT"

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" -o tsv)

echo "[INFO] Creating container..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" || true

echo ""
echo "[SUCCESS] ✓ Backend ready!"
echo ""
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
