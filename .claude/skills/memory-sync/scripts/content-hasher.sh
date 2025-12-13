#!/bin/bash
# content-hasher.sh
# Generate consistent SHA256 hashes for content deduplication
# Supports stdin, arguments, and Supabase duplicate checking

set -euo pipefail

# Load environment variables
ENV_FILE="/Users/adamkovacs/Documents/codebuild/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Configuration
CHECK_DUPLICATES=false
LOWERCASE=false
CONTENT=""
VERBOSE=false

# Usage information
usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [CONTENT]

Generate consistent SHA256 hashes for content deduplication.

OPTIONS:
  --check, -c       Check if hash exists in Supabase learnings
  --lowercase, -l   Convert content to lowercase before hashing
  --verbose, -v     Show detailed output
  --help, -h        Show this help message

CONTENT:
  If provided as argument, uses that content
  Otherwise, reads from stdin

EXIT CODES:
  0 - Hash generated successfully (or unique if --check)
  1 - Duplicate exists (only with --check)
  2 - Error occurred

EXAMPLES:
  # Hash from stdin
  echo "content" | $(basename "$0")

  # Hash from argument
  $(basename "$0") "content"

  # Check for duplicates in Supabase
  $(basename "$0") --check "content"

  # Hash with lowercase normalization
  $(basename "$0") --lowercase "Content"

EOF
  exit 0
}

# Logging functions
log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --check|-c)
      CHECK_DUPLICATES=true
      shift
      ;;
    --lowercase|-l)
      LOWERCASE=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      ;;
    *)
      CONTENT="$1"
      shift
      ;;
  esac
done

# Read content from stdin if not provided as argument
if [[ -z "$CONTENT" ]]; then
  if [[ -t 0 ]]; then
    log_error "No content provided. Supply content as argument or via stdin."
    exit 2
  fi
  CONTENT=$(cat)
fi

log_verbose "Original content length: ${#CONTENT} bytes"

# Normalize content
normalize_content() {
  local content="$1"

  # Trim leading/trailing whitespace
  content=$(echo "$content" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  # Normalize line endings (convert CRLF to LF)
  content=$(echo "$content" | tr -d '\r')

  # Remove trailing newlines
  content=$(echo -n "$content")

  # Lowercase if flag is set
  if [[ "$LOWERCASE" == "true" ]]; then
    content=$(echo "$content" | tr '[:upper:]' '[:lower:]')
  fi

  echo -n "$content"
}

# Generate hash
generate_hash() {
  local content="$1"

  # Use echo -n to avoid adding newline, pipe to shasum
  echo -n "$content" | shasum -a 256 | awk '{print $1}'
}

# Check if hash exists in Supabase
check_hash_exists() {
  local hash="$1"

  # Validate required environment variables
  if [[ -z "${SUPABASE_URL:-}" ]] || [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
    log_error "SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env"
    exit 2
  fi

  log_verbose "Checking Supabase for hash: $hash"

  # Query Supabase learnings table
  local response
  response=$(curl -s -X GET \
    "${SUPABASE_URL}/rest/v1/learnings?select=id,content_hash&content_hash=eq.${hash}&limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json")

  log_verbose "Supabase response: $response"

  # Check if response contains any records
  local count
  count=$(echo "$response" | jq -r '. | length')

  if [[ "$count" -gt 0 ]]; then
    log_verbose "Hash exists in Supabase (found $count record(s))"
    return 0
  else
    log_verbose "Hash is unique (not found in Supabase)"
    return 1
  fi
}

# Main execution
main() {
  # Normalize the content
  local normalized_content
  normalized_content=$(normalize_content "$CONTENT")

  log_verbose "Normalized content length: ${#normalized_content} bytes"

  # Generate hash
  local hash
  hash=$(generate_hash "$normalized_content")

  log_verbose "Generated hash: $hash"

  # Check for duplicates if flag is set
  if [[ "$CHECK_DUPLICATES" == "true" ]]; then
    if check_hash_exists "$hash"; then
      if [[ "$VERBOSE" == "true" ]]; then
        echo "$hash (DUPLICATE)" >&2
      else
        echo "$hash"
      fi
      exit 1
    else
      if [[ "$VERBOSE" == "true" ]]; then
        echo "$hash (UNIQUE)" >&2
      else
        echo "$hash"
      fi
      exit 0
    fi
  fi

  # Just output the hash
  echo "$hash"
  exit 0
}

# Run main function
main
