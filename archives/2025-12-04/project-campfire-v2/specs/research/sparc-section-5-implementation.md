# Section 5: Implementation Planning

## 5.1 Implementation Phases

### PHASE 0: Foundation (Week 1, Days 1-7)

**Objective**: Establish core infrastructure and development environment

**Deliverables**:
- Next.js 15 project with App Router and TypeScript
- Convex backend with schema deployed
- Convex Auth configured (Google OAuth + Magic Links)
- shadcn/ui component library integrated
- Vercel deployment pipeline with preview environments
- Environment configuration and secrets management
- Base layouts and routing structure
- Development tooling (ESLint, Prettier, testing setup)

**Success Criteria**:
- ✅ Application deploys to Vercel successfully
- ✅ Authentication flow completes end-to-end
- ✅ Convex schema migrations work correctly
- ✅ shadcn/ui components render properly
- ✅ CI/CD pipeline passes all checks

**Risk Mitigation**:
- Start with Convex template for proven setup
- Use official Convex Auth examples
- Lock dependency versions to avoid breaking changes

---

### PHASE 1: Live Cohort MVP (Weeks 2-4, Days 8-28)

**Objective**: Launch minimum viable platform for live cohort sales and delivery

**Deliverables**:

**Marketing Layer** (Days 8-14):
- Hero page with value proposition
- Course catalog with filtering
- Individual course detail pages
- Pricing page with cohort dates
- FAQ and testimonials sections

**Enrollment Flow** (Days 15-21):
- Stripe checkout integration
- Enrollment record creation
- Purchase confirmation page
- Automated confirmation email (Brevo)
- Pre-cohort drip email sequence

**Learner Experience** (Days 22-28):
- Learner portal dashboard
- Enrolled courses list
- Course content access (Zoom links, materials)
- Profile management
- Basic progress tracking

**Admin Tools** (Days 22-28):
- Admin dashboard with metrics
- Cohort management interface
- Enrollment list and search
- Manual enrollment creation
- Email blast capability

**Success Criteria**:
- ✅ Learner can discover course → purchase → receive confirmation
- ✅ Learner can access enrolled courses and materials
- ✅ Admin can create cohorts and view enrollments
- ✅ Stripe webhooks process payments correctly
- ✅ Email automations trigger on schedule

**Constraints**:
- Single course type only (2-day intensive)
- Manual cohort creation (no self-service)
- Basic UI polish (functional over beautiful)

---

### PHASE 2: Engagement & Retention (Weeks 5-7, Days 29-49)

**Objective**: Increase completion rates and enable B2B partnerships

**Deliverables**:

**Engagement Tools** (Days 29-35):
- Office hours booking (Cal.com integration)
- Enablement Kit download access
- Certificate generation with digital signatures
- Post-cohort feedback surveys (Formbricks)
- Reminder emails for upcoming sessions

**B2B Features** (Days 36-42):
- Partner/Organization accounts
- Bulk manual enrollment workflow
- Custom pricing and invoicing tracking
- Partner-specific landing pages
- White-label certificate option

**Community Foundation** (Days 43-49):
- Waitlist management for sold-out cohorts
- Referral tracking system
- Alumni directory (opt-in)
- Resource library organization
- Discussion forum (basic)

**Success Criteria**:
- ✅ 80%+ learners book office hours
- ✅ Certificates generate automatically on completion
- ✅ Partners can enroll teams via admin interface
- ✅ Feedback surveys achieve 60%+ response rate
- ✅ Waitlist converts to next cohort enrollment

**Metrics to Track**:
- Office hours booking rate
- Enablement Kit download rate
- Certificate claim rate
- Referral conversion rate
- Waitlist conversion rate

---

### PHASE 3: Self-Paced & Scale (Weeks 8-10, Days 50-70) **[DEFERRED]**

**Objective**: Enable asynchronous learning and multiple course formats

**Deliverables**:

**Self-Paced Architecture** (Days 50-56):
- Module-based content structure
- Drip content scheduling engine
- Video progress tracking
- Quiz and assessment system
- Completion criteria logic

**Session Type Expansion** (Days 57-63):
- Webinar format support
- Hackathon/workshop format
- Office hours as standalone product
- Hybrid cohort (live + async)
- Recorded session library

**Advanced Analytics** (Days 64-70):
- Cohort performance dashboards
- Learner engagement scoring
- Content effectiveness metrics
- Revenue forecasting
- Churn prediction

