# 6. Epics and Implementation Phases

## Overview

This section defines the complete development plan for AI Enablement Academy v2, organized for **parallel worktree-based development** with thin-sliced tasks that can be distributed across engineers or AI agents.

---

## Task Labeling System

### Area Labels

All tasks are labeled by area to enable proper assignment and parallel development:

| Label | Area | Description | Skills Required |
|-------|------|-------------|-----------------|
| `FRONTEND` | Frontend | React, Next.js, UI components, styling | React, TypeScript, Tailwind, shadcn/ui |
| `BACKEND` | Backend | Convex functions, business logic, APIs | Convex, TypeScript, Node.js |
| `DB` | Database | Schema design, indexes, migrations | Convex schema, data modeling |
| `DEVOPS` | DevOps | CI/CD, deployment, infrastructure | GitHub Actions, Vercel, Docker |
| `TESTING` | Testing | Unit, integration, E2E tests | Jest, Playwright, Vitest |
| `DOCS` | Documentation | README, API docs, guides | Markdown, technical writing |
| `API` | External APIs | Third-party SDK integrations | Stripe, Brevo, Cal.com, etc. |
| `AI/ML` | AI/ML | LLM integration, embeddings | OpenRouter, embeddings, RAG |
| `INTEGRATION` | Integration | Cross-system webhooks, sync | Webhooks, event handling |

### Task ID Format

```
E{Phase}.{Epic}-{TaskNumber}

Examples:
- E0.1-001 = Phase 0, Epic 1, Task 1
- E2.3-015 = Phase 2, Epic 3, Task 15
```

### Parallelization Markers

| Marker | Meaning |
|--------|---------|
| `✅` | Can run in parallel with other ✅ tasks |
| `-` | Sequential - must wait for dependencies |
| `🔀` | Can start after partial dependency completion |

---

## Worktree Strategy

### Branch Naming Convention

```
{phase}/{epic}/{area}-{feature}

Examples:
- phase0/E0.1/devops-ci-setup
- phase1/E1.2/backend-stripe-webhooks
- phase2/E2.3/ai-chatbot-context
```

### Worktree Structure

```
main (protected)
├── develop (integration branch)
│
├── worktree/phase0-foundation
│   ├── phase0/E0.0/devops-quality
│   ├── phase0/E0.1/frontend-setup
│   ├── phase0/E0.2/backend-auth
│   └── phase0/E0.3/db-schema
│
├── worktree/phase1-mvp
│   ├── phase1/E1.1/frontend-marketing
│   ├── phase1/E1.2/backend-stripe
│   ├── phase1/E1.3/backend-email
│   └── phase1/E1.4/frontend-portal
│
├── worktree/phase2-post-cohort
│   ├── phase2/E2.1/frontend-recordings
│   ├── phase2/E2.2/integration-calcom
│   ├── phase2/E2.3/ai-chatbot
│   └── phase2/E2.4/backend-certificates
│
├── worktree/phase3-b2b
│   ├── phase3/E3.1/backend-organizations
│   ├── phase3/E3.2/frontend-admin
│   └── phase3/E3.3/backend-waitlist
│
└── worktree/phase4-platform
    ├── phase4/E4.1/api-rest
    └── phase4/E4.2/api-mcp
```

### Git Worktree Commands

```bash
# Create worktree for a phase
git worktree add ../worktree/phase0-foundation -b phase0/foundation

# Create feature branch within worktree
cd ../worktree/phase0-foundation
git checkout -b phase0/E0.1/frontend-setup

# List all worktrees
git worktree list

# Remove completed worktree
git worktree remove ../worktree/phase0-foundation
```

---

## Phase Documents

| Phase | File | Duration | Epics | Tasks |
|-------|------|----------|-------|-------|
| Phase 0 | [07a-epics-phase0-foundation.md](./07a-epics-phase0-foundation.md) | Week 1-2 | 4 | 43 |
| Phase 1 | [07b-epics-phase1-core-mvp.md](./07b-epics-phase1-core-mvp.md) | Week 3-6 | 5 | ~65 |
| Phase 2 | [07c-epics-phase2-post-cohort.md](./07c-epics-phase2-post-cohort.md) | Week 7-8 | 5 | ~55 |
| Phase 3 | [07d-epics-phase3-b2b-admin.md](./07d-epics-phase3-b2b-admin.md) | Week 9-11 | 3 | ~45 |
| Phase 4 | [07e-epics-phase4-platform-api.md](./07e-epics-phase4-platform-api.md) | Week 12+ | 2 | ~30 |
| Phase 5 | [07f-epics-phase5-icp-features.md](./07f-epics-phase5-icp-features.md) | Week 14+ | 6 | ~80 |
| **Total** | | **14+ weeks** | **25 epics** | **~318 tasks** |

