# Slide 3: The Technical Complexity

## Visual Layout:
```
WHAT SOUNDS SIMPLE VS WHAT'S ACTUALLY REQUIRED

Sounds Simple:
"Process a $5,000 USD payment for a Canadian business"

Actually Required:
✓ Validate customer credentials and transaction limits
✓ Get real-time CAD/USD exchange rate and lock it
✓ Pre-authorize $6,750 USD (at current rate)
✓ Run fraud detection (Canadian + US frameworks)
✓ Perform AML compliance checks (multiple jurisdictions)
✓ Execute sanctions screening (international lists)
✓ Capture payment from USD account
✓ Update multi-currency ledger systems
✓ Reconcile with Canadian banking infrastructure
✓ Send notifications (customer + merchant + internal)
✓ Update accounting across multiple currencies
✓ Handle failures at ANY step without losing money

Each step can fail. Each failure can cost money. Each retry must be safe.
```

## Speaking Points (2 minutes):

**The Complexity:**
> "Here's what I learned when I joined Loop Card: multi-currency payments are deceptively complex."

> "What sounds like 'process a payment' actually involves 10+ discrete steps across 6-8 different services, each with their own failure modes."

**Real Stakes:**
> "This isn't a typical CRUD app where a failed request means someone has to click refresh. This is distributed systems with other people's money on the line."

> "Every transaction touches:
> - Payment gateways in multiple countries
> - Real-time foreign exchange systems
> - Fraud detection services
> - Multiple compliance frameworks
> - Banking infrastructure across borders
> - Accounting systems with multi-currency requirements"

**What Can Go Wrong:**
> "And here's the thing: each step can fail independently:
> - FX service timeout during rate lookup
> - Payment gateway pre-auth succeeds but capture fails
> - Compliance check takes too long and times out
> - Network partition between services
> - External API rate limits
> - Database deadlocks during concurrent updates"

**The Challenge:**
> "The fundamental challenge is coordination. How do you ensure that either ALL steps succeed, or ALL steps are safely rolled back? How do you debug failures across 8 different services? How do you retry safely without double-charging customers?"

> "Traditional job queues weren't designed for this level of coordination and state management."

## Speaker Notes:
- Use concrete example ($5,000 USD payment)
- Break down the complexity step by step
- Emphasize the stakes (real money, real businesses)
- Show how each step can fail independently
- Build the case for why traditional solutions aren't enough
- Set up the need for workflow orchestration

## Timing: 2 minutes