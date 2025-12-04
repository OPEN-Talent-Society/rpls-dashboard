# AI Enablement Academy v2 - Product Requirements Document

**Version:** 2.2.0
**Created:** 2025-12-02
**Updated:** 2025-12-03
**Status:** Draft - Pending Approval
**Author:** AI Enablement Academy Technical Team

---

## 1. Executive Summary

### 1.1 Project Overview
AI Enablement Academy v2 (project-campfire-v2) is a complete rebuild of the cohort-based AI learning platform, optimized for **AI-agent development workflows**. The platform evolves through distinct phases: from marketing presence → live cohort delivery → full e-learning platform.

### 1.2 Why Rebuild?
The v1 stack (PayloadCMS + PostgreSQL) introduced complexity that hindered AI-agent development velocity:
- Multiple languages/paradigms (SQL + TypeScript + CMS admin)
- Complex configuration management
- Inconsistent patterns across layers

### 1.3 Strategic Decision
**Convex full-stack** was selected for maximum AI-agent development efficiency:
- **Single TypeScript pattern** for all data operations
- **Zero configuration** real-time subscriptions
- **Built-in authentication, storage, file handling**
- **Type safety end-to-end** (schema → queries → mutations → UI)

### 1.4 Core Value Proposition
> **"Stop tinkering with AI. Start building with it!"**

Building real AI skills that move careers forward through 2-day intensive cohorts with hands-on labs and proven frameworks.

### 1.5 Platform Evolution Roadmap

```
Phase 0: Marketing Landing Page
├── Goal: Capture leads, showcase offerings
├── Deliverables: Marketing site, course catalog, contact forms
└── Revenue: Lead generation only

Phase 1: Live Cohort MVP
├── Goal: Sell and deliver 2-day intensives
├── Deliverables: Enrollment, payments, pre/post cohort experience
└── Revenue: B2C courses ($749-$1,479), B2B programs ($28K+)

Phase 2: Post-Cohort Engagement
├── Goal: Deliver promised inclusions, build relationships
├── Deliverables: Office hours, recordings, enablement kit, certificates
└── Revenue: Retention, upsell to next level

Phase 3: E-Learning Expansion
├── Goal: Add self-paced content for passive income
├── Deliverables: Drip content, progress tracking, quizzes
└── Revenue: Subscription + one-time purchases

Phase 4: Platform & AI Features
├── Goal: Full LMS rivaling Thinkific/Maven
├── Deliverables: Multi-event types, AI coach, advanced analytics
└── Revenue: Enterprise subscriptions, marketplace
```

### 1.6 Recent Enhancements (v2.1)

**Version 2.1 introduced critical learner engagement and enterprise features:**

- **Skills & Competencies System**: Structured skill taxonomy mapping learning outcomes to industry competencies, enabling personalized learning paths and progress tracking
- **Resource Library**: Centralized repository of AI glossary terms, pre-built prompts, and templates accessible throughout the learning journey
- **Learning Paths**: Guided progressions through content modules based on role, experience level, and career goals
- **Community System**: Discussion forums, peer networking, and alumni engagement features for ongoing collaboration
- **Assessment System**: Pre-cohort and post-cohort assessments enabling ROI measurement, learning impact validation, and personalized recommendations
- **Manager Dashboard**: B2B enterprise visibility into team progress, skill development, and organizational ROI metrics

---

## 2. Technology Stack Decisions

### 2.1 Core Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Database** | Convex | TypeScript-first, real-time, serverless, AI-agent optimized |
| **Frontend** | Next.js 15 (App Router) | React Server Components, optimal DX |
| **Hosting** | Vercel | Zero-config deployment, edge functions, analytics |
| **Authentication** | Convex Auth | Native integration, zero config |
| **Payments** | Stripe | Industry standard, webhook ecosystem |
| **Email** | Brevo | Existing MCP integration, transactional + marketing |
| **Analytics** | PostHog (self-hosted) | Privacy-focused, event tracking, session replay |
| **Forms/Surveys** | Formbricks (self-hosted) | Intake surveys, feedback collection |
| **Certificates** | Open Badges 3.0 | LinkedIn sharing, verifiable credentials |
| **Video** | YouTube/Vimeo embeds | Phase 0-2 simplicity, no CDN needed |
| **AI Provider** | OpenRouter | Multi-model routing, cost optimization |
| **UI Components** | shadcn/ui + Tailwind | Design system consistency |

