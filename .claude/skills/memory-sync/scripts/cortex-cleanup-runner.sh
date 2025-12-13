#!/bin/bash
# Long-running Cortex cleanup script
# Run with: nohup ./cortex-cleanup-runner.sh > /tmp/cortex-cleanup.log 2>&1 &

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')

BATCH_SIZE=20
PAUSE_BETWEEN_BATCHES=3
MAX_ROUNDS=2000

echo "Starting Cortex cleanup at $(date)"
echo "Batch size: $BATCH_SIZE, Pause: ${PAUSE_BETWEEN_BATCHES}s"

TOTAL_DELETED=0

for round in $(seq 1 $MAX_ROUNDS); do
    # Get batch of chunk IDs with timeout handling
    IDS=$(curl -s --max-time 15 --connect-timeout 5 -X POST "https://cortex.aienablement.academy/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT id FROM blocks WHERE type='d' AND content LIKE '%chunk-%' LIMIT $BATCH_SIZE\"}" 2>/dev/null || echo "")

    if [ -z "$IDS" ]; then
        echo "API timeout, retrying..."
        sleep 10
        continue
    fi

    # Parse IDs
    ID_LIST=$(echo "$IDS" | python3 -c "import sys,json; [print(x['id']) for x in json.load(sys.stdin).get('data',[])]" 2>/dev/null || echo "")

    if [ -z "$ID_LIST" ]; then
        echo "No more chunks to delete! Total deleted: $TOTAL_DELETED"
        break
    fi

    # Delete each ID with shorter timeout
    BATCH_COUNT=0
    while read -r id; do
        [ -z "$id" ] && continue
        curl -s --max-time 5 --connect-timeout 3 -X POST "https://cortex.aienablement.academy/api/block/deleteBlock" \
            -H "Authorization: Token ${CORTEX_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{\"id\": \"$id\"}" > /dev/null 2>&1 || true
        BATCH_COUNT=$((BATCH_COUNT + 1))
    done <<< "$ID_LIST"

    echo "Round $round: deleted $BATCH_COUNT"

    TOTAL_DELETED=$((TOTAL_DELETED + BATCH_COUNT))

    # Progress update every 100 deletes
    if [ $((TOTAL_DELETED % 100)) -lt $BATCH_SIZE ]; then
        REMAINING=$(curl -s --max-time 30 -X POST "https://cortex.aienablement.academy/api/query/sql" \
            -H "Authorization: Token ${CORTEX_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d '{"stmt": "SELECT COUNT(*) as cnt FROM blocks WHERE type=\"d\" AND content LIKE \"%chunk-%\""}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',[])[0].get('cnt',0))" 2>/dev/null)
        echo "[$(date +%H:%M:%S)] Deleted $TOTAL_DELETED total, $REMAINING remaining"
    fi

    sleep $PAUSE_BETWEEN_BATCHES
done

echo "Cleanup complete at $(date). Total deleted: $TOTAL_DELETED"
