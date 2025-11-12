# Development Environment Configuration
environment = "dev"
location    = "eastus"

# Networking
vnet_address_space     = "10.1.0.0/16"
function_subnet_prefix = "10.1.1.0/24"
enable_vnet_integration = false # Disabled in dev for easier testing

# Storage
storage_account_tier      = "Standard"
storage_replication_type  = "LRS"

# Monitoring
log_retention_days = 30

# Function App
max_instance_count = 10
instance_memory_mb = 2048

# CORS
allowed_cors_origins = [
  "https://dashboard.stripe.com",
  "http://localhost:7071"  # For local development
]

# Tags
common_tags = {
  Project     = "PaymentGateway"
  ManagedBy   = "Terraform"
  Repository  = "terraform-review-ai-action"
  CostCenter  = "Engineering"
  Environment = "Development"
}
