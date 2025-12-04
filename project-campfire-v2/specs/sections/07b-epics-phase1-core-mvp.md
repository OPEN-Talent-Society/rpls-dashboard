# Phase 1: Core MVP

**Duration:** Week 3-6
**Focus:** B2C purchase, learner portal
**Key Deliverables:** Public site, payments, learner access

## Worktree Strategy

Phase 1 enables parallel development across 4 independent streams:

```
develop
├── worktree/phase1-marketing    (E1.1) - Frontend stream
├── worktree/phase1-payments     (E1.2) - Backend/API stream
├── worktree/phase1-email        (E1.3) - Backend stream
└── worktree/phase1-portal       (E1.4) - Frontend stream
```

**Branch Naming:** `phase1/<epic>/<area>-<feature>`
**Example:** `phase1/E1.2/backend-stripe-webhooks`

---

## E1.0 - Performance & Mobile Optimization

**Owner:** Engineering
**Duration:** Ongoing (built into each sprint)
**Priority:** P0
**Branch:** N/A (applies to all branches)

**User Story:**
> As a learner, I want the platform to load quickly on my mobile device so I can access content anywhere.

### Quality Gates (Apply to ALL Tasks)

| Metric | Target | Tool |
|--------|--------|------|
| Lighthouse Performance | ≥90 | CI/CD |
| Lighthouse Accessibility | =100 | CI/CD |
| LCP | <2.5s on 3G | WebPageTest |
| INP | <200ms | Chrome DevTools |
| CLS | <0.1 | Lighthouse |
| Min Width | 320px | Manual QA |
| Touch Targets | ≥44x44px | Manual QA |

**Note:** This epic is NOT a standalone sprint but criteria that MUST be met for every feature delivered in Phase 1+.

---

## E1.1 - Marketing Site

**Owner:** Frontend Lead
**Duration:** 5 days
**Priority:** P0 - MVP Critical
**Branch:** `phase1/E1.1/frontend-marketing`

**User Story:**
> As a visitor, I need to browse courses and understand pricing so that I can decide to enroll.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E1.1-001 | Build homepage hero section | `FRONTEND` | 3 | - | E0.1 | - |
| E1.1-002 | Build course catalog preview (3 featured) | `FRONTEND` | 2 | ✅ | E1.1-001 | - |
| E1.1-003 | Build testimonial carousel | `FRONTEND` | 2 | ✅ | E1.1-001 | - |
| E1.1-004 | Build homepage CTA section | `FRONTEND` | 1 | ✅ | E1.1-001 | - |
| E1.1-005 | Build course catalog page layout | `FRONTEND` | 2 | ✅ | E0.3 | - |
| E1.1-006 | Build course card component | `FRONTEND` | 2 | ✅ | E1.1-005 | - |
| E1.1-007 | Implement catalog filtering (category/format) | `FRONTEND` `BACKEND` | 3 | - | E1.1-006 | - |
| E1.1-008 | Implement catalog sorting (date/popularity) | `FRONTEND` `BACKEND` | 2 | ✅ | E1.1-007 | - |
| E1.1-009 | Implement catalog search | `FRONTEND` `BACKEND` | 2 | ✅ | E1.1-007 | - |
| E1.1-010 | Build course detail page layout | `FRONTEND` | 3 | ✅ | E0.3 | - |
| E1.1-011 | Build instructor bio component | `FRONTEND` | 1.5 | ✅ | E1.1-010 | - |
| E1.1-012 | Build upcoming cohorts table | `FRONTEND` `BACKEND` | 2 | - | E1.1-010 | - |
| E1.1-013 | Build enrollment CTA button | `FRONTEND` | 1 | ✅ | E1.1-012 | - |
| E1.1-014 | Build pricing page with tiers | `FRONTEND` | 3 | ✅ | E0.1 | - |
| E1.1-015 | Build FAQ accordion | `FRONTEND` | 1.5 | ✅ | E1.1-014 | - |
| E1.1-016 | Build contact form with Zod validation | `FRONTEND` | 2 | ✅ | E0.1 | - |
| E1.1-017 | Implement Brevo contact form submission | `BACKEND` `API` | 2 | - | E1.1-016 | - |
| E1.1-018 | Add SEO meta tags to all pages | `FRONTEND` | 2 | - | E1.1-001-017 | - |
| E1.1-019 | Mobile responsive testing + fixes | `FRONTEND` `TESTING` | 3 | - | E1.1-018 | - |

