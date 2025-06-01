# Slide 12: Recovery Demo

## Visual Layout:
```
DEMO 3: SYSTEM RECOVERY

Scenario: Restart compliance service, process new payment
Transaction: $2,500 CAD → USD  
Customer: Legitimate Business Inc
Expected: Normal processing resumes automatically

No special recovery procedures needed - just restart and go
```

## Speaking Points (2 minutes):

**Service Recovery:**
```bash
# Restart the compliance service
docker start compliance-service
echo "🔧 Compliance service restarting..."
sleep 10

# Verify service health
curl -s localhost:3002/health | jq
echo "✅ Compliance service operational"
```

**Testing Recovery:**
```bash
# Process a normal payment to verify everything works
curl -X POST localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 2500.00,
    "charge_currency": "CAD",
    "settlement_currency": "USD",
    "customer": {
      "business_name": "Legitimate Business Inc",
      "email": "accounting@legitbiz.ca"
    },
    "merchant": {
      "name": "Standard Software License",
      "country": "US"
    }
  }'

echo "Recovery workflow: loop-payment-78901-recovery"
```

**Live Commentary:**
> "Watch how the system recovers:

> - ✅ **All services healthy** - no special recovery needed
> - ✅ **Validation:** Customer approved normally
> - ✅ **FX Rate:** New rate locked (CAD/USD: 1.36)
> - ✅ **Authorization:** $3,400 USD pre-authorized
> - ✅ **Compliance:** All three checks pass normally
>   - Fraud: Clear in 6 seconds
>   - AML: Clear in 11 seconds  
>   - Sanctions: Clear in 13 seconds
> - ✅ **Capture:** Payment successful
> - ✅ **Settlement:** Ledgers updated
> - ✅ **Complete:** $3,400 USD processed successfully"

**Side-by-Side Comparison:**
> "Now look at the Temporal UI with both workflows visible:

> **Failed Workflow (left):**
> - Clear failure point identification
> - Automatic compensation execution
> - Complete audit trail preserved
> - Runtime: 47 seconds
> - Customer impact: Zero

> **Recovery Workflow (right):**
> - Normal execution path
> - All services operational  
> - Successful payment processing
> - Runtime: 13.8 seconds
> - Customer charged successfully"

**Key Insights:**
> "This demonstrates:
> - **Failures are events, not emergencies**
> - **No special recovery procedures needed**  
> - **System automatically adapts to service availability**
> - **Complete isolation between workflows**
> - **Audit trail preserved across failures and recoveries**"

**The Developer Experience:**
> "As a developer, this is transformative:
> - Deploy with confidence
> - Services can fail without data loss
> - Complete visibility into what happened
> - No 3am emergency calls
> - Focus on building features, not debugging failures"

## Speaker Notes:
- Show how simple recovery is - just restart the service
- Emphasize no special procedures needed
- Use side-by-side comparison in Temporal UI
- Connect to developer experience and operational benefits
- Highlight the isolation between workflows
- Show confidence in deployment and operations

## Timing: 2 minutes