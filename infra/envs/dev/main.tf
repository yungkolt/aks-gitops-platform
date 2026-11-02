locals {
  name_suffix = "${var.project}-${var.environment}"

  tags = merge(
    {
      project     = "aks-gitops-platform"
      environment = var.environment
      managed-by  = "terraform"
    },
    var.tags,
  )
}

# Single resource group for the lab so a session can be torn down cleanly.
resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

# Modules are wired in here phase by phase:
#   Phase 1: module "network"
#   Phase 2: module "aks", module "acr", module "keyvault"
#   Phase 4: module "monitoring"
