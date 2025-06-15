# frozen_string_literal: true

# Demo: Temporal Worker
# This is the main entry point for the Temporal worker process.
# It connects to the Temporal server and registers workflows and activities.

require 'temporalio/client'
require 'temporalio/worker'
# Import workflow and activity definitions
require_relative 'app/activities/compliance_activities'
require_relative 'app/activities/fx_activities'
require_relative 'app/activities/payment_activities'
require_relative 'app/workflows/multi_currency_payment_workflow'

def log(level, message)
  puts "[#{Time.now}] #{level.upcase}: #{message}"
end

# Add signal handling for graceful shutdown
shutdown = false
Signal.trap("INT") { shutdown = true }
Signal.trap("TERM") { shutdown = true }

# Start the worker
log(:info, "Starting Temporal worker (#{Process.pid}) - Ruby #{RUBY_VERSION}")

begin
  # Connect to Temporal server
  temporal_address = "#{ENV['TEMPORAL_HOST'] || 'localhost'}:#{ENV['TEMPORAL_PORT'] || '7233'}"
  temporal_namespace = ENV['TEMPORAL_NAMESPACE'] || 'default'
  
  log(:info, "Connecting to Temporal at #{temporal_address}...")
  client = Temporalio::Client.connect(temporal_address, temporal_namespace)
  
  # Define activities
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
    RefundPaymentActivity,
    WaitForManualApprovalActivity
  ]

  # Create worker with task queue
  worker = Temporalio::Worker.new(
    client: client,
    task_queue: 'payment-task-queue',  # MUST match task queue in payment API!
    workflows: [MultiCurrencyPaymentWorkflow],
    activities: activities
  )
  
  # Start worker polling loop
  log(:info, "Starting worker on 'payment-task-queue'...")
  
  worker.run do
    log(:info, "Worker running. Press Ctrl-C to stop.")
    
    # Wait for shutdown signal
    while !shutdown
      sleep 1
    end
    
    log(:info, "Shutting down worker...")
  end
rescue => e
  log(:error, "Worker error: #{e.class} - #{e.message}")
  raise
end
