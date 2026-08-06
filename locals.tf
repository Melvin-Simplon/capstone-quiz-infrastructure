locals {
  # The "component" tag is added per resource, not here: it is what the CI queries
  # to locate its deployment target instead of relying on hardcoded resource names.
  common_tags = {
    owner       = var.owner
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }

  name_suffix = "${var.project}-${var.owner}"

  # Storage account names are globally unique, lowercase alphanumeric only and
  # capped at 24 characters, so the dashed suffix cannot be reused as is.
  storage_account_name = replace("st${local.name_suffix}", "-", "")

  storage_container_name = "java-uploads-${var.owner}"

  frontend_origin = "https://${azurerm_static_web_app.frontend.default_host_name}"
}
