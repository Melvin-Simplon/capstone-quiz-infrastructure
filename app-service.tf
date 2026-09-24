resource "azurerm_service_plan" "backend" {
  name                = "plan-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  os_type  = "Linux"
  sku_name = var.app_service_plan_sku

  tags = merge(local.common_tags, { component = "backend" })
}

resource "azurerm_linux_web_app" "backend" {
  name                = "app-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = azurerm_service_plan.backend.location
  service_plan_id     = azurerm_service_plan.backend.id

  https_only = true

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  public_network_access_enabled = true

  virtual_network_subnet_id = azurerm_subnet.app.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    health_check_path                 = "/actuator/health"
    health_check_eviction_time_in_min = 5
    ftps_state                        = "Disabled"

    minimum_tls_version = "1.2"
    http2_enabled       = true

    vnet_route_all_enabled = true

    application_stack {
      java_server         = "JAVA"
      java_server_version = "21"
      java_version        = "21"
    }

    auto_heal_setting {
      trigger {
        status_code {
          status_code_range = "500-599"
          count             = 20
          interval          = "00:05:00"
        }
      }

      action {
        action_type                    = "Recycle"
        minimum_process_execution_time = "00:05:00"
      }
    }
  }

  app_settings = {
    SPRING_PROFILES_ACTIVE = "prod"
    WEBSITES_PORT          = "8080"

    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
    SPRING_DATASOURCE_USERNAME = var.postgres_admin_username
    SPRING_DATASOURCE_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_admin_password.versionless_id})"

    REDIS_HOSTNAME    = azurerm_managed_redis.main.hostname
    REDIS_PORT        = tostring(azurerm_managed_redis.main.default_database[0].port)
    REDIS_PASSWORD    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.redis_primary_key.versionless_id})"
    REDIS_SSL_ENABLED = "true"

    STORAGE_ACCOUNT_NAME   = azurerm_storage_account.main.name
    STORAGE_CONTAINER_NAME = azurerm_storage_container.uploads.name

    BACKEND_API_KEY          = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.backend_api_key.versionless_id})"
    APP_CORS_ALLOWED_ORIGINS = local.frontend_origin
  }

  tags = merge(local.common_tags, { component = "backend" })
}
