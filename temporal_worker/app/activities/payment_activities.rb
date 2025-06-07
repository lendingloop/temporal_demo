require 'temporalio/activity'
require 'securerandom'
require 'json'
require 'logger'
require 'time'  # Explicitly require time to ensure iso8601 method is available

# Include ActivityLogging module if it exists, otherwise define it
module ActivityLogging
  def logger
    @logger ||= Logger.new(STDOUT).tap do |l|
      l.level = Logger::INFO
      l.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: [ACTIVITY] #{msg}\n"
      end
    end
  end
end unless defined?(ActivityLogging)

class ValidateTransactionActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Handle both array and hash inputs (API might send payment_data as first element in an array)
    data = if payment_data.is_a?(Array)
      logger.info "Converting payment_data from array to hash"
      payment_data.first
    else
      payment_data
    end
    
    logger.info "Validating transaction: #{data[:amount]} #{data[:charge_currency]}"
    
    # Simple validation rules
    errors = []
    errors << "Amount must be positive" if data[:amount].to_f <= 0
    errors << "Currency must be specified" if data[:charge_currency].to_s.empty?
    errors << "Settlement currency must be specified" if data[:settlement_currency].to_s.empty?
    errors << "Customer information incomplete" if data[:customer].nil? || data[:customer].empty?
    errors << "Merchant information incomplete" if data[:merchant].nil? || data[:merchant].empty?
    
    # For demo purposes, reject very large amounts
    if data[:amount].to_f > 50000
      errors << "Amount exceeds maximum allowed (50,000)"
    end

    if errors.any?
      return {
        approved: false,
        reason: errors.join(", ")
      }
    end
    
    return {
      approved: true,
      timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ") # Use strftime instead of iso8601
    }
  end
end

class AuthorizePaymentActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    logger.info "Authorizing payment: #{params[:amount]} #{params[:currency]}"
    
    # Simulate payment processor authorization
    # In real life, this would call a payment processor API
    auth_id = "auth-#{SecureRandom.uuid}"
    
    # Simulate processing time
    sleep(rand(0.5..2.0))
    
    # Randomly fail ~5% of authorizations for demo purposes
    if rand < 0.05
      raise "Payment authorization failed: Insufficient funds"
    end
    
    logger.info "Payment authorized with ID: #{auth_id}"
    
    return {
      authorization_id: auth_id,
      authorized_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"), # Use strftime instead of iso8601
      expires_at: (Time.now.utc + (60 * 60 * 24)), # 24-hour auth
      amount: params[:amount],
      currency: params[:currency]
    }
  end
end

class CapturePaymentActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    logger.info "Capturing payment with authorization: #{params[:authorization_id]}"
    
    # Simulate payment processor capture
    # In real life, this would call a payment processor API
    transaction_id = "txn-#{SecureRandom.uuid}"
    
    # Simulate processing time
    sleep(rand(0.5..1.5))
    
    # Randomly fail ~2% of captures for demo purposes
    if rand < 0.02
      raise "Payment capture failed: Processor error"
    end
    
    logger.info "Payment captured with transaction ID: #{transaction_id}"
    
    return {
      transaction_id: transaction_id,
      captured_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"), # Use strftime instead of iso8601
      amount: params[:amount],
      currency: params[:currency],
      authorization_id: params[:authorization_id]
    }
  end
end

class ReleaseAuthorizationActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    logger.info "Releasing authorization: #{params[:authorization_id]}"
    
    # Simulate payment processor voiding an authorization
    # In real life, this would call a payment processor API
    
    # Simulate processing time
    sleep(rand(0.3..1.0))
    
    logger.info "Authorization released: #{params[:authorization_id]}"
    
    return {
      success: true,
      authorization_id: params[:authorization_id],
      released_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ") # Use strftime instead of iso8601
    }
  end
end

class UpdateLedgersActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    logger.info "Updating ledgers for transaction: #{params[:transaction_id]}"
    
    # Simulate accounting system updates
    # In real life, this would call accounting/ledger APIs
    
    # Simulate processing time
    sleep(rand(0.5..2.0))
    
    logger.info "Ledgers updated for transaction: #{params[:transaction_id]}"
    
    return {
      success: true,
      transaction_id: params[:transaction_id],
      ledger_entries: [
        {
          type: "debit",
          account: "customer_funds",
          amount: params[:amount],
          currency: params[:charge_currency]
        },
        {
          type: "credit",
          account: "merchant_account",
          amount: params[:settlement_amount],
          currency: params[:settlement_currency]
        },
        {
          type: "fee",
          account: "fx_fee",
          amount: (params[:settlement_amount] * 0.01).round(2),
          currency: params[:settlement_currency]
        }
      ],
      recorded_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ") # Use strftime instead of iso8601
    }
  end
end

class SendNotificationsActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    payment_data = params[:payment_data]
    state = params[:state]
    
    logger.info "Sending notifications for completed payment"
    
    # Simulate notification sending
    # In real life, this would call email/SMS/push notification services
    
    # Simulate processing time
    sleep(rand(0.2..1.0))
    
    notifications = []
    
    # Customer notification
    notifications << {
      recipient: payment_data[:customer][:email],
      type: "email",
      template: "payment_confirmation",
      sent: true
    }
    
    # Merchant notification
    notifications << {
      recipient: "merchant@example.com", # In real life, this would be looked up
      type: "api_webhook",
      payload: {
        transaction_id: state[:capture][:transaction_id],
        amount: state[:settlement_amount],
        currency: payment_data[:settlement_currency],
        status: "completed"
      },
      sent: true
    }
    
    logger.info "Notifications sent: #{notifications.size}"
    
    return {
      success: true,
      notifications: notifications,
      sent_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ") # Use strftime instead of iso8601
    }
  end
end

class RefundPaymentActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    logger.info "Refunding payment: #{params[:transaction_id]} for #{params[:amount]} #{params[:currency]}"
    
    # Simulate payment processor refund
    # In real life, this would call a payment processor API
    refund_id = "refund-#{SecureRandom.uuid}"
    
    # Simulate processing time
    sleep(rand(0.5..2.0))
    
    # Randomly fail ~1% of refunds for demo purposes
    if rand < 0.01
      raise "Refund failed: Processor error"
    end
    
    logger.info "Payment refunded with refund ID: #{refund_id}"
    
    return {
      refund_id: refund_id,
      transaction_id: params[:transaction_id],
      refunded_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"), # Use strftime instead of iso8601
      amount: params[:amount],
      currency: params[:currency]
    }
  end
end

class WaitForManualApprovalActivity < Temporalio::Activity::Definition
  include ActivityLogging
  
  # Accept only a simple payment reference string
  def execute(payment_reference)
    # Simple validation of input
    reference = payment_reference.to_s
    
    # Log the activity execution
    logger.info "Waiting for manual approval for high-value payment: #{reference}"
    logger.info "Payment #{reference} added to manual approval queue"
    
    # Simulate review time (5 seconds for demo)
    sleep(5)
    
    # In real implementation, admin would make a decision through an admin UI
    # For demo purposes, randomly approve 80% of transactions
    is_approved = rand > 0.2
    
    # Return only simple strings - no complex objects
    if is_approved
      logger.info "✅ Payment #{reference} APPROVED by manual review"
      return "approved"
    else
      logger.info "❌ Payment #{reference} REJECTED by manual review"
      return "rejected"
    end
  rescue => e
    logger.error "⚠️ Error in manual approval: #{e.message}"
    return "error"
  end
end
