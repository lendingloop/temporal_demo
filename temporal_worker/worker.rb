# frozen_string_literal: true

# DEMO: TEMPORAL WORKER ENTRY POINT
# This is the main entry point for the Temporal worker process.
# It demonstrates the key components of a Temporal worker application:
#
# 1. Client connection to Temporal server
# 2. Worker registration with activities and workflows
# 3. Task queue configuration
# 4. Worker lifecycle management

require 'temporalio/client'
require 'temporalio/worker'
require 'logger'

# DEMO: IMPORT ALL WORKFLOW AND ACTIVITY DEFINITIONS
# Any workflow or activity that needs to be executed must be registered with the worker
require_relative 'app/activities/compliance_activities'
require_relative 'app/activities/fx_activities'
require_relative 'app/activities/payment_activities'
require_relative 'app/workflows/multi_currency_payment_workflow'

# Create and configure loggers
log_formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: #{msg}\n"
end

# Create global loggers so they can be accessed from the log method
$stdout_logger = Logger.new($stdout)
$stdout_logger.level = Logger::DEBUG
$stdout_logger.formatter = log_formatter

# File logger
log_file_path = File.join(File.dirname(__FILE__), 'logs', 'temporal_worker_detailed.log')
$file_logger = Logger.new(log_file_path, 0, 10485760) # Use 10MB max file size
$file_logger.level = Logger::DEBUG
$file_logger.formatter = log_formatter

# Create a custom logger that logs to both outputs
def log(level, message)
  $stdout_logger.send(level, message)
  $file_logger.send(level, message)
end

# Set up logging for the worker
# Note: Temporal SDK v0.4.0 doesn't support direct logger assignment

# Add signal handling for graceful shutdown
shutdown = false
Signal.trap("INT") do
  log(:info, "Received shutdown signal, stopping worker gracefully...")
  shutdown = true
end
Signal.trap("TERM") do
  log(:info, "Received termination signal, stopping worker gracefully...")
  shutdown = true
end

# The actual worker starts here
log(:info, "Starting Temporal worker...")
log(:info, "Worker process ID: #{Process.pid}")
log(:info, "Ruby version: #{RUBY_VERSION}")
log(:info, "SDK version: #{Temporalio::VERSION}")

begin
  # DEMO: TEMPORAL SERVER CONNECTION
  # This establishes a connection to the Temporal server
  # In our Docker setup, this connects to the 'temporal' service
  temporal_host = ENV['TEMPORAL_HOST'] || 'localhost'
  temporal_port = ENV['TEMPORAL_PORT'] || '7233'
  temporal_address = "#{temporal_host}:#{temporal_port}"
  temporal_namespace = ENV['TEMPORAL_NAMESPACE'] || 'default'
  
  log(:info, "Connecting to Temporal server at #{temporal_address}...")
  client = Temporalio::Client.connect(temporal_address, temporal_namespace)
  log(:info, "Connected to Temporal server successfully!")
  log(:info, "Client namespace: #{client.namespace}")
  # Note: connected? method doesn't exist in Temporalio::Client in v0.4.0
  log(:info, "Client successfully connected to namespace: #{client.namespace}")

  # DEMO: WORKFLOW & ACTIVITY REGISTRATION
  # This section shows how to register workflows and activities with the Temporal worker
  log(:info, "Starting payment worker on task queue 'payment-task-queue'")
  log(:info, "Press Ctrl-C to stop the worker")

  # DEMO: WORKFLOW REGISTRATION
  # The workflow must be registered with the worker to be processed
  # This is MultiCurrencyPaymentWorkflow from app/workflows/multi_currency_payment_workflow.rb
  log(:info, "Registering workflow: MultiCurrencyPaymentWorkflow")
  
  # DEMO: ACTIVITY REGISTRATION
  # All activities must be registered with the worker to be executed
  # These correspond to the activity classes in the app/activities/ directory
  activities = [
    # Compliance activities - handle fraud and compliance checks
    RunFraudCheckActivity,
    RunAmlCheckActivity,
    RunSanctionsCheckActivity,
    
    # FX activities - currency exchange operations
    # These contain our critical Host header fix for inter-container communication
    GetExchangeRateActivity,
    
    # Payment activities - handle the actual payment processing
    ValidateTransactionActivity,
    AuthorizePaymentActivity,
    CapturePaymentActivity,
    ReleaseAuthorizationActivity,
    UpdateLedgersActivity,
    SendNotificationsActivity,
    RefundPaymentActivity,
    WaitForManualApprovalActivity
  ]
  
  # Log each activity being registered
  activities.each do |activity|
    log(:info, "Registering activity: #{activity}")
  end

  # DEMO: TASK QUEUE CONFIGURATION - CRITICAL FOR UI VISIBILITY!
  # The task queue name MUST match exactly between worker and client
  # If workflows aren't visible in the UI, check this configuration!
  # In our case, 'payment-task-queue' is used by both worker and payment API
  worker = Temporalio::Worker.new(
    client: client,
    task_queue: 'payment-task-queue',  # THIS MUST MATCH THE TASK QUEUE IN PAYMENT API!
    workflows: [MultiCurrencyPaymentWorkflow],
    activities: activities
  )
  
  log(:info, "Worker created successfully with #{activities.size} activities")
  
  # DEMO: WORKER POLLING LOOP
  # This starts the worker polling for tasks on the specified task queue
  # The worker will continuously poll for workflow and activity tasks
  log(:info, "Starting worker run loop...")
  worker.run do |running_worker|
    # This block will be called once the worker is running
    log(:info, "Worker is now running and polling for tasks on 'payment-task-queue'")
    
    # DEMO: WORKER LIFECYCLE
    # The worker will continue running until it receives a shutdown signal
    # This allows for graceful shutdown when Docker stops the container
    while !shutdown
      sleep 1
    end
    
    # DEMO: GRACEFUL SHUTDOWN
    # When shutdown is triggered, the worker will finish its current tasks
    # This prevents workflow tasks from being abandoned midway
    log(:info, "Graceful shutdown initiated, worker will stop after current tasks complete")
  end
  
  log(:info, "Worker has stopped")
rescue => e
  # DEMO: ERROR HANDLING
  # If the worker encounters an error, we log it for troubleshooting
  # In a production system, you might send this to a monitoring service
  log(:error, "Worker error: #{e.class} - #{e.message}")
  log(:error, "Backtrace: #{e.backtrace.join('\n')}")
  raise
end

log(:info, "Worker process completed")
