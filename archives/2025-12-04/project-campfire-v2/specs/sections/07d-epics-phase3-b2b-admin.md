# Phase 3: B2B & Admin

**Duration:** Week 9-11
**Focus:** Organizations, admin dashboard, waitlist
**Key Deliverables:** Enterprise features, management tools

## Worktree Strategy

Phase 3 enables parallel development between B2B backend and Admin frontend:

```
develop
├── worktree/phase3-organizations  (E3.1) - Backend stream
├── worktree/phase3-admin          (E3.2) - Frontend stream
└── worktree/phase3-waitlist       (E3.3) - Backend stream
```

**Branch Naming:** `phase3/<epic>/<area>-<feature>`
**Example:** `phase3/E3.1/backend-org-invites`

---

## E3.1 - Organizations

**Owner:** Backend Lead
**Duration:** 5 days
**Priority:** P1 - Revenue Critical
**Branch:** `phase3/E3.1/backend-organizations`

**User Story:**
> As a company, I need to manage bulk enrollments for my team so that I can upskill multiple employees efficiently.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E3.1-001 | Create organization mutation | `BACKEND` `DB` | 2 | - | E0.3 | - |
| E3.1-002 | Edit organization details mutation | `BACKEND` | 1.5 | ✅ | E3.1-001 | - |
| E3.1-003 | Soft delete organization mutation | `BACKEND` | 1.5 | ✅ | E3.1-001 | - |
| E3.1-004 | List organizations query (admin) | `BACKEND` | 1 | ✅ | E3.1-001 | - |
| E3.1-005 | Implement invite token generation | `BACKEND` | 1.5 | - | E3.1-001 | - |
| E3.1-006 | Create invite mutation | `BACKEND` `DB` | 2 | - | E3.1-005 | - |
| E3.1-007 | Send invite email via Brevo | `BACKEND` `API` | 1.5 | - | E3.1-006 | - |
| E3.1-008 | Accept invite mutation | `BACKEND` | 2.5 | - | E3.1-006 | - |
| E3.1-009 | Decline invite mutation | `BACKEND` | 1 | ✅ | E3.1-006 | - |
| E3.1-010 | Create organizationMember on accept | `BACKEND` `DB` | 1.5 | - | E3.1-008 | - |
| E3.1-011 | Implement seat limit validation | `BACKEND` | 2 | - | E3.1-010 | - |
| E3.1-012 | Track active members vs seats | `BACKEND` | 1.5 | ✅ | E3.1-011 | - |
| E3.1-013 | Admin adjust seat count mutation | `BACKEND` | 1 | ✅ | E3.1-011 | - |
| E3.1-014 | Build B2B cohort selection (multi-select) | `FRONTEND` | 2.5 | ✅ | E3.1-001 | - |
| E3.1-015 | Bulk enrollment creation mutation | `BACKEND` `DB` | 3 | - | E3.1-011 | - |
| E3.1-016 | Send enrollment confirmation to each member | `BACKEND` `API` | 2 | - | E3.1-015 | - |
| E3.1-017 | List org members query | `BACKEND` | 1.5 | ✅ | E3.1-010 | - |
| E3.1-018 | Promote/demote member mutation | `BACKEND` | 1.5 | ✅ | E3.1-017 | - |
| E3.1-019 | Remove member mutation | `BACKEND` | 1.5 | ✅ | E3.1-017 | - |
| E3.1-020 | Transfer ownership mutation | `BACKEND` | 2 | - | E3.1-017 | - |
| E3.1-021 | Revoke org cohort access on removal | `BACKEND` | 2 | - | E3.1-019 | - |
| E3.1-022 | Build invite acceptance page | `FRONTEND` | 2.5 | - | E3.1-008 | - |
| E3.1-023 | Build org member management UI | `FRONTEND` | 3 | - | E3.1-017 | - |
| E3.1-024 | Organizations E2E tests | `TESTING` | 3 | - | E3.1-023 | - |

