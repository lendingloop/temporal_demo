#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Payment API on port 3000..."
bundle install

# Create config/environment.rb file if it doesn't exist
mkdir -p config
if [ ! -f config/environment.rb ]; then
  cat > config/environment.rb << 'EOL'
# Simple environment file for our minimal Rails app
require 'rails'
require 'active_support/all'
require 'action_controller/railtie'
require 'temporal-ruby'

module PaymentApi
  class Application < Rails::Application
    config.logger = Logger.new(STDOUT)
    config.api_only = true
    
    # Configure Temporal client
    Temporal.configure do |config|
      config.host = 'localhost'
      config.port = 7233
      config.namespace = 'default'
    end
    
    # Initialize configuration defaults
    config.load_defaults 7.0
    
    # Routing middleware
    config.middleware.use ActionDispatch::RoutingClearance
    config.middleware.use ActionDispatch::Callbacks
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
    config.middleware.use ActionDispatch::Flash
    
    # Add autoload paths
    config.autoload_paths += %W(#{config.root}/app/controllers)
    
    # Load routes
    routes.draw do
      eval(File.read(File.join(Rails.root, 'config/routes.rb')))
    end
  end
end

# Initialize the Rails application
PaymentApi::Application.initialize!
EOL
fi

# Create config.ru file if it doesn't exist
if [ ! -f config.ru ]; then
  cat > config.ru << 'EOL'
require_relative 'config/environment'
run PaymentApi::Application
EOL
fi

# Start Puma server with a simple configuration
bundle exec puma -p 3000
