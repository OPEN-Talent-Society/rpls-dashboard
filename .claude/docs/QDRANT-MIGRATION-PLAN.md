# Qdrant Data Migration Plan

**Created:** 2025-12-03
**Status:** Ready for Implementation
**Scope:** Normalizing 491 existing vectors to target schema
**Effort:** 4-6 hours (automated)

---

## Executive Summary

The Qdrant instance contains **491 vectors** distributed across 6 inconsistent schemas:
- 114 learnings (missing `source` consistency)
- 59 wiki entries (missing `source` field entirely)
- 17 episodes (rich metadata, good structure)
- 6 memory entries (good structure)
- 3 legacy learnings (inconsistent schema)
- 1 pattern

**Current Problem:** Metadata is fragmented, timestamps are missing, and no traceability linking back to source systems.

**Migration Goal:** Standardize all 491 points to the target schema with proper timestamps and source tracking.

---

## Current State Analysis

### Schema 1: Learnings (114 points)
```json
{
  "category": "string",
  "content": "string",
  "source": "string",
  "topic": "string",
  "type": "string"
}
```
**Status:** ✅ Good | **Missing:** `created_at`, `indexed_at`, `source_id`

### Schema 2: Wiki (59 points)
```json
{
  "category": "string",
  "content": "string",
  "topic": "string",
  "type": "string"
}
```
**Status:** ❌ Broken | **Issues:** Missing `source` entirely, no traceability

### Schema 3: Episodes (17 points)
```json
{
  "agentdb_id": "string",
  "created_at": "timestamp",
  "critique": "string",
  "input": "string",
  "latency_ms": "number",
  "output": "string",
  "reward": "number",
  "success": "boolean",
  "task": "string",
  "tokens_used": "number"
}
```
**Status:** ✅ Excellent | **Note:** Already has timestamps and rich metadata

### Schema 4: Memory (6 points)
```json
{
  "key": "string",
  "namespace": "string",
  "original_id": "string",
  "source": "string",
  "type": "string"
}
```
**Status:** ✅ Good | **Missing:** `created_at`, `indexed_at`

### Schema 5: Legacy Learnings (3 points)
```json
{
  "category": "string",
  "original_id": "string",
  "source": "string",
  "topic": "string",
  "type": "string"
}
```
**Status:** ⚠️ Variant | **Missing:** `content`, `created_at`, `indexed_at`

### Schema 6: Pattern (1 point)
```json
{
  "category": "string",
  "name": "string",
  "original_id": "string",
  "source": "string",
  "type": "string"
}
```
**Status:** ⚠️ Variant | **Missing:** `description`, `created_at`, `success_count`

---

## Target Schema (Unified)

All points should conform to this structure:

```json
{
  "type": "string",           // Required: "learning", "wiki", "episode", "memory", "pattern"
  "source": "string",         // Required: "supabase", "cortex", "agentdb", "local"
  "source_id": "string",      // Required: traceable ID (uuid or local ID)
  "topic": "string",          // Required: main subject/title
  "content": "string",        // Required: actual content/description
  "created_at": "timestamp",  // Required: original creation time
  "indexed_at": "timestamp",  // Required: when added to Qdrant

  // Hierarchical (for chunked content)
  "parent_id": "string",      // Optional: ID of parent point if chunked
  "chunk_index": "number",    // Optional: position in sequence
  "total_chunks": "number",   // Optional: total chunks for this document
  "is_parent": "boolean",     // Optional: whether this is a parent/summary

  // Categorization
  "category": "string",       // Optional: technical, workflow, tool, etc.
  "tags": ["string"],         // Optional: searchable tags
  "agent": "string",          // Optional: agent that created it

  // Relations
  "related_ids": ["string"],  // Optional: other point IDs
  "source_doc_id": "string",  // Optional: cortex doc ID if applicable

  // Code-specific
  "file_path": "string",      // Optional: for code snippets
  "language": "string",       // Optional: programming language
  "symbols": ["string"],      // Optional: function/class names

  // Quality
  "reward": "number",         // Optional: success metric (0-1)
  "success": "boolean",       // Optional: task success
  "confidence": "number"      // Optional: confidence metric (0-1)
}
```

---

## Issues to Fix

### Issue 1: Wiki Entries Missing `source` Field (59 points)
**Severity:** 🔴 Critical | **Impact:** No traceability

