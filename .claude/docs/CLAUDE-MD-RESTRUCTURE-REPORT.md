# CLAUDE.md Restructure Report

**Date:** 2025-12-04
**Coordinator:** Queen Coordinator (Hive-Mind)
**Workers Deployed:** 5 specialized analyzers
**Outcome:** Complete restructure with MANDATORY/STANDARD/OPTIONAL clarity

---

## Executive Summary

Successfully restructured `/Users/adamkovacs/CLAUDE.md` to clearly separate:
- **MANDATORY RULES** (MUST follow - causes failures if violated)
- **STANDARD PROCEDURES** (SHOULD follow - significantly improves efficiency/quality)
- **AVAILABLE FEATURES** (CAN use - optional enhancements)

**Key Impact:**
- 100% clarity on what is required vs optional
- Security rules now unmissable (Section 1.1)
- Memory SOP lifecycle clearly mandatory (Section 1.2)
- Tool usage patterns explicitly defined (Section 1.3)
- Parallel execution golden rule prominent (Section 1.4)

---

## Worker Analysis Results

### Worker 1: Memory SOP Analyzer

**MANDATORY Operations Identified:**

1. **PRE-TASK (Automatic via hook):**
   - Search all 7 backends before significant tasks
   - Hook: `.claude/hooks/pre-task-memory-lookup.sh`

2. **DURING TASK (Automatic via PostToolUse hooks):**
   - Incremental sync every 30 calls OR 5 minutes
   - Immediate sync on `agentdb_pattern_store`

3. **POST-TASK (Automatic via Stop hook):**
   - Full sync to cold + semantic layer
   - Script: `sync-all.sh --cold-only`

4. **EMERGENCY (Manual - BEFORE context compaction):**
   - Script: `emergency-memory-flush.sh`

**Memory Architecture (7 Backends):**
- Hot: AgentDB, Swarm Memory, Hive-Mind
- Semantic: Qdrant (768-dim vectors)
- Cold: Supabase, Cortex, Agent Memory

**Finding:** Memory SOP is a COMPLETE LIFECYCLE that MUST happen automatically. This was buried in old docs - now Section 1.2.

---

### Worker 2: Security & Credentials Analyzer

**MANDATORY Security Rules:**

**NEVER:**
- Hardcode secrets in code: `API_KEY="sk-abc123..."`
- Use fallback values with real keys
- Commit secrets to git

**ALWAYS:**
- Store in `/Users/adamkovacs/Documents/codebuild/.env` (gitignored)
- Fail if not set: `[ -z "$KEY" ] && exit 1`
- Add `.env` to `.gitignore`
- Keep files under 500 lines (split if larger)

**Finding:** Security violations are CRITICAL - they cause immediate security breaches. Now Section 1.1 (top priority).

---

### Worker 3: Tool Usage Analyzer

**MANDATORY Tool Patterns:**

1. **Package Manager:**
   - MUST use `pnpm` ONLY
   - NEVER use npm/npx (use `pnpm dlx`)

2. **Agent Spawning:**
   - MUST use Task tool
   - NEVER use `mcp__claude-flow__agentic_flow_agent` (DENIED - requires API keys)
   - NEVER use `mcp__claude-flow__swarm_init` (DENIED)
   - NEVER use `mcp__claude-flow__agent_spawn` (DENIED)

3. **File Operations:**
   - MUST use Claude Code tools (Read/Write/Edit/Glob/Grep)
   - NEVER use bash commands (cat/grep/find)

**Finding:** Tool usage has HARD CONSTRAINTS. Using wrong tools = failures. Now Section 1.3.

---

### Worker 4: Performance & Efficiency Analyzer

**MANDATORY Efficiency Rules:**

1. **Parallel Execution (GOLDEN RULE):**
   - If you need X operations, they MUST be in 1 message, not X messages
   - Impact: 2-3x performance improvement

