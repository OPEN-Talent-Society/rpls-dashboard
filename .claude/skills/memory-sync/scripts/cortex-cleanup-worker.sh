#!/bin/bash
# Cortex cleanup worker - run multiple instances for parallel cleanup
# Usage: ./cortex-cleanup-worker.sh [WORKER_ID]

WORKER_ID="${1:-1}"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
export CORTEX_TOKEN CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET

BATCH=200
WORKERS=15
ROUNDS=100

echo "[W$WORKER_ID] Started $(date +%H:%M:%S)"
TOTAL=0

for r in $(seq 1 $ROUNDS); do
    IDS=$(curl -s --max-time 30 -X POST "https://cortex.aienablement.academy/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT id FROM blocks WHERE type='d' AND content LIKE '%chunk-%' LIMIT $BATCH\"}" 2>/dev/null)

    [ -z "$IDS" ] && { sleep 2; continue; }
    ID_LIST=$(echo "$IDS" | python3 -c "import sys,json; [print(x['id']) for x in json.load(sys.stdin).get('data',[])]" 2>/dev/null)
    [ -z "$ID_LIST" ] && { echo "[W$WORKER_ID] Done! Total: $TOTAL"; exit 0; }

    CNT=$(echo "$ID_LIST" | wc -l | tr -d ' ')
    echo "$ID_LIST" | xargs -P $WORKERS -I {} curl -s --max-time 10 -X POST \
        "https://cortex.aienablement.academy/api/block/deleteBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{"id": "{}"}' > /dev/null 2>&1

    TOTAL=$((TOTAL + CNT))
    echo "[W$WORKER_ID] R$r: +$CNT = $TOTAL"
done
echo "[W$WORKER_ID] Complete: $TOTAL"
