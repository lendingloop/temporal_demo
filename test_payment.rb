#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'logger'

# Simple script to test the payment flow

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

def post_request(url, payload)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  req.body = payload.to_json
  response = http.request(req)
  JSON.parse(response.body)
rescue => e
  { error: e.message }
end

def get_request(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Get.new(uri.path)
  response = http.request(req)
  JSON.parse(response.body)
rescue => e
  { error: e.message }
end

def check_service(name, url)
  logger.info("Checking #{name} health...")
  begin
    response = get_request(url)
    if response["status"] == "ok" || response["success"] == true
      logger.info("✅ #{name} is healthy!")
      return true
    else
      logger.error("❌ #{name} health check failed: #{response.inspect}")
      return false
    end
  rescue => e
    logger.error("❌ #{name} is not responding: #{e.message}")
    return false
  end
end

# Check all services
if !check_service("FX Service", "http://localhost:3001/health") ||
   !check_service("Compliance API", "http://localhost:3002/api/health") ||
   !check_service("Payment API", "http://localhost:3000/health")
  logger.error("Not all services are running. Please start all services with ./start_all.sh")
  exit 1
end

logger.info("All services are running.")

# Create a test payment
logger.info("Creating a test payment...")
payment_data = {
  amount: 1000.00,
  charge_currency: "CAD",
  settlement_currency: "USD",
  customer: {
    business_name: "Test Business",
    email: "test@example.com"
  },
  merchant: {
    name: "Test Merchant",
    country: "US"
  }
}

result = post_request("http://localhost:3000/api/payments", payment_data)

if result["success"] && result["workflow_id"]
  workflow_id = result["workflow_id"]
  logger.info("Payment initiated with workflow ID: #{workflow_id}")
  
  # Poll for payment status
  logger.info("Checking payment status...")
  5.times do |i|
    status = get_request("http://localhost:3000/api/payments/#{workflow_id}")
    logger.info("Payment status: #{status.inspect}")
    
    if status["status"] == "completed"
      logger.info("✅ Payment completed successfully!")
      break
    elsif status["status"] == "failed"
      logger.error("❌ Payment failed: #{status["message"]}")
      break
    else
      logger.info("Payment still processing... waiting 3 seconds")
      sleep 3
    end
    
    # Last check
    if i == 4
      logger.info("Payment is still processing. Check the Temporal UI for more details.")
      logger.info("Temporal UI: http://localhost:8233")
    end
  end
else
  logger.error("❌ Failed to create payment: #{result.inspect}")
end

logger.info("Test complete. See Temporal UI for workflow details: http://localhost:8233")
