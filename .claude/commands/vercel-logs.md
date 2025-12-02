# Vercel Logs Command

View logs from Vercel deployments and serverless functions.

## Usage

```
/vercel-logs [deployment-url] [options]
```

## Options

- `deployment-url` - Deployment URL (uses latest if omitted)
- `--follow` - Stream logs in real-time
- `--since` - Show logs since timestamp
- `--output` - Output format (short|raw)

## Workflow

1. Get latest deployment URL if not specified
2. Fetch deployment logs
3. Display formatted output
4. Optionally stream new logs

## Implementation

```bash
#!/bin/bash
# Vercel Logs Command
set -e

DEPLOYMENT_URL="$1"
FOLLOW_FLAG=""
OUTPUT_FORMAT="short"

shift 2>/dev/null || true

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --follow|-f) FOLLOW_FLAG="--follow" ;;
    --output) OUTPUT_FORMAT="$2"; shift ;;
    --since) SINCE_FLAG="--since=$2"; shift ;;
    *) ;;
  esac
  shift
done

echo "📋 Vercel Logs"
echo "=============="

# Check if Vercel CLI is available
if ! command -v vercel &> /dev/null; then
  echo "❌ Vercel CLI not installed. Run: pnpm add -g vercel"
  exit 1
fi

# Get latest deployment URL if not specified
if [ -z "$DEPLOYMENT_URL" ]; then
  echo "🔍 Finding latest deployment..."
  DEPLOYMENT_URL=$(vercel ls --limit 1 2>/dev/null | grep -E "https://" | awk '{print $NF}')
  if [ -z "$DEPLOYMENT_URL" ]; then
    echo "❌ No deployments found"
    exit 1
  fi
  echo "📌 Using: $DEPLOYMENT_URL"
fi

echo ""

# Build command
CMD="vercel logs $DEPLOYMENT_URL"
[ -n "$FOLLOW_FLAG" ] && CMD="$CMD --follow"
[ -n "$SINCE_FLAG" ] && CMD="$CMD $SINCE_FLAG"
[ "$OUTPUT_FORMAT" != "short" ] && CMD="$CMD --output=$OUTPUT_FORMAT"

# Execute
if [ -n "$FOLLOW_FLAG" ]; then
  echo "📡 Streaming logs (Ctrl+C to stop)..."
  echo ""
fi

eval $CMD
```

## Example Output

```
📋 Vercel Logs
==============
🔍 Finding latest deployment...
📌 Using: https://ai-academy-xxx.vercel.app

2024-01-15T10:30:00.123Z  info   Starting Next.js server
2024-01-15T10:30:01.456Z  info   Connected to database
2024-01-15T10:30:02.789Z  info   Server listening on port 3000
2024-01-15T10:31:15.123Z  info   GET /api/health 200 12ms
2024-01-15T10:32:30.456Z  info   POST /api/auth/magic-link 200 245ms
```

## Log Types

### Build Logs
```bash
# View build output
vercel logs <deployment-url> --output=raw
```

### Function Logs
```bash
# Real-time function logs
vercel logs <deployment-url> --follow
```

### Error Logs
```bash
# Filter for errors
vercel logs <deployment-url> | grep -i error
```

## Related Commands

- `/vercel-deploy` - Deploy to Vercel
- `/vercel-status` - Check deployment status
- `/vercel-env` - Manage environment variables
