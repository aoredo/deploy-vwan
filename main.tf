resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_virtual_wan" "vwan" {
  name                = var.vwan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Specification
  allow_branch_to_branch_traffic = true
  office365_local_breakout_category = "All"
  type                           = "Standard"

  tags = var.tags
}

resource "azurerm_virtual_hub" "vhub" {
  name                = var.vhub_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = var.vhub_address_space

  tags = var.tags
}

# Hub Route Table - Default route table for the hub
resource "azurerm_virtual_hub_route_table" "default_route_table" {
  name                = "${var.vhub_name}-default-route-table"
  virtual_hub_id      = azurerm_virtual_hub.vhub.id
  labels              = ["default"]
}

# Hub Route - Route traffic through firewall
resource "azurerm_virtual_hub_route_table_route" "firewall_route" {
  route_table_id       = azurerm_virtual_hub_route_table.default_route_table.id
  name                 = "InternetRoute"
  destinations         = ["0.0.0.0/0"]
  destinations_type    = "CIDR"
  next_hop_type        = "ResourceId"
  next_hop             = azurerm_firewall.afw.id
}

# Hub Default Route Table Association
resource "azurerm_virtual_hub_route_table_route" "default_route" {
  count                = var.firewall_rules_enabled ? 1 : 0
  route_table_id       = azurerm_virtual_hub_route_table.default_route_table.id
  name                 = "DefaultToFirewall"
  destinations         = ["10.0.0.0/8"]
  destinations_type    = "CIDR"
  next_hop_type        = "ResourceId"
  next_hop             = azurerm_firewall.afw.id
}
