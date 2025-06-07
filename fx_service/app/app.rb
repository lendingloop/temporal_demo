require 'sinatra'
require 'json'
require 'securerandom'

# FX Service - Exchange Rate Provider using classic style Sinatra app

# Force Sinatra to bind to 0.0.0.0 instead of default localhost
set :bind, '0.0.0.0'
set :port, 3001
# Log every request
before do
  puts "[FXService] Request: #{request.request_method} #{request.path}"
end
# In-memory rate storage
RATES = {
  'CAD' => {
    'USD' => 0.75,
    'EUR' => 0.68,
    'GBP' => 0.58
  },
  'USD' => {
    'CAD' => 1.33,
    'EUR' => 0.91,
    'GBP' => 0.78
  }
}.freeze

# Store for locked rates
LOCKED_RATES = {}
# Health check endpoint
get '/health' do
  puts "[FXService] Health check requested"
  content_type :json
  { status: 'ok', service: 'fx_service' }.to_json
end

# Get current exchange rate
get '/api/rates/:from/:to' do
  from_currency = params[:from].upcase
  to_currency = params[:to].upcase
  
  puts "[FXService] Rate requested from #{from_currency} to #{to_currency}"
  
  if RATES[from_currency] && RATES[from_currency][to_currency]
    # Add small random fluctuation for realism
    base_rate = RATES[from_currency][to_currency]
    fluctuation = (rand - 0.5) * 0.02 # ±1% fluctuation
    rate = base_rate * (1 + fluctuation)
    
    content_type :json
    { success: true, from: from_currency, to: to_currency, rate: rate.round(4) }.to_json
  else
    status 404
    content_type :json
    { error: "Exchange rate not found for #{from_currency} to #{to_currency}" }.to_json
  end
end

# Lock in an exchange rate for a transaction
post '/api/lock_rate' do
  begin
    payload = JSON.parse(request.body.read)
    from_currency = payload['from'].upcase
    to_currency = payload['to'].upcase
    
    puts "[FXService] Lock rate requested from #{from_currency} to #{to_currency}"
    
    if RATES[from_currency] && RATES[from_currency][to_currency]
      # Generate a rate lock ID
      lock_id = SecureRandom.uuid
      
      # Add small random fluctuation for realism
      base_rate = RATES[from_currency][to_currency]
      fluctuation = (rand - 0.5) * 0.02 # ±1% fluctuation
      rate = base_rate * (1 + fluctuation)
      
      # Store the locked rate
      LOCKED_RATES[lock_id] = {
        from: from_currency,
        to: to_currency,
        rate: rate.round(4),
        locked_at: Time.now,
        expires_at: Time.now + (60 * 60) # 1 hour lock
      }
      
      content_type :json
      { success: true, lock_id: lock_id, from: from_currency, to: to_currency, rate: rate.round(4) }.to_json
    else
      status 404
      content_type :json
      { error: "Exchange rate not found for #{from_currency} to #{to_currency}" }.to_json
    end
  rescue => e
    status 400
    content_type :json
    { error: "Invalid request: #{e.message}" }.to_json
  end
end

# Get a previously locked rate
get '/api/locked_rate/:lock_id' do
  lock_id = params[:lock_id]
  
  puts "[FXService] Locked rate requested for ID: #{lock_id}"
  
  if LOCKED_RATES[lock_id]
    rate_info = LOCKED_RATES[lock_id]
    
    if Time.now > rate_info[:expires_at]
      status 400
      content_type :json
      { error: "Rate lock has expired", lock_id: lock_id }.to_json
    else
      content_type :json
      { 
        success: true, 
        lock_id: lock_id, 
        from: rate_info[:from], 
        to: rate_info[:to], 
        rate: rate_info[:rate],
        locked_at: rate_info[:locked_at],
        expires_at: rate_info[:expires_at]
      }.to_json
    end
  else
    status 404
    content_type :json
    { error: "Rate lock not found", lock_id: lock_id }.to_json
  end
end

# Log server startup
puts "Starting FX Service..."
puts "Binding to 0.0.0.0:3001"

# We no longer need this since we're using classic mode
# if __FILE__ == $0
#   FXService.run! host: '0.0.0.0', port: 3001
# end
