# Slide 6: Temporal Basics - What Is It?

## Visual Layout:
```
TEMPORAL.IO: WORKFLOW ORCHESTRATION FOR DEVELOPERS

Core Concepts:
┌─────────────────────────────────────────────────────────┐
│  Workflow: Your business logic (Ruby class)            │
│  ├── Activities: Individual tasks (Ruby methods)       │
│  ├── Workers: Processes that execute activities        │
│  └── Temporal Server: Orchestrates everything          │
└─────────────────────────────────────────────────────────┘

Key Benefits:
• Write normal Ruby code that's automatically reliable
• Complete state persistence across failures
• Time-travel debugging with full execution history
• Automatic retries with customizable policies
• Built-in compensation patterns for rollbacks
```

## Speaking Points (90 seconds):

**What Temporal Actually Is:**
> "For those who haven't seen Temporal before, think of it as reliability infrastructure for your business logic."

> "You write Ruby code that looks like normal synchronous business processes, but Temporal makes it resilient to any kind of failure."

**Core Concepts:**
> "Four main concepts:

> **Workflows:** Your business logic, written as Ruby classes. This is where you define the steps of your process.

> **Activities:** Individual tasks that can be retried independently. Each activity is a Ruby method that does one specific thing.

> **Workers:** Processes that execute your activities. These can run in different services, different containers, even different languages.

> **Temporal Server:** The orchestrator that manages state, handles retries, and coordinates everything."

**The Magic:**
> "Here's what makes it special: your workflow code looks like this:"

```ruby
def process_payment(payment_data)
  validate_transaction(payment_data)
  rate = get_exchange_rate(payment_data)
  auth = authorize_payment(payment_data, rate)
  run_compliance_checks(payment_data)
  capture_payment(auth)
  update_ledgers(payment_data)
  send_notifications(payment_data)
end
```

> "That looks like normal Ruby code, right? But Temporal makes it:
> - Survive server crashes and restarts
> - Retry failed steps automatically  
> - Maintain state across weeks or months
> - Provide complete audit trails
> - Handle compensation automatically"

**Key Insight:**
> "You focus on writing business logic. Temporal handles all the distributed systems complexity - state management, retries, failures, coordination."

## Speaker Notes:
- Keep the explanation simple and Ruby-focused
- Use familiar concepts (Ruby classes and methods)
- Show the contrast between simple-looking code and powerful capabilities
- Focus on developer experience benefits
- Don't get too deep into architecture details yet
- Build excitement for seeing it in practice

## Timing: 90 seconds