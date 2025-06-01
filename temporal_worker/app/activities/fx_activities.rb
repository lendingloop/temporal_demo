require 'temporal/activity'
require 'faraday'
require 'json'
require 'securerandom'

class GetExchangeRateActivity < Temporal::Activity
  def execute(params)
    logger.info "Getting exchange rate from #{params[:from]} to #{params[:to]}"
    
    # Connect to FX Service to get exchange rate
    conn = Faraday.new(url: 'http://localhost:3001')
    
    # Lock in an exchange rate
    response = conn.post('/api/lock_rate') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        from: params[:from],
        to: params[:to]
      }.to_json
    end
    
    if response.status != 200
      error_body = JSON.parse(response.body)
      raise "Failed to get exchange rate: #{error_body['error'] || 'Unknown error'}"
    end
    
    result = JSON.parse(response.body)
    
    logger.info "Got exchange rate: #{result['rate']} and lock ID: #{result['lock_id']}"
    
    return {
      rate: result['rate'],
      lock_id: result['lock_id'],
      from: result['from'],
      to: result['to']
    }
  end
end
