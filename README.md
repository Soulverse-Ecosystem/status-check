# GitHub Actions + Slack Monitoring

A complete **100% free** solution using GitHub Actions to monitor APIs, update GitHub Pages status page, and send Slack notifications.

## Overview

This solution:
- ✅ Checks multiple API endpoints on a schedule (GitHub Actions)
- ✅ Compares current status with previous status
- ✅ Updates GitHub Pages status page automatically
- ✅ Sends Slack notifications **only when status changes**
- ✅ **No n8n needed** - Runs entirely on GitHub
- ✅ **100% free** - GitHub Actions + Slack webhooks

## Cost: $0/month

- GitHub Actions: Free (2000 min/month private, unlimited public)
- GitHub Pages: Free (public repos) or $4/month (private repos)
- Slack Webhook: Free (unlimited)
- **Total: $0/month (public) or $4/month (private)**

##  Architecture

```
GitHub Actions (Cron: every 5 minutes)
  ↓
Check APIs (Bash script)
  ↓
Compare with Previous Status (stored in repo)
  ↓
IF Status Changed?
  ├─ YES → Send Slack Notification
  └─ NO → Skip notification
  ↓
Update status.json (GitHub repository)
  ↓
Commit and Push (triggers GitHub Pages update)
```

## Prerequisites

1. **GitHub Account**
   - Public or private repository
   - GitHub Actions enabled

2. **Slack Workspace**
   - Access to create webhooks
   - See `SLACK_SETUP.md` for setup

3. **No n8n Required!**
   - Everything runs on GitHub Actions

##  Quick Start

### Step 1: Create GitHub Repository

1. Create new repository (public or private)
2. Enable GitHub Pages (Settings → Pages)
3. Branch: `main`, Folder: `/ (root)`

### Step 2: Set Up Slack Webhook

1. Create Slack webhook (see `SLACK_SETUP.md`)
2. Copy webhook URL
3. Add as GitHub Secret (see Step 4)

### Step 3: Upload Files

1. Copy `.github/workflows/status-check.yml` to your repo
2. Copy `.github/scripts/status-check.sh` to your repo
3. Copy `index.html` to your repo root
4. Commit and push

### Step 4: Configure GitHub Secrets

1. Repository → Settings → Secrets and variables → Actions
2. Add secrets:
   - `SLACK_WEBHOOK_URL` - Your Slack webhook URL

### Step 5: Configure APIs

Edit `.github/scripts/status-check.sh`:
```bash
# Define your APIs
apis=(
  "API|https://api.example.com/health"
  "Auth|https://auth.example.com/health"
  "Database|https://db.example.com/health"
)
```

### Step 6: Enable Workflow

1. Go to Actions tab
2. Enable workflows
3. Workflow runs automatically every 5 minutes!

##  Files Structure

```
github-actions-slack/
├── README.md                          # This file
├── .github/
│   ├── workflows/
│   │   └── status-check.yml           # GitHub Actions workflow
│   └── scripts/
│       └── status-check.sh           # API checking script
├── index.html                         # Status page HTML
```

##  How It Works

### Status Comparison

1. **First Run**: 
   - Checks all APIs
   - Creates `status.json` and `previous-status.json`
   - No Slack notification (baseline)

2. **Subsequent Runs**:
   - Checks APIs
   - Compares with `previous-status.json`
   - If changed → Send Slack notification
   - If unchanged → Skip notification
   - Updates both files

### File Storage

- `status.json` - Current status (for GitHub Pages)
- `previous-status.json` - Previous status (for comparison)

### Workflow Execution

1. GitHub Actions triggers on schedule
2. Runs `status-check.sh` script
3. Script checks APIs and compares status
4. If status changed → Sends Slack notification
5. Updates `status.json` and `previous-status.json`
6. Commits and pushes changes
7. GitHub Pages automatically updates

##  Features

### Slack Notifications

