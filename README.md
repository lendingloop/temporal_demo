# Ruby Payments Temporal Demo

This project demonstrates how to build a multi-currency payment processing system using Temporal.io with Ruby. It's inspired by the real-world payment processing system implemented at Loop Card for handling complex, multi-step payment transactions with strong reliability guarantees.

## Architecture

The system consists of the following components:

1. **Payment API (Rails)** - Port 3000
   - REST API for initiating payments and checking status
   - Communicates with Temporal to start workflows

2. **FX Service (Sinatra)** - Port 3001  
   - Provides foreign exchange rates
   - Locks in exchange rates for transactions

3. **Compliance API (Grape)** - Port 3002
   - Handles fraud detection
   - Anti-money laundering (AML) checks
   - Sanctions screening

4. **Temporal Worker**
   - Implements the payment workflow and activities
   - Manages the entire payment lifecycle
   - Handles compensation logic for failures

5. **Temporal Server** (Local development via CLI)
   - Provides the workflow execution engine
   - Manages workflow state
   - Provides monitoring and visibility

## Payment Workflow

The payment workflow handles a multi-step payment process:

1. Transaction validation
2. Exchange rate locking
3. Payment authorization
4. Parallel compliance checks (fraud, AML, sanctions)
5. Payment capture
6. Ledger updates
7. Notifications

Each step is implemented as a Temporal activity with:
- Proper error handling
- Automatic retries
- Compensation logic for rollback

## Key Features Demonstrated

- **Durable Execution**: Transactions maintain state even if services fail
- **Automatic Compensation**: Handles failures with proper cleanup
- **Parallel Processing**: Runs compliance checks in parallel for efficiency
- **Service Independence**: Services can fail/restart without losing transaction state

## Getting Started

See [DEMO.md](DEMO.md) for detailed setup instructions and demo scenarios.

## Technology Stack

- Ruby 3.0+
- Rails (Payment API)
- Sinatra (FX Service)
- Grape (Compliance API)
- Temporal Ruby SDK
- Puma web server

## Demo Scenarios

The demo supports several key scenarios:

1. **Happy Path**: Complete successful payment processing
2. **Compliance Failure**: Automatic compensation when compliance checks fail
3. **Service Failure & Recovery**: Demonstrates how Temporal handles service outages with automatic recovery

## License

MIT
