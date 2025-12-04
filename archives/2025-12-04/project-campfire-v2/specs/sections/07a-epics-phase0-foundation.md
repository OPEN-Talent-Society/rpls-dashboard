# Phase 0: Foundation

**Duration:** Week 1-2
**Focus:** Project setup, auth, schema
**Key Deliverables:** Dev environment, auth system, database

## Worktree Strategy

Phase 0 uses a sequential worktree strategy due to foundational dependencies:

```
main
├── worktree/phase0-quality      (E0.0)
├── worktree/phase0-setup        (E0.1) - depends on E0.0
├── worktree/phase0-auth         (E0.2) - depends on E0.1
└── worktree/phase0-schema       (E0.3) - depends on E0.1, parallel with E0.2
```

**Branch Naming:** `phase0/<epic>/<area>-<task-id>`
**Example:** `phase0/E0.1/devops-001`

---

## E0.0 - Quality Infrastructure Setup

**Owner:** Engineering
**Duration:** 1 day
**Priority:** P0 - Blocking
**Branch:** `phase0/E0.0/quality-infra`

**User Story:**
> As a developer, I need quality infrastructure and accessibility tooling in place so that we maintain high standards from day one.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E0.0-001 | Configure Lighthouse CI in GitHub Actions | `DEVOPS` | 2 | ✅ | - | - |
| E0.0-002 | Add axe-core to Jest test suite | `TESTING` | 1 | ✅ | - | - |
| E0.0-003 | Add Playwright accessibility tests | `TESTING` | 2 | ✅ | - | - |
| E0.0-004 | Define performance budgets in next.config.js | `DEVOPS` | 1 | ✅ | - | - |
| E0.0-005 | Setup eslint-plugin-jsx-a11y | `DEVOPS` | 0.5 | ✅ | - | - |
| E0.0-006 | Document WCAG 2.2 AA checklist | `DOCS` | 1.5 | ✅ | - | - |

**Area Legend:**
- `DEVOPS` - CI/CD, configuration, infrastructure
- `TESTING` - Test setup and automation
- `DOCS` - Documentation

**Acceptance Criteria:**
- [ ] Lighthouse CI configured in GitHub Actions
- [ ] axe-core integrated into test suite
- [ ] Performance budgets defined in next.config.js
- [ ] WCAG 2.2 AA checklist documented
- [ ] Mobile-first Tailwind config set up
- [ ] Accessibility linting (eslint-plugin-jsx-a11y) enabled
- [ ] All CI checks passing on pull requests

**Dependencies:** None (first task)
**Risks:** None (foundational setup)

**Quality Standards:**
- Lighthouse: Performance >90, Accessibility 100, Best Practices 100, SEO 100
- Bundle: First Load JS < 200KB, LCP < 2.5s, CLS < 0.1

---

## E0.1 - Project Setup

**Owner:** Tech Lead
**Duration:** 2 days
**Priority:** P0 - Blocking
**Branch:** `phase0/E0.1/project-setup`

**User Story:**
> As a developer, I need a fully configured Next.js 15 project so that I can begin feature development with all tooling in place.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E0.1-001 | Initialize Next.js 15 with App Router + TypeScript | `FRONTEND` | 1 | - | E0.0 | - |
| E0.1-002 | Configure pnpm workspace + package.json | `DEVOPS` | 0.5 | ✅ | E0.1-001 | - |
| E0.1-003 | Setup Convex project (dev/staging/prod) | `BACKEND` | 2 | ✅ | E0.1-001 | - |
| E0.1-004 | Install + configure shadcn/ui with theme | `FRONTEND` | 2 | ✅ | E0.1-001 | - |
| E0.1-005 | Configure Vercel deployment + preview branches | `DEVOPS` | 1 | ✅ | E0.1-001 | - |
| E0.1-006 | Setup environment variables (.env.local, .env.example) | `DEVOPS` | 0.5 | ✅ | E0.1-003 | - |
| E0.1-007 | Configure ESLint, Prettier, Husky pre-commit | `DEVOPS` | 1 | ✅ | E0.1-001 | - |
| E0.1-008 | Create README.md + CONTRIBUTING.md | `DOCS` | 1 | ✅ | E0.1-001 | - |

**Area Legend:**
- `FRONTEND` - React, Next.js, UI components
- `BACKEND` - Convex, serverless functions
- `DEVOPS` - Configuration, deployment, tooling
- `DOCS` - Documentation

