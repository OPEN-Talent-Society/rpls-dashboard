#!/bin/bash
# Generate secure API keys for Qdrant
# Usage: ./generate-keys.sh

set -e

echo "🔐 Generating Qdrant API Keys"
echo "================================"
echo ""

# Generate admin API key
echo "📝 Generating Admin API Key (full access)..."
ADMIN_KEY=$(openssl rand -base64 48 | tr -d '/+=' | cut -c1-64)
echo "✅ Admin Key: ${ADMIN_KEY}"
echo ""

# Generate read-only API key
echo "📝 Generating Read-Only API Key (search only)..."
READONLY_KEY=$(openssl rand -base64 48 | tr -d '/+=' | cut -c1-64)
echo "✅ Read-Only Key: ${READONLY_KEY}"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📄 Creating .env file..."
    cat > .env << EOF
# Qdrant Security Configuration
# Generated: $(date)
# NEVER commit this file to git!

# Qdrant API Keys
QDRANT_API_KEY=${ADMIN_KEY}
QDRANT_READ_ONLY_API_KEY=${READONLY_KEY}

# Qdrant URLs
QDRANT_URL=https://qdrant.harbor.fyi
QDRANT_TAILSCALE_URL=http://100.x.x.x:6333

# Cloudflare Access (Optional)
CF_ACCESS_CLIENT_ID=
CF_ACCESS_CLIENT_SECRET=

# Qdrant Configuration
QDRANT_LOG_LEVEL=info
QDRANT_STORAGE_PATH=/qdrant/storage
QDRANT_SNAPSHOTS_PATH=/qdrant/snapshots

# Backup Configuration
QDRANT_BACKUP_ENABLED=true
QDRANT_BACKUP_SCHEDULE="0 2 * * *"
QDRANT_BACKUP_RETENTION_DAYS=30
EOF
    echo "✅ .env file created"
else
    echo "⚠️  .env file already exists, not overwriting"
    echo "   Manually update with these keys:"
    echo "   QDRANT_API_KEY=${ADMIN_KEY}"
    echo "   QDRANT_READ_ONLY_API_KEY=${READONLY_KEY}"
fi

echo ""
echo "🔐 Key Details:"
echo "================================"
echo "Admin Key Length: ${#ADMIN_KEY} characters"
echo "Read-Only Key Length: ${#READONLY_KEY} characters"
echo ""
echo "📋 Next Steps:"
echo "1. Update your .env file with these keys"
echo "2. Add .env to .gitignore (if not already)"
echo "3. Store keys in password manager (1Password, Bitwarden, etc.)"
echo "4. Set calendar reminder to rotate keys in 90 days"
echo "5. Deploy updated docker-compose.yml: docker-compose up -d"
echo ""
echo "⚠️  IMPORTANT: Keep these keys secure and never commit to git!"
