# Slide 9: Live Demo Setup

## Visual Layout:
```
LIVE DEMONSTRATION: TEMPORAL WORKFLOWS IN ACTION

What we'll show:
1. Happy path: Normal $3,000 CAD → USD payment
2. Failure scenario: Service dies mid-workflow
3. Automatic compensation: System cleans up automatically
4. Recovery: Service comes back, new payments work

Environment:
✓ Local Temporal server running
✓ Loop Card payment services (mocked for demo)
✓ Temporal Web UI for visibility
✓ Real workflow code (same as production)

This is not a toy demo - same architecture we use in production.
```

## Speaking Points (90 seconds):

**Demo Overview:**
> "Now I want to show you these workflows in action. This isn't a contrived demo with fake examples - this is our actual payment processing architecture running locally."

**What You'll See:**
> "Three scenarios:

> **1. Happy Path:** A normal $3,000 CAD → USD payment processing successfully. You'll see each step execute in real-time.

> **2. Failure Scenario:** I'll kill our compliance service mid-workflow. Watch what happens to the money that's already been pre-authorized.

> **3. Recovery:** Restart the service and process a new payment. Everything just works."

**The Setup:**
> "I'm running:
> - Local Temporal server (same as we use in production)
> - Our payment microservices (mocked for demo safety)
> - Temporal Web UI so you can see workflow execution
> - The exact same Ruby code that runs our production payments"

**Why This Matters:**
> "This demo shows the real developer experience of working with Temporal:
> - Complete visibility into workflow state
> - Time-travel debugging when things fail
> - Automatic recovery and compensation
> - No manual intervention required"

**Safety Note:**
> "Don't worry - we're not processing real payments here. But the architecture, the code, and the failure scenarios are identical to what we handle in production."

**What to Watch For:**
> "Pay attention to:
> - How each step shows up in the Temporal UI
> - What happens when the compliance service dies
> - How the compensation logic kicks in automatically
> - The complete audit trail of every action"

## Speaker Notes:
- Set expectations for what they'll see
- Emphasize this is real architecture, not toy demo
- Mention safety (no real payments)
- Guide them on what to pay attention to
- Build anticipation for seeing the concepts in action
- Mention the debugging/visibility aspects

## Timing: 90 seconds