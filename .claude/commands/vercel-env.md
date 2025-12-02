# Vercel Environment Command

Manage environment variables for Vercel projects.

## Usage

```
/vercel-env <action> [options]
```

## Actions

- `pull` - Pull env vars to local .env.local
- `ls` - List all environment variables
- `add` - Add new environment variable
- `rm` - Remove environment variable
- `sync` - Sync from .env file to Vercel

## Options

- `--environment` - Target environment (production|preview|development)
- `--decrypt` - Show decrypted values (for ls)

## Workflow

### Pull Environment Variables
```bash
/vercel-env pull
# Pulls all env vars to .env.local
```

### List Environment Variables
```bash
/vercel-env ls
/vercel-env ls --decrypt
```

### Add Environment Variable
```bash
/vercel-env add DATABASE_URL --environment production
```

### Sync from .env File
```bash
/vercel-env sync .env.production
```

## Implementation

```bash
#!/bin/bash
# Vercel Environment Command
set -e

ACTION="$1"
shift 2>/dev/null || true

echo "🔐 Vercel Environment Variables"
echo "================================"

# Check if Vercel CLI is available
if ! command -v vercel &> /dev/null; then
  echo "❌ Vercel CLI not installed. Run: pnpm add -g vercel"
  exit 1
fi

case "$ACTION" in
  pull)
    ENV_FILE="${1:-.env.local}"
    echo "📥 Pulling environment variables to $ENV_FILE..."
    vercel env pull "$ENV_FILE" --yes
    echo "✅ Environment variables saved to $ENV_FILE"
    echo ""
    echo "⚠️  Remember: Never commit .env.local to git!"
    ;;

  ls|list)
    DECRYPT_FLAG=""
    [[ "$*" == *"--decrypt"* ]] && DECRYPT_FLAG="--decrypt"
    echo "📋 Environment Variables:"
    echo ""
    vercel env ls $DECRYPT_FLAG
    ;;

  add)
    VAR_NAME="$1"
    ENV="${2:-production preview development}"

    if [ -z "$VAR_NAME" ]; then
      echo "Usage: /vercel-env add <VAR_NAME> [environment]"
      exit 1
    fi

    echo "➕ Adding $VAR_NAME..."
    echo "   Environments: $ENV"
    echo ""
    echo "Enter value (or pipe from stdin):"
    vercel env add "$VAR_NAME" $ENV
    echo ""
    echo "✅ Environment variable added"
    echo "💡 Redeploy to apply: /vercel-deploy --prod"
    ;;

  rm|remove)
    VAR_NAME="$1"
    ENV="${2:-production preview development}"

    if [ -z "$VAR_NAME" ]; then
      echo "Usage: /vercel-env rm <VAR_NAME> [environment]"
      exit 1
    fi

    echo "🗑️  Removing $VAR_NAME from $ENV..."
    vercel env rm "$VAR_NAME" $ENV --yes
    echo "✅ Environment variable removed"
    ;;

  sync)
    ENV_FILE="$1"
    TARGET_ENV="${2:-production}"

    if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
      echo "Usage: /vercel-env sync <.env-file> [environment]"
      exit 1
    fi

    echo "🔄 Syncing $ENV_FILE to Vercel ($TARGET_ENV)..."
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and empty lines
      [[ "$line" =~ ^#.*$ ]] && continue
      [[ -z "$line" ]] && continue

      # Extract key and value
      KEY=$(echo "$line" | cut -d'=' -f1)
      VALUE=$(echo "$line" | cut -d'=' -f2-)

      echo "   Adding $KEY..."
      echo "$VALUE" | vercel env add "$KEY" "$TARGET_ENV" --force 2>/dev/null || true
    done < "$ENV_FILE"

    echo ""
    echo "✅ Sync complete!"
    echo "💡 Redeploy to apply: /vercel-deploy --prod"
    ;;

  *)
    echo "Usage: /vercel-env <action> [options]"
    echo ""
    echo "Actions:"
    echo "  pull [file]              Pull env vars to local file"
    echo "  ls [--decrypt]           List environment variables"
    echo "  add <name> [env]         Add environment variable"
    echo "  rm <name> [env]          Remove environment variable"
    echo "  sync <file> [env]        Sync .env file to Vercel"
    echo ""
    echo "Environments: production, preview, development"
    ;;
esac
```

## Example Output

### Pull
```
🔐 Vercel Environment Variables
================================
📥 Pulling environment variables to .env.local...
✅ Environment variables saved to .env.local

⚠️  Remember: Never commit .env.local to git!
```

### List
```
🔐 Vercel Environment Variables
================================
📋 Environment Variables:

  Name                    Environments            Updated
  DATABASE_URL            Production, Preview     2d ago
  NEXTAUTH_SECRET         Production, Preview     2d ago
  PAYLOAD_SECRET          Production, Preview     2d ago
  BREVO_API_KEY           Production              2d ago
  NEXT_PUBLIC_APP_URL     Production, Preview     1d ago
```

### Add
```
🔐 Vercel Environment Variables
================================
➕ Adding NEW_API_KEY...
   Environments: production preview development

Enter value (or pipe from stdin):
? What's the value of NEW_API_KEY? [hidden]

✅ Environment variable added
💡 Redeploy to apply: /vercel-deploy --prod
```

## Related Commands

- `/vercel-deploy` - Deploy to Vercel
- `/vercel-status` - Check deployment status
- `/vercel-logs` - View deployment logs
