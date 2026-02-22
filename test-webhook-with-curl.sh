#!/bin/bash
# Test webhook endpoints directly with curl
# This helps verify if n8n webhooks are working independently of Supabase triggers

echo "=== Testing Webhook Endpoints with curl ==="
echo ""

# Test 1: CreateLink webhook
echo "Test 1: Testing CreateLink webhook endpoint..."
echo "URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link"
echo ""

curl -X POST \
  "https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link" \
  -H "Content-Type: application/json" \
  -d '{
    "test": true,
    "source": "curl_test",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "apartment_id": "test-from-curl",
    "status": "CreateLink"
  }' \
  -w "\nHTTP Status: %{http_code}\n" \
  -v

echo ""
echo "---"
echo ""

# Wait a moment
sleep 2

# Test 2: Active webhook
echo "Test 2: Testing Active webhook endpoint..."
echo "URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active"
echo ""

curl -X POST \
  "https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active" \
  -H "Content-Type: application/json" \
  -d '{
    "test": true,
    "source": "curl_test",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "event_type": "apartment_status_active",
    "apartment": {
      "id": "test-from-curl",
      "status": "Active"
    },
    "matched_tenants": []
  }' \
  -w "\nHTTP Status: %{http_code}\n" \
  -v

echo ""
echo "=== curl tests complete ==="
echo "Check n8n executions - you should see 2 new executions from these curl calls."
echo "If curl works but Supabase triggers don't, the issue is with Supabase -> n8n communication."
