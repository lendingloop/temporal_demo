require 'temporalio/workflow'

# DEMO: START HERE - TEMPORAL WORKFLOW OVERVIEW
# This file defines our payment workflow using Temporal's workflow framework.
# A workflow in Temporal represents a durable, long-running business process that will
# execute reliably even through server outages, process crashes, and network issues.
# 
# Key Temporal benefits to highlight in demo:
# 1. Durability - State is preserved automatically
# 2. Reliability - Automatic retries and error handling
# 3. Observability - Full history of every action
# 4. Signaling - Ability to inject events like approvals
# 5. Timeouts - Built-in support for SLAs and deadlines
class MultiCurrencyPaymentWorkflow < Temporalio::Workflow::Definition
  # DEMO: SIGNALS - EXTERNAL EVENTS INTO WORKFLOWS
  # Signals allow external systems or users to send events into a running workflow.
  # They're perfect for human approvals, cancellations, or injecting new information.
  #
  # This signal is used during the demo to approve high-value payments.
  # You can trigger this via Temporal UI or the API during the demo.
  workflow_signal
  def approve_payment(approved=nil)
    Temporalio::Workflow.logger.info("Received approval signal")
    @payment_approved = true
  end

  # A second signal for rejecting payments - giving business users options
  # during the payment approval process
  workflow_signal
  def decline_payment(value=nil)
    Temporalio::Workflow.logger.info("Received rejection signal")
    @payment_approved = false
  end

  # DEMO: WORKFLOW EXECUTION - THE PAYMENT PROCESS
  # The execute method defines the entire payment business process from start to finish.
  # Temporal ensures this executes EXACTLY ONCE and maintains its state through failures.
  # 
  # This workflow runs on the 'payment-task-queue' defined in worker.rb
  # All state within this method is automatically persisted by Temporal
  def execute(payment_data)
    # DEMO POINT 1: WORKFLOW INPUTS
    # Workflows receive their initial inputs when started
    # In this case, payment_data contains all details needed for processing
    Temporalio::Workflow.logger.info("Starting payment workflow with data type: #{payment_data.class}")
    Temporalio::Workflow.logger.info("Payment data: #{payment_data.inspect}")    
    
    # Normalize payment data right at the beginning to handle array/hash consistently
    normalized_data = normalize_payment_data(payment_data)
    Temporalio::Workflow.logger.info("Normalized payment data: #{normalized_data.inspect}")
    
    # DEMO POINT 2: WORKFLOW STATE
    # Any instance variables you set in workflow code are automatically persisted
    # If the worker crashes and restarts, this state will be exactly restored
    @state = {
      payment_data: payment_data,
      status: 'started'
    }
    
    begin
      # DEMO POINT 3: ACTIVITIES - EXTERNAL WORK WITH AUTOMATIC RETRIES
      # Activities are where actual work happens (API calls, DB operations, etc.)
      # Activities are automatically retried on failure based on retry policies
      # Remember to mention: Activities use the 'payment-task-queue' defined in worker.rb
      
      # Step 1: Validate the transaction with extensive logging and error handling
      Temporalio::Workflow.logger.info("Step 1: Validating transaction")
      begin
        # DEMO: This is calling ValidateTransactionActivity defined in payment_activities.rb
        # Note the timeout - if activity takes longer than 10 seconds, it will fail
        validation_result = Temporalio::Workflow.execute_activity(
          ValidateTransactionActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Validation result: #{validation_result.inspect}")
        @state[:validation] = validation_result
      rescue => e
        # All exceptions are logged and saved in workflow history for debugging
        Temporalio::Workflow.logger.error("Validation error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
      
      # DEMO POINT 4: EXTERNAL SERVICE CALLS
      # These activities call the compliance_api service via HTTP
      # Notice how we don't need special error handling code - Temporal handles retries
      Temporalio::Workflow.logger.info("Step 2: Running compliance checks")
      begin
        # DEMO: Show how this activity (RunFraudCheckActivity) contacts compliance_api
        # The compliance activity is defined in compliance_activities.rb
        # It makes HTTP calls using Faraday to the compliance_api container
        fraud_check_result = Temporalio::Workflow.execute_activity(
          RunFraudCheckActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Fraud check result: #{fraud_check_result.inspect}")
        @state[:fraud_check] = fraud_check_result
        
        # Another compliance check - showing multiple external API calls
        # Each activity is registered in worker.rb on the 'payment-task-queue'
        # If the UI doesn't show workflows, check worker registrations and task queues!
        aml_check_result = Temporalio::Workflow.execute_activity(
          RunAmlCheckActivity,
          payment_data,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("AML check result: #{aml_check_result.inspect}")
        @state[:aml_check] = aml_check_result
        
        # DEMO POINT 5: BUSINESS LOGIC AND CONDITIONAL PATHS
        # Temporal allows you to implement complex business logic with conditions
        # Here, we check if the payment amount exceeds the high-value threshold ($5000)
        amount = normalized_data[:amount].to_f
        Temporalio::Workflow.logger.info("Checking if payment is high-value: $#{amount}")
        
        requires_approval = amount >= 5000.0
        
        if requires_approval
          Temporalio::Workflow.logger.info("High-value payment detected ($#{amount}) - requires manual approval")
          
          # DEMO POINT 6: HUMAN INTERVENTION VIA SIGNALS
          # This is one of the most powerful Temporal features - human approval loops
          # The workflow will pause here and wait for a human decision indefinitely
          Temporalio::Workflow.logger.info("Step 2.5: Starting manual approval process")
          
          # Extract payment reference for logging
          payment_ref = normalized_data[:reference].to_s
          
          # Initialize approval status as nil - will be set by signal
          @payment_approved = nil
          
          # Log that we need manual approval
          Temporalio::Workflow.logger.info("Payment #{payment_ref} ($#{amount}) waiting for manual approval")
          Temporalio::Workflow.logger.info("TO APPROVE: Use Temporal UI or API to send signal 'approve_payment' with value true/false")
          
          # DEMO: IMPORTANT DEMO STEP - APPROVING THE PAYMENT
          # During the demo, you'll need to:
          # 1. Open the Temporal UI at http://localhost:8233
          # 2. Find this workflow (search for the workflow ID)
          # 3. Click "Signal" button, select "approve_payment" signal
          # 4. Execute the signal (no parameters needed)
          # 
          # NOTE: If workflows aren't showing in the UI, check that:
          # - The task queue names match exactly ('payment-task-queue')  
          # - The worker is properly registered (see worker.rb)
          # - The namespace is correct (default)
          Temporalio::Workflow.logger.info("Waiting for manual approval signal (no timeout)")
          Temporalio::Workflow.logger.info("**IMPORTANT** To approve: Send 'approve_payment' signal using Temporal UI")
          Temporalio::Workflow.logger.info("**IMPORTANT** To decline: Send 'decline_payment' signal using Temporal UI")
          
          # DEMO POINT 7: DURABLE TIMERS AND WAIT CONDITIONS
          # This workflow will pause execution here and wait for a signal
          # The worker could crash and restart - the workflow would still be waiting
          # This is incredibly powerful for long-running business processes!
          Temporalio::Workflow.wait_condition { @payment_approved != nil }
          
          # After receiving signal, log the result
          if @payment_approved
            Temporalio::Workflow.logger.info("Payment was APPROVED via signal")
          else
            Temporalio::Workflow.logger.info("Payment was DECLINED via signal")
          end
          
          # Record the approval decision
          @state[:manual_approval] = @payment_approved ? 'approved' : 'rejected'
          
          # DEMO POINT 8: BRANCHING WORKFLOW PATHS
          # Workflows can take different paths based on decisions
          # Here we either continue processing or terminate early with rejection
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
      
      # DEMO POINT 9: CROSS-SERVICE COMMUNICATION - THE FX SERVICE
      # This section demonstrates the Docker networking between containers
      # The KEY FIX we made was adding 'Host: localhost' headers to Faraday requests
      # This bypasses Sinatra's host protection when services communicate
      Temporalio::Workflow.logger.info("Step 3: Getting exchange rate")
      begin
        # DEMO NOTE: This calls the fx_service container via HTTP
        # In fx_activities.rb, notice the Host header we added to fix connectivity
        # When explaining, highlight how docker-compose networking uses service names
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
        # Without our Host header fix, we would get errors here with 'Host not permitted'
        Temporalio::Workflow.logger.error("FX service error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
      
      # DEMO POINT 10: FINAL PAYMENT PROCESSING
      # This is the last step in our payment workflow - capturing the payment
      # In a real system, this might interact with payment processors like Stripe
      Temporalio::Workflow.logger.info("Step 4: Capturing payment")
      begin
        # Prepare final payment parameters
        capture_params = {
          amount: normalized_data[:amount],
          currency: normalized_data[:currency] || normalized_data[:charge_currency] || normalized_data[:settlement_currency],
          authorization_id: normalized_data[:authorization_id] || 'default-auth-id'
        }
        capture_result = Temporalio::Workflow.execute_activity(
          CapturePaymentActivity,
          capture_params,
          start_to_close_timeout: 10
        )
        Temporalio::Workflow.logger.info("Capture result: #{capture_result.inspect}")
        @state[:capture] = capture_result
      rescue => e
        # Even at this late stage, Temporal would retry the activity
        # This provides end-to-end reliability for the entire payment process
        Temporalio::Workflow.logger.error("Capture error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        raise
      end
    rescue => e
      # Workflow-level errors are captured and the workflow would be marked as failed
      Temporalio::Workflow.logger.error("Workflow error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      raise
    end
    
    # DEMO POINT 11: WORKFLOW COMPLETION
    # When the workflow completes, the final state is returned to the caller
    # The payment API can query this status to show progress to end users
    @state[:status] = 'completed'
    @state[:result] = 'Payment processed successfully'
    
    # IMPORTANT: Make sure to check the Temporal UI for finished workflows
    # Remember task queue 'payment-task-queue' must be correctly registered!
    Temporalio::Workflow.logger.info("Workflow completed successfully: #{@state.inspect}")
    @state
  rescue StandardError => error
    # DEMO POINT 12: ERROR HANDLING
    # Temporal provides comprehensive error handling capabilities
    # We capture errors in our workflow state for easy debugging
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
