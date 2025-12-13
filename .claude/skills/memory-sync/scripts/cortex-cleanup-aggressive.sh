#!/bin/bash
# Ultra-aggressive Cortex cleanup with high parallelism
# Expected throughput: ~1500-2000 docs/minute

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')

export CORTEX_TOKEN CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET

BATCH_SIZE=500
PARALLEL_WORKERS=25
MAX_ROUNDS=200

echo "Starting AGGRESSIVE cleanup at $(date)"
echo "Batch: $BATCH_SIZE, Workers: $PARALLEL_WORKERS"

TOTAL=0

for round in $(seq 1 $MAX_ROUNDS); do
    IDS=$(curl -s --max-time 60 -X POST "https://cortex.aienablement.academy/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT id FROM blocks WHERE type='d' AND content LIKE '%chunk-%' LIMIT $BATCH_SIZE\"}" 2>/dev/null)

    [ -z "$IDS" ] && { echo "Timeout, retry..."; sleep 3; continue; }

    ID_LIST=$(echo "$IDS" | python3 -c "import sys,json; [print(x['id']) for x in json.load(sys.stdin).get('data',[])]" 2>/dev/null)

    [ -z "$ID_LIST" ] && { echo "Done! Total: $TOTAL"; break; }

    CNT=$(echo "$ID_LIST" | wc -l | tr -d ' ')

    echo "$ID_LIST" | xargs -P $PARALLEL_WORKERS -I {} curl -s --max-time 15 -X POST \
        "https://cortex.aienablement.academy/api/block/deleteBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{"id": "{}"}' > /dev/null 2>&1

    TOTAL=$((TOTAL + CNT))
    echo "[$(date +%H:%M:%S)] R$round: +$CNT = $TOTAL"
done

echo "Complete at $(date). Total: $TOTAL"
