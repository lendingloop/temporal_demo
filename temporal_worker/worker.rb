# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'temporalio/activity'
require 'logger'
require 'securerandom'
require 'net/http'
require 'uri'
require 'json'

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
      
      # Basic validation rules
      amount = payment_details[:amount].to_f
      charge_currency = payment_details[:charge_currency] || payment_details[:source_currency]
      settlement_currency = payment_details[:settlement_currency] || payment_details[:target_currency]
      
      if amount <= 0
        return { valid: false, reason: "Amount must be greater than zero" }
      end
      
      if !charge_currency || charge_currency.empty?
        return { valid: false, reason: "Source currency is required" }
      end
      
      if !settlement_currency || settlement_currency.empty?
        return { valid: false, reason: "Target currency is required" }
      end
      
      result = { valid: true }
      logger.debug("END ValidateTransaction activity with result: #{result}")
      result
    end
  end

  # Lock FX rate activity - calls external FX Service
  class LockFXRate < Temporalio::Activity::Definition
    def execute(charge_currency, settlement_currency)
      logger = Logger.new(STDOUT)
      logger.debug("START LockFXRate activity from #{charge_currency} to #{settlement_currency}")
      
      begin
        # Call external FX service to lock rate
        uri = URI.parse("http://localhost:3001/api/lock_rate")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = { from: charge_currency, to: settlement_currency }.to_json
        
        logger.debug("Calling FX service to lock rate")
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(req)
        end
        
        if response.code == "200"
          result = JSON.parse(response.body, symbolize_names: true)
          logger.debug("FX service returned result: #{result.inspect}")
          { 
            success: true, 
            lock_id: result[:lock_id], 
            rate: result[:rate],
            from: result[:from], 
            to: result[:to] 
          }
        else
          logger.error("FX service error: #{response.body}")
          { success: false, error: "Failed to lock FX rate" }
        end
      rescue => e
        logger.error("Error calling FX service: #{e.message}")
        { success: false, error: e.message }
      end
    end
  end
  
  # Release FX rate lock - compensation for LockFXRate
  class ReleaseFXRate < Temporalio::Activity::Definition
    def execute(lock_id)
      logger = Logger.new(STDOUT)
      logger.debug("START ReleaseFXRate activity for lock: #{lock_id}")
      
      # In real system, you'd call the FX service to release the lock
      # For demo, we'll simulate success
      logger.info("Released FX rate lock: #{lock_id}")
      
      { success: true, message: "Released FX rate lock" }
    end
  end

  # Fraud check activity - calls external Compliance API
  class RunFraudCheck < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.debug("START RunFraudCheck activity")
      
      begin
        # Format the data for compliance API
        request_data = {
          amount: payment_details[:amount].to_f,
          charge_currency: payment_details[:charge_currency] || payment_details[:source_currency],
          settlement_currency: payment_details[:settlement_currency] || payment_details[:target_currency],
          customer: payment_details[:customer] || {
            business_name: payment_details[:source_account],
            email: "#{payment_details[:source_account].gsub(' ', '').downcase}@example.com"
          },
          merchant: payment_details[:merchant] || {
            name: payment_details[:target_account],
            country: "US"
          }
        }
        
        # Call external Compliance API for fraud check
        uri = URI.parse("http://localhost:3002/api/checks/fraud")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = request_data.to_json
        
        logger.debug("Calling Compliance API for fraud check with: #{request_data}")
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(req)
        end
        
        if response.code == "200"
          result = JSON.parse(response.body, symbolize_names: true)
          logger.debug("Compliance API returned fraud check result: #{result.inspect}")
          {
            approved: result[:success] && result[:result] == "passed",
            risk_score: result[:risk_score],
            details: result
          }
        else
          result = JSON.parse(response.body, symbolize_names: true) rescue { error: response.body }
          logger.error("Compliance API fraud check failed: #{result.inspect}")
          {
            approved: false,
            reason: result[:reason] || "Fraud check failed",
            risk_score: result[:risk_score],
            details: result
          }
        end
      rescue => e
        logger.error("Error calling Compliance API for fraud check: #{e.message}")
        { approved: false, reason: "Service error: #{e.message}" }
      end
    end
  end
  
  # AML Check activity - calls external Compliance API
  class RunAMLCheck < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.debug("START RunAMLCheck activity")
      
      begin
        # Format the data for compliance API
        request_data = {
          amount: payment_details[:amount].to_f,
          charge_currency: payment_details[:charge_currency] || payment_details[:source_currency],
          settlement_currency: payment_details[:settlement_currency] || payment_details[:target_currency],
          customer: payment_details[:customer] || {
            business_name: payment_details[:source_account],
            email: "#{payment_details[:source_account].gsub(' ', '').downcase}@example.com"
          },
          merchant: payment_details[:merchant] || {
            name: payment_details[:target_account],
            country: "US"
          }
        }
        
        # Call external Compliance API for AML check
        uri = URI.parse("http://localhost:3002/api/checks/aml")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = request_data.to_json
        
        logger.debug("Calling Compliance API for AML check with: #{request_data}")
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(req)
        end
        
        if response.code == "200"
          result = JSON.parse(response.body, symbolize_names: true)
          logger.debug("Compliance API returned AML check result: #{result.inspect}")
          {
            approved: result[:success] && result[:result] == "passed",
            aml_score: result[:aml_score],
            details: result
          }
        else
          result = JSON.parse(response.body, symbolize_names: true) rescue { error: response.body }
          logger.error("Compliance API AML check failed: #{result.inspect}")
          {
            approved: false,
            reason: result[:reason] || "AML check failed",
            aml_score: result[:aml_score],
            details: result
          }
        end
      rescue => e
        logger.error("Error calling Compliance API for AML check: #{e.message}")
        { approved: false, reason: "Service error: #{e.message}" }
      end
    end
  end

  # Pre-authorize payment activity
  class PreAuthorizePayment < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.debug("START PreAuthorizePayment activity")
      
      # Simulate payment pre-authorization
      sleep(1)
      
      # Generate an authorization ID
      auth_id = "auth-#{SecureRandom.hex(8)}"
      logger.info("Payment pre-authorized with ID: #{auth_id}")
      
      {
        success: true, 
        auth_id: auth_id,
        amount: payment_details[:amount],
        currency: payment_details[:charge_currency] || payment_details[:source_currency],
        timestamp: Time.now.to_i
      }
    end
  end
  
  # Cancel pre-authorization - compensation for PreAuthorizePayment
  class CancelPreAuthorization < Temporalio::Activity::Definition
    def execute(auth_id)
      logger = Logger.new(STDOUT)
      logger.debug("START CancelPreAuthorization activity for auth: #{auth_id}")
      
      # Simulate payment pre-authorization cancellation
      sleep(1)
      
      logger.info("Payment pre-authorization canceled: #{auth_id}")
      { success: true, message: "Pre-authorization canceled" }
    end
  end

  # Process payment activity
  class ProcessPayment < Temporalio::Activity::Definition
    def execute(payment_details)
      logger = Logger.new(STDOUT)
      logger.debug("START ProcessPayment activity")
      
      # In production, this would call your payment gateway
      # For demo, simulate processing
      sleep(2)
      
      transaction_id = "txn-#{SecureRandom.hex(10)}"
      logger.info("Payment processed successfully with transaction ID: #{transaction_id}")
      
      { 
        success: true,
        transaction_id: transaction_id,
        amount: payment_details[:amount],
        currency: payment_details[:settlement_currency] || payment_details[:target_currency],
        timestamp: Time.now.to_i
      }
    end
  end
  
  # Reverse payment - compensation for ProcessPayment
  class ReversePayment < Temporalio::Activity::Definition
    def execute(transaction_id)
      logger = Logger.new(STDOUT)
      logger.debug("START ReversePayment activity for transaction: #{transaction_id}")
      
      # Simulate payment reversal
      sleep(1)
      
      logger.info("Payment reversed: #{transaction_id}")
      { success: true, message: "Payment reversed", transaction_id: transaction_id }
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
    logger.info("Starting MultiCurrencyPaymentWorkflow for #{payment_details.inspect}")
    
    # Store compensation information
    compensation_info = {}
    
    begin
      # Step 1: Validate the transaction
      logger.info("Step 1: Validating transaction")
      validation_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::ValidateTransaction,
        payment_details,
        start_to_close_timeout: 10
      )
      
      unless validation_result[:valid]
        logger.warn("Validation failed: #{validation_result[:reason]}")
        return {
          status: "rejected",
          reason: validation_result[:reason],
          stage: "validation"
        }
      end
      
      # Step 2: Lock FX rate if needed
      charge_currency = payment_details[:charge_currency] || payment_details[:source_currency]
      settlement_currency = payment_details[:settlement_currency] || payment_details[:target_currency]
      
      if charge_currency != settlement_currency
        logger.info("Step 2: Locking FX rate from #{charge_currency} to #{settlement_currency}")
        fx_result = Temporalio::Workflow.execute_activity(
          PaymentActivities::LockFXRate,
          charge_currency,
          settlement_currency,
          start_to_close_timeout: 10
        )
        
        unless fx_result[:success]
          logger.warn("Failed to lock FX rate: #{fx_result[:error]}")
          return {
            status: "failed",
            reason: "Could not lock exchange rate: #{fx_result[:error]}",
            stage: "fx_rate"
          }
        end
        
        # Store FX lock ID for potential compensation
        compensation_info[:fx_lock_id] = fx_result[:lock_id]
        
        # Calculate converted amount
        amount = payment_details[:amount].to_f
        converted_amount = amount * fx_result[:rate]
        logger.info("Conversion: #{amount} #{charge_currency} = #{converted_amount} #{settlement_currency} at rate #{fx_result[:rate]}")
      else
        converted_amount = payment_details[:amount].to_f
        logger.info("No FX conversion needed (same currency)")
      end
      
      # Step 3: Run fraud check
      logger.info("Step 3: Running fraud detection")
      fraud_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::RunFraudCheck,
        payment_details,
        start_to_close_timeout: 15
      )
      
      unless fraud_result[:approved]
        logger.warn("Fraud check failed: #{fraud_result[:reason]}")
        
        # Release FX rate lock if we have one
        if compensation_info[:fx_lock_id]
          logger.info("Compensation: Releasing FX rate lock")
          release_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReleaseFXRate,
            compensation_info[:fx_lock_id],
            start_to_close_timeout: 10
          )
        end
        
        return {
          status: "rejected",
          reason: "Fraud check failed: #{fraud_result[:reason]}",
          risk_score: fraud_result[:risk_score],
          stage: "fraud_check"
        }
      end
      
      # Step 4: Run AML check
      logger.info("Step 4: Running AML check")
      aml_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::RunAMLCheck,
        payment_details,
        start_to_close_timeout: 15
      )
      
      unless aml_result[:approved]
        logger.warn("AML check failed: #{aml_result[:reason]}")
        
        # Release FX rate lock if we have one
        if compensation_info[:fx_lock_id]
          logger.info("Compensation: Releasing FX rate lock")
          release_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReleaseFXRate,
            compensation_info[:fx_lock_id],
            start_to_close_timeout: 10
          )
        end
        
        return {
          status: "rejected",
          reason: "AML check failed: #{aml_result[:reason]}",
          aml_score: aml_result[:aml_score],
          stage: "aml_check"
        }
      end
      
      # Step 5: Pre-authorize payment (hold funds)
      logger.info("Step 5: Pre-authorizing payment")
      pre_auth_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::PreAuthorizePayment,
        {
          source_account: payment_details[:source_account] || payment_details[:customer][:business_name],
          target_account: payment_details[:target_account] || payment_details[:merchant][:name],
          amount: payment_details[:amount].to_f,
          currency: charge_currency,
          reference: payment_details[:reference] || "pay-#{SecureRandom.hex(6)}"
        },
        start_to_close_timeout: 10
      )
      
      unless pre_auth_result[:success]
        logger.warn("Pre-authorization failed: #{pre_auth_result[:message]}")
        
        # Release FX rate lock if we have one
        if compensation_info[:fx_lock_id]
          logger.info("Compensation: Releasing FX rate lock")
          release_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReleaseFXRate,
            compensation_info[:fx_lock_id],
            start_to_close_timeout: 10
          )
        end
        
        return {
          status: "failed",
          reason: "Failed to pre-authorize payment: #{pre_auth_result[:message]}",
          stage: "pre_authorization"
        }
      end
      
      # Store pre-auth ID for potential compensation
      compensation_info[:pre_auth_id] = pre_auth_result[:auth_id]
      
      # Step 6: Process payment (settle)
      logger.info("Step 6: Processing final payment")
      process_result = Temporalio::Workflow.execute_activity(
        PaymentActivities::ProcessPayment,
        {
          source_account: payment_details[:source_account] || payment_details[:customer][:business_name],
          target_account: payment_details[:target_account] || payment_details[:merchant][:name],
          amount: converted_amount,
          currency: settlement_currency,
          reference: payment_details[:reference] || "pay-#{SecureRandom.hex(6)}",
          auth_id: pre_auth_result[:auth_id]
        },
        start_to_close_timeout: 10
      )
      
      unless process_result[:success]
        logger.warn("Payment processing failed: #{process_result[:message]}")
        
        # Cancel pre-authorization
        logger.info("Compensation: Canceling payment pre-authorization")
        cancel_auth_result = Temporalio::Workflow.execute_activity(
          PaymentActivities::CancelPreAuthorization,
          compensation_info[:pre_auth_id],
          start_to_close_timeout: 10
        )
        
        # Release FX rate lock if we have one
        if compensation_info[:fx_lock_id]
          logger.info("Compensation: Releasing FX rate lock")
          release_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReleaseFXRate,
            compensation_info[:fx_lock_id],
            start_to_close_timeout: 10
          )
        end
        
        return {
          status: "failed",
          reason: "Payment processing failed: #{process_result[:message]}",
          stage: "payment_processing"
        }
      end
      
      # Store transaction ID
      compensation_info[:transaction_id] = process_result[:transaction_id]
      
      # Success! Return the complete result
      logger.info("Payment workflow completed successfully")
      {
        status: "completed",
        transaction_id: process_result[:transaction_id],
        amount: {
          original: payment_details[:amount].to_f,
          currency: charge_currency,
          converted: converted_amount.round(2),
          settlement_currency: settlement_currency
        },
        exchange_rate: fx_result ? fx_result[:rate] : 1.0,
        fx_lock_id: compensation_info[:fx_lock_id],
        timestamp: Time.now.to_i
      }
      
    rescue => e
      logger.error("Workflow error: #{e.class} - #{e.message}")
      logger.error(e.backtrace.join("\n"))
      
      # Run compensation logic based on how far we got
      begin
        if compensation_info[:transaction_id]
          # Reverse the payment if it was processed
          logger.info("Compensation: Reversing payment transaction")
          reverse_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReversePayment,
            compensation_info[:transaction_id],
            start_to_close_timeout: 10
          )
        end
        
        if compensation_info[:pre_auth_id]
          # Cancel pre-authorization
          logger.info("Compensation: Canceling payment pre-authorization")
          cancel_auth_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::CancelPreAuthorization,
            compensation_info[:pre_auth_id],
            start_to_close_timeout: 10
          )
        end
        
        if compensation_info[:fx_lock_id]
          # Release FX rate lock
          logger.info("Compensation: Releasing FX rate lock")
          release_result = Temporalio::Workflow.execute_activity(
            PaymentActivities::ReleaseFXRate,
            compensation_info[:fx_lock_id],
            start_to_close_timeout: 10
          )
        end
      rescue => comp_error
        logger.error("Error during compensation: #{comp_error.message}")
      end
      
      # Return error result
      {
        status: "failed",
        reason: "Workflow error: #{e.message}",
        stage: "unknown"
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
      PaymentActivities::LockFXRate,
      PaymentActivities::ReleaseFXRate,
      PaymentActivities::RunFraudCheck,
      PaymentActivities::RunAMLCheck,
      PaymentActivities::PreAuthorizePayment,
      PaymentActivities::CancelPreAuthorization,
      PaymentActivities::ProcessPayment,
      PaymentActivities::ReversePayment
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
