output "resource_group_name" {
  description = "Resource group holding the dev platform."
  value       = azurerm_resource_group.platform.name
}