- **Service Goes Down**: 🔴 Alert notification
- **Service Recovers**: 🟢 Recovery notification
- **Status Unchanged**: No notification (silent)

### GitHub Pages

- Real-time status page
- Auto-updates on every check
- Beautiful UI with status indicators
- Auto-refreshes every 30 seconds

### Status Tracking

- Tracks status changes over time
- Stores previous status for comparison
- Prevents duplicate notifications

## Configuration

### Change Check Interval

Edit `.github/workflows/status-check.yml`:
```yaml
schedule:
  - cron: '*/5 * * * *'  # Every 5 minutes
  # - cron: '*/1 * * * *'  # Every 1 minute
  # - cron: '*/15 * * * *'  # Every 15 minutes
```

### Add More APIs

Edit `.github/scripts/status-check.sh`:
```bash
apis=(
  "API|https://api.example.com/health"
  "Auth|https://auth.example.com/health"
  "New Service|https://new.example.com/health"
)
```

### Customize Slack Messages

Edit `.github/scripts/status-check.sh` - `send_slack_notification()` function.

## Status Page

The status page (`index.html`):
- Reads `status.json` from repository
- Displays all services with status
- Auto-refreshes every 30 seconds
- Beautiful, responsive design
- Shows last updated time

##  Notification Behavior

### First Run
- Checks all APIs
- Creates status files
- **No Slack notification** (establishes baseline)

### Status Changes
- **Down → Operational**: Recovery notification 🟢
- **Operational → Down**: Alert notification 🔴
- **Down → Down**: No notification (already down)
- **Operational → Operational**: No notification (still up)

##  Advantages

1. **100% Free** - No server costs
2. **No Maintenance** - Fully managed by GitHub
3. **No n8n Needed** - Runs entirely on GitHub
4. **Reliable** - GitHub's infrastructure
5. **Easy Setup** - Just YAML and bash scripts
6. **Version Controlled** - All code in git
7. **Scalable** - Handles many APIs

##  vs n8n Solution

| Feature | GitHub Actions | n8n |
|---------|---------------|-----|
| **Cost** | $0 | $0-15/month |
| **Server** | ❌ None | ✅ Needed |
| **Setup** | Easy (YAML) | Medium (Docker) |
| **Maintenance** | None | Updates needed |
| **Visual Builder** | ❌ No | ✅ Yes |
| **Dependencies** | GitHub only | n8n + server |

##  Migration from n8n

If you have n8n workflow:
1. Export your API list
2. Copy to `status-check.sh`
3. Set up GitHub Actions
4. Add Slack webhook
5. Done! (Can remove n8n)

## 📚 Documentation

- **README.md** - This file (overview)
- **SLACK_SETUP.md** - Slack webhook setup guide
- **CONFIGURATION.md** - Detailed configuration
- **TESTING.md** - Testing procedures

##  Troubleshooting

### Workflow Not Running

1. Check Actions tab for errors
2. Verify workflow file is in `.github/workflows/`
3. Check workflow syntax (YAML)
4. Verify cron schedule is correct

### No Slack Notifications

1. Check `SLACK_WEBHOOK_URL` secret is set
2. Verify webhook URL is correct
3. Check workflow logs for errors
4. Test webhook manually

### Status Page Not Updating

1. Check `status.json` exists in repository
2. Verify GitHub Pages is enabled
3. Check `index.html` is in root
4. Verify file paths are correct

##  Pro Tips

1. **Use Public Repo** - Free GitHub Actions (unlimited)
2. **Store Secrets Securely** - Use GitHub Secrets
3. **Monitor Actions** - Check execution history
4. **Test Manually** - Use workflow_dispatch trigger
5. **Version Control** - All changes tracked in git

## Bonus Features

- Manual trigger available (workflow_dispatch)
- Execution history in Actions tab
- Status files tracked in git
- Easy to customize and extend

---

**Perfect for**: Teams wanting free, zero-maintenance monitoring without n8n!