### 2.2 AI-Agent Development Optimization

The stack is optimized for Claude Code and similar AI coding agents:

1. **Single Pattern**: All data operations use Convex TypeScript
2. **Type Safety**: Schema → Query → Mutation → Component fully typed
3. **No Context Switching**: No SQL, no CMS admin, no separate API layer
4. **Predictable Structure**: Convention over configuration
5. **Self-Documenting**: TypeScript types serve as documentation

### 2.3 Integration Points

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Enablement Academy v2                  │
├─────────────────────────────────────────────────────────────┤
│  Frontend (Next.js 15 on Vercel)                            │
│  ├── Marketing Pages (SSG/ISR)                              │
│  ├── Course Catalog                                         │
│  ├── Learner Portal                                         │
│  └── Admin Dashboard                                        │
├─────────────────────────────────────────────────────────────┤
│  Backend (Convex)                                           │
│  ├── Schema-driven Database                                 │
│  ├── Queries & Mutations (TypeScript)                       │
│  ├── Real-time Subscriptions                                │
│  ├── File Storage (Enablement Kit)                          │
│  ├── Scheduled Jobs (cron)                                  │
│  └── HTTP Actions (webhooks)                                │
├─────────────────────────────────────────────────────────────┤
│  External Services                                          │
│  ├── Stripe (Payments/Webhooks)                             │
│  ├── Brevo (Email Automation)                               │
│  ├── PostHog (Analytics)                                    │
│  ├── Formbricks (Surveys) @ forms.aienablement.academy      │
│  ├── OpenRouter (AI Features - Phase 2+)                    │
│  └── Cal.com (Office Hours - Phase 2)                       │
└─────────────────────────────────────────────────────────────┘
```

### 2.4 Deployment & Infrastructure

**Domain:** aienablement.academy

**Vercel Configuration:**
- Production: `aienablement.academy`
- Preview: `*.vercel.app` (PR previews)
- Environment variables: Convex, Stripe, Brevo, PostHog keys

**Convex:**
- Production deployment with automatic backups
- File storage for Enablement Kit assets
- Scheduled functions for email triggers

**Self-Hosted Services:**
- PostHog: analytics.aienablement.academy
- Formbricks: forms.aienablement.academy (env: `cmhbcg6ty0009t6014kqfde0u`)

---

## 3. Business Model

### 3.1 Revenue Streams

**B2C (Individual Learners):**
| Course | Price | Format | Duration |
|--------|-------|--------|----------|
| AI Foundations | $749 | 2-day intensive | ~12 hours |
| AI Essentials | $1,479 | 2-day intensive | ~12 hours |

**B2B (Enterprise):**
| Program | Price Range | Format |
|---------|-------------|--------|
| Custom Cohorts | $28,500+ (20 seats) | 2-day intensive |
| Executive Strategy | $749-$995/person | 6 hours |
| Team Offsite | $997-$1,497/person | 10 hours |

### 3.2 Course Architecture

```
Impact Levels:
├── L1: Augmentation (AI-Curious → Foundations)
├── L2: Automation (AI-Engaged → Essentials)
└── L3: Architecture (AI-Native → Coming Soon)