**Area Legend:**
- `FRONTEND` - React components, Next.js pages, styling
- `BACKEND` - Convex queries and mutations
- `API` - External API integration (Brevo)
- `TESTING` - QA and responsive testing

**Parallel Streams:**
- **Stream A (Homepage):** E1.1-001 → E1.1-002/003/004
- **Stream B (Catalog):** E1.1-005 → E1.1-006 → E1.1-007 → E1.1-008/009
- **Stream C (Course Detail):** E1.1-010 → E1.1-011/012 → E1.1-013
- **Stream D (Other Pages):** E1.1-014/015/016 (parallel)

**Acceptance Criteria:**
- [ ] Homepage loads in <2s (Lighthouse score >90)
- [ ] Course catalog displays all active courses
- [ ] Filters update URL params for shareability
- [ ] Course detail shows correct cohort availability
- [ ] Contact form submits successfully to Brevo
- [ ] All pages mobile-responsive (tested on iOS/Android)
- [ ] SEO meta tags present on all pages

**Dependencies:** E0.3 (Database Schema)
**Risks:** Content (copy, images) may delay completion

---

## E1.2 - Stripe Integration

**Owner:** Backend Lead
**Duration:** 4 days
**Priority:** P0 - MVP Critical
**Branch:** `phase1/E1.2/backend-stripe`

**User Story:**
> As a learner, I need to securely purchase a cohort enrollment so that I can access the course.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E1.2-001 | Setup Stripe account (test + prod) | `DEVOPS` | 1 | - | - | - |
| E1.2-002 | Configure Stripe products/prices | `DEVOPS` | 1 | ✅ | E1.2-001 | - |
| E1.2-003 | Implement checkout session creation mutation | `BACKEND` `API` | 3 | - | E1.2-001 | - |
| E1.2-004 | Implement capacity validation in checkout | `BACKEND` | 2 | - | E1.2-003 | - |
| E1.2-005 | Build checkout button component | `FRONTEND` | 2 | ✅ | E1.2-003 | - |
| E1.2-006 | Build success redirect page | `FRONTEND` | 1 | ✅ | E1.2-003 | - |
| E1.2-007 | Build cancel redirect page | `FRONTEND` | 0.5 | ✅ | E1.2-003 | - |
| E1.2-008 | Create webhook endpoint route | `BACKEND` `API` | 1 | - | E1.2-001 | - |
| E1.2-009 | Implement webhook signature verification | `BACKEND` | 1 | - | E1.2-008 | - |
| E1.2-010 | Handle checkout.session.completed event | `BACKEND` | 2 | - | E1.2-009 | - |
| E1.2-011 | Create enrollment record on payment | `BACKEND` `DB` | 2 | - | E1.2-010 | - |
| E1.2-012 | Implement idempotency (prevent duplicates) | `BACKEND` | 1.5 | - | E1.2-011 | - |
| E1.2-013 | Handle charge.refunded event | `BACKEND` | 2 | ✅ | E1.2-009 | - |
| E1.2-014 | Implement refund processing mutation | `BACKEND` | 2 | - | E1.2-013 | - |
| E1.2-015 | Setup Stripe CLI for local dev | `DEVOPS` | 0.5 | ✅ | E1.2-001 | - |
| E1.2-016 | Add audit logging for all payment events | `BACKEND` | 1.5 | - | E1.2-011 | - |
| E1.2-017 | E2E payment flow tests | `TESTING` | 3 | - | E1.2-016 | - |

**Area Legend:**
- `BACKEND` - Convex mutations, business logic
- `FRONTEND` - React components
- `API` - Stripe SDK integration
- `DB` - Database operations
- `DEVOPS` - Configuration, tooling
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Setup):** E1.2-001 → E1.2-002/003/015
- **Stream B (Checkout UI):** E1.2-005/006/007 (parallel after E1.2-003)
- **Stream C (Webhooks):** E1.2-008 → E1.2-009 → E1.2-010/013 → E1.2-011 → E1.2-012

**Acceptance Criteria:**
- [ ] Checkout button redirects to Stripe Checkout
- [ ] Successful payment creates enrollment record
- [ ] Webhook logs in auditLog table
- [ ] Refund creates refund record and updates enrollment
- [ ] Capacity validation prevents overselling
- [ ] Test mode transactions work correctly
- [ ] Webhook signature verification passes
- [ ] Idempotency prevents duplicate enrollments

**Dependencies:** E0.2 (Authentication), E0.3 (Database Schema)
**Risks:** Stripe webhook delivery failures (implement retry logic)

---

## E1.3 - Email Automation

