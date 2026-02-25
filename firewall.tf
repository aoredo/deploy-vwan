resource "azurerm_public_ip" "afw_pip" {
  name                = "${var.firewall_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_firewall" "afw" {
  name                = var.firewall_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_Hub"
  sku_tier            = var.firewall_sku_tier
  
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.vhub.id
    public_ip_count = 1
  }

  firewall_policy_id = azurerm_firewall_policy.policy.id

  tags = var.tags

  depends_on = [
    azurerm_public_ip.afw_pip
  ]
}

# Firewall Policy
resource "azurerm_firewall_policy" "policy" {
  name                = "${var.firewall_name}-policy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  enabled                           = true
  threat_intelligence_mode          = "Alert"
  threat_intelligence_allowlist {
    ip_addresses = []
    fqdns        = []
  }

  tags = var.tags
}

# Network Rule Collection - Allow internal traffic
resource "azurerm_firewall_policy_rule_collection_group" "network_rules" {
  name               = "NetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 100

  network_rule_collection {
    name     = "AllowInternalTraffic"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "AllowVnetToVnet"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "AllowDNS"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }

  network_rule_collection {
    name     = "DenyInternetTraffic"
    priority = 200
    action   = "Deny"

    rule {
      name                  = "DenyAllInternet"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }

  depends_on = [
    azurerm_firewall_policy.policy
  ]
}

# Application Rule Collection - Allow specific traffic to internet
resource "azurerm_firewall_policy_rule_collection_group" "application_rules" {
  name               = "ApplicationRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 200

  application_rule_collection {
    name     = "AllowMicrosoftServices"
    priority = 100
    action   = "Allow"

    rule {
      name             = "AllowAzureServices"
      source_addresses = ["10.0.0.0/8"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.azure.com",
        "*.microsoft.com",
        "*.windows.net",
        "*.azureedge.net"
      ]
    }
  }
}

# Diagnostic Settings for Firewall - Optional, requires Log Analytics Workspace
resource "azurerm_monitor_diagnostic_setting" "firewall_diagnostics" {
  count                      = var.enable_logging && var.log_analytics_workspace_id != "" ? 1 : 0
  name                       = "${var.firewall_name}-diagnostics"
  target_resource_id         = azurerm_firewall.afw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Firewall Policy Rule Collection Group - NAT Rules (if needed)
resource "azurerm_firewall_policy_rule_collection_group" "nat_rules" {
  name               = "NATRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 300

  nat_rule_collection {
    name     = "TranslateRules"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "TranslateVnetTraffic"
      protocols           = ["TCP", "UDP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.afw_pip.ip_address
      destination_ports   = ["80", "443", "3389", "22"]
      translated_address  = "10.0.0.1"
      translated_port     = "80"
    }
  }
}
