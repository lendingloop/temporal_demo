require 'grape'
require 'json'
require 'rack'
require 'rack/handler/puma'

module ComplianceAPI
  class API < Grape::API
    format :json
    prefix :api
    
    # High-risk indicators
    HIGH_RISK_INDICATORS = {
      amount: 10000.00,            # Transactions over $10,000 trigger additional scrutiny
      suspicious_merchants: ['Suspicious Merchant', 'High Risk Vendor'],
      suspicious_countries: ['XZ', 'YZ'],  # Fictional sanctioned countries
      suspicious_businesses: ['High Risk Corp']
    }

    resource :health do
      desc 'Health check endpoint'
      get do
        { status: 'ok', service: 'compliance_api' }
      end
    end

    resource :checks do
      desc 'Run fraud detection check'
      params do
        requires :amount, type: Float, desc: 'Transaction amount'
        requires :charge_currency, type: String, desc: 'Transaction currency'
        requires :settlement_currency, type: String, desc: 'Settlement currency'
        requires :customer, type: Hash do
          requires :business_name, type: String
          requires :email, type: String
        end
        requires :merchant, type: Hash do
          requires :name, type: String
          requires :country, type: String
        end
      end
      post :fraud do
        # Simulate processing time
        sleep(rand(1..3))
        
        # Check for fraud indicators
        is_high_risk = params[:amount] > HIGH_RISK_INDICATORS[:amount]
        is_high_risk ||= HIGH_RISK_INDICATORS[:suspicious_businesses].include?(params[:customer][:business_name])
        
        # For demo purposes, we'll randomly fail some high-risk transactions
        if is_high_risk && rand > 0.7
          status 400
          { 
            success: false, 
            result: 'failed', 
            reason: 'Suspicious transaction pattern detected',
            risk_score: (rand * 50 + 50).round(2) # 50-100 risk score
          }
        else
          { 
            success: true, 
            result: 'passed',
            risk_score: is_high_risk ? (rand * 30 + 40).round(2) : (rand * 30).round(2) # 40-70 for high risk, 0-30 for normal
          }
        end
      end
      
      desc 'Run AML (Anti Money Laundering) check'
      params do
        requires :amount, type: Float
        requires :charge_currency, type: String
        requires :settlement_currency, type: String
        requires :customer, type: Hash do
          requires :business_name, type: String
          requires :email, type: String
        end
        requires :merchant, type: Hash do
          requires :name, type: String
          requires :country, type: String
        end
      end
      post :aml do
        # Simulate processing time
        sleep(rand(2..4))
        
        # Check for AML risk indicators
        is_high_risk = params[:amount] > HIGH_RISK_INDICATORS[:amount]
        is_high_risk ||= HIGH_RISK_INDICATORS[:suspicious_merchants].include?(params[:merchant][:name])
        
        # For demo purposes, we'll randomly fail some high-risk transactions
        if is_high_risk && rand > 0.7
          status 400
          { 
            success: false, 
            result: 'failed', 
            reason: 'Potential money laundering risk detected',
            aml_score: (rand * 50 + 50).round(2) # 50-100 risk score
          }
        else
          { 
            success: true, 
            result: 'passed',
            aml_score: is_high_risk ? (rand * 30 + 40).round(2) : (rand * 30).round(2)
          }
        end
      end
      
      desc 'Run sanctions screening'
      params do
        requires :amount, type: Float
        requires :charge_currency, type: String
        requires :settlement_currency, type: String
        requires :customer, type: Hash do
          requires :business_name, type: String
          requires :email, type: String
        end
        requires :merchant, type: Hash do
          requires :name, type: String
          requires :country, type: String
        end
      end
      post :sanctions do
        # Simulate processing time
        sleep(rand(1..5))
        
        # Check for sanctions risk
        is_sanctioned = HIGH_RISK_INDICATORS[:suspicious_countries].include?(params[:merchant][:country])
        
        # For demo purposes, we'll fail all sanctioned transactions
        if is_sanctioned
          status 400
          { 
            success: false, 
            result: 'failed', 
            reason: 'Sanctioned country detected',
            details: "Transactions to #{params[:merchant][:country]} are not permitted"
          }
        else
          { 
            success: true, 
            result: 'passed',
            details: 'No sanctions detected'
          }
        end
      end
    end
  end
end

# Start the server if this file is executed directly
if __FILE__ == $0
  require 'rack'
  require 'puma'
  
  # Create Rack application
  app = Rack::Builder.new do
    run ComplianceAPI::API
  end
  
  # Start Puma server
  Rack::Handler::Puma.run(app, Port: 3002, Host: 'localhost')
end
