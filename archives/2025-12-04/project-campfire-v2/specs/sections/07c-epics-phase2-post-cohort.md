# Phase 2: Post-Cohort

**Duration:** Week 7-8
**Focus:** Recordings, chatbot, certificates, CMS
**Key Deliverables:** Content delivery, AI support, credentials

## Worktree Strategy

Phase 2 enables fully parallel development - no blocking dependencies between epics:

```
develop
├── worktree/phase2-recordings   (E2.1) - Frontend/Backend stream
├── worktree/phase2-office       (E2.2) - Integration stream
├── worktree/phase2-chatbot      (E2.3) - AI/ML stream
├── worktree/phase2-certs        (E2.4) - Backend stream
└── worktree/phase2-cms          (E2.5) - Frontend/Backend stream
```

**Branch Naming:** `phase2/<epic>/<area>-<feature>`
**Example:** `phase2/E2.3/ai-openrouter-streaming`

---

## E2.1 - Recordings & Materials

**Owner:** Frontend Lead
**Duration:** 4 days
**Priority:** P1 - High Value
**Branch:** `phase2/E2.1/frontend-recordings`

**User Story:**
> As a learner who completed a cohort, I need access to session recordings and enablement kits so that I can review and apply what I learned.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E2.1-001 | Setup Vercel Blob Storage | `DEVOPS` | 1 | - | E0.1 | - |
| E2.1-002 | Create recording upload mutation | `BACKEND` | 2 | - | E2.1-001 | - |
| E2.1-003 | Implement chunked upload for large files | `BACKEND` | 3 | - | E2.1-002 | - |
| E2.1-004 | Build admin recording upload form | `FRONTEND` | 2.5 | - | E2.1-002 | - |
| E2.1-005 | Link recording to cohort | `BACKEND` `DB` | 1 | ✅ | E2.1-002 | - |
| E2.1-006 | Support multiple recordings per cohort | `BACKEND` | 1.5 | ✅ | E2.1-005 | - |
| E2.1-007 | Build video player component | `FRONTEND` | 3 | ✅ | E0.1 | - |
| E2.1-008 | Add playback speed control | `FRONTEND` | 1 | ✅ | E2.1-007 | - |
| E2.1-009 | Add fullscreen mode | `FRONTEND` | 0.5 | ✅ | E2.1-007 | - |
| E2.1-010 | Build transcript display (if available) | `FRONTEND` | 2 | ✅ | E2.1-007 | - |
| E2.1-011 | Build recordings list in cohort detail | `FRONTEND` | 2 | - | E2.1-006 | - |
| E2.1-012 | Build enablement kit list component | `FRONTEND` | 2 | ✅ | E1.4-010 | - |
| E2.1-013 | Implement PDF preview | `FRONTEND` | 2 | ✅ | E2.1-012 | - |
| E2.1-014 | Implement download with tracking | `BACKEND` | 2 | - | E2.1-012 | - |
| E2.1-015 | Generate signed URLs for access control | `BACKEND` | 2 | - | E2.1-001 | - |
| E2.1-016 | Auto-generate video thumbnails | `BACKEND` `API` | 2 | 🔀 | E2.1-002 | - |
| E2.1-017 | Log downloads in auditLog | `BACKEND` | 1 | - | E2.1-014 | - |
| E2.1-018 | Recordings E2E tests | `TESTING` | 2 | - | E2.1-017 | - |

**Area Legend:**
- `FRONTEND` - Video player, upload forms, UI
- `BACKEND` - File handling, signed URLs
- `API` - Cloudinary/thumbnail generation
- `DB` - Recording metadata
- `DEVOPS` - Blob storage config
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Upload):** E2.1-001 → E2.1-002 → E2.1-003/004/005/006
- **Stream B (Playback):** E2.1-007 → E2.1-008/009/010 (independent)
- **Stream C (Downloads):** E2.1-012 → E2.1-013/014 → E2.1-017

