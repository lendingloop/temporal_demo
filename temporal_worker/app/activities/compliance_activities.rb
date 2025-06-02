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
    # Add detailed logging of payment_data
    logger.info "Payment data: #{payment_data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = payment_data[:amount] || payment_data['amount']
    charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
    
    logger.info "Running fraud check for transaction: #{amount} #{charge_currency}"
    
    # First check if Compliance API is up with a short timeout
    begin
      conn = Faraday.new(url: 'http://localhost:3002') do |f|
        f.options.timeout = 2  # 2 second timeout for demo
        f.options.open_timeout = 1
      end
      
      # Call the fraud check endpoint
      response = conn.post('/api/checks/fraud') do |req|
        req.headers['Content-Type'] = 'application/json'
        
        # Handle both string and symbol keys for compatibility
        amount = payment_data[:amount] || payment_data['amount']
        charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
        settlement_currency = payment_data[:settlement_currency] || payment_data['settlement_currency']
        customer = payment_data[:customer] || payment_data['customer']
        merchant = payment_data[:merchant] || payment_data['merchant']
        
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
        
        # Raise a standard error that will fail the workflow
        raise RuntimeError, "#{error_message} (Risk score: #{result['risk_score']})"
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
      
      # Raise a standard error that will fail the workflow
      # This will ensure the workflow shows as failed in Temporal UI
      raise RuntimeError, "#{error_message} (Service: compliance_api)"
    end
  end
end

class RunAmlCheckActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Add detailed logging of payment_data
    logger.info "Payment data: #{payment_data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = payment_data[:amount] || payment_data['amount']
    charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
    
    logger.info "Running AML check for transaction: #{amount} #{charge_currency}"
    
    # First check if Compliance API is up with an even shorter timeout
    begin
      conn = Faraday.new(url: 'http://localhost:3002') do |f|
        f.options.timeout = 1  # 1 second timeout for demo
        f.options.open_timeout = 0.5  # Half second connection timeout
      end
      
      # First try a health check with minimal timeout
      health_response = conn.get('/api/health')
      unless health_response.status == 200
        logger.warn "⚠️ Compliance API health check failed: #{health_response.status}"
        # For demo purposes, return a mock success response instead of failing
        logger.info "✅ [MOCK] AML check passed with score: 25.45 (mock due to service unavailable)"
        return {
          success: true,
          result: 'pass',
          aml_score: 25.45,
          mock: true
        }
      end
      
      # Call the AML check endpoint
      response = conn.post('/api/checks/aml') do |req|
        req.headers['Content-Type'] = 'application/json'
        
        # Handle both string and symbol keys for compatibility
        amount = payment_data[:amount] || payment_data['amount']
        charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
        settlement_currency = payment_data[:settlement_currency] || payment_data['settlement_currency']
        customer = payment_data[:customer] || payment_data['customer']
        merchant = payment_data[:merchant] || payment_data['merchant']
        
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
        
        # For demo purposes, return a mock success response instead of failing
        logger.info "✅ [MOCK] AML check passed with override (mock due to service error)"
        return {
          success: true,
          result: 'pass',
          aml_score: 25.45,
          mock: true
        }
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
      
      # For demo purposes, return a mock success response instead of failing
      logger.info "✅ [MOCK] AML check passed with score: 25.45 (mock due to connection error)"
      return {
        success: true,
        result: 'pass',
        aml_score: 25.45,
        mock: true
      }
    end
  end
end

class RunSanctionsCheckActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(payment_data)
    # Add detailed logging of payment_data
    logger.info "Payment data: #{payment_data.inspect}"
    
    # Handle both string and symbol keys for compatibility
    amount = payment_data[:amount] || payment_data['amount']
    charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
    
    logger.info "Running sanctions check for transaction: #{amount} #{charge_currency}"
    
    # Connect to Compliance API
    conn = Faraday.new(url: 'http://localhost:3002')
    
    # Call the sanctions check endpoint
    response = conn.post('/api/checks/sanctions') do |req|
      req.headers['Content-Type'] = 'application/json'
      
      # Handle both string and symbol keys for compatibility
      amount = payment_data[:amount] || payment_data['amount']
      charge_currency = payment_data[:charge_currency] || payment_data['charge_currency']
      settlement_currency = payment_data[:settlement_currency] || payment_data['settlement_currency']
      customer = payment_data[:customer] || payment_data['customer']
      merchant = payment_data[:merchant] || payment_data['merchant']
      
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
      return {
        success: false,
        result: 'failed',
        reason: reason,
        details: result['details']
      }
    end
    
    logger.info "Sanctions check passed: #{result['details']}"
    
    return {
      success: true,
      result: result['result'],
      details: result['details']
    }
  end
end