2. **NocoDB Constraints:**
   - Query limit: 25,000 tokens - MUST specify `fields` parameter
   - Update limit: 10 records max per call - MUST batch large updates

**SHOULD USE (Standard Procedures):**
- `agent_booster_edit_file` - 352x faster code editing
- `agent_booster_batch_edit` - Multi-file edits
- Batch NocoDB operations
- Limit query fields

**Finding:** Parallel execution is NON-NEGOTIABLE for efficiency. NocoDB limits are HARD CONSTRAINTS. Now Section 1.4 and 1.5.

---

### Worker 5: Outdated Reference Finder

**Files with Outdated MCP Tool References (37 files):**

**Categories:**
1. **Agent definitions** (25 files):
   - `.claude/agents/swarm/*.md` (3 files)
   - `.claude/agents/hive-mind/*.md` (5 files)
   - `.claude/agents/templates/*.md` (3 files)
   - `.claude/agents/github/*.md` (9 files)
   - `.claude/agents/goal/*.md` (2 files)
   - `.claude/agents/specialized/*.md` (1 file)

2. **Skills** (6 files):
   - `.claude/skills/github-*/SKILL.md` (5 files)
   - `.claude/skills/swarm-advanced/SKILL.md` (1 file)

3. **Documentation** (3 files):
   - `.claude/docs/ref/MCP-TOOLS.md`
   - `.claude/docs/ref/SWARM-PATTERNS.md`
   - `.claude/docs/TOOL-REFERENCE.md`

4. **Commands** (1 file):
   - `.claude/commands/agents/agent-spawning.md`

5. **Settings** (1 file):
   - `.claude/settings.json`

**Outdated References:**
- `mcp__claude-flow__swarm_init` - DENIED
- `mcp__claude-flow__agent_spawn` - DENIED
- `mcp__claude-flow__agentic_flow_agent` - DENIED (requires API keys)
- "72 agents" should be "143 Custom Agents (Task tool)"

**Finding:** 37 files need updates to remove references to denied tools. This is a FOLLOW-UP task.

---

## Restructure Summary

### Old Structure (CLAUDE.md v1.0)
```
- Quick Reference (mixed mandatory/optional)
- Agents (143 Custom + 72 Agentic-Flow)
- Skills (107)
- Commands (85)
- Hooks (37)
- Plugins (16)
- 1. Security Rules (mixed language)
- 2. Memory System (unclear if mandatory)
- 3. NocoDB (constraints buried)
- 4. Cortex
- 5. Development Stack
- 6. Parallel Execution (GOLDEN RULE but not prominent)
- 7. Claude Code vs MCP
- 8. Quick Agent Selection
- 9. MCP Tools Reference
- 10. Support
```

**Problems:**
- No clear distinction between MUST/SHOULD/CAN
- Security rules mixed with other content
- Memory SOP lifecycle not explicit
- Tool constraints buried in text
- Parallel execution rule not prominent enough
- Outdated "72 agents" reference

---

### New Structure (CLAUDE.md v2.0)

```
I. MANDATORY RULES (MUST FOLLOW)
   1.1 Security (CRITICAL)
   1.2 Memory System (MANDATORY SOP)
   1.3 Tool Usage (MANDATORY)
   1.4 Parallel Execution (GOLDEN RULE)
   1.5 NocoDB Constraints (MANDATORY)
   1.6 Responsibility Separation (MANDATORY)

II. STANDARD PROCEDURES (SHOULD FOLLOW)
   2.1 Agent Selection Guide
   2.2 Performance Optimization
   2.3 Memory Commands
   2.4 Cortex (Knowledge Management)

III. AVAILABLE FEATURES (CAN USE)
   3.1 Custom Agents (143)
   3.2 Skills (107)
   3.3 Commands (85)
   3.4 Hooks (37)
   3.5 Plugins (16)
   3.6 Available MCP Tools
   3.7 NocoDB (Business Tasks)
   3.8 Development Stack

IV. QUICK REFERENCE
   - Enforcement Levels table

V. SUPPORT
   - Resources and links
```

