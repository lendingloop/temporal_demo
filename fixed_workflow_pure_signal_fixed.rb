require 'temporalio/workflow'

# Minimal workflow for payment processing demo
class MultiCurrencyPaymentWorkflow < Temporalio::Workflow::Definition
  # Define signal handler for manual approval
  workflow_signal
  def approve_payment(approved)
    Temporalio::Workflow.logger.info("Received approval signal with value: #{approved}")
    @payment_approved = approved
  end

  def execute(payment_data)
    # Log workflow start with detailed data info
    Temporalio::Workflow.logger.info("Starting payment workflow with data type: #{payment_data.class}")
    Temporalio::Workflow.logger.info("Payment data: #{payment_data.inspect}")    
    
    # Normalize payment data right at the beginning to handle array/hash consistently
    normalized_data = normalize_payment_data(payment_data)
    Temporalio::Workflow.logger.info("Normalized payment data: #{normalized_data.inspect}")
    
    # Initialize workflow state with safe defaults
    @state = {
      payment_data: payment_data,
      status: 'started'
    }
    
    begin
      # Step 1: Validate the transaction with extensive logging and error handling
      Temporalio::Workflow.logger.info("Step 1: Validating transaction")
      begin
        validation_result = Temporalio::Workflow.execute_activity(
          ValidateTransactionActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Validation result: #{validation_result.inspect}")
        @state[:validation] = validation_result
      rescue => e
        Temporalio::Workflow.logger.error("Validation error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
      
      # Step 2: Run compliance checks using the compliance API
      Temporalio::Workflow.logger.info("Step 2: Running compliance checks")
      begin
        # Run fraud check via compliance API
        fraud_check_result = Temporalio::Workflow.execute_activity(
          RunFraudCheckActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Fraud check result: #{fraud_check_result.inspect}")
        @state[:fraud_check] = fraud_check_result
        
        # Run AML check via compliance API
        aml_check_result = Temporalio::Workflow.execute_activity(
          RunAmlCheckActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("AML check result: #{aml_check_result.inspect}")
        @state[:aml_check] = aml_check_result
        
        # Check if payment is high-value and requires manual approval
        # High-value threshold is $5000
        amount = normalized_data[:amount].to_f
        Temporalio::Workflow.logger.info("Checking if payment is high-value: $#{amount}")
        
        requires_approval = amount >= 5000.0
        
        if requires_approval
          Temporalio::Workflow.logger.info("High-value payment detected ($#{amount}) - requires manual approval")
          
          # Step 2.5: Waiting for manual approval via signal
          Temporalio::Workflow.logger.info("Step 2.5: Starting manual approval process")
          
          # Extract payment reference for logging
          payment_ref = normalized_data[:reference].to_s
          
          # Initialize approval status as nil - will be set by signal
          @payment_approved = nil
          
          # Log instructions for manual approval via Temporal UI
          workflow_id = Temporalio::Workflow.info.workflow_id
          namespace = Temporalio::Workflow.info.namespace || "default"
          task_queue = Temporalio::Workflow.info.task_queue
          
          Temporalio::Workflow.logger.info("======= MANUAL APPROVAL REQUIRED =======")
          Temporalio::Workflow.logger.info("Payment #{payment_ref} ($#{amount}) waiting for manual approval")
          Temporalio::Workflow.logger.info("TO APPROVE: Use Temporal UI to send signal 'approve_payment' to workflow ID: #{workflow_id}")
          Temporalio::Workflow.logger.info("  Workflow ID: #{workflow_id}")
          Temporalio::Workflow.logger.info("  Namespace: #{namespace}")
          Temporalio::Workflow.logger.info("  Task Queue: #{task_queue}")
          Temporalio::Workflow.logger.info("  Signal Name: approve_payment")
          Temporalio::Workflow.logger.info("  Signal Value: true (to approve) or false (to reject)")
          Temporalio::Workflow.logger.info("=========================================")
          
          # Wait indefinitely for the approval signal - no timeout
          # We'll only proceed once the signal is received
          Temporalio::Workflow.logger.info("Waiting for manual approval signal (no timeout)")
          
          # Wait for the condition that @payment_approved is no longer nil (signal received)
          while @payment_approved.nil?
            Temporalio::Workflow.sleep(5)  # Check every 5 seconds
            Temporalio::Workflow.logger.info("Still waiting for manual approval signal...")
          end
          
          # Record the approval decision
          @state[:manual_approval] = @payment_approved ? 'approved' : 'rejected'
          
          if @payment_approved
            Temporalio::Workflow.logger.info("Payment #{payment_ref} APPROVED by manual review - continuing workflow")
          else
            @state[:status] = 'rejected'
            @state[:result] = "Payment rejected by manual review"
            Temporalio::Workflow.logger.info("Payment #{payment_ref} REJECTED by manual review - ending workflow")
            return @state
          end
        end
      rescue => e
        Temporalio::Workflow.logger.error("Compliance check or manual approval error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
      
      # Step 3: Get exchange rate from FX service API
      Temporalio::Workflow.logger.info("Step 3: Getting exchange rate")
      begin
        # Prepare params for FX API call using normalized data
        fx_params = {
          from: normalized_data[:charge_currency] || normalized_data[:currency],
          to: normalized_data[:settlement_currency] || normalized_data[:currency]
        }
        fx_result = Temporalio::Workflow.execute_activity(
          GetExchangeRateActivity,
          fx_params,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("FX rate result: #{fx_result.inspect}")
        @state[:fx_rate] = fx_result
      rescue => e
        Temporalio::Workflow.logger.error("FX service error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
      
      # Step 4: Capture the payment with extensive logging and error handling
      Temporalio::Workflow.logger.info("Step 4: Capturing payment")
      begin
        # Ensure we have the right params for capture using normalized data
        capture_params = {
          amount: normalized_data[:amount],
          currency: normalized_data[:currency] || normalized_data[:charge_currency] || normalized_data[:settlement_currency],
          authorization_id: normalized_data[:authorization_id] || 'default-auth-id'  # Fallback for demo
        }
        capture_result = Temporalio::Workflow.execute_activity(
          CapturePaymentActivity,
          capture_params,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Capture result: #{capture_result.inspect}")
        @state[:capture] = capture_result
      rescue => e
        Temporalio::Workflow.logger.error("Capture error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
    rescue => e
      Temporalio::Workflow.logger.error("Workflow error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      raise
    end
    
    # Mark workflow as completed
    @state[:status] = 'completed'
    @state[:result] = 'Payment processed successfully'
    
    # Log final state and return
    Temporalio::Workflow.logger.info("Workflow completed successfully: #{@state.inspect}")
    @state
  rescue StandardError => error
    # Handle errors by capturing them in state with detailed logging
    Temporalio::Workflow.logger.error("Workflow error: #{error.class} - #{error.message}")
    Temporalio::Workflow.logger.error("Backtrace: #{error.backtrace.join("\n")}")
    
    @state ||= {}
    @state[:status] = 'failed'
    @state[:error] = "#{error.class}: #{error.message}"
    @state
  end
  
  private
  
  # Helper method to safely normalize payment data
  def normalize_payment_data(input)
    Temporalio::Workflow.logger.info("Normalizing payment data of type: #{input.class}")
    
    if input.is_a?(Hash)
      # Carefully convert string keys to symbols for consistency
      begin
        result = {}
        input.each do |k, v|
          # Extra logging to help debug the TypeError issue
          Temporalio::Workflow.logger.debug("Processing key: #{k.inspect} (#{k.class}) with value: #{v.inspect}")
          
          # Handle nested hashes/arrays
          if v.is_a?(Hash)
            result[k.respond_to?(:to_sym) ? k.to_sym : k] = normalize_payment_data(v)
          elsif v.is_a?(Array) && v.first.is_a?(Hash)
            result[k.respond_to?(:to_sym) ? k.to_sym : k] = v.map { |item| item.is_a?(Hash) ? normalize_payment_data(item) : item }
          else
            result[k.respond_to?(:to_sym) ? k.to_sym : k] = v
          end
        end
        result
      rescue => e
        # Log error and fall back to safe default
        Temporalio::Workflow.logger.error("Error normalizing data: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        {amount: 100.0, currency: "USD", error_info: e.message}
      end
    elsif input.is_a?(Array) && !input.empty?
      if input.first.is_a?(Hash)
        # If array of hashes, take first element and normalize
        normalize_payment_data(input.first)
      else
        # If array of non-hashes, return safe default
        Temporalio::Workflow.logger.warn("Array contains non-hash elements, using default")
        {amount: 100.0, currency: "USD"}
      end
    else
      # Default safe fallback
      Temporalio::Workflow.logger.warn("Invalid payment data format (#{input.class}), using default")
      {amount: 100.0, currency: "USD"}
    end
  end
end
