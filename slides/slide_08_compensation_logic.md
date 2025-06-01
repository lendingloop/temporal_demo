# Slide 8: Compensation Logic - Automatic Rollbacks

## Visual Layout:
```
AUTOMATIC COMPENSATION: UNDOING COMPLETED WORK

The Problem:
Payment authorized → Compliance fails → Money stuck in pre-auth

The Solution:
Temporal automatically undoes completed steps when later steps fail

Compensation Stack (LIFO):
3. [Refund Payment]     ← If capture succeeded
2. [Release Auth]       ← If authorization succeeded  
1. [Unlock FX Rate]     ← If rate was locked

Each step knows how to undo itself safely.
```

## Speaking Points (2 minutes):

**The Compensation Pattern:**
> "This is the game-changer for financial workflows: automatic compensation."

> "In our old system, if step 5 failed after steps 1-4 succeeded, we'd have partial state everywhere. Money tied up, ledgers inconsistent, manual cleanup required."

**How It Works:**
```ruby
def authorize_payment(payment_data)
  auth_result = AuthorizePaymentActivity.execute(...)
  
  # Record how to undo this step
  @compensations << {
    type: :release_authorization,
    auth_id: auth_result.authorization_id,
    amount: @state.settlement_amount
  }
  
  @state.authorization = auth_result
end

def capture_payment(payment_data)
  capture_result = CapturePaymentActivity.execute(...)
  
  # Upgrade compensation: now we need refunds, not auth releases
  @compensations.pop  # Remove release_authorization
  @compensations << {
    type: :refund_payment,
    transaction_id: capture_result.transaction_id,
    amount: @state.settlement_amount
  }
  
  @state.capture = capture_result
end
```

**Executing Compensations:**
```ruby
def execute_compensations
  # Execute compensations in reverse order (LIFO stack)
  while compensation = @compensations.pop
    case compensation[:type]
    when :release_authorization
      ReleaseAuthorizationActivity.execute(
        auth_id: compensation[:auth_id],
        amount: compensation[:amount]
      )
      
    when :refund_payment
      RefundPaymentActivity.execute(
        transaction_id: compensation[:transaction_id],
        amount: compensation[:amount]
      )
    end
  end
end
```

**Why This Matters:**
> "Notice how the compensation logic evolves:

> **Before capture:** If we fail, release the pre-authorization. Customer never gets charged.

> **After capture:** If we fail, issue a full refund. Customer gets charged but money comes back.

> **The system knows the difference** and handles it automatically."

**Real Impact:**
> "This eliminated our biggest source of operational overhead:
> - No more manual cleanup of stuck payments
> - No more emergency calls about money in limbo  
> - No more weekend debugging sessions
> - Complete audit trail of what was undone and why"

**Business Value:**
> "Before: Partial failures cost us $47k per quarter plus engineering time.
> After: Automatic compensation means zero stuck payments, zero manual cleanup."

## Speaker Notes:
- Focus on the business problem this solves
- Show how compensation logic evolves during workflow execution
- Use concrete examples (auth vs refund)
- Emphasize the automation - no manual intervention needed
- Connect to real operational benefits
- Highlight the audit trail aspect

## Timing: 2 minutes