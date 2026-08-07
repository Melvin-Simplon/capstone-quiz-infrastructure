resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = var.vnet_address_space

  tags = merge(local.common_tags, { component = "network" })
}

# Outbound path of the backend. The App Service Plan is shared with the whole
# promotion, so this subnet carries integration traffic only and never hosts a
# resource of its own.
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

# PostgreSQL Flexible Server is injected into its own subnet rather than reached
# through a private endpoint. Private access is the mode the server supports
# natively, it removes the public endpoint entirely instead of leaving it up and
# filtered, and a delegated subnet accepts exactly one delegation, hence a
# dedicated one here.
resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres-${local.name_suffix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_postgres_prefix]

  # Added by Azure itself when the server is injected here, so declaring it is
  # what stops Terraform from trying to take it away on every run.
  service_endpoint {
    service = "Microsoft.Storage"
  }

  delegation {
    name = "flexibleservers"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Redis, Storage and Key Vault are reached through private endpoints landing here.
# Network policies stay enabled on purpose: when they are disabled, the NSG below
# is simply not evaluated for private endpoint traffic and the segmentation would
# only look enforced.
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

  # Integration traffic is outbound only, so nothing inside the network has a
  # reason to reach this subnet.
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

  # 443 for Storage and Key Vault, 10000 for Managed Redis. The frontend is a
  # Static Web App outside the network and must never appear as a source here.
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
