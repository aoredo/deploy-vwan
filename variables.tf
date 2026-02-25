variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Service Principal client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Service Principal client secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-vwan-prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vwan_name" {
  description = "Name of the Virtual WAN"
  type        = string
  default     = "vwan-prod"
}

variable "vhub_name" {
  description = "Name of the Virtual Hub"
  type        = string
  default     = "vhub-prod"
}

variable "vhub_address_space" {
  description = "Address space for Virtual Hub (in CIDR notation)"
  type        = string
  default     = "10.0.0.0/23"
}

variable "firewall_name" {
  description = "Name of the Azure Firewall"
  type        = string
  default     = "afw-prod"
}

variable "firewall_sku_tier" {
  description = "Firewall SKU tier (Standard or Premium)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be either Standard or Premium."
  }
}

variable "virtual_networks" {
  description = "Map of virtual networks to create and connect to vWAN hub"
  type = map(object({
    address_space       = list(string)
    enable_firewall     = bool
  }))
  default = {
    "vnet-prod-001" = {
      address_space   = ["10.1.0.0/16"]
      enable_firewall = true
    }
    "vnet-prod-002" = {
      address_space   = ["10.2.0.0/16"]
      enable_firewall = true
    }
  }
}

variable "firewall_rules_enabled" {
  description = "Enable firewall policy rules"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable diagnostic logging for firewall"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    CreatedDate = "2026-02-25"
  }
}
