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
