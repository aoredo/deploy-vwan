output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.rg.id
}

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "vwan_id" {
  description = "ID of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.id
}

output "vwan_name" {
  description = "Name of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.name
}

output "virtual_hub_id" {
  description = "ID of the Virtual Hub"
  value       = azurerm_virtual_hub.vhub.id
}

output "virtual_hub_name" {
  description = "Name of the Virtual Hub"
  value       = azurerm_virtual_hub.vhub.name
}

output "firewall_id" {
  description = "ID of the Azure Firewall"
  value       = azurerm_firewall.afw.id
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall"
  value       = azurerm_firewall.afw.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = azurerm_public_ip.afw_pip.ip_address
}

output "firewall_public_ip_id" {
  description = "ID of the Firewall Public IP"
  value       = azurerm_public_ip.afw_pip.id
}

output "firewall_policy_id" {
  description = "ID of the Firewall Policy"
  value       = azurerm_firewall_policy.policy.id
}

output "virtual_network_ids" {
  description = "IDs of created virtual networks"
  value       = { for k, v in azurerm_virtual_network.vnet : k => v.id }
}

output "hub_connections" {
  description = "Virtual Hub connections information"
  value = {
    for k, v in azurerm_virtual_hub_connection.hub_conn : k => {
      id                    = v.id
      remote_virtual_network_id = v.remote_virtual_network_id
    }
  }
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region          = azurerm_resource_group.rg.location
    vwan_name       = azurerm_virtual_wan.vwan.name
    hub_name        = azurerm_virtual_hub.vhub.name
    firewall_name   = azurerm_firewall.afw.name
    firewall_ip     = azurerm_firewall.afw.ip_configuration[0].private_ip_address
    vnet_count      = length(azurerm_virtual_network.vnet)
  }
}
