# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/worker'
require 'logger'

# Require all the activity and workflow definitions
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
log_file_path = File.join(File.dirname(__FILE__), '..', 'logs', 'temporal_worker_detailed.log')
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
  # Connect to the Temporal server
  log(:info, "Connecting to Temporal server at localhost:7233...")
  client = Temporalio::Client.connect("localhost:7233", "default")
  log(:info, "Connected to Temporal server successfully!")
  log(:info, "Client namespace: #{client.namespace}")
  # Note: connected? method doesn't exist in Temporalio::Client in v0.4.0
  log(:info, "Client successfully connected to namespace: #{client.namespace}")

  # Start the worker
  log(:info, "Starting payment worker on task queue 'payment-task-queue'")
  log(:info, "Press Ctrl-C to stop the worker")

  # Log all activities and workflows that will be registered
  log(:info, "Registering workflow: MultiCurrencyPaymentWorkflow")
  
  # Define all activities with detailed logging
  activities = [
    # Compliance activities
    RunFraudCheckActivity,
    RunAmlCheckActivity,
    RunSanctionsCheckActivity,
    
    # FX activities
    GetExchangeRateActivity,
    
    # Payment activities
    ValidateTransactionActivity,
    AuthorizePaymentActivity,
    CapturePaymentActivity,
    ReleaseAuthorizationActivity,
    UpdateLedgersActivity,
    SendNotificationsActivity,
    RefundPaymentActivity
  ]
  
  # Log each activity being registered
  activities.each do |activity|
    log(:info, "Registering activity: #{activity}")
  end

  # Create a worker registering the activities and workflows from the app directory
  worker = Temporalio::Worker.new(
    client: client,
    task_queue: 'payment-task-queue',
    workflows: [MultiCurrencyPaymentWorkflow],
    activities: activities
  )
  
  log(:info, "Worker created successfully with #{activities.size} activities")
  
  # Run the worker
  log(:info, "Starting worker run loop...")
  worker.run do |running_worker|
    # This block will be called once the worker is running
    log(:info, "Worker is now running and polling for tasks on 'payment-task-queue'")
    
    # Check for shutdown signal periodically
    while !shutdown
      sleep 1
    end
    
    log(:info, "Graceful shutdown initiated, worker will stop after current tasks complete")
  end
  
  log(:info, "Worker has stopped")
rescue => e
  log(:error, "Worker error: #{e.class} - #{e.message}")
  log(:error, "Backtrace: #{e.backtrace.join('\n')}")
  raise
end

log(:info, "Worker process completed")
