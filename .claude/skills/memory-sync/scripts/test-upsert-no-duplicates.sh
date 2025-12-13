#!/bin/bash
# Quick test to verify upsert logic prevents duplicates
# Run this twice - should create doc on first run, update on second run

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load cortex-helpers.sh
source "$PROJECT_DIR/.claude/lib/cortex-helpers.sh"

# Load .env
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

echo "=========================================="
echo "Testing Upsert Logic - No Duplicates Test"
echo "=========================================="

# Test document details
TEST_TITLE="UPSERT-TEST-$(date +%s)"
TEST_MARKDOWN="# Test Document

This is a test document to verify upsert logic.

Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

TEST_METADATA='{"custom-type": "test", "custom-purpose": "upsert-verification"}'

echo ""
echo "Test document title: $TEST_TITLE"
echo ""

# First call - should CREATE
echo "Call 1: Should CREATE new document..."
DOC_ID_1=$(upsert_doc "$TEST_TITLE" "$TEST_MARKDOWN" "$NOTEBOOK_RESOURCES" "/Test/$TEST_TITLE" "test" "$TEST_METADATA")

if [ -n "$DOC_ID_1" ]; then
    echo "  ✅ Created document: $DOC_ID_1"
else
    echo "  ❌ Failed to create document"
    exit 1
fi

echo ""
echo "Waiting 2 seconds..."
sleep 2

# Second call - should UPDATE (not create duplicate)
echo "Call 2: Should UPDATE existing document (no duplicate)..."
UPDATED_MARKDOWN="# Test Document (Updated)

This is the UPDATED test document.

Updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

DOC_ID_2=$(upsert_doc "$TEST_TITLE" "$UPDATED_MARKDOWN" "$NOTEBOOK_RESOURCES" "/Test/$TEST_TITLE" "test" "$TEST_METADATA")

if [ -n "$DOC_ID_2" ]; then
    echo "  ✅ Upserted document: $DOC_ID_2"

    if [ "$DOC_ID_1" == "$DOC_ID_2" ]; then
        echo "  ✅ PASS: Same document ID ($DOC_ID_1 == $DOC_ID_2)"
        echo "  ✅ No duplicate created!"
    else
        echo "  ❌ FAIL: Different document IDs ($DOC_ID_1 != $DOC_ID_2)"
        echo "  ❌ Duplicate was created!"
        exit 1
    fi
else
    echo "  ❌ Failed to upsert document"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ TEST PASSED: Upsert logic works correctly"
echo "✅ No duplicates created"
echo "=========================================="
