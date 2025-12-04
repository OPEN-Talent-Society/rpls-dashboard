# 3. Architecture

## 3.1 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │  Marketing Pages│  │ Learner Portal  │  │    Admin Dashboard          │ │
│  │    (SSG/ISR)    │  │   (Protected)   │  │  (Role-based Protected)     │ │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────────────────┤ │
│  │ • Homepage      │  │ • Dashboard     │  │ • Course Management         │ │
│  │ • Course Catalog│  │ • Cohort View   │  │ • Cohort Management         │ │
│  │ • Course Detail │  │ • Office Hours  │  │ • Enrollment Management     │ │
│  │ • Pricing       │  │ • AI Chatbot    │  │ • Organization Management   │ │
│  │ • About/Contact │  │ • Certificates  │  │ • Analytics & Reports       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │
│                                                                               │
│                    Next.js 15 App Router (Vercel Edge)                       │
│                    • Server Components • Client Components                   │
│                    • Server Actions • Route Handlers                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Convex React Client
                                      │ Real-time Subscriptions
                                      │ Optimistic Updates
                                      │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND LAYER                                   │
│                                CONVEX                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐  ┌─────┐  ┌──────────────┐ │
│  │ Queries  │  │ Mutations │  │ HTTP Actions │  │Crons│  │ File Storage │ │
│  ├──────────┤  ├───────────┤  ├──────────────┤  ├─────┤  ├──────────────┤ │
│  │ • list   │  │ • create  │  │ • Webhooks   │  │Daily│  │ • Avatars    │ │
│  │ • get    │  │ • update  │  │ • Stripe CB  │  │Tasks│  │ • Certs      │ │
│  │ • search │  │ • delete  │  │ • Cal.com CB │  │     │  │ • Assets     │ │
│  │ • filter │  │ • enroll  │  │ • Brevo CB   │  │     │  │ • Uploads    │ │
│  └──────────┘  └───────────┘  └──────────────┘  └─────┘  └──────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        Convex Database                                   ││
│  │  • Document-based NoSQL • Real-time Reactivity • ACID Transactions      ││
│  │  • Automatic Indexing • Vector Search Ready • Built-in Auth             ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ SDK & Webhook Integrations
                                      │
┌─────────────────────────────────────────────────────────────────────────────┐
│                          INTEGRATION LAYER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌────────┐  ┌───────┐  ┌─────────┐  ┌───────────┐  ┌─────────┐  ┌───────┐│
│  │ Stripe │  │ Brevo │  │ PostHog │  │Formbricks │  │ Cal.com │  │OpenRtr││
│  ├────────┤  ├───────┤  ├─────────┤  ├───────────┤  ├─────────┤  ├───────┤│
│  │Payment │  │ Email │  │Analytics│  │  Survey   │  │Booking  │  │  AI   ││
│  │Billing │  │Market │  │Events   │  │ Feedback  │  │Scheduling│ │ Chat  ││
│  │Webhook │  │Trans  │  │Flags    │  │  NPS/CSAT │  │ Webhook │  │ LLM   ││
│  └────────┘  └───────┘  └─────────┘  └───────────┘  └─────────┘  └───────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

**Architecture Principles:**
- **Edge-First**: Next.js deployed to Vercel Edge for global low-latency
- **Real-time**: Convex reactive queries for instant UI updates
- **Serverless**: Zero server management, auto-scaling backend
- **Type-Safe**: End-to-end TypeScript from database to UI
- **Composable**: Modular integrations via webhooks and SDKs

## 3.2 Data Flow Diagram

### Enrollment Flow: User Selection → Payment → Confirmation

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         ENROLLMENT & PAYMENT FLOW                             │
└──────────────────────────────────────────────────────────────────────────────┘

[User] ──1─→ Browse Course Page (/courses/[slug])
              │
              │ Click "Enroll Now"
              │
              ├─2─→ Select Cohort + Pricing Plan
              │     (B2C Individual | B2B Team | Enterprise)
              │
              ├─3─→ [Convex Mutation: checkout.create]
              │     • Validate seat availability
              │     • Check organization membership
              │     • Create pending enrollment record
              │     • Generate Stripe Checkout Session
              │
              ├─4─→ Redirect to Stripe Checkout
              │     (hosted payment page)
              │
              └─5─→ User Completes Payment
                    │
                    ├─── Payment Success ───┐
                    │                        │
                    ▼                        │
         ┌─────────────────────────┐        │
         │  Stripe Webhook Event   │        │
         │  checkout.session.      │        │
         │  completed              │        │
         └─────────────────────────┘        │
                    │                        │
                    ├─6─→ [Convex HTTP Action: stripe.webhook]
                    │     • Verify webhook signature
                    │     • Extract payment metadata
                    │     • Update enrollment status: pending → active
                    │     • Decrement available seats
                    │     • Create certificate record (if applicable)
                    │     • Trigger welcome email
                    │
                    ├─7─→ [Convex Mutation: brevo.sendTransactional]
                    │     • Enrollment confirmation email
                    │     • Cohort access credentials
                    │     • Session schedule (ICS attachment)
                    │     • Onboarding checklist
                    │
                    ├─8─→ [PostHog Event: enrollment_completed]
                    │     • Track conversion
                    │     • User properties update
                    │     • Feature flag eligibility
                    │
                    └─9─→ Redirect User to Dashboard
                          (/portal)
                          │
                          └─→ Real-time Convex Query Updates
                              • New cohort appears in "My Learning"
                              • Access to course materials
                              • Office hours booking enabled

                    Payment Failure ────┐
                                        │
                    ┌───────────────────┘
                    │
                    ├─10─→ [Stripe Webhook: checkout.session.expired]
                    │      • Mark enrollment as failed
                    │      • Release reserved seat
                    │      • Send recovery email (Brevo)
                    │
                    └─11─→ User sees error message
                           "Payment unsuccessful. Try again?"
```

### Email Automation Trigger Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        EMAIL AUTOMATION TRIGGERS                              │
└──────────────────────────────────────────────────────────────────────────────┘

ENROLLMENT LIFECYCLE EMAILS:

1. ENROLLMENT CONFIRMATION (Immediate)
   Trigger: enrollment.status = "active"
   Template: "Welcome to [Course Name]"
   Data: { cohortId, sessionSchedule, slackInvite, enablementKit }

2. PRE-SESSION REMINDER (24 hours before)
   Trigger: Convex Cron (daily check)
   Condition: session.startDate - now() < 24h AND user.enrolled
   Template: "Session Tomorrow: [Session Title]"
   Data: { sessionTitle, zoomLink, preworkUrl }

3. SESSION RECORDING AVAILABLE (2 hours after session)
   Trigger: Convex Cron (hourly check)
   Condition: session.endDate + 2h < now() AND recording.uploaded
   Template: "Recording Ready: [Session Title]"
   Data: { recordingUrl, transcriptUrl, slidesUrl }

4. MILESTONE ACHIEVEMENT (Event-driven)
   Trigger: certificate.issued = true
   Template: "Congratulations! You completed [Course Name]"
   Data: { certificateUrl, badgeImage, shareLinks }

5. OFFICE HOURS CONFIRMATION (Cal.com webhook)
   Trigger: Cal.com booking.created
   Template: "Office Hours Confirmed with [Instructor]"
   Data: { meetingTime, zoomLink, agenda, cancelUrl }

6. COHORT COMPLETION SURVEY (1 day after last session)
   Trigger: Convex Cron (daily check)
   Condition: cohort.endDate + 1d = today
   Template: "Share Your Feedback"
   Data: { formbricksUrl, npsPrompt, incentive }

7. RENEWAL REMINDER (30 days before expiry - Enterprise only)
   Trigger: Convex Cron (weekly check)
   Condition: organization.expiresAt - now() < 30d
   Template: "Renew Your Team Access"
   Data: { expiryDate, renewalLink, accountManager }

INTEGRATION ARCHITECTURE:

[Event Source] ──→ [Convex Mutation] ──→ [brevo.sendTransactional]
                                              │
                                              ├─→ Brevo API
                                              │   • Template ID
                                              │   • Recipient email
                                              │   • Dynamic params
                                              │   • Tracking tags
                                              │
                                              └─→ Response Logged
                                                  • messageId stored
                                                  • delivery tracked
                                                  • opens/clicks via webhook
```

### B2B Organization Enrollment Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      B2B ORGANIZATION ENROLLMENT                              │
└──────────────────────────────────────────────────────────────────────────────┘

ENTERPRISE SALES-ASSISTED:

1. Sales Team Creates Organization
   [Admin] ──→ /admin/organizations/create
            ├─→ orgName, domain, seatCount, expiresAt
            └─→ [Convex Mutation: organizations.create]

2. Admin Invites Organization Admin
   [Admin] ──→ /admin/organizations/[id]/invite
            ├─→ email, role: "org_admin"
            └─→ [Convex Mutation: organizationInvites.create]
                 │
                 └─→ Email sent with invite link
                     (/org/join/[inviteToken])

3. Org Admin Accepts Invite
   [Org Admin] ──→ Click email link
                ├─→ Create account (if new user)
                ├─→ [Convex Mutation: organizationInvites.accept]
                │    • Link user to organization
                │    • Assign org_admin role
                │    • Mark invite as accepted
                └─→ Redirect to /org/dashboard

4. Org Admin Invites Team Members
   [Org Admin] ──→ /org/team/invite
                ├─→ Upload CSV or enter emails
                ├─→ [Convex Mutation: organizationInvites.bulkCreate]
                │    • Max invites = org.seatsPurchased - org.seatsUsed
                │    • Generate unique tokens
                │    • Send invitation emails (Brevo)
                └─→ Track invitation status

5. Team Member Enrollment
   [Team Member] ──→ Click invite link
                  ├─→ Create account (auto-joined to org)
                  ├─→ Browse available courses
                  ├─→ Self-enroll in cohorts
                  │    • No payment required (org pays)
                  │    • Seat count decremented
                  │    • Org admin notified
                  └─→ Access course materials

6. Seat Management
   [Org Admin] ──→ /org/dashboard
                ├─→ View: seatsUsed / seatsPurchased
                ├─→ Remove team members (frees seats)
                └─→ Request seat expansion (contact sales)
