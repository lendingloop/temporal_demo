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
echo "This might take up to 15-30 seconds to complete in the Docker environment"

for i in {1..10}; do
  echo "Checking payment status (attempt $i)..."
  STATUS_RESPONSE=$(curl -s http://localhost:3000/api/payments/$WORKFLOW_ID)
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
    break
  elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "REJECTED" ]; then
    echo -e "${RED}❌ Payment failed or was rejected${NC}"
    echo "Full response: $STATUS_RESPONSE"
    break
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
  if [ $i -eq 10 ] && [ "$STATUS" != "COMPLETED" ]; then
    echo -e "${YELLOW}Payment is still processing. Check the Temporal UI for more details.${NC}"
  fi
done

echo ""
echo -e "${BLUE}View workflow details in Temporal UI:${NC}"
echo "http://localhost:8233/namespaces/default/workflows/$WORKFLOW_ID"
echo ""
echo -e "${YELLOW}To check Docker container logs:${NC}"
echo "docker logs payment-api"
echo "docker logs temporal-worker"
