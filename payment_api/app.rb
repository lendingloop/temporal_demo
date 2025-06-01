require 'sinatra/base'
require 'json'
require 'securerandom'
require 'logger'
require 'temporalio/client'

# Simple Payment API using Sinatra instead of Rails
class PaymentAPI < Sinatra::Base
  # Configure logging
  set :logger, Logger.new(STDOUT)
  enable :logging
  
  # Configure Temporal client with detailed logging
  def self.temporal_client
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    
    if defined?(@@temporal_client)
      logger.debug("Returning existing Temporal client")
      return @@temporal_client
    end
    
    logger.debug("Connecting to Temporal server at localhost:7233")
    @@temporal_client = Temporalio::Client.connect('localhost:7233', 'default')
    logger.debug("Successfully connected to Temporal server")
    @@temporal_client
  end
  
  def temporal_client
    self.class.temporal_client
  end
  
  # Health check endpoint
  get '/health' do
    content_type :json
    { status: 'ok', service: 'payment_api' }.to_json
  end
  
  # Create payment endpoint
  post '/api/payments' do
    begin
      payload = JSON.parse(request.body.read, symbolize_names: true)
      
      # Generate a unique workflow ID
      workflow_id = "payment-#{SecureRandom.uuid}"
      
      # Start the workflow using the Temporal client
      temporal_client.start_workflow(
        'MultiCurrencyPaymentWorkflow',
        [payload],
        id: workflow_id,
        task_queue: 'payment-task-queue'
        # Using default ID reuse policy
      )
      
      # Return the workflow ID for status tracking
      status 202 # Accepted
      content_type :json
      { 
        success: true, 
        message: "Payment processing started", 
        workflow_id: workflow_id 
      }.to_json
    rescue Temporalio::Error => e
      if e.message.include?('not found') || e.message.include?('NotFound')
        status 404
        content_type :json
        { 
          success: false, 
          message: "Payment workflow not found", 
          workflow_id: workflow_id
        }.to_json
      else
        logger.error "Failed to start payment workflow: #{e.message}"
        logger.error e.backtrace.join("\n")
        status 500
        content_type :json
        { 
          success: false, 
          message: "Failed to start payment processing", 
          error: e.message 
        }.to_json
      end
    rescue => e
      logger.error "Failed to start payment workflow: #{e.message}"
      logger.error e.backtrace.join("\n")
      status 500
      content_type :json
      { 
        success: false, 
        message: "Failed to start payment processing", 
        error: e.message 
      }.to_json
    end
  end
  
  # Get payment status endpoint
  get '/api/payments/:id' do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    workflow_id = params['id']
    
    logger.debug("GET /api/payments/#{workflow_id} - Retrieving payment status")
    
    begin
      # Create a workflow handle with just the workflow ID (based on samples-ruby)
      logger.debug("Creating workflow handle for workflow_id: #{workflow_id}")
      handle = temporal_client.workflow_handle(workflow_id)
      logger.debug("Successfully created workflow handle")
      
      # Get workflow status using describe
      logger.debug("Getting workflow description")
      description = handle.describe
      logger.debug("Workflow status: #{description.status}")
      
      # Map Temporal status to our application status
      # Status codes from Temporal Ruby SDK:
      # 1 = RUNNING
      # 2 = COMPLETED
      # 3 = FAILED
      # 4 = CANCELED
      # 5 = TERMINATED
      # 6 = CONTINUED_AS_NEW
      # 7 = TIMED_OUT
      status = case description.status
               when 2
                 "COMPLETED"
               when 1
                 "RUNNING"
               when 3
                 "FAILED"
               when 4
                 "CANCELED"
               when 5
                 "TERMINATED"
               when 7
                 "TIMED_OUT"
               when 6
                 "CONTINUED_AS_NEW"
               else
                 "UNKNOWN_#{description.status}"
               end
      
      # If completed, try to get the result
      if status == "COMPLETED"
        begin
          logger.debug("Getting workflow result")
          result = handle.result(timeout: 2) # Short timeout for completed workflows
          logger.debug("Workflow result: #{result.inspect}")
        rescue => e
          logger.warn("Could not get workflow result: #{e.message}")
          result = { status: "completed" }
        end
      else
        result = nil
      end
      
      # Set appropriate message based on status
      message = case status
                when "COMPLETED"
                  "Payment has been completed successfully"
                when "RUNNING"
                  "Payment is being processed"
                when "FAILED"
                  "Payment processing failed"
                when "TERMINATED", "CANCELED"
                  "Payment was canceled"
                when "TIMED_OUT"
                  "Payment timed out"
                else
                  "Payment status: #{status}"
                end
      
      # Return the result
      content_type :json
      {
        success: true,
        status: status,
        message: message,
        workflow_id: workflow_id,
        result: result
      }.to_json
    rescue Temporalio::Error => e
      # Handle all Temporal errors
      logger.error("Temporal error: #{e.class}: #{e.message}")
      
      if e.message.include?('not found') || e.message.include?('NotFound')
        status 404
        content_type :json
        { error: "Payment workflow not found" }.to_json
      else
        status 500
        content_type :json
        { error: "Temporal error: #{e.message}" }.to_json
      end
    rescue => e
      # Handle all other errors
      logger.error("Error fetching workflow status: #{e.message}")
      logger.error(e.backtrace.join("\n")) 
      
      status 500
      content_type :json
      { error: e.message }.to_json
    end
  end
end

# Start the server if this file is executed directly
if __FILE__ == $0
  puts "Starting Payment API on port 3000..."
  PaymentAPI.run! host: 'localhost', port: 3000
end
