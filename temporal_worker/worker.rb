require 'temporal/worker'
require 'logger'

# Require workflow and activities
require_relative 'app/workflows/multi_currency_payment_workflow'
require_relative 'app/activities/fx_activities'
require_relative 'app/activities/compliance_activities'
require_relative 'app/activities/payment_activities'

# Configure logger
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Configure Temporal client
Temporal.configure do |config|
  config.host = 'localhost'
  config.port = 7233
  config.namespace = 'default'
  config.logger = logger
  
  # Add task queue retry policies
  config.timeouts = {
    execution: 60,          # Workflow execution timeout (in seconds)
    run: 60 * 5,            # Single workflow run timeout
    task: 10,               # Single workflow task timeout
    schedule_to_close: 120, # Activity schedule to close timeout
    schedule_to_start: 60,  # Activity schedule to start timeout
    start_to_close: 60,     # Activity start to close timeout
    heartbeat: 10           # Activity heartbeat timeout
  }
end

# Start worker process
worker = Temporal::Worker.new
logger.info "Starting Temporal worker"

# Register activities
worker.register_activity(ValidateTransactionActivity)
worker.register_activity(GetExchangeRateActivity)
worker.register_activity(AuthorizePaymentActivity)
worker.register_activity(RunFraudCheckActivity)
worker.register_activity(RunAmlCheckActivity)
worker.register_activity(RunSanctionsCheckActivity)
worker.register_activity(CapturePaymentActivity)
worker.register_activity(ReleaseAuthorizationActivity)
worker.register_activity(RefundPaymentActivity)
worker.register_activity(UpdateLedgersActivity)
worker.register_activity(SendNotificationsActivity)

# Register workflow
worker.register_workflow(MultiCurrencyPaymentWorkflow)

# Start worker process
logger.info "Starting worker. Press Ctrl-C to stop..."
worker.start
