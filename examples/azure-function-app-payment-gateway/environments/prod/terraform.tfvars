# Production Environment Configuration
environment = "prod"
location    = "eastus"

# Networking
vnet_address_space     = "10.0.0.0/16"
function_subnet_prefix = "10.0.1.0/24"
enable_vnet_integration = true

# Storage
storage_account_tier      = "Standard"
storage_replication_type  = "GRS"

# Monitoring
log_retention_days = 90

# Function App
max_instance_count = 100
instance_memory_mb = 4096

# CORS
allowed_cors_origins = [
  "https://dashboard.stripe.com",
  "https://www.example.com",
  "https://api.example.com"
]

# Tags
common_tags = {
  Project     = "PaymentGateway"
  ManagedBy   = "Terraform"
  Repository  = "terraform-review-ai-action"
  CostCenter  = "Engineering"
  Environment = "Production"
  Compliance  = "PCI-DSS"
  DataClass   = "Sensitive"
}