Capability Progression:
├── Foundations → Entry point, $749
├── Essentials → Intermediate, $1,479
├── Fluent → Advanced (future)
└── Native → Expert (future)
```

### 3.3 Program Inclusions (What Learners Get)

**Included in Every Course:**

| Inclusion | Duration | Description |
|-----------|----------|-------------|
| Live Cohort | 2 days | 9 AM - 5 PM PT, 15 sessions |
| Weekly Office Hours | 3 months | 1-hour sessions, book via Cal.com |
| Course Materials | 1 year | Slides, worksheets, templates |
| Session Recordings | 1 year | Full cohort recordings |
| Enablement Kit | 1 year | Prompt libraries, custom chatbots |
| Knowledge Chatbot | 1 year | AI assistant for real-time support |
| Monthly Expert Calls | Ongoing | Industry trends and best practices |

### 3.4 Cohort Model

- **Max Participants**: 20 per cohort (optimal engagement)
- **Format**: 2-day live virtual intensives (Zoom)
- **Schedule**: 9 AM - 5 PM PT (both days)
- **Frequency**: Rolling cohorts (2-4 per month)
- **Session Types**: Seminars (S), Workshops (W), Masterminds (MM), Capstone (CAP)

### 3.5 B2B Deliverables (per Talabat SOW)

| Deliverable | Description |
|-------------|-------------|
| Pre-Cohort Audit | Workflow analysis, intake surveys |
| Live Delivery | Custom 2-day cohort for team |
| Enablement Kit | Recordings, slides, prompt libraries, 2 custom chatbots |
| Post-Cohort Support | 3 weeks Slack integration + weekly office hours |
| Executive Impact Report | ROI summary for leadership |

---

## 4. Feature Requirements

### 4.0 Phase 0 (Marketing Landing Page) - Priority P0

> **Goal:** Get live with lead capture and course showcase

#### 4.0.1 Marketing Website
- [ ] Hero section with value proposition
- [ ] Course catalog with filtering (Impact Level, Capability)
- [ ] Individual course detail pages
- [ ] Pricing page with B2C/B2B differentiation
- [ ] Founder bios and credibility section
- [ ] Testimonials display (quotes + logos)
- [ ] FAQ accordion
- [ ] Contact form (enterprise inquiries → Brevo)
- [ ] Newsletter signup (waitlist → Brevo list)

#### 4.0.2 Basic Analytics
- [ ] PostHog page view tracking
- [ ] CTA click tracking
- [ ] Form submission tracking

### 4.1 Phase 1 (Live Cohort MVP) - Priority P0

> **Goal:** Sell and deliver 2-day intensives with full learner experience

#### 4.1.1 User Authentication
- [ ] Email/password registration
- [ ] Social login (Google, LinkedIn)
- [ ] Role-based access (admin, instructor, learner)
- [ ] Organization management (B2B)
- [ ] Seat licensing for enterprise

#### 4.1.2 User Profiles
- [ ] Profile creation with photo, bio, LinkedIn URL
- [ ] Professional background (role, industry, company)
- [ ] Learning goals and AI experience level
- [ ] Public/private profile toggle
- [ ] Profile sharing for networking
- [ ] "Return to Academy" upsell on profile page

#### 4.1.3 Course & Cohort Management (Admin)
- [ ] Course CRUD (title, description, price, impact level)
- [ ] Cohort scheduling with capacity limits (max 20)
- [ ] Cohort status workflow (scheduled → open → in_progress → completed)
- [ ] Waitlist management when cohorts full
- [ ] Zoom link management per cohort
- [ ] Session schedule per cohort (15 sessions over 2 days)

#### 4.1.4 Enrollment & Payments
- [ ] Stripe Checkout integration
- [ ] Individual course purchase ($749, $1,479)
- [ ] Cohort selection during checkout
- [ ] Enterprise invoicing (manual process initially)
- [ ] Refund processing (7-day policy)
- [ ] Payment confirmation emails (Brevo)
- [ ] Webhook handling (payment events)

#### 4.1.5 Pre-Cohort Experience
- [ ] Formbricks intake survey trigger (post-purchase)
- [ ] Survey completion tracking
- [ ] Welcome email with cohort details (T-7 days)
- [ ] Pre-work materials access
- [ ] Tech check reminder (T-2 days)
- [ ] Zoom link delivery (T-1 day)

#### 4.1.6 Live Cohort Delivery
- [ ] Learner portal with enrolled cohorts
- [ ] Session schedule view (Day 1: Sessions 1-7, Day 2: Sessions 8-15)
- [ ] Zoom join links (per session or single cohort link)
- [ ] Session materials access (slides, worksheets)
- [ ] Real-time cohort roster (who's enrolled)

#### 4.1.7 Post-Cohort Experience
- [ ] Session recordings access (uploaded post-cohort)
- [ ] Enablement Kit access (Convex file storage)
  - [ ] Presentation slides (PDF)
  - [ ] Prompt libraries (templates)
  - [ ] Custom chatbot links (external)
  - [ ] Worksheets and templates
- [ ] Feedback survey trigger (+1 day, Formbricks)
- [ ] Office hours invitation (+3 days, Brevo)

#### 4.1.8 Program Access Tracking
- [ ] Enrollment start date (purchase date)
- [ ] Office hours eligibility (3 months from cohort end)
- [ ] Materials access expiry (1 year from cohort end)
- [ ] Knowledge chatbot access (1 year)
- [ ] Access status display in learner portal

### 4.2 Phase 2 (Post-Cohort Engagement) - Priority P1

> **Goal:** Deliver promised inclusions, drive retention and upsells

#### 4.2.1 Office Hours Booking
- [ ] Cal.com integration for scheduling
- [ ] Available slots per instructor
- [ ] Booking confirmation emails
- [ ] 3-month eligibility enforcement
- [ ] Usage tracking (sessions booked/attended)

#### 4.2.2 Knowledge Chatbot
- [ ] OpenRouter integration
- [ ] Course-specific knowledge base
- [ ] Chat interface in learner portal
- [ ] Conversation history
- [ ] 1-year access enforcement

#### 4.2.3 Certificates (Open Badges 3.0)
- [ ] Certificate generation on cohort completion
- [ ] Open Badge 3.0 compliant credentials
- [ ] Verification URL system
- [ ] LinkedIn sharing integration
- [ ] Badge image generation
- [ ] PDF certificate export

#### 4.2.4 Email Automation (Brevo)
- [ ] Registration confirmation
- [ ] Cohort welcome (T-7 days)
- [ ] Tech check reminder (T-2 days)
- [ ] Post-cohort feedback request (+1 day)
- [ ] Office hours invitation (+3 days)
- [ ] Certificate delivery
- [ ] Monthly expert call invitations
- [ ] Access expiry reminders (30 days before)
- [ ] Upsell campaigns (next level course)

#### 4.2.5 B2B Post-Cohort Features
- [ ] Slack workspace integration (connect client Slack)
- [ ] Dedicated support channel
- [ ] Weekly office hours scheduling
- [ ] Executive Impact Report generation
- [ ] Team progress dashboard
- [ ] ROI metrics display

#### 4.2.6 Community (B2C)
- [ ] Alumni discussion forum
- [ ] Course-specific channels
- [ ] Peer networking features
- [ ] Instructor Q&A threads
- [ ] Upvoting and pinned posts

### 4.3 Phase 3 (E-Learning Expansion) - Priority P2

> **Goal:** Add self-paced content for passive income stream

#### 4.3.1 Self-Paced Course Structure
- [ ] Module/lesson hierarchy
- [ ] Video content hosting (move to own CDN or Mux)
- [ ] Drip schedule for content unlocking
- [ ] Lesson completion tracking
- [ ] Progress percentage display
- [ ] Resume where you left off

#### 4.3.2 Assessment & Quizzes
- [ ] Self-assessment quizzes (Study Mode style)
- [ ] Multiple choice, true/false, multi-select
- [ ] Instant feedback (not graded gates)
- [ ] AI-generated quiz questions (OpenRouter)
- [ ] Spaced repetition reminders

#### 4.3.3 Learning Dashboard
- [ ] All enrolled courses view
- [ ] Progress tracking per course
- [ ] Upcoming deadlines/milestones
- [ ] Achievement badges
- [ ] Study streak tracking

### 4.4 Phase 4 (Platform Features) - Priority P3

> **Goal:** Full LMS capabilities rivaling Thinkific/Maven

#### 4.4.1 Multi-Event Types
- [ ] Webinars (free/paid, one-time)
- [ ] Workshops (shorter format, 2-4 hours)
- [ ] Hackathons (competition format)
- [ ] Courses (current 2-day intensive)
- [ ] Subscriptions (ongoing access)

#### 4.4.2 Advanced AI Features
- [ ] Sidebar AI copilot (context-aware)
- [ ] Proactive AI coach (multi-layer memory)
- [ ] Personalized learning paths
- [ ] Content summarization
- [ ] Smart recommendations

#### 4.4.3 Subscription Models
- [ ] Monthly/annual subscriptions
- [ ] Tiered access levels
- [ ] Usage-based pricing options

#### 4.4.4 Marketplace Features
- [ ] Instructor profiles
- [ ] Course ratings and reviews
- [ ] Social proof badges
- [ ] Affiliate/referral program

---

## 5. Data Schema (Convex)

### 5.1 Core Tables

```typescript
// Users & Organizations
users              // Learners, instructors, admins
  - email, name, role, profileImage
  - linkedInUrl, bio, company, jobTitle
  - aiExperienceLevel, learningGoals
  - isPublicProfile