```

## 3.3 Component Hierarchy

```
app/
├── layout.tsx                          # Root layout (global providers)
│   ├── ConvexClientProvider            # Real-time data layer
│   ├── PostHogProvider                 # Analytics tracking
│   └── Toaster                         # Notifications
│
├── (marketing)/                        # Public pages (SSG/ISR)
│   ├── layout.tsx                      # Marketing layout (header/footer)
│   ├── page.tsx                        # Homepage (/)
│   ├── courses/
│   │   ├── page.tsx                    # Course catalog (/courses)
│   │   └── [slug]/
│   │       ├── page.tsx                # Course detail (/courses/ai-mastery)
│   │       └── enroll/
│   │           └── page.tsx            # Enrollment form (/courses/ai-mastery/enroll)
│   ├── pricing/
│   │   └── page.tsx                    # Pricing page (/pricing)
│   ├── about/
│   │   └── page.tsx                    # About page (/about)
│   └── contact/
│       └── page.tsx                    # Contact form (/contact)
│
├── (auth)/                             # Authentication pages
│   ├── layout.tsx                      # Auth layout (centered form)
│   ├── login/
│   │   └── page.tsx                    # Login page (/login)
│   ├── register/
│   │   └── page.tsx                    # Register page (/register)
│   ├── verify-email/
│   │   └── page.tsx                    # Email verification (/verify-email)
│   └── reset-password/
│       └── page.tsx                    # Password reset (/reset-password)
│
├── (dashboard)/                        # Learner portal (protected)
│   ├── layout.tsx                      # Dashboard layout (sidebar nav)
│   ├── portal/
│   │   └── page.tsx                    # Dashboard home (/portal)
│   ├── cohorts/
│   │   └── [id]/
│   │       ├── page.tsx                # Cohort detail (/cohorts/123)
│   │       ├── sessions/
│   │       │   └── [sessionId]/
│   │       │       └── page.tsx        # Session view (/cohorts/123/sessions/456)
│   │       └── recordings/
│   │           └── page.tsx            # Recordings library (/cohorts/123/recordings)
│   ├── office-hours/
│   │   ├── page.tsx                    # Office hours booking (/office-hours)
│   │   └── [bookingId]/
│   │       └── page.tsx                # Booking detail (/office-hours/789)
│   ├── chatbot/
│   │   └── page.tsx                    # AI chatbot interface (/chatbot)
│   ├── certificates/
│   │   └── page.tsx                    # Certificates & badges (/certificates)
│   └── profile/
│       └── page.tsx                    # User profile settings (/profile)
│
├── (admin)/                            # Admin dashboard (role: platform_admin)
│   ├── layout.tsx                      # Admin layout (admin sidebar)
│   ├── admin/
│   │   ├── page.tsx                    # Admin home (/admin)
│   │   ├── courses/
│   │   │   ├── page.tsx                # Course management list (/admin/courses)
│   │   │   ├── create/
│   │   │   │   └── page.tsx            # Create course (/admin/courses/create)
│   │   │   └── [id]/
│   │   │       ├── page.tsx            # Edit course (/admin/courses/123)
│   │   │       └── sessions/
│   │   │           ├── page.tsx        # Manage sessions (/admin/courses/123/sessions)
│   │   │           └── create/
│   │   │               └── page.tsx    # Create session
│   │   ├── cohorts/
│   │   │   ├── page.tsx                # Cohort management list (/admin/cohorts)
│   │   │   ├── create/
│   │   │   │   └── page.tsx            # Create cohort (/admin/cohorts/create)
│   │   │   └── [id]/
│   │   │       ├── page.tsx            # Edit cohort (/admin/cohorts/123)
│   │   │       ├── enrollments/
│   │   │       │   └── page.tsx        # Manage enrollments
│   │   │       └── waitlist/
│   │   │           └── page.tsx        # Waitlist management
│   │   ├── enrollments/
│   │   │   ├── page.tsx                # Enrollment management (/admin/enrollments)
│   │   │   └── [id]/
│   │   │       └── page.tsx            # Enrollment detail (/admin/enrollments/456)
│   │   ├── organizations/
│   │   │   ├── page.tsx                # Organization management (/admin/organizations)
│   │   │   ├── create/
│   │   │   │   └── page.tsx            # Create organization
│   │   │   └── [id]/
│   │   │       ├── page.tsx            # Edit organization (/admin/organizations/789)
│   │   │       ├── team/
│   │   │       │   └── page.tsx        # Team member management
│   │   │       └── reports/
│   │   │           └── page.tsx        # Executive reports
│   │   └── analytics/
│   │       ├── page.tsx                # Analytics dashboard (/admin/analytics)
│   │       ├── revenue/
│   │       │   └── page.tsx            # Revenue analytics
│   │       └── engagement/
│   │           └── page.tsx            # Engagement metrics
│
├── (organization)/                     # Organization admin (role: org_admin)
│   ├── layout.tsx                      # Org layout (org sidebar)
│   ├── org/
│   │   ├── dashboard/
│   │   │   └── page.tsx                # Org overview (/org/dashboard)
│   │   ├── team/
│   │   │   ├── page.tsx                # Team management (/org/team)
│   │   │   └── invite/
│   │   │       └── page.tsx            # Invite team members (/org/team/invite)
│   │   └── reports/
│   │       └── page.tsx                # Executive reports (/org/reports)
│
└── api/                                # API routes
    ├── webhooks/
    │   ├── stripe/
    │   │   └── route.ts                # Stripe webhook handler
    │   ├── cal/
    │   │   └── route.ts                # Cal.com webhook handler
    │   └── formbricks/
    │       └── route.ts                # Formbricks webhook handler
    ├── admin/
    │   └── [...]/route.ts              # Admin API endpoints (protected)
    └── public/
        └── [...]/route.ts              # Public API endpoints

components/
├── ui/                                 # shadcn/ui primitives
│   ├── button.tsx
│   ├── card.tsx
│   ├── dialog.tsx
│   ├── input.tsx
│   └── ...
├── marketing/                          # Marketing components
│   ├── Hero.tsx
│   ├── CourseCard.tsx
│   ├── PricingTable.tsx
│   └── Testimonials.tsx
├── dashboard/                          # Dashboard components
│   ├── Sidebar.tsx
│   ├── CohortCard.tsx
│   ├── SessionCard.tsx
│   ├── ChatInterface.tsx
│   └── CertificateBadge.tsx
└── admin/                              # Admin components
    ├── DataTable.tsx
    ├── CourseEditor.tsx
    ├── CohortEditor.tsx
    └── AnalyticsChart.tsx
```

## 3.4 Auth Boundaries

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           AUTHENTICATION ZONES                                │
└──────────────────────────────────────────────────────────────────────────────┘

PUBLIC ROUTES (No authentication required)
┌────────────────────────────────────────────────────────────────────────────┐
│ Route Pattern              │ Purpose                │ Data Access          │
├────────────────────────────┼────────────────────────┼─────────────────────┤
│ /                          │ Homepage               │ Published courses    │
│ /courses                   │ Course catalog         │ Published courses    │
│ /courses/[slug]            │ Course detail page     │ Single course (pub)  │
│ /pricing                   │ Pricing page           │ Pricing plans        │
│ /about                     │ About page             │ Static content       │
│ /contact                   │ Contact form           │ None (form submit)   │
│ /api/webhooks/*            │ Webhook receivers      │ Validated payloads   │
└────────────────────────────────────────────────────────────────────────────┘

AUTHENTICATED ROUTES (Valid session required)
┌────────────────────────────────────────────────────────────────────────────┐
│ Route Pattern              │ Auth Check             │ Data Access          │
├────────────────────────────┼────────────────────────┼─────────────────────┤
│ /portal                    │ ctx.auth.userId        │ User enrollments     │
│ /cohorts/[id]              │ ctx.auth.userId +      │ Cohort where user    │
│                            │ enrollment.verify      │ is enrolled          │
│ /cohorts/[id]/sessions/*   │ Same as above          │ Session data         │
│ /office-hours              │ ctx.auth.userId        │ User bookings        │
│ /office-hours/[bookingId]  │ ctx.auth.userId +      │ Specific booking     │
│                            │ booking.userId = ctx   │                      │
│ /chatbot                   │ ctx.auth.userId        │ User conversations   │
│ /certificates              │ ctx.auth.userId        │ User certificates    │
│ /profile                   │ ctx.auth.userId        │ User profile         │
└────────────────────────────────────────────────────────────────────────────┘

ADMIN ROUTES (Role: platform_admin)
┌────────────────────────────────────────────────────────────────────────────┐
│ Route Pattern              │ Auth Check             │ Data Access          │
├────────────────────────────┼────────────────────────┼─────────────────────┤
│ /admin/*                   │ ctx.auth.userId +      │ ALL platform data    │
│                            │ user.role =            │ (unrestricted)       │
│                            │ "platform_admin"       │                      │
│ /api/admin/*               │ Same as above          │ Admin mutations      │
└────────────────────────────────────────────────────────────────────────────┘

ORG_ADMIN ROUTES (Role: org_admin)
┌────────────────────────────────────────────────────────────────────────────┐
│ Route Pattern              │ Auth Check             │ Data Access          │
├────────────────────────────┼────────────────────────┼─────────────────────┤
│ /org/dashboard             │ ctx.auth.userId +      │ Organization data    │
│                            │ user.role =            │ (scoped to org)      │
│                            │ "org_admin" +          │                      │
│                            │ user.organizationId    │                      │
│ /org/team                  │ Same as above          │ Org team members     │
│ /org/team/invite           │ Same as above          │ Org invites          │
│ /org/reports               │ Same as above          │ Org exec reports     │
└────────────────────────────────────────────────────────────────────────────┘

CONVEX AUTH MIDDLEWARE PATTERN:
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  export const myQuery = query({                                             │
│    args: { cohortId: v.id("cohorts") },                                    │
│    handler: async (ctx, args) => {                                         │
│      // 1. Check if authenticated                                          │
│      const userId = await ctx.auth.getUserIdentity();                      │
│      if (!userId) throw new Error("Not authenticated");                    │
│                                                                              │
│      // 2. Get user record                                                 │
│      const user = await ctx.db                                             │
│        .query("users")                                                      │
│        .withIndex("by_clerk_id", (q) => q.eq("clerkId", userId.subject))  │
│        .unique();                                                           │
│                                                                              │
│      // 3. Check role (if admin route)                                     │
│      if (user?.role !== "platform_admin") {                                │
│        throw new Error("Unauthorized: Admin only");                        │
│      }                                                                      │
│                                                                              │
│      // 4. Check resource ownership (if user route)                        │
│      const enrollment = await ctx.db                                       │
│        .query("enrollments")                                               │
│        .withIndex("by_user_cohort", (q) =>                                 │
│          q.eq("userId", user._id).eq("cohortId", args.cohortId))          │
│        .unique();                                                           │
│                                                                              │
│      if (!enrollment) {                                                    │
│        throw new Error("Not enrolled in this cohort");                     │
│      }                                                                      │
│                                                                              │
│      // 5. Return authorized data                                          │
│      return ctx.db.get(args.cohortId);                                     │
│    },                                                                       │
│  });                                                                        │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

ROLE HIERARCHY:
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  platform_admin  ──→  Full access to everything (platform operations)      │
│       │                                                                      │
│       ├──→ Can manage all courses, cohorts, users, organizations           │
│       ├──→ Can view all analytics and reports                              │
│       └──→ Can configure platform settings                                 │
│                                                                              │
│  org_admin  ──→  Organization-scoped admin (team management)                │
│       │                                                                      │
│       ├──→ Can invite/remove team members                                  │
│       ├──→ Can view organization reports                                   │
│       ├──→ Can manage seat allocation                                      │
│       └──→ Cannot access other organizations' data                         │
│                                                                              │
│  user  ──→  Standard learner (enrolled courses only)                        │
│       │                                                                      │
│       ├──→ Can view enrolled cohorts                                       │
│       ├──→ Can book office hours                                           │
│       ├──→ Can access chatbot                                              │
│       └──→ Cannot access admin or org_admin routes                         │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘
```

