#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== PAYMENT WORKFLOW TESTS =====${NC}"
echo -e "${BLUE}1. Testing standard payment processing flow${NC}"
echo -e "${BLUE}2. Testing high-value payment requiring approval${NC}"
echo ""

# Check if all services are running
# Note: We're now checking Docker container status directly instead of health endpoints

# Check all required services
echo "Checking if Docker containers are running..."
if ! docker ps | grep -q "fx-service"; then
  echo -e "${RED}FX Service is not running. Please start all services with docker compose up -d${NC}"
  exit 1
else
  echo -e "✅ ${GREEN}FX Service container is running${NC}"
fi

if ! docker ps | grep -q "compliance-api"; then
  echo -e "${RED}Compliance API is not running. Please start all services with docker compose up -d${NC}"
  exit 1
else
  echo -e "✅ ${GREEN}Compliance API container is running${NC}"
fi

if ! docker ps | grep -q "payment-api"; then
  echo -e "${RED}Payment API is not running. Please start all services with docker compose up -d${NC}"
  exit 1
else
  echo -e "✅ ${GREEN}Payment API container is running${NC}"
fi

if ! docker ps | grep -q "temporal-worker"; then
  echo -e "${RED}Temporal Worker is not running. Please start all services with docker compose up -d${NC}"
  exit 1
else
  echo -e "✅ ${GREEN}Temporal Worker container is running${NC}"
fi

echo -e "${GREEN}All required Docker containers are running.${NC}"
echo ""

# Function to check payment status
check_payment_status() {
  local workflow_id=$1
  local max_attempts=$2
  
  echo -e "${BLUE}Monitoring payment status...${NC}"
  echo "This might take up to 15-30 seconds to complete in the Docker environment"
  
  for i in $(seq 1 $max_attempts); do
    echo "Checking payment status (attempt $i)..."
    STATUS_RESPONSE=$(curl -s http://localhost:3000/api/payments/$workflow_id)
    echo "Raw API response: '$STATUS_RESPONSE'"
    
    # Try to extract JSON structure with jq if available
    if command -v jq &> /dev/null; then
      echo "Parsed response:"
      echo "$STATUS_RESPONSE" | jq .
      STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"')
    else
      # Fallback to grep if jq is not available
      STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    fi
    
    echo "Payment status: $STATUS"
    
    if [ "$STATUS" == "COMPLETED" ]; then
      echo -e "${GREEN}✅ Payment completed successfully!${NC}"
      return 0
    elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "REJECTED" ]; then
      echo -e "${RED}❌ Payment failed or was rejected${NC}"
      echo "Full response: $STATUS_RESPONSE"
      return 1
    elif [ "$STATUS" == "WAITING_FOR_APPROVAL" ]; then
      echo -e "${YELLOW}⏳ Payment is waiting for approval${NC}"
      return 2
    elif [ -z "$STATUS" ]; then
      echo -e "${YELLOW}Unable to parse status from response. Raw response:${NC}"
      echo "$STATUS_RESPONSE"
      echo "Waiting 3 seconds before next attempt..."
      sleep 3
    else
      echo "Payment status: $STATUS - waiting 3 seconds for next check..."
      sleep 3
    fi
    
    # Last check
    if [ $i -eq $max_attempts ] && [ "$STATUS" != "COMPLETED" ]; then
      echo -e "${YELLOW}Payment is still processing. Check the Temporal UI for more details.${NC}"
      return 3
    fi
  done
}

# Function to test standard payment flow
test_standard_payment() {
  echo -e "\n${BLUE}===== STANDARD PAYMENT TEST =====${NC}"
  
  # Generate a unique reference for this test
  REFERENCE="DEMO-$(date +%s)"
  
  echo "Creating a standard test payment with reference: $REFERENCE"
  echo "Amount: 3000.00 CAD → USD"
  
  # Create a payment using the Payment API
  RESPONSE=$(curl -s -X POST http://localhost:3000/api/payments \
    -H "Content-Type: application/json" \
    -d "{
      \"amount\": 3000.00,
      \"charge_currency\": \"CAD\",
      \"settlement_currency\": \"USD\",
      \"customer\": {
        \"business_name\": \"Loop Card Customer\",
        \"email\": \"customer@example.com\"
      },
      \"merchant\": {
        \"name\": \"USA Vendor Inc\",
        \"country\": \"US\"
      },
      \"reference\": \"$REFERENCE\"
    }")
    
  # Extract workflow ID using grep and cut
  WORKFLOW_ID=$(echo $RESPONSE | grep -o '"workflow_id":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$WORKFLOW_ID" ]; then
    echo -e "${RED}Failed to create payment. Response:${NC}"
    echo $RESPONSE
    return 1
  fi
  
  echo -e "${GREEN}Payment initiated with workflow ID: $WORKFLOW_ID${NC}"
  echo ""
  
  check_payment_status "$WORKFLOW_ID" 10
  return $?
}

