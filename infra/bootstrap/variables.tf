variable "subscription_id" {
  description = "Azure subscription the platform is deployed into."
  type        = string
}

variable "location" {
  description = "Azure region for bootstrap resources."
  type        = string
  default     = "westus3"
}

variable "project" {
  description = "Short project name used in resource names."
  type        = string
  default     = "aksplat"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.project))
    error_message = "project must be 3-10 lowercase letters or digits (it is used in a storage account name)."
  }
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
  default     = "yungkolt"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "aks-gitops-platform"
}

variable "github_environment" {
  description = "GitHub environment that gates applies. Must match the environment used in terraform.yml."
  type        = string
  default     = "dev"
}

variable "budget_amount" {
  description = "Monthly subscription budget in USD."
  type        = number
  default     = 25
}

variable "budget_contact_emails" {
  description = "Addresses that receive budget alerts."
  type        = list(string)

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "Provide at least one email address for budget alerts."
  }
}

variable "assignable_roles" {
  # The role-assignment admin grant is constrained to exactly these, so a
  # compromised pipeline cannot hand out Owner or User Access Administrator.
  description = "Built-in roles the apply identity is allowed to assign."
  type        = list(string)

  default = [
    "AcrPull",
    "Key Vault Secrets User",
    "Key Vault Secrets Officer",
    "Azure Kubernetes Service RBAC Cluster Admin",
    "Azure Kubernetes Service RBAC Reader",
    "Network Contributor",
    "Private DNS Zone Contributor",
    "Monitoring Metrics Publisher",
  ]
}

variable "tags" {
  description = "Tags applied to every bootstrap resource."
  type        = map(string)

  default = {
    project    = "aks-gitops-platform"
    managed-by = "terraform"
    stack      = "bootstrap"
  }
}