## 3.5 Integration Points Table

| Integration | Direction | Protocol | Trigger | Auth Method | Purpose |
|-------------|-----------|----------|---------|-------------|---------|
| **Stripe → Convex** | Inbound | Webhook (HTTPS POST) | `checkout.session.completed`<br>`checkout.session.expired`<br>`customer.subscription.updated`<br>`customer.subscription.deleted` | Webhook Signature (stripe.webhooks.constructEvent) | Payment processing, enrollment activation, subscription management |
| **Convex → Stripe** | Outbound | Stripe SDK (REST) | Checkout session creation, subscription management | API Key (Secret Key) | Create checkout sessions, manage subscriptions, issue refunds |
| **Convex → Brevo** | Outbound | Brevo SDK (REST) | Enrollment confirmation, pre-session reminders, recording availability, milestone emails, surveys | API Key (Header: `api-key`) | Transactional emails, marketing automation, contact management |
| **Brevo → Convex** | Inbound | Webhook (HTTPS POST) | Email delivery events (`opened`, `clicked`, `bounced`, `unsubscribed`) | Webhook Signature (optional) | Track email engagement, update user preferences |
| **Cal.com → Convex** | Inbound | Webhook (HTTPS POST) | `booking.created`<br>`booking.cancelled`<br>`booking.rescheduled` | Webhook Signature (HMAC SHA256) | Office hours booking confirmation, calendar sync |
| **Convex → Cal.com** | Outbound | Cal.com API (REST) | Availability check, booking creation (admin) | API Key (Header: `Authorization: Bearer`) | Check instructor availability, create admin bookings |
| **Formbricks → Convex** | Inbound | Webhook (HTTPS POST) | Survey response submission (`response.created`, `response.updated`) | Webhook Signature (HMAC SHA256) | Collect NPS/CSAT feedback, trigger follow-up actions |
| **Convex → PostHog** | Outbound | PostHog SDK (client-side) | User actions (`enrollment_completed`, `session_viewed`, `certificate_earned`) | Project API Key (client-side public key) | Product analytics, feature flags, A/B testing |
| **Next.js → OpenRouter** | Outbound | OpenRouter SDK (REST) | Chat message submission (`/chat/completions`) | API Key (Header: `Authorization: Bearer`) | AI chatbot conversations, course Q&A |
| **Platform → External Webhooks** | Outbound | HTTPS POST (JSON) | Platform events (`enrollment.created`, `cohort.completed`, `certificate.issued`) | HMAC Signature (SHA256) | Third-party integrations (CRM, Slack, Zapier) |
| **Convex → Vercel Blob Storage** | Outbound | Vercel SDK (REST) | File uploads (avatars, certificates, recordings) | Vercel Token (Header: `Authorization: Bearer`) | Persistent file storage, CDN delivery |
| **Clerk → Convex** | Inbound | Webhook (HTTPS POST) | `user.created`<br>`user.updated`<br>`user.deleted` | Webhook Signature (svix) | User authentication sync, profile updates |

### Integration Security Details

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      WEBHOOK SIGNATURE VERIFICATION                           │
└──────────────────────────────────────────────────────────────────────────────┘

STRIPE WEBHOOK VERIFICATION:
  const sig = request.headers.get("stripe-signature");
  const event = stripe.webhooks.constructEvent(
    rawBody,
    sig,
    process.env.STRIPE_WEBHOOK_SECRET
  );
  // Throws error if signature invalid

