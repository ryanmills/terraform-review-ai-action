# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet (HTTPS)                             │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Application Gateway   │
                    │     /API Management     │ (Optional)
                    └────────────┬────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────────┐
│                     Azure Virtual Network                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Function App Subnet                        │  │
│  │  ┌───────────────────────────────────────────────────────┐   │  │
│  │  │          Azure Function App (Flex Consumption)        │   │  │
│  │  │  ┌────────────────────────────────────────────────┐   │   │  │
│  │  │  │  Payment Processing Function (Python 3.11)     │   │   │  │
│  │  │  │  ┌──────────────┬──────────────┬────────────┐  │   │   │  │
│  │  │  │  │ /process     │ /webhook     │ /health    │  │   │   │  │
│  │  │  │  │ -payment     │              │            │  │   │   │  │
│  │  │  │  └──────────────┴──────────────┴────────────┘  │   │   │  │
│  │  │  └────────────────────────────────────────────────┘   │   │  │
│  │  │           ▲                         ▲                  │   │  │
│  │  │           │ Managed Identity        │ VNet Integration│   │  │
│  │  └───────────┼─────────────────────────┼──────────────────   │  │
│  └──────────────┼─────────────────────────┼──────────────────────┘  │
└─────────────────┼─────────────────────────┼─────────────────────────┘
                  │                         │
        ┌─────────┴──────────┐  ┌──────────┴──────────┐
        │                    │  │                      │
┌───────▼──────────┐  ┌──────▼────────┐  ┌───────────▼────────┐
│  Azure Key Vault │  │   Storage     │  │ Application        │
│                  │  │   Account     │  │ Insights           │
│  ┌────────────┐  │  │               │  │                    │
│  │ Secrets:   │  │  │ - Function    │  │ - Telemetry        │
│  │ - Stripe   │  │  │   Runtime     │  │ - Logs             │
│  │   API Key  │  │  │ - State       │  │ - Metrics          │
│  │ - Webhook  │  │  │               │  │ - Alerts           │
│  │   Secret   │  │  │               │  │                    │
│  └────────────┘  │  └───────────────┘  └────────────────────┘
│                  │                              │
│  RBAC:           │                              │
│  Key Vault       │                    ┌─────────▼─────────┐
│  Secrets User    │                    │  Log Analytics    │
└──────────────────┘                    │  Workspace        │
                                        │                   │
                                        │  - Centralized    │
                                        │    Logging        │
                                        │  - Query Engine   │
                                        └───────────────────┘
```

## Payment Flow Sequence

```
┌────────┐          ┌──────────────┐         ┌─────────────┐         ┌───────┐
│ Client │          │ Function App │         │  Key Vault  │         │Stripe │
└───┬────┘          └──────┬───────┘         └──────┬──────┘         └───┬───┘
    │                      │                        │                    │
    │  POST /process-      │                        │                    │
    │  payment             │                        │                    │
    ├─────────────────────▶│                        │                    │
    │                      │                        │                    │
    │                      │  Get Stripe API Key    │                    │
    │                      ├───────────────────────▶│                    │
    │                      │◀───────────────────────┤                    │
    │                      │  API Key (via MI)      │                    │
    │                      │                        │                    │
    │                      │  Create Payment Intent │                    │
    │                      ├───────────────────────────────────────────▶│
    │                      │                        │                    │
    │                      │◀───────────────────────────────────────────┤
    │                      │  Payment Intent Created│                    │
    │                      │                        │                    │
    │                      │  Log Event             │                    │
    │                      ├──────────────┐         │                    │
    │                      │              │         │                    │
    │                      │◀─────────────┘         │                    │
    │                      │                        │                    │
    │  HTTP 200 OK         │                        │                    │
    │◀─────────────────────┤                        │                    │
    │  Payment Success     │                        │                    │
    │                      │                        │                    │
    │                      │   Webhook Event        │                    │
    │                      │◀───────────────────────────────────────────┤
    │                      │                        │                    │
    │                      │  Verify Signature      │                    │
    │                      ├───────────────────────▶│                    │
    │                      │◀───────────────────────┤                    │
    │                      │                        │                    │
    │                      │  Process Event         │                    │
    │                      ├──────────────┐         │                    │
    │                      │              │         │                    │
    │                      │◀─────────────┘         │                    │
    │                      │                        │                    │
    │                      │  HTTP 200 OK           │                    │
    │                      ├───────────────────────────────────────────▶│
    │                      │                        │                    │
