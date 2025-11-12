# Security & Compliance Documentation

## Payment Gateway Security Architecture

This document outlines the security measures, compliance considerations, and best practices implemented in the Azure Function App Payment Gateway solution.

## Table of Contents

1. [Security Architecture](#security-architecture)
2. [Data Protection](#data-protection)
3. [Network Security](#network-security)
4. [Identity and Access Management](#identity-and-access-management)
5. [Compliance](#compliance)
6. [Security Monitoring](#security-monitoring)
7. [Incident Response](#incident-response)

## Security Architecture

### Defense in Depth

This solution implements multiple layers of security controls:

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Network Security (VNet, NSG, Private EP)  │
├─────────────────────────────────────────────────────┤
│ Layer 2: Application Security (HTTPS, WAF, CORS)   │
├─────────────────────────────────────────────────────┤
│ Layer 3: Data Security (Encryption, Key Vault)     │
├─────────────────────────────────────────────────────┤
│ Layer 4: Identity Security (Managed Identity, RBAC)│
├─────────────────────────────────────────────────────┤
│ Layer 5: Monitoring & Response (App Insights, Logs)│
└─────────────────────────────────────────────────────┘
```

## Data Protection

### Encryption

#### Data at Rest
- ✅ **Storage Account**: AES-256 encryption (Microsoft-managed keys)
- ✅ **Key Vault**: HSM-backed or software-protected keys
- ✅ **Application Insights**: Encrypted storage of telemetry data
- ✅ **Log Analytics**: Encrypted at rest

#### Data in Transit
- ✅ **HTTPS Only**: All traffic enforced over TLS 1.2+
- ✅ **Function App**: HTTPS-only configuration enabled
- ✅ **Storage Account**: HTTPS traffic only enabled
- ✅ **Key Vault**: TLS 1.2 minimum version

### Sensitive Data Handling

#### Credit Card Data
⚠️ **IMPORTANT**: This solution does NOT store or process raw credit card numbers (PANs).

- Credit card processing is delegated to Stripe
- Function App only receives Stripe payment method tokens
- No PCI scope for card data storage

#### Secrets Management
- All API keys stored in Azure Key Vault
- Secrets referenced using Key Vault references in App Settings
- No secrets in source code or environment variables
- Automatic secret rotation capability

```hcl
# Example: Key Vault reference in App Settings
STRIPE_API_KEY = "@Microsoft.KeyVault(SecretUri=${vault_uri}secrets/stripe-api-key/)"
```

## Network Security

### Virtual Network Integration

#### Development Environment
- VNet integration: **Disabled** (for easier testing)
- Public access: **Allowed** (restricted by IP if needed)

#### Test Environment
- VNet integration: **Enabled**
- Private subnet delegation for Function App
- Network Security Groups (NSG) for traffic control

#### Production Environment
- VNet integration: **Enabled** (required)
- Private endpoints for storage and Key Vault
- Network ACLs on storage and Key Vault
- Deny all by default, allow specific IPs only

### CORS Configuration

```typescript
allowed_cors_origins = [
  "https://dashboard.stripe.com",      // Stripe webhooks
  "https://www.example.com",            // Production frontend
  "https://api.example.com"             // Production API
]
```

### Traffic Controls

- **Ingress**: HTTPS only, no HTTP redirection
- **Egress**: VNet route all enabled for prod
- **DDoS**: Azure DDoS Protection (platform level)

## Identity and Access Management

### Managed Identity

The Function App uses **System-Assigned Managed Identity** for:

- ✅ Accessing Key Vault secrets (no credentials needed)
- ✅ Writing to Application Insights
- ✅ Accessing Storage Account
- ✅ Future: Reading from other Azure services

### Role-Based Access Control (RBAC)

```hcl
# Function App → Key Vault
Role: "Key Vault Secrets User"
Scope: Key Vault resource
Principal: Function App Managed Identity

# Developers → Key Vault (manual assignment)
Role: "Key Vault Secrets Officer"
Scope: Key Vault resource
Principal: Azure AD Security Group
```

### Least Privilege Principle

- Function App has read-only access to secrets
- No direct storage account key access in app code
- Service Plan cannot be modified by Function App
- Separate RBAC for each environment

## Compliance

### PCI-DSS Compliance

This solution implements PCI-DSS Level 1 controls:

| Requirement | Implementation |
|-------------|----------------|
| **Req 1**: Firewall | Network Security Groups, VNet integration |
| **Req 2**: No defaults | All passwords in Key Vault, no default credentials |
| **Req 3**: Protect data** | Encryption at rest and in transit, no card storage |
| **Req 4**: Encryption | TLS 1.2+, encrypted storage |
| **Req 5**: Anti-malware | Azure platform protections |
| **Req 6**: Secure code | Code scanning, dependency checks |
| **Req 7**: Access control | RBAC, managed identities |
| **Req 8**: Identity | Azure AD authentication |
| **Req 9**: Physical access | Azure datacenter controls |
| **Req 10**: Logging | Application Insights, Log Analytics |
| **Req 11**: Security testing | Automated scanning in CI/CD |
| **Req 12**: Security policy | This documentation |

**Note**: Using Stripe as payment processor reduces PCI scope significantly as no card data touches your environment.

### GDPR Compliance

Data residency and privacy controls:

- ✅ Data residency: East US (configurable)
- ✅ Data retention: Configurable (30-90 days)
- ✅ Right to erasure: Key Vault soft delete
- ✅ Data encryption: At rest and in transit
- ✅ Access logging: All Key Vault access logged
- ✅ Privacy by design: Minimal data collection

### SOC 2 Type II

Azure services used are SOC 2 compliant:

- Azure Functions: Yes
- Azure Key Vault: Yes
- Azure Storage: Yes
- Application Insights: Yes

## Security Monitoring

### Application Insights

Monitors:
- Request/response times and failure rates
- Dependency calls (Stripe API)
- Custom events for payment processing
- Exception tracking and stack traces

### Log Analytics

Centralized logging:
- Function execution logs
- HTTP request logs
- Key Vault access logs
- Security audit logs

### Alerts

Recommended alerts:

```yaml
Critical Alerts:
  - Payment processing failure rate > 5%
  - Function App unavailable
  - Key Vault access denied
  - Stripe API authentication failure

Warning Alerts:
  - Response time > 2 seconds (p95)
  - Key Vault secret approaching expiration
  - High number of failed payment attempts
```

### Security Scanning

Automated scans in CI/CD:

- **Code scanning**: GitHub Advanced Security
- **Dependency scanning**: Dependabot
- **Infrastructure scanning**: Terraform AI Review Action
- **Secret scanning**: GitHub secret scanning

## Incident Response

### Incident Response Plan

1. **Detection**: Automated alerts trigger incident
2. **Containment**: Disable function app if compromised
3. **Eradication**: Rotate all secrets in Key Vault
4. **Recovery**: Deploy clean version from source control
5. **Lessons Learned**: Update security controls

### Emergency Procedures

#### Suspected API Key Compromise

```bash
# 1. Immediately rotate Stripe API keys
az keyvault secret set --vault-name <vault> \
  --name stripe-api-key --value <new-key>

# 2. Revoke old key in Stripe dashboard
# 3. Review Application Insights for suspicious activity
# 4. Review Stripe dashboard for unauthorized transactions
```

#### Function App Compromise

```bash
# 1. Stop the function app
az functionapp stop --name <func-app> --resource-group <rg>

# 2. Enable network restrictions immediately
az functionapp config access-restriction add \
  --name <func-app> --resource-group <rg> \
  --rule-name "EmergencyDeny" --action Deny --priority 100

# 3. Investigate logs
az monitor app-insights query --app <app-insights> \
  --analytics-query "requests | where timestamp > ago(1h)"

# 4. Deploy clean version
terraform taint azurerm_linux_function_app.main
terraform apply
```

### Security Contacts

- **Security Team**: security@example.com
- **On-Call Engineer**: oncall@example.com
- **Stripe Support**: https://support.stripe.com

## Security Best Practices

### For Developers

1. ✅ Never commit secrets to source control
2. ✅ Always use Key Vault references for API keys
3. ✅ Test with Stripe test mode before production
4. ✅ Implement rate limiting for payment endpoints
5. ✅ Validate all webhook signatures from Stripe
6. ✅ Log security-relevant events
7. ✅ Use least privilege for RBAC assignments

### For Operations

1. ✅ Regularly rotate API keys (monthly)
2. ✅ Review Key Vault access logs weekly
3. ✅ Keep Application Insights retention at 90 days min
4. ✅ Enable soft delete on Key Vault (production)
5. ✅ Use separate Stripe accounts for each environment
6. ✅ Monitor for unusual payment patterns
7. ✅ Perform quarterly security reviews

### For Security Teams

1. ✅ Run quarterly penetration tests
2. ✅ Review RBAC assignments monthly
3. ✅ Audit network security rules quarterly
4. ✅ Update security documentation as changes occur
5. ✅ Conduct incident response drills
6. ✅ Review compliance attestations annually

## Security Checklist

Pre-production deployment checklist:

- [ ] All secrets stored in Key Vault
- [ ] VNet integration enabled (test/prod)
- [ ] HTTPS-only enforced
- [ ] Managed identity configured
- [ ] RBAC assignments reviewed
- [ ] Network ACLs configured
- [ ] Application Insights enabled
- [ ] Alerts configured
- [ ] Log retention set appropriately
- [ ] Backup and disaster recovery tested
- [ ] Security scan passed
- [ ] Compliance review completed
- [ ] Documentation updated
- [ ] Incident response plan in place

## References

- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/baselines/functions-security-baseline)
- [Stripe Security Best Practices](https://stripe.com/docs/security/guide)
- [PCI DSS v4.0 Requirements](https://www.pcisecuritystandards.org/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [GDPR Compliance on Azure](https://docs.microsoft.com/en-us/azure/compliance/offerings/offering-gdpr)

---

**Last Updated**: 2024-11-12  
**Next Review**: 2025-02-12  
**Owner**: Platform Security Team