CAL.COM WEBHOOK VERIFICATION:
  const signature = request.headers.get("x-cal-signature-256");
  const hash = crypto
    .createHmac("sha256", process.env.CAL_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  if (signature !== hash) throw new Error("Invalid signature");

FORMBRICKS WEBHOOK VERIFICATION:
  const signature = request.headers.get("x-formbricks-signature");
  const hash = crypto
    .createHmac("sha256", process.env.FORMBRICKS_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  if (signature !== `sha256=${hash}`) throw new Error("Invalid signature");

CLERK WEBHOOK VERIFICATION (Svix):
  import { Webhook } from "svix";
  const wh = new Webhook(process.env.CLERK_WEBHOOK_SECRET);
  const evt = wh.verify(rawBody, headers);
  // Throws error if signature invalid

PLATFORM OUTBOUND WEBHOOK SIGNING:
  const signature = crypto
    .createHmac("sha256", webhookConfig.secret)
    .update(JSON.stringify(payload))
    .digest("hex");
  headers["X-Platform-Signature"] = `sha256=${signature}`;
```

### API Rate Limits & Quotas

| Service | Rate Limit | Quota | Handling |
|---------|------------|-------|----------|
| Stripe API | 100 req/sec per account | Unlimited events | Exponential backoff on 429 |
| Brevo API | 300 emails/min (Lite plan) | 40,000 emails/month | Queue emails, batch send |
| PostHog API | No hard limit | Unlimited events (free tier) | Client-side batching |
| OpenRouter | Model-dependent | Pay-per-token | Token usage tracking, user limits |
| Cal.com API | 1000 req/hour | Unlimited bookings | Cache availability data |
| Formbricks API | No hard limit | Unlimited responses | N/A |

## 3.6 Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          DATABASE SCHEMA (CONVEX)                             │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│     users       │
├─────────────────┤
│ _id             │───────────┐
│ _creationTime   │           │
│ clerkId         │  (unique) │
│ email           │           │
│ name            │           │
│ avatarUrl       │           │
│ role            │           │ (enum: user | org_admin | platform_admin)
│ organizationId? │──────┐    │
│ timezone        │      │    │
│ preferences     │      │    │
└─────────────────┘      │    │
         │               │    │
         │ 1             │    │
         │               │    │
         ∞               │    │
┌─────────────────┐      │    │
│  enrollments    │      │    │
├─────────────────┤      │    │
│ _id             │      │    │
│ userId          │←─────┘    │
│ cohortId        │───────┐   │
│ status          │       │   │ (enum: pending | active | completed | cancelled)
│ progress        │       │   │
│ stripeCheckoutId│       │   │
│ stripeSessionId │       │   │
│ paymentStatus   │       │   │
│ enrolledAt      │       │   │
│ completedAt?    │       │   │
└─────────────────┘       │   │
         │                │   │
         │ 1              │   │
         │                ∞   │
         ∞          ┌─────────────────┐
┌─────────────────┐ │    cohorts      │
│  certificates   │ ├─────────────────┤
├─────────────────┤ │ _id             │
│ _id             │ │ courseId        │───────┐
│ enrollmentId    │─│ name            │       │
│ userId          │ │ slug            │       │
│ cohortId        │─│ startDate       │       │
│ imageUrl        │ │ endDate         │       │
│ issuedAt        │ │ timezone        │       │
│ verificationCode│ │ capacity        │       │
│ linkedinUrl     │ │ seatsAvailable  │       │
│ twitterUrl      │ │ status          │       │ (enum: draft | open | full | active | completed)
└─────────────────┘ │ pricing         │       │
                    │ slackInviteUrl  │       │
┌─────────────────┐ │ zoomMeetingId   │       │
│chatConversations│ └─────────────────┘       │
├─────────────────┤          │                │
│ _id             │          │ 1              │
│ userId          │───┘      │                │
│ title           │          ∞                │
│ createdAt       │ ┌─────────────────┐       │
└─────────────────┘ │    sessions     │       │
         │          ├─────────────────┤       │
         │ 1        │ _id             │       │
         │          │ cohortId        │───────┘
         ∞          │ title           │
┌─────────────────┐ │ description     │
│  chatMessages   │ │ sessionNumber   │
├─────────────────┤ │ startTime       │
│ _id             │ │ endTime         │
│ conversationId  │─│ type            │ (enum: live | recording | hybrid)
│ role            │ │ zoomLink        │
│ content         │ │ recordingUrl?   │
│ timestamp       │ │ slidesUrl?      │
│ tokens          │ │ transcriptUrl?  │
└─────────────────┘ │ preworkUrl?     │
                    │ status          │ (enum: scheduled | live | completed | cancelled)
                    └─────────────────┘
                             │
                             │ 1
                             │
                             ∞
                    ┌─────────────────┐
                    │sessionRecordings│
                    ├─────────────────┤
                    │ _id             │
                    │ sessionId       │───┘
                    │ cohortId        │
                    │ recordingUrl    │
                    │ thumbnailUrl    │
                    │ duration        │
                    │ uploadedAt      │
                    │ viewCount       │
                    └─────────────────┘

┌─────────────────┐          ┌─────────────────┐
│    courses      │          │ organizations   │
├─────────────────┤          ├─────────────────┤
│ _id             │←─────┘   │ _id             │←───┘
│ name            │          │ name            │
│ slug            │ (unique) │ domain          │
│ tagline         │          │ seatsPurchased  │
│ description     │          │ seatsUsed       │
│ duration        │          │ expiresAt?      │
│ deliveryFormat  │          │ contactEmail    │
│ outcomes        │ (array)  │ billingEmail    │
│ prerequisites   │ (array)  │ stripeCustomerId│
│ status          │          │ status          │ (enum: active | suspended | expired)
│ thumbnailUrl    │          │ createdAt       │
│ pricing         │          └─────────────────┘
│ createdAt       │                   │
└─────────────────┘                   │ 1
         │                            │
         │ 1                          ∞
         │                   ┌─────────────────┐
         ∞                   │organizationInvites│
┌─────────────────┐          ├─────────────────┤
│enablementKitItems│         │ _id             │
├─────────────────┤          │ organizationId  │───┘
│ _id             │          │ email           │
│ courseId        │───┘      │ role            │ (enum: user | org_admin)
│ title           │          │ token           │ (unique)
│ description     │          │ status          │ (enum: pending | accepted | expired)
│ type            │          │ invitedBy       │
│ fileUrl?        │          │ invitedAt       │
│ linkUrl?        │          │ acceptedAt?     │
│ order           │          └─────────────────┘
└─────────────────┘

┌─────────────────┐
│    waitlist     │
├─────────────────┤
│ _id             │
│ email           │
│ cohortId        │───┐
│ position        │   │
│ notified        │   │
│ addedAt         │   │
└─────────────────┘   │
                      │
                      └─→ (references cohorts._id)

┌─────────────────┐
│officeHoursBookings│
├─────────────────┤
│ _id             │
│ userId          │───┐
│ enrollmentId    │───│─→ (references enrollments._id)
│ calEventId      │   │
│ instructorName  │   │
│ scheduledAt     │   │
│ duration        │   │
│ meetingUrl      │   │
│ agenda?         │   │
│ status          │   │ (enum: scheduled | completed | cancelled | no_show)
│ createdAt       │   │
│ updatedAt       │   │
└─────────────────┘   │
                      │
                      └─→ (references users._id)

┌─────────────────┐
│executiveReports │
├─────────────────┤
│ _id             │
│ organizationId  │───┐
│ reportDate      │   │
│ totalEnrollments│   │
│ activeUsers     │   │
│ completionRate  │   │
│ avgProgress     │   │
│ topCourses      │ (array)
│ engagementScore │   │
│ generatedAt     │   │
└─────────────────┘   │
                      │
                      └─→ (references organizations._id)

┌────────────────────────────────────────────────────────────────────────────┐
│                            INDEX STRATEGY                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ users:                                                                      │
│   • by_clerk_id (clerkId) - Fast auth lookups                              │
│   • by_email (email) - User search                                         │
│   • by_organization (organizationId) - Org member queries                  │
│                                                                              │
│ enrollments:                                                                │
│   • by_user (userId) - User dashboard queries                              │
│   • by_cohort (cohortId) - Cohort roster queries                           │
│   • by_user_cohort (userId, cohortId) - Access checks                      │
│   • by_status (status, enrolledAt) - Active enrollment queries             │
│                                                                              │
│ cohorts:                                                                    │
│   • by_course (courseId, startDate) - Course cohort listings               │
│   • by_status (status) - Active cohort queries                             │
│   • by_slug (slug) - URL routing                                           │
│                                                                              │
│ sessions:                                                                   │
│   • by_cohort (cohortId, sessionNumber) - Cohort session listings          │
│   • by_start_time (startTime) - Upcoming session queries                   │
│                                                                              │
│ chatConversations:                                                          │
│   • by_user (userId, createdAt) - User chat history                        │
│                                                                              │
│ chatMessages:                                                               │
│   • by_conversation (conversationId, timestamp) - Chat thread queries      │
│                                                                              │
│ organizationInvites:                                                        │
│   • by_organization (organizationId, status) - Org invite management       │
│   • by_token (token) - Invite redemption                                   │
│   • by_email (email) - Duplicate invite prevention                         │
│                                                                              │
│ officeHoursBookings:                                                        │
│   • by_user (userId, scheduledAt) - User booking history                   │
│   • by_enrollment (enrollmentId) - Cohort booking queries                  │
│   • by_cal_event (calEventId) - Webhook event matching                     │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

RELATIONSHIPS SUMMARY:

1:∞ users → enrollments (one user, many enrollments)
1:∞ cohorts → enrollments (one cohort, many enrollments)
1:1 enrollments → certificates (one enrollment, one certificate)
1:∞ users → chatConversations (one user, many conversations)
1:∞ chatConversations → chatMessages (one conversation, many messages)
1:∞ courses → cohorts (one course, many cohorts)
1:∞ cohorts → sessions (one cohort, many sessions)
1:∞ sessions → sessionRecordings (one session, many recordings)
1:∞ courses → enablementKitItems (one course, many kit items)
1:∞ organizations → users (one org, many users)
1:∞ organizations → organizationInvites (one org, many invites)
1:∞ organizations → executiveReports (one org, many reports)
1:∞ cohorts → waitlist (one cohort, many waitlist entries)
1:∞ users → officeHoursBookings (one user, many bookings)
1:∞ enrollments → officeHoursBookings (one enrollment, many bookings)
```

---

## Architecture Decision Records (ADRs)

### ADR-001: Why Convex over Supabase/Firebase?
**Decision**: Use Convex as the backend database and API layer.

**Rationale**:
- **Real-time by default**: Reactive queries eliminate websocket setup
- **Type-safe**: End-to-end TypeScript from database to UI
- **Serverless**: Zero infrastructure management, auto-scaling
- **Developer experience**: Query/mutation pattern simpler than REST/GraphQL
- **File storage**: Built-in file storage (no S3 setup needed)
- **Scheduled functions**: Native cron jobs for email automation

**Trade-offs**:
- Vendor lock-in (migration requires full rewrite)
- Smaller ecosystem vs. Supabase/Firebase
- No SQL interface (document-based only)

### ADR-002: Why Next.js App Router over Pages Router?
**Decision**: Use Next.js 15 with App Router (not Pages Router).

**Rationale**:
- **Server Components**: Reduced client bundle size (critical for marketing pages)
- **Server Actions**: Simpler form handling without API routes
- **Layouts**: Shared layouts (marketing vs. dashboard) without workarounds
- **Streaming**: Progressive rendering for better perceived performance
- **Route Groups**: Clean separation of (marketing), (auth), (dashboard), (admin)

**Trade-offs**:
- Steeper learning curve for developers unfamiliar with React Server Components
- Less mature ecosystem (fewer examples vs. Pages Router)

### ADR-003: Why shadcn/ui over Material-UI/Chakra?
**Decision**: Use shadcn/ui as the component library.

**Rationale**:
- **No runtime overhead**: Components copied into codebase (not imported from package)
- **Full customization**: Tailwind-based styling allows complete design control
- **Accessibility**: Built on Radix UI primitives (WAI-ARIA compliant)
- **Tree-shaking**: Only ship components you use
- **TypeScript-first**: Excellent type safety

**Trade-offs**:
- More setup required (copy/paste vs. npm install)
- Smaller component library vs. Material-UI
- Manual updates (not automatic package updates)

### ADR-004: Why Stripe over PayPal/Square?
**Decision**: Use Stripe for payment processing.

**Rationale**:
- **Subscription management**: Native support for recurring billing (B2B retainers)
- **Webhook reliability**: Industry-leading webhook delivery guarantees
- **Developer experience**: Excellent documentation, test mode, CLI tools
- **Global support**: Multi-currency, localized payment methods
- **Compliance**: PCI DSS Level 1 certified, handles all security

**Trade-offs**:
- 2.9% + $0.30 per transaction (higher than some alternatives)
- Complex API for advanced use cases
- Strong vendor lock-in

### ADR-005: Why Brevo over SendGrid/Mailgun?
**Decision**: Use Brevo (formerly Sendinblue) for transactional and marketing emails.

**Rationale**:
- **Generous free tier**: 300 emails/day (9000/month) for free
- **Marketing + transactional**: Unified platform (no separate tools)
- **Template builder**: Visual email editor (non-developers can create templates)
- **Contact management**: Built-in CRM for lead nurturing
- **SMTP relay**: Fallback option if API is down

**Trade-offs**:
- Smaller ecosystem vs. SendGrid
- Less advanced automation vs. enterprise tools (Marketo, HubSpot)

## 3.7 Real-Time & File Flow Patterns

### 3.7.1 Real-Time Enrollment Count Updates

```
Browser A (Course Page)     Browser B (Course Page)     Convex
       │                           │                      │
       │ useQuery(cohorts.get)     │                      │
       ├────────────────────────────────────────────────→ │
       │                           │                      │
       │ Subscribe to cohort       │ Subscribe            │
       │<──────────────────────────┼─────────────────────→│
       │                           │                      │
       │                    Browser C enrolls (Stripe)    │
       │                           │                      │
       │                           │    cohort.patch({    │
       │                           │      currentEnroll++ │
       │                           │    })                │
       │                           │                      │
       │ Push update (WebSocket)   │ Push update          │
       │<──────────────────────────┼←────────────────────│
       │ "19/20 spots"             │ "19/20 spots"        │
```

### 3.7.2 Office Hours Booking Flow (Cal.com)

```
Learner          Next.js           Cal.com        Convex Webhook
   │                │                  │                │
   │ Click "Book    │                  │                │
   │ Office Hours"  │                  │                │
   ├───────────────→│                  │                │
   │                │ Check eligibility│                │
   │                ├─────────────────────────────────→ │
   │                │<─────────────────────────────────┤
   │                │ officeHoursUntil > now?          │
   │                │                  │                │
   │                │ Embed Cal widget │                │
   │<───────────────┤ (metadata: user, │                │
   │                │  enrollmentId)   │                │
   │                │                  │                │
   │ Select time    │                  │                │
   ├────────────────────────────────→  │                │
   │                │      BOOKING_    │                │
   │                │      CREATED     │                │
   │                │                  ├───────────────→│
   │                │                  │ Create booking │
   │                │                  │ record         │
   │<────────────────────────────────  │                │
   │ Confirmation   │                  │                │
```

### 3.7.3 File Upload Flow (Admin → Enablement Kit)

```
Admin           Next.js          Convex Storage
  │                │                  │
  │ Select file    │                  │
  │ (PDF, 5MB)     │                  │
  ├───────────────→│                  │
  │                │ generateUploadUrl│
  │                ├─────────────────→│
  │                │<─────────────────┤
  │                │ Signed URL (1hr) │
  │                │                  │
  │ Upload direct  │                  │
  │ to signed URL  ├─────────────────→│
  │                │                  │
  │                │<─────────────────┤
  │                │ storageId        │
  │                │                  │
  │                │ saveEnablementKit│
  │                │ Item({storageId})│
  │                ├─────────────────→│
  │<───────────────┤                  │
  │ Upload complete│                  │
```

### 3.7.4 Certificate Download Flow

```
Learner          Next.js          Convex Storage
  │                │                  │
  │ Click Download │                  │
  │ Certificate    │                  │
  ├───────────────→│                  │
  │                │ Verify ownership │
  │                │ (enrollment.user │
  │                │  = current user) │
  │                ├─────────────────→│
  │                │<─────────────────┤
  │                │ pdfId (storageId)│
  │                │                  │
  │                │ getFileUrl(pdfId)│
  │                ├─────────────────→│
  │                │<─────────────────┤
  │                │ Signed URL (15m) │
  │<───────────────┤                  │
  │ Redirect to    │                  │
  │ download       │                  │
```

## 3.8 Lighthouse Performance Requirements

### Target Scores (All Pages)
| Category | Target | Minimum |
|----------|--------|---------|
| Performance | 100 | 90 |
| Accessibility | 100 | 100 |
| Best Practices | 100 | 95 |
| SEO | 100 | 95 |

### Core Web Vitals Targets
| Metric | Target | Maximum |
|--------|--------|---------|
| LCP (Largest Contentful Paint) | <1.5s | <2.5s |
| INP (Interaction to Next Paint) | <100ms | <200ms |
| CLS (Cumulative Layout Shift) | <0.05 | <0.1 |
| FCP (First Contentful Paint) | <1.0s | <1.8s |
| TTFB (Time to First Byte) | <200ms | <600ms |

### Implementation Requirements
1. **Next.js Optimizations**:
   - Use `next/image` for all images
   - Use `next/font` for font optimization
   - Enable static generation where possible
   - Implement ISR for dynamic content

2. **Bundle Optimization**:
   - Code splitting per route
   - Dynamic imports for heavy components
   - Tree shaking enabled
   - No unused dependencies

3. **Caching Strategy**:
   - Static assets: 1 year cache
   - API responses: SWR pattern
   - Service worker for offline support

4. **Monitoring**:
   - Vercel Analytics for real-user metrics
   - Lighthouse CI in GitHub Actions
   - Performance budgets enforced

### CI/CD Integration
```yaml
# Run Lighthouse CI on every PR
- name: Lighthouse CI
  run: lhci autorun
  env:
    LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

## 3.9 WCAG 2.2 Level AA Accessibility Requirements

### Compliance Target
- **Standard**: WCAG 2.2 Level AA
- **Audit Frequency**: Before each major release
- **Tools**: axe-core, WAVE, manual testing with screen readers

### Perceivable (1.x)
1. **Text Alternatives (1.1)**: All images have descriptive alt text
2. **Time-Based Media (1.2)**: Captions for videos, transcripts for audio
3. **Adaptable (1.3)**: Semantic HTML, proper heading hierarchy, landmarks
4. **Distinguishable (1.4)**:
   - Color contrast: 4.5:1 for text, 3:1 for large text
   - Text resizable to 200% without loss
   - No images of text
   - Reflow at 320px width

### Operable (2.x)
1. **Keyboard Accessible (2.1)**: All functionality via keyboard
2. **Enough Time (2.2)**: Adjustable timeouts, pause/stop animations
3. **Seizures (2.3)**: No flashing content >3 times/second
4. **Navigable (2.4)**:
   - Skip links
   - Descriptive page titles
   - Focus order logical
   - Link purpose clear
   - Multiple ways to find pages
5. **Input Modalities (2.5)**: Touch targets min 24x24px (44x44px preferred)

### Understandable (3.x)
1. **Readable (3.1)**: Language declared, abbreviations explained
2. **Predictable (3.2)**: Consistent navigation, no unexpected context changes
3. **Input Assistance (3.3)**:
   - Error identification
   - Labels for inputs
   - Error suggestions
   - Error prevention for important actions

### Robust (4.x)
1. **Compatible (4.1)**: Valid HTML, ARIA used correctly, status messages announced

### Testing Requirements
1. **Automated**: axe-core in Jest tests, CI pipeline checks
2. **Manual**: Screen reader testing (NVDA, VoiceOver, JAWS)
3. **User Testing**: Include users with disabilities in usability testing

### Component Library (shadcn/ui)
- All shadcn/ui components are built on Radix UI primitives
- Radix provides WCAG-compliant keyboard navigation and ARIA
- Custom components MUST follow same patterns

### Implementation Checklist
- [ ] Skip link to main content
- [ ] Proper heading hierarchy (h1 → h2 → h3)
- [ ] Form labels associated with inputs
- [ ] Error messages linked to fields
- [ ] Focus indicators visible (2px solid outline)
- [ ] Color not sole indicator of meaning
- [ ] Touch targets minimum 44x44px
- [ ] Reduced motion support (@media prefers-reduced-motion)


## 3.10 Mobile Optimization & Responsive Design

### Design Philosophy
- **Mobile-First Approach**: Design for mobile screens first, then enhance for larger viewports
- **Progressive Enhancement**: Core functionality works on all devices, enhanced features for capable devices
- **Touch-First Interactions**: All interactive elements sized for touch (min 44x44px tap targets)

### Breakpoints (Tailwind CSS)
```
sm: 640px   // Mobile landscape
md: 768px   // Tablets
lg: 1024px  // Desktop
xl: 1280px  // Large desktop
2xl: 1536px // Extra large
```

### Mobile Requirements

#### 1. Viewport & Layout
- **Meta Viewport**: `<meta name="viewport" content="width=device-width, initial-scale=1">`
- **No Horizontal Scroll**: Content must fit within viewport width
- **Safe Areas**: Respect iOS notch and Android navigation bars (use `safe-area-inset-*`)
- **Orientation Support**: Graceful handling of landscape mode

#### 2. Typography
- **Base Font Size**: Minimum 16px to prevent iOS zoom on input focus
- **Scalable Text**: Use `rem` units (not `px`) for accessibility
- **Line Height**: 1.5-1.6 for body text on mobile
- **Contrast Ratio**: WCAG AA minimum (4.5:1 for normal text, 3:1 for large text)

#### 3. Images & Media
- **Responsive Images**: Use `srcset` and `sizes` attributes
- **Modern Formats**: WebP with JPEG fallback, AVIF for hero images
- **Lazy Loading**: `loading="lazy"` for below-the-fold images
- **Aspect Ratio**: Use `aspect-ratio` CSS to prevent layout shifts
- **Compression**: ImageOptim/TinyPNG for 60-80% size reduction
- **CDN Delivery**: Vercel Image Optimization (`next/image`)

#### 4. Navigation
- **Mobile Menu**: Hamburger icon (☰) for primary navigation
- **Bottom Navigation**: Key actions (Dashboard, Courses, Profile) for thumb reach
- **Sticky Header**: Fixed top bar with logo and menu toggle
- **Breadcrumbs**: Simplified on mobile (show only current + parent)
- **Back Button**: Browser back should work (avoid hijacking)

#### 5. Forms
- **Large Input Fields**: Minimum 44px height for touch targets
- **Proper Input Types**: `email`, `tel`, `url`, `number` for native keyboards
- **Autocomplete**: Use `autocomplete` attributes (`email`, `name`, `cc-number`)
- **Error Messages**: Inline validation, clear error states
- **Submit Buttons**: Full-width on mobile, prominent CTA color
- **Focus States**: Visible focus indicators (not just `:hover`)

#### 6. Tables
- **Horizontal Scroll**: Wrap tables in `overflow-x-auto` container
- **Card View**: Convert to stacked cards on mobile (<768px)
- **Essential Columns**: Show only critical columns on mobile
- **Expandable Rows**: Hide details in expandable rows (accordion pattern)

#### 7. Modals & Dialogs
- **Full-Screen on Mobile**: Dialogs take full viewport height on mobile
- **Dismissible**: Swipe down to close (in addition to X button)
- **Scroll Lock**: Prevent body scroll when modal open
- **Focus Trap**: Tab navigation stays within modal

#### 8. Touch Interactions
- **Swipe Gestures**: Carousel navigation, dismiss modals, swipe-to-delete
- **Pull-to-Refresh**: Native behavior on lists (iOS/Android)
- **Long Press**: Context menus on cards (use `contextmenu` event)
- **No Hover-Only**: All interactions must work without hover state
- **Tap Delay**: Use `touch-action: manipulation` to eliminate 300ms delay

#### 9. Performance on Mobile

**Target Metrics (3G Connection):**
- First Contentful Paint (FCP): <3s
- Largest Contentful Paint (LCP): <4s
- Time to Interactive (TTI): <5s
- Cumulative Layout Shift (CLS): <0.1

**Optimization Strategies:**
- **Bundle Size**: Initial JS <200KB (gzipped), code splitting for admin/dashboard
- **Images**: 60-80% compression, responsive srcset, lazy loading, WebP/JPEG
- **Fonts**: System fonts or subset web fonts (<30KB WOFF2), font-display: swap
- **Critical CSS**: Inline above-the-fold CSS, defer non-critical stylesheets
- **Service Worker**: Cache static assets, offline fallback, stale-while-revalidate

#### 10. Testing Checklist
- **Devices**: iPhone 12/13/14, Samsung Galaxy S21/S22, iPad, Android tablet
- **Browsers**: Safari (iOS), Chrome (Android), Firefox Mobile, Samsung Internet
- **Networks**: 4G, 3G throttle, offline mode
- **Accessibility**: Screen readers (VoiceOver/TalkBack), keyboard nav, 200% zoom

### Mobile-First Component Examples

#### Responsive Course Card
```tsx
<Card className="flex flex-col gap-3 p-4 md:flex-row md:gap-6 md:p-6 lg:gap-8">
  <img
    src={course.thumbnailUrl}
    alt={course.name}
    className="w-full h-48 object-cover rounded md:w-64 md:h-auto lg:w-80"
  />
  <div className="flex-1">
    <h3 className="text-lg md:text-xl lg:text-2xl font-bold">{course.name}</h3>
    <p className="text-sm md:text-base text-gray-600 mt-2">{course.tagline}</p>
  </div>
</Card>
```

#### Touch-Optimized Enrollment Button
```tsx
<button className="w-full h-14 px-6 text-lg font-semibold rounded-lg bg-primary text-white active:scale-95 transition-transform disabled:opacity-50 md:w-auto md:h-12">
  Enroll Now - $1,495
</button>
```

### Responsive Design System (Tailwind Config)

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      spacing: {
        "safe-top": "env(safe-area-inset-top)",
        "safe-bottom": "env(safe-area-inset-bottom)",
        "safe-left": "env(safe-area-inset-left)",
        "safe-right": "env(safe-area-inset-right)",
      },
      minHeight: {
        touch: "44px", // iOS minimum touch target
      },
      fontSize: {
        "mobile-base": "16px", // Prevent iOS zoom
      }
    }
  }
}
```

**Mobile Optimization Priority:**
1. **Critical Path**: Homepage, Course Detail, Enrollment Flow
2. **High Priority**: Dashboard, Cohort View, Payment
3. **Medium Priority**: Admin pages, Analytics
4. **Low Priority**: Org Admin (primarily desktop users)

## 3.11 CMS Architecture

### 3.11.1 CMS Route Structure

```
app/
├── (admin)/
│   └── admin/
│       └── content/                     # CMS Management Area
│           ├── page.tsx                  # Content dashboard (/admin/content)
│           │                             # Overview: posts, pages, media stats
│           │                             # Quick actions: New Post, New Page
│           │
│           ├── posts/                    # Blog Post Management
│           │   ├── page.tsx              # Post list (/admin/content/posts)
│           │   │                         # Table: title, author, status, updated
│           │   │                         # Filters: draft/published, search
│           │   │
│           │   ├── new/
│           │   │   └── page.tsx          # New post (/admin/content/posts/new)
│           │   │                         # BlockNote editor for rich content
│           │   │                         # SEO fields: slug, meta description
│           │   │                         # Featured image picker
│           │   │                         # Tags & categories
│           │   │
│           │   └── [id]/
│           │       ├── page.tsx          # Edit post (/admin/content/posts/[id])
│           │       │                     # Same as new post, pre-populated
│           │       │                     # Version history sidebar
│           │       │                     # Collaborator presence indicators
│           │       │
│           │       └── versions/
│           │           └── page.tsx      # Version history browser
│           │
│           ├── pages/                    # Landing Page Management
│           │   ├── page.tsx              # Page list (/admin/content/pages)
│           │   │                         # Table: title, slug, status, updated
│           │   │                         # Templates: Homepage, Feature, Pricing
│           │   │
│           │   ├── new/
│           │   │   └── page.tsx          # New page (/admin/content/pages/new)
│           │   │                         # Puck visual editor
│           │   │                         # Component library (Hero, Features, etc.)
│           │   │                         # Preview mode (mobile/tablet/desktop)
│           │   │
│           │   └── [id]/
│           │       ├── page.tsx          # Edit page (/admin/content/pages/[id])
│           │       │                     # Same as new page, pre-populated
│           │       │                     # Real-time preview pane
│           │       │                     # Component tree view
│           │       │
│           │       └── versions/
│           │           └── page.tsx      # Version history browser
│           │
│           └── media/
│               └── page.tsx              # Media library (/admin/content/media)
│                                         # Grid view of images/videos
│                                         # Upload: drag-drop, paste, file picker
│                                         # Filters: type, date, size
│                                         # Bulk actions: delete, tag, organize
│                                         # Image editing: crop, resize, compress

components/
├── content/                              # CMS Components
│   ├── BlockNoteEditor.tsx               # Main blog editor wrapper
│   │   ├── Uses: @blocknote/react
│   │   ├── Features: Rich text, embeds, tables, code blocks
│   │   ├── Real-time: useBlockNoteSync hook
│   │   └── Autosave: Every 2 seconds (debounced)
│   │
│   ├── PuckEditor.tsx                    # Page builder wrapper
│   │   ├── Uses: @measured/puck
│   │   ├── Features: Drag-drop components, responsive preview
│   │   ├── Real-time: Convex queries/mutations
│   │   └── Undo/Redo: Built-in history management
│   │
│   ├── MediaLibrary.tsx                  # Media manager component
│   │   ├── Upload: Convex file storage
│   │   ├── Display: Grid/List toggle
│   │   ├── Selection: Single/Multi select
│   │   └── Actions: Insert, Copy URL, Delete
│   │
│   ├── ContentPublishBar.tsx             # Publish controls
│   │   ├── Status: Draft | Published | Scheduled
│   │   ├── Visibility: Public | Private | Password
│   │   ├── Publish Date: Date picker (immediate or scheduled)
│   │   └── Actions: Save Draft, Publish, Unpublish
│   │
│   ├── VersionHistory.tsx                # Version browser
│   │   ├── Timeline: List of versions with timestamps
│   │   ├── Diff View: Side-by-side comparison
│   │   ├── Restore: Revert to previous version
│   │   └── Immutable: Versions never deleted
│   │
│   └── CollaboratorPresence.tsx          # Cursor indicators
│       ├── Avatar: User photo + name
│       ├── Cursor: Colored cursor with label
│       ├── Selection: Highlighted text selection
│       └── Awareness: Via @convex-dev/prosemirror-sync
│
├── puck-components/                      # Puck Page Builder Components
│   ├── Hero.tsx                          # Hero section
│   │   ├── Props: title, subtitle, ctaText, ctaUrl, backgroundImage
│   │   ├── Variants: Full-height, Split (text/image)
│   │   └── Responsive: Mobile-first layout
│   │
│   ├── Features.tsx                      # Feature grid
│   │   ├── Props: title, features[] (icon, title, description)
│   │   ├── Layouts: 2-col, 3-col, 4-col
│   │   └── Icons: Lucide React icons
│   │
│   ├── Testimonials.tsx                  # Social proof
│   │   ├── Props: testimonials[] (quote, author, role, avatar)
│   │   ├── Layouts: Carousel, Grid, Single
│   │   └── Automation: Pull from database or static
│   │
│   ├── PricingTable.tsx                  # Pricing comparison
│   │   ├── Props: plans[] (name, price, features[], cta)
│   │   ├── Toggle: Monthly/Annual pricing
│   │   └── Highlight: Most popular badge
│   │
│   ├── FAQ.tsx                           # Accordion FAQ
│   │   ├── Props: faqs[] (question, answer)
│   │   ├── Behavior: Collapsible accordion
│   │   └── Search: Filter FAQs by keyword
│   │
│   └── CTA.tsx                           # Call-to-action block
│       ├── Props: heading, description, primaryCta, secondaryCta
│       ├── Variants: Banner, Card, Modal
│       └── Tracking: PostHog event on click
```

### 3.11.2 CMS Data Flow

#### Document Editing Flow (Real-Time Collaboration)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BLOCKNOTE REAL-TIME EDITING FLOW                       │
└──────────────────────────────────────────────────────────────────────────────┘

User A (Editor)          User B (Editor)          Convex (Backend)
     │                        │                          │
     │ Open post /123         │                          │
     ├────────────────────────┼─────────────────────────→│
     │                        │                          │
     │ BlockNote loads        │                          │
     │ useBlockNoteSync       │                          │
     │ connects to Convex     │                          │
     │<────────────────────────────────────────────────┤
     │ Initial document state │                          │
     │                        │                          │
     │ User B opens same post │                          │
     │                        ├─────────────────────────→│
     │                        │ useBlockNoteSync         │
     │                        │<─────────────────────────┤
     │                        │ Initial document state   │
     │                        │                          │
     │ Types: "Hello World"   │                          │
     ├────────────────────────┼─────────────────────────→│
     │                        │ Prosemirror transaction  │
     │                        │ stored in Convex         │
     │                        │                          │
     │                        │ Push update (WebSocket)  │
     │                        │<─────────────────────────┤
     │                        │ "Hello World" appears    │
     │                        │ with User A avatar       │
     │                        │                          │
     │ See User B cursor      │ Types: "Nice post!"      │
     │<────────────────────────────────────────────────┤
     │ User B cursor visible  │                          │
     │ at line 2, column 15   ├─────────────────────────→│
     │                        │ Transaction stored       │
     │                        │                          │
     │ Auto-version created   │                          │
     │ (every 10 significant  │                          │
     │  edits or 5 minutes)   │                          │
     │<────────────────────────────────────────────────┤
     │ Version #47 saved      │                          │
     │ Timestamp: 2:34 PM     │                          │

TECHNICAL IMPLEMENTATION:

1. @convex-dev/prosemirror-sync
   • Handles operational transform (OT) for conflict-free editing
   • Stores document as Prosemirror JSON in Convex
   • Broadcasts changes via Convex subscriptions

2. BlockNote Editor
   • Built on Prosemirror (same as Notion, Google Docs)
   • Block-based editing (paragraphs, headings, lists, embeds)
   • Custom schema for course-specific blocks

3. Convex Schema
   • posts table: { _id, title, content (Prosemirror JSON), authorId, status }
   • postVersions table: { _id, postId, content, versionNumber, createdAt }
   • presence table: { userId, postId, cursor, lastSeen }
```

#### Publishing Flow (Draft → Published)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            CONTENT PUBLISHING FLOW                            │
└──────────────────────────────────────────────────────────────────────────────┘

[Admin] ──1─→ Clicks "Publish" in ContentPublishBar
              │
              ├─→ Client-side validation:
              │   • Title not empty ✓
              │   • Slug unique ✓
              │   • Content >100 chars ✓
              │   • Featured image set ✓
              │   • Meta description <160 chars ✓
              │
              ├─2─→ [Convex Mutation: posts.publish]
              │     • Validate user role: platform_admin or org_admin
              │     • Check post ownership (if org_admin)
              │     • Update post.status = "published"
              │     • Set post.publishedAt = Date.now()
              │     • Create final version snapshot
              │
              ├─3─→ SEO Metadata Generation
              │     • Generate Open Graph tags
              │     • Create Twitter Card metadata
              │     • Generate JSON-LD structured data
              │     • Update sitemap.xml (Convex cron)
              │
              ├─4─→ CDN Cache Invalidation
              │     • Purge Vercel ISR cache for /blog/[slug]
              │     • Purge homepage cache (shows latest posts)
              │     • Purge RSS feed cache
              │
              ├─5─→ Notification Triggers (Optional)
              │     • Send Brevo email to subscribers
              │     • Post to Twitter/LinkedIn (if configured)
              │     • Webhook to Zapier/Slack (if configured)
              │
              └─6─→ Public Slug Active
                    • /blog/[slug] now accessible
                    • Appears in course catalog (if post.courseId set)
                    • Indexed by search engines

SCHEDULED PUBLISHING:

[Admin] ──→ Sets publishDate = future date
         ├─→ Status remains "draft" until scheduled time
         ├─→ Convex Cron Job (runs hourly):
         │   • Query posts WHERE status="draft" AND publishDate <= now()
         │   • For each: run posts.publish mutation
         │   • Log published posts in admin audit log
         └─→ Post goes live automatically

UNPUBLISHING:

[Admin] ──→ Clicks "Unpublish"
         ├─→ [Convex Mutation: posts.unpublish]
         │   • Update post.status = "draft"
         │   • Keep publishedAt for history
         │   • Purge CDN cache
         └─→ /blog/[slug] returns 404 (or redirect to homepage)
```

#### Media Upload Flow (Images/Videos)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          MEDIA UPLOAD & STORAGE FLOW                          │
└──────────────────────────────────────────────────────────────────────────────┘

[Admin] ──1─→ Select file(s) in MediaLibrary
              • Drag-drop, paste from clipboard, or file picker
              • Client-side validation:
                - Images: PNG, JPEG, WebP, SVG, GIF (<10MB)
                - Videos: MP4, MOV, WebM (<100MB)
              │
              ├─2─→ [Convex Mutation: media.generateUploadUrl]
              │     • Returns signed Convex Storage URL (1 hour expiry)
              │     • Unique storageId generated
              │
              ├─3─→ Upload directly to Convex Storage
              │     • Bypasses Next.js server (no serverless limits)
              │     • Progress bar tracks upload %
              │     • Cancellable upload (abort controller)
              │
              ├─4─→ [Convex Mutation: media.create]
              │     • Store metadata:
              │       { storageId, filename, mimeType, size,
              │         width, height, uploadedBy, tags[] }
              │     • If image: Extract EXIF metadata (camera, location)
              │     • If video: Extract duration, codec, resolution
              │
              ├─5─→ Thumbnail Generation (Convex Action)
              │     • If image: Generate 3 sizes
              │       - Thumbnail: 200x200 (for library grid)
              │       - Medium: 800x600 (for editor preview)
              │       - Large: 1200x900 (for full view)
              │     • If video: Extract frame at 00:00:01
              │     • Store thumbnails as separate storageIds
              │
              ├─6─→ Media Available in Library
              │     • Appears in /admin/content/media
              │     • Searchable by filename, tags, type
              │     • Filterable by date, size, uploader
              │
              └─7─→ Insert into Document
                    • BlockNote: Image block with storageId
                    • Puck: Image component with Convex URL
                    • URL format: https://[deployment].convex.cloud/api/storage/[storageId]

IMAGE OPTIMIZATION:

• Convex Storage serves images with:
  - Automatic WebP conversion (if browser supports)
  - Content-Delivery via global CDN (Cloudflare)
  - Immutable cache headers (1 year)

• For responsive images:
  <img
    src={convex.storage.getUrl(media.storageId)}
    srcSet={`
      ${convex.storage.getUrl(media.thumbnail)} 200w,
      ${convex.storage.getUrl(media.medium)} 800w,
      ${convex.storage.getUrl(media.large)} 1200w
    `}
    sizes="(max-width: 640px) 200px,
           (max-width: 1024px) 800px,
           1200px"
    alt={media.altText}
  />

VIDEO HANDLING:

• Videos NOT transcoded by Convex (use external service if needed)
• Recommendation: Upload to Mux/Cloudinary, store URL in Convex
• Alternative: Store small videos (<100MB) in Convex for internal use
```

### 3.11.3 CMS Integration Points

| Integration | Direction | Protocol | Purpose |
|------------|-----------|----------|---------|
| **BlockNote → Convex** | Bidirectional | WebSocket (Convex Sync) | Real-time collaborative editing, document sync |
| **Puck → Convex** | Bidirectional | HTTP (Convex Queries/Mutations) | Page data CRUD, component state storage |
| **Media → Convex Storage** | Upload | HTTPS (Signed URL) | File storage (images, videos, documents) |
| **CDN → Public Pages** | Fetch | ISR (Incremental Static Regeneration) | Content delivery, edge caching |
| **Convex → Vercel ISR** | Outbound | Webhook (Cache Purge) | Invalidate stale cached pages after publish |
| **BlockNote → Media Library** | Inbound | Component API | Insert images/videos into editor |

### 3.11.4 CMS Security Model

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          CMS ACCESS CONTROL MATRIX                            │
└──────────────────────────────────────────────────────────────────────────────┘

ROLE HIERARCHY:

platform_admin  ──→  Full CMS access (all content types)
     │
     ├──→ Create, edit, delete ANY post/page
     ├──→ Publish/unpublish ANY content
     ├──→ Manage ALL media library assets
     ├──→ View ALL version history
     ├──→ Restore ANY previous version
     └──→ Configure CMS settings (slug format, SEO defaults)

org_admin  ──→  Organization-scoped CMS access
     │
     ├──→ Create, edit posts/pages for OWN organization
     ├──→ Publish content (with approval workflow if enabled)
     ├──→ Manage media uploaded by own team
     ├──→ View version history for own content
     └──→ CANNOT access other organizations' content

user  ──→  No CMS access (read-only public content)
     │
     └──→ Can view published posts/pages at /blog/[slug]

┌────────────────────────────────────────────────────────────────────────────┐
│                            CONTENT PERMISSIONS                              │
├────────────────────────────────────────────────────────────────────────────┤
│ Action                 │ platform_admin │ org_admin    │ user             │
├────────────────────────┼────────────────┼──────────────┼─────────────────┤
│ View draft posts       │ All            │ Own org only │ None             │
│ Create posts           │ ✓              │ ✓            │ ✗                │
│ Edit own posts         │ ✓              │ ✓            │ ✗                │
│ Edit others' posts     │ ✓              │ Same org     │ ✗                │
│ Delete posts           │ ✓              │ Own only     │ ✗                │
│ Publish posts          │ ✓              │ ✓            │ ✗                │
│ Unpublish posts        │ ✓              │ Own only     │ ✗                │
│ Restore versions       │ ✓              │ Own only     │ ✗                │
│ Upload media           │ ✓              │ ✓            │ ✗                │
│ Delete media           │ All            │ Own uploads  │ ✗                │
│ Create pages (Puck)    │ ✓              │ ✗ (admin-only)│ ✗               │
│ Edit pages (Puck)      │ ✓              │ ✗            │ ✗                │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                          MEDIA UPLOAD LIMITS                                │
├────────────────────────────────────────────────────────────────────────────┤
│ File Type    │ Max Size     │ Allowed Extensions      │ Quota (per org) │
├──────────────┼──────────────┼─────────────────────────┼────────────────┤
│ Images       │ 10 MB        │ .jpg, .jpeg, .png,      │ 5 GB           │
│              │              │ .webp, .svg, .gif       │                 │
│ Videos       │ 100 MB       │ .mp4, .mov, .webm       │ 20 GB          │
│ Documents    │ 10 MB        │ .pdf, .docx, .pptx      │ 2 GB           │
│ Audio        │ 50 MB        │ .mp3, .wav, .m4a        │ 5 GB           │
└────────────────────────────────────────────────────────────────────────────┘

UPLOAD VALIDATION (Server-Side):

export const uploadMedia = mutation({
  args: { filename: v.string(), mimeType: v.string(), size: v.number() },
  handler: async (ctx, args) => {
    // 1. Authentication check
    const userId = await ctx.auth.getUserIdentity();
    if (!userId) throw new Error("Not authenticated");

    // 2. Role check
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", userId.subject))
      .unique();

    if (!user || !["platform_admin", "org_admin"].includes(user.role)) {
      throw new Error("Unauthorized: Admin access required");
    }

    // 3. File size validation
    const maxSize = args.mimeType.startsWith("video/") ? 100_000_000 : 10_000_000;
    if (args.size > maxSize) {
      throw new Error(`File too large: ${args.size} bytes (max: ${maxSize})`);
    }

    // 4. MIME type validation
    const allowedTypes = [
      "image/jpeg", "image/png", "image/webp", "image/svg+xml", "image/gif",
      "video/mp4", "video/quicktime", "video/webm",
      "application/pdf",
    ];
    if (!allowedTypes.includes(args.mimeType)) {
      throw new Error(`File type not allowed: ${args.mimeType}`);
    }

    // 5. Quota check (org_admin only)
    if (user.role === "org_admin" && user.organizationId) {
      const orgUsage = await getOrganizationStorageUsage(ctx, user.organizationId);
      if (orgUsage + args.size > 5_000_000_000) { // 5GB limit
        throw new Error("Organization storage quota exceeded");
      }
    }

    // 6. Generate upload URL
    return await ctx.storage.generateUploadUrl();
  },
});

┌────────────────────────────────────────────────────────────────────────────┐
│                        PUBLISH APPROVAL WORKFLOW                            │
│                       (Optional - Enterprise Feature)                       │
└────────────────────────────────────────────────────────────────────────────┘

IF enableApprovalWorkflow = true (organization setting):

1. org_admin creates post → status = "pending_review"
2. platform_admin receives notification
3. platform_admin reviews content:
   • Approve: status = "published", notification sent to org_admin
   • Request Changes: status = "revision_requested", comments added
   • Reject: status = "rejected", reason required
4. org_admin edits and resubmits → status = "pending_review" again

CONVEX SCHEMA:

posts: {
  status: v.union(
    v.literal("draft"),
    v.literal("pending_review"),
    v.literal("revision_requested"),
    v.literal("published"),
    v.literal("rejected")
  ),
  reviewedBy?: v.id("users"),
  reviewedAt?: v.number(),
  reviewComments?: v.string(),
}
```

### 3.11.5 CMS Version History & Audit Trail

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           VERSION CONTROL SYSTEM                              │
└──────────────────────────────────────────────────────────────────────────────┘

AUTOMATIC VERSIONING:

Versions are created automatically on:
  1. Every 10 "significant" edits (character count change >100)
  2. Every 5 minutes (if document modified)
  3. Manual save (user clicks "Save Version")
  4. Status change (draft → published)
  5. Before restore (backup current state)

CONVEX SCHEMA:

postVersions: {
  _id: v.id("postVersions"),
  postId: v.id("posts"),              // Parent post
  versionNumber: v.number(),          // Auto-incrementing (1, 2, 3...)
  content: v.any(),                   // Prosemirror JSON snapshot
  title: v.string(),                  // Title at time of version
  authorId: v.id("users"),            // Who created this version
  createdAt: v.number(),              // Timestamp
  changeType: v.union(                // Why this version was created
    v.literal("auto"),                // Automatic save
    v.literal("manual"),              // User clicked "Save Version"
    v.literal("publish"),             // Published content
    v.literal("restore")              // Restored from previous version
  ),
  changeSummary?: v.string(),         // Optional: "Added hero image, fixed typo"
  characterCount: v.number(),         // Content length
  diffSize: v.number(),               // Bytes changed from previous version
}

VERSION HISTORY UI:

┌─────────────────────────────────────────────────────────────────────────────┐
│ Version History                                                   [Close X] │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Timeline:                                                                   │
│                                                                               │
│  ● v12 - Published                             2 hours ago (Current)        │
│  │  By: Adam Kovacs                                                         │
│  │  "Final version for launch"                                              │
│  │  [View] [Restore] [Download]                                             │
│  │                                                                            │
│  ● v11 - Manual Save                           3 hours ago                  │
│  │  By: Adam Kovacs                                                         │
│  │  "Added pricing section, updated hero"                                   │
│  │  [View] [Restore] [Compare to v12]                                       │
│  │                                                                            │
│  ● v10 - Auto Save                             4 hours ago                  │
│  │  By: Sarah Johnson                                                       │
│  │  (382 chars changed)                                                     │
│  │  [View] [Restore]                                                        │
│  │                                                                            │
│  ● v9 - Restore from v7                        5 hours ago                  │
│  │  By: Adam Kovacs                                                         │
│  │  "Reverted accidental deletion"                                          │
│  │  [View]                                                                   │
│  │                                                                            │
│  └─ Show all 12 versions ▼                                                  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

DIFF VIEW (Compare Versions):

┌─────────────────────────────────────────────────────────────────────────────┐
│ Compare Versions: v11 ↔ v12                                       [Close X] │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  v11 (3 hours ago)              │  v12 (2 hours ago) - Current              │
│  By: Adam Kovacs                │  By: Adam Kovacs                          │
│  ────────────────────────────────┼────────────────────────────────────────│
│                                  │                                            │
│  # AI Mastery Course             │  # AI Mastery Course                      │
│                                  │                                            │
│  Learn to build AI apps in 2    │  Learn to build AI apps in 2              │
│  days intensive cohort.          │  days intensive cohort.                   │
│                                  │                                            │
│  ## Pricing                      │  ## Pricing                               │
│  - Individual: $1,495            │  - Individual: $1,495                     │
│  - Team (5+): $1,295/seat        │  - Team (5+): $1,295/seat                 │
│                                  │  + Enterprise: Custom pricing             │
│                                  │                                            │
│  [Hero Image]                    │  [Hero Image - Updated]                   │
│  old-hero.png                    │  new-hero.png                             │
│                                  │                                            │
│  ────────────────────────────────┼────────────────────────────────────────│
│                                  │                                            │
│  Legend:  + Added  - Removed  ~ Modified                                    │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

RESTORE WORKFLOW:

1. User clicks "Restore" on version #9
2. Confirmation dialog: "Restore to version 9? Current work will be saved as v13."
3. Backend logic:
   • Create version #13 (backup current state before restore)
   • Copy version #9 content to current post
   • Create version #14 (restore event) with changeType="restore"
4. Editor reloads with version #9 content
5. Notification: "Restored to version 9. Undo: [Restore to v13]"

IMMUTABLE AUDIT TRAIL:

• Versions NEVER deleted (compliance requirement)
• Every change tracked with timestamp + user
• Full content snapshots (not diffs) for reliability
• Queryable history for analytics:
  - Who edited most?
  - Average time between publish?
  - Most reverted sections?
```

### 3.11.6 CMS Performance Optimization

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       EDITOR PERFORMANCE TARGETS                              │
└──────────────────────────────────────────────────────────────────────────────┘

BLOCKNOTE EDITOR:

Target Metrics:
  • Initial Load: <2s (editor ready to type)
  • Keystroke Latency: <16ms (60 FPS)
  • Autosave Debounce: 2s (balance between safety and performance)
  • Real-time Sync Delay: <200ms (perceivable as "instant")
  • Large Document (10,000 words): <3s load time

Optimization Strategies:
  1. Lazy Load Editor: Dynamic import BlockNote only when /admin/content route
  2. Virtual Scrolling: Render only visible blocks (react-window)
  3. Debounced Sync: Batch small edits before sending to Convex
  4. Optimistic Updates: Apply changes locally immediately, sync in background
  5. Web Worker: Offload Prosemirror operations to separate thread

PUCK PAGE BUILDER:

Target Metrics:
  • Component Drag Start: <50ms (smooth drag feedback)
  • Preview Re-render: <100ms (after component property change)
  • Save Page: <500ms (optimistic save + background sync)
  • Component Palette Load: <1s (all available components)

Optimization Strategies:
  1. Component Code Splitting: Lazy load each Puck component
  2. Preview Throttling: Debounce preview re-renders during drag
  3. Memoization: React.memo on all Puck components
  4. SSR Disabled: Puck editor client-only (no SSR overhead)
  5. Image Proxying: Lazy load component thumbnails in palette

MEDIA LIBRARY:

Target Metrics:
  • Grid Load (100 items): <1s
  • Thumbnail Load: <100ms per image (progressive)
  • Search Filter: <50ms (instant feedback)
  • Upload Progress: Real-time (1% increments)

Optimization Strategies:
  1. Virtual Grid: Render only visible thumbnails (react-window)
  2. Thumbnail CDN: Serve 200x200 thumbnails from Convex CDN
  3. Lazy Image Loading: Intersection Observer for below-fold images
  4. Indexed Search: Convex indexes on filename, tags, mimeType
  5. Upload Chunking: Split large files (>10MB) into 1MB chunks

┌──────────────────────────────────────────────────────────────────────────────┐
│                        ISR CACHE STRATEGY (VERCEL)                            │
└──────────────────────────────────────────────────────────────────────────────┘

BLOG POST PAGES (/blog/[slug]):

export async function generateStaticParams() {
  // Pre-render top 50 posts at build time
  const posts = await convex.query(api.posts.listPublished, { limit: 50 });
  return posts.map((post) => ({ slug: post.slug }));
}

export const revalidate = 3600; // Revalidate every 1 hour

// On-demand revalidation after publish:
// POST /api/revalidate?path=/blog/my-post&secret=TOKEN

LANDING PAGES (/[slug]):

export const revalidate = 86400; // Revalidate every 24 hours (rarely change)

HOMEPAGE (/):

export const revalidate = 1800; // Revalidate every 30 minutes (shows latest posts)

CACHE PURGE AFTER PUBLISH:

export const publishPost = mutation({
  handler: async (ctx, args) => {
    // ... publish logic ...

    // Trigger on-demand ISR revalidation
    await fetch(`https://campfire-v2.vercel.app/api/revalidate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        secret: process.env.REVALIDATE_SECRET,
        paths: [
          `/blog/${post.slug}`,  // Post page
          `/blog`,               // Blog index
          `/`,                   // Homepage (latest posts)
        ],
      }),
    });
  },
});

