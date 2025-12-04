# Cortex Deduplication Plan

**Generated**: 2025-12-03
**Agent**: cortex-ops
**Status**: READY FOR REVIEW - DO NOT EXECUTE YET

## Problem Summary

Multiple documents have been synced repeatedly to Cortex, creating 7+ duplicates for many documents. This happened during the memory system standardization work on 2025-12-03.

**Root Cause**: AgentDB → Cortex sync ran multiple times without deduplication logic.

## Duplicate Groups Identified

### Group 1: "Create-unified-memory-sync-system-across-6-backend-20251203" (7 duplicates)

**KEEP** (newest): `20251203215319-u28hqg5`
- Created: 2025-12-03 21:53:19
- Source: agentdb
- Reward: 1.0

**DELETE** (6 older duplicates):
1. `20251203201028-xqx59mt` (2025-12-03 20:10:28)
2. `20251203200344-0poq7or` (2025-12-03 20:03:44)
3. `20251203200316-0a03d0j` (2025-12-03 20:03:16)
4. `20251203200147-74quqy5` (2025-12-03 20:01:47)
5. `20251203180017-7jg30jv` (2025-12-03 18:00:18)
6. `20251203175423-aht7m9s` (2025-12-03 17:54:23)

---

### Group 2: "Standardize-memory-system-with-6-backends-fix-Cort-20251203" (7 duplicates)

**KEEP** (newest): `20251203215317-zla8xo6`
- Created: 2025-12-03 21:53:17
- Source: agentdb
- Reward: 0.95

**DELETE** (6 older duplicates):
1. `20251203201027-j03ymms` (2025-12-03 20:10:28)
2. `20251203200343-s8z7y6h` (2025-12-03 20:03:44)
3. `20251203200315-r9d6u4m` (2025-12-03 20:03:16)
4. `20251203200146-cyqblah` (2025-12-03 20:01:47)
5. `20251203180017-avjt9yz` (2025-12-03 18:00:17)
6. `20251203175422-ss1qxvm` (2025-12-03 17:54:23)

---

### Group 3-9: Other 7-duplicate patterns (pending detailed analysis)

These documents also have 7 duplicates each from 2025-12-03:
- `Verify-claudeflow-installation-and-configuration-f-20251203` (7 duplicates)
- `Verify-claudeflow-implementation-per-GitHub-issue--20251203` (7 duplicates)
- `Update-claudeflow-MCP-to-use-claudeflowlatest-inst-20251203` (7 duplicates)
- `Troubleshoot-Calcom-selfhosted-deployment-issues-t-20251203` (7 duplicates)
- `Create-infrastructure-skills-Brevo-OCI-Cloudflare--20251203` (7 duplicates)
- `Configure-Brevo-SMTP-for-Calcom-email-sending-20251203` (7 duplicates)

### Group 10-11: 6-duplicate patterns

- `Fix-useSession-prerendering-error-in-Nextjs-15-20251203` (6 duplicates)
- `Find-Cloudflare-DNS-API-credentials-for-aienableme-20251203` (6 duplicates)

### Historical duplicates (2025-12-02)

Additional 5 duplicates each from previous day (lower priority):
- Multiple documents with `-20251202` suffix

---

## Deduplication Strategy

### Selection Criteria (Priority Order)

1. **Newest timestamp** - Keep most recent sync
2. **Has custom-source=agentdb** - Proper metadata
3. **Highest reward score** - Quality indicator
4. **Complete attributes** - All expected metadata present

### Execution Plan (3 Phases)

#### Phase 1: Verify Selection Logic (MANUAL)
- [ ] Review this plan with human operator
- [ ] Confirm selection criteria is correct
- [ ] Spot-check a few documents to verify content is identical

#### Phase 2: Test Delete (1 document)
- [ ] Delete ONE duplicate as test: `20251203175423-aht7m9s`
- [ ] Verify deletion successful
- [ ] Confirm kept document still accessible
- [ ] Check for broken references

#### Phase 3: Bulk Delete (if Phase 2 successful)
- [ ] Delete all identified duplicates in batches of 10
- [ ] Log each deletion
- [ ] Monitor for errors
- [ ] Create backup before bulk operation

---

## Estimated Impact

**Total duplicates to remove**: ~50-60 documents
**Disk space saved**: Minimal (text documents)
**Complexity reduction**: Significant (cleaner search results)
**Risk level**: Low (all duplicates have identical content)

---

## API Endpoint for Deletion

```javascript
// Single document deletion
mcp__cortex__siyuan_request({
  endpoint: "/api/filetree/removeDoc",
  payload: {
    notebook: "20251201183343-ujsixib",  // Resources notebook
    path: "/data/20251201183343-ujsixib/[document-id].sy"
  }
})
```

---

## Rollback Plan

If issues occur:
1. Stop immediately
2. Check AgentDB - original data still exists
3. Re-sync from AgentDB if needed
4. Documents are recoverable from backups

---

## Prevention for Future

**Recommendation**: Add deduplication logic to AgentDB → Cortex sync:
1. Check if document with same title already exists
2. If exists, update instead of create
3. Use document title + date as unique key
4. Log when duplicates are detected

**File to update**: `.claude/hooks/session-end-sync.sh` or similar sync script

---

## Next Steps

**AWAITING APPROVAL** - Do not execute deletions without human review.

1. Human reviews this plan
2. Approves selection criteria
3. Authorizes Phase 2 test deletion
4. Reviews test results
5. Approves Phase 3 bulk deletion (if test successful)
