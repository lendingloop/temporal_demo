# Slide 7: Our Payment Workflow - Real Implementation

## Visual Layout:
```
LOOP CARD MULTI-CURRENCY PAYMENT WORKFLOW

Input: $5,000 CAD → USD payment
Services: 6 microservices coordinated by Temporal
Output: Reliable payment with complete audit trail

This is the actual production code running our payments.
```

## Speaking Points (3 minutes):

**The Real Workflow:**
> "Let me show you our actual payment workflow. This is the code running in production right now:"

```ruby
class LoopMultiCurrencyPaymentWorkflow < Temporal::Workflow
  def execute(payment_data)
    @state = PaymentState.new(payment_data)
    @compensations = []
    
    begin
      # Execute payment pipeline
      validate_transaction(payment_data)
      get_exchange_rate(payment_data)
      authorize_payment(payment_data)
      run_compliance_checks(payment_data)
      capture_payment(payment_data)
      update_ledgers(payment_data)
      send_notifications(payment_data)
      
      payment_successful(@state)
      
    rescue => error
      execute_compensations
      payment_failed(error, @state)
    end
  end
```

**Key Workflow Steps:**
```ruby
def validate_transaction(payment_data)
  result = ValidateTransactionActivity.execute(payment_data)
  @state.validation = result
  
  raise PaymentDeclinedError.new(result.reason) unless result.approved?
end

def get_exchange_rate(payment_data)
  # Lock in FX rate for entire workflow - prevents arbitrage bugs
  rate = GetExchangeRateActivity.execute_with_retry(
    from: payment_data[:charge_currency],    # CAD
    to: payment_data[:settlement_currency],  # USD
    retry_policy: fx_retry_policy
  )
  
  @state.exchange_rate = rate.rate
  @state.charge_amount = payment_data[:amount]  # $5,000 CAD
  @state.settlement_amount = payment_data[:amount] * rate.rate  # $6,750 USD
end

def authorize_payment(payment_data)
  auth_result = AuthorizePaymentActivity.execute_with_retry(
    amount: @state.settlement_amount,  # $6,750 USD
    currency: payment_data[:settlement_currency],
    card_token: payment_data[:card_token],
    retry_policy: auth_retry_policy
  )
  
  # Track for compensation if later steps fail
  @compensations << {
    type: :release_authorization,
    auth_id: auth_result.authorization_id
  }
  
  @state.authorization = auth_result
end
```

**What Makes This Different:**
> "Notice what's happening here that wasn't possible with Sidekiq:

> **State Persistence:** The `@state` object is automatically persisted. If the workflow crashes and resumes, all state is intact.

> **Compensation Tracking:** We build a stack of compensations. If step 6 fails, steps 1-5 are automatically undone.

> **Exchange Rate Consistency:** We lock the FX rate at the beginning. Retries don't cause currency arbitrage bugs.

> **Smart Retries:** Each activity has its own retry policy. Network timeouts retry, invalid cards don't."

**Parallel Compliance:**
```ruby
def run_compliance_checks(payment_data)
  # Run multiple checks in parallel - 90 seconds becomes 45 seconds
  fraud_future = FraudCheckActivity.execute_async(payment_data)
  aml_future = AMLCheckActivity.execute_async(payment_data)
  sanctions_future = SanctionsCheckActivity.execute_async(payment_data)
  
  # Wait with appropriate timeouts
  fraud_result = await(fraud_future, timeout: 15.seconds)
  aml_result = await(aml_future, timeout: 30.seconds)
  sanctions_result = await(sanctions_future, timeout: 45.seconds)
  
  if fraud_result.flagged? || aml_result.flagged? || sanctions_result.flagged?
    raise ComplianceFailureError.new("Transaction flagged")
  end
end
```

**The Key Insight:**
> "This workflow eliminates partial failures. Either the entire payment succeeds, or it fails cleanly with automatic compensation. No more money stuck in limbo."

## Speaker Notes:
- Emphasize this is real production code
- Walk through each step methodically
- Highlight specific improvements over Sidekiq approach
- Use concrete examples ($5,000 CAD → $6,750 USD)
- Show parallel execution benefits
- Connect technical features to business value
- Build excitement for the live demo

## Timing: 3 minutes