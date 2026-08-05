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
}
