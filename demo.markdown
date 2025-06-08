# Temporal Ruby Payment Workflow Demo Guide

## Demo Setup

1. Ensure all services are running:
   ```
   docker-compose up
   ```

2. Open these tabs in your browser:
   * Temporal UI: http://localhost:8233
   * (Optional) API docs if available

## Demo Flow

### 1. Introduction to the Application (2-3 minutes)

* **Explain the multi-service architecture:**
  * Payment API - Customer-facing service
  * Temporal Worker - Orchestrates the payment workflow
  * FX Service - Handles currency exchange
  * Compliance API - Runs fraud and AML checks
  * Temporal - Workflow engine (show UI)

* **Key points about Temporal:**
  * Durable execution - survives crashes/restarts
  * Automatic retries - handles transient failures
  * Visibility - full history of workflow events
  * Human intervention - signals for approvals
  * Timeouts - built-in SLAs

### 2. Code Walkthrough (5-7 minutes)

* **Start with workflow definition:**
  * Open `/temporal_worker/app/workflows/multi_currency_payment_workflow.rb`
  * Show the workflow class definition and signal handlers
  * Highlight how the workflow organizes a complex business process

* **Show the main workflow steps:**
  * Validation
  * Compliance checks
  * Exchange rate lookup
  * High-value payment approval process
  * Payment capture

* **Point out key Temporal patterns:**
  * Activity execution
  * Signal handlers for approvals
  * State management (everything in execute method is durable)
  * Error handling

* **Show the worker registration:**
  * Open `/temporal_worker/worker.rb`
  * Point out task queue configuration (`payment-task-queue`)
  * Explain workflow and activity registration

### 3. Inter-Service Communication (2-3 minutes)

* **Highlight the FX service connectivity:**
  * Open `/temporal_worker/app/activities/fx_activities.rb`
  * Show the Host header fix that enables communication between containers
  * Explain how Docker service names work for networking
  
* **Explain Temporal's retry capabilities:**
  * Show how activity failures are automatically retried
  * Highlight the clean error raising pattern (no complex retry code)

### 4. Demo Execution (5-7 minutes)

* **Run a standard payment flow:**
  ```
  ./test_payment.sh standard
  ```
  * Show the API response with workflow ID
  * Find the workflow in the Temporal UI
  * Walk through the event history showing each step

* **Run a high-value payment flow:**
  ```
  ./test_payment.sh high-value
  ```
  * Show the workflow paused waiting for approval
  * Demonstrate sending a signal through the Temporal UI:
    1. Find the workflow in the UI
    2. Click "Signal" button
    3. Select "approve_payment" signal
    4. Submit (no parameters needed)
  * Watch the workflow complete

### 5. Resilience Demo (if time permits)

* **Demonstrate durability:**
  * Start a high-value payment
  * Kill and restart the temporal worker during execution
  * Show the workflow continues where it left off
  * Point out how no data is lost

### 6. Key Takeaways

* **Highlight business benefits:**
  * Reliability - workflows always complete correctly
  * Visibility - every action is recorded
  * Maintainability - workflow code is clear and focused
  * Flexibility - easy to add steps or change logic

* **Technical advantages:**
  * No custom persistence code needed
  * Automatic retries handled by framework
  * Clean separation of orchestration and implementation
  * Human intervention without custom queuing

## Troubleshooting Guide

If workflows aren't appearing in the Temporal UI:

1. Verify task queue names match exactly between:
   * Worker registration (in `worker.rb`)
   * Workflow execution (in payment API)

2. Check namespace configuration:
   * Both worker and UI should use same namespace (default)

3. Ensure worker is running and connected:
   * Check logs for successful registration
   * Look for "Worker is now running and polling" message

4. Verify the critical Host header fix:
   * FX activities include `req.headers['Host'] = 'localhost'`
   * This bypasses Sinatra's host protection

## Q&A Topics to Prepare For

* Comparison with other workflow engines
* Production deployment considerations
* Performance and scaling
* Integration with existing systems
* Error handling strategies
* Long-running workflow patterns