**Improvements:**
- Clear 3-tier hierarchy: MANDATORY > STANDARD > OPTIONAL
- Security rules FIRST (Section 1.1)
- Memory SOP lifecycle explicit and mandatory (Section 1.2)
- Tool usage patterns with DENIED examples (Section 1.3)
- Parallel execution golden rule prominent (Section 1.4)
- NocoDB constraints clearly MANDATORY (Section 1.5)
- Visual indicators (❌ for wrong, ✅ for correct)
- Enforcement levels table (MUST/SHOULD/CAN meanings)
- Removed outdated "72 agents" reference

---

## MANDATORY Rules Extracted (Section I)

### 1.1 Security (CRITICAL)
- **Impact:** Security breaches, exposed credentials
- **Enforcement:** NEVER/ALWAYS language
- **Location:** Section 1.1 (first item)

### 1.2 Memory System (MANDATORY SOP)
- **Impact:** Data loss, learning loss, context loss
- **Enforcement:** MUST HAPPEN AUTOMATICALLY
- **Location:** Section 1.2
- **Lifecycle:** 4 phases (PRE/DURING/POST/EMERGENCY)

### 1.3 Tool Usage (MANDATORY)
- **Impact:** Tool failures, denied operations
- **Enforcement:** CORRECT vs WRONG examples with ❌/✅
- **Location:** Section 1.3

### 1.4 Parallel Execution (GOLDEN RULE)
- **Impact:** 2-3x performance degradation if violated
- **Enforcement:** MANDATORY language
- **Location:** Section 1.4

### 1.5 NocoDB Constraints (MANDATORY)
- **Impact:** Query failures, token overflows
- **Enforcement:** MUST RESPECT
- **Location:** Section 1.5

### 1.6 Responsibility Separation (MANDATORY)
- **Impact:** Incorrect tool usage, failures
- **Enforcement:** Clear separation table
- **Location:** Section 1.6

---

## STANDARD Procedures (Section II)

**Rationale:** These significantly improve efficiency/quality but don't cause failures if skipped.

- Agent Selection Guide (helps pick right agent)
- Performance Optimization (352x faster edits, batching)
- Memory Commands (manual operations)
- Cortex documentation (knowledge management)

---

## AVAILABLE Features (Section III)

**Rationale:** Optional capabilities that enhance workflow.

- 143 Custom Agents (Task tool)
- 107 Skills
- 85 Commands
- 37 Hooks
- 16 Plugins
- Available MCP Tools (context7, agent_booster, agentdb)
- NocoDB reference info
- Development stack info

---

## Enforcement Levels (Section IV)

| Level | Language | Meaning |
|-------|----------|---------|
| **MANDATORY** | MUST, NEVER, ALWAYS, CRITICAL | Non-negotiable - causes failures if violated |
| **STANDARD** | SHOULD, RECOMMENDED | Best practices - significantly improves quality/efficiency |
| **OPTIONAL** | CAN, MAY, AVAILABLE | Nice-to-have features - use when beneficial |

---

## Follow-Up Tasks Required

### 1. Update 37 Files with Outdated References

**High Priority (Documentation):**
- [ ] `.claude/docs/ref/MCP-TOOLS.md` - Remove swarm examples
- [ ] `.claude/docs/ref/SWARM-PATTERNS.md` - Update to Task tool patterns
- [ ] `.claude/docs/TOOL-REFERENCE.md` - Remove denied tools

**Medium Priority (Skills):**
- [ ] `.claude/skills/github-code-review/SKILL.md`
- [ ] `.claude/skills/github-multi-repo/SKILL.md`
- [ ] `.claude/skills/github-project-management/SKILL.md`
- [ ] `.claude/skills/github-release-management/SKILL.md`
- [ ] `.claude/skills/github-workflow-automation/SKILL.md`
- [ ] `.claude/skills/swarm-advanced/SKILL.md`