organizations      // B2B team accounts
  - name, domain, slackWorkspaceId
  - seats, adminUserId

// Course Structure
courses            // Course metadata and settings
  - title, description, slug
  - price, impactLevel, capabilityLevel
  - status (draft, published, archived)

sessions           // Session types within courses
  - courseId, title, type (S, W, MM, CAP, IO)
  - dayNumber, orderInDay, durationMinutes
  - description, outcomes[]

cohorts            // Scheduled course instances
  - courseId, startDate, endDate
  - maxCapacity, currentEnrollment
  - status (scheduled, open, in_progress, completed)
  - zoomLink, instructorId

// Enrollment & Access
enrollments        // User-cohort relationships
  - userId, cohortId, courseId
  - purchaseDate, paymentStatus
  - intakeSurveyCompleted
  - officeHoursEligibleUntil
  - materialsAccessUntil
  - chatbotAccessUntil

// Assets & Deliverables
enablementKitItems // Files in the Enablement Kit
  - courseId, title, type (slides, prompts, template, chatbot)
  - fileId (Convex file storage), externalUrl

sessionRecordings  // Post-cohort recordings
  - cohortId, sessionId
  - videoUrl, duration, uploadedAt

// Engagement
officeHoursBookings
  - enrollmentId, scheduledAt, calcomEventId
  - status (scheduled, completed, cancelled)

