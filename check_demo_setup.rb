#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'logger'

# Script to verify all services are running correctly for the demo

logger = Logger.new(STDOUT)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  if severity == "INFO"
    "\e[32m[#{severity}]\e[0m #{msg}\n"
  elsif severity == "WARN"
    "\e[33m[#{severity}]\e[0m #{msg}\n"
  elsif severity == "ERROR"
    "\e[31m[#{severity}]\e[0m #{msg}\n"
  else
    "[#{severity}] #{msg}\n"
  end
end

def get_request(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Get.new(uri.path)
  
  http.open_timeout = 2
  http.read_timeout = 2
  
  response = http.request(req)
  JSON.parse(response.body)
rescue => e
  { error: e.message }
end

def check_service(name, url)
  print "Checking #{name} status... "
  begin
    response = get_request(url)
    if response["status"] == "ok" || response["success"] == true
      puts "✅ RUNNING"
      return true
    else
      puts "❌ ERROR: Service returned unexpected response"
      return false
    end
  rescue => e
    puts "❌ NOT RUNNING"
    return false
  end
end

puts "\n========== TEMPORAL PAYMENT DEMO SETUP CHECK ==========\n\n"

# Check all required services
services_ok = true

# Check Payment API
services_ok = check_service("Payment API", "http://localhost:3000/health") && services_ok

# Check FX Service
services_ok = check_service("FX Service", "http://localhost:3001/health") && services_ok  

# Check Compliance API
services_ok = check_service("Compliance API", "http://localhost:3002/api/health") && services_ok

# Check Temporal UI web access
print "Checking Temporal UI access... "
begin
  uri = URI.parse("http://localhost:8233")
  response = Net::HTTP.get_response(uri)
  if response.code == "200"
    puts "✅ RUNNING"
  else
    puts "❌ ERROR: Received code #{response.code}"
    services_ok = false
  end
rescue => e
  puts "❌ NOT RUNNING"
  services_ok = false
end

puts "\n======================================================"
if services_ok
  puts "\n✅ All services are running! Ready for demo."
  puts "To start the demo, run: ruby test_payment.rb"
  puts "To view workflows in the UI, visit: http://localhost:8233"
else
  puts "\n❌ Some services are not running correctly!"
  puts "Please run ./start_all.sh to launch all required services."
end
puts "======================================================"