**Low Priority (Agent Definitions):**
- [ ] All 25 agent files in:
  - `.claude/agents/swarm/`
  - `.claude/agents/hive-mind/`
  - `.claude/agents/templates/`
  - `.claude/agents/github/`
  - `.claude/agents/goal/`
  - `.claude/agents/specialized/`

**Settings:**
- [ ] `.claude/settings.json` - Remove denied MCP tool references

---

### 2. Create Supplementary Quick Reference

**Suggested:** Create `.claude/docs/QUICK-REFERENCE.md` with:
- 1-page cheat sheet of MANDATORY rules only
- Common violations and fixes
- Emergency procedures

---

### 3. Update Memory SOP Cross-References

**Check:**
- [ ] `.claude/docs/MEMORY-SOP.md` - Ensure alignment with Section 1.2
- [ ] Hook scripts reference correct documentation

---

## Metrics

**Documentation Size:**
- Old CLAUDE.md: 296 lines
- New CLAUDE.md: 369 lines (+24.7% for clarity)

**Structure Depth:**
- Old: 2 levels (sections + subsections)
- New: 3 levels (MANDATORY/STANDARD/OPTIONAL + sections + subsections)

**Clarity Improvement:**
- MANDATORY rules: Was implicit → Now explicit (Section I)
- Security rules: Was Section 1 → Now Section 1.1 (first)
- Memory SOP: Was "Memory System" → Now "MANDATORY SOP"
- Tool usage: Was scattered → Now Section 1.3 with ❌/✅ examples
- Parallel execution: Was Section 6 → Now Section 1.4 (GOLDEN RULE)

**Outdated References:**
- Found: 37 files
- Fixed in CLAUDE.md: 1 file (removed "72 agents" reference)
- Remaining: 36 files (follow-up task)

---

## Success Criteria Met

✅ **Clear MANDATORY rules** - Section I explicitly labeled
✅ **Security FIRST** - Section 1.1 is top priority
✅ **Memory SOP lifecycle explicit** - Section 1.2 with 4 phases
✅ **Tool usage patterns defined** - Section 1.3 with CORRECT/WRONG examples
✅ **Parallel execution prominent** - Section 1.4 GOLDEN RULE
✅ **Enforcement levels defined** - Section IV table
✅ **Outdated references identified** - 37 files catalogued
✅ **Visual clarity** - ❌/✅ indicators, bold headers, clear hierarchy

---

## Recommendations

### For Immediate Use
1. **Share Section I** with all agents - these are MANDATORY
2. **Reference enforcement table** when unclear on MUST vs SHOULD
3. **Use visual indicators** (❌/✅) in code reviews

### For Follow-Up
1. **Update 37 files** with outdated MCP tool references
2. **Create quick reference card** for MANDATORY rules only
3. **Add enforcement reminders** to hooks (check MANDATORY rules)

### For Long-Term
1. **Automated validation** - Hook to check MANDATORY rules compliance
2. **Metrics tracking** - Track violations of MANDATORY rules
3. **Regular review** - Update as SOPs evolve

---

## Conclusion

Successfully restructured CLAUDE.md with crystal-clear separation of:
- **MANDATORY** (MUST - causes failures)
- **STANDARD** (SHOULD - improves efficiency/quality)
- **OPTIONAL** (CAN - nice-to-have)

**Key Impact:**
- Security rules unmissable (Section 1.1)
- Memory SOP lifecycle explicit (Section 1.2)
- Tool usage patterns clear (Section 1.3)
- Parallel execution rule prominent (Section 1.4)
- 37 files identified for follow-up updates

**Version:** 2.0
**Last Updated:** 2025-12-04
**Coordinator:** Queen Coordinator (Hive-Mind)
**Status:** COMPLETE ✅
