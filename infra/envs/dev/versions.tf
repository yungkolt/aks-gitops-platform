terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }

  # Partial configuration; values come from backend.hcl, which the bootstrap
  # stack generates:  terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # subscription_id is read from ARM_SUBSCRIPTION_ID so the same code runs
  # locally and in CI without editing.

  # The plan identity is Reader only and cannot register resource providers.
  # Required providers are registered once during bootstrap (see RUNBOOK).
  resource_provider_registrations = "none"

  storage_use_azuread = true
}
