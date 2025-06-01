#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Temporal Worker..."

# Use the default Ruby version in the PATH

# Install dependencies
bundle install

# Start the worker
bundle exec ruby worker.rb
