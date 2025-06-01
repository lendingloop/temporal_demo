# Temporal Payment Processing Demo

This demo showcases a distributed payment processing system using Temporal for workflow orchestration. The system consists of multiple microservices that work together to process payments reliably.

## Prerequisites

- Ruby 3.0+
- Bundler
- Temporal CLI (for local Temporal server)
- jq (for JSON parsing in demo scripts)

## Setup

### 1. Install Temporal CLI

```bash
# On macOS
brew install temporal

# On Linux
curl -sSf https://temporal.download/cli.sh | sh
```

### 2. Start Temporal Server

```bash
# Start Temporal in development mode
temporal server start-dev
```

## Demo Script (Matching slides)

### 1. Happy Path: $3,000 CAD → USD payment

Run the test payment script:

```sh
# Make sure all services are running with ./start_all.sh first
ruby test_payment.rb
```

This creates a payment with these details:
- Amount: $3,000.00 CAD
- Settlement: USD
- Reference: DEMO123
- Customer: Loop Card Customer
- Merchant: USA Vendor Inc

Observe in Temporal UI (http://localhost:8233):
- FX rate locking
- Fraud and AML checks
- Payment pre-authorization
- Payment processing
- Successful completion

### 2. Failure Scenario: Service dies mid-workflow

While a payment is processing, kill the compliance service:

```sh
# In terminal 1: Start a payment
ruby test_payment.rb

# In terminal 2: Kill the compliance service IMMEDIATELY after starting the payment
killall -9 puma  # This kills the Compliance API
```

Observe in Temporal UI:
- Workflow fails during compliance checks
- Automatic compensation begins
- FX rate lock is released
- Any pre-authorizations are canceled

### 3. Recovery: Service comes back, new payments work

```sh
# Restart the compliance service
cd compliance_api
./start.sh

# Wait a moment, then try another payment
ruby test_payment.rb
```

Observe that payments now complete successfully again.

## API Details

### Payment API (http://localhost:3000)

**Create Payment:**
```sh
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 3000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Loop Card Customer",
      "email": "customer@example.com"
    },
    "merchant": {
      "name": "USA Vendor Inc",
      "country": "US"
    },
    "reference": "DEMO123"
  }'
```

**Check Payment Status:**
```sh
curl http://localhost:3000/api/payments/payment-DEMO123
# Start a payment
WORKFLOW_ID=$(curl -s -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 5000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Test Recovery",
      "email": "recovery@example.com"
    },
    "merchant": {
      "name": "Test Merchant",
      "country": "US"
    }
  }' | jq -r '.workflow_id')

echo "Workflow ID: $WORKFLOW_ID"

# Kill the FX service (in its terminal window), then:
curl http://localhost:3000/api/payments/$WORKFLOW_ID | jq

# Restart FX service, then check status again
curl http://localhost:3000/api/payments/$WORKFLOW_ID | jq
```

## Monitoring

- **Temporal Web UI**: http://localhost:8233
  - View workflow executions
  - See activity history
  - Debug failed workflows

## Troubleshooting

1. **Temporal Server Not Starting**
   - Make sure ports 7233 (gRPC) and 8233 (UI) are available
   - Run `temporal server start-dev --enable-elasticsearch` if you need advanced search

2. **Worker Not Processing**
   - Check Temporal server is running
   - Verify worker logs for connection errors
   - Ensure all required environment variables are set

3. **Service Connection Issues**
   - Verify all services are running on correct ports
   - Check service logs for connection errors
   - Use `lsof -i :<port>` to check port availability

## Cleanup

```bash
# Stop all services
pkill -f "rails s -p 3000"
pkill -f "ruby app.rb -p 3001"
pkill -f "puma -p 3002"
pkill -f "ruby worker.rb"

# Stop Temporal server
temporal server stop
```

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Payment API    │    │   FX Service    │    │ Compliance API  │
│  (Rails)        │    │  (Sinatra)      │    │  (Grape)        │
│  Port: 3000     │    │  Port: 3001     │    │  Port: 3002     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Temporal Server │
                    │   Port: 7233    │
                    └─────────────────┘
```

## Next Steps

1. Explore the Temporal Web UI
2. Try modifying workflow logic
3. Add new activities
4. Implement additional error handling
5. Add more comprehensive tests
