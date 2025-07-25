require 'temporalio/activity'
require 'faraday'
require 'json'
require 'logger'

# Create a module to include in all activity classes
module ActivityLogging
  def logger
    @logger ||= Logger.new(STDOUT).tap do |l|
      l.level = Logger::INFO
      l.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: [ACTIVITY] #{msg}\n"
      end
    end
  end
end

class RunFraudCheckActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Handle array input (API might send payment_data as first element in an array)
    data = if payment_data.is_a?(Array)
      logger.info "Converting payment_data from array to hash"
      payment_data.first
    else
      payment_data
    end
    
    # Add detailed logging of payment_data
    logger.info "Payment data: #{data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = data[:amount] || data['amount']
    charge_currency = data[:charge_currency] || data['charge_currency']
    
    logger.info "Running fraud check for transaction: #{amount} #{charge_currency}"
    
    # First check if Compliance API is up with a short timeout
    begin
      conn = Faraday.new(url: 'http://compliance_api:3002') do |f|
        f.options.timeout = 2  # 2 second timeout for demo
        f.options.open_timeout = 1
      end
      
      # Prepare all data outside the block to avoid scoping issues
      amount = data[:amount] || data['amount']
      charge_currency = data[:charge_currency] || data['charge_currency']
      settlement_currency = data[:settlement_currency] || data['settlement_currency']
      customer = data[:customer] || data['customer']
      merchant = data[:merchant] || data['merchant']
      
      # Call the fraud check endpoint
      response = conn.post('/api/checks/fraud') do |req|
        req.headers['Content-Type'] = 'application/json'
        
        # Use pre-extracted data to avoid scoping issues
        req.body = {
          amount: amount,
          charge_currency: charge_currency,
          settlement_currency: settlement_currency,
          customer: customer,
          merchant: merchant
        }.to_json
      end
      
      result = JSON.parse(response.body)
      
      if ![200, 201].include?(response.status) || !result['success']
        reason = result['reason'] || (result['success'] == false ? 'Failed check' : 'Unknown error')
        error_message = "Fraud check failed: #{reason}"
        logger.error "⚠️ #{error_message}"
        
        # Let the activity fail so Temporal will retry it
        logger.error "❌ Fraud check failed - activity will fail and Temporal will retry based on retry policy"
        raise "Fraud check failed: #{reason}"
      end
      
      logger.info "✅ Fraud check passed with risk score: #{result['risk_score']}"
      
      return {
        success: true,
        result: result['result'],
        risk_score: result['risk_score']
      }
    rescue Faraday::Error => e
      # API connection error - THIS WILL HAPPEN WHEN COMPLIANCE API IS DOWN
      error_message = "Compliance API unavailable: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # Log if this is a high-value payment, but still fail properly
      amount = data[:amount] || data['amount'] || 0.0
      high_value = amount >= 5000.0
      if high_value
        logger.info "High-value payment detected: $#{amount}"
      end
      
      # Let the activity fail so Temporal will retry it
      logger.error "❌ Compliance API unavailable - activity will fail and Temporal will retry based on retry policy"
      raise "Compliance API unavailable: #{e.message}"
    end
  end
end

class RunAmlCheckActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Handle array input (API might send payment_data as first element in an array)
    data = if payment_data.is_a?(Array)
      logger.info "Converting payment_data from array to hash"
      payment_data.first
    else
      payment_data
    end
    
    # Add detailed logging of payment_data
    logger.info "Payment data: #{data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = data[:amount] || data['amount']
    charge_currency = data[:charge_currency] || data['charge_currency']
    
    logger.info "Running AML check for transaction: #{amount} #{charge_currency}"
    
    # First check if Compliance API is up with an even shorter timeout
    begin
      conn = Faraday.new(url: 'http://compliance_api:3002') do |f|
        f.options.timeout = 5  # 5 second timeout for demo
        f.options.open_timeout = 2  # 2 second connection timeout
      end
      
      # First try a health check with minimal timeout
      health_response = conn.get('/api/health')
      unless health_response.status == 200
        raise RuntimeError, "Compliance API health check failed with status: #{health_response.status}"
      end
      
      # Prepare all data outside the block to avoid scoping issues
      amount = data[:amount] || data['amount']
      charge_currency = data[:charge_currency] || data['charge_currency']
      settlement_currency = data[:settlement_currency] || data['settlement_currency']
      customer = data[:customer] || data['customer']
      merchant = data[:merchant] || data['merchant']
      
      # Now make the actual API call
      response = conn.post('/api/checks/aml') do |req|
        req.headers['Content-Type'] = 'application/json'
        
        # Use pre-extracted data to avoid scoping issues
        req.body = {
          amount: amount,
          charge_currency: charge_currency,
          settlement_currency: settlement_currency,
          customer: customer,
          merchant: merchant
        }.to_json
      end
      
      result = JSON.parse(response.body)
      
      if ![200, 201].include?(response.status) || !result['success']
        reason = result['reason'] || (result['success'] == false ? 'Failed check' : 'Unknown error')
        error_message = "AML check failed: #{reason}"
        logger.error "⚠️ #{error_message}"
        
        # Let the activity fail so Temporal will retry it
        logger.error "❌ AML check failed - activity will fail and Temporal will retry based on retry policy"
        raise "AML check failed: #{reason}"
      end
      
      logger.info "✅ AML check passed with score: #{result['aml_score']}"
      
      return {
        success: true,
        result: result['result'],
        aml_score: result['aml_score']
      }
    rescue Faraday::Error => e
      # API connection error - THIS WILL HAPPEN WHEN COMPLIANCE API IS DOWN
      error_message = "Compliance API unavailable: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # Let the activity fail so Temporal will retry it
      logger.error "❌ Compliance API unavailable for AML check - activity will fail and Temporal will retry"
      raise "Compliance API unavailable: #{e.message}"
    end
  end
end

class RunSanctionsCheckActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Handle array input (API might send payment_data as first element in an array)
    data = if payment_data.is_a?(Array)
      logger.info "Converting payment_data from array to hash"
      payment_data.first
    else
      payment_data
    end
    
    # Add detailed logging of payment_data
    logger.info "Payment data: #{data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = data[:amount] || data['amount']
    charge_currency = data[:charge_currency] || data['charge_currency']
    
    logger.info "Running sanctions check for transaction: #{amount} #{charge_currency}"
    
    begin
      # Connect to Compliance API
      conn = Faraday.new(url: 'http://compliance_api:3002') do |f|
        f.options.timeout = 5  # 5 second timeout for demo
        f.options.open_timeout = 2  # 2 second connection timeout
      end
      
      # Prepare all data outside the block to avoid scoping issues
      amount = data[:amount] || data['amount']
      charge_currency = data[:charge_currency] || data['charge_currency']
      settlement_currency = data[:settlement_currency] || data['settlement_currency']
      customer = data[:customer] || data['customer']
      merchant = data[:merchant] || data['merchant']
      
      # Call the sanctions check endpoint
      response = conn.post('/api/checks/sanctions') do |req|
        req.headers['Content-Type'] = 'application/json'
        
        # Use pre-extracted data to avoid scoping issues
        req.body = {
          amount: amount,
          charge_currency: charge_currency,
          settlement_currency: settlement_currency,
          customer: customer,
          merchant: merchant
        }.to_json
      end
      
      result = JSON.parse(response.body)
      
      if ![200, 201].include?(response.status) || !result['success']
        reason = result['reason'] || (result['success'] == false ? 'Failed check' : 'Unknown error')
        logger.error "Sanctions check failed: #{reason}"
        
        # Let the activity fail so Temporal will retry it
        logger.error "❌ Sanctions check failed - activity will fail and Temporal will retry"
        raise "Sanctions check failed: #{reason}"
      end
      
      logger.info "Sanctions check passed: #{result['details']}"
      
      return {
        success: true,
        result: result['result'],
        details: result['details']
      }
    rescue Faraday::Error => e
      # API connection error - Handle gracefully
      error_message = "Compliance API unavailable: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # Let the activity fail so Temporal will retry it
      logger.error "❌ Compliance API unavailable for Sanctions check - activity will fail and Temporal will retry"
      raise "Compliance API unavailable for Sanctions check: #{e.message}"
    end
  end
end
