# Slide 10: Happy Path Demo

## Visual Layout:
```
DEMO 1: SUCCESSFUL PAYMENT PROCESSING

Transaction: $3,000 CAD → USD
Customer: Toronto Tech Startup  
Merchant: US Software Vendor
Expected: ~15 seconds end-to-end

Real-time execution visible in Temporal Web UI
```

## Speaking Points (2 minutes):

**Starting the Demo:**
> "Let me start a payment and walk you through what happens:"

**Terminal Commands:**
```bash
# Verify all services are running
curl -s localhost:3000/health | jq
curl -s localhost:3001/health | jq  
curl -s localhost:3002/health | jq

# Process a payment
curl -X POST localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 3000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD", 
    "customer": {
      "business_name": "Toronto Tech Startup",
      "email": "cto@torontotech.ca"
    },
    "merchant": {
      "name": "US Software Vendor",
      "country": "US"
    }
  }'
```

**Live Commentary:**
> "Watch the Temporal UI. You can see our workflow starting in real-time:

> - ✅ **Validation Step:** Customer credentials approved (200ms)
> - ✅ **FX Rate Step:** CAD to USD at 1.35 - rate locked for consistency  
> - ✅ **Authorization Step:** $4,050 USD pre-authorized successfully
> - 🔄 **Compliance Steps:** Three checks running in parallel...
>   - Fraud Detection: Clear in 8 seconds
>   - AML Verification: Clear in 12 seconds  
>   - Sanctions Screening: Clear in 14 seconds
> - ✅ **Capture Step:** Payment successfully captured
> - ✅ **Ledger Update:** Multi-currency balances updated
> - ✅ **Notifications:** Customer and merchant notified"

**What Just Happened:**
> "Total execution: 15.3 seconds. Every step visible, traceable, and logged.

> Notice:
> - Complete audit trail of every action
> - Parallel