**Area Legend:**
- `BACKEND` - Mutations, queries, business logic
- `FRONTEND` - Org management UI
- `API` - Brevo email integration
- `DB` - Organization/member tables
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (CRUD):** E3.1-001 → E3.1-002/003/004
- **Stream B (Invites):** E3.1-005 → E3.1-006 → E3.1-007/008/009 → E3.1-010
- **Stream C (Seats):** E3.1-011 → E3.1-012/013 → E3.1-015
- **Stream D (Members):** E3.1-017 → E3.1-018/019/020 → E3.1-021

**Acceptance Criteria:**
- [ ] Admin can create organization with seat limit
- [ ] Invite emails sent with clickable acceptance link
- [ ] Accepting invite creates organizationMember
- [ ] Seat limit prevents over-enrollment
- [ ] Bulk enrollment creates multiple enrollments atomically
- [ ] Organization admin can manage members
- [ ] Removed members lose access to organization cohorts

**Dependencies:** E0.2 (Authentication), E1.2 (Stripe - B2B pricing tier)
**Risks:** Complex permissions model (document thoroughly)

---

## E3.2 - Admin Dashboard

**Owner:** Frontend Lead
**Duration:** 6 days
**Priority:** P1 - Operational Critical
**Branch:** `phase3/E3.2/frontend-admin`

**User Story:**
> As an admin, I need a comprehensive dashboard to manage courses, cohorts, enrollments, and users so that I can operate the platform efficiently.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E3.2-001 | Build admin layout (sidebar + content) | `FRONTEND` | 3 | - | E0.2 | - |
| E3.2-002 | Implement admin role check middleware | `FRONTEND` `BACKEND` | 1.5 | - | E0.2 | - |
| E3.2-003 | Build breadcrumb navigation | `FRONTEND` | 1 | ✅ | E3.2-001 | - |
| E3.2-004 | Build reusable DataTable component | `FRONTEND` | 4 | - | E3.2-001 | - |
| E3.2-005 | Implement DataTable sorting | `FRONTEND` | 1.5 | ✅ | E3.2-004 | - |
| E3.2-006 | Implement DataTable filtering | `FRONTEND` | 2 | ✅ | E3.2-004 | - |
| E3.2-007 | Implement DataTable pagination | `FRONTEND` `BACKEND` | 2 | - | E3.2-004 | - |
| E3.2-008 | Implement bulk selection checkbox | `FRONTEND` | 1.5 | ✅ | E3.2-004 | - |
| E3.2-009 | Build course management page | `FRONTEND` | 2 | - | E3.2-004 | - |
| E3.2-010 | Build create course modal form | `FRONTEND` | 2.5 | ✅ | E3.2-009 | - |
| E3.2-011 | Build edit course inline/modal | `FRONTEND` | 2 | ✅ | E3.2-009 | - |
| E3.2-012 | Implement archive course (soft delete) | `FRONTEND` `BACKEND` | 1.5 | - | E3.2-009 | - |
| E3.2-013 | Build cohort management page | `FRONTEND` | 2 | - | E3.2-004 | - |
| E3.2-014 | Build cohort filters (course, status, date) | `FRONTEND` | 1.5 | ✅ | E3.2-013 | - |
| E3.2-015 | Build create cohort form | `FRONTEND` | 2.5 | ✅ | E3.2-013 | - |
| E3.2-016 | Implement cancel cohort with refunds | `FRONTEND` `BACKEND` | 3 | - | E3.2-013 | - |
| E3.2-017 | Build enrollment management page | `FRONTEND` | 2 | - | E3.2-004 | - |
| E3.2-018 | Build enrollment search/filters | `FRONTEND` | 1.5 | ✅ | E3.2-017 | - |
| E3.2-019 | Build manual enrollment creation | `FRONTEND` `BACKEND` | 2.5 | - | E3.2-017 | - |
| E3.2-020 | Build refund enrollment action | `FRONTEND` | 1.5 | ✅ | E3.2-017 | - |
| E3.2-021 | Build mark complete action | `FRONTEND` `BACKEND` | 1.5 | - | E3.2-017 | - |
| E3.2-022 | Implement CSV export | `FRONTEND` `BACKEND` | 2 | - | E3.2-017 | - |
| E3.2-023 | Build user management page | `FRONTEND` | 2 | - | E3.2-004 | - |
| E3.2-024 | Build user detail view | `FRONTEND` | 2 | ✅ | E3.2-023 | - |
| E3.2-025 | Implement promote to admin | `FRONTEND` `BACKEND` | 1.5 | - | E3.2-023 | - |
| E3.2-026 | Implement disable account | `FRONTEND` `BACKEND` | 1.5 | - | E3.2-023 | - |
| E3.2-027 | Build analytics overview page | `FRONTEND` | 2.5 | ✅ | E3.2-001 | - |
| E3.2-028 | Build revenue metrics cards | `FRONTEND` `BACKEND` | 2 | - | E3.2-027 | - |
| E3.2-029 | Build enrollment metrics cards | `FRONTEND` `BACKEND` | 1.5 | ✅ | E3.2-027 | - |
| E3.2-030 | Build popular courses chart | `FRONTEND` | 2 | ✅ | E3.2-027 | - |
| E3.2-031 | Build cohort capacity chart | `FRONTEND` `BACKEND` | 2 | - | E3.2-027 | - |
| E3.2-032 | Mobile-responsive tables (horizontal scroll) | `FRONTEND` | 2 | - | E3.2-004 | - |
| E3.2-033 | Admin dashboard E2E tests | `TESTING` | 4 | - | E3.2-032 | - |