```

## Multi-Environment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Development                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ - VNet Integration: Disabled                                   │ │
│  │ - Public Access: Allowed                                       │ │
│  │ - Stripe Mode: Test                                            │ │
│  │ - Retention: 30 days                                           │ │
│  │ - Replication: LRS                                             │ │
│  │ - Max Instances: 10                                            │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                            Test                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ - VNet Integration: Enabled                                    │ │
│  │ - Public Access: Restricted                                    │ │
│  │ - Stripe Mode: Test                                            │ │
│  │ - Retention: 60 days                                           │ │
│  │ - Replication: GRS                                             │ │
│  │ - Max Instances: 50                                            │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          Production                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ - VNet Integration: Enabled (Required)                         │ │
│  │ - Public Access: Denied (Whitelist only)                       │ │
│  │ - Stripe Mode: Live                                            │ │
│  │ - Retention: 90 days                                           │ │
│  │ - Replication: GRS                                             │ │
│  │ - Max Instances: 100                                           │ │
│  │ - Key Vault: Purge Protection Enabled                         │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Resource Naming Convention

All resources follow Azure naming best practices:

```
Resource Type         │ Naming Pattern                        │ Example
─────────────────────┼───────────────────────────────────────┼─────────────────────────
Resource Group        │ rg-{app}-{env}-{region}              │ rg-payment-gateway-prod-eus
Virtual Network       │ vnet-{app}-{env}                     │ vnet-payment-gateway-prod
Subnet                │ snet-{purpose}                       │ snet-functions
Function App          │ func-{app}-{env}-{random}            │ func-payment-prod-abc123
Storage Account       │ st{app}{env}{random}                 │ stfuncprodabc123
Key Vault             │ kv-{app}-{env}-{random}              │ kv-pay-prod-abc123
App Service Plan      │ plan-func-{env}-{random}             │ plan-func-prod-abc123
Application Insights  │ appi-{app}-{env}-{random}            │ appi-payment-gateway-prod-abc123
Log Analytics         │ law-{app}-{env}-{random}             │ law-payment-gateway-prod-abc123
```

## Data Flow

### Payment Processing

1. **Client Request** → Function App receives payment request
2. **Authentication** → Function validates request (function key)
3. **Secret Retrieval** → Managed Identity retrieves Stripe API key from Key Vault
4. **Payment Processing** → Function calls Stripe API to create payment intent
5. **Response** → Success/failure returned to client
6. **Logging** → Transaction logged to Application Insights

### Webhook Processing

1. **Stripe Webhook** → Stripe sends event notification
2. **Signature Verification** → Function validates webhook signature using secret from Key Vault
3. **Event Processing** → Function processes payment confirmation/failure
4. **Business Logic** → Update order status, send notifications, etc.
5. **Acknowledgment** → HTTP 200 returned to Stripe

## Network Topology

```
Virtual Network: 10.0.0.0/16 (Production)
├── Function Subnet: 10.0.1.0/24
│   ├── Delegation: Microsoft.Web/serverFarms
│   └── Service Endpoints: Microsoft.KeyVault, Microsoft.Storage
│
Virtual Network: 10.1.0.0/16 (Development)
└── Function Subnet: 10.1.1.0/24
    ├── Delegation: Microsoft.Web/serverFarms
    └── Service Endpoints: None (Public access)

Virtual Network: 10.2.0.0/16 (Test)
└── Function Subnet: 10.2.1.0/24
    ├── Delegation: Microsoft.Web/serverFarms
    └── Service Endpoints: Microsoft.KeyVault
```

## Scaling and Performance

### Flex Consumption Plan Characteristics

- **Instance Memory**: 2048 MB (dev/test), 4096 MB (prod)
- **Max Instances**: 10 (dev), 50 (test), 100 (prod)
- **Cold Start**: ~2-3 seconds (Python)
- **Scaling**: Event-driven, automatic
- **Concurrent Executions**: Per-instance HTTP concurrency

### Performance Targets

| Environment | Response Time (p95) | Availability | Throughput |
|-------------|-------------------|--------------|------------|
| Dev         | < 5s              | 95%          | 10 req/s   |
| Test        | < 3s              | 99%          | 50 req/s   |
| Prod        | < 2s              | 99.9%        | 500 req/s  |

## Cost Estimation

### Monthly Cost Breakdown (Production)

| Resource                 | Estimated Cost |
|-------------------------|----------------|
| Function App (Flex)     | $50-200        |
| Storage Account (GRS)   | $20-40         |
| Key Vault               | $5-10          |
| Application Insights    | $30-100        |
| Log Analytics           | $50-150        |
| VNet                    | $5             |
| **Total**               | **$160-505/mo**|

*Costs vary based on actual usage and transaction volume*

## Disaster Recovery

### Backup Strategy

- **Function Code**: Stored in Git repository
- **Infrastructure**: Terraform state (backend storage)
- **Secrets**: Key Vault soft delete (7-90 days retention)
- **Logs**: Application Insights (30-90 days retention)

### Recovery Time Objectives

- **RTO**: < 1 hour (redeploy from Terraform)
- **RPO**: Near zero (stateless function, no data loss)

### Failover Process

1. Detect outage via monitoring alerts
2. Verify primary region is unavailable
3. Deploy to secondary region using Terraform
4. Update DNS/Traffic Manager
5. Validate functionality
6. Communicate to stakeholders

---

**Document Version**: 1.0  
**Last Updated**: 2024-11-12  
**Maintained By**: Platform Engineering Team
