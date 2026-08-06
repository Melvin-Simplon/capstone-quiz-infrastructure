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


variable "vnet_address_space" {
  description = "Address space of the project virtual network"
  type        = list(string)
  default     = ["10.60.0.0/16"]
}

variable "subnet_app_prefix" {
  description = "Subnet delegated to the App Service Plan for outbound VNet integration"
  type        = string
  default     = "10.60.1.0/24"
}

variable "subnet_postgres_prefix" {
  description = "Subnet delegated to PostgreSQL Flexible Server private access"
  type        = string
  default     = "10.60.2.0/24"
}

variable "subnet_privatelink_prefix" {
  description = "Subnet hosting the private endpoints of Redis, Storage and Key Vault"
  type        = string
  default     = "10.60.3.0/24"
}

variable "shared_resource_group_name" {
  description = "Resource group holding the resources shared with the promotion"
  type        = string
  default     = "rg-shared-prf2026"
}

variable "app_service_plan_name" {
  description = "Shared App Service Plan hosting the backend, referenced as a data source"
  type        = string
  default     = "plan-npr-prf2026"
}

variable "static_web_app_location" {
  description = "Static Web Apps are not offered in France Central, hence a separate location"
  type        = string
  default     = "westeurope"
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "Burstable tier, the only one within this subscription's quota"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage allocated to the database server"
  type        = number
  default     = 32768
}

variable "postgres_admin_username" {
  description = "Administrator login of the database server"
  type        = string
  default     = "quizzadmin"
}

variable "postgres_database_name" {
  description = "Application database, created empty and migrated by Flyway at startup"
  type        = string
  default     = "quizz"
}

variable "redis_sku_name" {
  description = "Azure Managed Redis SKU"
  type        = string
  default     = "Balanced_B0"
}