**Current State:**
```json
{
  "category": "wiki",
  "content": "...",
  "topic": "...",
  "type": "wiki"
}
```

**Solution:** Query Qdrant for all points with `type: "wiki"` and `!source`, add `source: "cortex"` (assuming they came from Cortex/SiYuan).

**Verification:** Confirm with project team that wiki entries are from Cortex before migration.

---

### Issue 2: Missing Timestamps (most entries)
**Severity:** 🔴 Critical | **Impact:** Cannot track indexing timeline, breaks TTL logic

**Current State:** ~450 points missing `created_at` and `indexed_at`

**Solution:**
- Set `indexed_at` to **NOW()** (migration time: 2025-12-03T22:33:00Z)
- Set `created_at` to **indexed_at** (use migration time as proxy)
- For episodes (which have `created_at`), use that value

**Caveat:** This loses original creation timestamps for non-episode entries. To preserve history:
1. Query Supabase for original `created_at` values for learnings/patterns
2. Cross-reference by `topic` or `original_id`
3. Use Supabase values if available, else use migration time

---

### Issue 3: Missing `source_id` (all entries)
**Severity:** 🟡 High | **Impact:** Cannot trace back to source system

**Current State:** No linkage back to original data

**Solution:**
- For learnings/patterns with `original_id`: use that as `source_id`
- For episodes with `agentdb_id`: use that as `source_id`
- For memory entries with `original_id`: use that as `source_id`
- For legacy learnings with `original_id`: use that as `source_id`
- For wiki entries: generate UUID or use content hash as `source_id`

---

### Issue 4: Inconsistent Schemas (6 variations)
**Severity:** 🟡 High | **Impact:** Inconsistent filtering/querying behavior

**Solution:**
- Unify all payloads to target schema
- Map legacy fields to standard fields:
  - `agentdb_id` → `source_id`
  - `name` → `topic`
  - `description` → `content`
  - `original_id` → `source_id` (or supplement)

---

### Issue 5: No Chunking Metadata (parent_id, chunk_index)
**Severity:** 🟢 Low | **Impact:** Cannot efficiently manage large documents

**Solution:**
- Not needed for current 491 points (all atomic)
- Add infrastructure for future chunk tracking
- Set `is_parent: true` for standalone points, `is_parent: false` for chunks

---

## Migration Strategy Comparison

### Option 1: In-Place Update (RECOMMENDED)
**Approach:** Use Qdrant's `set_payload` API to update missing fields

**Pros:**
- ✅ Vectors unchanged (no re-embedding needed)
- ✅ Fastest option (1-2 hours)
- ✅ Preserves all embeddings
- ✅ No downtime during migration
- ✅ Easy rollback (old payloads still in backup)

**Cons:**
- ⚠️ Cannot fix embedding quality issues
- ⚠️ Must query Supabase to get original `created_at` values

**Steps:**
1. Query Qdrant for all points (paginated)
2. For each point, fetch source data from Supabase (if available)
3. Construct normalized payload
4. Call `set_payload` API with updated fields
5. Verify schema compliance

**Time:** ~2 hours (automated batch updates)

---

### Option 2: Full Re-Index (NOT RECOMMENDED)
**Approach:** Delete all points, re-sync from Supabase with proper schema

**Pros:**
- ✅ Complete refresh ensures consistency
- ✅ Can fix any embedding quality issues
- ✅ Starts fresh with no legacy data

**Cons:**
- ❌ Requires re-embedding all 491 points (cost: $0, time: 30+ min)
- ❌ Supabase must be source of truth (verify schema first)
- ❌ Downtime during re-embedding
- ❌ Takes 2-3x longer than Option 1

**Steps:**
1. Backup current Qdrant data
2. Delete all collections
3. Re-create collections
4. Fetch all from Supabase
5. Generate embeddings (batched)
6. Upsert to Qdrant

**Time:** ~4-5 hours (including embedding generation)

---

### Option 3: Hybrid (BEST COMPROMISE)
**Approach:** In-place update for payloads, re-embed if quality issues detected

**Pros:**
- ✅ Fast for most entries (Option 1)
- ✅ Can fix problematic entries (Option 2)
- ✅ Minimal downtime
- ✅ Quality assurance built in

**Cons:**
- ⚠️ More complex execution
- ⚠️ Requires automated quality checks