**Acceptance Criteria:**
- [ ] Admins can upload recordings via admin dashboard
- [ ] Recordings appear in cohort detail page after upload
- [ ] Video player works on all major browsers
- [ ] Downloads tracked in auditLog table
- [ ] Access restricted to enrolled learners only
- [ ] Large files (>100MB) upload successfully
- [ ] Video thumbnails auto-generated

**Dependencies:** E1.4 (Learner Portal - displays recordings)
**Risks:** Large file uploads may timeout (implement chunked uploads)

---

## E2.2 - Office Hours

**Owner:** Backend Lead
**Duration:** 3 days
**Priority:** P2 - Nice to Have
**Branch:** `phase2/E2.2/integration-calcom`

**User Story:**
> As a learner who completed a cohort, I need to book office hours with instructors so that I can get personalized help.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E2.2-001 | Setup Cal.com account for instructors | `DEVOPS` | 1 | - | - | - |
| E2.2-002 | Create Cal.com embed component | `FRONTEND` | 2 | - | E2.2-001 | - |
| E2.2-003 | Pass user email for pre-fill | `FRONTEND` | 0.5 | ✅ | E2.2-002 | - |
| E2.2-004 | Create webhook endpoint for Cal.com | `BACKEND` `API` | 2 | - | E2.2-001 | - |
| E2.2-005 | Verify webhook signature | `BACKEND` | 1 | - | E2.2-004 | - |
| E2.2-006 | Handle booking.created event | `BACKEND` | 2 | - | E2.2-005 | - |
| E2.2-007 | Create officeHourBookings record | `BACKEND` `DB` | 1.5 | - | E2.2-006 | - |
| E2.2-008 | Implement eligibility check query | `BACKEND` | 2 | ✅ | E0.3 | - |
| E2.2-009 | Check booking quota before widget display | `FRONTEND` `BACKEND` | 1.5 | - | E2.2-008 | - |
| E2.2-010 | Send booking confirmation email | `BACKEND` `API` | 1.5 | - | E2.2-007 | - |
| E2.2-011 | Build booking history page | `FRONTEND` | 2.5 | ✅ | E2.2-007 | - |
| E2.2-012 | Display past/upcoming bookings | `FRONTEND` | 1.5 | ✅ | E2.2-011 | - |
| E2.2-013 | Show join link (Zoom/Google Meet) | `FRONTEND` | 1 | ✅ | E2.2-011 | - |
| E2.2-014 | Office hours E2E tests | `TESTING` | 2 | - | E2.2-013 | - |

**Area Legend:**
- `FRONTEND` - Cal.com embed, booking UI
- `BACKEND` - Webhook handling, eligibility
- `API` - Cal.com integration
- `DB` - Booking records
- `DEVOPS` - Account setup
- `TESTING` - E2E tests

**Acceptance Criteria:**
- [ ] Cal.com widget embeds correctly
- [ ] Booking creates officeHourBookings record
- [ ] Ineligible learners see error message
- [ ] Booking confirmation email sent
- [ ] Booking history page displays all bookings
- [ ] Webhook signature verified
- [ ] Quota enforcement prevents overbooking

**Dependencies:** E1.4 (Learner Portal - displays widget)
**Risks:** Cal.com webhook reliability (implement retry logic)

---

## E2.3 - Knowledge Chatbot

**Owner:** Backend Lead
**Duration:** 5 days
**Priority:** P1 - High Value
**Branch:** `phase2/E2.3/ai-chatbot`

