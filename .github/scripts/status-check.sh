#!/bin/bash

# API Status Check Script for GitHub Actions
# Checks multiple APIs, compares with previous status, and sends Slack notifications

set -e

# Configuration
TIMEOUT=10
STATUS_FILE="status.json"
PREVIOUS_STATUS_FILE="previous-status.json"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Optional: API Authentication (if your API requires it)
# Set these as GitHub Secrets if needed:
# API_KEY="${API_KEY:-}"
# API_TOKEN="${API_TOKEN:-}"
# AUTH_HEADER="${AUTH_HEADER:-}"  # e.g., "Bearer token" or "ApiKey key"

# Define your API endpoints here
# Format: "Service Name|URL"
# 
# To add all APIs from https://api-gateway.soulverse.us/api#/:
# 1. Visit the Swagger documentation page
# 2. Expand each API section to see all endpoints
# 3. For each endpoint, add a health check URL
# 4. Common patterns: /health, /status, /ping, or the base endpoint path
#
# Soulverse API Gateway endpoints
apis=(
  # Base API Gateway Health Checks
  "Soulverse API Gateway|https://api-gateway.soulverse.us/health"
  "Soulverse API Gateway Root|https://api-gateway.soulverse.us/api"
  
  # News Service (GET endpoints - these should work)
  "Soulverse News|https://api-gateway.soulverse.us/api/news?page=1&pageSize=1"
  "Soulverse News Providers|https://api-gateway.soulverse.us/api/news/providers"
  "Soulverse News Categories|https://api-gateway.soulverse.us/api/news/categories"
  
  # LinkedIn Service (GET endpoints)
  "Soulverse LinkedIn Authorization|https://api-gateway.soulverse.us/api/linkedin/authorization"
  "Soulverse LinkedIn Company Posts|https://api-gateway.soulverse.us/api/linkedin/company-posts"
  "Soulverse LinkedIn Callback|https://api-gateway.soulverse.us/api/linkedin/callback?code=test&state=test"
  
  # Organizations Service (GET endpoints)
  "Soulverse Organizations|https://api-gateway.soulverse.us/api/organizations"
  "Soulverse Organizations Tags|https://api-gateway.soulverse.us/api/organizations/credential-tag"
  
  # App Config Service (GET endpoints)
  "Soulverse App Version|https://api-gateway.soulverse.us/api/app-config/app-version"
  "Soulverse App Constant|https://api-gateway.soulverse.us/api/app-config/app-constant"
  "Soulverse Mobile App Constant|https://api-gateway.soulverse.us/api/app-config/mobile-app-constant"
  
  # Auth Logger Service (GET endpoints)
  "Soulverse Auth Logger|https://api-gateway.soulverse.us/api/auth-logger/log"
  "Soulverse Auth Logger Trace|https://api-gateway.soulverse.us/api/auth-logger/trace"
  "Soulverse Auth Logger Daily Report|https://api-gateway.soulverse.us/api/auth-logger/daily-report"
  "Soulverse Auth Logger Attempts|https://api-gateway.soulverse.us/api/auth-logger/attempts"
  "Soulverse Auth Logger Monthly Report|https://api-gateway.soulverse.us/api/auth-logger/monthly-report"
  "Soulverse Auth Logger Weekly Report|https://api-gateway.soulverse.us/api/auth-logger/weekly-report"
  
  # SoulScan Service (includes health-check endpoint)
  "Soulverse SoulScan Health Check|https://api-gateway.soulverse.us/api/soulscan/health-check"
  
  # Trust Registry Service (GET endpoints)
  "Soulverse Trust Registry|https://api-gateway.soulverse.us/api/trust-registry/get-all-entities"
  
  # POST/PUT/DELETE endpoints - monitored with appropriate HTTP methods
  # These endpoints are checked with minimal payloads to verify service availability
  # 400/401/403 responses mean service is operational (needs proper payload/auth)
  # 500/503/000 responses mean service is down
  
  # Backup and Recovery Service (POST)
  "Soulverse Backup Recovery Upload|https://api-gateway.soulverse.us/api/BackupAndRecovery/upload|POST"
  
  # SoulId Service (POST/PATCH/DELETE)
  "Soulverse SoulId Create|https://api-gateway.soulverse.us/api/soul-id|POST|{\"soulId\":\"test.soul\",\"purchase\":{}}"
  "Soulverse SoulId Link Address|https://api-gateway.soulverse.us/api/soul-id/link-address|POST|{\"soulId\":\"test.soul\",\"addresses\":[]}"
  "Soulverse SoulId Payment Detail|https://api-gateway.soulverse.us/api/soul-id/payment-detail|PATCH|{\"soulId\":\"test.soul\",\"purchase\":{}}"
  "Soulverse SoulId Recover|https://api-gateway.soulverse.us/api/soul-id/recover|POST|{\"soulId\":\"test\",\"image\":\"test\"}"
  
  # SoulScan Service (POST)
  "Soulverse SoulScan Login|https://api-gateway.soulverse.us/api/soulscan/login|POST|{\"soulId\":\"test\",\"image\":\"test\"}"
  "Soulverse SoulScan Register|https://api-gateway.soulverse.us/api/soulscan/register|POST|{\"soulId\":\"test\",\"image\":\"test\"}"
  "Soulverse SoulScan Validate Face|https://api-gateway.soulverse.us/api/soulscan/validate-face|POST|{\"image\":\"test\"}"
  
  # Store Login Service (POST)
  "Soulverse Store Login|https://api-gateway.soulverse.us/api/store-login|POST|{\"username\":\"test\",\"password\":\"test\"}"
  
  # Trust Registry Service (POST)
  "Soulverse Trust Registry Add Entity|https://api-gateway.soulverse.us/api/trust-registry/add-entity|POST|{\"orgId\":\"test\",\"type\":\"ISSUER\",\"orgDid\":\"test\",\"serviceEndpoint\":\"https://test.com\",\"schemaIds\":[],\"credentialDefinitionIds\":[]}"
  
  # Organizations Service (POST)
  "Soulverse Organizations Create|https://api-gateway.soulverse.us/api/organizations|POST"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check API status
check_api() {
  local name=$1
  local url=$2
  local method="${3:-GET}"  # Default to GET if not specified
  local payload="${4:-}"     # Optional payload for POST/PUT requests
  
  # Send colored logs to stderr so only the plain status is captured
  echo -e "${YELLOW}Checking $name ($url) [${method}]...${NC}" >&2
  
  # For endpoints that might need query parameters, try with minimal params
  # News endpoint needs query parameters
  if [[ "$url" == *"/api/news" ]] && [[ "$url" != *"?"* ]] && [[ "$method" == "GET" ]]; then
    url="${url}?page=1&pageSize=1"
  fi
  
  # Build curl headers array for authentication
  local curl_headers=()
  
  # Add authentication headers if provided
  if [ -n "$API_KEY" ]; then
    curl_headers+=("-H" "X-API-Key: $API_KEY")
  fi
  if [ -n "$API_TOKEN" ]; then
    curl_headers+=("-H" "Authorization: Bearer $API_TOKEN")
  fi
  if [ -n "$AUTH_HEADER" ]; then
    curl_headers+=("-H" "Authorization: $AUTH_HEADER")
  fi
  
  # Make HTTP request based on method
  local response="000"
  
  case "$method" in
    "GET")
      # Use HEAD request first (lighter), fallback to GET if HEAD not allowed
      response=$(curl -s -I -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                 "${curl_headers[@]}" \
                 -X HEAD "$url" 2>/dev/null || \
                 curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                 "${curl_headers[@]}" \
                 "$url" 2>/dev/null || echo "000")
      ;;
    "POST"|"PUT"|"PATCH")
      # For POST/PUT/PATCH, send minimal payload and check response
      # We consider 400 (Bad Request) as "operational" - service is up but needs proper payload
      # 401/403 means service is up but needs auth
      # 500/503 means service is down
      if [ -n "$payload" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                   "${curl_headers[@]}" \
                   -X "$method" \
                   -H "Content-Type: application/json" \
                   -d "$payload" \
                   "$url" 2>/dev/null || echo "000")
      else
        # Try with empty JSON payload
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                   "${curl_headers[@]}" \
                   -X "$method" \
                   -H "Content-Type: application/json" \
                   -d "{}" \
                   "$url" 2>/dev/null || echo "000")
      fi
      ;;
    "DELETE")
      # For DELETE, try with a test ID or check if endpoint responds
      # Many DELETE endpoints need an ID, so we check if we get 400/404 (endpoint exists) vs 500 (down)
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                 "${curl_headers[@]}" \
                 -X "$method" \
                 "$url" 2>/dev/null || echo "000")
      ;;
    *)
      # Default to GET
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
                 "${curl_headers[@]}" \
                 "$url" 2>/dev/null || echo "000")
      ;;
  esac
  
  # Consider these as "operational" (service is responding):
  # 200, 201, 204 - Success
  # 301, 302 - Redirect (service is up)
  # 400 - Bad Request (service is up, but needs proper payload/auth)
  # 401, 403 - Unauthorized/Forbidden (service is up, but needs auth)
  # 404 - Not Found (endpoint doesn't exist OR service is down)
  #     For POST/PUT/PATCH: 404 might mean endpoint exists but needs proper path/ID
  #     For GET: 404 usually means endpoint doesn't exist or needs auth
  # 405 - Method Not Allowed (endpoint exists but wrong method - service is up)
  # 500, 502, 503, 504 - Server errors (service is down)
  # 000 - Timeout/Connection error (service is down)
  
  # For POST/PUT/PATCH, also consider 404 as potentially operational (endpoint might need proper ID/path)
  if [[ "$method" =~ ^(POST|PUT|PATCH)$ ]]; then
    if [[ "$response" =~ ^(200|201|204|301|302|400|401|403|404|405)$ ]]; then
      echo -e "${GREEN}✅ $name is operational (HTTP $response)${NC}" >&2
      echo "operational"
    else
      echo -e "${RED}❌ $name is down (HTTP $response)${NC}" >&2
      echo "down"
    fi
  else
    # For GET requests, 404 means endpoint doesn't exist (treat as down)
    if [[ "$response" =~ ^(200|201|204|301|302|400|401|403|405)$ ]]; then
      echo -e "${GREEN}✅ $name is operational (HTTP $response)${NC}" >&2
      echo "operational"
    else
      echo -e "${RED}❌ $name is down (HTTP $response)${NC}" >&2
      echo "down"
    fi
  fi
}

