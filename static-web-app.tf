resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.static_web_app_location

  sku_tier = "Free"
  sku_size = "Free"

  tags = merge(local.common_tags, { component = "frontend" })

  lifecycle {
    ignore_changes = [repository_url, repository_branch]
  }
}
