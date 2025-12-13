#!/bin/bash
# Fast Cortex cleanup with parallel deletes
# Run with: nohup ./cortex-cleanup-fast.sh > /tmp/cortex-cleanup-fast.log 2>&1 &

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')

BATCH_SIZE=100
PARALLEL_WORKERS=10
MAX_ROUNDS=500

echo "Starting FAST Cortex cleanup at $(date)"
echo "Batch size: $BATCH_SIZE, Parallel workers: $PARALLEL_WORKERS"

TOTAL_DELETED=0

delete_doc() {
    local id="$1"
    curl -s --max-time 10 --connect-timeout 5 -X POST "https://cortex.aienablement.academy/api/block/deleteBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$id\"}" > /dev/null 2>&1
    echo "1"
}
export -f delete_doc
export CORTEX_TOKEN CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET

for round in $(seq 1 $MAX_ROUNDS); do
    # Get batch of chunk IDs
    IDS=$(curl -s --max-time 30 --connect-timeout 10 -X POST "https://cortex.aienablement.academy/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT id FROM blocks WHERE type='d' AND content LIKE '%chunk-%' LIMIT $BATCH_SIZE\"}" 2>/dev/null || echo "")

    if [ -z "$IDS" ]; then
        echo "API timeout, retrying..."
        sleep 5
        continue
    fi

    # Parse IDs into array
    ID_LIST=$(echo "$IDS" | python3 -c "import sys,json; [print(x['id']) for x in json.load(sys.stdin).get('data',[])]" 2>/dev/null || echo "")

    if [ -z "$ID_LIST" ]; then
        echo "No more chunks to delete! Total deleted: $TOTAL_DELETED"
        break
    fi

    # Delete in parallel using xargs
    BATCH_COUNT=$(echo "$ID_LIST" | xargs -P $PARALLEL_WORKERS -I {} bash -c 'delete_doc "$@"' _ {} | wc -l | tr -d ' ')

    TOTAL_DELETED=$((TOTAL_DELETED + BATCH_COUNT))
    echo "[$(date +%H:%M:%S)] Round $round: deleted $BATCH_COUNT (total: $TOTAL_DELETED)"

    # Brief pause to not overwhelm API
    sleep 1
done

echo "Cleanup complete at $(date). Total deleted: $TOTAL_DELETED"
