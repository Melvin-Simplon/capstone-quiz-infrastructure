variable "subscription_id" {
  description = "Target Azure subscription (shared Simplon subscription)"
  type        = string
  default     = "5e683e0f-b00c-48d6-9769-5aaf598de8f1"
}

variable "resource_group_name" {
  description = "Dedicated resource group provided by the trainer"
  type        = string
  default     = "mpetitRG"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "francecentral"
}

variable "owner" {
  description = "Owner identifier, set as the owner tag on every resource"
  type        = string
  default     = "mpetit"
}

variable "project" {
  description = "Project name, set as the project tag"
  type        = string
  default     = "simplon-quiz"
}

variable "environment" {
  description = "Target environment"
  type        = string
  default     = "nonprod"
}

variable "shared_resource_group_name" {
  description = "Shared resource group holding the App Service Plan"
  type        = string
  default     = "rg-shared-prf2026"
}

variable "shared_service_plan_name" {
  description = "Shared App Service Plan, referenced and not created"
  type        = string
  default     = "plan-npr-prf2026"
}