chatConversations  // Knowledge chatbot
  - enrollmentId, messages[]
  - createdAt, updatedAt

// Credentials
certificates       // Open Badge 3.0 credentials
  - enrollmentId, issuedAt
  - badgeData (JSON-LD)
  - verificationUrl, linkedInShareUrl

// Marketing & Sales
contactSubmissions // Enterprise inquiries
  - name, email, company, message
  - status (new, contacted, qualified, closed)

waitlist           // Course/cohort interest
  - email, courseId, cohortId
  - notifiedAt

// B2B Specific
executiveReports   // Impact reports for enterprise
  - organizationId, cohortId
  - metrics, generatedAt, pdfUrl
```

### 5.2 Key Relationships

```
User ─────────────┬──────────────────────────────────┐
                  │                                  │
                  ▼                                  ▼
            Enrollment ◄──────────────────────► Cohort
                  │                                  │
                  │                                  ▼
                  │                              Course
                  │                                  │
                  │                                  ├──► Session
                  │                                  │
                  ├──► OfficeHoursBooking           ├──► EnablementKitItem
                  │                                  │
                  ├──► ChatConversation             └──► SessionRecording
                  │
                  └──► Certificate
```

### 5.3 Event Types Schema (Phase 4)

```typescript
// Future: Multi-event type support
events
  - type (course, webinar, workshop, hackathon)
  - title, description, price
  - startDate, endDate, duration
  - maxCapacity, registrationDeadline
  - deliveryMethod (live, hybrid, recorded)