# Function to send Slack notification
send_slack_notification() {
  local service_name=$1
  local old_status=$2
  local new_status=$3
  local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
  
  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "⚠️  SLACK_WEBHOOK_URL not set, skipping notification"
    return
  fi
  
  local emoji=""
  local title=""
  local message=""
  
  if [ "$old_status" = "operational" ] && [ "$new_status" = "down" ]; then
    emoji="🔴"
    title="Service Alert - DOWN"
    message="*${service_name}* is now *DOWN*\n\nStatus: ${new_status}\nTime: ${timestamp}"
  elif [ "$old_status" = "down" ] && [ "$new_status" = "operational" ]; then
    emoji="🟢"
    title="Service Recovered"
    message="*${service_name}* is now *OPERATIONAL*\n\nStatus: ${new_status}\nTime: ${timestamp}"
  else
    emoji="⚠️"
    title="Status Change"
    message="*${service_name}* status changed from *${old_status}* to *${new_status}*\n\nTime: ${timestamp}"
  fi
  
  # Format Slack message using Block Kit
  local slack_payload=$(cat <<EOF
{
  "text": "${emoji} ${title}",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "${emoji} ${title}"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "${message}"
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Updated: ${timestamp}"
        }
      ]
    }
  ]
}
EOF
)
  
  # Send to Slack
  curl -X POST -H 'Content-type: application/json' \
    --data "$slack_payload" \
    "$SLACK_WEBHOOK_URL" 2>/dev/null || echo "⚠️  Failed to send Slack notification"
  
  echo -e "${GREEN}📧 Slack notification sent for $service_name${NC}" >&2
}

