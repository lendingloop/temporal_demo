require 'temporal/activity'
require 'faraday'
require 'json'

class RunFraudCheckActivity < Temporal::Activity
  def execute(payment_data)
    logger.info "Running fraud check for transaction: #{payment_data[:amount]} #{payment_data[:charge_currency]}"
    
    # Connect to Compliance API
    conn = Faraday.new(url: 'http://localhost:3002')
    
    # Call the fraud check endpoint
    response = conn.post('/api/checks/fraud') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        amount: payment_data[:amount],
        charge_currency: payment_data[:charge_currency],
        settlement_currency: payment_data[:settlement_currency],
        customer: payment_data[:customer],
        merchant: payment_data[:merchant]
      }.to_json
    end
    
    result = JSON.parse(response.body)
    
    if response.status != 200
      logger.error "Fraud check failed: #{result['reason'] || 'Unknown error'}"
      return {
        success: false,
        result: 'failed',
        reason: result['reason'] || 'Unknown error',
        risk_score: result['risk_score']
      }
    end
    
    logger.info "Fraud check passed with risk score: #{result['risk_score']}"
    
    return {
      success: true,
      result: result['result'],
      risk_score: result['risk_score']
    }
  end
end

class RunAmlCheckActivity < Temporal::Activity
  def execute(payment_data)
    logger.info "Running AML check for transaction: #{payment_data[:amount]} #{payment_data[:charge_currency]}"
    
    # Connect to Compliance API
    conn = Faraday.new(url: 'http://localhost:3002')
    
    # Call the AML check endpoint
    response = conn.post('/api/checks/aml') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        amount: payment_data[:amount],
        charge_currency: payment_data[:charge_currency],
        settlement_currency: payment_data[:settlement_currency],
        customer: payment_data[:customer],
        merchant: payment_data[:merchant]
      }.to_json
    end
    
    result = JSON.parse(response.body)
    
    if response.status != 200
      logger.error "AML check failed: #{result['reason'] || 'Unknown error'}"
      return {
        success: false,
        result: 'failed',
        reason: result['reason'] || 'Unknown error',
        aml_score: result['aml_score']
      }
    end
    
    logger.info "AML check passed with score: #{result['aml_score']}"
    
    return {
      success: true,
      result: result['result'],
      aml_score: result['aml_score']
    }
  end
end

class RunSanctionsCheckActivity < Temporal::Activity
  def execute(payment_data)
    logger.info "Running sanctions check for transaction: #{payment_data[:amount]} #{payment_data[:charge_currency]}"
    
    # Connect to Compliance API
    conn = Faraday.new(url: 'http://localhost:3002')
    
    # Call the sanctions check endpoint
    response = conn.post('/api/checks/sanctions') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        amount: payment_data[:amount],
        charge_currency: payment_data[:charge_currency],
        settlement_currency: payment_data[:settlement_currency],
        customer: payment_data[:customer],
        merchant: payment_data[:merchant]
      }.to_json
    end
    
    result = JSON.parse(response.body)
    
    if response.status != 200
      logger.error "Sanctions check failed: #{result['reason'] || 'Unknown error'}"
      return {
        success: false,
        result: 'failed',
        reason: result['reason'] || 'Unknown error',
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