**Steps:**
1. Run Option 1 (in-place updates)
2. Sample 10 points from each collection
3. Re-query and verify embeddings make sense
4. If quality issues found:
   - Flag affected points
   - Re-embed using Option 2 approach
   - Update vectors only (keep new payloads)

**Time:** ~2.5 hours (1x Option 1 + spot checks)

---

## Recommended Approach: OPTION 1 (In-Place Update)

**Rationale:**
1. Fastest path to consistency (2 hours)
2. Zero downtime
3. Preserves all embeddings (no re-generation cost/time)
4. Easy rollback if issues arise
5. Can be done incrementally (per collection)

**Implementation:**

### Phase 1: Preparation (30 min)

1. **Backup current state:**
   ```bash
   # Dump all collections
   for COLLECTION in learnings patterns agent_memory episodes memory; do
     curl -s "http://qdrant.harbor.fyi/collections/${COLLECTION}/points?limit=1000" \
       > /tmp/qdrant-backup-${COLLECTION}.json
   done
   ```

2. **Query source data:**
   ```bash
   # From Supabase: learnings with created_at
   SELECT id, topic, created_at FROM learnings LIMIT 500

   # From Supabase: patterns with created_at
   SELECT id, name, created_at FROM patterns LIMIT 500

   # From AgentDB: episodes
   SELECT agentdb_id, created_at FROM episodes LIMIT 500
   ```

3. **Prepare mapping file:**
   - Map `original_id` or `agentdb_id` to `source_id`
   - Map to source system (supabase, agentdb, cortex)
   - Collect original timestamps

### Phase 2: Update Payloads (90 min)

**Script: `migrate-qdrant-payloads.sh`**

```bash
#!/bin/bash

# Configuration
QDRANT_URL="http://qdrant.harbor.fyi"
COLLECTIONS=("learnings" "patterns" "agent_memory" "episodes" "memory")
BATCH_SIZE=50
MIGRATION_TIME="2025-12-03T22:33:00Z"

# Create normalized payload function
normalize_payload() {
  local point_id=$1
  local payload=$2
  local collection=$3

  # Extract existing fields
  local type=$(echo $payload | jq -r '.type // "unknown"')
  local source=$(echo $payload | jq -r '.source // "unknown"')
  local topic=$(echo $payload | jq -r '.topic // .name // ""')
  local content=$(echo $payload | jq -r '.content // .description // ""')

  # Determine source_id
  local source_id=$(echo $payload | jq -r '.original_id // .agentdb_id // ""')
  if [ -z "$source_id" ]; then
    source_id="qdrant-${point_id}"
  fi

  # Get timestamps
  local created_at=$(echo $payload | jq -r '.created_at // null')
  if [ "$created_at" == "null" ]; then
    created_at="$MIGRATION_TIME"
  fi

  # Build normalized payload
  cat <<EOF
{
  "type": "${type}",
  "source": "${source}",
  "source_id": "${source_id}",
  "topic": "${topic}",
  "content": "${content}",
  "created_at": "${created_at}",
  "indexed_at": "${MIGRATION_TIME}",
  "is_parent": true,
  "confidence": 0.8
}
EOF
}

# Process each collection
for COLLECTION in "${COLLECTIONS[@]}"; do
  echo "Migrating $COLLECTION..."

  # Fetch all points (paginated)
  local offset=0
  local total=0

  while true; do
    # Get batch of points
    local response=$(curl -s "${QDRANT_URL}/collections/${COLLECTION}/points?limit=${BATCH_SIZE}&offset=${offset}")
    local points=$(echo $response | jq -r '.result.points[]? | @json')

    if [ -z "$points" ]; then
      break
    fi

    # Process each point
    while IFS= read -r point_json; do
      local point_id=$(echo $point_json | jq -r '.id')
      local payload=$(echo $point_json | jq -r '.payload')

      # Normalize payload
      local normalized=$(normalize_payload "$point_id" "$payload" "$COLLECTION")

      # Update point
      curl -X PATCH "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "Content-Type: application/json" \
        -d "{\"points\": [{\"id\": ${point_id}, \"payload\": ${normalized}}]}"

      ((total++))
      if (( total % 10 == 0 )); then
        echo "  Processed $total points..."
      fi
    done <<< "$points"

    ((offset += BATCH_SIZE))
  done

  echo "✅ $COLLECTION migration complete ($total points)"
done

echo "✅ All collections migrated!"
```

