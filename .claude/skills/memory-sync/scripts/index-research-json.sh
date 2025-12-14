#!/bin/bash
# ====================================================
# JSON RESEARCH FILE INDEXER
# Converts JSON research files to structured text and
# indexes them into Qdrant's research collection
# ====================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Load environment
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Configuration
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
COLLECTION="research"
EMBEDDING_MODEL="gemini-embedding-001"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Generate embedding using Gemini API
generate_embedding() {
  local text="$1"
  # Truncate to ~8000 chars for embedding
  text="${text:0:8000}"

  # Escape text for JSON
  local escaped_text
  escaped_text=$(echo "$text" | jq -Rs .)

  local response
  response=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/$EMBEDDING_MODEL:embedContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"content\": {\"parts\": [{\"text\": $escaped_text}]}, \"outputDimensionality\": 768}" 2>/dev/null)

  # Extract embedding vector
  local embedding
  embedding=$(echo "$response" | jq -c '.embedding.values')

  if [[ -z "$embedding" ]] || [[ "$embedding" == "null" ]]; then
    error "Gemini API error: $(echo "$response" | jq -r '.error.message // "unknown"')"
    echo "null"
  else
    echo "$embedding"
  fi
}

# Convert JSON research file to structured text
json_to_text() {
  local json_file="$1"
  local org_name

  # Extract organization name
  org_name=$(jq -r '.organization.name // .organization_name // .company_name // "Unknown"' "$json_file" 2>/dev/null)

  # Build structured text representation
  cat << EOF
# Research Profile: ${org_name}

## Organization Overview
$(jq -r '
  if .organization then
    "Name: " + (.organization.name // "N/A") + "\n" +
    "Tagline: " + (.organization.tagline // "N/A") + "\n" +
    "Website: " + (.organization.website // "N/A") + "\n" +
    "Industry: " + (.organization.industry // "N/A")
  elif .company_name then
    "Name: " + .company_name + "\n" +
    "Tagline: " + (.tagline // "N/A") + "\n" +
    "Website: " + (.website // "N/A")
  else
    "Name: " + (.organization_name // "Unknown")
  end
' "$json_file" 2>/dev/null)

## Mission and Vision
$(jq -r '
  if .mission_vision_values then
    "Mission: " + (.mission_vision_values.mission // "N/A") + "\n" +
    "Vision: " + (.mission_vision_values.vision // "N/A") + "\n" +
    "Core Philosophy: " + (.mission_vision_values.core_philosophy // .mission_vision_values.philosophy // "N/A")
  elif .mission then
    "Mission: " + (.mission.primary // .mission // "N/A") + "\n" +
    "Vision: " + (.mission.vision // "N/A") + "\n" +
    "Approach: " + (.mission.approach // "N/A")
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Services and Offerings
$(jq -r '
  if .services then
    if .services.service_lines then
      [.services.service_lines[] | "- " + .name + ": " + .description] | join("\n")
    elif .services.specific_offerings then
      [.services_products.specific_offerings[] | "- " + .name + ": " + .description] | join("\n")
    else
      .services | tostring
    end
  elif .services_products then
    if .services_products.specific_offerings then
      [.services_products.specific_offerings[] | "- " + .name + ": " + .description] | join("\n")
    else
      "Service Model: " + (.services_products.service_model // "N/A")
    end
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Target Audience
$(jq -r '
  if .target_audience then
    "Primary: " + (.target_audience.primary // "N/A") + "\n" +
    if .target_audience.characteristics then
      "Characteristics:\n" + ([.target_audience.characteristics[] | "  - " + .] | join("\n"))
    else "" end
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Key Differentiators
$(jq -r '
  if .key_differentiators then
    if type == "array" then
      [.key_differentiators[] | "- " + .] | join("\n")
    elif .key_differentiators.unique_value_propositions then
      [.key_differentiators.unique_value_propositions[] | "- " + .] | join("\n")
    elif .key_differentiators.specific_advantages then
      [.key_differentiators.specific_advantages[] | "- " + .] | join("\n")
    else
      .key_differentiators | tostring
    end
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Team and Leadership
$(jq -r '
  if .team then
    if .team.leadership then
      [.team.leadership[] | "- " + .name + " (" + .title + "): " + (.background // "N/A")] | join("\n")
    else
      .team | tostring
    end
  elif .team_members then
    if .team_members.founder then
      "Founder: " + .team_members.founder.name + " - " + .team_members.founder.title
    else
      .team_members | tostring
    end
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Contact Information
$(jq -r '
  if .contact_information then
    "Website: " + (.contact_information.website // "N/A") + "\n" +
    if .contact_information.social_media then
      "LinkedIn: " + (.contact_information.social_media.linkedin // .contact_information.social_media.linkedin_company // "N/A")
    else "" end
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)

## Keywords and Tags
$(jq -r '
  if .semantic_keywords then
    [.semantic_keywords[]] | join(", ")
  elif .seo_keywords then
    [.seo_keywords[]] | join(", ")
  else
    "Not available"
  end
' "$json_file" 2>/dev/null)
EOF
}

# Index a single JSON file
index_json_file() {
  local json_file="$1"
  local filename=$(basename "$json_file")
  local org_name

  log "Processing: $filename"

  # Extract org name for metadata
  org_name=$(jq -r '.organization.name // .organization_name // .company_name // "Unknown"' "$json_file" 2>/dev/null)

  # Convert to text
  local text_content
  text_content=$(json_to_text "$json_file")

  if [[ -z "$text_content" ]]; then
    error "Failed to convert $filename to text"
    return 1
  fi

  log "Converted to text (${#text_content} chars)"

  # Generate embedding
  log "Generating embedding..."
  local embedding
  embedding=$(generate_embedding "$text_content")

  if [[ "$embedding" == "null" ]] || [[ -z "$embedding" ]]; then
    error "Failed to generate embedding for $filename"
    return 1
  fi

  # Create point ID from filename hash using python for reliable conversion
  local point_id
  point_id=$(echo -n "$filename" | md5sum | cut -c1-8 | python3 -c "import sys; h=sys.stdin.read().strip(); print(int(h, 16) % 2147483647)")

  # Build Qdrant upsert payload
  local payload
  payload=$(jq -n \
    --arg org "$org_name" \
    --arg source "$filename" \
    --arg text "$text_content" \
    --arg file "$json_file" \
    --arg type "research" \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      organization: $org,
      source_file: $source,
      content: $text,
      file_path: $file,
      content_type: $type,
      indexed_at: $date,
      owner_id: "adam_kovacs",
      scope: "personal",
      data_class: "internal"
    }')

  # Upsert to Qdrant
  log "Upserting to Qdrant ($COLLECTION collection)..."

  local qdrant_payload
  qdrant_payload=$(jq -n \
    --argjson id "$point_id" \
    --argjson vector "$embedding" \
    --argjson payload "$payload" \
    '{points: [{id: $id, vector: $vector, payload: $payload}]}')

  local response
  response=$(curl -s -X PUT "$QDRANT_URL/collections/$COLLECTION/points?wait=true" \
    -H "Content-Type: application/json" \
    ${QDRANT_API_KEY:+-H "api-key: $QDRANT_API_KEY"} \
    -d "$qdrant_payload" 2>/dev/null)

  if echo "$response" | jq -e '.status == "ok"' >/dev/null 2>&1; then
    success "Indexed: $org_name (ID: $point_id)"
    return 0
  else
    error "Failed to index $filename: $response"
    return 1
  fi
}

# Main
main() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}JSON RESEARCH INDEXER (Gemini Embeddings)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Validate API keys
  if [[ -z "$GEMINI_API_KEY" ]]; then
    error "GEMINI_API_KEY not set in .env"
    exit 1
  fi

  if [[ -z "$QDRANT_API_KEY" ]]; then
    error "QDRANT_API_KEY not set in .env"
    exit 1
  fi

  # Check if collection exists
  local collection_check
  collection_check=$(curl -s "$QDRANT_URL/collections/$COLLECTION" \
    ${QDRANT_API_KEY:+-H "api-key: $QDRANT_API_KEY"} 2>/dev/null)

  if ! echo "$collection_check" | jq -e '.result.status == "green"' >/dev/null 2>&1; then
    warn "Collection '$COLLECTION' may not exist or is not ready"
  fi

  local indexed=0
  local failed=0

  # Process each file
  for file in "$@"; do
    if [[ -f "$file" ]] && [[ "$file" == *.json ]]; then
      if index_json_file "$file"; then
        ((indexed++))
      else
        ((failed++))
      fi
      echo "---"
    else
      warn "Skipping: $file (not a JSON file)"
    fi
  done

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Summary:${NC}"
  echo "  Indexed: $indexed"
  echo "  Failed: $failed"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

if [[ $# -eq 0 ]]; then
  echo "Usage: $(basename "$0") <json_file> [json_file...]"
  echo "Example: $(basename "$0") talent-foundation-research.json red_rebel_learning_research.json"
  exit 1
fi

main "$@"
