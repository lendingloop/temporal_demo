require 'temporal/workflow'

class MultiCurrencyPaymentWorkflow < Temporal::Workflow
  # Define our activities
  activity :validate_transaction_activity
  activity :get_exchange_rate_activity
  activity :authorize_payment_activity
  activity :run_fraud_check_activity
  activity :run_aml_check_activity
  activity :run_sanctions_check_activity
  activity :capture_payment_activity
  activity :release_authorization_activity
  activity :update_ledgers_activity
  activity :send_notifications_activity

  def execute(payment_data)
    # Initialize workflow state
    @state = {
      payment_data: payment_data,
      steps_completed: [],
      status: 'started'
    }

    # Track compensations for rollback
    @compensations = []
    
    begin
      # Execute payment pipeline
      validate_transaction(payment_data)
      get_exchange_rate(payment_data)
      authorize_payment(payment_data)
      run_compliance_checks(payment_data)
      capture_payment(payment_data)
      update_ledgers(payment_data)
      send_notifications(payment_data)
      
      # Payment successful
      @state[:status] = 'completed'
      @state[:result] = 'Payment processed successfully'
      
      return @state
      
    rescue => error
      # Execute compensations for rollback
      execute_compensations
      
      # Update state with error
      @state[:status] = 'failed'
      @state[:error] = error.message
      @state[:result] = 'Payment processing failed'
      
      return @state
    end
  end
  
  private

  def validate_transaction(payment_data)
    logger.info "Validating transaction: #{payment_data[:amount]} #{payment_data[:charge_currency]}"
    
    result = validate_transaction_activity(payment_data)
    @state[:validation] = result
    @state[:steps_completed] << 'validation'
    
    raise "Transaction validation failed: #{result[:reason]}" unless result[:approved]
  end

  def get_exchange_rate(payment_data)
    logger.info "Getting exchange rate: #{payment_data[:charge_currency]} to #{payment_data[:settlement_currency]}"
    
    rate_result = get_exchange_rate_activity(
      from: payment_data[:charge_currency],
      to: payment_data[:settlement_currency]
    )
    
    # Store the rate and lock ID
    @state[:exchange_rate] = {
      rate: rate_result[:rate],
      lock_id: rate_result[:lock_id],
      from: rate_result[:from],
      to: rate_result[:to]
    }
    
    # Calculate settlement amount
    @state[:charge_amount] = payment_data[:amount]
    @state[:settlement_amount] = (payment_data[:amount] * rate_result[:rate]).round(2)
    @state[:steps_completed] << 'exchange_rate'
    
    # Add compensation to release the rate lock if later steps fail
    @compensations << {
      type: :release_rate_lock,
      lock_id: rate_result[:lock_id]
    }
  end

  def authorize_payment(payment_data)
    logger.info "Authorizing payment: #{@state[:settlement_amount]} #{payment_data[:settlement_currency]}"
    
    auth_result = authorize_payment_activity(
      amount: @state[:settlement_amount],
      currency: payment_data[:settlement_currency],
      customer: payment_data[:customer],
      merchant: payment_data[:merchant]
    )
    
    @state[:authorization] = auth_result
    @state[:steps_completed] << 'authorization'
    
    # Add compensation to release authorization if later steps fail
    @compensations << {
      type: :release_authorization,
      auth_id: auth_result[:authorization_id]
    }
  end

  def run_compliance_checks(payment_data)
    logger.info "Running compliance checks"
    
    # Run multiple checks in parallel
    fraud_future = run_fraud_check_activity.execute_async(payment_data)
    aml_future = run_aml_check_activity.execute_async(payment_data)
    sanctions_future = run_sanctions_check_activity.execute_async(payment_data)
    
    # Wait for all futures to complete
    fraud_result = fraud_future.get
    aml_result = aml_future.get
    sanctions_result = sanctions_future.get
    
    # Store results
    @state[:compliance] = {
      fraud: fraud_result,
      aml: aml_result,
      sanctions: sanctions_result
    }
    @state[:steps_completed] << 'compliance_checks'
    
    # Raise errors for any failed checks
    if !fraud_result[:success]
      raise "Fraud check failed: #{fraud_result[:reason]}"
    end
    
    if !aml_result[:success]
      raise "AML check failed: #{aml_result[:reason]}"
    end
    
    if !sanctions_result[:success]
      raise "Sanctions check failed: #{sanctions_result[:reason]}"
    end
  end

  def capture_payment(payment_data)
    logger.info "Capturing payment: #{@state[:settlement_amount]} #{payment_data[:settlement_currency]}"
    
    capture_result = capture_payment_activity(
      authorization_id: @state[:authorization][:authorization_id],
      amount: @state[:settlement_amount],
      currency: payment_data[:settlement_currency]
    )
    
    @state[:capture] = capture_result
    @state[:steps_completed] << 'capture'
    
    # Update compensation - now we need a refund instead of auth release
    @compensations.delete_if { |comp| comp[:type] == :release_authorization }
    
    @compensations << {
      type: :refund_payment,
      transaction_id: capture_result[:transaction_id],
      amount: @state[:settlement_amount],
      currency: payment_data[:settlement_currency]
    }
  end

  def update_ledgers(payment_data)
    logger.info "Updating ledgers"
    
    ledger_result = update_ledgers_activity(
      transaction_id: @state[:capture][:transaction_id],
      amount: @state[:charge_amount],
      charge_currency: payment_data[:charge_currency],
      settlement_amount: @state[:settlement_amount],
      settlement_currency: payment_data[:settlement_currency],
      customer: payment_data[:customer],
      merchant: payment_data[:merchant]
    )
    
    @state[:ledger_updates] = ledger_result
    @state[:steps_completed] << 'ledgers'
  end

  def send_notifications(payment_data)
    logger.info "Sending notifications"
    
    notification_result = send_notifications_activity(
      payment_data: payment_data,
      state: @state
    )
    
    @state[:notifications] = notification_result
    @state[:steps_completed] << 'notifications'
  end

  def execute_compensations
    logger.info "Executing compensations: #{@compensations.size} compensation(s) to process"
    
    # Execute compensations in reverse order (LIFO)
    while compensation = @compensations.pop
      begin
        case compensation[:type]
        when :release_rate_lock
          # No real action needed for rate lock
          logger.info "Released rate lock: #{compensation[:lock_id]}"
          
        when :release_authorization
          logger.info "Releasing authorization: #{compensation[:auth_id]}"
          release_authorization_activity(
            authorization_id: compensation[:auth_id]
          )
          
        when :refund_payment
          logger.info "Refunding payment: #{compensation[:transaction_id]}"
          refund_payment_activity(
            transaction_id: compensation[:transaction_id],
            amount: compensation[:amount],
            currency: compensation[:currency]
          )
        end
      rescue => e
        logger.error "Compensation failed: #{e.message}"
        # Continue with next compensation
      end
    end
    
    logger.info "Compensations completed"
  end
end