```

---

## 6. Integration Specifications

### 6.1 Stripe Integration

**Checkout Flow:**
1. User selects course/cohort
2. Create Stripe Checkout Session (with cohortId metadata)
3. Redirect to Stripe hosted page
4. On success, webhook creates enrollment
5. Set access expiry dates (3mo office hours, 1yr materials)
6. Send confirmation email via Brevo
7. Trigger Formbricks intake survey

**Webhook Events:**
- `checkout.session.completed` → Create enrollment, set access dates
- `payment_intent.succeeded` → Update payment status
- `charge.refunded` → Revoke access, update enrollment status

**Products:**
- AI Foundations: `price_foundations_749`
- AI Essentials: `price_essentials_1479`

### 6.2 Brevo Integration (MCP Available)

**Email Templates:**
| Template | Trigger | Variables |
|----------|---------|-----------|
| `welcome` | enrollment.created | userName, courseName, cohortDates |
| `reminder-7d` | cohort.startDate - 7 | userName, courseName, zoomLink |
| `reminder-2d` | cohort.startDate - 2 | userName, techCheckList |
| `zoom-link` | cohort.startDate - 1 | userName, zoomLink, schedule |
| `feedback` | cohort.endDate + 1 | userName, surveyLink |
| `office-hours` | cohort.endDate + 3 | userName, calcomLink |
| `certificate` | certificate.issued | userName, credentialUrl, linkedInUrl |
| `expert-call` | monthly schedule | userName, callLink, topic |
| `access-expiring` | accessExpiry - 30 | userName, expiryDate, renewLink |
| `upsell` | cohort.endDate + 14 | userName, nextCourse, discount |

**Lists:**
- Newsletter/Waitlist: List ID TBD
- Active Learners: List ID TBD
- Alumni: List ID TBD

### 6.3 Formbricks Integration

**Intake Survey Flow:**
1. User completes Stripe checkout
2. Redirect to success page with survey embed
3. Show Formbricks survey (inline widget)
4. On completion, mark `enrollment.intakeSurveyCompleted = true`
5. Store survey response ID for pre-cohort preparation

**Feedback Survey Flow:**
1. Scheduled job triggers at cohort.endDate + 1
2. Send email with embedded survey link
3. Track completion for NPS calculation

**Environment:** `cmhbcg6ty0009t6014kqfde0u`
**Host:** `forms.aienablement.academy`

### 6.4 PostHog Integration

**Key Events:**
| Event | Trigger | Properties |
|-------|---------|------------|
| `page_view` | All pages | path, referrer |
| `course_viewed` | Course detail page | courseId, impactLevel |
| `cohort_selected` | Cohort selection | cohortId, startDate |
| `checkout_started` | Begin payment | courseId, price |
| `checkout_completed` | Payment success | enrollmentId, revenue |
| `survey_completed` | Formbricks submit | surveyType |
| `recording_viewed` | Play recording | sessionId, duration |
| `kit_downloaded` | Download asset | assetType, assetId |
| `office_hours_booked` | Cal.com booking | bookingId |
| `chatbot_message` | AI chat | messageCount |
| `certificate_shared` | LinkedIn share | platform |

### 6.5 Cal.com Integration (Phase 2)

**Office Hours Flow:**
1. Learner clicks "Book Office Hours" in portal
2. Redirect to Cal.com booking page (instructor calendar)
3. Select available slot
4. Confirmation email via Cal.com
5. Webhook updates `officeHoursBookings` table
6. Track against 3-month eligibility window

### 6.6 Open Badges 3.0 Specification

**Badge Structure:**
```json
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "type": ["VerifiableCredential", "OpenBadgeCredential"],
  "issuer": {
    "id": "https://aienablement.academy",
    "name": "AI Enablement Academy"
  },
  "issuanceDate": "2025-01-15T00:00:00Z",
  "credentialSubject": {
    "id": "did:example:learner123",
    "achievement": {
      "id": "https://aienablement.academy/badges/ai-foundations",
      "name": "AI Foundations",
      "description": "Completed 2-day AI Foundations intensive with capstone project",
      "criteria": {
        "narrative": "Attended all 15 sessions across 2 days, completed hands-on workshops, and delivered capstone presentation"
      }
    }
  }
}
```

---

## 7. User Journeys

### 7.1 B2C Learner Journey

```
1. DISCOVER
   └── Land on homepage → Browse courses → Read testimonials

2. EVALUATE
   └── Compare Foundations vs Essentials → Check upcoming cohorts → Review pricing

3. PURCHASE
   └── Select cohort → Stripe Checkout → Payment confirmation

4. ONBOARD (Pre-Cohort)
   └── Complete intake survey → Receive welcome email → Access pre-work materials
   └── Tech check reminder → Receive Zoom link

5. LEARN (Live Cohort)
   └── Day 1: Sessions 1-7 (Fundamentals, Prompting, Labs, Mastermind)
   └── Day 2: Sessions 8-15 (Process Mapping, Research, Knowledge Mgmt, Capstone)

6. COMPLETE (Post-Cohort)
   └── Access recordings → Download Enablement Kit → Receive certificate
   └── Share on LinkedIn

7. ENGAGE (3 Months)
   └── Book weekly office hours → Use knowledge chatbot → Join monthly expert calls

