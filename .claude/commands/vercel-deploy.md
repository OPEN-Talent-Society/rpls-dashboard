# Vercel Deploy Command

Deploy the current project to Vercel with optional production flag.

## Usage

```
/vercel-deploy [options]
```

## Options

- `--prod` - Deploy to production (default: preview)
- `--force` - Force new deployment (skip cache)
- `--prebuilt` - Deploy pre-built output

## Workflow

1. Check Vercel CLI is installed
2. Verify project is linked
3. Pull latest environment variables
4. Deploy to specified environment
5. Output deployment URL and status

## Implementation

```bash
#!/bin/bash
# Vercel Deploy Command
set -e

# Parse arguments
PROD_FLAG=""
FORCE_FLAG=""
PREBUILT_FLAG=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --prod) PROD_FLAG="--prod" ;;
    --force) FORCE_FLAG="--force" ;;
    --prebuilt) PREBUILT_FLAG="--prebuilt" ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

echo "🚀 Vercel Deployment"
echo "==================="

# Check if Vercel CLI is available
if ! command -v vercel &> /dev/null; then
  echo "Installing Vercel CLI..."
  pnpm add -g vercel
fi

# Check if project is linked
if [ ! -f ".vercel/project.json" ]; then
  echo "⚠️  Project not linked. Running vercel link..."
  vercel link
fi

# Pull environment variables
echo "📥 Pulling environment variables..."
vercel env pull .env.local --yes 2>/dev/null || true

# Run deployment
echo ""
echo "📦 Starting deployment..."
if [ -n "$PROD_FLAG" ]; then
  echo "🎯 Target: Production"
else
  echo "🎯 Target: Preview"
fi

DEPLOY_OUTPUT=$(vercel $PROD_FLAG $FORCE_FLAG $PREBUILT_FLAG 2>&1)
DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -E "https://" | tail -1)

echo ""
echo "✅ Deployment complete!"
echo "🔗 URL: $DEPLOY_URL"

# Verify deployment
echo ""
echo "🔍 Verifying deployment..."
sleep 5
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOY_URL/api/health" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" == "200" ]; then
  echo "✅ Health check passed (HTTP $HTTP_STATUS)"
else
  echo "⚠️  Health check returned HTTP $HTTP_STATUS"
  echo "   Check logs: vercel logs $DEPLOY_URL"
fi
```

## Example Output

```
🚀 Vercel Deployment
===================
📥 Pulling environment variables...
📦 Starting deployment...
🎯 Target: Production

Vercel CLI 33.0.0
🔍  Inspect: https://vercel.com/team/project/xxx
✅  Production: https://project.vercel.app

✅ Deployment complete!
🔗 URL: https://project.vercel.app

🔍 Verifying deployment...
✅ Health check passed (HTTP 200)
```

## Related Commands

- `/vercel-status` - Check deployment status
- `/vercel-logs` - View deployment logs
- `/vercel-env` - Manage environment variables
