# Testing Guide

This guide covers how to test the payment gateway function app after deployment.

## Prerequisites

- Azure subscription with deployed infrastructure
- Stripe account (test mode)
- Azure CLI installed and authenticated
- Python 3.11+ (for local testing)
- Azure Functions Core Tools v4

## Setup Test Environment

### 1. Configure Stripe Test Keys

```bash
# Set your Stripe test API key in Key Vault
az keyvault secret set \
  --vault-name kv-pay-dev-abc123 \
  --name stripe-api-key \
  --value "sk_test_YOUR_TEST_KEY_HERE"

# Set webhook secret (from Stripe dashboard)
az keyvault secret set \
  --vault-name kv-pay-dev-abc123 \
  --name stripe-webhook-secret \
  --value "whsec_YOUR_WEBHOOK_SECRET"
```

### 2. Get Function App URL and Key

```bash
# Get function app URL
FUNCTION_URL=$(az functionapp show \
  --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus \
  --query defaultHostName -o tsv)

# Get function key (master key)
FUNCTION_KEY=$(az functionapp keys list \
  --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus \
  --query masterKey -o tsv)

echo "Function URL: https://$FUNCTION_URL"
echo "Function Key: $FUNCTION_KEY"
```

## Test Payment Processing

### Test 1: Health Check

```bash
curl -X GET "https://$FUNCTION_URL/api/health"
```

**Expected Response:**
```json
{
  "status": "healthy",
  "environment": "DEV",
  "mode": "test",
  "stripe_configured": true
}
```

### Test 2: Process Test Payment (Success)

```bash
curl -X POST "https://$FUNCTION_URL/api/process-payment?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000,
    "currency": "usd",
    "payment_method": "pm_card_visa",
    "description": "Test payment #1",
    "metadata": {
      "order_id": "TEST-001",
      "customer_id": "test-customer-123"
    }
  }'
```

**Expected Response:**
```json
{
  "status": "succeeded",
  "payment_intent_id": "pi_xxxxxxxxxxxxx",
  "amount": 1000,
  "currency": "usd",
  "environment": "DEV",
  "message": "Payment processed successfully"
}
```

### Test 3: Process Test Payment (Declined Card)

Use Stripe's test card numbers to simulate failures:

```bash
curl -X POST "https://$FUNCTION_URL/api/process-payment?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000,
    "currency": "usd",
    "payment_method": "pm_card_chargeDeclined",
    "description": "Test declined payment",
    "metadata": {
      "order_id": "TEST-002"
    }
  }'
```

**Expected Response:**
```json
{
  "error": "Card was declined",
  "status": "failed",
  "details": "Your card was declined."
}
```

### Test 4: Invalid Request (Missing Fields)

```bash
curl -X POST "https://$FUNCTION_URL/api/process-payment?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000
  }'
```

**Expected Response:**
```json
{
  "error": "Missing required field: currency",
  "status": "failed"
}
```

## Test Webhook Processing

### Setup Stripe Webhook

1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint: `https://$FUNCTION_URL/api/webhook`
3. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Copy the webhook signing secret and update Key Vault

### Test Webhook Locally

```bash
# Send test webhook event (requires valid signature from Stripe)
stripe trigger payment_intent.succeeded --stripe-webhook-secret $WEBHOOK_SECRET
```

## Load Testing

### Simple Load Test with Apache Bench

```bash
# Install apache bench
sudo apt-get install apache2-utils

# Create payload file
cat > payment.json <<EOF
{
  "amount": 100,
  "currency": "usd",
  "payment_method": "pm_card_visa",
  "description": "Load test payment"
}
EOF

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 \
  -p payment.json \
  -T "application/json" \
  -H "x-functions-key: $FUNCTION_KEY" \
  "https://$FUNCTION_URL/api/process-payment"
```

### Load Test with Artillery

```bash
# Install artillery
npm install -g artillery

# Create load test config
cat > load-test.yml <<EOF
config:
  target: "https://$FUNCTION_URL"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Sustained load"
scenarios:
  - name: "Process Payment"
    flow:
      - post:
          url: "/api/process-payment?code=$FUNCTION_KEY"
          json:
            amount: 1000
            currency: "usd"
            payment_method: "pm_card_visa"
            description: "Load test payment"
EOF

# Run test
artillery run load-test.yml
```

## Monitor Test Results

### View Logs in Application Insights

```bash
# Query recent requests
az monitor app-insights query \
  --app appi-payment-gateway-dev-abc123 \
  --analytics-query "requests | where timestamp > ago(1h) | project timestamp, name, resultCode, duration" \
  --resource-group rg-payment-gateway-dev-eus
```

### Check Failed Requests

```bash
az monitor app-insights query \
  --app appi-payment-gateway-dev-abc123 \
  --analytics-query "requests | where timestamp > ago(1h) and success == false | project timestamp, name, resultCode, customDimensions" \
  --resource-group rg-payment-gateway-dev-eus
```

### View Exceptions

