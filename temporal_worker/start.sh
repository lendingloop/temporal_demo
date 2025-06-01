#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Temporal Worker..."
bundle install
ruby worker.rb
