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

The Temporal Web UI will be available at: http://localhost:8233

### 3. Set Up Services

Open separate terminal windows for each service:

#### Terminal 1: FX Service
```bash
cd fx_service
bundle install
bundle exec ruby app.rb -p 3001
```

#### Terminal 2: Compliance API
```bash
cd compliance_api
bundle install
bundle exec puma -p 3002
```

#### Terminal 3: Payment API
```bash
cd payment_api
bundle install
bundle exec rails db:create db:migrate
bundle exec rails s -p 3000
```

#### Terminal 4: Temporal Worker
```bash
cd temporal_worker
bundle install
bundle exec ruby worker.rb
```

## Demo Scenarios

### 1. Verify Services

```bash
# Check FX Service
curl http://localhost:3001/health | jq

# Check Compliance API
curl http://localhost:3002/health | jq

# Check Payment API
curl http://localhost:3000/health | jq
```

### 2. Happy Path

```bash
# Start a new payment
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 3000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Happy Path Corp",
      "email": "happy@example.com"
    },
    "merchant": {
      "name": "Test Merchant",
      "country": "US"
    }
  }' | jq

# Check status (replace with actual workflow_id)
WORKFLOW_ID="payment-123"
curl http://localhost:3000/api/payments/$WORKFLOW_ID | jq
```

### 3. Compliance Failure

```bash
# Start a payment that will fail compliance
curl -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 15000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "High Risk Corp",
      "email": "highrisk@example.com"
    },
    "merchant": {
      "name": "Suspicious Merchant",
      "country": "US"
    }
  }' | jq

# Check status to see failure and compensation
WORKFLOW_ID="payment-124"  # Replace with actual ID
curl http://localhost:3000/api/payments/$WORKFLOW_ID | jq
```

### 4. Service Failure & Recovery

```bash
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
