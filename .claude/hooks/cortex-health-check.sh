#!/bin/bash
# cortex-health-check.sh - Quick Cortex health assessment
# Usage: .claude/hooks/cortex-health-check.sh
# Updated: 2025-12-01

TOKEN="0fkvtzw0jrat2oht"
CF_ID="6c0fe301311410aea8ca6e236a176938.access"
CF_SECRET="714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3"
URL="https://cortex.aienablement.academy"

echo "🏥 Cortex Health Check"
echo "======================"
echo ""

# Total documents
DOCS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\""}' | jq -r '.data[0].cnt')

# Orphan documents
ORPHANS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND id NOT IN (SELECT DISTINCT def_block_id FROM refs WHERE def_block_id IS NOT NULL)"}' | jq -r '.data[0].cnt')

# Total references
REFS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM refs"}' | jq -r '.data[0].cnt')

# Documents with custom attributes
ATTRS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND ial LIKE \"%custom-%\""}' | jq -r '.data[0].cnt')

# Calculate rates
ORPHAN_RATE=$(echo "scale=1; $ORPHANS * 100 / $DOCS" | bc)
ATTR_RATE=$(echo "scale=1; $ATTRS * 100 / $DOCS" | bc)
REFS_PER_DOC=$(echo "scale=1; $REFS / $DOCS" | bc)

# Status indicators
if (( $(echo "$ORPHAN_RATE < 3" | bc -l) )); then
  ORPHAN_STATUS="✅"
elif (( $(echo "$ORPHAN_RATE < 10" | bc -l) )); then
  ORPHAN_STATUS="🟡"
else
  ORPHAN_STATUS="🔴"
fi

if (( $(echo "$ATTR_RATE > 90" | bc -l) )); then
  ATTR_STATUS="✅"
elif (( $(echo "$ATTR_RATE > 50" | bc -l) )); then
  ATTR_STATUS="🟡"
else
  ATTR_STATUS="🔴"
fi

if (( $(echo "$REFS_PER_DOC > 2" | bc -l) )); then
  REFS_STATUS="✅"
elif (( $(echo "$REFS_PER_DOC > 1" | bc -l) )); then
  REFS_STATUS="🟡"
else
  REFS_STATUS="🔴"
fi

echo "📊 Metrics"
echo "   Total Documents:    ${DOCS}"
echo "   Orphan Documents:   ${ORPHANS} (${ORPHAN_RATE}%) ${ORPHAN_STATUS}"
echo "   Total References:   ${REFS} (${REFS_PER_DOC}/doc) ${REFS_STATUS}"
echo "   Custom Attributes:  ${ATTRS} (${ATTR_RATE}%) ${ATTR_STATUS}"
echo ""

# Document distribution by notebook
echo "📁 Distribution by Notebook"
curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT box, COUNT(*) as cnt FROM blocks WHERE type=\"d\" GROUP BY box ORDER BY cnt DESC"}' | jq -r '.data[] | "   \(.box): \(.cnt)"'
echo ""

# Recent activity
echo "📅 Recent Activity (Last 7 Days)"
RECENT=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND updated > datetime(\"now\", \"-7 days\")"}' | jq -r '.data[0].cnt')
echo "   Modified: ${RECENT} documents"
echo ""

# Feature utilization
echo "🎯 Feature Utilization"
LEARNINGS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND ial LIKE \"%custom-type=\\\"learning\\\"%\""}' | jq -r '.data[0].cnt')

TASKS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND ial LIKE \"%custom-type=\\\"task\\\"%\""}' | jq -r '.data[0].cnt')

ADRS=$(curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ID}" \
  -H "CF-Access-Client-Secret: ${CF_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND ial LIKE \"%custom-type=\\\"adr\\\"%\""}' | jq -r '.data[0].cnt')

echo "   Learnings: ${LEARNINGS}"
echo "   Tasks: ${TASKS}"
echo "   ADRs: ${ADRS}"
echo ""

# Overall health score
HEALTH_SCORE=0
(( $(echo "$ORPHAN_RATE < 5" | bc -l) )) && HEALTH_SCORE=$((HEALTH_SCORE + 25))
(( $(echo "$ATTR_RATE > 80" | bc -l) )) && HEALTH_SCORE=$((HEALTH_SCORE + 25))
(( $(echo "$REFS_PER_DOC > 1.5" | bc -l) )) && HEALTH_SCORE=$((HEALTH_SCORE + 25))
(( RECENT > 10 )) && HEALTH_SCORE=$((HEALTH_SCORE + 25))

if (( HEALTH_SCORE >= 75 )); then
  HEALTH_EMOJI="🟢"
  HEALTH_TEXT="Excellent"
elif (( HEALTH_SCORE >= 50 )); then
  HEALTH_EMOJI="🟡"
  HEALTH_TEXT="Good"
else
  HEALTH_EMOJI="🔴"
  HEALTH_TEXT="Needs Attention"
fi

echo "🏆 Overall Health: ${HEALTH_EMOJI} ${HEALTH_TEXT} (${HEALTH_SCORE}/100)"
echo ""
echo "Run '.claude/hooks/cortex-fix-orphans.sh' to fix orphan documents"