**Success Criteria**:
- ✅ Self-paced learners can progress independently
- ✅ Multiple session types coexist in catalog
- ✅ Drip content releases on schedule
- ✅ Analytics inform content improvements

**Deferral Rationale**:
- Live cohorts validate market demand first
- Self-paced requires significant content investment
- Analytics need baseline data from Phase 1-2

---

### PHASE 4: AI Coach & Community (Weeks 11+, Days 71+) **[DEFERRED]**

**Objective**: Differentiate with AI assistance and peer learning

**Deliverables**:

**AI Coaching** (Days 71-84):
- Knowledge chatbot with OpenRouter integration
- Context-aware Q&A using course materials
- Personalized learning recommendations
- Automated check-ins and nudges
- Usage analytics and feedback loop

**Community Platform** (Days 85-98):
- Slack workspace integration
- Peer mentorship matching
- Project showcase gallery
- Live coding sessions
- Champion network activation

**Personalization Engine** (Days 99-112):
- Learning path recommendations
- Skill gap analysis
- Custom course bundles
- Dynamic pricing experiments
- A/B testing framework

**Success Criteria**:
- ✅ AI chatbot answers 70%+ questions accurately
- ✅ Community drives 30%+ referrals
- ✅ Personalized paths increase completion by 20%
- ✅ Champion network generates 50% of enrollments

**Deferral Rationale**:
- Requires substantial content corpus for AI training
- Community needs critical mass of engaged learners
- Personalization depends on behavioral data

---

## 5.2 Epic Definitions

### PHASE 0 EPICS

#### E0.1: Project Scaffolding
**Description**: Initialize Next.js 15 project with Convex backend and development tooling

**Acceptance Criteria**:
- [ ] Next.js 15 project created with App Router and TypeScript
- [ ] Convex backend initialized with schema files
- [ ] ESLint, Prettier, and Git hooks configured
- [ ] README with setup instructions
- [ ] Environment variable documentation

**Dependencies**: None
**Complexity**: M (Medium)
**Duration**: 1 day

---

#### E0.2: Convex Schema Design
**Description**: Define database schema for courses, enrollments, users, and payments

**Acceptance Criteria**:
- [ ] Schema files created for all core tables
- [ ] Indexes defined for common queries
- [ ] Validation rules implemented
- [ ] Migration scripts tested
- [ ] Schema documentation complete

**Dependencies**: E0.1
**Complexity**: L (Large)
**Duration**: 2 days

---

#### E0.3: Authentication Setup
**Description**: Configure Convex Auth with Google OAuth and Magic Links

**Acceptance Criteria**:
- [ ] Google OAuth provider configured
- [ ] Magic link email provider configured
- [ ] Auth middleware implemented
- [ ] Protected routes working
- [ ] Session management tested

**Dependencies**: E0.2
**Complexity**: M
**Duration**: 2 days

---

#### E0.4: UI Foundation
**Description**: Integrate shadcn/ui and create base layouts

**Acceptance Criteria**:
- [ ] shadcn/ui components installed
- [ ] Base layout with header/footer
- [ ] Typography system configured
- [ ] Color palette and theme defined
- [ ] Responsive breakpoints tested

**Dependencies**: E0.1
**Complexity**: S (Small)
**Duration**: 1 day

---

#### E0.5: Deployment Pipeline
**Description**: Configure Vercel deployment with preview environments

**Acceptance Criteria**:
- [ ] Vercel project linked to GitHub repo
- [ ] Preview deployments work on PR creation
- [ ] Production deployment on main branch merge
- [ ] Environment variables synced
- [ ] Custom domain configured

**Dependencies**: E0.1, E0.3
**Complexity**: S
**Duration**: 1 day

---

### PHASE 1 EPICS

#### E1.1: Marketing Pages
**Description**: Build public-facing marketing pages for course discovery

**Acceptance Criteria**:
- [ ] Hero page with CTA buttons
- [ ] Course catalog with search and filters
- [ ] Course detail pages with dynamic routing
- [ ] Pricing page with cohort calendar
- [ ] FAQ and testimonials sections

**Dependencies**: E0.4
**Complexity**: L
**Duration**: 5 days

---

#### E1.2: Course Management
**Description**: Admin interface for creating and managing courses

**Acceptance Criteria**:
- [ ] Course creation form with validation
- [ ] Course editing with draft/published states
- [ ] Cohort scheduling interface
- [ ] Course archival and deletion
- [ ] Media upload for course images

