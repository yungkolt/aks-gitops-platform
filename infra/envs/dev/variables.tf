variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
}

variable "location" {
  description = "Azure region for the environment."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names."
  type        = string
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