**Owner:** Backend Lead
**Duration:** 3 days
**Priority:** P1 - MVP Important
**Branch:** `phase1/E1.3/backend-email`

**User Story:**
> As a learner, I need to receive timely emails about my enrollment so that I don't miss important information.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E1.3-001 | Setup Brevo SDK configuration | `BACKEND` `API` | 1 | - | E0.1 | - |
| E1.3-002 | Create welcome email template in Brevo | `DOCS` | 1 | ✅ | E1.3-001 | - |
| E1.3-003 | Create T-7 reminder template | `DOCS` | 0.5 | ✅ | E1.3-001 | - |
| E1.3-004 | Create T-2 reminder template (with Zoom) | `DOCS` | 0.5 | ✅ | E1.3-001 | - |
| E1.3-005 | Create T-1 reminder template | `DOCS` | 0.5 | ✅ | E1.3-001 | - |
| E1.3-006 | Implement reusable sendEmail mutation | `BACKEND` `API` | 2 | - | E1.3-001 | - |
| E1.3-007 | Implement template parameter substitution | `BACKEND` | 1.5 | - | E1.3-006 | - |
| E1.3-008 | Send welcome email on enrollment | `BACKEND` | 1.5 | - | E1.3-006, E1.2-011 | - |
| E1.3-009 | Implement daily reminder cron job | `BACKEND` | 3 | - | E1.3-006 | - |
| E1.3-010 | Query enrollments needing reminders | `BACKEND` `DB` | 2 | - | E1.3-009 | - |
| E1.3-011 | Track sent emails in enrollments table | `BACKEND` `DB` | 1 | - | E1.3-010 | - |
| E1.3-012 | Implement email error handling + logging | `BACKEND` | 1.5 | - | E1.3-008 | - |
| E1.3-013 | Build email preview component (admin) | `FRONTEND` | 2 | ✅ | E1.3-006 | - |
| E1.3-014 | Email integration tests | `TESTING` | 2 | - | E1.3-011 | - |

**Area Legend:**
- `BACKEND` - Convex functions, cron jobs
- `API` - Brevo SDK integration
- `DB` - Database updates
- `FRONTEND` - Admin UI
- `DOCS` - Email template content
- `TESTING` - Integration tests

**Parallel Streams:**
- **Stream A (Setup):** E1.3-001 → E1.3-006 → E1.3-007
- **Stream B (Templates):** E1.3-002/003/004/005 (all parallel)
- **Stream C (Automation):** E1.3-008 → E1.3-009 → E1.3-010 → E1.3-011

**Acceptance Criteria:**
- [ ] Welcome email sends within 5 minutes of enrollment
- [ ] Reminder emails send at correct intervals
- [ ] Emails contain correct personalization (name, cohort)
- [ ] Zoom link only included in T-2 and T-1 emails
- [ ] Failed emails logged in auditLog
- [ ] Unsubscribe link included in all emails
- [ ] Email deliverability >95% (checked in Brevo)

**Dependencies:** E1.2 (Stripe Integration - triggers welcome email)
**Risks:** Brevo account approval (1-2 days), email deliverability issues

---

## E1.4 - Learner Portal

**Owner:** Frontend Lead
**Duration:** 5 days
**Priority:** P0 - MVP Critical
**Branch:** `phase1/E1.4/frontend-portal`

