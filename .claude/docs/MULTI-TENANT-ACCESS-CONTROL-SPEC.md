# Multi-Tenant Access Control Specification

**Version:** 1.0
**Date:** 2025-12-13
**Status:** Draft for Review
**Purpose:** Define complete access control model for memory system

---

## 1. Organizational Structure

### 1.1 Tenants (Organizations)

| Tenant ID | Name | Type | Owners |
|-----------|------|------|--------|
| `academy` | AI Enablement Academy | Shared Venture | Adam, Klara |
| `red-rebel` | Red Rebel Learning | Independent | Klara |
| `talent-foundation` | The Talent Foundation | Independent | Adam |

### 1.2 Users

| User ID | Name | Primary Tenant | Roles |
|---------|------|----------------|-------|
| `adam` | Adam Kovacs | talent-foundation | founder@talent-foundation, founder@academy |
| `klara` | Klara Hermesz | red-rebel | founder@red-rebel, founder@academy |
| `system` | System | academy | system@all |

### 1.3 Relationship Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TENANT RELATIONSHIPS                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                        ┌─────────────────┐                              │
│                        │    ACADEMY      │                              │
│                        │   (Shared)      │                              │
│                        └────────┬────────┘                              │
│                                 │                                       │
│              ┌──────────────────┼──────────────────┐                    │
│              │                  │                  │                    │
│              ▼                  ▼                  ▼                    │
│   ┌─────────────────┐   Inheritance    ┌─────────────────┐             │
│   │  RED REBEL      │◄────────────────►│ TALENT          │             │
│   │  (Klara)        │   (via Academy)  │ FOUNDATION      │             │
│   └─────────────────┘                  │ (Adam)          │             │
│                                        └─────────────────┘             │
│                                                                         │
│   RULES:                                                                │
│   - Academy founders see ALL Academy data                               │
│   - Red Rebel data is ISOLATED (Klara only)                            │
│   - Talent Foundation data is ISOLATED (Adam only)                     │
│   - NO automatic cross-flow between Red Rebel ↔ Talent Foundation      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Role Model

### 2.1 Role Definitions

| Role | Scope | Permissions |
|------|-------|-------------|
| `founder` | Per-tenant | Full CRUD on all tenant data, manage members, see analytics |
| `admin` | Per-tenant | Full CRUD on tenant data, cannot manage billing/ownership |
| `member` | Per-tenant | Read all tenant data, write to assigned areas |
| `coach` | Academy only | Read course content, write to learner's private space |
| `learner` | Academy only | Read courses, write own activity, see own analytics |
| `client` | Per-tenant | Read assigned projects, write deliverables |
| `agent` | Per-tenant | Scoped operations defined by agent config |
| `public` | Global | Read public content only |

### 2.2 Role Inheritance

```yaml
founder:
  inherits: [admin]
  additional:
    - manage_members
    - view_billing
    - delete_tenant_data
    - export_all_data

admin:
  inherits: [member]
  additional:
    - write_all_areas
    - manage_content
    - view_audit_logs

member:
  inherits: [public]
  additional:
    - read_internal_content
    - write_assigned_areas
    - create_personal_content

coach:
  inherits: [member]
  scope: academy_only
  additional:
    - read_learner_activity (with consent)
    - write_learner_feedback
    - view_aggregate_analytics

learner:
  inherits: [public]
  scope: academy_only
  additional:
    - read_enrolled_courses
    - write_own_activity
    - view_own_progress
```

### 2.3 Agent Architecture

