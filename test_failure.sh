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

# First, verify that the Compliance API is actually down
echo -e "Checking if Compliance API is down..."
response=$(curl -s -o /dev/null -w "%{http_code}" -m 2 http://localhost:3002/api/health || echo "000")

if [ "$response" == "200" ]; then
  echo -e "${RED}⚠️ Compliance API is still running!${NC}"
  echo -e "To run the failure scenario, first stop the Compliance API:"
  echo -e "${YELLOW}lsof -ti:3002 | xargs kill -9${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Confirmed: Compliance API is down as expected${NC}"
fi

# Check if other services are running
check_service() {
  local service_name=$1
  local url=$2
  
  echo -e "Checking ${service_name} health..."
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 2 $url || echo "000")
  
  if [ "$response" == "200" ]; then
    echo -e "✅ ${GREEN}${service_name} is healthy!${NC}"
    return 0
  else
    echo -e "❌ ${RED}${service_name} is not responding (HTTP $response)${NC}"
    return 1
  fi
}

# Verify other services are running
echo "Checking other required services..."

check_service "FX Service" "http://localhost:3001/health" || { 
  echo -e "${RED}FX Service is not running. Please start it with ./start_all.sh${NC}"; 
  exit 1; 
}

check_service "Payment API" "http://localhost:3000/health" || { 
  echo -e "${RED}Payment API is not running. Please start it with ./start_all.sh${NC}"; 
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
echo -e "${YELLOW}To restart the Compliance API after this test:${NC}"
echo "cd compliance_api && bundle exec ruby app.rb -p 3002 -o 0.0.0.0"
