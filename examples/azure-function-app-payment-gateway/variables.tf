variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
  default     = "eus"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "PaymentGateway"
    ManagedBy   = "Terraform"
    Repository  = "terraform-review-ai-action"
    CostCenter  = "Engineering"
  }
}

# Networking Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
}

variable "function_subnet_prefix" {
  description = "Address prefix for the function app subnet"
  type        = string
}

variable "enable_vnet_integration" {
  description = "Enable VNet integration for Function App"
  type        = bool
  default     = true
}

variable "allowed_ip_addresses" {
  description = "List of allowed IP addresses for network rules"
  type        = list(string)
  default     = []
}

variable "allowed_cors_origins" {
  description = "List of allowed CORS origins for the Function App"
  type        = list(string)
  default     = ["https://dashboard.stripe.com"]
}

# Storage Configuration
variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
}

# Function App Configuration
variable "function_app_runtime" {
  description = "Function App runtime"
  type        = string
  default     = "python"
}

variable "function_app_runtime_version" {
  description = "Function App runtime version"
  type        = string
  default     = "3.11"
}

variable "max_instance_count" {
  description = "Maximum instance count for Flex Consumption plan"
  type        = number
  default     = 100
}

variable "instance_memory_mb" {
  description = "Memory per instance in MB (2048 or 4096)"
  type        = number
  default     = 2048
  validation {
    condition     = contains([2048, 4096], var.instance_memory_mb)
    error_message = "Instance memory must be 2048 or 4096 MB."
  }
}