**User Story:**
> As a learner, I need an AI chatbot to answer questions about course materials so that I can get help 24/7.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E2.3-001 | Setup OpenRouter SDK configuration | `BACKEND` `API` | 1.5 | - | E0.1 | - |
| E2.3-002 | Create conversation mutation | `BACKEND` `DB` | 2 | - | E2.3-001 | - |
| E2.3-003 | Link conversation to user and cohort | `BACKEND` | 1 | ✅ | E2.3-002 | - |
| E2.3-004 | Build context retrieval from course materials | `BACKEND` `AI/ML` | 3 | - | E2.3-002 | - |
| E2.3-005 | Implement streaming response from OpenRouter | `BACKEND` `AI/ML` | 3 | - | E2.3-001 | - |
| E2.3-006 | Save user messages to database | `BACKEND` `DB` | 1 | - | E2.3-002 | - |
| E2.3-007 | Save assistant messages incrementally | `BACKEND` `DB` | 2 | - | E2.3-005 | - |
| E2.3-008 | Retrieve conversation history | `BACKEND` | 1.5 | ✅ | E2.3-002 | - |
| E2.3-009 | Build chat UI container | `FRONTEND` | 2 | ✅ | E1.4-001 | - |
| E2.3-010 | Build message list with avatars | `FRONTEND` | 2 | ✅ | E2.3-009 | - |
| E2.3-011 | Build input field with send button | `FRONTEND` | 1 | ✅ | E2.3-009 | - |
| E2.3-012 | Build typing indicator | `FRONTEND` | 1 | ✅ | E2.3-009 | - |
| E2.3-013 | Implement markdown rendering | `FRONTEND` | 1.5 | ✅ | E2.3-010 | - |
| E2.3-014 | Implement code syntax highlighting | `FRONTEND` | 1.5 | ✅ | E2.3-010 | - |
| E2.3-015 | Connect UI to streaming backend | `FRONTEND` `BACKEND` | 2 | - | E2.3-005, E2.3-010 | - |
| E2.3-016 | Load conversation history on page load | `FRONTEND` | 1.5 | - | E2.3-008 | - |
| E2.3-017 | Implement access control (enrolled only) | `BACKEND` | 2 | - | E2.3-002 | - |
| E2.3-018 | Implement rate limiting (50/day/user) | `BACKEND` | 2 | - | E2.3-006 | - |
| E2.3-019 | Mobile-responsive chat interface | `FRONTEND` | 1.5 | - | E2.3-015 | - |
| E2.3-020 | Chatbot E2E tests | `TESTING` | 2.5 | - | E2.3-019 | - |

**Area Legend:**
- `FRONTEND` - Chat UI components
- `BACKEND` - Conversation handling
- `AI/ML` - LLM integration, context building
- `API` - OpenRouter SDK
- `DB` - Message storage
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Backend):** E2.3-001 → E2.3-002 → E2.3-004/005 → E2.3-006/007
- **Stream B (Frontend):** E2.3-009 → E2.3-010/011/012/013/014
- **Stream C (Integration):** E2.3-015 → E2.3-016 → E2.3-019

**Acceptance Criteria:**
- [ ] Chat interface renders correctly
- [ ] Messages stream in real-time (no full response wait)
- [ ] Conversation history persists across sessions
- [ ] Access restricted to enrolled learners
- [ ] Chatbot references course materials correctly
- [ ] Rate limiting enforced
- [ ] Code blocks render with syntax highlighting
- [ ] Mobile-responsive chat interface

**Dependencies:** E1.4 (Learner Portal - hosts chat)
**Risks:** OpenRouter API costs (implement budget limits)

---

## E2.4 - Certificates

**Owner:** Backend Lead
**Duration:** 4 days
**Priority:** P1 - High Value
**Branch:** `phase2/E2.4/backend-certificates`

