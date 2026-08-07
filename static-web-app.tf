# Only component exposed on the internet, as required by section 6 of the brief.
# Static Web Apps are not offered in France Central, so this one resource sits in
# West Europe while everything else stays with the resource group.
resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.static_web_app_location

  sku_tier = "Free"
  sku_size = "Free"

  # The repository is not wired here: the deployment token is read by the frontend
  # pipeline, which builds and uploads. Terraform owns the resource, not the app.
  tags = merge(local.common_tags, { component = "frontend" })

  lifecycle {
    # Azure recorded the repository at creation and refuses to clear it: an apply
    # that unsets it reports success and changes nothing, so the same diff came
    # back on every plan. Declaring the values instead is not an option, the
    # provider then demands a repository_token, which is a secret this
    # configuration has no reason to hold.
    ignore_changes = [repository_url, repository_branch]
  }
}
