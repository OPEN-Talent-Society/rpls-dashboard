#!/bin/bash
# Sync Claude Flow memory to Supabase agent_memory table
# Usage: ./sync-memory-to-supabase.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"

# Load environment
if [ -f "${CODEBUILD_ROOT}/.env" ]; then
  source "${CODEBUILD_ROOT}/.env"
fi

if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "Error: SUPABASE_ACCESS_TOKEN not set"
  exit 1
fi

# Function to insert a single memory entry
insert_memory() {
  local KEY="$1"
  local NAMESPACE="$2"
  local VALUE="$3"
  local SESSION_ID="$4"

  # Escape single quotes for SQL
  VALUE_ESCAPED=$(echo "$VALUE" | sed "s/'/''/g")
  KEY_ESCAPED=$(echo "$KEY" | sed "s/'/''/g")

  QUERY="INSERT INTO agent_memory (key, namespace, value, metadata, agent_id, agent_email) VALUES ('${KEY_ESCAPED}', '${NAMESPACE}', '${VALUE_ESCAPED}', '{\"type\": \"knowledge\", \"session_id\": \"${SESSION_ID}\"}', 'claude-code', 'claude-code@aienablement.academy') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW() RETURNING id, key;"

  # Create JSON payload using jq
  PAYLOAD=$(jq -n --arg query "$QUERY" '{"query": $query}')

  RESULT=$(curl -s -X POST "https://api.supabase.com/v1/projects/zxcrbcmdxpqprpxhsntc/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>&1)

  if echo "$RESULT" | grep -q '"id"'; then
    echo "✅ Synced: $KEY"
  else
    echo "⚠️ Failed: $KEY - $RESULT"
  fi
}

echo "Syncing Claude Flow memory to Supabase..."

# Get memory entries from Claude Flow and sync each one
# For now, let's sync the key entries we know about

# Scientific Cubism Design System
insert_memory "swarm/scientific-cubism/init" "default" '{"design_system":"Scientific Cubism","colors":{"background":"#1A2332","accent_cyan":"#42A5F5"},"pages_to_create":10}' "session-cf-1764441110270-bp7e"

insert_memory "swarm/scientific-cubism/batch1-complete" "default" '{"batch":1,"pages":["courses","about","contact","pricing"],"design":"Scientific Cubism"}' "session-cf-1764441110270-bp7e"

insert_memory "swarm/scientific-cubism/batch2-complete" "default" '{"batch":2,"pages":["login","register","dashboard","faq"],"total_so_far":8}' "session-cf-1764441110270-bp7e"

insert_memory "scientific-cubism/batch-3-completion" "default" '{"batch":3,"pages":["courses/[slug]/page.tsx","resources/page.tsx"],"total":10,"status":"completed"}' "session-cf-1764441110270-bp7e"

# UX Review
insert_memory "ux-review/screenshot-analysis" "default" '{"hero":"Transform section analysis","issues":["CTAs blend in","Cards lack differentiation","Need more Scientific Cubism boldness"]}' "session-cf-1764441110270-bp7e"

# Design Direction
insert_memory "design-direction/ppt-colors" "default" '{"palette":"Deep Navy #0B2B4A, Teal #158158, Blue #058DC7","style":"flat cubist/formist"}' "session-cf-1764441110270-bp7e"

insert_memory "design-verification/success" "default" '{"status":"success","features":["Apple-inspired design","12 courses","Manrope+DM Sans","gradient badges"]}' "session-cf-1764441110270-bp7e"

insert_memory "design-verification/css-fixes" "default" '{"fixes":"Converted Tailwind custom colors to direct CSS","classes":["bg-coral/20","text-navy","ring-electric"]}' "session-cf-1764441110270-bp7e"

# Project Status
insert_memory "project/local-testing" "default" '{"server":"http://localhost:3000","status":"running","checklist":["Landing page","Navigation","Course catalog","Filters"]}' "session-cf-1764441110270-bp7e"

insert_memory "project/deployment-ready" "default" '{"status":"ready_to_deploy","repo":"AI-Enablement-Academy/project-campfire","platform":"DigitalOcean"}' "session-cf-1764441110270-bp7e"

insert_memory "project/deployment-options" "default" '{"tech_stack":"Next.js 15.5.6, React 19, TypeScript","options":["Vercel","Netlify","DigitalOcean"]}' "session-cf-1764441110270-bp7e"

insert_memory "project/mvp-status" "default" '{"completed":["Landing page","Course catalog","12 courses","Filtering"],"pending":["Stripe","Cal.com","Formbricks"]}' "session-cf-1764441110270-bp7e"

# Catalog
insert_memory "catalog/init" "default" '{"task":"Build course catalog page","agents":4,"approach":"parallel development"}' "session-cf-1764441110270-bp7e"

insert_memory "catalog/implementation" "default" '{"files":["types/course.ts","lib/courses.ts","app/courses/page.tsx"],"courses":4}' "session-cf-1764441110270-bp7e"

insert_memory "catalog/completion" "default" '{"status":"success","build_time":"992ms","features":["search","level_filter","price_filter","stripe"]}' "session-cf-1764441110270-bp7e"

# Hive MVP
insert_memory "hive-mvp/sections-completed" "default" '{"agents":["About Section Builder","Contact Section Builder","Footer Builder"],"status":"completed"}' "session-cf-1764441110270-bp7e"

insert_memory "hive-mvp/build-fix" "default" '{"agent":"Build Fixer","fix":"Changed module.exports to export default with withPayload wrapper"}' "session-cf-1764441110270-bp7e"

# Architecture Audit
insert_memory "swarm-architecture-audit/completion" "default" '{"status":"completed","changes":{"emailService":"Brevo","userFeedback":"Formbricks"}}' "session-cf-1764441110270-bp7e"

insert_memory "swarm-architecture-audit/decisions" "default" '{"emailService":"Brevo","userFeedback":"Formbricks","source":"V1-System-Architecture.md"}' "session-cf-1764441110270-bp7e"

# Course Catalog Swarm
insert_memory "swarm-course-catalog/completion" "default" '{"task":"Rebuild course catalog with AEA framework","status":"completed","framework":{"impact_levels":3,"capability_levels":4,"total_courses":12}}' "session-cf-1764441110270-bp7e"

insert_memory "design-direction/powerpoint-analysis" "default" '{"task":"Analyzing Academy PowerPoint for color palette and cubist design inspiration"}' "session-cf-1764441110270-bp7e"

echo ""
echo "Memory sync complete!"
