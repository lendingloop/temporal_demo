# Slide 5: Finding Temporal - The Research Process

## Visual Layout:
```
THE SEARCH FOR A WORKFLOW ORCHESTRATION SOLUTION

Requirements:
✓ Reliable coordination across multiple services
✓ Automatic compensation when failures occur
✓ Complete visibility into workflow state
✓ Strong consistency guarantees
✓ Production-ready Ruby support
✓ Reasonable operational complexity

Options Evaluated:
├── AWS Step Functions (vendor lock-in, painful local dev)
├── Apache Airflow (batch-oriented, not real-time)
├── Cadence (operational complexity too high)
├── Custom solution (6+ months to build, ongoing maintenance)
└── Temporal.io ✓ (met all requirements)
```

## Speaking Points (90 seconds):

**The Mandate:**
> "After Q4's $47k loss incident, our CTO gave us a clear mandate: find a solution that guarantees workflow reliability. We had 3 weeks to research and recommend."

**What We Evaluated:**
> "We looked at several options:

> **AWS Step Functions:** Great if you're all-in on AWS, but we're multi-cloud and local development was painful.

> **Apache Airflow:** Built for batch ETL workflows, not real-time payment processing.

> **Cadence:** The predecessor to Temporal, but operational complexity was too high for our team size.

> **Custom Solution:** We sketched out building our own orchestrator. Would take 6+ months and we'd be maintaining complex distributed systems code instead of focusing on payments."

**Why Temporal Won:**
> "Temporal kept coming up in our research. Three things sold us:

> **1. Production-ready Ruby SDK.** We could start building immediately without rewriting existing services.

> **2. Time-travel debugging.** When workflows fail, you can see exactly what happened at every step. No more log archaeology.

> **3. Automatic compensation.** Temporal can automatically undo completed steps when later steps fail. This directly solved our partial failure problem."

**Social Proof:**
> "Plus, companies like Uber, Netflix, and Stripe use Temporal for similar workflows. If it's good enough for Stripe's payment processing..."

**The Proof of Concept:**
> "We ran a 2-week POC migrating our simplest payment flow. Results were immediate:
> - Zero partial failures during testing
> - Complete workflow visibility  
> - Developers actually enjoyed working with it
> - Easy local development and testing"

**The Decision:**
> "Team was sold. We got budget approval to migrate our entire payment system to Temporal."

## Speaker Notes:
- Show this was a deliberate, researched decision
- Acknowledge alternatives and explain why they didn't fit
- Focus on specific requirements that mattered to the business
- Highlight Ruby support for this audience
- Use social proof (other companies using it)
- Show validation through proof of concept
- Connect to team satisfaction and developer experience

## Timing: 90 seconds