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
# Extracted from Swagger documentation: https://api-gateway.soulverse.us/api#/
# NOTE: Endpoints do NOT use /api prefix - they're directly under the root domain

apis=(
  # Base API Gateway Health Checks
  "Soulverse API Gateway Root|https://api-gateway.soulverse.us/api"
  
  # News Service (GET endpoints - tested and working)
  "Soulverse News|https://api-gateway.soulverse.us/news|GET"
  "Soulverse News Providers|https://api-gateway.soulverse.us/news/providers|GET"
  "Soulverse News Categories|https://api-gateway.soulverse.us/news/categories|GET"
  
  # LinkedIn Service (GET endpoints)
  "Soulverse LinkedIn Authorization|https://api-gateway.soulverse.us/linkedin/authorization|GET"
  "Soulverse LinkedIn Company Posts|https://api-gateway.soulverse.us/linkedin/company-posts|GET"
  "Soulverse LinkedIn Callback|https://api-gateway.soulverse.us/linkedin/callback|GET"
  
  # Organizations Service (GET endpoints)
  "Soulverse Organizations Credential Tag|https://api-gateway.soulverse.us/organizations/credential-tag|GET"
  
  # App Config Service (GET endpoints)
  "Soulverse Mobile App Constant|https://api-gateway.soulverse.us/app-config/mobile-app-constant|GET"
  
  # Auth Logger Service (GET endpoints)
  "Soulverse Auth Logger Attempts|https://api-gateway.soulverse.us/auth-logger/attempts|GET"
  "Soulverse Auth Logger Daily Report|https://api-gateway.soulverse.us/auth-logger/daily-report|GET"
  "Soulverse Auth Logger Monthly Report|https://api-gateway.soulverse.us/auth-logger/monthly-report|GET"
  "Soulverse Auth Logger Trace|https://api-gateway.soulverse.us/auth-logger/trace|GET"
  "Soulverse Auth Logger Weekly Report|https://api-gateway.soulverse.us/auth-logger/weekly-report|GET"
  
  # Trust Registry Service (GET endpoints)
  "Soulverse Trust Registry Get All Entities|https://api-gateway.soulverse.us/trust-registry/get-all-entities|GET"
  
  # POST/PUT/PATCH/DELETE endpoints - monitored with appropriate HTTP methods
  # These endpoints are checked with minimal payloads to verify service availability
  # 400/401/403 responses mean service is operational (needs proper payload/auth)
  # 404/500/503/000 responses mean service is down
  
  # Backup and Recovery Service
  "Soulverse Backup Recovery Upload|https://api-gateway.soulverse.us/BackupAndRecovery/upload|POST"
  
  # App Config Service (POST endpoints)
  "Soulverse App Config Constant|https://api-gateway.soulverse.us/app-config/app-constant|POST"
  "Soulverse App Config Version|https://api-gateway.soulverse.us/app-config/app-version|POST"
  
  # Auth Logger Service (POST)
  "Soulverse Auth Logger Log|https://api-gateway.soulverse.us/auth-logger/log|POST"
  
  # SoulId Service
  "Soulverse SoulId Create|https://api-gateway.soulverse.us/soul-id|POST"
  "Soulverse SoulId Link Address|https://api-gateway.soulverse.us/soul-id/link-address|POST"
  "Soulverse SoulId Payment Detail|https://api-gateway.soulverse.us/soul-id/payment-detail|PATCH"
  "Soulverse SoulId Recover|https://api-gateway.soulverse.us/soul-id/recover|POST"
  
  # SoulScan Service
  "Soulverse SoulScan Health Check|https://api-gateway.soulverse.us/soulscan/health-check|POST"
  "Soulverse SoulScan Login|https://api-gateway.soulverse.us/soulscan/login|POST"
  "Soulverse SoulScan Register|https://api-gateway.soulverse.us/soulscan/register|POST"
  "Soulverse SoulScan Validate Face|https://api-gateway.soulverse.us/soulscan/validate-face|POST"
  
  # Store Login Service
  "Soulverse Store Login|https://api-gateway.soulverse.us/store-login|POST"
  
  # Trust Registry Service
  "Soulverse Trust Registry Add Entity|https://api-gateway.soulverse.us/trust-registry/add-entity|POST"
  
  # Organizations Service
  "Soulverse Organizations Create|https://api-gateway.soulverse.us/organizations|POST"
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
  if [[ "$url" == *"/news" ]] && [[ "$url" != *"?"* ]] && [[ "$method" == "GET" ]] && [[ "$url" != *"/news/providers" ]] && [[ "$url" != *"/news/categories" ]]; then
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
  # 200-299: Success responses (service is operational)
  # 300-399: Redirects (service is up and redirecting)
  # 400-403: Client errors indicating service is responding:
  #   - 400: Bad Request (service is up, but needs proper payload)
  #   - 401: Unauthorized (service is up, but needs authentication)
  #   - 402: Payment Required (service is up, but needs payment)
  #   - 403: Forbidden (service is up, but access is denied)
  # 404+: Not Found or Server errors (treat as down)
  # 000: Timeout/Connection error (service is down)
  
  # Mark 200-403 as operational (inclusive range)
  if [[ "$response" =~ ^[0-9]+$ ]] && [ "$response" -ge 200 ] && [ "$response" -le 403 ]; then
    echo -e "${GREEN}✅ $name is operational (HTTP $response)${NC}" >&2
    echo "operational|$response"
  else
    echo -e "${RED}❌ $name is down (HTTP $response)${NC}" >&2
    echo "down|$response"
  fi
}