8. ADVANCE
   └── Receive upsell for next level → Re-enroll → Continue journey
```

### 7.2 B2B Enterprise Journey

```
1. DISCOVER
   └── Land on homepage → See enterprise option → Review team programs

2. INQUIRE
   └── Submit contact form → Receive response → Schedule discovery call

3. CUSTOMIZE
   └── Pre-cohort audit → Custom proposal → Negotiate terms (e.g., $28.5K/20 seats)

4. CONTRACT
   └── Sign agreement → Receive invoice → Process payment

5. ONBOARD
   └── Connect Slack workspace → Assign seats → Invite team members
   └── Intake surveys per participant → Schedule cohort dates

6. DELIVER
   └── Custom cohort delivery → Daily Slack support → Track team progress

7. SUPPORT (3 Weeks Post-Cohort)
   └── Slack channel active → Weekly office hours → Answer questions

8. REPORT
   └── Generate Executive Impact Report → Present ROI → Plan next cohort
```

---

## 8. Design System

### 8.1 Prism Refraction Theme

The design system follows the "Scientific Cubism" aesthetic from v1:

**Color Palette:**
- Navy foundation: `#0B2B4A` (primary dark)
- Blue spectrum: `#42A5F5` (primary), `#23c0f1` (cyan accent)
- Warm spectrum: `#fbc952` (gold), `#fa5f2e` (coral)
- Hot spectrum: `#e350bb` (magenta), `#b364e7` (purple)

**Typography:**
- Display: DM Sans (headlines, CTAs)
- Body: IBM Plex Sans (content)
- Mono: IBM Plex Mono (code)

**Effects:**
- Glass morphism backgrounds
- Hard geometric shadows
- Angular shapes and crystalline sections
- Gradient CTAs

### 8.2 Component Library

Using shadcn/ui with custom theme tokens:
- Buttons (primary, secondary, ghost, destructive)
- Cards (course cards, pricing cards, testimonial cards)
- Forms (inputs, selects, checkboxes)
- Navigation (header, footer, mobile menu)
- Modals and dialogs
- Toast notifications
- Progress indicators
- Badge/tag components

---

## 9. Success Metrics

### 9.1 Business Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cohort Fill Rate | >80% | Enrolled / Max capacity |
| Conversion Rate | >3% | Purchases / Page visits |
| Cohort Completion | >95% | Attended Day 2 / Enrolled |
| NPS Score | >50 | Post-cohort survey |
| Revenue per Cohort | >$10K B2C, >$28K B2B | Monthly reporting |
| Office Hours Utilization | >50% | Booked / Eligible |
| Upsell Rate | >20% | Next level purchases / Completers |

### 9.2 Technical Metrics

| Metric | Target | Tool |
|--------|--------|------|
| Page Load Time | <2s | PostHog, Vercel Analytics |
| API Response Time | <200ms | Convex dashboard |
| Uptime | 99.9% | Vercel status |
| Error Rate | <0.1% | PostHog |

---

## 10. Development Phases

> Note: Phases are scope-based, not time-based. Each phase is complete when all features ship.

### Phase 0: Marketing Foundation
- [ ] Initialize Next.js 15 + Convex project
- [ ] Setup Vercel deployment pipeline
- [ ] Implement marketing pages (hero, catalog, pricing, about)
- [ ] Contact form → Brevo integration
- [ ] Newsletter signup → Brevo list
- [ ] Basic PostHog analytics

### Phase 1: Live Cohort MVP
- [ ] Convex schema for users, courses, cohorts, enrollments
- [ ] User authentication (Convex Auth)
- [ ] Stripe Checkout integration
- [ ] Payment webhooks → enrollment creation
- [ ] Pre-cohort email sequence (Brevo)
- [ ] Learner portal (enrolled cohorts, Zoom links, schedule)
- [ ] Post-cohort: recordings upload, Enablement Kit access
- [ ] Admin: cohort management, enrollment tracking

### Phase 2: Engagement & Credentials
- [ ] Cal.com integration for office hours
- [ ] Knowledge chatbot (OpenRouter)
- [ ] Certificate generation (Open Badges 3.0)
- [ ] LinkedIn sharing
- [ ] Community features (alumni forum)
- [ ] B2B Slack integration
- [ ] Executive Impact Report generation

