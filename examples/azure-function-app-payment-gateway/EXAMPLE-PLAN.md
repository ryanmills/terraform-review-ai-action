# Example Terraform Plan Output

This document shows an example of the resources that would be created when deploying this solution.

## Development Environment

When you run `terraform plan` in the dev environment, Terraform will create the following resources:

### Resource Summary

```
Plan: 22 to add, 0 to change, 0 to destroy.
```

### Resources Created

#### Core Infrastructure

1. **Resource Group** (`module.resource_group`)
   - Name: `rg-payment-gateway-dev-eus`
   - Location: East US
   - Tags: Environment=Development, Application=PaymentGateway

2. **Virtual Network** (`azurerm_virtual_network.main`)
   - Name: `vnet-payment-gateway-dev`
   - Address Space: `10.1.0.0/16`
   - Subnets:
     - `snet-functions`: `10.1.1.0/24` (with delegation to Microsoft.Web/serverFarms)

#### Compute

3. **App Service Plan** (`azurerm_service_plan.function_plan`)
   - Name: `plan-func-dev-{random}`
   - SKU: FC1 (Flex Consumption)
   - OS: Linux

4. **Linux Function App** (`azurerm_linux_function_app.main`)
   - Name: `func-payment-dev-{random}`
   - Runtime: Python 3.11
   - Configuration:
     - HTTPS only: true
     - VNet Integration: false (dev)
     - Managed Identity: System Assigned

#### Storage

5. **Storage Account** (`module.storage_account`)
   - Name: `stfuncdev{random}`
   - Tier: Standard
   - Replication: LRS
   - HTTPS Only: true
   - TLS Version: 1.2

#### Security

6. **Key Vault** (`module.key_vault`)
   - Name: `kv-pay-dev-{random}`
   - SKU: Standard
   - Soft Delete: 7 days
   - Purge Protection: false (dev)
   - RBAC: Enabled

7. **Key Vault Secrets**
   - `stripe-api-key` (placeholder)
   - `stripe-webhook-secret` (placeholder)

8. **RBAC Assignment** (`azurerm_role_assignment.function_app_keyvault_secrets_user`)
   - Role: Key Vault Secrets User
   - Principal: Function App Managed Identity
   - Scope: Key Vault

#### Monitoring

9. **Log Analytics Workspace** (`module.log_analytics`)
   - Name: `law-payment-gateway-dev-{random}`
   - SKU: PerGB2018
   - Retention: 30 days
   - Daily Quota: 10 GB

10. **Application Insights** (`module.application_insights`)
    - Name: `appi-payment-gateway-dev-{random}`
    - Type: Web
    - Workspace: Linked to Log Analytics
    - Retention: 30 days

#### Supporting Resources

11. **Random String** (`random_string.suffix`)
    - Length: 6 characters
    - Used for globally unique naming

### Outputs

After deployment, Terraform will output:

```hcl
Outputs:

function_app_name = "func-payment-dev-abc123"
function_app_default_hostname = "func-payment-dev-abc123.azurewebsites.net"
function_app_identity_principal_id = "12345678-1234-1234-1234-123456789012"

key_vault_name = "kv-pay-dev-abc123"
key_vault_uri = "https://kv-pay-dev-abc123.vault.azure.net/"

storage_account_name = "stfuncdevabc123"
application_insights_name = "appi-payment-gateway-dev-abc123"
log_analytics_workspace_name = "law-payment-gateway-dev-abc123"

resource_group_name = "rg-payment-gateway-dev-eus"
virtual_network_name = "vnet-payment-gateway-dev"
function_subnet_id = "/subscriptions/.../subnets/snet-functions"

deployment_instructions = <<-EOT
====================================
Deployment Complete!
====================================

Next Steps:

1. Update Stripe API secrets in Key Vault:
   az keyvault secret set --vault-name kv-pay-dev-abc123 --name stripe-api-key --value "your-stripe-api-key"
   az keyvault secret set --vault-name kv-pay-dev-abc123 --name stripe-webhook-secret --value "your-stripe-webhook-secret"

2. Deploy Function App code:
   func azure functionapp publish func-payment-dev-abc123

3. Access Application Insights:
   https://portal.azure.com/#resource/subscriptions/.../Microsoft.Insights/components/appi-payment-gateway-dev-abc123

4. Function App URL:
   https://func-payment-dev-abc123.azurewebsites.net

5. Verify VNet Integration:
   az functionapp vnet-integration list --name func-payment-dev-abc123 --resource-group rg-payment-gateway-dev-eus

====================================
EOT
```