**Area Legend:**
- `FRONTEND` - Admin UI, tables, forms, charts
- `BACKEND` - Paginated queries, mutations
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Layout):** E3.2-001 → E3.2-002/003
- **Stream B (DataTable):** E3.2-004 → E3.2-005/006/007/008
- **Stream C (Courses):** E3.2-009 → E3.2-010/011/012
- **Stream D (Cohorts):** E3.2-013 → E3.2-014/015/016
- **Stream E (Enrollments):** E3.2-017 → E3.2-018/019/020/021/022
- **Stream F (Users):** E3.2-023 → E3.2-024/025/026
- **Stream G (Analytics):** E3.2-027 → E3.2-028/029/030/031

**Acceptance Criteria:**
- [ ] Only users with isAdmin=true can access dashboard
- [ ] All tables support pagination (50 per page)
- [ ] Search/filter updates URL params
- [ ] Create/edit forms validate inputs
- [ ] Bulk actions work on selected items
- [ ] CSV export downloads correctly
- [ ] Analytics charts render correctly
- [ ] Mobile-responsive tables (horizontal scroll)

**Dependencies:** E0.2 (Authentication - isAdmin check), E0.3 (Database - all tables)
**Risks:** Large data tables may slow down (implement server-side pagination)

---

## E3.3 - Waitlist

**Owner:** Backend Lead
**Duration:** 3 days
**Priority:** P2 - Revenue Optimization
**Branch:** `phase3/E3.3/backend-waitlist`

