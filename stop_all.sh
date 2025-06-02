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
    echo "PID file not found. Looking for running processes by port and name..."
    
    # Find and stop processes by port
    echo "Checking for services running on known ports..."
    
    # FX Service on port 3001
    FX_PID=$(lsof -ti:3001)
    if [ ! -z "$FX_PID" ]; then
        echo "Found FX Service running on port 3001 with PID: $FX_PID"
        kill $FX_PID 2>/dev/null || kill -9 $FX_PID 2>/dev/null
        echo "FX Service stopped."
    fi
    
    # Compliance API on port 3002
    COMPLIANCE_PID=$(lsof -ti:3002)
    if [ ! -z "$COMPLIANCE_PID" ]; then
        echo "Found Compliance API running on port 3002 with PID: $COMPLIANCE_PID"
        kill $COMPLIANCE_PID 2>/dev/null || kill -9 $COMPLIANCE_PID 2>/dev/null
        echo "Compliance API stopped."
    fi
    
    # Payment API on port 3000
    PAYMENT_PID=$(lsof -ti:3000)
    if [ ! -z "$PAYMENT_PID" ]; then
        echo "Found Payment API running on port 3000 with PID: $PAYMENT_PID"
        kill $PAYMENT_PID 2>/dev/null || kill -9 $PAYMENT_PID 2>/dev/null
        echo "Payment API stopped."
    fi
    
    # Find any Ruby processes matching our app names
    echo "Checking for Ruby processes matching our application names..."
    
    # Look for Ruby processes with specific keywords
    for KEYWORD in "temporal_worker" "fx_service" "compliance_api" "payment_api"; do
        PIDS=$(ps aux | grep ruby | grep $KEYWORD | grep -v grep | awk '{print $2}')
        if [ ! -z "$PIDS" ]; then
            echo "Found Ruby processes for $KEYWORD: $PIDS"
            for PID in $PIDS; do
                kill $PID 2>/dev/null || kill -9 $PID 2>/dev/null
                echo "Stopped process with PID: $PID"
            done
        fi
    done
    
    # Aggressively kill all worker-related processes
    echo "Forcefully killing ALL worker processes..."
    
    # Kill any ruby process with 'worker' in the name or command line
    WORKER_PIDS=$(ps aux | grep -E 'ruby.*worker|worker.rb|temporal.*worker' | grep -v grep | awk '{print $2}')
    if [ ! -z "$WORKER_PIDS" ]; then
        echo "Found worker processes: $WORKER_PIDS"
        for PID in $WORKER_PIDS; do
            kill -9 $PID 2>/dev/null
            echo "Force killed worker process with PID: $PID"
        done
    else
        echo "No worker processes found with worker pattern."
    fi
    
    # Find and kill ALL ruby processes related to Temporal
    TEMPORAL_RUBY_PIDS=$(ps aux | grep -E 'ruby.*temporal|temporal.*ruby' | grep -v grep | awk '{print $2}')
    if [ ! -z "$TEMPORAL_RUBY_PIDS" ]; then
        echo "Found Temporal Ruby processes: $TEMPORAL_RUBY_PIDS"
        for PID in $TEMPORAL_RUBY_PIDS; do
            kill -9 $PID 2>/dev/null
            echo "Force killed Temporal Ruby process with PID: $PID"
        done
    fi
    
    # Kill any process connected to Temporal worker ports (client ports)  
    TEMPORAL_PORT_PIDS=$(lsof -ti:7233,8233,7234,8234 2>/dev/null)
    if [ ! -z "$TEMPORAL_PORT_PIDS" ]; then
        echo "Found processes on Temporal ports: $TEMPORAL_PORT_PIDS"
        for PID in $TEMPORAL_PORT_PIDS; do
            # Make sure we're not killing the Temporal server itself
            if ! ps -p $PID | grep -q "temporal-server"; then
                kill -9 $PID 2>/dev/null
                echo "Force killed process on Temporal port with PID: $PID"
            else
                echo "Skipping Temporal server process with PID: $PID"
            fi
        done
    fi
    
    # Check for any socket files that might be left behind
    echo "Checking for socket files..."
    find . -name "*.sock" -type s -exec rm -f {} \; 2>/dev/null
    echo "Removed any socket files"
    
    # Extra check for any MultiCurrencyPaymentWorkflow or any Temporal process
    TEMPORAL_PIDS=$(ps aux | grep -E '(MultiCurrency|[tT]emporal)' | grep -v grep | awk '{print $2}')
    if [ ! -z "$TEMPORAL_PIDS" ]; then
        echo "Found Temporal-related processes: $TEMPORAL_PIDS"
        for PID in $TEMPORAL_PIDS; do
            kill -9 $PID 2>/dev/null
            echo "Force killed Temporal-related process with PID: $PID"
        done
    fi
    
    # Kill ALL ruby worker.rb processes
    RUBY_WORKER_PIDS=$(ps aux | grep 'ruby worker.rb' | grep -v grep | awk '{print $2}')
    if [ ! -z "$RUBY_WORKER_PIDS" ]; then
        echo "Found Ruby worker.rb processes: $RUBY_WORKER_PIDS"
        for PID in $RUBY_WORKER_PIDS; do
            kill -9 $PID 2>/dev/null
            echo "Force killed Ruby worker.rb process with PID: $PID"
        done
    fi
    
    # Look for any .pid files in the logs directory and kill those processes
    if [ -d "logs" ]; then
        echo "Checking for PID files in logs directory..."
        for PID_FILE in logs/*.pid; do
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                echo "Found PID file $PID_FILE with PID: $PID"
                kill -9 $PID 2>/dev/null || true
                rm "$PID_FILE" 2>/dev/null
                echo "Removed PID file: $PID_FILE"
            fi
        done
    fi
    
    # Kill any remaining ruby processes in the temporal_worker directory
    WORKER_DIR_PIDS=$(ps aux | grep ruby | grep temporal_worker | grep -v grep | awk '{print $2}')
    if [ ! -z "$WORKER_DIR_PIDS" ]; then
        echo "Found Ruby processes in temporal_worker directory: $WORKER_DIR_PIDS"
        for PID in $WORKER_DIR_PIDS; do
            kill -9 $PID 2>/dev/null
            echo "Force killed temporal_worker process with PID: $PID"
        done
    fi
    
    # Kill all Ruby processes as a last resort
    echo "Killing ALL Ruby processes as a last resort..."
    pkill -9 -f 'ruby' 2>/dev/null || true
    
    # ULTRA AGGRESSIVE PROCESS KILLING
    echo "\nPerforming ULTRA AGGRESSIVE process killing for ALL Ruby worker processes..."
    
    # Kill all Ruby worker.rb processes directly using pkill with force - multiple patterns
    echo "Using pkill with -9 signal to forcefully terminate all worker.rb processes..."
    pkill -9 -f 'ruby worker.rb' 2>/dev/null || true
    pkill -9 -f '/ruby worker' 2>/dev/null || true
    pkill -9 -f '/bin/ruby worker' 2>/dev/null || true
    # Also try with the full path
    pkill -9 -f '/Users/yan/.local/share/mise/installs/ruby/3.4.2/bin/ruby worker.rb' 2>/dev/null || true
    
    # Double-check for any remaining processes
    REMAINING_WORKER_PROCESSES=$(ps aux | grep 'ruby' | grep 'worker.rb' | grep -v grep)
    if [ ! -z "$REMAINING_WORKER_PROCESSES" ]; then
        echo "Still found some worker processes! Using direct PID killing as fallback:"
        echo "$REMAINING_WORKER_PROCESSES"
        
        # Direct PID killing as a fallback
        ps aux | grep 'ruby' | grep 'worker.rb' | grep -v grep | awk '{print $2}' > /tmp/worker_pids_to_kill.txt
        if [ -s /tmp/worker_pids_to_kill.txt ]; then
            cat /tmp/worker_pids_to_kill.txt
            while read pid; do
                echo "⚠️ Forcefully killing PID $pid with kill -9"
                kill -9 $pid 2>/dev/null || true
                sleep 0.1
            done < /tmp/worker_pids_to_kill.txt
        fi
    else
        echo "✅ No Ruby worker processes found after initial termination."
    fi
    
    # Ensure no zombie Ruby processes remain
    ps aux | grep 'ruby' | grep -v grep | grep -v 'language_server' | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    
    # Remove PID file regardless of whether processes were found
    rm -f /tmp/worker_pids_to_kill.txt
    
    # Final verification that everything was properly stopped
    echo "\nVerifying all services are stopped..."
    REMAINING_PROCESSES=$(ps aux | grep -E 'ruby|temporal_worker|payment-task-queue' | grep -v grep | grep -v stop_all.sh)
    if [ ! -z "$REMAINING_PROCESSES" ]; then
        echo "WARNING: Some processes might still be running:"
        echo "$REMAINING_PROCESSES"
        echo "Attempting final forced termination..."
        ps aux | grep -E 'ruby|temporal_worker|payment-task-queue' | grep -v grep | grep -v stop_all.sh | awk '{print $2}' | xargs kill -9 2>/dev/null || true
        
        # Wait a moment and try one more time for persistent processes
        sleep 1
        STUBBORN_PROCESSES=$(ps aux | grep 'ruby worker.rb' | grep -v grep)
        if [ ! -z "$STUBBORN_PROCESSES" ]; then
            echo "CRITICAL: Some worker processes are resistant to termination!"
            echo "$STUBBORN_PROCESSES"
            echo "Using extreme measures..."
            # Use direct pkill with very specific pattern
            pkill -9 -f 'ruby worker.rb' 2>/dev/null || true
        fi
    else
        echo "✅ All services have been successfully terminated."
    fi
    
    echo "Cleanup completed."
    # Slight pause to ensure all child processes have terminated
    sleep 1
fi

# Reminder about the Temporal server
echo ""
echo "Note: This script does not stop the Temporal server."
echo "If you want to stop the Temporal server, run:"
echo "temporal server stop-dev"
