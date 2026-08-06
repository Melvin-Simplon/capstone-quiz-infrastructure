resource "azurerm_linux_web_app" "backend" {
  name                = "app-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_service_plan.shared.location
  service_plan_id     = data.azurerm_service_plan.shared.id

  https_only = true

  # Publishing profiles are password based and enabled by default. Deployments
  # come from GitHub Actions over OIDC, so these are two sets of credentials that
  # exist only to be stolen.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # Reachable from the internet, unavoidably: the frontend is a static site, so
  # its calls come from the visitor's browser and no source address can be listed
  # in advance. The X-Api-Key filter and the CORS origin below are what stand in
  # for a network restriction here, and the trade-off is written up in the ADR.
  public_network_access_enabled = true

  # Outbound side: every call to the database, the cache, the storage account and
  # the vault leaves through this subnet and stays inside the network.
  virtual_network_subnet_id = azurerm_subnet.app.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    # Polled by App Service, which takes the instance out of rotation once it has
    # been failing for this long.
    health_check_path                 = "/actuator/health"
    health_check_eviction_time_in_min = 5
    ftps_state                        = "Disabled"

    minimum_tls_version = "1.2"
    http2_enabled       = true

    # Without this, only private address ranges are routed to the subnet and calls
    # to the private endpoints would go back out through the public path.
    vnet_route_all_enabled = true

    # No cors block on purpose: the backend already answers the preflight itself
    # (WebConfig, fed by APP_CORS_ALLOWED_ORIGINS below). Declaring it here too
    # makes App Service add a second Access-Control-Allow-Origin header, which
    # browsers reject outright.

    application_stack {
      java_server         = "JAVA"
      java_server_version = "21"
      java_version        = "21"
    }

    # The health check only covers an instance that stopped answering entirely.
    # This covers the other failure mode, a JVM still alive but serving errors,
    # which the probe on /actuator/health would not necessarily catch.
    auto_heal_setting {
      trigger {
        status_code {
          status_code_range = "500-599"
          count             = 20
          interval          = "00:05:00"
        }
      }

      action {
        action_type = "Recycle"
        # Never recycle an instance that just started: a cold start replaying the
        # Flyway migrations legitimately takes a while.
        minimum_process_execution_time = "00:05:00"
      }
    }
  }

  app_settings = {
    SPRING_PROFILES_ACTIVE = "prod"
    # The application listens on 8080; App Service otherwise probes port 80.
    WEBSITES_PORT = "8080"

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
