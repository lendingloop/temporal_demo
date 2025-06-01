#!/bin/bash
cd "$(dirname "$0")"
echo "Starting FX Service on port 3001..."
bundle install
ruby app/app.rb
