# Terraform Configuration Examples

This file contains examples of common scenarios and how to configure them.

## Example 1: Basic Production Deployment

### terraform.tfvars
```hcl
resource_group_name = "rg-vwan-prod"
location            = "eastus"
environment         = "prod"
vwan_name           = "vwan-prod"
vhub_name           = "vhub-prod"
firewall_name       = "afw-prod"
firewall_sku_tier   = "Standard"

virtual_networks = {
  "vnet-prod-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
  "vnet-prod-002" = {
    address_space   = ["10.2.0.0/16"]
    enable_firewall = true
  }
}

enable_logging = true
```

### Deployment
```bash
make init
make plan
make apply
```

---

## Example 2: High-Security Premium Deployment

### terraform.tfvars
```hcl
resource_group_name = "rg-vwan-secure"
location            = "eastus"
environment         = "prod"
firewall_sku_tier   = "Premium"  # Enhanced security features

virtual_networks = {
  "vnet-secure-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
  "vnet-secure-002" = {
    address_space   = ["10.2.0.0/16"]
    enable_firewall = true
  }
  "vnet-secure-dmz" = {
    address_space   = ["10.100.0.0/16"]
    enable_firewall = true
  }
}

enable_logging = true
log_analytics_workspace_id = "/subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.OperationalInsights/workspaces/security-logs"
```

### Custom Firewall Rules (firewall.tf)
```hcl
# Add restrictive rules for DMZ
resource "azurerm_firewall_policy_rule_collection_group" "dmz_rules" {
  name               = "DMZRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 150

  network_rule_collection {
    name     = "DenyDMZInternal"
    priority = 100
    action   = "Deny"

    rule {
      name                  = "BlockInternalAccess"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.100.0.0/16"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["443", "3306", "5432"]
    }
  }
}
```

---

## Example 3: Multi-Region with Failover

### terraform.tfvars (Primary Region)
```hcl
location = "eastus"
vwan_name = "vwan-primary"

virtual_networks = {
  "vnet-primary-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
}
```

### Deploy Secondary Region
```bash
# Create secondary workspace
terraform workspace new secondary

# Apply with different configuration
terraform apply -var-file=terraform-secondary.tfvars
```

---

## Example 4: Development Environment (Cost-Optimized)

### terraform.tfvars
```hcl
resource_group_name = "rg-vwan-dev"
location            = "eastus"
environment         = "dev"
firewall_sku_tier   = "Standard"

# Minimal vnet configuration for dev
virtual_networks = {
  "vnet-dev-001" = {
    address_space   = ["10.1.0.0/24"]  # Smaller /24 instead of /16
    enable_firewall = true
  }
}

enable_logging = false  # Reduce costs in dev
```

---

## Example 5: Custom Firewall Rules - Web Application

### firewall.tf Addition
```hcl
resource "azurerm_firewall_policy_rule_collection_group" "web_app_rules" {
  name               = "WebAppRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 150

  # NAT rules for web app
  nat_rule_collection {
    name     = "WebAppNAT"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "AllowHTTP"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = "PUBLIC_IP"
      destination_ports   = ["80"]
      translated_address  = "10.1.1.10"
      translated_port     = "80"
    }

    rule {
      name                = "AllowHTTPS"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = "PUBLIC_IP"
      destination_ports   = ["443"]
      translated_address  = "10.1.1.10"
      translated_port     = "443"
    }
  }

  # Application rules for web app traffic
  application_rule_collection {
    name     = "WebAppAppRules"
    priority = 100
    action   = "Allow"

    rule {
      name             = "AllowWebTraffic"
      source_addresses = ["10.100.0.0/16"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "api.example.com",
        "cdn.example.com",
        "*.azurecdn.net"
      ]
    }
  }
}
```

---

## Example 6: Adding Database Connectivity Rules

### firewall.tf Addition
```hcl
resource "azurerm_firewall_policy_rule_collection_group" "database_rules" {
  name               = "DatabaseRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 120

  network_rule_collection {
    name     = "AllowDatabaseTraffic"
    priority = 100
    action   = "Allow"

    # SQL Server connectivity
    rule {
      name                  = "AllowSQL"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.50.0.0/24"]
      destination_ports     = ["1433"]
    }

    # PostgreSQL connectivity
    rule {
      name                  = "AllowPostgreSQL"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.50.1.0/24"]
      destination_ports     = ["5432"]
    }

    # MySQL connectivity
    rule {
      name                  = "AllowMySQL"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.50.2.0/24"]
      destination_ports     = ["3306"]
    }
  }
}
```

---

## Example 7: On-Premises Connectivity (VPN)

