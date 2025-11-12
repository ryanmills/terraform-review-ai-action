# Quick Start Guide

Get your payment gateway running in under 15 minutes!

## Prerequisites

- Azure subscription ([Free trial available](https://azure.microsoft.com/free/))
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- [Terraform](https://www.terraform.io/downloads.html) >= 1.9.2 installed
- [Stripe account](https://dashboard.stripe.com/register) (free test account)

## Step 1: Clone and Navigate (1 minute)

```bash
git clone https://github.com/thomast1906/terraform-review-ai-action.git
cd terraform-review-ai-action/examples/azure-function-app-payment-gateway/environments/dev
```

## Step 2: Azure Login (1 minute)

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Verify
az account show
```

## Step 3: Initialize Terraform (2 minutes)

```bash
# Initialize Terraform
terraform init

# Preview what will be created
terraform plan
```

## Step 4: Deploy Infrastructure (5 minutes)

```bash
# Deploy all resources
terraform apply

# Type 'yes' when prompted
# ☕ Grab coffee - this takes about 5 minutes
```

## Step 5: Configure Stripe (2 minutes)

### Get Your Stripe Test Keys

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys)
2. Copy your **Secret key** (starts with `sk_test_`)

### Store in Key Vault

```bash
# Get your Key Vault name from Terraform output
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

# Set your Stripe test API key
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name stripe-api-key \
  --value "sk_test_YOUR_KEY_HERE"

# Set a placeholder webhook secret (update later)
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name stripe-webhook-secret \
  --value "whsec_placeholder"
```

## Step 6: Deploy Function Code (3 minutes)

```bash
# Install Azure Functions Core Tools (if not already installed)
# On macOS
brew install azure-functions-core-tools@4

# On Ubuntu/Debian
sudo apt-get install azure-functions-core-tools-4

# On Windows
choco install azure-functions-core-tools-4

# Deploy the function code
cd ../../function-code
FUNCTION_APP=$(cd ../environments/dev && terraform output -raw function_app_name)
func azure functionapp publish $FUNCTION_APP --python
```

## Step 7: Test It! (1 minute)

```bash
# Get your function app URL
FUNCTION_URL=$(cd ../environments/dev && terraform output -raw function_app_default_hostname)

# Test health check
curl https://$FUNCTION_URL/api/health

# You should see:
# {"status": "healthy", "environment": "DEV", "mode": "test", "stripe_configured": true}
```

### Test a Payment

```bash
# Get your function key
FUNCTION_KEY=$(az functionapp keys list \
  --name $FUNCTION_APP \
  --resource-group $(cd ../environments/dev && terraform output -raw resource_group_name) \
  --query masterKey -o tsv)

# Process a test payment using Stripe's test card
curl -X POST "https://$FUNCTION_URL/api/process-payment?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000,
    "currency": "usd", 
    "payment_method": "pm_card_visa",
    "description": "Quick start test payment"
  }'

# You should see a success response! 🎉
```

## That's It! 🚀

Your payment gateway is now running!

## What You've Deployed

- ✅ Serverless Function App (scales to zero)
- ✅ Secure Key Vault for secrets
- ✅ Application Insights for monitoring
- ✅ Storage account for function runtime
- ✅ Virtual network (ready for VNet integration)
- ✅ Log Analytics for centralized logging

## Next Steps

### View Your Resources

```bash
# Open Azure Portal to your resource group
az group show --name $(cd ../environments/dev && terraform output -raw resource_group_name) --query id -o tsv | \
  xargs -I {} echo "https://portal.azure.com/#@/resource{}/overview"
```

### Monitor Your Function

```bash
# View recent requests in Application Insights
APP_INSIGHTS=$(cd ../environments/dev && terraform output -raw application_insights_name)
RESOURCE_GROUP=$(cd ../environments/dev && terraform output -raw resource_group_name)

az monitor app-insights query \
  --app $APP_INSIGHTS \
  --resource-group $RESOURCE_GROUP \
  --analytics-query "requests | where timestamp > ago(1h) | project timestamp, name, resultCode, duration"
```

### Set Up Stripe Webhooks (Optional)

1. Go to [Stripe Webhooks](https://dashboard.stripe.com/test/webhooks)
2. Click "Add endpoint"
3. Enter URL: `https://$FUNCTION_URL/api/webhook`
4. Select events: `payment_intent.succeeded`, `payment_intent.payment_failed`
5. Copy the signing secret
6. Update in Key Vault:
   ```bash
   az keyvault secret set \
     --vault-name $KEY_VAULT_NAME \
     --name stripe-webhook-secret \
     --value "whsec_YOUR_WEBHOOK_SECRET"
   ```

## Common Issues

### "az: command not found"
Install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli

### "terraform: command not found"  
Install Terraform: https://www.terraform.io/downloads.html

### "func: command not found"
Install Azure Functions Core Tools: https://docs.microsoft.com/azure/azure-functions/functions-run-local

### "Error: ... already exists"
Resource names must be globally unique. Terraform will generate a random suffix automatically. If deployment fails, try running `terraform destroy` and then `terraform apply` again.

### "Payment failed: Stripe authentication error"
Verify your Stripe API key in Key Vault is correct and starts with `sk_test_`

## Costs

Development environment costs approximately **$50-80/month** with typical usage:
- Most cost comes from Application Insights and Log Analytics
- Function App (Flex Consumption) is very cheap - you only pay for execution time
- First 1 million executions/month are free

**Tip**: Run `terraform destroy` when not using to avoid charges!

## Production Deployment

When ready for production:

1. **Switch to prod environment:**
   ```bash
   cd ../environments/prod
   ```

2. **Update Stripe keys:**
   - Use live mode keys (starts with `sk_live_`)
   - Configure production webhook endpoints

3. **Enable security features:**
   - VNet integration (already configured)
   - Network ACLs (already configured)
   - Review SECURITY.md

4. **Deploy:**
   ```bash
   terraform init
   terraform apply
   ```

## Learn More

- **[Full Documentation](README.md)** - Complete deployment guide
- **[Architecture](ARCHITECTURE.md)** - Detailed architecture and design
- **[Security](SECURITY.md)** - Security controls and compliance
- **[Testing](TESTING.md)** - Comprehensive testing guide

## Cleanup

When you're done testing:

```bash
cd ../environments/dev
terraform destroy

# Type 'yes' when prompted
# This will delete all resources and stop charges
```

---

**Need Help?**
- Check [TESTING.md](TESTING.md) for detailed testing examples
- Review [SECURITY.md](SECURITY.md) for security best practices
- See [ARCHITECTURE.md](ARCHITECTURE.md) for architecture details

**Happy Building! 🎉**
