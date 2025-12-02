# Vercel Status Command

Check the status of recent deployments and project configuration.

## Usage

```
/vercel-status [deployment-url]
```

## Options

- `deployment-url` - Optional specific deployment to inspect

## Workflow

1. List recent deployments
2. Show deployment states
3. Display production URL
4. Check project configuration

## Implementation

```bash
#!/bin/bash
# Vercel Status Command
set -e

DEPLOYMENT_URL="$1"

echo "📊 Vercel Project Status"
echo "========================"

# Check if Vercel CLI is available
if ! command -v vercel &> /dev/null; then
  echo "❌ Vercel CLI not installed. Run: pnpm add -g vercel"
  exit 1
fi

# Check project link
if [ ! -f ".vercel/project.json" ]; then
  echo "⚠️  Project not linked to Vercel"
  echo "   Run: vercel link"
  exit 1
fi

# Get project info
PROJECT_ID=$(cat .vercel/project.json | jq -r '.projectId')
ORG_ID=$(cat .vercel/project.json | jq -r '.orgId')

echo "📁 Project ID: $PROJECT_ID"
echo "🏢 Org ID: $ORG_ID"
echo ""

if [ -n "$DEPLOYMENT_URL" ]; then
  # Inspect specific deployment
  echo "🔍 Inspecting: $DEPLOYMENT_URL"
  echo ""
  vercel inspect "$DEPLOYMENT_URL"
else
  # List recent deployments
  echo "📋 Recent Deployments:"
  echo ""
  vercel ls --limit 5

  echo ""
  echo "🌐 Production Domains:"
  vercel domains ls 2>/dev/null || echo "   No custom domains configured"
fi

echo ""
echo "💡 Useful commands:"
echo "   vercel logs <url>     - View deployment logs"
echo "   vercel inspect <url>  - Get deployment details"
echo "   vercel env ls         - List environment variables"
```

## Example Output

```
📊 Vercel Project Status
========================
📁 Project ID: prj_xxx
🏢 Org ID: team_xxx

📋 Recent Deployments:

  Age       Status   Duration   URL
  2h ago    Ready    45s        ai-academy-xxx.vercel.app
  5h ago    Ready    52s        ai-academy-yyy.vercel.app
  1d ago    Ready    48s        ai-academy-zzz.vercel.app

🌐 Production Domains:
  aienablement.academy
  www.aienablement.academy

💡 Useful commands:
   vercel logs <url>     - View deployment logs
   vercel inspect <url>  - Get deployment details
   vercel env ls         - List environment variables
```

## Related Commands

- `/vercel-deploy` - Deploy to Vercel
- `/vercel-logs` - View deployment logs
- `/vercel-env` - Manage environment variables
