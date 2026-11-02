data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.project}-bootstrap"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Budget: created before anything that costs money, and kept outside the dev
# stack so a `terraform destroy` of the lab never removes it.
# ---------------------------------------------------------------------------
resource "azurerm_consumption_budget_subscription" "lab" {
  name            = "budget-${var.project}-monthly"
  subscription_id = data.azurerm_subscription.current.id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 50
    threshold_type = "Actual"
    operator       = "GreaterThanOrEqualTo"
    contact_emails = var.budget_contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Actual"
    operator       = "GreaterThanOrEqualTo"
    contact_emails = var.budget_contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Forecasted"
    operator       = "GreaterThanOrEqualTo"
    contact_emails = var.budget_contact_emails
  }

  lifecycle {
    # start_date is computed from the apply date; pin it after creation.
    ignore_changes = [time_period]
  }
}
