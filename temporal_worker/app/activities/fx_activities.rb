require 'temporalio/activity'
require 'faraday'
require 'json'
require 'securerandom'
require 'logger'

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

class GetExchangeRateActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    # Add detailed logging of params
    logger.info "FX params: #{params.inspect}"
    
    # Handle both string and symbol keys for compatibility
    from_currency = params[:from] || params['from']
    to_currency = params[:to] || params['to']
    
    logger.info "Getting exchange rate from #{from_currency} to #{to_currency}"
    
    begin
      # Connect to FX Service to get exchange rate - Use Docker service name instead of localhost
      conn = Faraday.new(url: 'http://fx_service:3001') do |f|
        f.options.timeout = 2  # 2 second timeout for demo
        f.options.open_timeout = 1
      end
      
      # Lock in an exchange rate
      response = conn.post('/api/lock_rate') do |req|
        req.headers['Content-Type'] = 'application/json'
        # Add the Host header to bypass Sinatra's host protection
        req.headers['Host'] = 'localhost'
        req.body = {
          from: from_currency,
          to: to_currency
        }.to_json
      end
      
      if response.status != 200
        error_body = JSON.parse(response.body)
        error_message = "Failed to get exchange rate: #{error_body['error'] || 'Unknown error'}"
        logger.error "⚠️ #{error_message}"
        
        # Let the activity fail so Temporal will retry it
        logger.error "❌ FX Service returned error status #{response.status} - activity will fail and Temporal will retry based on retry policy"
        raise "FX Service error: #{error_message}"
      end
      
      result = JSON.parse(response.body)
      
      logger.info "✅ Got exchange rate: #{result['rate']} and lock ID: #{result['lock_id']}"
      
      return {
        rate: result['rate'],
        lock_id: result['lock_id'],
        from: result['from'],
        to: result['to']
      }
    rescue Faraday::Error => e
      # API connection error - THIS WILL HAPPEN WHEN FX SERVICE IS DOWN
      error_message = "FX Service unavailable: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # Instead of mocking, let the activity fail so Temporal will retry it
      # This is the proper pattern for Temporal workflows
      logger.error "❌ FX Service failure - activity will fail and Temporal will retry based on retry policy"
      raise "FX Service unavailable: #{e.message}"
    end
  end
end

class ReleaseRateLockActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    # Add detailed logging of params
    logger.info "Release params: #{params.inspect}"
    
    # Handle both string and symbol keys for compatibility
    lock_id = params[:lock_id] || params['lock_id']
    
    logger.info "Releasing exchange rate lock: #{lock_id}"
    
    # We no longer have mock responses, but we'll handle this gracefully
    # in case there are existing workflows with mock=true
    if params[:mock] || params['mock']
      logger.info "Mock lock detected, but proceeding with release attempt anyway"
    end
    
    begin
      # Connect to FX Service to release the rate lock - Use Docker service name instead of localhost
      conn = Faraday.new(url: 'http://fx_service:3001')
      
      # Release the exchange rate lock
      response = conn.post('/api/release_lock') do |req|
        req.headers['Content-Type'] = 'application/json'
        # Add the Host header to bypass Sinatra's host protection
        req.headers['Host'] = 'localhost'
        req.body = {
          lock_id: lock_id
        }.to_json
      end
      
      if response.status != 200
        error_body = JSON.parse(response.body)
        logger.error "Failed to release rate lock: #{error_body['error'] || 'Unknown error'}"
        # Don't raise an exception here as this is a compensation activity
        # We want to continue with other compensations even if this one fails
        return { success: false, error: error_body['error'] || 'Unknown error' }
      end
      
      logger.info "Successfully released rate lock: #{lock_id}"
      
      return {
        success: true,
        lock_id: lock_id,
        released_at: Time.now.utc.iso8601
      }
    rescue Faraday::Error => e
      # API connection error - FX Service might be down
      error_message = "FX Service unavailable when releasing lock: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # Let the activity fail so Temporal will retry it
      logger.error "❌ FX Service unavailable when releasing lock - activity will fail and Temporal will retry"
      raise "FX Service unavailable when releasing lock: #{e.message}"
    end
  end
end
