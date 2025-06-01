#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Payment API on port 3000..."

# Use the default Ruby version in the PATH

# Set the port (default: 3000)
PORT=${PORT:-3000}

# Install dependencies
bundle install

# Start the Sinatra app using puma
bundle exec ruby app.rb -p $PORT
