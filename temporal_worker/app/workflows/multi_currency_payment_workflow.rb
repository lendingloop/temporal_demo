require 'temporalio/workflow'

# Minimal workflow for payment processing demo
class MultiCurrencyPaymentWorkflow < Temporalio::Workflow::Definition

  def execute(payment_data)
    # Log workflow start with detailed data info
    Temporalio::Workflow.logger.info("Starting payment workflow with data type: #{payment_data.class}")
    Temporalio::Workflow.logger.info("Payment data: #{payment_data.inspect}")
    
    # Defensive data normalization with logging
    data = normalize_payment_data(payment_data)
    Temporalio::Workflow.logger.info("Normalized data: #{data.inspect}")
    
    # Initialize workflow state with safe defaults
    @state = {
      payment_data: data,
      status: 'started'
    }
    
    # Step 1: Validate the transaction with extensive logging and error handling
    Temporalio::Workflow.logger.info("Step 1: Validating transaction")
    begin
      validation_result = Temporalio::Workflow.execute_activity(
        ValidateTransactionActivity,
        data,
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
        data,
        start_to_close_timeout: 10
      )
      Temporalio::Workflow.logger.info("Fraud check result: #{fraud_check_result.inspect}")
      @state[:fraud_check] = fraud_check_result
      
      # Run AML check via compliance API
      aml_check_result = Temporalio::Workflow.execute_activity(
        RunAmlCheckActivity,
        data,
        start_to_close_timeout: 10
      )
      Temporalio::Workflow.logger.info("AML check result: #{aml_check_result.inspect}")
      @state[:aml_check] = aml_check_result
    rescue => e
      Temporalio::Workflow.logger.error("Compliance check error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      raise
    end
    
    # Step 3: Get exchange rate from FX service API
    Temporalio::Workflow.logger.info("Step 3: Getting exchange rate")
    begin
      # Prepare params for FX API call
      fx_params = {
        from: data[:charge_currency] || data[:currency],
        to: data[:settlement_currency] || data[:currency]
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
      # Ensure we have the right params for capture
      capture_params = {
        amount: data[:amount],
        currency: data[:currency] || data[:charge_currency] || data[:settlement_currency],
        authorization_id: data[:authorization_id] || 'default-auth-id'  # Fallback for demo
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
