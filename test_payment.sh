#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== PAYMENT WORKFLOW HAPPY PATH TEST =====${NC}"
echo -e "${BLUE}Testing successful payment processing flow${NC}"
echo ""

# Check if all services are running
check_service() {
  local service_name=$1
  local url=$2
  
  echo -e "Checking ${service_name} health..."
  response=$(curl -s -o /dev/null -w "%{http_code}" $url)
  
  if [ "$response" == "200" ]; then
    echo -e "✅ ${GREEN}${service_name} is healthy!${NC}"
    return 0
  else
    echo -e "❌ ${RED}${service_name} is not responding (HTTP $response)${NC}"
    return 1
  fi
}

# Check all required services
echo "Checking all required services..."
check_service "FX Service" "http://localhost:3001/health" || { 
  echo -e "${RED}FX Service is not running. Please start all services with ./start_all.sh${NC}"; 
  exit 1; 
}

check_service "Compliance API" "http://localhost:3002/api/health" || { 
  echo -e "${RED}Compliance API is not running. Please start all services with ./start_all.sh${NC}"; 
  exit 1; 
}

check_service "Payment API" "http://localhost:3000/health" || { 
  echo -e "${RED}Payment API is not running. Please start all services with ./start_all.sh${NC}"; 
  exit 1; 
}

echo -e "${GREEN}All services are running.${NC}"
echo ""

# Generate a unique reference for this test
REFERENCE="DEMO-$(date +%s)"

echo "Creating a test payment with reference: $REFERENCE"
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
  exit 1
fi

echo -e "${GREEN}Payment initiated with workflow ID: $WORKFLOW_ID${NC}"
echo ""

# Poll for payment status
echo -e "${BLUE}Monitoring payment status...${NC}"
echo "This might take up to 15 seconds to complete"

for i in {1..5}; do
  STATUS_RESPONSE=$(curl -s http://localhost:3000/api/payments/$WORKFLOW_ID)
  STATUS=$(echo $STATUS_RESPONSE | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  
  echo "Status check $i: $STATUS"
  
  if [ "$STATUS" == "COMPLETED" ]; then
    echo -e "${GREEN}✅ Payment completed successfully!${NC}"
    break
  elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "REJECTED" ]; then
    echo -e "${RED}❌ Payment failed or was rejected${NC}"
    echo $STATUS_RESPONSE
    break
  else
    echo "Payment still processing... waiting 3 seconds"
    sleep 3
  fi
  
  # Last check
  if [ $i -eq 5 ] && [ "$STATUS" != "COMPLETED" ]; then
    echo -e "${YELLOW}Payment is still processing. Check the Temporal UI for more details.${NC}"
  fi
done

echo ""
echo -e "${BLUE}View workflow details in Temporal UI:${NC}"
echo "http://localhost:8233/namespaces/default/workflows/$WORKFLOW_ID"
