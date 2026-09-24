resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = var.vnet_address_space

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app-${local.name_suffix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_app_prefix]

  delegation {
    name = "serverfarms"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres-${local.name_suffix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_postgres_prefix]

  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "flexibleservers"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "privatelink" {
  name                              = "snet-privatelink-${local.name_suffix}"
  resource_group_name               = data.azurerm_resource_group.main.name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.subnet_privatelink_prefix]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_network_security_group" "postgres" {
  name                = "nsg-postgres-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowPostgresFromApp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.subnet_app_prefix
    destination_address_prefix = var.subnet_postgres_prefix
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_network_security_group" "privatelink" {
  name                = "nsg-privatelink-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowBackendToPrivateEndpoints"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "10000"]
    source_address_prefix      = var.subnet_app_prefix
    destination_address_prefix = var.subnet_privatelink_prefix
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "postgres" {
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.postgres.id
}

resource "azurerm_subnet_network_security_group_association" "privatelink" {
  subnet_id                 = azurerm_subnet.privatelink.id
  network_security_group_id = azurerm_network_security_group.privatelink.id
}
