# infra/modules/functions/main.tf

# ── NO DATA SOURCE NEEDED ─────────────────────────────────────────────────────
# The resource group name and location come in as input variables.
# The Terragrunt dependency block in each environment's terragrunt.hcl
# guarantees aks-acr runs first and passes resource_group_name as output.
# This means the RG is guaranteed to exist before any resource here is created —
# regardless of whether you run via pipeline or manually.
#
# See environments/<env>/functions/terragrunt.hcl for the dependency block.
# ─────────────────────────────────────────────────────────────────────────────

# ── STORAGE ACCOUNT ───────────────────────────────────────────────────────────
# Every Durable Functions setup needs a storage account.
# This is where ALL orchestration state lives:
#   - Azure Table Storage  → orchestration history and checkpoints
#   - Azure Queue Storage  → messages between orchestrator and activities
#   - Azure Blob Storage   → large payloads that exceed queue message size
#
# If this storage account is deleted, ALL orchestration history is gone.
resource "azurerm_storage_account" "functions" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
  # LRS = 3 copies in one datacenter — fine for dev/staging
  # GRS = 6 copies across 2 regions    — required for prod

  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "demoapi-functions"
  }

  # lifecycle {
  #   prevent_destroy = true   # uncomment for prod
  # }
}

# ── APP SERVICE PLAN (CONSUMPTION) ────────────────────────────────────────────
# sku_name = "Y1"  → Consumption plan (free tier, pay per execution)
# sku_name = "EP1" → Premium plan (~£120/month, no cold starts)
# os_type  = "Linux" matches your Dockerfile
resource "azurerm_service_plan" "functions" {
  name                = var.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "demoapi-functions"
  }
}

# ── FUNCTION APP ──────────────────────────────────────────────────────────────
# The platform — not the code.
# Code is deployed separately via pipeline, same as Docker image → AKS.
resource "azurerm_linux_function_app" "functions" {
  name                = var.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  # NOTE: enterprise improvement = managed identity instead of access key

  # Same pattern as your AKS cluster — SystemAssigned identity
  # so Function App can authenticate to Azure services without credentials
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
      # isolated = required for .NET 8
      # in-process model only supports up to .NET 6
    }
  }

  app_settings = {
    # Where Durable Functions stores ALL orchestration state
    # Without this, no orchestrations can run
    "AzureWebJobsStorage" = azurerm_storage_account.functions.primary_connection_string

    # Run from zip package — required for Consumption plan deployments
    "WEBSITE_RUN_FROM_PACKAGE" = "1"

    # Same concept as ASPNETCORE_ENVIRONMENT in your deployment.yaml
    "FUNCTIONS_ENVIRONMENT" = var.environment

    # Must match use_dotnet_isolated_runtime = true above
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"

    # Uncomment when we cover Observability module
    # "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "demoapi-functions"
  }

  # lifecycle {
  #   prevent_destroy = true   # uncomment for prod
  # }
}

# ── ROLE ASSIGNMENT ───────────────────────────────────────────────────────────
# Grant Function App managed identity Storage Blob Data Owner
# on its own storage account.
#
# Access key  → covers queue + table operations (Durable state)
# This role   → covers blob operations (large payloads)
# Both needed for full Durable Functions functionality.
#
# Identical pattern to AcrPull on AKS — same idea, different resource.
resource "azurerm_role_assignment" "functions_storage" {
  principal_id         = azurerm_linux_function_app.functions.identity[0].principal_id
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.functions.id
  skip_service_principal_aad_check = true
  # Same flag as your AcrPull assignment — managed identities are not
  # traditional service principals, so skip the AAD validation check
}