```bash
az monitor app-insights query \
  --app appi-payment-gateway-dev-abc123 \
  --analytics-query "exceptions | where timestamp > ago(1h) | project timestamp, type, outerMessage, innermostMessage" \
  --resource-group rg-payment-gateway-dev-eus
```

## Integration Testing

### Automated Test Script

Create `test_payment_gateway.py`:

```python
import requests
import json
import os
import time

FUNCTION_URL = os.getenv("FUNCTION_URL")
FUNCTION_KEY = os.getenv("FUNCTION_KEY")

def test_health_check():
    """Test health endpoint"""
    response = requests.get(f"{FUNCTION_URL}/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    print("✓ Health check passed")

def test_successful_payment():
    """Test successful payment processing"""
    payload = {
        "amount": 1000,
        "currency": "usd",
        "payment_method": "pm_card_visa",
        "description": "Test payment",
        "metadata": {"test": "true"}
    }
    response = requests.post(
        f"{FUNCTION_URL}/api/process-payment?code={FUNCTION_KEY}",
        json=payload
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "succeeded"
    print("✓ Successful payment test passed")

def test_declined_payment():
    """Test declined payment handling"""
    payload = {
        "amount": 1000,
        "currency": "usd",
        "payment_method": "pm_card_chargeDeclined",
        "description": "Test declined payment"
    }
    response = requests.post(
        f"{FUNCTION_URL}/api/process-payment?code={FUNCTION_KEY}",
        json=payload
    )
    assert response.status_code == 402
    data = response.json()
    assert data["status"] == "failed"
    print("✓ Declined payment test passed")

def test_missing_fields():
    """Test validation of required fields"""
    payload = {"amount": 1000}
    response = requests.post(
        f"{FUNCTION_URL}/api/process-payment?code={FUNCTION_KEY}",
        json=payload
    )
    assert response.status_code == 400
    data = response.json()
    assert "error" in data
    print("✓ Validation test passed")

if __name__ == "__main__":
    print("Running Payment Gateway Tests...")
    test_health_check()
    time.sleep(1)
    test_successful_payment()
    time.sleep(1)
    test_declined_payment()
    time.sleep(1)
    test_missing_fields()
    print("\nAll tests passed! ✓")
```

Run the tests:

```bash
export FUNCTION_URL="https://func-payment-dev-abc123.azurewebsites.net"
export FUNCTION_KEY="your-function-key"
python test_payment_gateway.py
```

## Performance Benchmarks

Expected performance metrics:

| Metric | Target | Acceptable |
|--------|--------|------------|
| Health check response | < 100ms | < 200ms |
| Payment processing (p50) | < 1s | < 2s |
| Payment processing (p95) | < 2s | < 5s |
| Payment processing (p99) | < 3s | < 8s |
| Success rate | > 99% | > 95% |
| Cold start time | < 3s | < 5s |

## Security Testing

### Test HTTPS Enforcement

```bash
# Attempt HTTP (should fail)
curl -v http://$FUNCTION_URL/api/health

# HTTPS should work
curl -v https://$FUNCTION_URL/api/health
```

### Test CORS Configuration

```bash
# Test from allowed origin
curl -X OPTIONS "https://$FUNCTION_URL/api/process-payment" \
  -H "Origin: https://dashboard.stripe.com" \
  -H "Access-Control-Request-Method: POST" \
  -v

# Test from disallowed origin (should be blocked)
curl -X OPTIONS "https://$FUNCTION_URL/api/process-payment" \
  -H "Origin: https://malicious-site.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

### Test Key Vault Integration

```bash
# Verify function can access secrets
az monitor app-insights query \
  --app appi-payment-gateway-dev-abc123 \
  --analytics-query "traces | where message contains 'Key Vault' | project timestamp, message" \
  --resource-group rg-payment-gateway-dev-eus
```

## Troubleshooting

### Function Not Responding

```bash
# Check function app status
az functionapp show \
  --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus \
  --query state

# Restart function app
az functionapp restart \
  --name func-payment-dev-abc123 \
  --resource-group rg-payment-gateway-dev-eus
```

### Key Vault Access Issues

```bash
# Verify managed identity has access
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --scope <key-vault-resource-id>

# Check Key Vault audit logs
az monitor activity-log list \
  --resource-id <key-vault-resource-id> \
  --offset 1h
```

### Stripe API Errors

```bash
# View Stripe-related errors in logs
az monitor app-insights query \
  --app appi-payment-gateway-dev-abc123 \
  --analytics-query "exceptions | where outerMessage contains 'Stripe' | project timestamp, outerMessage" \
  --resource-group rg-payment-gateway-dev-eus
```

## Cleanup

After testing, clean up test resources:

```bash
# Delete test resource group (WARNING: deletes everything)
terraform destroy -auto-approve

# Or manually delete specific test data
az keyvault secret delete \
  --vault-name kv-pay-dev-abc123 \
  --name stripe-api-key
```

---

**Note**: Always use Stripe test mode and test keys for all development and testing activities.