CDN EDGE CACHING:

• Convex Storage URLs: 1 year cache (immutable storageIds)
• Blog pages: 1 hour cache, revalidate on-demand
• API routes: No cache (dynamic data)
• Static assets: 1 year cache (hashed filenames)
```

### 3.11.7 CMS SEO Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          SEO METADATA GENERATION                              │
└──────────────────────────────────────────────────────────────────────────────┘

BLOG POST SEO FIELDS (Convex Schema):

posts: {
  // ... other fields ...
  seo: v.object({
    metaTitle: v.optional(v.string()),        // Override page title (default: post.title)
    metaDescription: v.string(),              // REQUIRED (max 160 chars)
    slug: v.string(),                         // URL-friendly (auto-generated from title)
    canonicalUrl: v.optional(v.string()),     // If content duplicated elsewhere
    focusKeyword: v.optional(v.string()),     // Primary SEO keyword
    ogImage: v.optional(v.id("mediaAssets")), // Open Graph image (1200x630)
    twitterCard: v.optional(v.union(          // Twitter Card type
      v.literal("summary"),
      v.literal("summary_large_image")
    )),
    noIndex: v.optional(v.boolean()),         // Exclude from search engines
    noFollow: v.optional(v.boolean()),        // Don't follow links
    structuredData: v.optional(v.any()),      // Custom JSON-LD
  }),
}

NEXT.JS METADATA API (App Router):

// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }) {
  const post = await convex.query(api.posts.getBySlug, { slug: params.slug });

  return {
    title: post.seo.metaTitle || post.title,
    description: post.seo.metaDescription,
    keywords: [post.seo.focusKeyword, ...post.tags],
    authors: [{ name: post.author.name }],
    openGraph: {
      title: post.seo.metaTitle || post.title,
      description: post.seo.metaDescription,
      url: `https://campfire.aienablement.academy/blog/${post.slug}`,
      siteName: "AI Enablement Academy",
      images: [
        {
          url: convex.storage.getUrl(post.seo.ogImage),
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
      locale: "en_US",
      type: "article",
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.author.name],
      tags: post.tags,
    },
    twitter: {
      card: post.seo.twitterCard || "summary_large_image",
      title: post.seo.metaTitle || post.title,
      description: post.seo.metaDescription,
      images: [convex.storage.getUrl(post.seo.ogImage)],
      creator: "@AIEnablementAcademy",
    },
    robots: {
      index: !post.seo.noIndex,
      follow: !post.seo.noFollow,
      googleBot: {
        index: !post.seo.noIndex,
        follow: !post.seo.noFollow,
      },
    },
    alternates: {
      canonical: post.seo.canonicalUrl || `https://campfire.aienablement.academy/blog/${post.slug}`,
    },
  };
}

