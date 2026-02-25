resource "azurerm_virtual_network" "vnet" {
  for_each = var.virtual_networks

  name                = each.key
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = each.value.address_space

  tags = var.tags
}

resource "azurerm_subnet" "default_subnet" {
  for_each = var.virtual_networks

  name                 = "${each.key}-default-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [cidrsubnet(each.value.address_space[0], 2, 0)]
}

resource "azurerm_subnet" "firewall_subnet" {
  for_each = var.virtual_networks

  name                 = "${each.key}-firewall-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [cidrsubnet(each.value.address_space[0], 2, 1)]
}

# Hub Connection - Connect VNets to Virtual Hub
resource "azurerm_virtual_hub_connection" "hub_conn" {
  for_each = var.virtual_networks

  name                    = "${azurerm_virtual_network.vnet[each.key].name}-to-hub"
  virtual_hub_id          = azurerm_virtual_hub.vhub.id
  remote_virtual_network_id = azurerm_virtual_network.vnet[each.key].id

  internet_security_enabled = each.value.enable_firewall

  routing {
    associated_route_table_id = azurerm_virtual_hub_route_table.default_route_table.id
    
    propagated_route_table {
      labels          = ["default"]
      route_table_ids = [azurerm_virtual_hub_route_table.default_route_table.id]
    }

    inbound_route_map_id  = null
    outbound_route_map_id = null
  }

  depends_on = [
    azurerm_virtual_hub.vhub,
    azurerm_virtual_network.vnet,
    azurerm_firewall.afw
  ]
}

# Route Table for Subnets - Direct traffic to firewall
resource "azurerm_route_table" "subnet_rt" {
  for_each = var.virtual_networks

  name                = "${each.key}-route-table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  disable_bgp_route_propagation = false

  route {
    name                   = "ToFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.afw.ip_configuration[0].private_ip_address
  }

  tags = var.tags

  depends_on = [
    azurerm_firewall.afw
  ]
}

# Associate Route Table with Subnets
resource "azurerm_subnet_route_table_association" "default_subnet_rt" {
  for_each = var.virtual_networks

  subnet_id      = azurerm_subnet.default_subnet[each.key].id
  route_table_id = azurerm_route_table.subnet_rt[each.key].id
}

# Network Security Group - Default allowing lab traffic
resource "azurerm_network_security_group" "nsg" {
  for_each = var.virtual_networks

  name                = "${each.key}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowVnetTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowRdp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSsh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with Subnets
resource "azurerm_subnet_network_security_group_association" "default_subnet_nsg" {
  for_each = var.virtual_networks

  subnet_id                 = azurerm_subnet.default_subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}