---

## Phase Summaries

### Phase 0: Foundation
**File:** [07a-epics-phase0-foundation.md](./07a-epics-phase0-foundation.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E0.0 | Quality Infrastructure Setup | 1 | `DEVOPS` `TESTING` |
| E0.1 | Project Setup | 2 | `FRONTEND` `BACKEND` `DEVOPS` |
| E0.2 | Authentication | 3 | `BACKEND` `FRONTEND` `DB` |
| E0.3 | Database Schema | 3 | `DB` `BACKEND` `DOCS` |

**Deliverables:** Dev environment, auth system, 18-table schema

---

### Phase 1: Core MVP
**File:** [07b-epics-phase1-core-mvp.md](./07b-epics-phase1-core-mvp.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E1.0 | Performance & Mobile Optimization | ongoing | `FRONTEND` `DEVOPS` |
| E1.1 | Marketing Site | 5 | `FRONTEND` `BACKEND` |
| E1.2 | Stripe Integration | 4 | `BACKEND` `API` `INTEGRATION` |
| E1.3 | Email Automation | 3 | `BACKEND` `API` |
| E1.4 | Learner Portal | 5 | `FRONTEND` `BACKEND` |

**Deliverables:** Public site, payments, learner access

---

### Phase 2: Post-Cohort
**File:** [07c-epics-phase2-post-cohort.md](./07c-epics-phase2-post-cohort.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E2.1 | Recordings & Materials | 4 | `FRONTEND` `BACKEND` |
| E2.2 | Office Hours | 3 | `INTEGRATION` `FRONTEND` |
| E2.3 | Knowledge Chatbot | 5 | `AI/ML` `BACKEND` `FRONTEND` |
| E2.4 | Certificates | 4 | `BACKEND` `FRONTEND` |
| E2.5 | Content Management System | 6 | `FRONTEND` `BACKEND` `DB` |

**Deliverables:** Content delivery, AI support, credentials, CMS

---

### Phase 3: B2B & Admin
**File:** [07d-epics-phase3-b2b-admin.md](./07d-epics-phase3-b2b-admin.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E3.1 | Organizations | 5 | `BACKEND` `DB` `FRONTEND` |
| E3.2 | Admin Dashboard | 6 | `FRONTEND` `BACKEND` |
| E3.3 | Waitlist | 3 | `BACKEND` `FRONTEND` |

**Deliverables:** Enterprise features, management tools

---

### Phase 4: Platform API
**File:** [07e-epics-phase4-platform-api.md](./07e-epics-phase4-platform-api.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E4.1 | REST API | 5 | `API` `BACKEND` `DOCS` |
| E4.2 | MCP Server | 4 | `API` `BACKEND` `AI/ML` |

**Deliverables:** Developer platform, AI agent integration

---

### Phase 5: v2.1 ICP Features
**File:** [07f-epics-phase5-icp-features.md](./07f-epics-phase5-icp-features.md)

| Epic | Name | Days | Area Focus |
|------|------|------|------------|
| E5.1 | Skills & Competencies System | 8 | `DB` `BACKEND` `FRONTEND` |
| E5.2 | Resource Library System | 6 | `BACKEND` `FRONTEND` |
| E5.3 | Learning Paths System | 7 | `DB` `BACKEND` `FRONTEND` |
| E5.4 | Community System | 6 | `BACKEND` `FRONTEND` |
| E5.5 | Assessment System (Pre/Post ROI) | 7 | `BACKEND` `FRONTEND` `AI/ML` |
| E5.6 | Manager Dashboard System (B2B) | 8 | `FRONTEND` `BACKEND` `DB` |

**Deliverables:** Skills tracking, resources, paths, community, assessments, B2B analytics

---

## Task Distribution Summary

### By Area (All Phases)

| Area | Estimated Tasks | % of Total |
|------|-----------------|------------|
| `FRONTEND` | ~95 | 30% |
| `BACKEND` | ~85 | 27% |
| `DB` | ~40 | 13% |
| `API` | ~25 | 8% |
| `INTEGRATION` | ~20 | 6% |
| `AI/ML` | ~18 | 6% |
| `TESTING` | ~20 | 6% |
| `DEVOPS` | ~10 | 3% |
| `DOCS` | ~5 | 2% |
| **Total** | **~318** | **100%** |

### Team Composition Recommendation

| Role | Count | Primary Areas | Phases |
|------|-------|---------------|--------|
| Frontend Lead | 1 | `FRONTEND` | All |
| Backend Lead | 1 | `BACKEND` `DB` | All |
| Full-Stack Dev | 2 | `FRONTEND` `BACKEND` | 1-5 |
| DevOps | 0.5 | `DEVOPS` `TESTING` | 0, 4 |
| AI/ML Engineer | 0.5 | `AI/ML` | 2, 4, 5 |
| **Total** | **5 FTE** | | |

---

## Critical Path Analysis

```
E0.0 → E0.1 → E0.2 → E0.3 → E1.2 → E1.4 → E2.1
(1d)   (2d)   (3d)   (3d)   (4d)   (5d)   (4d)

Total Critical Path: 22 days (4.4 weeks) = Minimum time to MVP
```

### Parallel Acceleration Opportunities

| Parallel Stream | Epics | Days Saved |
|-----------------|-------|------------|
| Auth + Schema | E0.2 ∥ E0.3 | 3 days |
| Marketing + Stripe | E1.1 ∥ E1.2 | 4 days |
| Email + Portal | E1.3 ∥ E1.4 | 3 days |
| All Phase 2 | E2.1 ∥ E2.2 ∥ E2.3 ∥ E2.4 | 11 days |
| Org + Admin | E3.1 ∥ E3.2 | 5 days |
| **Total Savings** | | **26 days** |

**Compressed Timeline with 3 engineers: 3-4 weeks to MVP** (vs 6 weeks sequential)

---

## Parallel Development Streams

| Stream | Focus | Epics | File Boundaries |
|--------|-------|-------|-----------------|
| **Stream A** | Auth & Users | E0.2, E3.1 | `convex/auth/`, `convex/organizations/` |
| **Stream B** | Courses & Content | E0.3, E1.1, E2.1, E2.5 | `convex/courses/`, `app/(marketing)/` |
| **Stream C** | Payments | E1.2 | `convex/payments/`, `app/api/webhooks/stripe/` |
| **Stream D** | Email & Comms | E1.3 | `convex/crons/`, `lib/brevo/` |
| **Stream E** | Learner Portal | E1.4, E2.1 | `app/(portal)/`, `components/portal/` |
| **Stream F** | AI & Chat | E2.3 | `convex/chat/`, `lib/openrouter/` |
| **Stream G** | Certificates | E2.4 | `convex/certificates/`, `lib/badges/` |
| **Stream H** | Admin | E3.2, E3.3 | `app/(admin)/`, `components/admin/` |
| **Stream I** | Platform API | E4.1, E4.2 | `app/api/v1/`, `mcp-server/` |
| **Stream J** | Skills & Paths | E5.1, E5.2, E5.3 | `convex/skills/`, `convex/paths/` |
| **Stream K** | Community | E5.4 | `convex/community/`, `app/(portal)/community/` |
| **Stream L** | Assessments | E5.5, E5.6 | `convex/assessments/`, `app/(portal)/assessments/` |

---

## Delivery Milestones

| Week | Milestone | Epics Complete |
|------|-----------|----------------|
| 2 | Foundation Complete | E0.0-E0.3 |
| 4 | Core MVP Ready | E1.1-E1.4 |
| 6 | Post-Cohort Live | E2.1-E2.5 |
| 8 | B2B + Admin Ready | E3.1-E3.3 |
| 10 | Platform API Launched | E4.1-E4.2 |
| 14 | v2.1 ICP Features | E5.1-E5.6 |

---

## Agent/Engineer Assignment Matrix

For AI agent or human engineer assignment:

| Complexity | Task Types | Recommended Assignee |
|------------|------------|---------------------|
| Low | `DOCS`, simple `FRONTEND` | Junior Dev / AI Agent |
| Medium | `FRONTEND`, `BACKEND`, `TESTING` | Mid-Level Dev / AI Agent |
| High | `DB`, `API`, `INTEGRATION` | Senior Dev |
| Expert | `AI/ML`, architecture decisions | Lead / Specialist |

### AI Agent Suitability

| Area | AI Agent Suitability | Notes |
|------|---------------------|-------|
| `FRONTEND` | ⭐⭐⭐⭐ High | Component generation, styling |
| `BACKEND` | ⭐⭐⭐⭐ High | CRUD operations, queries |
| `DB` | ⭐⭐⭐ Medium | Schema design needs review |
| `TESTING` | ⭐⭐⭐⭐⭐ Excellent | Test generation |
| `DOCS` | ⭐⭐⭐⭐⭐ Excellent | Documentation |
| `DEVOPS` | ⭐⭐ Low | Needs human oversight |
| `API` | ⭐⭐⭐ Medium | SDK integration |
| `AI/ML` | ⭐⭐⭐ Medium | Prompt engineering |
| `INTEGRATION` | ⭐⭐ Low | Complex error handling |

---

## Next Steps

1. **Review and approve** epic definitions in phase files
2. **Assign stream owners** (Frontend Lead, Backend Lead, etc.)
3. **Create worktrees** for Phase 0
4. **Initialize swarm** for parallel development
5. **Begin E0.0** - Quality Infrastructure Setup