**User Story:**
> As a learner, I need to join a waitlist when a cohort is full so that I can enroll if a spot opens up.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E3.3-001 | Implement join waitlist mutation | `BACKEND` `DB` | 2 | - | E0.3 | - |
| E3.3-002 | Check cohort full status | `BACKEND` | 1 | ✅ | E3.3-001 | - |
| E3.3-003 | Create waitlistEntry with FIFO position | `BACKEND` | 1.5 | - | E3.3-001 | - |
| E3.3-004 | Send waitlist confirmation email | `BACKEND` `API` | 1.5 | - | E3.3-003 | - |
| E3.3-005 | Trigger offer on enrollment cancel/refund | `BACKEND` | 2 | - | E1.2-013 | - |
| E3.3-006 | Create offer for next in line (FIFO) | `BACKEND` | 2 | - | E3.3-005 | - |
| E3.3-007 | Generate offer token with 48h expiry | `BACKEND` | 1 | ✅ | E3.3-006 | - |
| E3.3-008 | Send offer email with accept/decline links | `BACKEND` `API` | 2 | - | E3.3-007 | - |
| E3.3-009 | Implement accept offer mutation | `BACKEND` | 2.5 | - | E3.3-008 | - |
| E3.3-010 | Create enrollment on offer accept | `BACKEND` `DB` | 1.5 | - | E3.3-009 | - |
| E3.3-011 | Implement decline offer mutation | `BACKEND` | 1 | ✅ | E3.3-008 | - |
| E3.3-012 | Implement offer expiry cron (hourly) | `BACKEND` | 2 | - | E3.3-007 | - |
| E3.3-013 | Create new offer on expire/decline | `BACKEND` | 1.5 | - | E3.3-012 | - |
| E3.3-014 | Build waitlist CTA on full cohorts | `FRONTEND` | 2 | - | E3.3-001 | - |
| E3.3-015 | Build waitlist position badge | `FRONTEND` | 1 | ✅ | E3.3-014 | - |
| E3.3-016 | Build accept/decline offer page | `FRONTEND` | 2.5 | - | E3.3-009 | - |
| E3.3-017 | Build admin waitlist view per cohort | `FRONTEND` | 2 | ✅ | E3.3-001 | - |
| E3.3-018 | Implement admin manual promotion | `FRONTEND` `BACKEND` | 2 | - | E3.3-017 | - |
| E3.3-019 | Implement admin remove from waitlist | `FRONTEND` `BACKEND` | 1 | ✅ | E3.3-017 | - |
| E3.3-020 | Optimistic concurrency for race conditions | `BACKEND` | 2 | - | E3.3-009 | - |
| E3.3-021 | Waitlist E2E tests | `TESTING` | 2.5 | - | E3.3-020 | - |

**Area Legend:**
- `BACKEND` - Waitlist logic, cron jobs
- `FRONTEND` - Waitlist UI, offer pages
- `API` - Email notifications
- `DB` - WaitlistEntry records
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Join):** E3.3-001 → E3.3-002/003 → E3.3-004
- **Stream B (Offers):** E3.3-005 → E3.3-006 → E3.3-007/008 → E3.3-009/011
- **Stream C (Expiry):** E3.3-012 → E3.3-013
- **Stream D (UI):** E3.3-014 → E3.3-015/016
- **Stream E (Admin):** E3.3-017 → E3.3-018/019

**Acceptance Criteria:**
- [ ] Full cohorts show "Join Waitlist" button
- [ ] Joining waitlist creates entry with correct position
- [ ] Refund triggers offer to next in waitlist
- [ ] Offer email includes accept/decline links
- [ ] Accepting offer creates enrollment
- [ ] Expired offers move to next person
- [ ] Admin can view/manage waitlist

**Dependencies:** E1.2 (Stripe - refunds trigger offers), E1.4 (Learner Portal - waitlist UI)
**Risks:** Race conditions (two people accepting same offer - use optimistic concurrency)

---

## Phase 3 Summary

**Total Duration:** ~14 days (2.8 weeks) sequential, ~8-10 days with parallelization
**Total Tasks:** 78 tasks

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `FRONTEND` | 38 | ~55h |
| `BACKEND` | 42 | ~58h |
| `API` | 5 | ~7h |
| `DB` | 8 | ~10h |
| `TESTING` | 3 | ~9.5h |
| **Total** | **78 tasks** | **~139.5h** |

### Parallel Execution Plan

With 2 engineers (Frontend + Backend), Phase 3 compresses to **~8-10 days**:

| Day | Frontend Engineer | Backend Engineer |
|-----|------------------|------------------|
| 1-2 | E3.2 Layout + DataTable | E3.1 Org CRUD + Invites |
| 3-4 | E3.2 Course/Cohort pages | E3.1 Seats + Bulk enroll |
| 5-6 | E3.2 Enrollment/User pages | E3.1 Member mgmt + E3.3 Waitlist core |
| 7-8 | E3.2 Analytics | E3.3 Offers + Expiry |
| 9-10 | E3.1 Org UI + E3.3 Waitlist UI | E3.3 Concurrency + All E2E tests |

### Deliverables:
- ✅ Organization management with seat licenses
- ✅ Member invitations and bulk enrollments
- ✅ Comprehensive admin dashboard
- ✅ Waitlist system with FIFO offers

**Next Phase:** [Phase 4 (Platform API)](./07e-epics-phase4-platform-api.md) - Week 12+
