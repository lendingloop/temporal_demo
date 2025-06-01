#!/bin/bash
set -e

echo "======================================"
echo "Temporal Payments Demo - Startup Script"
echo "======================================"

# Make all service scripts executable
chmod +x fx_service/start.sh
chmod +x compliance_api/start.sh
chmod +x payment_api/start.sh
chmod +x temporal_worker/start.sh

# Check if Temporal server is running
if ! nc -z localhost 7233 >/dev/null 2>&1; then
    echo "⚠️ Temporal server not detected on port 7233"
    echo "Please start the Temporal server first with:"
    echo "temporal server start-dev"
    echo ""
    echo "If you haven't installed Temporal CLI yet, please follow the instructions in DEMO.md"
    exit 1
fi

echo "✅ Temporal server detected on port 7233"
echo ""
echo "Starting all services..."
echo ""
echo "Choose an option:"
echo "1) Start all services in separate terminal tabs (macOS only)"
echo "2) Start all services in the background"
echo "3) Exit"

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        # macOS only - open new terminal tabs for each service
        echo "Starting services in new terminal tabs..."
        osascript -e 'tell application "Terminal" to do script "cd \"'"$PWD"'\" && ./fx_service/start.sh"'
        osascript -e 'tell application "Terminal" to do script "cd \"'"$PWD"'\" && ./compliance_api/start.sh"'
        osascript -e 'tell application "Terminal" to do script "cd \"'"$PWD"'\" && ./payment_api/start.sh"'
        osascript -e 'tell application "Terminal" to do script "cd \"'"$PWD"'\" && ./temporal_worker/start.sh"'
        echo "All services started in separate terminal tabs."
        ;;
    2)
        # Start all services in background
        echo "Starting services in the background..."
        mkdir -p logs
        
        echo "Starting FX Service..."
        ./fx_service/start.sh > logs/fx_service.log 2>&1 &
        FX_PID=$!
        echo "FX Service started with PID: $FX_PID"
        
        echo "Starting Compliance API..."
        ./compliance_api/start.sh > logs/compliance_api.log 2>&1 &
        COMPLIANCE_PID=$!
        echo "Compliance API started with PID: $COMPLIANCE_PID"
        
        echo "Starting Payment API..."
        ./payment_api/start.sh > logs/payment_api.log 2>&1 &
        PAYMENT_PID=$!
        echo "Payment API started with PID: $PAYMENT_PID"
        
        echo "Starting Temporal Worker..."
        ./temporal_worker/start.sh > logs/temporal_worker.log 2>&1 &
        WORKER_PID=$!
        echo "Temporal Worker started with PID: $WORKER_PID"
        
        # Write PIDs to file
        cat > services_pids.txt << EOL
FX_SERVICE_PID=$FX_PID
COMPLIANCE_API_PID=$COMPLIANCE_PID
PAYMENT_API_PID=$PAYMENT_PID
TEMPORAL_WORKER_PID=$WORKER_PID
EOL
        
        echo ""
        echo "All services started in background. Log files available in the 'logs' directory."
        echo "To stop all services, run: ./stop_all.sh"
        ;;
    3)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting..."
        exit 1
        ;;
esac

echo ""
echo "Once all services are running, you can access:"
echo "- Payment API: http://localhost:3000"
echo "- FX Service: http://localhost:3001"
echo "- Compliance API: http://localhost:3002"
echo "- Temporal UI: http://localhost:8233"
echo ""
echo "Follow the instructions in DEMO.md to test the payment workflow."