**Parallelization Note:** Tasks E0.1-002 through E0.1-008 can all run in parallel once E0.1-001 completes.

**Acceptance Criteria:**
- [ ] `pnpm dev` starts local development server
- [ ] `pnpm build` completes without errors
- [ ] Convex functions deploy to dev environment
- [ ] shadcn/ui components render correctly
- [ ] Vercel preview deployment succeeds
- [ ] All environment variables documented

**Dependencies:** E0.0 (Quality Infrastructure Setup)
**Risks:** None (greenfield)

---

## E0.2 - Authentication

**Owner:** Backend Lead
**Duration:** 3 days
**Priority:** P0 - Blocking
**Branch:** `phase0/E0.2/auth`

**User Story:**
> As a user, I need to securely authenticate using Google OAuth or magic link so that I can access the platform.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E0.2-001 | Implement Convex Auth base setup | `BACKEND` | 2 | - | E0.1 | - |
| E0.2-002 | Configure Google OAuth provider | `BACKEND` | 3 | ✅ | E0.2-001 | - |
| E0.2-003 | Configure magic link provider + rate limiting | `BACKEND` | 2 | ✅ | E0.2-001 | - |
| E0.2-004 | Implement user creation callback (users table) | `BACKEND` `DB` | 2 | - | E0.2-001 | - |
| E0.2-005 | Build SignIn component | `FRONTEND` | 2 | ✅ | E0.2-001 | - |
| E0.2-006 | Build SignUp component | `FRONTEND` | 1.5 | ✅ | E0.2-001 | - |
| E0.2-007 | Build SignOut button | `FRONTEND` | 0.5 | ✅ | E0.2-001 | - |
| E0.2-008 | Create protected route middleware | `FRONTEND` `BACKEND` | 2 | - | E0.2-004 | - |
| E0.2-009 | Setup session management | `BACKEND` | 2 | - | E0.2-001 | - |
| E0.2-010 | Implement useCurrentUser hook | `FRONTEND` | 1 | - | E0.2-009 | - |
| E0.2-011 | E2E auth flow tests | `TESTING` | 2 | - | E0.2-010 | - |

**Area Legend:**
- `FRONTEND` - React components, hooks
- `BACKEND` - Convex auth, providers
- `DB` - Database schema changes
- `TESTING` - E2E and integration tests

**Parallel Streams:**
- **Stream A (Backend):** E0.2-001 → E0.2-002/003/004 → E0.2-009
- **Stream B (Frontend):** E0.2-005/006/007 (parallel after E0.2-001)
- **Stream C (Integration):** E0.2-008 → E0.2-010 → E0.2-011

**Acceptance Criteria:**
- [ ] Users can sign in with Google OAuth
- [ ] Users can sign in with magic link email
- [ ] New users automatically created in database
- [ ] Protected routes redirect to /sign-in
- [ ] Session persists across page refreshes
- [ ] Sign out clears session correctly
- [ ] Auth UI follows design system

**Dependencies:** E0.1 (Project Setup)
**Risks:** OAuth consent screen approval (1-3 days)

**Security Considerations:**
- CSRF protection enabled
- Magic link expiry: 15 minutes
- Rate limiting: 5 requests per email per hour
- Session expiry: 30 days with sliding window

---

## E0.3 - Database Schema

**Owner:** Backend Lead
**Duration:** 3 days
**Priority:** P0 - Blocking
**Branch:** `phase0/E0.3/schema`

**User Story:**
> As a developer, I need a complete database schema so that I can implement business logic with proper data models.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E0.3-001 | Define Core tables (users, courses, cohorts, enrollments) | `DB` | 3 | - | E0.1 | - |
| E0.3-002 | Define Content tables (recordings, enablementKits, certificates) | `DB` | 2 | ✅ | E0.3-001 | - |
| E0.3-003 | Define Commerce tables (payments, refunds, waitlistEntries) | `DB` | 2 | ✅ | E0.3-001 | - |
| E0.3-004 | Define B2B tables (organizations, orgMembers, invites) | `DB` | 2 | ✅ | E0.3-001 | - |
| E0.3-005 | Define Engagement tables (conversations, messages, bookings) | `DB` | 2 | ✅ | E0.3-001 | - |
| E0.3-006 | Define Platform tables (apiKeys, webhooks, auditLog) | `DB` | 1.5 | ✅ | E0.3-001 | - |
| E0.3-007 | Create all indexes for query patterns | `DB` | 2 | - | E0.3-002-006 | - |
| E0.3-008 | Create seed data script (dev) | `BACKEND` | 2 | - | E0.3-007 | - |
| E0.3-009 | Implement schema validation functions | `BACKEND` `TESTING` | 2 | ✅ | E0.3-007 | - |
| E0.3-010 | Generate ERD documentation | `DOCS` | 1 | ✅ | E0.3-007 | - |
| E0.3-011 | Document migration strategy | `DOCS` | 1 | ✅ | E0.3-007 | - |