**User Story:**
> As a learner who completed a cohort, I need a verifiable digital certificate so that I can showcase my achievement on LinkedIn.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E2.4-001 | Design certificate PDF template | `DOCS` | 2 | ✅ | - | - |
| E2.4-002 | Implement Open Badges 3.0 JSON generation | `BACKEND` | 3 | - | E0.3 | - |
| E2.4-003 | Generate badge image (logo, colors) | `BACKEND` | 2 | ✅ | E2.4-002 | - |
| E2.4-004 | Implement issuer information | `BACKEND` | 1 | ✅ | E2.4-002 | - |
| E2.4-005 | Implement recipient identifier (email hash) | `BACKEND` | 1 | ✅ | E2.4-002 | - |
| E2.4-006 | Implement PDF certificate generation | `BACKEND` | 4 | - | E2.4-001 | - |
| E2.4-007 | Add QR code for verification URL | `BACKEND` | 1.5 | - | E2.4-006 | - |
| E2.4-008 | Generate unique certificate ID | `BACKEND` | 0.5 | ✅ | E2.4-002 | - |
| E2.4-009 | Build certificate verification endpoint | `BACKEND` `API` | 2 | - | E2.4-002 | - |
| E2.4-010 | Build public verification page | `FRONTEND` | 2.5 | - | E2.4-009 | - |
| E2.4-011 | Implement LinkedIn share URL generation | `BACKEND` | 1.5 | ✅ | E2.4-002 | - |
| E2.4-012 | Build LinkedIn share button | `FRONTEND` | 1 | - | E2.4-011 | - |
| E2.4-013 | Trigger certificate on enrollment completion | `BACKEND` | 2 | - | E2.4-006 | - |
| E2.4-014 | Implement async job queue for generation | `BACKEND` | 2 | - | E2.4-013 | - |
| E2.4-015 | Build certificate display in portal | `FRONTEND` | 2 | - | E2.4-006 | - |
| E2.4-016 | Build PDF download button | `FRONTEND` | 1 | ✅ | E2.4-015 | - |
| E2.4-017 | Validate against Open Badges 3.0 spec | `TESTING` | 2 | - | E2.4-002 | - |
| E2.4-018 | Certificates E2E tests | `TESTING` | 2 | - | E2.4-016 | - |

**Area Legend:**
- `BACKEND` - Badge/PDF generation, verification
- `FRONTEND` - Display, share buttons
- `API` - Verification endpoint
- `DOCS` - Template design
- `TESTING` - Validation, E2E

**Parallel Streams:**
- **Stream A (Badges):** E2.4-002 → E2.4-003/004/005/008/011
- **Stream B (PDF):** E2.4-001 → E2.4-006 → E2.4-007 → E2.4-013
- **Stream C (Verification):** E2.4-009 → E2.4-010
- **Stream D (UI):** E2.4-015 → E2.4-012/016

**Acceptance Criteria:**
- [ ] Certificate generated when enrollment marked complete
- [ ] PDF downloadable from learner portal
- [ ] Open Badges JSON validates against 3.0 spec
- [ ] LinkedIn share button redirects correctly
- [ ] Verification page shows badge details
- [ ] Certificate includes unique verifiable ID
- [ ] QR code on PDF links to verification page

**Dependencies:** E1.4 (Learner Portal - displays certificate)
**Risks:** PDF generation performance (implement async job queue)

---

## E2.5 - Content Management System

**Owner:** Frontend Lead
**Duration:** 6 days
**Priority:** P1 - High Value
**Branch:** `phase2/E2.5/frontend-cms`

**User Story:**
> As a platform admin, I need a visual content editor so that I can create and manage blog posts, landing pages, and course materials without writing code.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E2.5-001 | Setup BlockNote editor | `FRONTEND` | 2 | - | E0.1 | - |
| E2.5-002 | Implement Convex real-time sync for BlockNote | `FRONTEND` `BACKEND` | 3 | - | E2.5-001 | - |
| E2.5-003 | Build blog post CRUD (list, create, edit, delete) | `FRONTEND` `BACKEND` | 4 | - | E2.5-002 | - |
| E2.5-004 | Setup Puck page builder | `FRONTEND` | 2 | ✅ | E0.1 | - |
| E2.5-005 | Build Hero component for Puck | `FRONTEND` | 1.5 | ✅ | E2.5-004 | - |
| E2.5-006 | Build CTA component for Puck | `FRONTEND` | 1 | ✅ | E2.5-004 | - |
| E2.5-007 | Build Features component for Puck | `FRONTEND` | 1.5 | ✅ | E2.5-004 | - |
| E2.5-008 | Build Testimonials component for Puck | `FRONTEND` | 1.5 | ✅ | E2.5-004 | - |
| E2.5-009 | Build Pricing component for Puck | `FRONTEND` | 1.5 | ✅ | E2.5-004 | - |
| E2.5-010 | Build FAQ component for Puck | `FRONTEND` | 1 | ✅ | E2.5-004 | - |
| E2.5-011 | Implement Puck page save/load | `FRONTEND` `BACKEND` | 2 | - | E2.5-010 | - |
| E2.5-012 | Build media library with folder organization | `FRONTEND` `BACKEND` | 4 | ✅ | E2.1-001 | - |
| E2.5-013 | Implement content versioning (last 10) | `BACKEND` `DB` | 2.5 | - | E2.5-003 | - |
| E2.5-014 | Build version history UI with restore | `FRONTEND` | 2 | - | E2.5-013 | - |
| E2.5-015 | Implement publish/schedule workflow | `BACKEND` | 2.5 | - | E2.5-003 | - |
| E2.5-016 | Build draft/published status UI | `FRONTEND` | 1.5 | - | E2.5-015 | - |
| E2.5-017 | Implement SEO metadata management | `FRONTEND` `BACKEND` | 2 | ✅ | E2.5-003 | - |
| E2.5-018 | Implement real-time collaborative editing | `FRONTEND` `BACKEND` | 3 | - | E2.5-002 | - |
| E2.5-019 | Render published content on public routes | `FRONTEND` | 2 | - | E2.5-015 | - |
| E2.5-020 | CMS E2E tests | `TESTING` | 3 | - | E2.5-019 | - |

