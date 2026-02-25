# Additional routing configurations for advanced scenarios

# Custom Route Table for Specific VNets
resource "azurerm_virtual_hub_route_table" "custom_route_table" {
  name          = "${var.vhub_name}-custom-route-table"
  virtual_hub_id = azurerm_virtual_hub.vhub.id
  labels        = ["custom", "prod"]
}

# Route for specific traffic patterns
resource "azurerm_virtual_hub_route_table_route" "custom_route" {
  route_table_id = azurerm_virtual_hub_route_table.custom_route_table.id
  name           = "CustomIntranetRoute"
  destinations   = ["172.16.0.0/12"]
  next_hop_type  = "ResourceId"
  next_hop_id    = azurerm_firewall.afw.id
}

# Static routes for DNS queries to Azure DNS
resource "azurerm_virtual_hub_route_table_route" "dns_route" {
  route_table_id = azurerm_virtual_hub_route_table.default_route_table.id
  name           = "AzureDnsRoute"
  destinations   = ["168.63.129.16/32"]
  next_hop_type  = "IPAddress"
  next_hop_id    = azurerm_virtual_hub.vhub.id
}

# BGP Connection for on-premises connectivity (optional)
# Uncomment and configure when adding ExpressRoute or VPN connections
#
# resource "azurerm_virtual_hub_bgp_connection" "example" {
#   name           = "${var.vhub_name}-bgp-connection"
#   virtual_hub_id = azurerm_virtual_hub.vhub.id
#   peer_asn       = 65001
#   peer_ip        = "192.168.0.1"
# 
#   depends_on = [
#     azurerm_virtual_hub.vhub
#   ]
# }

# Example: Route filters for internal traffic segmentation
# This demonstrates how to implement Zero Trust principles

locals {
  # Define traffic policies for different environments
  traffic_policies = {
    production = {
      allowed_protocols = ["TCP", "UDP", "ICMP"]
      denied_ports      = ["23", "135", "139", "445"]  # Telnet, RPC, NetBIOS
    }
    development = {
      allowed_protocols = ["TCP", "UDP", "ICMP"]
      denied_ports      = ["135", "139", "445"]
    }
  }

  # Source IP ranges by environment
  source_ranges = {
    trusted_internal = ["10.0.0.0/8"]
    guest_network    = ["192.168.0.0/16"]
  }
}

# Example output for routing configuration
output "routing_configuration" {
  description = "Summary of routing configuration"
  value = {
    default_route_table_id = azurerm_virtual_hub_route_table.default_route_table.id
    custom_route_table_id  = azurerm_virtual_hub_route_table.custom_route_table.id
    firewall_next_hop      = azurerm_firewall.afw.ip_configuration[0].private_ip_address
  }
  sensitive = false
}
