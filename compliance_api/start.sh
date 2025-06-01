#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Compliance API on port 3002..."
bundle install
ruby app/api.rb