### Phase 3: Verification (30 min)

**Verification script:**

```bash
#!/bin/bash

QDRANT_URL="http://qdrant.harbor.fyi"
COLLECTIONS=("learnings" "patterns" "agent_memory" "episodes" "memory")

echo "Qdrant Data Quality Report"
echo "=========================="
echo ""

for COLLECTION in "${COLLECTIONS[@]}"; do
  echo "📊 $COLLECTION"

  # Sample 5 points
  local sample=$(curl -s "${QDRANT_URL}/collections/${COLLECTION}/points?limit=5" | jq '.result.points[]')

  # Check required fields
  local has_type=$(echo "$sample" | jq 'select(.payload.type != null)' | wc -l)
  local has_source=$(echo "$sample" | jq 'select(.payload.source != null)' | wc -l)
  local has_source_id=$(echo "$sample" | jq 'select(.payload.source_id != null)' | wc -l)
  local has_created_at=$(echo "$sample" | jq 'select(.payload.created_at != null)' | wc -l)
  local has_indexed_at=$(echo "$sample" | jq 'select(.payload.indexed_at != null)' | wc -l)

  # Calculate compliance percentage
  local compliance=$(( (has_type + has_source + has_source_id + has_created_at + has_indexed_at) / 25 * 100 ))

  echo "  Type: $has_type/5 ✓"
  echo "  Source: $has_source/5 ✓"
  echo "  Source ID: $has_source_id/5 ✓"
  echo "  Created At: $has_created_at/5 ✓"
  echo "  Indexed At: $has_indexed_at/5 ✓"
  echo "  Compliance: ${compliance}%"
  echo ""
done

echo "✅ Verification complete"
```

### Phase 4: Rollback (if needed)

```bash
#!/bin/bash

# If migration fails, restore from backup
for COLLECTION in learnings patterns agent_memory episodes memory; do
  echo "Rolling back $COLLECTION..."

  # Delete current collection
  curl -X DELETE "http://qdrant.harbor.fyi/collections/${COLLECTION}"

  # Restore from backup
  curl -X PUT "http://qdrant.harbor.fyi/collections/${COLLECTION}" \
    -H "Content-Type: application/json" \
    -d "$(cat /tmp/qdrant-backup-${COLLECTION}.json)"

  echo "✅ $COLLECTION restored"
done
```

---

## Migration Script Requirements

### Required Tools
- `curl` (API calls)
- `jq` (JSON parsing)
- `bash` 4.0+
- Network access to Qdrant and Supabase

### Environment Variables
```bash
QDRANT_URL="http://qdrant.harbor.fyi"
SUPABASE_URL="https://..."
SUPABASE_API_KEY="..."
```

### Error Handling
- Retry failed updates (3 times)
- Log errors to `/tmp/qdrant-migration.log`
- Continue processing even if single point fails
- Report summary at end (X succeeded, Y failed)

### Performance Targets
- **Batch size:** 50 points per API call
- **Throughput:** ~200 points/min (with network latency)
- **Total time:** ~3 min for 491 points
- **Parallelization:** Process 5 collections sequentially or in parallel

---

## Risk Assessment

### Risk 1: Data Loss During Migration
**Probability:** Low | **Impact:** High

**Mitigation:**
- ✅ Backup all data before migration
- ✅ Test on sample (10 points) first
- ✅ Implement rollback script
- ✅ Verify each batch before moving to next

### Risk 2: Incorrect Timestamp Values
**Probability:** Medium | **Impact:** Medium

**Mitigation:**
- ✅ Query Supabase for authoritative timestamps
- ✅ Use content hash to match records
- ✅ Fall back to migration time if no match found
- ✅ Manual review of suspicious timestamps

### Risk 3: Source Traceability Lost for Wiki Entries
**Probability:** High | **Impact:** Low (recoverable)

**Mitigation:**
- ✅ Assume cortex source, document assumption
- ✅ Can re-derive from Cortex API if needed
- ✅ Low risk since wiki entries are not critical

### Risk 4: API Rate Limits
**Probability:** Low | **Impact:** Low

**Mitigation:**
- ✅ Batch requests (50 points per call)
- ✅ Implement exponential backoff
- ✅ Add 100ms delay between batches if needed

