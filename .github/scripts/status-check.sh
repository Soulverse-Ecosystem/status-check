#!/bin/bash

# API Status Check Script for GitHub Actions
# Checks multiple APIs, compares with previous status, and sends Slack notifications

set -e

# Configuration
TIMEOUT=10
STATUS_FILE="status.json"
PREVIOUS_STATUS_FILE="previous-status.json"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

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
  "Soulverse API Gateway Root|https://api-gateway.soulverse.us/"
  
  # News Service
  "Soulverse News|https://api-gateway.soulverse.us/api/news"
  "Soulverse News Providers|https://api-gateway.soulverse.us/api/news/providers"
  "Soulverse News Categories|https://api-gateway.soulverse.us/api/news/categories"
  
  # LinkedIn Service
  "Soulverse LinkedIn Authorization|https://api-gateway.soulverse.us/api/linkedin/authorization"
  "Soulverse LinkedIn Company Posts|https://api-gateway.soulverse.us/api/linkedin/company-posts"
  
  # Backup and Recovery Service
  "Soulverse Backup Recovery|https://api-gateway.soulverse.us/api/BackupAndRecovery/upload"
  
  # SoulId Service
  "Soulverse SoulId|https://api-gateway.soulverse.us/api/soul-id"
  "Soulverse SoulId Link Address|https://api-gateway.soulverse.us/api/soul-id/link-address"
  
  # Organizations Service
  "Soulverse Organizations|https://api-gateway.soulverse.us/api/organizations"
  "Soulverse Organizations Tags|https://api-gateway.soulverse.us/api/organizations/credential-tag"
  
  # App Config Service
  "Soulverse App Version|https://api-gateway.soulverse.us/api/app-config/app-version"
  "Soulverse App Constant|https://api-gateway.soulverse.us/api/app-config/app-constant"
  "Soulverse Mobile App Constant|https://api-gateway.soulverse.us/api/app-config/mobile-app-constant"
  
  # Auth Logger Service
  "Soulverse Auth Logger|https://api-gateway.soulverse.us/api/auth-logger/log"
  "Soulverse Auth Logger Trace|https://api-gateway.soulverse.us/api/auth-logger/trace"
  "Soulverse Auth Logger Daily Report|https://api-gateway.soulverse.us/api/auth-logger/daily-report"
  "Soulverse Auth Logger Attempts|https://api-gateway.soulverse.us/api/auth-logger/attempts"
  "Soulverse Auth Logger Monthly Report|https://api-gateway.soulverse.us/api/auth-logger/monthly-report"
  "Soulverse Auth Logger Weekly Report|https://api-gateway.soulverse.us/api/auth-logger/weekly-report"
  
  # SoulScan Service (Important: includes health-check endpoint)
  "Soulverse SoulScan Health Check|https://api-gateway.soulverse.us/api/soulscan/health-check"
  "Soulverse SoulScan Login|https://api-gateway.soulverse.us/api/soulscan/login"
  "Soulverse SoulScan Register|https://api-gateway.soulverse.us/api/soulscan/register"
  "Soulverse SoulScan Validate Face|https://api-gateway.soulverse.us/api/soulscan/validate-face"
  
  # Store Login Service
  "Soulverse Store Login|https://api-gateway.soulverse.us/api/store-login"
  
  # Trust Registry Service
  "Soulverse Trust Registry|https://api-gateway.soulverse.us/api/trust-registry/get-all-entities"
  "Soulverse Trust Registry Add Entity|https://api-gateway.soulverse.us/api/trust-registry/add-entity"
  
  # Additional SoulId Endpoints
  "Soulverse SoulId Payment Detail|https://api-gateway.soulverse.us/api/soul-id/payment-detail"
  "Soulverse SoulId Recover|https://api-gateway.soulverse.us/api/soul-id/recover"
  "Soulverse SoulId Delete|https://api-gateway.soulverse.us/api/soul-id/delete"
  
  # Additional LinkedIn Endpoint
  "Soulverse LinkedIn Callback|https://api-gateway.soulverse.us/api/linkedin/callback"
  
  # Additional Organizations Endpoint
  "Soulverse Organizations By ID|https://api-gateway.soulverse.us/api/organizations"
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
  
  # Send colored logs to stderr so only the plain status is captured
  echo -e "${YELLOW}Checking $name ($url)...${NC}" >&2
  
  # Make HTTP request with timeout
  response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
  
  if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ $name is operational${NC}" >&2
    echo "operational"
  else
    echo -e "${RED}❌ $name is down (HTTP $response)${NC}" >&2
    echo "down"
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
  IFS='|' read -r name url <<< "$api"
  
  # Check current status
  status=$(check_api "$name" "$url")
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

