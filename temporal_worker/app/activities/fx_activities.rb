# DEMO: FX ACTIVITIES
# This file contains activities that interact with the FX Service
# These activities demonstrate key Temporal SDK patterns:
# 1. External service interaction with proper error handling
# 2. Docker inter-container networking with service discovery
# 3. Retry patterns for resilient API calls

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

# DEMO: FX RATE ACTIVITY
# This activity calls the FX service to get and lock an exchange rate
# Demonstrates making HTTP calls from a Temporal activity
class GetExchangeRateActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    # Activity logging shows up in worker container logs
    logger.info "FX params: #{params.inspect}"
    
    # Handle both string and symbol keys for compatibility
    from_currency = params[:from] || params['from']
    to_currency = params[:to] || params['to']
    
    logger.info "Getting exchange rate from #{from_currency} to #{to_currency}"
    
    begin
      # DEMO: INTER-SERVICE COMMUNICATION IN DOCKER
      # Notice we connect to 'fx_service:3001' - this uses Docker's DNS resolution
      # The service name (fx_service) comes from docker-compose.yml
      conn = Faraday.new(url: 'http://fx_service:3001') do |f|
        f.options.timeout = 2  # 2 second timeout for demo
        f.options.open_timeout = 1
      end
      
      # CRITICAL FIX: THE HOST HEADER SOLUTION
      # This is the key fix that makes inter-container communication work
      # Sinatra's protection middleware blocks requests with mismatched hosts
      # Adding 'Host: localhost' header bypasses this protection
      response = conn.post('/api/lock_rate') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['Host'] = 'localhost'  # THE CRITICAL FIX!
        req.body = {
          from: from_currency,
          to: to_currency
        }.to_json
      end
      
      # DEMO: ERROR HANDLING AND RESPONSE VALIDATION
      # Always check API response status codes and handle them properly
      if response.status != 200
        error_body = JSON.parse(response.body)
        error_message = "Failed to get exchange rate: #{error_body['error'] || 'Unknown error'}"
        logger.error "⚠️ #{error_message}"
        
        # DEMO: TEMPORAL RETRY BEHAVIOR
        # This is where Temporal's power shines - we can simply raise an exception
        # and Temporal will automatically retry the activity based on retry policy
        # No complex retry logic needed in our code!
        logger.error "❌ FX Service returned error status #{response.status} - activity will fail and Temporal will retry based on retry policy"
        raise "FX Service error: #{error_message}"
      end
      
      result = JSON.parse(response.body)
      
      logger.info "✅ Got exchange rate: #{result['rate']} and lock ID: #{result['lock_id']}"
      
      # Return structured data to the workflow
      return {
        rate: result['rate'],
        lock_id: result['lock_id'],
        from: result['from'],
        to: result['to']
      }
    rescue Faraday::Error => e
      # DEMO: CONNECTION ERRORS
      # Handle network level errors like timeouts or service unavailability
      # This might happen if the FX service container is starting up or unreachable
      error_message = "FX Service unavailable: #{e.message}"
      logger.error "⚠️⚠️⚠️ #{error_message}"
      
      # DEMO: LETTING TEMPORAL HANDLE RETRIES
      # This is the key Temporal pattern - let the activity fail cleanly
      # Temporal will automatically retry based on the retry policy configured in the worker
      # This allows service recovery without complex handling in our code
      logger.error "❌ FX Service failure - activity will fail and Temporal will retry based on retry policy"
      raise "FX Service unavailable: #{e.message}"
    end
  end
end

# DEMO: RELEASE RATE LOCK ACTIVITY
# This activity is called at the end of the workflow to clean up resources
# It demonstrates proper cleanup actions after a workflow completes
class ReleaseRateLockActivity < Temporalio::Activity::Definition
  include ActivityLogging
  def execute(params)
    # Detailed logging in activities helps with debugging
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
      # DEMO: SAME CONNECTIVITY APPROACH AS GET EXCHANGE RATE
      # Note how we use the Docker service name (fx_service) for networking
      conn = Faraday.new(url: 'http://fx_service:3001')
      
      # CRITICAL FIX: THE HOST HEADER APPLIED HERE TOO
      # This same fix is needed in all Faraday requests to the FX service
      # Without the Host header, we'd get a 403 Forbidden error
      response = conn.post('/api/release_lock') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['Host'] = 'localhost'  # THE CRITICAL FIX AGAIN!
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