# Function to load previous status
load_previous_status() {
  if [ -f "$PREVIOUS_STATUS_FILE" ]; then
    cat "$PREVIOUS_STATUS_FILE"
  else
    echo "{}"
  fi
}

# Function to save previous status
save_previous_status() {
  echo "$1" > "$PREVIOUS_STATUS_FILE"
}

# Main execution
echo "=========================================="
echo "API Status Check"
echo "=========================================="
echo ""

# Load previous status
previous_status_json=$(load_previous_status)
previous_status=$(echo "$previous_status_json" | jq -r '.' 2>/dev/null || echo "{}")

# Initialize current status
declare -A current_status
services_array=()

# Check each API
echo "Checking APIs..."
echo ""

for api in "${apis[@]}"; do
  # Parse API entry: "Name|URL" or "Name|URL|METHOD" or "Name|URL|METHOD|PAYLOAD"
  IFS='|' read -r name url method payload <<< "$api"
  
  # Check current status (pass method and payload if provided)
  if [ -n "$payload" ]; then
    status=$(check_api "$name" "$url" "$method" "$payload")
  elif [ -n "$method" ]; then
    status=$(check_api "$name" "$url" "$method")
  else
    status=$(check_api "$name" "$url")
  fi
  current_status["$name"]="$status"
  
  # Get previous status
  previous_status_for_api=$(echo "$previous_status" | jq -r ".[\"$name\"] // empty" 2>/dev/null || echo "")
  
  # Compare and send notification if changed
  if [ -n "$previous_status_for_api" ] && [ "$previous_status_for_api" != "$status" ]; then
    echo -e "${YELLOW}⚠️  Status changed for $name: $previous_status_for_api → $status${NC}"
    send_slack_notification "$name" "$previous_status_for_api" "$status"
  elif [ -z "$previous_status_for_api" ]; then
    echo -e "${YELLOW}ℹ️  First check for $name (no notification)${NC}" >&2
  else
    echo -e "${GREEN}✓ Status unchanged for $name${NC}" >&2
  fi
  
  # Add to services array
  services_array+=("{\"name\":\"$name\",\"status\":\"$status\"}")
done

echo ""
echo "=========================================="
echo "Generating status files..."
echo "=========================================="

# Create current status JSON object
current_status_json="{"
first=true
for name in "${!current_status[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    current_status_json+=","
  fi
  current_status_json+="\"$name\":\"${current_status[$name]}\""
done
current_status_json+="}"

# Create services array for status.json
services_json=$(IFS=','; echo "[${services_array[*]}]")

# Generate status.json for GitHub Pages
cat > "$STATUS_FILE" <<EOF
{
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "services": $services_json
}
EOF

# Save current status as previous for next run
save_previous_status "$current_status_json"

echo ""
echo -e "${GREEN}✅ Status check complete!${NC}"
echo ""
echo "Files generated:"
echo "  - $STATUS_FILE (for GitHub Pages)"
echo "  - $PREVIOUS_STATUS_FILE (for comparison)"
echo ""
echo "Status summary:"
for name in "${!current_status[@]}"; do
  status_emoji="🟢"
  [ "${current_status[$name]}" = "down" ] && status_emoji="🔴"
  echo "  $status_emoji $name: ${current_status[$name]}"
done
echo ""

