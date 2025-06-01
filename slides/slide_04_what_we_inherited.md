# Slide 4: What We Inherited - The Rails Monolith

## Visual Layout:
```
THE ORIGINAL SYSTEM: RAILS MONOLITH + SIDEKIQ

Architecture:
┌─────────────────────────────────────┐
│           Rails Application          │
│  ┌─────────────────────────────────┐ │
│  │         Sidekiq Jobs            │ │
│  │                                 │ │
│  │  MultiCurrencyPaymentJob        │ │
│  │  FraudCheckJob                  │ │
│  │  ComplianceJob                  │ │
│  │  NotificationJob                │ │
│  │  LedgerUpdateJob                │ │
│  │                                 │ │
│  └─────────────────────────────────┘ │
└─────────────────────────────────────┘

The Problems:
• Partial failures with no clean recovery
• No visibility into distributed state  
• Complex retry logic that often made things worse
• Debugging nightmares across multiple services
```

## Speaking Points (2 minutes):

**What We Started With:**
> "When I joined Loop Card, we had a Rails monolith coordinating everything through Sidekiq jobs. Now, Sidekiq is great for many use cases, but coordinating financial workflows across multiple services? That's where the limitations become painful."

**The Code That Seemed Reasonable:**
```ruby
class MultiCurrencyPaymentJob < ApplicationJob
  def perform(payment_id)
    payment = Payment.find(payment_id)
    
    # Get exchange rate
    rate = FXService.get_rate(payment.from_currency, payment.to_currency)
    
    # Pre-authorize payment
    auth = PaymentGateway.preauth(payment.amount * rate, payment.card_token)
    
    # Run compliance checks
    FraudCheckJob.perform_now(payment.id)
    ComplianceJob.perform_now(payment.id)
    
    # Capture payment
    result = PaymentGateway.capture(auth.id)
    
    # Update systems
    LedgerUpdateJob.perform_now(payment.id, result.id)
    NotificationJob.perform_later(payment.id)
    
    payment.update!(status: 'completed')
  rescue => e
    payment.update!(status: 'failed', error: e.message)
    PaymentFailureJob.perform_later(payment_id)
  end
end
```

**What Actually Happened:**
> "This looks clean, but in production it was a nightmare:

> **Partial Failures:** What if capture succeeds but ledger update fails? We've charged the customer but our books are wrong.

> **Retry Hell:** Job fails and retries. Now we have a different exchange rate, duplicate fraud checks, confused state everywhere.

> **No Visibility:** Payment failed? Great, check Redis, check the database, check logs from 6 different services. Good luck figuring out where it broke.

> **Lost Money:** We actually lost money to partial failures. Pre-auth succeeded, capture failed, money stuck in limbo for days."

**The Real Numbers:**
> "By Q4 2024:
> - 6% of payments failing partially or completely
> - 3.2 hours average debug time per incident  
> - $47,000 lost per quarter to payment failures
> - 23 emergency after-hours incidents
> - Developers afraid to deploy on Fridays"

**Why We Needed Something Better:**
> "The fundamental issue: we were trying to coordinate stateful workflows across multiple services using a tool designed for stateless background jobs."

## Speaker Notes:
- Show realistic code that looks reasonable but has problems
- Be specific about what goes wrong in practice
- Use real numbers to show business impact
- Don't bash Sidekiq - acknowledge it's good for other use cases
- Build the case for workflow orchestration
- Connect technical problems to business consequences

## Timing: 2 minutes