### main.tf Addition
```hcl
# VPN Gateway connection
resource "azurerm_vpn_site" "on_prem" {
  name                = "on-prem-site"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id

  link {
    name       = "on-prem-link"
    ip_address = "203.0.113.0"  # On-premises public IP
  }

  address_space {
    address_prefix = "192.168.0.0/16"  # On-premises network
  }

  tags = var.tags
}

# VPN connection
resource "azurerm_vpn_gateway_connection" "on_prem_connection" {
  name                = "on-prem-connection"
  vpn_gateway_id      = azurerm_vpn_gateway.vwan_gateway.id
  remote_vpn_site_id  = azurerm_vpn_site.on_prem.id
  protocol            = "IKEv2"

  vpn_link_connection {
    name             = "on-prem-link-connection"
    vpn_site_link_id = azurerm_vpn_site.on_prem.link[0].id
    protocol         = "IKEv2"
    shared_key       = "YOUR_SHARED_KEY"
  }

  tags = var.tags
}

# Route on-premises traffic through firewall
resource "azurerm_virtual_hub_route_table_route" "on_prem_route" {
  route_table_id = azurerm_virtual_hub_route_table.default_route_table.id
  name           = "OnPremisesRoute"
  destinations   = ["192.168.0.0/16"]
  next_hop_type  = "ResourceId"
  next_hop_id    = azurerm_firewall.afw.id
}
```

---

## Example 8: Adding ExpressRoute Connectivity

### main.tf Addition
```hcl
# Express Route connection
resource "azurerm_express_route_circuit" "on_prem" {
  name                  = "on-prem-er"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  service_provider_name = "Equinix"
  peering_location      = "New York"
  bandwidth_in_mbps     = 100

  sku {
    tier   = "Standard"
    family = "MeteredData"
  }

  tags = var.tags
}

# Express Route connection to hub
resource "azurerm_virtual_hub_express_route_gateway" "er_gateway" {
  name                = "vhub-er-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_hub_id      = azurerm_virtual_hub.vhub.id

  tags = var.tags
}
```

---

## Example 9: Monitoring and Alerting Setup

### Additional Configuration
```bash
# Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group "rg-vwan-prod" \
  --workspace-name "vwan-analytics"

# Enable diagnostics
az monitor diagnostic-settings create \
  --name "firewall-diagnostics" \
  --resource "/subscriptions/.../firewall" \
  --logs '[{"category":"AzureFirewallApplicationRule","enabled":true}]' \
  --workspace "/subscriptions/.../workspaces/vwan-analytics"
```

### terraform.tfvars Addition
```hcl
enable_logging = true
log_analytics_workspace_id = "/subscriptions/xxx/resourceGroups/rg-vwan-prod/providers/Microsoft.OperationalInsights/workspaces/vwan-analytics"
```

---

## Example 10: Complete Enterprise Setup

### terraform.tfvars
```hcl
resource_group_name = "rg-vwan-enterprise"
location            = "eastus"
environment         = "prod"
firewall_sku_tier   = "Premium"

virtual_networks = {
  # Production workloads
  "vnet-prod-001" = {
    address_space   = ["10.1.0.0/16"]
    enable_firewall = true
  }
  "vnet-prod-002" = {
    address_space   = ["10.2.0.0/16"]
    enable_firewall = true
  }
  # DMZ network
  "vnet-dmz" = {
    address_space   = ["10.100.0.0/16"]
    enable_firewall = true
  }
  # Database tier
  "vnet-database" = {
    address_space   = ["10.50.0.0/16"]
    enable_firewall = true
  }
  # Backup and disaster recovery
  "vnet-backup" = {
    address_space   = ["10.200.0.0/16"]
    enable_firewall = true
  }
}

enable_logging = true
log_analytics_workspace_id = "YOUR_WORKSPACE_ID"

tags = {
  Environment = "prod"
  CostCenter  = "IT-Operations"
  Owner       = "Enterprise-Team"
  Project     = "WAN-Consolidation"
}
```

---

## Deployment Commands

### Basic Deployment
```bash
terraform init
terraform plan
terraform apply
```

### Modular Deployment (per component)
```bash
terraform apply -target=azurerm_resource_group.rg
terraform apply -target=azurerm_virtual_wan.vwan
terraform apply -target=azurerm_firewall.afw
terraform apply -target=azurerm_virtual_network.vnet
```

### Workspace-Based Deployments
```bash
# Dev environment
terraform workspace new dev
terraform apply -var-file=terraform-dev.tfvars

# Staging environment
terraform workspace new staging
terraform apply -var-file=terraform-staging.tfvars

# Production environment
terraform workspace select prod
terraform apply
```

---

## Cleanup Examples

```bash
# Remove specific vnet
terraform destroy -target='azurerm_virtual_network.vnet["vnet-prod-001"]'

# Remove entire resource group
terraform destroy

# Force destroy with approval
terraform destroy -auto-approve
```

---

## Useful Terraform Commands

```bash
# Show state
terraform show

# List resources
terraform state list

# Get specific resource details
terraform state show azurerm_firewall.afw

# Export data to query
terraform output -json > outputs.json

# Plan to file and review
terraform plan -out=tfplan
terraform show tfplan
```

---

## Cost Estimation

```bash
# Using Infracost (install: https://www.infracost.io)
infracost breakdown --path .

# Manual estimation:
# Firewall Standard: $0.995/hour = ~$730/month
# Firewall Premium: $4.75/hour = ~$3,480/month
# vWAN Hub: ~$100/month
# vNets: ~$0.08/hour each = ~$58/month each
# Total: $900-1200/month minimum
```