**Dependencies**: E0.2, E0.3
**Complexity**: M
**Duration**: 3 days

---

#### E1.3: Stripe Checkout Integration
**Description**: Implement payment flow with Stripe Checkout

**Acceptance Criteria**:
- [ ] Stripe account connected to Convex
- [ ] Checkout session creation endpoint
- [ ] Redirect to Stripe-hosted checkout
- [ ] Webhook handler for payment success
- [ ] Payment failure handling

**Dependencies**: E0.3, E1.1
**Complexity**: L
**Duration**: 4 days

---

#### E1.4: Enrollment Management
**Description**: Create and track course enrollments

**Acceptance Criteria**:
- [ ] Enrollment records created on payment
- [ ] Enrollment status tracking (pending, active, completed)
- [ ] Duplicate enrollment prevention
- [ ] Enrollment cancellation workflow
- [ ] Admin manual enrollment interface

**Dependencies**: E1.3
**Complexity**: M
**Duration**: 3 days

---

#### E1.5: Email Automation
**Description**: Automated email sequences using Brevo

**Acceptance Criteria**:
- [ ] Brevo API integration configured
- [ ] Purchase confirmation email template
- [ ] Pre-cohort drip sequence (7 days, 3 days, 1 day before)
- [ ] Post-cohort thank you email
- [ ] Email sending triggered by enrollment events

**Dependencies**: E1.4
**Complexity**: M
**Duration**: 3 days

---

#### E1.6: Learner Portal
**Description**: Authenticated dashboard for enrolled learners

**Acceptance Criteria**:
- [ ] Dashboard showing enrolled courses
- [ ] Course content access (Zoom links, materials)
- [ ] Progress indicators
- [ ] Profile editing
- [ ] Enrollment history

**Dependencies**: E0.3, E1.4
**Complexity**: L
**Duration**: 4 days

---

#### E1.7: Admin Dashboard
**Description**: Admin interface for platform management

**Acceptance Criteria**:
- [ ] Metrics overview (revenue, enrollments, active courses)
- [ ] Enrollment list with search and filters
- [ ] User management (roles, permissions)
- [ ] Email blast tool for announcements
- [ ] Export data to CSV

**Dependencies**: E0.3, E1.4
**Complexity**: M
**Duration**: 3 days

---

### PHASE 2 EPICS

#### E2.1: Office Hours Integration
**Description**: Cal.com booking for learner-coach sessions

**Acceptance Criteria**:
- [ ] Cal.com account linked to platform
- [ ] Booking widget embedded in learner portal
- [ ] Calendar synced with enrollment data
- [ ] Reminder emails sent (24h before)
- [ ] Session history tracked

**Dependencies**: E1.6
**Complexity**: M
**Duration**: 3 days

---

#### E2.2: Enablement Kit Access
**Description**: Downloadable resources for enrolled learners

**Acceptance Criteria**:
- [ ] File storage integration (Convex file storage)
- [ ] Upload interface for admins
- [ ] Download access control (enrolled users only)
- [ ] Version tracking for kit updates
- [ ] Download analytics

**Dependencies**: E1.6
**Complexity**: S
**Duration**: 2 days

---

#### E2.3: Certificate Generation
**Description**: Automated certificates on course completion

**Acceptance Criteria**:
- [ ] Certificate template design
- [ ] PDF generation with learner name and date
- [ ] Digital signature for authenticity
- [ ] Certificate delivery via email
- [ ] Certificate verification page (public)

**Dependencies**: E1.6
**Complexity**: M
**Duration**: 3 days

---

#### E2.4: Feedback Surveys
**Description**: Formbricks integration for post-cohort feedback

**Acceptance Criteria**:
- [ ] Formbricks account connected
- [ ] Survey triggered on cohort end date
- [ ] Survey responses stored in Convex
- [ ] Admin dashboard showing aggregated feedback
- [ ] Follow-up email for non-responders

**Dependencies**: E1.6
**Complexity**: S
**Duration**: 2 days

---

#### E2.5: B2B Enrollment
**Description**: Partner/organization accounts with bulk enrollment

**Acceptance Criteria**:
- [ ] Organization account creation
- [ ] Bulk enrollment CSV upload
- [ ] Custom pricing per organization
- [ ] Partner-specific landing pages
- [ ] Invoice tracking interface

**Dependencies**: E1.4, E1.7
**Complexity**: L
**Duration**: 5 days

---

#### E2.6: Waitlist Management
**Description**: Capture demand for sold-out cohorts