**Area Legend:**
- `DB` - Convex schema definitions
- `BACKEND` - Seed scripts, validation
- `TESTING` - Schema tests
- `DOCS` - ERD, migration docs

**Parallelization Note:**
- E0.3-002 through E0.3-006 can ALL run in parallel (different table groups)
- E0.3-009, E0.3-010, E0.3-011 can run in parallel after indexes complete

**Table Groups for Parallel Development:**

| Group | Tables | Branch |
|-------|--------|--------|
| Core | users, courses, cohorts, enrollments | `phase0/E0.3/db-core` |
| Content | recordings, enablementKits, certificates | `phase0/E0.3/db-content` |
| Commerce | payments, refunds, waitlistEntries | `phase0/E0.3/db-commerce` |
| B2B | organizations, organizationMembers, invites | `phase0/E0.3/db-b2b` |
| Engagement | conversations, messages, officeHourBookings | `phase0/E0.3/db-engagement` |
| Platform | apiKeys, webhookSubscriptions, auditLog | `phase0/E0.3/db-platform` |

**Acceptance Criteria:**
- [ ] All 18 tables defined with correct fields
- [ ] All indexes created for query optimization
- [ ] Seed data populates sample courses/cohorts
- [ ] Schema validation functions pass tests
- [ ] ERD documentation generated
- [ ] Migration path documented

**Dependencies:** E0.1 (Project Setup)
**Risks:** Schema changes require data migration in production

**Data Model Example:**
```typescript
// enrollments table with all relationships
enrollments: defineTable({
  userId: v.id("users"),
  cohortId: v.id("cohorts"),
  status: v.union(v.literal("active"), v.literal("completed"), v.literal("cancelled")),
  purchaseDate: v.number(),
  completionDate: v.optional(v.number()),
  paymentId: v.id("payments"),
  certificateId: v.optional(v.id("certificates")),
})
  .index("by_user", ["userId"])
  .index("by_cohort", ["cohortId"])
  .index("by_status", ["status"])
  .index("by_user_cohort", ["userId", "cohortId"])
```

---

## Phase 0 Summary

**Total Duration:** 9 days (1.8 weeks)
**Critical Path:** E0.0 → E0.1 → E0.2 → E0.3

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `DEVOPS` | 8 | 6.5h |
| `FRONTEND` | 7 | 8h |
| `BACKEND` | 10 | 17h |
| `DB` | 9 | 14.5h |
| `TESTING` | 4 | 6h |
| `DOCS` | 5 | 5.5h |
| **Total** | **43 tasks** | **57.5h** |

### Parallel Execution Opportunities

With 3 engineers, Phase 0 can compress to **5-6 days**:

| Day | Engineer 1 (Backend) | Engineer 2 (Frontend) | Engineer 3 (DevOps) |
|-----|---------------------|----------------------|---------------------|
| 1 | E0.0-001,002,003 | E0.0-004,005 | E0.0-006 |
| 2 | E0.1-003 | E0.1-001,004 | E0.1-002,005,007 |
| 3 | E0.2-001,002 | E0.2-005,006,007 | E0.1-006,008 |
| 4 | E0.2-003,004,009 | E0.2-008,010 | E0.3-001 |
| 5 | E0.3-002,003,007 | E0.2-011 | E0.3-004,005,006 |
| 6 | E0.3-008,009 | - | E0.3-010,011 |

### Deliverables:
- ✅ Quality infrastructure with CI/CD, accessibility, performance monitoring
- ✅ Complete Next.js 15 project setup with Convex, shadcn/ui, Vercel
- ✅ Authentication system with Google OAuth and magic links
- ✅ Complete database schema with 18 tables and indexes

**Next Phase:** [Phase 1 (Core MVP)](./07b-epics-phase1-core-mvp.md) - Week 3-6
