# ---------------------------------------------------------------------------
# GitHub Actions identities, federated with OIDC. Two app registrations so a
# pull request can never act with apply rights:
#
#   plan  - trusted only for pull_request events. Reader on the subscription,
#           read-only on state. Runs `terraform plan -lock=false`.
#   apply - trusted only for jobs that run in the GitHub environment "dev",
#           which only the main branch can use. Contributor plus a role-
#           assignment admin grant constrained to a fixed list of roles.
# ---------------------------------------------------------------------------
locals {
  github_repo_path = "${var.github_owner}/${var.github_repo}"

  github_identities = {
    plan = {
      description = "Terraform plan on pull requests (read-only)"
      subject     = "repo:${local.github_repo_path}:pull_request"
    }
    apply = {
      description = "Terraform apply from the ${var.github_environment} environment"
      subject     = "repo:${local.github_repo_path}:environment:${var.github_environment}"
    }
  }
}

resource "azuread_application" "github" {
  for_each = local.github_identities

  display_name = "gh-${var.github_repo}-${each.key}"
  description  = each.value.description
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github" {
  for_each = local.github_identities

  client_id = azuread_application.github[each.key].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = local.github_identities

  application_id = azuread_application.github[each.key].id
  display_name   = "github-${var.github_repo}-${each.key}"
  description    = each.value.description
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value.subject
}

# --- plan identity ---------------------------------------------------------

resource "azurerm_role_assignment" "plan_reader" {
  scope                            = data.azurerm_subscription.current.id
  role_definition_name             = "Reader"
  principal_id                     = azuread_service_principal.github["plan"].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "plan_state_reader" {
  scope                            = azurerm_storage_account.state.id
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azuread_service_principal.github["plan"].object_id
  skip_service_principal_aad_check = true
}

# --- apply identity --------------------------------------------------------

resource "azurerm_role_assignment" "apply_contributor" {
  scope                            = data.azurerm_subscription.current.id
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.github["apply"].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "apply_state_writer" {
  scope                            = azurerm_storage_account.state.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.github["apply"].object_id
  skip_service_principal_aad_check = true
}

data "azurerm_role_definition" "assignable" {
  for_each = toset(var.assignable_roles)

  name  = each.value
  scope = data.azurerm_subscription.current.id
}

locals {
  assignable_role_guids = join(", ", [for r in data.azurerm_role_definition.assignable : r.role_definition_id])

  # ABAC condition: the apply identity may create or delete role assignments
  # only when the role is one of var.assignable_roles.
  rbac_admin_condition = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_guids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_guids}}
     )
    )
  EOT
}

resource "azurerm_role_assignment" "apply_rbac_admin" {
  scope                            = data.azurerm_subscription.current.id
  role_definition_name             = "Role Based Access Control Administrator"
  principal_id                     = azuread_service_principal.github["apply"].object_id
  skip_service_principal_aad_check = true

  condition_version = "2.0"
  condition         = local.rbac_admin_condition
  description       = "Constrained to: ${join(", ", var.assignable_roles)}"
}
