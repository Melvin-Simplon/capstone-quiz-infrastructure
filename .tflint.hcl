plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# This rule asks for lifecycle { prevent_destroy = true } on every resource
# holding data, and it is the rule ADR 0008 was written from. ADR 0012 reverses
# that decision: this environment has to be destroyable for its rebuild to be
# provable, and a lint rule cannot be argued with in a plan review.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
