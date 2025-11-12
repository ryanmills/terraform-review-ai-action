# Test Environment Configuration
environment = "test"
location    = "eastus"

# Networking
vnet_address_space     = "10.2.0.0/16"
function_subnet_prefix = "10.2.1.0/24"
enable_vnet_integration = true

# Storage
storage_account_tier      = "Standard"
storage_replication_type  = "GRS"

# Monitoring
log_retention_days = 60

# Function App
max_instance_count = 50
instance_memory_mb = 2048

# CORS
allowed_cors_origins = [
  "https://dashboard.stripe.com",
  "https://test.example.com"
]

# Tags
common_tags = {
  Project     = "PaymentGateway"
  ManagedBy   = "Terraform"
  Repository  = "terraform-review-ai-action"
  CostCenter  = "Engineering"
  Environment = "Test"
}
