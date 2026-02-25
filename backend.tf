terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "1-1b120876-playground-sandbox"
    storage_account_name = "stterraformstate1683"
    container_name       = "tfstate"
    key                  = "vwan/terraform.tfstate"
  }
}