**Key Concept:** Agents are **personas** that belong to users or organizations. They act on behalf of their owners with scoped permissions.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AGENT OWNERSHIP MODEL                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ORGANIZATION-OWNED AGENTS (Shared across org)                          │
│  ─────────────────────────────────────────────                          │
│  • learning-coach      (Academy persona - helps learners)               │
│  • content-indexer     (System agent - indexes content)                 │
│  • analytics-agent     (System agent - runs aggregate analytics)        │
│                                                                         │
│  USER-OWNED AGENTS (Personal assistants)                                │
│  ────────────────────────────────────────                               │
│  • claude-code@adam    (Adam's dev agent)                               │
│  • claude-code@klara   (Klara's dev agent)                              │
│  • custom-agent@user   (Platform users can create their own)            │
│                                                                         │
│  INHERITANCE: User agents inherit user's role permissions               │
│               Org agents have explicitly scoped permissions             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Agent Roles Table

| Agent ID | Owner Type | Tenant | Role | Allowed Operations |
|----------|------------|--------|------|-------------------|
| `claude-code@{user}` | User | * | agent | Full access based on owner's permissions |
| `learning-coach` | Org (Academy) | academy | coach | Read courses, read consented activities, write feedback |
| `content-indexer` | System | * | agent | Write to collections, no read of private data |
| `analytics-agent` | Org (Academy) | academy | agent | Read aggregate data only, no PII |
| `external-webhook` | System | specified | agent | Write to specified collection only |
| `custom-agent@{user}` | User | user's tenant | agent | Scoped by user's role + agent config |

### 2.5 Future Roles (Roadmap)

| Role | Scope | Description | Phase |
|------|-------|-------------|-------|
| `employee` | Per-tenant | Staff member with elevated access | Phase 2 |
| `vendor` | Cross-tenant | External service provider with limited access | Phase 3 |
| `partner` | Cross-tenant | Strategic partner with shared content access | Phase 3 |
| `auditor` | Per-tenant | Read-only access for compliance review | Phase 4 |

**Employee vs Member:**
- `member` = External (clients, learners)
- `employee` = Internal staff with admin-lite permissions

---

## 3. Data Classification

### 3.1 Classification Levels

| Level | Description | Retention | Access |
|-------|-------------|-----------|--------|
| `confidential` | PII, credentials, private notes | 90 days unless extended | Owner only |
| `internal` | Business data, client info | 1 year | Tenant members |
| `shared` | Cross-org content | 2 years | Specified orgs |
| `public` | Published content | Indefinite | Everyone |

### 3.2 PII Handling

```yaml
pii_fields:
  - email
  - phone
  - address
  - financial_data
  - health_data
  - biometric_data

pii_rules:
  storage: encrypted_at_rest
  access_logging: required
  retention: 90_days_default
  cross_tenant: never
  aggregation: anonymized_only
  deletion_request: cascade_all_backends
```

---

## 4. Complete Payload Schema

### 4.1 Required Fields (All Collections)

```json
{
  // === OWNERSHIP (Immutable after creation) ===
  "owner_id": "adam",                    // Human who owns this data
  "created_by": "adam",                  // Human who caused creation
  "created_by_agent": "claude-code",     // Agent that created (if applicable)
  "created_at": "2025-01-15T10:00:00Z",

  // === TENANCY ===
  "tenant_id": "academy",                // Primary tenant
  "source_tenant": "talent-foundation",  // Where it originated (if different)

  // === ACCESS CONTROL ===
  "scope": "org",                        // private|org|cross-org|public
  "org_access": ["academy"],             // Which orgs can access
  "role_access": ["founder", "member"],  // Which roles can access
  "user_access": [],                     // Specific user overrides (optional)

  // === CLASSIFICATION ===
  "data_class": "internal",              // confidential|internal|shared|public
  "contains_pii": false,
  "pii_fields": [],                      // List if contains_pii=true

  // === CONSENT (for activity/analytics) ===
  "consent_required": false,
  "consent_granted_by": null,            // User ID if consent given
  "consent_granted_at": null,
  "consent_scope": null,                 // "analytics"|"coach"|"research"

  // === LIFECYCLE ===
  "retention_days": 365,                 // null = forever
  "archive_after_days": 90,              // Move to cold storage
  "expires_at": null,                    // Hard expiration

  // === AUDIT ===
  "version": 1,
  "last_modified_by": "adam",
  "last_modified_at": "2025-01-15T10:00:00Z",
  "access_count": 0
}
```

### 4.2 Minimal Valid Payload

```json
{
  "owner_id": "adam",
  "tenant_id": "academy",
  "scope": "org",
  "data_class": "internal",
  "created_at": "2025-01-15T10:00:00Z"
}
```

---

## 5. Routing Rules

### 5.1 Ingestion Source → Access Control Mapping

```yaml
routing_rules:
  # === CORTEX (SiYuan Knowledge Base) ===
  - source: cortex
    conditions:
      notebook: "01 Projects"
    result:
      tenant_id: academy
      scope: org
      org_access: [academy, red-rebel, talent-foundation]
      data_class: internal

  - source: cortex
    conditions:
      notebook: "03 Resources"
    result:
      tenant_id: academy
      scope: shared
      org_access: [academy, red-rebel, talent-foundation]
      data_class: shared

  - source: cortex
    conditions:
      path_contains: "red-rebel"
    result:
      tenant_id: red-rebel
      scope: org
      org_access: [red-rebel]
      data_class: internal

  - source: cortex
    conditions:
      path_contains: "talent-foundation"
    result:
      tenant_id: talent-foundation
      scope: org
      org_access: [talent-foundation]
      data_class: internal

  # === FILE SYSTEM ===
  - source: file
    conditions:
      path_matches: "*/red-rebel/*"
    result:
      tenant_id: red-rebel
      scope: org
      org_access: [red-rebel]

  - source: file
    conditions:
      path_matches: "*/talent-foundation/*"
    result:
      tenant_id: talent-foundation
      scope: org
      org_access: [talent-foundation]

  - source: file
    conditions:
      path_matches: "*/academy/*|*/ai-enablement/*"
    result:
      tenant_id: academy
      scope: org
      org_access: [academy, red-rebel, talent-foundation]

  # === POSTHOG (Learning Analytics) ===
  - source: posthog
    conditions:
      event_type: "*"
    result:
      tenant_id: academy
      scope: private
      owner_id: "$user_id"  # Dynamic from event
      data_class: confidential
      contains_pii: true
      consent_required: true
      consent_scope: analytics

  # === AGENT-GENERATED ===
  - source: agent
    conditions:
      agent_id: "learning-coach"
    result:
      tenant_id: academy
      scope: org
      owner_id: system
      created_by_agent: learning-coach

  - source: agent
    conditions:
      agent_id: "claude-code"
    result:
      # Inherit from user's context
      tenant_id: "$user_tenant"
      scope: "$user_default_scope"
      owner_id: "$user_id"

  # === EXTERNAL WEBHOOK ===
  - source: webhook
    conditions:
      api_key_tenant: "*"
    result:
      tenant_id: "$api_key_tenant"
      scope: org
      owner_id: system
      created_by_agent: external-webhook

  # === DEFAULT (Reject Unknown) ===
  - source: "*"
    conditions:
      default: true
    result:
      action: REJECT
      reason: "Unknown source - explicit routing rule required"
```

### 5.2 User Input Classification Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CONTENT CLASSIFICATION FLOW                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. AUTO-DETECT (from metadata)                                         │
│     ├─ File path → tenant/scope                                         │
│     ├─ Cortex notebook → tenant/scope                                   │
│     ├─ Agent identity → tenant/scope                                    │
│     └─ API key → tenant                                                 │
│                                                                         │
│  2. IF AMBIGUOUS → INTAKE QUESTIONS                                     │
│     ┌────────────────────────────────────────────────────────────────┐  │
│     │ "This content could belong to multiple organizations:"          │  │
│     │                                                                 │  │
│     │ [ ] AI Enablement Academy (shared with all co-founders)         │  │
│     │ [ ] Red Rebel Learning (Klara's private)                        │  │
│     │ [ ] The Talent Foundation (Adam's private)                      │  │
│     │                                                                 │  │
│     │ Visibility:                                                     │  │
│     │ ( ) Private - Only I can see                                    │  │
│     │ ( ) Organization - Team members can see                         │  │
│     │ ( ) Shared - All co-founders can see                           │  │
│     │ ( ) Public - Anyone can see                                     │  │
│     └────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  3. APPLY ROUTING RULES                                                 │
│     └─ Set all payload fields based on selection                       │
│                                                                         │
│  4. VALIDATE                                                            │
│     ├─ Required fields present?                                         │
│     ├─ User has permission to create with this scope?                   │
│     └─ PII fields marked if detected?                                   │
│                                                                         │
│  5. INGEST OR REJECT                                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Edge Case Decisions

### 6.1 Organizational Changes

| Scenario | Decision | Implementation |
|----------|----------|----------------|
| **Third co-founder joins Academy** | Add to `org_access: [academy]` for all Academy data | Update role: `founder@academy`. No data migration needed - filter includes them automatically. |
| **Klara leaves Academy** | Her Academy-OWNED data stays with Academy | Data where `owner_id=klara AND tenant_id=academy` remains. Her personal Red Rebel data unaffected. |
| **New tenant created** | Isolated by default | No automatic access from other tenants. Must explicitly add to `org_access`. |
| **Tenant deleted** | Cascade delete or archive | All data with `tenant_id=X` archived to cold storage, deleted after 90 days. |

### 6.2 Data Ownership

| Scenario | Owner | Tenant | Reasoning |
|----------|-------|--------|-----------|
| Adam creates Academy course content | `adam` | `academy` | Adam owns creation, Academy owns context |
| Learning Coach generates insight | `system` | `academy` | Agent-generated, org-owned |
| Klara imports Red Rebel client data | `klara` | `red-rebel` | Her data, her org |
| External webhook sends PostHog event | `$user_id` from event | `academy` | User owns their activity |
| Claude Code creates doc for Adam | `adam` | Adam's current context | Agent acts on behalf of user |

### 6.3 Cross-Tenant Scenarios

| Scenario | Decision | Implementation |
|----------|----------|----------------|
| **Same client works with Red Rebel AND Talent Foundation** | Separate records, no auto-merge | Client has `client_id` in both tenants. No cross-reference unless explicit. |
| **Content should be visible to both orgs** | Use `org_access` array | Set `org_access: ["red-rebel", "talent-foundation"]` - does NOT require Academy tenant. |
| **Academy content shared with specific external party** | Add to `user_access` | `user_access: ["external-consultant@email.com"]` with expiry. |
| **Migrate personal content to Academy** | Re-classify with audit | Update `tenant_id`, keep `owner_id`, log change in `version` history. |

### 6.4 Agent Behavior

| Scenario | Decision | Implementation |
|----------|----------|----------------|
| **Agent creates data on behalf of user** | User is owner, agent is creator | `owner_id: user`, `created_by_agent: agent-id` |
| **Agent reads cross-tenant** | Denied unless explicitly permitted | Agent role defines allowed tenants |
| **Agent aggregates user data** | Only with consent | Check `consent_granted_by` before including |
| **Agent stores reasoning patterns** | Org-scoped, not user-private | Patterns are `scope: org` to benefit all users |

---

## 7. Consent Model

### 7.1 Consent Collection

**Important:** Consent is collected during **user registration** as part of service provider terms. We (AI Enablement Academy / The Talent Foundation / Red Rebel Learning) are the service providers.

**Registration Consent Flow:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    USER REGISTRATION CONSENT                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. User registers on Academy platform (Clerk authentication)           │
│                                                                         │
│  2. Required acceptance during registration:                            │
│     ☑ Terms of Service                                                  │
│     ☑ Privacy Policy                                                    │
│     ☑ Activity tracking for learning personalization                   │
│                                                                         │
│  3. Optional consent toggles (can change later in settings):            │
│     [ ] Enable AI coaching recommendations                              │
│     [ ] Include my anonymized data in aggregate analytics               │
│     [ ] Allow personalized content suggestions                          │
│                                                                         │
│  4. Consent stored in Clerk user metadata + replicated to Qdrant        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Consent Types

| Consent Type | Default | What It Allows |
|--------------|---------|----------------|
| `activity_tracking` | **Required** | Store page views, time on content, clicks (service functionality) |
| `progress_analytics` | Required | Track completion %, quiz scores for learning path |
| `ai_coaching` | Optional | Learning coach agent can reference activity for personalized help |
| `aggregate_analytics` | Optional | Include in anonymized cross-user statistics |
| `personalization` | Optional | AI-driven content recommendations |

### 7.3 Consent Storage

Consent is stored in **two locations**:
1. **Clerk user metadata** - Source of truth, managed via settings UI
2. **Qdrant payload** - Replicated for query-time filtering

```json
{
  "user_id": "learner-123",
  "tenant_id": "academy",
  "registration_date": "2025-01-15T10:00:00Z",
  "consents": {
    "activity_tracking": {
      "granted": true,
      "granted_at": "2025-01-15T10:00:00Z",
      "required": true,
      "can_revoke": false  // Required for service
    },
    "ai_coaching": {
      "granted": true,
      "granted_at": "2025-01-16T08:30:00Z",
      "required": false,
      "can_revoke": true
    },
    "aggregate_analytics": {
      "granted": false
    }
  }
}
```

### 7.4 Query Filtering with Consent

```python
def get_learner_activity(coach_agent, learner_id):
    # Check consent in Clerk (source of truth)
    consent = get_clerk_consent(learner_id, "ai_coaching")
    if not consent.granted:
        return {"error": "Learner has not enabled AI coaching"}

    # Query with consent filter (Qdrant)
    return qdrant.search(
        collection="activities",
        filter={
            "must": [
                {"key": "owner_id", "match": {"value": learner_id}},
                {"key": "consent_ai_coaching", "match": {"value": true}}
            ]
        }
    )
```

---

## 8. Query Patterns

### 8.1 User Search (Adam)

```json
{
  "filter": {
    "should": [
      // His own private data
      {"must": [
        {"key": "owner_id", "match": {"value": "adam"}},
        {"key": "scope", "match": {"value": "private"}}
      ]},
      // His tenant's org data
      {"must": [
        {"key": "tenant_id", "match": {"value": "talent-foundation"}},
        {"key": "scope", "match": {"any": ["org", "shared"]}}
      ]},
      // Academy data (he's a founder)
      {"must": [
        {"key": "org_access", "match": {"any": ["academy", "talent-foundation"]}}
      ]},
      // Public data
      {"key": "scope", "match": {"value": "public"}}
    ]
  }
}
```

### 8.2 Agent Search (Learning Coach)

```json
{
  "filter": {
    "must": [
      // Only Academy tenant
      {"key": "tenant_id", "match": {"value": "academy"}},
      // Only allowed data classes
      {"key": "data_class", "match": {"any": ["shared", "public"]}},
      // No confidential/PII
      {"key": "contains_pii", "match": {"value": false}}
    ],
    "should": [
      // Course content
      {"key": "type", "match": {"value": "course_content"}},
      // Consented learner activity (if searching for specific learner)
      {"must": [
        {"key": "consent_scope", "match": {"any": ["coach"]}},
        {"key": "owner_id", "match": {"value": "$learner_id"}}
      ]}
    ]
  }
}
```

### 8.3 Cross-Org Search (Shared Content)

```json
{
  "filter": {
    "must": [
      {"key": "scope", "match": {"value": "shared"}},
      {"key": "org_access", "match": {"any": ["$user_orgs"]}}
    ]
  }
}
```

---

## 9. Audit Requirements

### 9.1 Events to Log

| Event | Required Fields |
|-------|-----------------|
| `data_created` | who, what, when, tenant, classification |
| `data_accessed` | who, what, when, query_type |
| `data_modified` | who, what, when, old_value_hash, new_value_hash |
| `data_deleted` | who, what, when, reason |
| `consent_granted` | user, consent_type, when |
| `consent_revoked` | user, consent_type, when, cascade_actions |
| `permission_changed` | who_changed, target_user, old_role, new_role |
| `cross_tenant_access` | who, from_tenant, to_tenant, what |

### 9.2 Audit Log Schema

```json
{
  "event_id": "uuid",
  "event_type": "data_accessed",
  "timestamp": "2025-01-15T10:00:00Z",
  "actor": {
    "type": "user|agent|system",
    "id": "adam",
    "tenant": "talent-foundation",
    "role": "founder"
  },
  "target": {
    "collection": "articles",
    "point_id": "uuid",
    "tenant_id": "academy"
  },
  "context": {
    "query_type": "semantic_search",
    "client_ip": "masked",
    "user_agent": "claude-code/1.0"
  }
}
```

---

## 10. Implementation Checklist

### Phase 1: Foundation
- [ ] Add all required fields to Qdrant collection schemas
- [ ] Implement routing rules engine
- [ ] Create intake question UI/CLI flow
- [ ] Add validation to all indexer scripts

### Phase 2: Role System
- [ ] Implement role definitions
- [ ] Add role-based filter generation
- [ ] Create role assignment API

### Phase 3: Consent
- [ ] Implement consent storage
- [ ] Add consent checks to activity queries
- [ ] Create consent management UI

### Phase 4: Audit
- [ ] Implement audit logging
- [ ] Create audit query API
- [ ] Set up retention policies

---

**Document Version:** 1.0
**Created:** 2025-12-13
**Author:** Claude Code
**Status:** Draft - Awaiting Review
