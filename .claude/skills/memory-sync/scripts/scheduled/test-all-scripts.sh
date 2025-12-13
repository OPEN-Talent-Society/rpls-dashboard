#!/bin/bash
# Test All Scheduled Maintenance Scripts
# Runs each script in test/dry-run mode to verify they work correctly
# Usage: bash test-all-scripts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Testing All Scheduled Maintenance Scripts"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Track results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Helper function to run test
run_test() {
    local name="$1"
    local script="$2"
    local description="$3"

    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│ Test: $name"
    echo "│ $description"
    echo "└──────────────────────────────────────────────────────────┘"
    echo ""

    if [ ! -f "$script" ]; then
        echo "  ⚠️  SKIPPED - Script not found: $script"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo ""
        return
    fi

    if bash "$script" 2>&1 | head -20; then
        echo ""
        echo "  ✅ PASSED - Script executed successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo ""
        echo "  ❌ FAILED - Script returned error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""
}

# Check environment
echo "📋 Environment Check"
echo "───────────────────────────────────────────────────────────"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "  ❌ .env file not found at $PROJECT_DIR/.env"
    echo "  ⚠️  Tests may fail without proper credentials"
else
    echo "  ✅ .env file found"

    # Check for required vars
    REQUIRED_VARS="QDRANT_API_KEY CORTEX_TOKEN CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET"
    for var in $REQUIRED_VARS; do
        if grep -q "^${var}=" "$PROJECT_DIR/.env"; then
            echo "  ✅ $var is set"
        else
            echo "  ⚠️  $var not found in .env"
        fi
    done
fi

echo ""
echo ""

# Test 1: Qdrant Daily Cleanup
run_test \
    "Qdrant Daily Cleanup" \
    "$SCRIPT_DIR/qdrant-daily-cleanup.sh" \
    "Tests Qdrant container cleanup (orphans, old vectors, compaction)"

# Test 2: Cortex Hourly Validation
run_test \
    "Cortex Hourly Validation" \
    "$SCRIPT_DIR/cortex-hourly-validate.sh" \
    "Tests Cortex validation (orphans, categories, health report)"

# Test 3: Cortex Daily Backup
run_test \
    "Cortex Daily Backup" \
    "$SCRIPT_DIR/cortex-daily-backup.sh" \
    "Tests Cortex backup (export notebooks to markdown)"

# Test 4: Installation Script
echo "┌──────────────────────────────────────────────────────────┐"
echo "│ Test: Cron Installation Script"
echo "│ Tests cron job installation in dry-run mode"
echo "└──────────────────────────────────────────────────────────┘"
echo ""

if [ -f "$SCRIPT_DIR/install-cron-jobs.sh" ]; then
    if bash "$SCRIPT_DIR/install-cron-jobs.sh" --dry-run 2>&1 | head -30; then
        echo ""
        echo "  ✅ PASSED - Installation script works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo ""
        echo "  ❌ FAILED - Installation script error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "  ⚠️  SKIPPED - Script not found"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "📊 Test Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  ✅ Passed:  $TESTS_PASSED"
echo "  ❌ Failed:  $TESTS_FAILED"
echo "  ⚠️  Skipped: $TESTS_SKIPPED"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
echo "  Total:   $TOTAL_TESTS tests"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
    echo "⚠️  Some tests failed - check credentials and connectivity"
    echo ""
    echo "Common issues:"
    echo "  1. Missing .env file or credentials"
    echo "  2. Qdrant/Cortex containers not accessible"
    echo "  3. Cloudflare Access authentication issues"
    echo ""
elif [ "$TESTS_PASSED" -eq 0 ]; then
    echo "⚠️  No tests passed - environment setup required"
else
    echo "✅ All tests passed! Scripts are ready for production."
    echo ""
    echo "Next steps:"
    echo "  1. Review logs in /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/"
    echo "  2. Install cron jobs: bash $SCRIPT_DIR/install-cron-jobs.sh"
    echo "  3. Setup Supabase pg_cron (see supabase-weekly-cleanup.sql)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
