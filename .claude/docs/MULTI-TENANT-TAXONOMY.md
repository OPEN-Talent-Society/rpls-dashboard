# Multi-Tenant Taxonomy

> Comprehensive taxonomy of users, organizations, agents, and access control for the knowledge base.

## Users

| User ID | Name | Email | Roles | Primary Org |
|---------|------|-------|-------|-------------|
| `adam` | Adam Kovacs | adam@talent.foundation | founder, owner, ceo, chair, president, treasurer | talent-foundation |
| `klara` | Klara Hermesz | klara@redrebellearning.com | founder, owner, ceo, board-secretary | red-rebel |

### User Relationships
- **Adam & Klara**: Cofounders, couple
- **Shared ownership**: AI Enablement Academy (co-founders)

---

## Organizations

| Org ID | Legal Name | Type | URL | Primary Owner |
|--------|------------|------|-----|---------------|
| `academy` | AI Enablement Academy | LLC | https://aienablement.academy | Adam & Klara (co-founders) |
| `red-rebel` | Red Rebel Learning | LLC | https://redrebellearning.com | Klara Hermesz |
| `talent-foundation` | The Talent Foundation | LLC | https://talent.foundation | Adam Kovacs |
| `open-talent` | OPEN Talent Society (Sourcing Seven DBA) | 501(c)(3) Non-Profit | https://opentalentsociety.org | Adam Kovacs (Chair/President) |

### Organization Relationships

```
AI Enablement Academy
├── Co-founded by: Adam Kovacs, Klara Hermesz
├── Sister company to: Red Rebel Learning, Talent Foundation
└── Mission: AI-powered learning enablement

Red Rebel Learning
├── Owner: Klara Hermesz
├── Focus: Learning & development consulting
└── Relationship: Academy partner

The Talent Foundation
├── Owner: Adam Kovacs
├── Focus: Talent acquisition & HR technology
└── Relationship: Academy partner

OPEN Talent Society (501c3)
├── Chair/President/Treasurer: Adam Kovacs
├── Board Secretary: Klara Hermesz
├── Focus: Charitable talent development
└── DBA: Sourcing Seven
```

---

## Agents

### Human-Controlled Agents

| Agent ID | Type | Owner | Access Level |
|----------|------|-------|--------------|
| `claude-code` | AI Assistant | adam | full |
| `claude-desktop` | AI Assistant | adam, klara | full |
| `claude-web` | AI Assistant | adam, klara | read |
| `chatgpt` | AI Assistant | adam, klara | read |
| `gemini-cli` | AI Assistant | adam | full |
| `codex` | AI Assistant | adam | full |
| `perplexity` | AI Research | adam, klara | read |
| `comet` | AI Assistant | adam | read |
| `atlas` | AI Assistant | adam | read |

### Automated Agents

| Agent ID | Type | Purpose | Owner |
|----------|------|---------|-------|
| `n8n-workflows` | Automation | Workflow orchestration | adam |
| `backup-agent` | System | Backup automation | adam |
| `monitoring-agent` | System | Infrastructure monitoring | adam |
| `sync-agent` | System | Memory synchronization | adam |
| `cortex-sync` | System | Cortex to Qdrant sync | adam |
| `codebase-indexer` | System | Code embedding indexer | adam |

---

## Access Control Matrix

### Scope Levels

| Scope | Description | Example |
|-------|-------------|---------|
| `private` | Only owner can access | Personal notes, drafts |
| `team` | Team members can access | Project docs, meeting notes |
| `org` | Organization-wide access | Company policies, procedures |
| `public` | Anyone can access | Published content, marketing |

### Role Hierarchy

```
founder
├── owner
│   ├── ceo
│   │   ├── executive
│   │   │   ├── manager
│   │   │   │   ├── member
│   │   │   │   └── contributor
│   │   │   └── advisor
│   │   └── board-member
│   └── chair
│       ├── president
│       ├── treasurer
│       └── board-secretary
└── co-founder
```

### Data Classification

| Class | Description | PII Allowed | Retention |
|-------|-------------|-------------|-----------|
| `public` | Marketing, published content | No | Permanent |
| `internal` | Business operations | Limited | 7 years |
| `confidential` | Sensitive business data | Yes | 3 years |
| `restricted` | Legal, financial, HR | Yes | Per regulation |

---

## Payload Schema (Qdrant)

Every vector point must include:

```json
{
  // Identity & Ownership
  "owner_id": "adam",                     // Primary owner user ID
  "created_by": "adam",                   // User who created
  "created_by_agent": "claude-code",      // Agent that created

  // Multi-Tenancy
  "tenant_id": "academy",                 // Primary org
  "org_access": ["academy", "red-rebel", "talent-foundation"],
  "role_access": ["founder", "member"],

  // Security
  "scope": "org",                         // private|team|org|public
  "data_class": "internal",               // public|internal|confidential|restricted
  "contains_pii": false,

  // Timestamps
  "created_at": "2025-12-13T21:00:00Z",
  "updated_at": "2025-12-13T21:00:00Z",

  // Content Metadata
  "type": "knowledge",                    // See taxonomy
  "source": "cortex",                     // Origin system
  "version": 1
}
```

---

## Content Type Taxonomy

| Type | Collection | Source Systems |
|------|------------|----------------|
| `knowledge` | cortex | SiYuan/Cortex |
| `code` | codebase | Git repositories |
| `pattern` | patterns | AgentDB ReasoningBank |
| `learning` | learnings | Session insights |
| `episode` | agent_memory | Task execution logs |
| `research` | research | Analysis, reports |
| `transcript` | transcripts | Speech-to-text |
| `video` | videos | YouTube, recordings |
| `article` | articles | Blog, docs, Substack |
| `social` | social_posts | LinkedIn, Twitter |
| `news` | news | Industry updates |
| `howto` | howtos | SOPs, procedures |
| `course` | courses | Academy content |
| `activity` | activities | Analytics events |
| `client` | clients | CRM data |
| `contact` | contacts | Contact profiles |
| `communication` | communications | Emails, chats |

---

## Query Patterns

### Filter by User Access
```json
{
  "must": [
    { "key": "owner_id", "match": { "value": "adam" } }
  ],
  "should": [
    { "key": "org_access", "match": { "any": ["academy", "talent-foundation"] } },
    { "key": "scope", "match": { "value": "public" } }
  ]
}
```

### Filter by Role
```json
{
  "must": [
    { "key": "role_access", "match": { "any": ["founder", "owner", "ceo"] } }
  ]
}
```

### Filter by Data Class (for PII compliance)
```json
{
  "must_not": [
    { "key": "contains_pii", "match": { "value": true } }
  ]
}
```

---

**Last Updated:** 2025-12-13
**Version:** 1.0
