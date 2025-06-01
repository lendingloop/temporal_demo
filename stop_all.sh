#!/bin/bash
echo "======================================"
echo "Temporal Payments Demo - Shutdown Script"
echo "======================================"

# Check if PID file exists
if [ -f services_pids.txt ]; then
    echo "Stopping all background services..."
    
    # Source the PID file
    source services_pids.txt
    
    # Function to kill process safely
    kill_service() {
        local pid=$1
        local name=$2
        if ps -p $pid > /dev/null 2>&1; then
            echo "Stopping $name (PID: $pid)"
            kill $pid
            # Wait for it to exit
            for i in {1..5}; do
                if ! ps -p $pid > /dev/null 2>&1; then
                    echo "$name stopped successfully."
                    return 0
                fi
                sleep 1
            done
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                echo "$name still running, force killing..."
                kill -9 $pid
                sleep 1
                if ! ps -p $pid > /dev/null 2>&1; then
                    echo "$name force stopped."
                else
                    echo "Failed to stop $name."
                fi
            fi
        else
            echo "$name (PID: $pid) is not running."
        fi
    }
    
    # Stop each service
    kill_service $FX_SERVICE_PID "FX Service"
    kill_service $COMPLIANCE_API_PID "Compliance API"
    kill_service $PAYMENT_API_PID "Payment API"
    kill_service $TEMPORAL_WORKER_PID "Temporal Worker"
    
    # Remove the PID file
    rm services_pids.txt
    echo "All services stopped."
else
    echo "No background services found. If services are running in separate terminals, you'll need to stop them manually."
fi

# Reminder about the Temporal server
echo ""
echo "Note: This script does not stop the Temporal server."
echo "If you want to stop the Temporal server, run:"
echo "temporal server stop-dev"