# Function to send Slack notification
send_slack_notification() {
  local service_name=$1
  local old_status=$2
  local new_status=$3
  local status_code=${4:-"N/A"}
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
    message="*${service_name}* is now *DOWN*\n\nStatus: ${new_status}\nHTTP Status Code: ${status_code}\nTime: ${timestamp}"
  elif [ "$old_status" = "down" ] && [ "$new_status" = "operational" ]; then
    emoji="🟢"
    title="Service Recovered"
    message="*${service_name}* is now *OPERATIONAL*\n\nStatus: ${new_status}\nHTTP Status Code: ${status_code}\nTime: ${timestamp}"
  else
    emoji="⚠️"
    title="Status Change"
    message="*${service_name}* status changed from *${old_status}* to *${new_status}*\n\nHTTP Status Code: ${status_code}\nTime: ${timestamp}"
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
declare -A current_status_code
services_array=()

# Check each API
echo "Checking APIs..."
echo ""

for api in "${apis[@]}"; do
  # Parse API entry: "Name|URL" or "Name|URL|METHOD" or "Name|URL|METHOD|PAYLOAD"
  IFS='|' read -r name url method payload <<< "$api"
  
  # Check current status (pass method and payload if provided)
  if [ -n "$payload" ]; then
    status_result=$(check_api "$name" "$url" "$method" "$payload")
  elif [ -n "$method" ]; then
    status_result=$(check_api "$name" "$url" "$method")
  else
    status_result=$(check_api "$name" "$url")
  fi
  
  # Parse status and statusCode (format: "operational|200" or "down|404")
  status=$(echo "$status_result" | cut -d'|' -f1)
  status_code=$(echo "$status_result" | cut -d'|' -f2)
  
  # Ensure status_code is a number (handle "000" for timeout)
  if ! [[ "$status_code" =~ ^[0-9]+$ ]]; then
    status_code=0
  fi
  
  # Store status with code for comparison
  current_status["$name"]="$status"
  current_status_code["$name"]="$status_code"
  
  # Get previous status (format: "operational" or stored separately)
  previous_status_for_api=$(echo "$previous_status" | jq -r ".[\"$name\"] // empty" 2>/dev/null || echo "")
  # Extract just the status part if it's in old format "operational|200"
  previous_status_for_api=$(echo "$previous_status_for_api" | cut -d'|' -f1)
  
  # Compare status (not status code, to avoid notifications for same status with different codes)
  if [ -n "$previous_status_for_api" ] && [ "$previous_status_for_api" != "$status" ]; then
    echo -e "${YELLOW}⚠️  Status changed for $name: $previous_status_for_api → $status (HTTP $status_code)${NC}"
    send_slack_notification "$name" "$previous_status_for_api" "$status" "$status_code"
  elif [ -z "$previous_status_for_api" ]; then
    echo -e "${YELLOW}ℹ️  First check for $name (no notification)${NC}" >&2
  else
    echo -e "${GREEN}✓ Status unchanged for $name (HTTP $status_code)${NC}" >&2
  fi
  
  # Add to services array with status code
  services_array+=("{\"name\":\"$name\",\"status\":\"$status\",\"statusCode\":$status_code}")
done

echo ""
echo "=========================================="
echo "Generating status files..."
echo "=========================================="

# Create current status JSON object (store both status and statusCode)
current_status_json="{"
first=true
for name in "${!current_status[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    current_status_json+=","
  fi
  current_status_json+="\"$name\":\"${current_status[$name]}\",\"${name}_code\":${current_status_code[$name]}"
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
  echo "  $status_emoji $name: ${current_status[$name]} (HTTP ${current_status_code[$name]})"
done
echo ""

