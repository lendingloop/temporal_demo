# Temporal Payment Processing Demo - Example API Calls

This document contains example curl commands to interact with the payment processing system. These examples demonstrate various scenarios including happy path, compliance failures, and recovery.

## Prerequisites

- Ensure all services are running using `./start_all.sh`
- Temporal server is running using `temporal server start-dev`
- You can access the Temporal web UI at http://localhost:8233

## Basic Health Checks

Test that all services are up and running:

```bash
# Check FX Service
curl http://localhost:3001/health

# Check Compliance API 
curl http://localhost:3002/api/health

# Check Payment API
curl http://localhost:3000/health
```

## Happy Path Scenario

This example demonstrates a successful payment processing flow.

1. **Create a new payment**:

```bash
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Example Business",
      "email": "business@example.com"
    },
    "merchant": {
      "name": "Example Merchant",
      "country": "US"
    }
  }'
```

Response will include a `workflow_id` that you can use to check payment status.

2. **Check payment status**:

```bash
curl http://localhost:3000/api/payments/payment-<WORKFLOW_ID>
```

Replace `<WORKFLOW_ID>` with the actual workflow ID from the previous response.

## Compliance Failure Scenario

This example demonstrates how the system handles a payment that fails compliance checks.

```bash
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 12000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "High Risk Corp",
      "email": "high.risk@example.com"
    },
    "merchant": {
      "name": "Suspicious Merchant",
      "country": "US"
    }
  }'
```

The workflow should fail due to compliance checks, and you'll see automatic compensation actions in the Temporal UI.

## Sanctions Failure Scenario

This example shows how the system handles payments to sanctioned countries:

```bash
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 500.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Example Business",
      "email": "business@example.com"
    },
    "merchant": {
      "name": "Foreign Merchant",
      "country": "XZ"
    }
  }'
```

The workflow should fail due to the sanctioned country code (XZ), and automatic compensation should occur.

## Service Failure & Recovery Scenario

To demonstrate Temporal's durability and service recovery:

1. Start a new payment processing:

```bash
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 3000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Resilience Test",
      "email": "test@example.com"
    },
    "merchant": {
      "name": "Recovery Merchant",
      "country": "US"
    }
  }'
```

2. While the payment is processing (you can check in the Temporal UI), kill one of the services:

```bash
# Find and kill the Compliance API service
ps aux | grep compliance_api
kill -9 <PID>
```

3. After verifying the workflow is paused due to activity failure, restart the service:

```bash
cd compliance_api
./start.sh
```

4. Watch in the Temporal UI as processing automatically resumes and completes.

## Testing Direct Service APIs

You can also test each service directly:

### FX Service

```bash
# Get current exchange rate
curl http://localhost:3001/api/rates/CAD/USD

# Lock in an exchange rate
curl -X POST http://localhost:3001/api/lock_rate \
  -H "Content-Type: application/json" \
  -d '{"from": "CAD", "to": "USD"}'
```

### Compliance API

```bash
# Run fraud check
curl -X POST http://localhost:3002/api/checks/fraud \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Example Business",
      "email": "business@example.com"
    },
    "merchant": {
      "name": "Example Merchant",
      "country": "US"
    }
  }'
```

## Monitoring with Temporal UI

While running these examples, watch the Temporal UI (http://localhost:8233) to observe:

1. Workflow execution and progress
2. Activity details and timing
3. Workflow state and variables
4. Compensation actions when failures occur

This visibility is one of the key benefits of using Temporal for payment processing!