**Acceptance Criteria**:
- [ ] Waitlist signup form on course detail page
- [ ] Waitlist notification when seats open
- [ ] Automatic conversion to enrollment (optional)
- [ ] Waitlist analytics dashboard
- [ ] Email sequence for waitlist nurturing

**Dependencies**: E1.1, E1.5
**Complexity**: M
**Duration**: 3 days

---

## 5.3 Thin-Slice Task Breakdown

### Example: E1.3 - Stripe Checkout Integration

**Epic Goal**: Enable learners to purchase courses via Stripe

**Vertical Slices** (each delivers user value):

---

#### **Slice 1: Create Checkout Session (API Foundation)**
**User Value**: Backend can generate Stripe checkout URLs
**Duration**: 4 hours

**Tasks**:
1. Install Stripe SDK and configure API keys
2. Create Convex action `createCheckoutSession.ts`
3. Implement checkout session creation logic (line items, customer email)
4. Test with Stripe CLI webhook forwarding
5. Return checkout URL to client

**Acceptance**:
- [ ] API endpoint returns valid Stripe checkout URL
- [ ] URL includes correct price and metadata
- [ ] Test mode transaction succeeds

**Files Changed**:
- `convex/stripe/createCheckoutSession.ts` (new)
- `convex/schema.ts` (add paymentIntent field)
- `.env.local` (add Stripe keys)

---

#### **Slice 2: Checkout Button Component (UI Integration)**
**User Value**: Learners see "Enroll Now" button that redirects to Stripe
**Duration**: 3 hours

**Tasks**:
1. Create `CheckoutButton.tsx` component
2. Call `createCheckoutSession` action on click
3. Handle loading state during session creation
4. Redirect to Stripe checkout URL
5. Add error handling for failed session creation

**Acceptance**:
- [ ] Button click redirects to Stripe checkout page
- [ ] Loading spinner shows during redirect
- [ ] Error message displays if session creation fails

**Files Changed**:
- `components/checkout/CheckoutButton.tsx` (new)
- `app/courses/[id]/page.tsx` (add button)

---

#### **Slice 3: Success Page with Polling (Purchase Confirmation)**
**User Value**: Learners see confirmation after payment
**Duration**: 5 hours

**Tasks**:
1. Create `/checkout/success` page
2. Extract `session_id` from URL query params
3. Poll Convex for enrollment creation (webhook may lag)
4. Display success message with enrollment details
5. Redirect to learner portal after confirmation

**Acceptance**:
- [ ] Success page loads after Stripe redirect
- [ ] Enrollment data appears within 10 seconds
- [ ] Graceful handling if webhook hasn't fired yet

**Files Changed**:
- `app/checkout/success/page.tsx` (new)
- `convex/enrollments/getEnrollmentBySessionId.ts` (new query)

---

#### **Slice 4: Enrollment Creation (Webhook Handler)**
**User Value**: System creates enrollment record on successful payment
**Duration**: 6 hours

**Tasks**:
1. Create `convex/http.ts` webhook endpoint
2. Verify Stripe webhook signature
3. Handle `checkout.session.completed` event
4. Create enrollment record with payment metadata
5. Update user's enrolled courses list
6. Log transaction for audit trail

