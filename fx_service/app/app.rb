require 'sinatra'
require 'sinatra/json'
require 'json'
require 'securerandom'

# FX Service - Exchange Rate Provider
class FXService < Sinatra::Base
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
    json status: 'ok', service: 'fx_service'
  end
  
  # Get current exchange rate
  get '/api/rates/:from/:to' do
    from_currency = params[:from].upcase
    to_currency = params[:to].upcase
    
    if RATES[from_currency] && RATES[from_currency][to_currency]
      # Add small random fluctuation for realism
      base_rate = RATES[from_currency][to_currency]
      fluctuation = (rand - 0.5) * 0.02 # ±1% fluctuation
      rate = base_rate * (1 + fluctuation)
      
      json success: true, from: from_currency, to: to_currency, rate: rate.round(4)
    else
      status 404
      json error: "Exchange rate not found for #{from_currency} to #{to_currency}"
    end
  end
  
  # Lock in an exchange rate for a transaction
  post '/api/lock_rate' do
    payload = JSON.parse(request.body.read)
    from_currency = payload['from'].upcase
    to_currency = payload['to'].upcase
    
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
      
      json success: true, lock_id: lock_id, from: from_currency, to: to_currency, rate: rate.round(4)
    else
      status 404
      json error: "Exchange rate not found for #{from_currency} to #{to_currency}"
    end
  end
  
  # Get a previously locked rate
  get '/api/locked_rate/:lock_id' do
    lock_id = params[:lock_id]
    
    if LOCKED_RATES[lock_id]
      rate_info = LOCKED_RATES[lock_id]
      
      if Time.now > rate_info[:expires_at]
        status 400
        json error: "Rate lock has expired", lock_id: lock_id
      else
        json success: true, 
             lock_id: lock_id, 
             from: rate_info[:from], 
             to: rate_info[:to], 
             rate: rate_info[:rate],
             locked_at: rate_info[:locked_at],
             expires_at: rate_info[:expires_at]
      end
    else
      status 404
      json error: "Rate lock not found", lock_id: lock_id
    end
  end
end

# Start the server if this file is executed directly
if __FILE__ == $0
  FXService.run! host: 'localhost', port: 3001
end
