require 'rails'
require 'action_controller/railtie'
require 'temporal-ruby'

module PaymentApi
  class Application < Rails::Application
    # Initialize configuration defaults
    config.load_defaults 7.0
    
    # API-only application
    config.api_only = true
    
    # Configure logger
    config.logger = Logger.new(STDOUT)
    config.log_level = :info
    
    # Configure Temporal connection
    Temporal.configure do |config|
      config.host = 'localhost'
      config.port = 7233
      config.namespace = 'default'
    end
    
    # Don't generate system test files
    config.generators.system_tests = nil
  end
end