**Acceptance**:
- [ ] Webhook endpoint returns 200 OK for valid signatures
- [ ] Enrollment record created with correct course and user IDs
- [ ] Payment metadata stored (amount, currency, Stripe ID)
- [ ] Idempotent (duplicate webhooks don't create duplicate enrollments)

**Files Changed**:
- `convex/http.ts` (new)
- `convex/enrollments/createEnrollment.ts` (new mutation)
- `convex/schema.ts` (add stripeSessionId index)

---

#### **Slice 5: Confirmation Email (Post-Purchase Automation)**
**User Value**: Learners receive email confirmation with next steps
**Duration**: 4 hours

**Tasks**:
1. Create Brevo email template for purchase confirmation
2. Trigger email send from `createEnrollment` mutation
3. Include enrollment details (course name, cohort date, Zoom link)
4. Add unsubscribe link and support contact
5. Test email delivery in Brevo sandbox

**Acceptance**:
- [ ] Email sends within 1 minute of enrollment creation
- [ ] Email includes correct learner name and course details
- [ ] Links in email are functional (portal, support)
- [ ] Email logs stored for debugging

**Files Changed**:
- `convex/email/sendPurchaseConfirmation.ts` (new action)
- `convex/enrollments/createEnrollment.ts` (add email trigger)
- Brevo dashboard (template creation)

---

### Thin-Slice Benefits for E1.3

| Slice | Independent Deploy? | User-Testable? | Rollback Safe? |
|-------|---------------------|----------------|----------------|
| 1: API Foundation | ✅ Yes (no UI change) | ✅ Via Stripe CLI | ✅ Yes |
| 2: Checkout Button | ✅ Yes (feature flag) | ✅ Click and redirect | ✅ Yes |
| 3: Success Page | ✅ Yes (new route) | ✅ Full purchase flow | ✅ Yes |
| 4: Webhook Handler | ✅ Yes (background) | ✅ Via Stripe dashboard | ⚠️ Requires monitoring |
| 5: Email Trigger | ✅ Yes (async action) | ✅ Test mode emails | ✅ Yes |

**Parallel Work Opportunity**: Slices 2 and 4 can be developed simultaneously by different developers (UI vs. backend).

---

### Example: E1.6 - Learner Portal

**Epic Goal**: Authenticated dashboard for enrolled learners

**Vertical Slices**:

---

#### **Slice 1: Authentication Gate (Access Control)**
**User Value**: Only logged-in users can access portal
**Duration**: 2 hours

**Tasks**:
1. Create `/portal` route with layout
2. Add auth middleware to check session
3. Redirect unauthenticated users to login
4. Display loading state during auth check
5. Show user profile in header

**Acceptance**:
- [ ] Unauthenticated users redirected to `/login`
- [ ] Authenticated users see portal layout
- [ ] User name and email displayed in header

---

#### **Slice 2: Empty State Dashboard (Base Layout)**
**User Value**: Users see portal structure even without enrollments
**Duration**: 3 hours

**Tasks**:
1. Create dashboard layout with sidebar navigation
2. Add empty state for "My Courses" section
3. Include CTA to browse catalog
4. Responsive design for mobile
5. Add footer with support links

**Acceptance**:
- [ ] Portal renders correctly on desktop and mobile
- [ ] Empty state messaging is clear and helpful
- [ ] Navigation links functional (even if destinations empty)

---

#### **Slice 3: Enrolled Courses List (Data Display)**
**User Value**: Users see courses they've purchased
**Duration**: 4 hours

**Tasks**:
1. Create Convex query `getEnrolledCourses.ts`
2. Fetch enrollments for current user
3. Join with course data (title, image, cohort date)
4. Display as card grid on dashboard
5. Add loading skeleton

**Acceptance**:
- [ ] Enrolled courses appear on dashboard load
- [ ] Course cards show title, date, and status
- [ ] No enrolled courses shows empty state

---

#### **Slice 4: Course Detail Page (Content Access)**
**User Value**: Users access Zoom links and materials
**Duration**: 5 hours

**Tasks**:
1. Create `/portal/courses/[id]` dynamic route
2. Verify user enrollment before showing content
3. Display course schedule with session dates/times
4. Show Zoom links for upcoming sessions
5. Add downloadable materials section

**Acceptance**:
- [ ] Only enrolled users can access course page
- [ ] Zoom links visible 24 hours before session
- [ ] Materials download correctly

---

#### **Slice 5: Progress Tracking (Engagement Metrics)**
**User Value**: Users see completion status
**Duration**: 4 hours

**Tasks**:
1. Add `progress` field to enrollment schema
2. Create mutation `updateProgress.ts` (mark session attended)
3. Display progress bar on dashboard
4. Show completion badge when 100% complete
5. Calculate and store completion percentage

**Acceptance**:
- [ ] Progress bar updates when sessions marked attended
- [ ] Completion badge appears when all sessions done
- [ ] Progress persists across sessions

---

#### **Slice 6: Profile Management (User Settings)**
**User Value**: Users can update name, email, preferences
**Duration**: 3 hours

**Tasks**:
1. Create `/portal/profile` page
2. Display current user data (name, email, role)
3. Implement edit form with validation
4. Save changes to Convex users table
5. Add email notification preference toggles

**Acceptance**:
- [ ] Profile data loads correctly
- [ ] Form validation prevents invalid data
- [ ] Changes save and persist on reload
- [ ] Success message shown after save

---

## 5.4 Parallel Development Streams

### Stream Assignment Matrix

| Stream | Epics | Team Size | Start Day | End Day | Dependencies |
|--------|-------|-----------|-----------|---------|--------------|
| **A: Foundation** | E0.1-E0.5 | 2 devs | Day 1 | Day 7 | None |
| **B: Marketing** | E1.1 | 2-3 devs | Day 8 | Day 14 | Stream A complete |
| **C: Admin Tools** | E1.2, E1.7 | 1-2 devs | Day 8 | Day 21 | Stream A complete |
| **D: Payments** | E1.3, E1.4 | 2 devs | Day 15 | Day 21 | E1.1 (checkout button placement) |
| **E: Email** | E1.5 | 1 dev | Day 15 | Day 18 | E1.4 (enrollment triggers) |
| **F: Learner Portal** | E1.6 | 2 devs | Day 22 | Day 28 | E1.4 (enrollment data) |
| **G: Engagement** | E2.1-E2.4 | 2 devs | Day 29 | Day 42 | E1.6 complete |
| **H: B2B Features** | E2.5 | 1-2 devs | Day 29 | Day 42 | E1.7 (admin interface) |
| **I: Waitlist** | E2.6 | 1 dev | Day 29 | Day 35 | E1.1 (course pages) |

### Critical Path Analysis

```
┌──────────────────────────────────────────────────────────────────┐
│                        CRITICAL PATH                              │
└──────────────────────────────────────────────────────────────────┘

Day 1────────Day 7────────Day 14───────Day 21───────Day 28
  │            │            │            │            │
  │   PHASE 0  │          PHASE 1 (Marketing MVP)     │
  │  (Setup)   │                                      │
  ▼            ▼            ▼            ▼            ▼
┌────┐      ┌────┐      ┌────┐      ┌────┐      ┌────┐
│ A  │─────▶│ B  │─────▶│ D  │─────▶│ F  │─────▶│LAUNCH│
│Found│      │Mktg│      │Pay │      │Port│      │      │
└────┘      └────┘      └────┘      └────┘      └────┘
  │            │            │            │
  │            ├────────────┤            │
  │            │   E (Email)│            │
  │            └────────────┘            │
  │                                      │
  └──────────────────────────────────────┘
           C (Admin) runs parallel
```

**Critical Path** (longest dependency chain):
A → B → D → F = **28 days minimum**

**Bottleneck Identification**:
1. **Day 7**: Foundation must complete before any feature work
2. **Day 14**: Marketing pages gate payment integration
3. **Day 21**: Payment integration gates learner portal
4. **Day 28**: Portal completion gates PHASE 2 engagement features

### Parallelization Opportunities

#### Week 1 (Days 1-7): Foundation Phase
```
┌─────────────────────────────────────────┐
│  Dev 1: E0.1 → E0.2 → E0.3             │
│  Dev 2: E0.4 → E0.5                    │
└─────────────────────────────────────────┘
```
- **No conflicts**: Different file domains
- **Merge strategy**: Feature branches, merge daily

#### Week 2 (Days 8-14): Marketing + Admin
```
┌─────────────────────────────────────────┐
│  Stream B (2-3 devs): Marketing Pages   │
│    ├─ Dev 1: Hero + Catalog             │
│    ├─ Dev 2: Course Detail Pages        │
│    └─ Dev 3: Pricing + FAQ              │
│                                         │
│  Stream C (1-2 devs): Admin Interface   │
│    └─ Dev 4: Course Management          │
└─────────────────────────────────────────┘
```
- **Low conflict risk**: Separate route paths
- **Shared files**: Layout components (lock early), schema (coordinate changes)

#### Week 3 (Days 15-21): Payments + Email + Admin
```
┌─────────────────────────────────────────┐
│  Stream D (2 devs): Stripe Integration  │
│    ├─ Dev 1: Checkout + Webhooks        │
│    └─ Dev 2: Enrollment Logic           │
│                                         │
│  Stream E (1 dev): Email Automation     │
│    └─ Dev 3: Brevo Templates            │
│                                         │
│  Stream C (1 dev): Admin Dashboard      │
│    └─ Dev 4: Metrics + User Management  │
└─────────────────────────────────────────┘
```
- **Medium conflict risk**: Enrollment schema changes (coordinate via Slack)
- **Shared files**: `convex/enrollments/*` (use feature flags to isolate logic)

#### Week 4 (Days 22-28): Learner Portal
```
┌─────────────────────────────────────────┐
│  Stream F (2 devs): Portal Development  │
│    ├─ Dev 1: Dashboard + Courses List   │
│    └─ Dev 2: Course Access + Profile    │
└─────────────────────────────────────────┘
```
- **High conflict risk**: Portal layout (assign one owner)
- **Merge strategy**: Merge Dev 1's layout first, Dev 2 rebases

### Team Size vs. Timeline Trade-offs

| Team Size | Timeline | Rationale |
|-----------|----------|-----------|
| **2 devs** | 8 weeks | Sequential work, minimal parallelization |
| **4 devs** | 4 weeks | **RECOMMENDED** - Optimal parallelization, manageable coordination |
| **6+ devs** | 3 weeks | Diminishing returns, high coordination overhead |

**Recommended**: **4 developers** for **28-day timeline** (4 weeks)

---

## 5.5 Worktree Compatibility

### File Boundary Strategy

**Goal**: Enable multiple developers to work on different features without merge conflicts

#### Low-Conflict Zones (Parallel-Safe)

**Route-Based Isolation**:
```
app/
├── (marketing)/          ← Stream B (Marketing)
│   ├── page.tsx
│   ├── courses/
│   └── pricing/
│
├── portal/               ← Stream F (Learner Portal)
│   ├── layout.tsx
│   ├── dashboard/
│   └── courses/
│
├── admin/                ← Stream C (Admin Tools)
│   ├── layout.tsx
│   ├── courses/
│   └── enrollments/
│
└── checkout/             ← Stream D (Payments)
    └── success/
```

**Component Isolation**:
```
components/
├── marketing/            ← Stream B ownership
├── portal/               ← Stream F ownership
├── admin/                ← Stream C ownership
└── checkout/             ← Stream D ownership
```

**Backend Isolation**:
```
convex/
├── courses/              ← Stream C writes, others read
├── enrollments/          ← Stream D writes, Stream F reads
├── stripe/               ← Stream D exclusive
├── email/                ← Stream E exclusive
└── users/                ← Stream F writes, others read
```

#### High-Conflict Files (Coordination Required)

**Shared Schema** (`convex/schema.ts`):
- **Owner**: Assigned per week
- **Process**: Schema changes require PR review from all stream leads
- **Workaround**: Use `v.optional()` for new fields to avoid breaking changes

**Root Layout** (`app/layout.tsx`):
- **Owner**: Stream A (Foundation), locked after Day 7
- **Changes**: Require approval from tech lead
- **Workaround**: Create nested layouts for isolated changes

**Shared Components** (`components/ui/*`):
- **Owner**: Stream A installs, all streams read-only
- **Changes**: Propose via GitHub Discussion before implementing
- **Workaround**: Create feature-specific variants instead of modifying base

**Environment Variables** (`.env.local`):
- **Owner**: Rotating (whoever adds new integration)
- **Process**: Update `.env.example` and post in Slack #dev channel
- **Workaround**: Use namespaced keys (e.g., `STRIPE_*`, `BREVO_*`)

### Merge Strategy Recommendations

#### Feature Branch Workflow
```bash
# Developer workflow
git checkout -b feature/stream-d-stripe-checkout
# ... make changes ...
git commit -m "feat(payments): add Stripe checkout session creation"
git push origin feature/stream-d-stripe-checkout
# Create PR → Review → Merge to main
```

#### Daily Integration Points
```
┌──────────────────────────────────────────┐
│  9 AM:  Stand-up + merge conflicts check │
│  12 PM: Mid-day sync (optional)          │
│  5 PM:  End-of-day PR review             │
│  6 PM:  Merge approved PRs to main       │
└──────────────────────────────────────────┘
```

#### Conflict Resolution Protocol

**Minor Conflicts** (e.g., import order, formatting):
- Auto-resolve with Prettier
- Developer resolves and self-merges

**Medium Conflicts** (e.g., function signature changes):
- Developer pings affected stream lead in PR comment
- Pair review conflict resolution
- Merge after approval

**Major Conflicts** (e.g., schema breaking changes):
- Tech lead mediates
- Synchronous call to align
- May require refactor before merge

### Locking Strategy for High-Risk Files

**Week 1 (Foundation)**:
- 🔒 `convex/schema.ts` - Locked to Stream A
- 🔒 `app/layout.tsx` - Locked to Stream A
- 🔒 `components/ui/*` - Locked to Stream A

**Week 2 (Marketing + Admin)**:
- 🔒 `convex/schema.ts` - Unlocked, changes require PR approval
- 🔒 `app/(marketing)/layout.tsx` - Locked to Stream B
- 🔒 `app/admin/layout.tsx` - Locked to Stream C

**Week 3 (Payments + Email)**:
- ⚠️ `convex/enrollments/schema.ts` - High-conflict zone, coordinate via Slack
- 🔒 `convex/stripe/*` - Locked to Stream D
- 🔒 `convex/email/*` - Locked to Stream E

**Week 4 (Learner Portal)**:
- 🔒 `app/portal/layout.tsx` - Locked to Stream F (Dev 1)
- ⚠️ `convex/enrollments/queries.ts` - Coordinate with Stream D

### Git Worktree Usage

**Setup** (for developers working on multiple streams):
```bash
# Main repository
cd ai-enablement-academy
git worktree add ../academy-stream-b feature/stream-b-marketing
git worktree add ../academy-stream-d feature/stream-d-payments

# Now you have 3 working directories:
# 1. ai-enablement-academy (main)
# 2. academy-stream-b (marketing work)
# 3. academy-stream-d (payments work)
```

**Benefits**:
- Switch contexts without stashing
- Run both branches simultaneously (different ports)
- Test integration locally before merging

**Cleanup**:
```bash
git worktree remove ../academy-stream-b
git worktree remove ../academy-stream-d
```

### Pre-Merge Checklist

Before merging any PR, verify:

- [ ] **Build passes**: `pnpm build` succeeds
- [ ] **Tests pass**: `pnpm test` (if tests exist)
- [ ] **Lint clean**: `pnpm lint` (no errors)
- [ ] **No console errors**: Manual QA in browser
- [ ] **Convex schema deployed**: `pnpm convex deploy` (if schema changed)
- [ ] **Environment variables documented**: `.env.example` updated
- [ ] **Conflicts resolved**: No merge conflict markers
- [ ] **Approved by stream lead**: At least 1 approval
- [ ] **Breaking changes communicated**: Posted in Slack #dev

### Dependency Coordination Matrix

| Stream | Writes To | Reads From | Coordination Required |
|--------|-----------|------------|-----------------------|
| A: Foundation | Schema, Layout, UI | - | None (first stream) |
| B: Marketing | Marketing routes, components | Schema, UI | Low (isolated routes) |
| C: Admin | Admin routes, course mutations | Schema, UI, enrollments | Medium (schema changes) |
| D: Payments | Stripe routes, enrollment mutations | Schema, courses | High (enrollment schema) |
| E: Email | Email templates, actions | Enrollments | Medium (enrollment triggers) |
| F: Portal | Portal routes, user queries | Schema, enrollments, courses | High (reads enrollment data) |
| G: Engagement | Cal.com, certs, surveys | Enrollments, users | Medium (extends enrollments) |
| H: B2B | Organizations, bulk enrollments | Enrollments, courses | Medium (new schema tables) |
| I: Waitlist | Waitlist routes, notifications | Courses, enrollments | Low (isolated feature) |

**Coordination Channels**:
- 🔴 High: Daily sync call + Slack thread
- 🟡 Medium: Slack updates before schema changes
- 🟢 Low: Async PR reviews

---

## Summary: Implementation Readiness

### Phase 0 Completion Gates
✅ Convex schema deployed to production
✅ Authentication working end-to-end
✅ Vercel CI/CD pipeline operational
✅ Development environment documented

### Phase 1 Launch Criteria
✅ Learner can complete purchase flow
✅ Admin can create cohorts and view enrollments
✅ Emails send automatically on enrollment
✅ Payment webhook tested in production
✅ At least 5 alpha testers complete flow

### Phase 2 Engagement Gates
✅ Office hours booked by 80%+ of enrollments
✅ Certificates generated without manual intervention
✅ B2B partner successfully enrolls team
✅ Feedback surveys achieve 60%+ response rate

### Deferred Phases Trigger Conditions
**Phase 3** (Self-Paced):
- 100+ enrollments in live cohorts
- 3+ courses in catalog
- Content team ready for async production

**Phase 4** (AI Coach):
- 500+ enrollments (enough data for AI training)
- Community of 200+ active learners
- Budget for OpenRouter API costs ($500+/month)

---

**Next Steps**:
1. Assign stream leads and team members
2. Create GitHub project board with epics and slices
3. Schedule daily stand-ups for each stream
4. Set up Slack channels for coordination (#dev, #stream-b, #stream-d, etc.)
5. Begin PHASE 0 on Day 1 with full team alignment

**Estimated Timeline**: **28 days to Phase 1 launch** with 4-person team.
