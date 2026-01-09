# API Authentication Setup

Guide to add authentication for monitoring APIs that require it.

## 🔐 Why Authentication?

Many APIs return **404 Not Found** when accessed without authentication. This doesn't mean the service is down - it means you need to authenticate first.

## 📋 Setup Options

### Option 1: API Key Authentication

If your API uses API Key authentication:

1. **Get your API Key** from your API Gateway dashboard
2. **Add to GitHub Secrets:**
   - Repository → Settings → Secrets and variables → Actions
   - New repository secret
   - Name: `API_KEY`
   - Value: Your API key
   - Add secret

3. **Update workflow file** (`.github/workflows/status-check.yml`):
   ```yaml
   - name: Check API Status
     env:
       SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
       API_KEY: ${{ secrets.API_KEY }}  # Add this line
     run: bash .github/scripts/status-check.sh
   ```

### Option 2: Bearer Token Authentication

If your API uses Bearer token:

1. **Generate/Get your Bearer token**
2. **Add to GitHub Secrets:**
   - Name: `API_TOKEN`
   - Value: Your bearer token

3. **Update workflow file:**
   ```yaml
   env:
     API_TOKEN: ${{ secrets.API_TOKEN }}
   ```

### Option 3: Custom Authorization Header

If your API uses custom auth format:

1. **Add to GitHub Secrets:**
   - Name: `AUTH_HEADER`
   - Value: `Bearer your-token` or `ApiKey your-key`

2. **Update workflow file:**
   ```yaml
   env:
     AUTH_HEADER: ${{ secrets.AUTH_HEADER }}
   ```

## 🔧 How It Works

The script automatically uses authentication if secrets are set:

- `API_KEY` → Adds header: `X-API-Key: <value>`
- `API_TOKEN` → Adds header: `Authorization: Bearer <value>`
- `AUTH_HEADER` → Adds header: `Authorization: <value>`

## 🧪 Testing Authentication

### Test with API Key

```bash
# Set API key
export API_KEY="your-api-key"

# Run script
bash .github/scripts/status-check.sh
```

### Test with Bearer Token

```bash
# Set token
export API_TOKEN="your-bearer-token"

# Run script
bash .github/scripts/status-check.sh
```

### Test Manually

```bash
# Test endpoint with API key
curl -H "X-API-Key: your-key" \
     https://api-gateway.soulverse.us/api/news

# Test with Bearer token
curl -H "Authorization: Bearer your-token" \
     https://api-gateway.soulverse.us/api/news
```

## 📊 Response Code Interpretation

With authentication, you'll see different response codes:

- **200, 201, 204** - Success (operational)
- **400** - Bad Request (operational, needs proper payload)
- **401, 403** - Unauthorized (operational, but token might be invalid/expired)
- **404** - Not Found (endpoint doesn't exist OR still needs auth)
- **405** - Method Not Allowed (operational, endpoint exists)
- **500, 503** - Server Error (down)

## 🔍 Troubleshooting

### Still Getting 404 After Adding Auth

1. **Verify token/key is correct**
   - Test manually with curl
   - Check token hasn't expired

2. **Check header format**
   - Some APIs need: `Authorization: Bearer token`
   - Others need: `X-API-Key: key`
   - Verify in API documentation

3. **Check endpoint paths**
   - Verify paths are correct
   - Some APIs have version prefixes: `/api/v1/...`

4. **Check API Gateway routing**
   - Endpoints might be behind different paths
   - Some might require specific query parameters

### Getting 401/403

- Token/key is invalid or expired
- Token doesn't have required permissions
- Regenerate token/key

## 💡 Best Practices

1. **Use GitHub Secrets** - Never hardcode credentials
2. **Rotate tokens regularly** - Update secrets periodically
3. **Use least privilege** - Only grant read permissions for monitoring
4. **Monitor token expiration** - Set reminders to renew

## 📝 Example Workflow Update

```yaml
- name: Check API Status
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
    API_KEY: ${{ secrets.API_KEY }}
    # Or use:
    # API_TOKEN: ${{ secrets.API_TOKEN }}
    # AUTH_HEADER: ${{ secrets.AUTH_HEADER }}
  run: bash .github/scripts/status-check.sh
```

---

**After adding authentication, your APIs should return 200, 400, 401, or 403 instead of 404!**

