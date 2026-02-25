locals {
  # Naming conventions
  name_prefix = "${var.environment}-${data.azurerm_client_config.current.subscription_id}"
  common_name = "${var.environment}-${var.location}"

  # Common tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      Terraform   = "true"
      Environment = var.environment
      CreatedDate = timestamp()
    }
  )

  # Firewall configuration
  firewall_config = {
    sku_name = "AZFW_Hub"
    sku_tier = var.firewall_sku_tier
  }

  # Virtual Hub configuration
  vhub_config = {
    name           = var.vhub_name
    address_prefix = var.vhub_address_space
  }

  # IP ranges for common scenarios
  ip_ranges = {
    private_ipv4     = "10.0.0.0/8"
    azure_dns        = "168.63.129.16/32"
    all_ipv4         = "0.0.0.0/0"
    all_ipv6         = "::/0"
  }

  # Protocol definitions
  protocols = {
    all  = ["TCP", "UDP", "ICMP"]
    tcp  = ["TCP"]
    udp  = ["UDP"]
    icmp = ["ICMP"]
  }

  # Common ports
  ports = {
    dns     = "53"
    http    = "80"
    https   = "443"
    ssh     = "22"
    rdp     = "3389"
    winrm   = "5985"
    all     = "*"
  }

  # Firewall rules defaults
  fw_rule_defaults = {
    deny_action  = "Deny"
    allow_action = "Allow"
  }

  # Virtual network defaults
  vnet_defaults = {
    dns_servers             = []
    enable_vm_protection    = true
    enable_ddos_protection  = false
    address_space_increment = 2
  }

  # Routing configuration
  routing_config = {
    default_route_destination = "0.0.0.0/0"
    private_routes = {
      "10.0.0.0/8"    = "Private Address Space"
      "172.16.0.0/12" = "Private Address Space"
      "192.168.0.0/16" = "Private Address Space"
    }
  }

  # Environment-specific settings
  environment_config = {
    prod = {
      enforce_ssl           = true
      enable_logging        = true
      firewall_sku_tier     = "Premium"
      enable_threat_intel   = true
      threat_intel_mode     = "Alert"
    }
    staging = {
      enforce_ssl           = true
      enable_logging        = true
      firewall_sku_tier     = "Standard"
      enable_threat_intel   = true
      threat_intel_mode     = "Alert"
    }
    dev = {
      enforce_ssl           = false
      enable_logging        = true
      firewall_sku_tier     = "Standard"
      enable_threat_intel   = false
      threat_intel_mode     = "Off"
    }
  }
}

# Data source for current Azure context
data "azurerm_client_config" "current" {}

# Output local values for debugging
output "locals_summary" {
  description = "Summary of local values used in deployment"
  value = {
    name_prefix              = local.name_prefix
    common_tags              = local.common_tags
    firewall_config          = local.firewall_config
    ip_ranges                = local.ip_ranges
    environment_config       = local.environment_config[var.environment]
  }
  sensitive = false
}
