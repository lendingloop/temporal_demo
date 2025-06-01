# Slide 11: Failure Scenario Demo

## Visual Layout:
```
DEMO 2: WHEN THINGS GO WRONG

Scenario: Compliance service dies mid-workflow
Transaction: $15,000 CAD → USD (high-risk amount)
Timing: Kill service after authorization but before capture
Expected: Automatic compensation kicks in

Watch the money: $20,250 USD will be pre-authorized then automatically released
```

## Speaking Points (3 minutes):

**Setting Up the Failure:**
> "Now let's see what happens when Murphy's Law strikes. I'm going to start a high-value payment that will trigger extra compliance checks, then kill the compliance service."

**Starting the Risky Payment:**
```bash
# High-value transaction that will get extra scrutiny
curl -X POST localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 15000.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "High Value Transaction Corp",
      "email": "cfo@bigspender.ca"
    },
    "merchant": {
      "name": "Expensive Software License",
      "country": "US"
    }
  }'

echo "Workflow started: loop-payment-67890-risky"
echo "Waiting for authorization to complete..."
sleep 8  # Let authorization complete
```

**The Service Kill:**
```bash
# Kill the compliance service mid-workflow
docker stop compliance-service
echo "💥 COMPLIANCE SERVICE IS DOWN!"
echo "💳 We have $20,250 USD pre-authorized..."
echo "🤔 In the old system, this money would be stuck for days..."
```

**Live Commentary:**
> "Watch the Temporal UI carefully:

> - ✅ **Validation:** Approved (high-value but valid)
> - ✅ **FX Rate:** CAD to USD at 1.35 - locked in
> - ✅ **Authorization:** $20,250 USD pre-authorized successfully
> - 🔄 **Compliance:** Three checks starting in parallel...
> - ⏰ **Fraud Check:** Timing out... no response from service
> - ⏰ **AML Check:** Timing out... service unavailable  
> - ⏰ **Sanctions:** Timing out... connection refused
> - 💀 **ComplianceTimeoutError:** All compliance checks failed
> - 🔄 **AUTO-COMPENSATION ACTIVATING!**
> - ✅ **ReleaseAuthorizationActivity:** $20,250 USD released
> - 📊 **Workflow Failed:** Complete audit trail preserved"

**What Just Happened:**
> "In 47 seconds, the system:
> 1. Detected the compliance service failure
> 2. Automatically triggered compensation
> 3. Released the $20,250 pre-authorization  
> 4. Created complete audit trail
> 5. Marked workflow as failed with clear reason"

**The Business Impact:**
> "In our old system:
> - Money would be stuck in pre-auth for days
> - Manual investigation required
> - Customer calling asking about charges
> - Engineers debugging across multiple services
> - Possible revenue loss"

> "With Temporal:
> - Automatic compensation in under a minute
> - Zero manual intervention
> - Complete audit trail
> - Customer never charged
> - System state consistent"

**Failure Analysis:**
```ruby
# Temporal gives us complete failure analysis
workflow = Temporal.describe_workflow('loop-payment-67890-risky')

puts "Status: #{workflow.status}"           # FAILED
puts "Failure: #{workflow.failure_message}" # ComplianceTimeoutError
puts "Compensations: #{workflow.compensations_executed}" # 1
puts "Money at risk: $0"                    # Auto-released
```

## Speaker Notes:
- Build suspense around the high-value transaction
- Time the service kill for maximum dramatic effect
- Provide live commentary during the failure and recovery
- Emphasize the automation - no human intervention
- Compare to what would happen in the old system
- Show the complete audit trail and failure analysis
- Highlight zero money at risk

## Timing: 3 minutes