JSON-LD STRUCTURED DATA:

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "{{ post.title }}",
  "description": "{{ post.seo.metaDescription }}",
  "image": "{{ post.seo.ogImage }}",
  "author": {
    "@type": "Person",
    "name": "{{ post.author.name }}",
    "url": "{{ post.author.profileUrl }}"
  },
  "publisher": {
    "@type": "Organization",
    "name": "AI Enablement Academy",
    "logo": {
      "@type": "ImageObject",
      "url": "https://campfire.aienablement.academy/logo.png"
    }
  },
  "datePublished": "{{ post.publishedAt }}",
  "dateModified": "{{ post.updatedAt }}",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://campfire.aienablement.academy/blog/{{ post.slug }}"
  },
  "keywords": "{{ post.tags.join(', ') }}",
  "articleSection": "{{ post.category }}",
  "wordCount": "{{ post.characterCount }}",
  "inLanguage": "en-US"
}
</script>

SITEMAP GENERATION (Convex Cron):

// Runs daily at 3 AM
export const generateSitemap = internalMutation({
  handler: async (ctx) => {
    const posts = await ctx.db
      .query("posts")
      .withIndex("by_status", (q) => q.eq("status", "published"))
      .collect();

    const pages = await ctx.db
      .query("pages")
      .withIndex("by_status", (q) => q.eq("status", "published"))
      .collect();

    const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${posts.map((post) => `
  <url>
    <loc>https://campfire.aienablement.academy/blog/${post.slug}</loc>
    <lastmod>${new Date(post.updatedAt).toISOString()}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  `).join("")}

  ${pages.map((page) => `
  <url>
    <loc>https://campfire.aienablement.academy/${page.slug}</loc>
    <lastmod>${new Date(page.updatedAt).toISOString()}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>${page.slug === "home" ? "1.0" : "0.9"}</priority>
  </url>
  `).join("")}
</urlset>`;

    // Store in Convex Storage
    await ctx.storage.store(new Blob([sitemap], { type: "application/xml" }));
  },
});

RSS FEED GENERATION:

// app/blog/rss.xml/route.ts
export async function GET() {
  const posts = await convex.query(api.posts.listPublished, { limit: 50 });

  const rss = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>AI Enablement Academy Blog</title>
    <link>https://campfire.aienablement.academy/blog</link>
    <description>Latest insights on AI enablement and education</description>
    <language>en-us</language>
    <lastBuildDate>${new Date().toUTCString()}</lastBuildDate>
    <atom:link href="https://campfire.aienablement.academy/blog/rss.xml" rel="self" type="application/rss+xml"/>

    ${posts.map((post) => `
    <item>
      <title>${post.title}</title>
      <link>https://campfire.aienablement.academy/blog/${post.slug}</link>
      <description>${post.seo.metaDescription}</description>
      <pubDate>${new Date(post.publishedAt).toUTCString()}</pubDate>
      <guid>https://campfire.aienablement.academy/blog/${post.slug}</guid>
      <author>${post.author.email} (${post.author.name})</author>
      ${post.tags.map((tag) => `<category>${tag}</category>`).join("")}
    </item>
    `).join("")}
  </channel>
</rss>`;

  return new Response(rss, {
    headers: {
      "Content-Type": "application/xml",
      "Cache-Control": "s-maxage=3600, stale-while-revalidate",
    },
  });
}
```

---

**CMS Implementation Priority:**

1. **Phase 1 (MVP)**: BlockNote blog editor, basic media library, publish/draft
2. **Phase 2**: Puck page builder, version history, SEO metadata
3. **Phase 3**: Approval workflow, advanced media management, structured data
4. **Phase 4**: Multi-language support, scheduled publishing, content analytics