## Test Environment Differences

The test environment creates the same resources with these differences:

- VNet Integration: **Enabled**
- Storage Replication: **GRS** (instead of LRS)
- Log Retention: **60 days** (instead of 30)
- Daily Quota: **10 GB** (same as dev)
- Max Instances: **50** (instead of 10)

## Production Environment Differences

The production environment creates the same resources with these differences:

- VNet Integration: **Enabled** (required)
- Storage Replication: **GRS** (geo-redundant)
- Log Retention: **90 days**
- Daily Quota: **50 GB**
- Max Instances: **100**
- Key Vault Purge Protection: **Enabled**
- Key Vault Soft Delete: **90 days**
- Network ACLs: **Deny by default** (whitelist required)
- Instance Memory: **4096 MB** (instead of 2048 MB)
- Additional Tags: Compliance=PCI-DSS, DataClass=Sensitive

## Resource Dependencies

```
random_string.suffix
└── module.resource_group
    ├── azurerm_virtual_network.main
    │   └── azurerm_subnet.function_subnet
    ├── module.log_analytics
    │   └── module.application_insights
    ├── module.storage_account
    ├── module.key_vault
    │   ├── azurerm_role_assignment.function_app_keyvault_secrets_user
    │   ├── azurerm_key_vault_secret.stripe_api_key
    │   └── azurerm_key_vault_secret.stripe_webhook_secret
    └── azurerm_service_plan.function_plan
        └── azurerm_linux_function_app.main
            └── azurerm_role_assignment.function_app_keyvault_secrets_user
```

## Estimated Deployment Time

- **Initial Deployment**: 5-8 minutes
- **Subsequent Updates**: 2-5 minutes

## Cost Estimate

### Development Environment
- **Monthly Cost**: ~$50-80
  - Function App (Flex): $10-20
  - Storage (LRS): $5-10
  - Key Vault: $5
  - App Insights: $10-20
  - Log Analytics: $10-20
  - VNet: $5

### Test Environment
- **Monthly Cost**: ~$80-150
  - Function App (Flex): $20-40
  - Storage (GRS): $10-20
  - Key Vault: $5
  - App Insights: $15-30
  - Log Analytics: $20-40
  - VNet: $5

### Production Environment
- **Monthly Cost**: ~$160-505
  - Function App (Flex): $50-200
  - Storage (GRS): $20-40
  - Key Vault: $5-10
  - App Insights: $30-100
  - Log Analytics: $50-150
  - VNet: $5

*Note: Actual costs depend on usage patterns and transaction volume*

## Verification Steps

After deployment, verify the infrastructure:

```bash
# 1. Check Function App status
az functionapp show --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus \
  --query "{name:name,state:state,defaultHostName:defaultHostName}"

# 2. Verify Key Vault
az keyvault show --name kv-pay-dev-abc123 \
  --query "{name:name,vaultUri:properties.vaultUri,enableRbacAuthorization:properties.enableRbacAuthorization}"

# 3. Check storage account
az storage account show --name stfuncdevabc123 \
  --resource-group rg-payment-gateway-dev-eus \
  --query "{name:name,httpsOnly:enableHttpsTrafficOnly,tls:minimumTlsVersion}"

# 4. Verify managed identity
az functionapp identity show --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus

# 5. Check RBAC assignments
az role assignment list --scope /subscriptions/.../resourceGroups/rg-payment-gateway-dev-eus/providers/Microsoft.KeyVault/vaults/kv-pay-dev-abc123 \
  --query "[?principalType=='ServicePrincipal'].{role:roleDefinitionName,principal:principalId}"
```

---

**Note**: This is an example output. Actual resource IDs and names will vary based on the random suffix generated during deployment.
