terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Bootstrap keeps local state on purpose: it creates the remote state backend
  # everything else uses. It is applied once, by a human, and rarely changes.
  # See docs/DECISIONS.md (ADR-002).
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Resource providers are registered by register-providers.sh before the
  # first apply, so the Reader-only plan identity never has to.
  resource_provider_registrations = "none"

  # State storage has shared keys disabled, so data-plane calls must use Entra ID.
  storage_use_azuread = true
}

provider "azuread" {}
