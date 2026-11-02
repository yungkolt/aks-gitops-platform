# ---------------------------------------------------------------------------
# Remote state for every other stack. Entra ID auth only: shared keys and SAS
# are disabled, so access is governed entirely by RBAC and shows up in the
# activity log under a real identity.
# ---------------------------------------------------------------------------
resource "random_string" "state_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "state" {
  name                = "st${var.project}tf${random_string.state_suffix.result}"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# The person running bootstrap needs data-plane access to run terraform
# locally against the dev stack (for example, the end-of-session destroy).
resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Backend settings for the dev stack, written next to it so the pipeline and a
# local `terraform init` read the same values. None of these are secrets.
resource "local_file" "dev_backend" {
  filename        = "${path.module}/../envs/dev/backend.hcl"
  file_permission = "0644"

  content = <<-EOT
    resource_group_name  = "${azurerm_resource_group.bootstrap.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "dev.terraform.tfstate"
    use_azuread_auth     = true
  EOT
}