**User Story:**
> As an enrolled learner, I need a dashboard to access my courses, materials, and Zoom links so that I can participate in cohorts.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E1.4-001 | Build dashboard layout (sidebar + main) | `FRONTEND` | 3 | - | E0.2 | - |
| E1.4-002 | Build mobile hamburger menu | `FRONTEND` | 1.5 | ✅ | E1.4-001 | - |
| E1.4-003 | Build sidebar navigation component | `FRONTEND` | 2 | ✅ | E1.4-001 | - |
| E1.4-004 | Implement protected route check | `FRONTEND` `BACKEND` | 1.5 | - | E0.2 | - |
| E1.4-005 | Build CohortCard component | `FRONTEND` | 2.5 | ✅ | E1.4-001 | - |
| E1.4-006 | Build status badges (Upcoming/In Progress/Completed) | `FRONTEND` | 1 | ✅ | E1.4-005 | - |
| E1.4-007 | Build progress indicators | `FRONTEND` | 1.5 | ✅ | E1.4-005 | - |
| E1.4-008 | Query enrolled cohorts for user | `BACKEND` | 2 | - | E0.3 | - |
| E1.4-009 | Build enrolled cohorts grid display | `FRONTEND` | 2 | - | E1.4-005, E1.4-008 | - |
| E1.4-010 | Build cohort detail page layout | `FRONTEND` | 2.5 | ✅ | E1.4-001 | - |
| E1.4-011 | Query cohort detail with access control | `BACKEND` | 2.5 | - | E0.3 | - |
| E1.4-012 | Build course overview section | `FRONTEND` | 1.5 | ✅ | E1.4-010 | - |
| E1.4-013 | Build ZoomLinkButton (time-gated) | `FRONTEND` `BACKEND` | 3 | - | E1.4-011 | - |
| E1.4-014 | Build pre-work materials section | `FRONTEND` | 2 | ✅ | E1.4-010 | - |
| E1.4-015 | Build enablement kit downloads | `FRONTEND` | 1.5 | ✅ | E1.4-010 | - |
| E1.4-016 | Build profile settings page | `FRONTEND` | 2 | ✅ | E1.4-001 | - |
| E1.4-017 | Build notification preferences form | `FRONTEND` `BACKEND` | 2 | - | E1.4-016 | - |
| E1.4-018 | Build timezone selection | `FRONTEND` | 1 | ✅ | E1.4-016 | - |
| E1.4-019 | Add loading states to all queries | `FRONTEND` | 1.5 | - | E1.4-008 | - |
| E1.4-020 | Add error states for failed queries | `FRONTEND` | 1.5 | ✅ | E1.4-019 | - |
| E1.4-021 | Portal E2E tests | `TESTING` | 3 | - | E1.4-020 | - |

**Area Legend:**
- `FRONTEND` - React components, layouts
- `BACKEND` - Convex queries with access control
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Layout):** E1.4-001 → E1.4-002/003/004
- **Stream B (Dashboard):** E1.4-005 → E1.4-006/007 → E1.4-009
- **Stream C (Cohort Detail):** E1.4-010 → E1.4-011 → E1.4-012/013/014/015
- **Stream D (Profile):** E1.4-016 → E1.4-017/018

**Acceptance Criteria:**
- [ ] Dashboard shows all user enrollments
- [ ] Cohort detail page loads enrollment-specific data
- [ ] Zoom link only visible during access window
- [ ] Pre-work materials accessible immediately
- [ ] Navigation works on mobile (<768px)
- [ ] Loading states for all data fetches
- [ ] Error states for failed queries
- [ ] Unauthorized users redirected to sign-in

**Dependencies:** E0.2 (Authentication), E1.2 (Stripe - creates enrollments)
**Risks:** Zoom link security (implement signed URLs)

---

## Phase 1 Summary

**Total Duration:** ~17 days (3.4 weeks)
**Total Tasks:** 71 tasks

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `FRONTEND` | 42 | ~58h |
| `BACKEND` | 23 | ~32h |
| `API` | 6 | ~8h |
| `DB` | 4 | ~5h |
| `DEVOPS` | 3 | ~2.5h |
| `TESTING` | 4 | ~11h |
| `DOCS` | 4 | ~2.5h |
| **Total** | **71 tasks** | **~119h** |

### Parallel Execution Plan

With 2 engineers (Frontend + Backend), Phase 1 compresses to **~12-14 days**:

| Day | Frontend Engineer | Backend Engineer |
|-----|------------------|------------------|
| 1-2 | E1.1 Homepage (001-004) | E1.2 Setup (001-003) |
| 3-4 | E1.1 Catalog (005-009) | E1.2 Webhooks (008-012) |
| 5 | E1.1 Course Detail (010-013) | E1.2 Refunds (013-014) |
| 6 | E1.1 Pricing/Contact (014-017) | E1.3 Setup + Templates |
| 7 | E1.1 SEO + Testing (018-019) | E1.3 Automation (008-011) |
| 8-9 | E1.4 Layout (001-004) | E1.3 Testing + E1.2 Tests |
| 10-11 | E1.4 Dashboard (005-009) | E1.4 Backend queries |
| 12-13 | E1.4 Cohort Detail (010-015) | E1.4 Zoom time-gating |
| 14 | E1.4 Profile + Testing | Integration testing |

### Deliverables:
- ✅ Marketing site with course catalog, pricing, contact
- ✅ Stripe payment integration with webhook handling
- ✅ Email automation for enrollment and reminders
- ✅ Learner portal with dashboard and cohort access
- ✅ Mobile-optimized, accessible, performant UI

**Next Phase:** [Phase 2 (Post-Cohort)](./07c-epics-phase2-post-cohort.md) - Week 7-8
