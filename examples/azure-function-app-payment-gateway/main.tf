terraform {
  required_version = ">= 1.9.2"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = var.environment == "dev"
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }
  }
}

# Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group using AVM
module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.1.0"

  name     = "rg-payment-gateway-${var.environment}-${var.location_short}"
  location = var.location

  tags = merge(var.common_tags, {
    Environment = var.environment
    Application = "PaymentGateway"
    ManagedBy   = "Terraform"
  })
}

# Virtual Network - Using direct resources for compatibility
resource "azurerm_virtual_network" "main" {
  name                = "vnet-payment-gateway-${var.environment}"
  resource_group_name = module.resource_group.name
  location            = var.location
  address_space       = [var.vnet_address_space]

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [module.resource_group]
}

resource "azurerm_subnet" "function_subnet" {
  name                 = "snet-functions"
  resource_group_name  = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.function_subnet_prefix]

  delegation {
    name = "Microsoft.Web.serverFarms"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }

  depends_on = [azurerm_virtual_network.main]
}

# Log Analytics Workspace using AVM
module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.4.2"

  name                = "law-payment-gateway-${var.environment}-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location

  log_analytics_workspace_retention_in_days = var.log_retention_days
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_daily_quota_gb    = var.environment == "prod" ? 50 : 10

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [module.resource_group]
}

# Application Insights using AVM
module "application_insights" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "0.1.3"

  name                = "appi-payment-gateway-${var.environment}-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location

  application_type  = "web"
  workspace_id      = module.log_analytics.resource_id
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [module.log_analytics]
}

# Storage Account for Function App using AVM
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.2.9" # Updated to newer version for compatibility

  name                = "stfunc${var.environment}${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location

  account_tier                      = var.storage_account_tier
  account_replication_type          = var.storage_replication_type
  account_kind                      = "StorageV2"
  access_tier                       = "Hot"
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = true
  public_network_access_enabled     = true
  default_to_oauth_authentication   = false

  network_rules = {
    default_action = var.environment == "prod" ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
    ip_rules       = var.allowed_ip_addresses
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "FunctionAppStorage"
  })

  depends_on = [module.resource_group]
}

# Key Vault using AVM
module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.0"

  name                = "kv-pay-${var.environment}-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location

  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = var.environment == "prod"
  soft_delete_retention_days      = var.environment == "prod" ? 90 : 7
  sku_name                        = "standard"
  public_network_access_enabled   = var.environment == "prod" ? false : true

  network_acls = var.environment == "prod" ? {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.allowed_ip_addresses
    virtual_network_subnet_ids = []
  } : null

  # Role assignments for RBAC
  role_assignments = {
    secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "SecretManagement"
  })

  depends_on = [module.resource_group]
}

# Service Plan for Function App (Flex Consumption)
resource "azurerm_service_plan" "function_plan" {
  name                = "plan-func-${var.environment}-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption SKU

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [module.resource_group]
}

# Linux Function App with Flex Consumption
resource "azurerm_linux_function_app" "main" {
  name                = "func-payment-${var.environment}-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location

  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = module.storage_account.name
  storage_account_access_key = module.storage_account.resource.primary_access_key

  https_only = true

  site_config {
    application_insights_connection_string = module.application_insights.connection_string
    application_insights_key               = module.application_insights.instrumentation_key

    application_stack {
      python_version = "3.11"
    }

    cors {
      allowed_origins     = var.allowed_cors_origins
      support_credentials = true
    }

    ftps_state      = "Disabled"
    http2_enabled   = true
    minimum_tls_version = "1.2"
    
    vnet_route_all_enabled = var.enable_vnet_integration
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME              = "python"
    FUNCTIONS_EXTENSION_VERSION           = "~4"
    WEBSITE_RUN_FROM_PACKAGE              = "1"
    APPINSIGHTS_INSTRUMENTATIONKEY        = module.application_insights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = module.application_insights.connection_string
    
    # Stripe Configuration (reference to Key Vault)
    STRIPE_API_KEY         = "@Microsoft.KeyVault(SecretUri=${module.key_vault.uri}secrets/stripe-api-key/)"
    STRIPE_WEBHOOK_SECRET  = "@Microsoft.KeyVault(SecretUri=${module.key_vault.uri}secrets/stripe-webhook-secret/)"
    
    # Environment Configuration
    ENVIRONMENT            = upper(var.environment)
    PAYMENT_GATEWAY_MODE   = var.environment == "prod" ? "live" : "test"
    
    # Security Settings
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    WEBSITE_CONTENTOVERVNET             = var.enable_vnet_integration ? "1" : "0"
  }

  identity {
    type = "SystemAssigned"
  }

  virtual_network_subnet_id = var.enable_vnet_integration ? azurerm_subnet.function_subnet.id : null

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "PaymentProcessing"
  })

  depends_on = [
    module.resource_group,
    module.storage_account,
    module.application_insights,
    module.key_vault,
    azurerm_service_plan.function_plan,
    azurerm_subnet.function_subnet
  ]
}

# Grant Function App access to Key Vault secrets
resource "azurerm_role_assignment" "function_app_keyvault_secrets_user" {
  scope                = module.key_vault.resource_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id

  depends_on = [azurerm_linux_function_app.main]
}

# Create placeholder secrets in Key Vault (to be updated with real values)
resource "azurerm_key_vault_secret" "stripe_api_key" {
  name         = "stripe-api-key"
  value        = "placeholder-update-after-deployment"
  key_vault_id = module.key_vault.resource_id

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [
    module.key_vault,
    azurerm_role_assignment.function_app_keyvault_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "stripe_webhook_secret" {
  name         = "stripe-webhook-secret"
  value        = "placeholder-update-after-deployment"
  key_vault_id = module.key_vault.resource_id

  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  depends_on = [
    module.key_vault,
    azurerm_role_assignment.function_app_keyvault_secrets_user
  ]
}