**Area Legend:**
- `FRONTEND` - Editors, UI components
- `BACKEND` - CRUD, real-time sync
- `DB` - Versioning, content storage
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (BlockNote):** E2.5-001 → E2.5-002 → E2.5-003 → E2.5-013/015/018
- **Stream B (Puck):** E2.5-004 → E2.5-005/006/007/008/009/010 → E2.5-011
- **Stream C (Media):** E2.5-012 (independent)

**Acceptance Criteria:**
- [ ] Admin can create/edit blog posts with BlockNote
- [ ] Admin can build landing pages with Puck drag-drop
- [ ] Media can be uploaded and organized in folders
- [ ] Content has draft/published status workflow
- [ ] Version history shows last 10 versions with restore
- [ ] Published content renders on public routes
- [ ] Real-time collaboration works with 2+ users

**Dependencies:** E0.2 (Authentication - role-based access), E0.3 (Database Schema)
**Risks:** ProseMirror sync complexity (use proven patterns)

---

## Phase 2 Summary

**Total Duration:** ~22 days (4.4 weeks) sequential, ~10-12 days with parallelization
**Total Tasks:** 90 tasks

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `FRONTEND` | 45 | ~62h |
| `BACKEND` | 38 | ~55h |
| `AI/ML` | 4 | ~9h |
| `API` | 6 | ~8h |
| `DB` | 8 | ~10h |
| `DEVOPS` | 3 | ~3h |
| `TESTING` | 6 | ~13.5h |
| `DOCS` | 2 | ~4h |
| **Total** | **90 tasks** | **~164.5h** |

### Parallel Execution Plan

With 3 engineers, Phase 2 compresses to **~10-12 days**:

| Day | Engineer 1 (Frontend) | Engineer 2 (Backend) | Engineer 3 (AI/Full-Stack) |
|-----|----------------------|---------------------|---------------------------|
| 1-2 | E2.1 Video player | E2.1 Upload + Blob | E2.3 OpenRouter setup |
| 3-4 | E2.1 Recordings UI | E2.1 Signed URLs | E2.3 Context + Streaming |
| 5-6 | E2.5 BlockNote setup | E2.2 Cal.com webhooks | E2.3 Chat UI |
| 7-8 | E2.5 Puck components | E2.4 Badges JSON | E2.3 Integration |
| 9-10 | E2.5 Versioning/Media | E2.4 PDF generation | E2.2 UI + Testing |
| 11-12 | E2.5 Publishing | E2.4 Verification | All E2E tests |

### Deliverables:
- ✅ Session recordings with playback and download tracking
- ✅ Office hours booking with Cal.com integration
- ✅ AI-powered knowledge chatbot with streaming
- ✅ Verifiable certificates with Open Badges 3.0
- ✅ Content management system with visual editors

**Next Phase:** [Phase 3 (B2B & Admin)](./07d-epics-phase3-b2b-admin.md) - Week 9-11
