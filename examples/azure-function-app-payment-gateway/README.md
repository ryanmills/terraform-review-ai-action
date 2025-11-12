# Azure Function App Payment Gateway - Multi-Environment Example

This example demonstrates a production-ready, multi-environment Azure Function App solution using **Azure Verified Modules (AVM)** to create a payment gateway that processes credit card information via Stripe API.

## Architecture Overview

This solution deploys:
- **Azure Function App** with Flex Consumption plan for cost-effective, scalable serverless computing
- **Storage Account** for Function App runtime and state
- **Key Vault** for secure Stripe API key storage
- **Application Insights** for monitoring and telemetry
- **Virtual Network** integration for secure network isolation
- **Log Analytics Workspace** for centralized logging

## Environments

The solution supports three environments:
- **dev** - Development environment with minimal resources
- **test** - Testing/staging environment with moderate resources
- **prod** - Production environment with high availability and security

## Azure Verified Modules Used

This example uses only Microsoft-verified Terraform modules from the [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) initiative:

- `Azure/avm-res-web-site/azurerm` - Function App with Flex Consumption plan
- `Azure/avm-res-storage-storageaccount/azurerm` - Storage Account
- `Azure/avm-res-keyvault-vault/azurerm` - Key Vault for secrets management
- `Azure/avm-res-operationalinsights-workspace/azurerm` - Log Analytics Workspace
- `Azure/avm-res-insights-component/azurerm` - Application Insights
- `Azure/avm-res-network-virtualnetwork/azurerm` - Virtual Network
- `Azure/avm-res-resources-resourcegroup/azurerm` - Resource Group

## Prerequisites

1. Azure subscription
2. Terraform >= 1.9.0
3. Azure CLI authenticated (`az login`)
4. Stripe API account and API keys

## Deployment

### Deploy Development Environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Deploy Test Environment

```bash
cd environments/test
terraform init
terraform plan
terraform apply
```

### Deploy Production Environment

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Configuration

### Stripe API Integration

After deployment, configure the Stripe API key in Key Vault:

```bash
# Set Stripe API key in Key Vault
az keyvault secret set \
  --vault-name <keyvault-name> \
  --name stripe-api-key \
  --value <your-stripe-api-key>
```

### Function App Code

Deploy your payment processing function code:

```bash
# Package and deploy function code
cd function-code
func azure functionapp publish <function-app-name>
```

## Security Features

- ✅ Secrets stored in Azure Key Vault
- ✅ VNet integration for network isolation
- ✅ HTTPS-only traffic enforcement
- ✅ Managed Identity for secure authentication
- ✅ Application Insights for monitoring
- ✅ Minimum TLS 1.2 enforcement

## Cost Optimization

- Flex Consumption plan scales to zero when idle
- Pay only for execution time and memory used
- Optimized storage tier selection per environment
- Resource tagging for cost allocation

## Monitoring

Access monitoring through:
- **Application Insights** - Real-time metrics and logs
- **Log Analytics** - Centralized query and analysis
- **Azure Monitor** - Alerts and dashboards

## CI/CD Integration

See the included workflow file for GitHub Actions integration:
- `.github/workflows/function-app-deployment.yml`

## Compliance

This solution follows:
- Azure Well-Architected Framework
- PCI-DSS guidelines for payment processing
- GDPR data protection standards
- Azure security baseline

## Related Resources

- [Azure Verified Modules Documentation](https://azure.github.io/Azure-Verified-Modules/)
- [Azure Functions Flex Consumption](https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Azure Functions Security](https://learn.microsoft.com/en-us/azure/azure-functions/security-concepts)
