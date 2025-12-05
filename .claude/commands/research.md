---
description: Execute comprehensive research flow following RESEARCH-SOP.md
---

# Research Flow

Following RESEARCH-SOP.md to gather information...

**Query:** {{args}}

## Level 1: Memory Search

Checking Qdrant, AgentDB, and wider memory systems...

```bash
# This would trigger memory search
echo "🔍 Searching memory systems for: {{args}}"
```

## Level 2: Documentation Search

Checking Context7 for library documentation...

## Level 3: Web Research

Searching web with current date context...

**Current Date:** $(date +%Y-%m-%d)
**Current Year:** $(date +%Y)

## Instructions

To execute this research flow, I will:

1. **Search memory systems first** (Qdrant, AgentDB, Supabase, Swarm, Hive-Mind)
2. **Check Context7** if library/framework-related
3. **Use WebFetch/WebSearch** with current date/year for recent information
4. **Spawn research swarm** if deep analysis needed with multiple perspectives

---

**What information are you looking for?**

Provide your research query and I'll execute the appropriate levels of the Research SOP to gather comprehensive, current information.

**Examples:**
- `/research Next.js App Router best practices`
- `/research AI agent framework market 2025`
- `/research TypeScript strict mode patterns`
- `/research competitive landscape for X`

I'll automatically determine which research levels are needed and execute them in parallel when possible.