### Phase 3: E-Learning Platform
- [ ] Self-paced course structure
- [ ] Video hosting (Mux or similar)
- [ ] Drip content scheduling
- [ ] Progress tracking
- [ ] Self-assessment quizzes
- [ ] Learning dashboard

### Phase 4: Platform Expansion
- [ ] Multi-event types (webinars, workshops, hackathons)
- [ ] Subscription billing
- [ ] Advanced AI features (copilot, coach)
- [ ] Marketplace features
- [ ] Advanced analytics dashboard

---

## 11. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Convex learning curve | Medium | Medium | Comprehensive docs, AI-assisted development |
| Stripe webhook reliability | High | Low | Retry logic, idempotency keys, manual fallback |
| Open Badges complexity | Medium | Medium | Use existing libraries, defer to Phase 2 |
| Video hosting costs | Low | Low | YouTube/Vimeo for Phase 0-2, evaluate Mux later |
| Email deliverability | Medium | Low | Brevo reputation, proper DNS (SPF, DKIM, DMARC) |
| Cal.com integration | Low | Medium | Simple redirect flow, manual fallback |
| AI chatbot quality | Medium | Medium | Curated knowledge base, human escalation path |

---

## 12. Platform Vision

### 12.1 Long-Term Trajectory

AI Enablement Academy will evolve into a full LMS platform:

```
Current: Service Provider (consulting + cohorts)
    ↓
Phase 2: Hybrid (cohorts + post-cohort digital)
    ↓
Phase 3: Product (self-paced e-learning + cohorts)
    ↓
Phase 4: Platform (marketplace, subscriptions, AI-native)
```

### 12.2 Competitive Positioning

| Competitor | Their Focus | Our Differentiation |
|------------|-------------|---------------------|
| Thinkific | Self-paced courses | Live cohorts + post-support |
| Maven | Cohort-based learning | AI focus + Enablement Kit |
| Moodle | Enterprise LMS | Modern UX, AI-native |
| Coursera | Mass education | Boutique, high-touch |

### 12.3 Future AI Features

| Feature | Description | Phase |
|---------|-------------|-------|
| Sidebar Copilot | Context-aware AI during learning | 4 |
| Proactive Coach | Multi-layer memory, personalized nudges | 4 |
| Study Mode AI | Flashcard generation, spaced repetition | 3 |
| Content Summarizer | Auto-summarize recordings | 3 |

---

## 13. Appendices

### A. Reference Documents
- `/specs/V1-Academy-Requirements.md` - Original v1 requirements
- `/specs/EPICS.md` - Task breakdown
- `/research/COMPREHENSIVE EDTECH_LEARNING ECOSYSTEM RESEARCH B.md` - Market research
- Talabat SOW - B2B contract template

### B. External Resources
- [Convex Documentation](https://docs.convex.dev)
- [Vercel Deployment](https://vercel.com/docs)
- [Open Badges 3.0 Spec](https://www.imsglobal.org/spec/ob/v3p0)
- [Formbricks SDK](https://formbricks.com/docs)
- [Brevo API](https://developers.brevo.com)
- [PostHog Docs](https://posthog.com/docs)
- [Cal.com API](https://cal.com/docs)

### C. Design Assets
- Prism logo: `/public/images/logo.svg`
- Founder photos: `/public/images/founders/`
- Course thumbnails: Convex file storage

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2025-12-02 | Technical Team | Initial v2 PRD with Convex stack |
| 2.1.0 | 2025-12-02 | Technical Team | Major restructure: Phase separation (Marketing → Live Cohorts → E-Learning), added Vercel deployment, user profiles, program inclusions, B2B features, session types, enablement kit, removed time estimates |
| 2.2.0 | 2025-12-03 | Technical Team | Updated to reflect v2.1 feature additions: Skills & Competencies System, Resource Library, Learning Paths, Community System, Assessment System (Pre/Post ROI), Manager Dashboard (B2B) |

---

**Next Steps:**
1. Review and approve this PRD
2. Create detailed technical specifications (Convex schema, API contracts)
3. Use claude-flow swarms for parallel spec development
4. Begin Phase 0 implementation
