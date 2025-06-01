# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'temporalio/activity'
require 'logger'
require 'securerandom'

# Set up logger with more detail
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
puts "Starting worker initialization at #{Time.now}"

# Define payment activities
module PaymentActivities
  # Validate transaction activity
  class ValidateTransaction < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      logger.debug("START ValidateTransaction activity with details: #{payment_details}")
      # Simulate validation
      sleep(1)
      result = { valid: true }
      logger.debug("END ValidateTransaction activity with result: #{result}")
      result
    end
  end

  # Get FX rate activity
  class GetFXRate < Temporalio::Activity::Definition
    def execute(source_currency, target_currency)
      logger = Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      logger.debug("START GetFXRate activity from #{source_currency} to #{target_currency}")
      # Simulate API call to FX service
      sleep(1)
      rate = rand(0.8..1.2)
      result = { rate: rate, timestamp: Time.now.to_i }
      logger.debug("END GetFXRate activity with rate: #{rate}")
      result
    end
  end

  # Compliance check activity
  class CheckCompliance < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.info("Checking compliance for payment: #{payment_details}")
      # Simulate compliance check
      sleep(1)
      { approved: true }
    end
  end

  # Process payment activity
  class ProcessPayment < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.info("Processing payment: #{payment_details}")
      # Simulate payment processing
      sleep(2)
      { transaction_id: "txn-#{SecureRandom.hex(10)}" }
    end
  end
end

# Define the payment workflow
class MultiCurrencyPaymentWorkflow < Temporalio::Workflow::Definition
  # Define workflow logger
  def logger
    @logger ||= Temporalio::Workflow.logger
  end
  
  def execute(payment_details)
    # Extract payment details from the array if needed
    payment_details = payment_details[0] if payment_details.is_a?(Array)
    logger.debug("Starting MultiCurrencyPaymentWorkflow for #{payment_details}")
    
    # Step 1: Validate the transaction
    logger.debug("Executing ValidateTransaction activity")
    validation_result = Temporalio::Workflow.execute_activity(
      PaymentActivities::ValidateTransaction,
      payment_details,
      start_to_close_timeout: 10
    )
    
    # Step 2: Check if FX needed
    if payment_details[:source_currency] != payment_details[:target_currency]
      # Get FX rate
      logger.debug("Executing GetFXRate activity")
      fx_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::GetFXRate,
        payment_details[:source_currency],
        payment_details[:target_currency],
        start_to_close_timeout: 10
      )
      
      # Apply FX rate to amount
      converted_amount = payment_details[:amount] * fx_result[:rate]
    else
      converted_amount = payment_details[:amount]
    end
    
    # Step 3: Run compliance check
    logger.debug("Executing CheckCompliance activity")
    compliance_result = Temporalio::Workflow.execute_activity(
      PaymentActivities::CheckCompliance,
      payment_details,
      start_to_close_timeout: 10
    )
    
    # Step 4: Process payment
    if compliance_result[:approved]
      logger.debug("Executing ProcessPayment activity")
      process_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::ProcessPayment,
        {
          source_account: payment_details[:source_account],
          target_account: payment_details[:target_account],
          amount: converted_amount,
          currency: payment_details[:target_currency],
          reference: payment_details[:reference]
        }, 
        start_to_close_timeout: 10
      )
      
      {
        status: "completed",
        transaction_id: process_result[:transaction_id],
        amount: converted_amount,
        currency: payment_details[:target_currency]
      }
    else
      {
        status: "rejected",
        reason: compliance_result[:reason]
      }
    end
  end
end

# Connect to the Temporal server
puts "Connecting to Temporal server at localhost:7233..."
client = Temporalio::Client.connect('localhost:7233', 'default')
puts "Connected to Temporal server namespace 'default' successfully"

# Start the worker
puts "Starting Temporal worker on queue 'payment-task-queue'... Press Ctrl-C to stop..."
begin
  # Create a worker instance
  worker = Temporalio::Worker.new(
    client: client,
    task_queue: 'payment-task-queue',
    workflows: [MultiCurrencyPaymentWorkflow],
    activities: [
      PaymentActivities::ValidateTransaction,
      PaymentActivities::GetFXRate,
      PaymentActivities::CheckCompliance,
      PaymentActivities::ProcessPayment
    ]
  )
  
  # Run the worker with shutdown on SIGINT
  puts "Starting worker run loop..."
  worker.run(shutdown_signals: ['SIGINT'])
  puts "Worker run loop started"
rescue => e
  logger.error "Error running Temporal worker: #{e.class} - #{e.message}"
  logger.error e.backtrace.join("\n")
  raise
end