---

## Implementation Checklist

### Pre-Migration
- [ ] Backup all Qdrant collections
- [ ] Query Supabase for mapping data
- [ ] Test migration script on 10 sample points
- [ ] Communicate to team about maintenance window
- [ ] Document current state in `/tmp/qdrant-pre-migration.log`

### Migration Phase
- [ ] Run migration script (collect output logs)
- [ ] Monitor for errors in real-time
- [ ] Stop and rollback if >5% failure rate
- [ ] Verify each collection post-migration

### Post-Migration
- [ ] Run verification script
- [ ] Sample 20 random points for manual review
- [ ] Check that all queries still work
- [ ] Update MEMORY-SOP.md with new schema
- [ ] Archive old backup to cold storage
- [ ] Document lessons learned

### Documentation
- [ ] Update QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md with actual state
- [ ] Create QDRANT-MIGRATION-COMPLETED.md with results
- [ ] Update data model diagrams
- [ ] Document any schema variations that remain

---

## Post-Migration (Next Steps)

### Week 1 After Migration
1. Monitor Qdrant performance (query latency, collection sizes)
2. Test pre-task lookup semantic search with actual queries
3. Verify no regressions in existing workflows

### Week 2 After Migration
1. Implement embedding caching (to avoid re-generation)
2. Add incremental indexing for new records
3. Enhance pre-task lookup to use semantic search

### Week 3 After Migration
1. Index codebase to `codebase` collection
2. Add hybrid search (semantic + keyword)
3. Create user commands for manual semantic search

### Week 4+ After Migration
1. Implement Cortex integration (sync Cortex blocks to Qdrant)
2. Add filtered search (by category, date, agent)
3. Setup automated quality monitoring

---

## Success Criteria

### Must Have (Migration Success)
- ✅ 100% of points have `type`, `source`, `source_id`
- ✅ 100% of points have `created_at` and `indexed_at`
- ✅ All 491 points remain in Qdrant
- ✅ Zero data loss or corruption
- ✅ All collections queryable

### Should Have (Data Quality)
- ✅ >95% of points have valid timestamps
- ✅ >90% of source_ids traceable back to source system
- ✅ >85% of points have meaningful topic/content
- ✅ Schema compliance: 100%

### Nice to Have (Enhancements)
- ✅ Embedded caching implementation started
- ✅ Incremental indexing infrastructure ready
- ✅ Pre-task lookup updated to use semantic search

---

## Estimated Effort

| Phase | Time | Notes |
|-------|------|-------|
| Preparation | 30 min | Backup, data extraction, mapping |
| Migration | 90 min | Batch updates to 491 points |
| Verification | 30 min | Quality checks and manual review |
| **Total** | **2.5 hours** | Fully automated process |

**Execution Window:** Off-peak hours (2-3 AM, no impact on development)

---

## File Locations

### Backup Storage
```
/tmp/qdrant-backup-learnings.json
/tmp/qdrant-backup-patterns.json
/tmp/qdrant-backup-agent_memory.json
/tmp/qdrant-backup-episodes.json
/tmp/qdrant-backup-memory.json
```

### Migration Scripts
```
/tmp/migrate-qdrant-payloads.sh
/tmp/verify-qdrant-migration.sh
/tmp/rollback-qdrant-migration.sh
```

### Logs
```
/tmp/qdrant-migration.log
/tmp/qdrant-pre-migration.log
/tmp/qdrant-post-migration-report.txt
```

---

## Conclusion

**Recommended Action:** Implement **Option 1 (In-Place Update)** during off-peak hours.

**Rationale:**
1. Fastest path to schema consistency (2.5 hours)
2. Zero downtime during migration
3. All embeddings preserved (no re-generation)
4. Easy rollback mechanism
5. Minimal risk with proper backups

**Next Step:**
1. Review this plan with stakeholders
2. Get approval for execution window
3. Execute migration using provided scripts
4. Document results and lessons learned

---

**Document Version:** 1.0
**Last Updated:** 2025-12-03
**Status:** Ready for Implementation
**Author:** Claude Code

---

**Related Documents:**
- [QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md)
- [QDRANT-INDEX.md](./QDRANT-INDEX.md)
- [QDRANT-QUICK-REFERENCE.md](./QDRANT-QUICK-REFERENCE.md)
