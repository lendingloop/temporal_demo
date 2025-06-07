#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== PAYMENT WORKFLOW FAILURE TEST =====${NC}"
echo -e "${BLUE}Testing failure and compensation when Compliance API is down${NC}"
echo ""

# First, stop the compliance-api container to simulate a failure
echo -e "Stopping Compliance API container to simulate a failure scenario..."

if docker ps | grep -q "compliance-api"; then
  echo "Stopping compliance-api container..."
  docker stop compliance-api
  sleep 2
  if docker ps | grep -q "compliance-api"; then
    echo -e "${RED}⚠️ Failed to stop Compliance API container!${NC}"
    exit 1
  else
    echo -e "${GREEN}✅ Confirmed: Compliance API container is stopped${NC}"
  fi
else
  echo -e "${GREEN}✅ Confirmed: Compliance API container is already stopped${NC}"
fi

# Check if other services are running
check_container() {
  local container_name=$1
  
  echo -e "Checking if ${container_name} container is running..."
  if docker ps | grep -q "$container_name"; then
    echo -e "✅ ${GREEN}${container_name} container is running!${NC}"
    return 0
  else
    echo -e "❌ ${RED}${container_name} container is not running!${NC}"
    return 1
  fi
}

# Verify other services are running
echo "Checking other required containers..."

check_container "fx-service" || { 
  echo -e "${RED}FX Service container is not running. Start it with: docker compose up -d fx_service${NC}"; 
  exit 1; 
}

check_container "payment-api" || { 
  echo -e "${RED}Payment API container is not running. Start it with: docker compose up -d payment_api${NC}"; 
  exit 1; 
}

check_container "temporal-worker" || { 
  echo -e "${RED}Temporal Worker container is not running. Start it with: docker compose up -d temporal_worker${NC}"; 
  exit 1; 
}

echo -e "${GREEN}Other services are running as needed.${NC}"
echo ""

# Generate a unique reference for this test
REFERENCE="FAIL-$(date +%s)"

echo "Creating a high-risk payment with reference: $REFERENCE"
echo "This payment should fail at the compliance check stage"

# Create a payment using the Payment API with high-risk indicators
RESPONSE=$(curl -s -X POST http://localhost:3000/api/payments \
  -H "Content-Type: application/json" \
  -d "{
    \"amount\": 5000.00,
    \"charge_currency\": \"CAD\",
    \"settlement_currency\": \"USD\",
    \"customer\": {
      \"business_name\": \"High Risk Corp\",
      \"email\": \"test@example.com\"
    },
    \"merchant\": {
      \"name\": \"Suspicious Merchant\",
      \"country\": \"US\"
    },
    \"reference\": \"$REFERENCE\"
  }")

# Extract workflow ID using grep and cut
WORKFLOW_ID=$(echo $RESPONSE | grep -o '"workflow_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$WORKFLOW_ID" ]; then
  echo -e "${RED}Failed to create payment. Response:${NC}"
  echo $RESPONSE
  exit 1
fi

echo -e "${GREEN}Payment initiated with workflow ID: $WORKFLOW_ID${NC}"
echo ""

# Poll for payment status
echo -e "${BLUE}Monitoring payment status...${NC}"
echo "We expect this payment to FAIL due to the Compliance API being down"
echo "You should see compensation activities in the Temporal UI"

for i in {1..10}; do
  STATUS_RESPONSE=$(curl -s http://localhost:3000/api/payments/$WORKFLOW_ID)
  STATUS=$(echo $STATUS_RESPONSE | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  
  echo "Status check $i: $STATUS"
  
  if [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "REJECTED" ]; then
    echo -e "${GREEN}✅ EXPECTED RESULT: Payment failed as expected!${NC}"
    echo -e "This confirms that the workflow properly handles the Compliance API failure"
    break
  elif [ "$STATUS" == "COMPLETED" ]; then
    echo -e "${RED}❌ UNEXPECTED: Payment completed despite Compliance API being down!${NC}"
    echo -e "This suggests there might be an issue with the error handling"
    break
  else
    echo "Payment still processing... waiting 3 seconds"
    sleep 3
  fi
  
  # Last check
  if [ $i -eq 10 ] && [ "$STATUS" != "FAILED" ] && [ "$STATUS" != "REJECTED" ]; then
    echo -e "${YELLOW}Payment is still processing. Check the Temporal UI for more details.${NC}"
  fi
done

echo ""
echo -e "${BLUE}View workflow details in Temporal UI:${NC}"
echo "http://localhost:8233/namespaces/default/workflows/$WORKFLOW_ID"
echo ""
echo -e "${YELLOW}To restart the Compliance API container after this test:${NC}"
echo "docker compose up -d compliance_api"