# Function to test high-value payment flow
test_high_value_payment() {
  echo -e "\n${BLUE}===== HIGH VALUE PAYMENT TEST =====${NC}"
  
  # Generate a unique reference for this test
  REFERENCE="HIGH-VALUE-$(date +%s)"
  
  echo "Creating a high-value test payment with reference: $REFERENCE"
  echo "Amount: 6000.00 CAD → USD (requires approval)"
  
  # Create a payment using the Payment API
  RESPONSE=$(curl -s -X POST http://localhost:3000/api/payments \
    -H "Content-Type: application/json" \
    -d "{
      \"amount\": 6000.00,
      \"charge_currency\": \"CAD\",
      \"settlement_currency\": \"USD\",
      \"customer\": {
        \"business_name\": \"Loop Card Customer\",
        \"email\": \"customer@example.com\"
      },
      \"merchant\": {
        \"name\": \"USA Vendor Inc\",
        \"country\": \"US\"
      },
      \"reference\": \"$REFERENCE\"
    }")
    
  # Extract workflow ID using grep and cut
  WORKFLOW_ID=$(echo $RESPONSE | grep -o '"workflow_id":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$WORKFLOW_ID" ]; then
    echo -e "${RED}Failed to create payment. Response:${NC}"
    echo $RESPONSE
    return 1
  fi
  
  echo -e "${GREEN}High-value payment initiated with workflow ID: $WORKFLOW_ID${NC}"
  echo ""
  
  # Check for payment status, expecting WAITING_FOR_APPROVAL
  check_payment_status "$WORKFLOW_ID" 5
  STATUS_CODE=$?
  
  # If payment is waiting for approval (status code 2), proceed with approval
  if [ $STATUS_CODE -eq 2 ]; then
    echo -e "\n${BLUE}===== APPROVING HIGH VALUE PAYMENT =====${NC}"
    echo "Sending approval for payment: $WORKFLOW_ID"
    
    APPROVAL_RESPONSE=$(curl -s -X POST http://localhost:3000/api/payments/$WORKFLOW_ID/approve \
      -H "Content-Type: application/json" \
      -d '{
        "approved": true,
        "approver_id": "test-approver-1",
        "approver_name": "Test Approver"
      }')
      
    echo "Approval response: $APPROVAL_RESPONSE"
    
    # Check final status after approval
    echo "Checking final payment status after approval..."
    check_payment_status "$WORKFLOW_ID" 10
    return $?
  else
    echo -e "${YELLOW}Payment didn't reach WAITING_FOR_APPROVAL status. Skipping approval step.${NC}"
    return $STATUS_CODE
  fi
}

# Ask which test to run
echo "Which test would you like to run?"
echo "1) Standard payment test"
echo "2) High-value payment test with approval"
echo "3) Run both tests"
read -p "Enter your choice (1, 2, or 3): " TEST_CHOICE

case $TEST_CHOICE in
  1)
    test_standard_payment
    ;;
  2)
    test_high_value_payment
    ;;
  3)
    test_standard_payment
    test_high_value_payment
    ;;
  *)
    echo -e "${RED}Invalid choice. Please run again and select 1, 2, or 3.${NC}"
    exit 1
    ;;
esac

# Print final message with helpful commands
echo ""
echo -e "${BLUE}View workflow details in Temporal UI:${NC}"
echo "http://localhost:8233/namespaces/default/workflows/"
echo ""
echo -e "${YELLOW}To check Docker container logs:${NC}"
echo "docker logs payment-api"
echo "docker logs temporal-worker"
