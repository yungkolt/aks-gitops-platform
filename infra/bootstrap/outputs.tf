output "state_storage_account" {
  description = "Storage account holding Terraform state."
  value       = azurerm_storage_account.state.name
}

output "state_resource_group" {
  description = "Resource group holding bootstrap resources."
  value       = azurerm_resource_group.bootstrap.name
}

output "plan_client_id" {
  description = "Client ID of the plan identity (AZURE_CLIENT_ID_PLAN)."
  value       = azuread_application.github["plan"].client_id
}

output "apply_client_id" {
  description = "Client ID of the apply identity (AZURE_CLIENT_ID_APPLY)."
  value       = azuread_application.github["apply"].client_id
}

output "github_variables_commands" {
  description = "Run these from the repo root to set the non-secret values the workflows read."

  value = <<-EOT
    gh variable set AZURE_TENANT_ID       --body "${data.azurerm_client_config.current.tenant_id}"
    gh variable set AZURE_SUBSCRIPTION_ID --body "${var.subscription_id}"
    gh variable set AZURE_CLIENT_ID_PLAN  --body "${azuread_application.github["plan"].client_id}"
    gh variable set AZURE_CLIENT_ID_APPLY --body "${azuread_application.github["apply"].client_id}"
  EOT
}
