# AI Enablement Academy v2 - SPARC Technical Specification

**Version:** 2.2.0
**Created:** 2025-12-02
**Last Updated:** 2025-12-03
**Based on:** PRD v2.2.0
**Methodology:** SPARC (Specification, Pseudocode, Architecture, Refinement, Completion)

---

## Executive Summary

Complete platform rebuild of the AI Enablement Academy using **Convex + Next.js 15 + Vercel**. This specification covers B2C and B2B (manual) enrollment support, multi-session types (cohorts, webinars, hackathons), 8 SDK integrations, Platform API, MCP Server for AI agent integration, and London School TDD approach.

**Key Technologies:**
- **Frontend:** Next.js 15 (App Router), React 19, shadcn/ui, Tailwind CSS
- **Backend:** Convex (serverless, real-time subscriptions)
- **Payments:** Stripe SDK (`@stripe/stripe-node`)
- **Email:** Brevo SDK (`@getbrevo/brevo`)
- **Analytics:** PostHog JS (`posthog-js`) - self-hosted
- **Surveys:** Formbricks JS (`@formbricks/js`) - self-hosted
- **Scheduling:** Cal.com (embed + webhooks)
- **AI/LLM:** OpenRouter SDK (`@openrouter/sdk`)
- **Package Manager:** pnpm (required), bun (optional for local dev speed)

---

## Document Structure

This specification is split into modular files for better maintainability, parallel development, and token efficiency:

| Section | File | Description |
|---------|------|-------------|
| Overview | [00-overview.md](sections/00-overview.md) | Executive summary, tech stack, key decisions |
| Schema | [01-schema.md](sections/01-schema.md) | Database schema (64 tables), Convex patterns |
| SDKs | [02-sdk-integrations.md](sections/02-sdk-integrations.md) | 11 SDK integration patterns with TypeScript |
| Learner Flows | [03a-pseudocode-learner.md](sections/03a-pseudocode-learner.md) | 6 learner user flows with FOMO/capacity |
| Admin Flows | [03b-pseudocode-admin.md](sections/03b-pseudocode-admin.md) | 4 admin flows including B2B, waitlist |
| System Flows | [03c-pseudocode-system.md](sections/03c-pseudocode-system.md) | Webhooks, crons, real-time, outbound webhooks |
| Skills/Resources Flows | [03d-pseudocode-skills-resources.md](sections/03d-pseudocode-skills-resources.md) | Skills tracking, competency evidence, resource library |
| Paths/Community Flows | [03e-pseudocode-paths-community.md](sections/03e-pseudocode-paths-community.md) | Learning paths, discussions, peer networking |
| Assessments/Manager Flows | [03f-pseudocode-assessments-manager.md](sections/03f-pseudocode-assessments-manager.md) | Pre/post assessments, manager dashboard, B2B analytics |
| Content Management Flows | [03g-pseudocode-content-management.md](sections/03g-pseudocode-content-management.md) | Blog authoring, landing pages, media library, collaboration |
| Architecture | [04-architecture.md](sections/04-architecture.md) | System diagrams, data flows, component hierarchy, mobile/accessibility, CMS architecture |
| Edge Cases | [05-edge-cases.md](sections/05-edge-cases.md) | Error handling, race conditions, retries |
| TDD Strategy | [06-tdd-strategy.md](sections/06-tdd-strategy.md) | London School TDD, 10 service interfaces |
| Epics & Phases | [07-epics-phases.md](sections/07-epics-phases.md) | 17 epics, 5 phases, 9 parallel streams |
| Platform API | [08-platform-api.md](sections/08-platform-api.md) | REST API spec, webhooks, rate limiting |
| MCP Server | [09-mcp-server.md](sections/09-mcp-server.md) | 16 MCP tools, 10 resources for AI agents |

---

## Key Design Decisions

### Authentication
- **Google OAuth** + **Magic Links** via Convex Auth
- Role-based access: `individual`, `org_admin`, `org_member`, `platform_admin`

### B2B Model
- **Manual process**: Admin creates org, sends invites, creates Stripe manual invoice
- No self-service B2B portal (intentional simplicity)
- Seat-based licensing with invite tokens

### Multi-Session Types
- One course can have multiple session types:
  - **Cohort**: 2-day intensive
  - **Webinar**: Single session
  - **Hackathon**: Multi-day event

### Capacity Management
- Real-time capacity indicators ("5 spots left!")
- FOMO triggers at >70% capacity
- Atomic validation in Stripe webhook (race condition fix)
- Cross-sell to future sessions when full

### Waitlist
- FIFO queue with automatic promotion
- 48-hour offer expiry
- Position notifications

### Cron Strategy
- **Convex crons**: Simple scheduled tasks (reminders, expiry checks)
- **n8n workflows**: Complex multi-step automation (reports, bulk operations)
- Hybrid coordination via webhooks

### Webhook Reliability
- Exponential backoff retry: 1s → 10s → 100s
- Dead Letter Queue after 3 failures
- Admin notifications for DLQ items

---

## Quick Start

### Reading the Spec
1. Start with [00-overview.md](sections/00-overview.md) for context
2. Review [01-schema.md](sections/01-schema.md) for data model
3. Follow flows in `03a`, `03b`, `03c` for user journeys
4. Check [07-epics-phases.md](sections/07-epics-phases.md) for implementation order

### Development Setup
```bash
# Clone and install
git clone <repo>
cd project-campfire-v2
pnpm install

# Start Convex
pnpm convex dev

# Start Next.js
pnpm dev

# Optional: Use bun for faster local dev
bun run dev
```

### Implementation Order
1. **Phase 0** (Week 1-2): Project setup, auth, schema
2. **Phase 1** (Week 3-6): Core MVP - B2C purchase, learner portal
3. **Phase 2** (Week 7-8): Post-cohort - recordings, chatbot, certificates
4. **Phase 3** (Week 9-11): B2B & admin dashboard
5. **Phase 4** (Week 12+): Platform API, MCP Server

---

## File Statistics

| File | Size | Purpose |
|------|------|---------|
| 00-overview.md | 9.6KB | Executive summary |
| 01-schema.md | 137KB | 57 database tables (v2.1 expansion) |
| 02-sdk-integrations.md | 53KB | 8 SDK patterns |
| 03a-pseudocode-learner.md | 15KB | 6 learner flows |
| 03b-pseudocode-admin.md | 77KB | 4 admin flows |
| 03c-pseudocode-system.md | 43KB | 4 system flows |
| 03d-pseudocode-skills-resources.md | 23KB | Skills & resources flows |
| 03e-pseudocode-paths-community.md | 34KB | Paths & community flows |
| 03f-pseudocode-assessments-manager.md | 55KB | Assessments & manager flows |
| 04-architecture.md | 69KB | Diagrams, ERD, mobile/accessibility |
| 05-edge-cases.md | 87KB | Error handling |
| 06-tdd-strategy.md | 153KB | Testing strategy |
| 07-epics-phases.md | 114KB | Implementation plan |
| 08-platform-api.md | 113KB | REST API spec |
| 09-mcp-server.md | 115KB | MCP tools & resources |

**Total:** ~1,097KB of comprehensive specification (v2.1)

---

## v2.1 Feature Additions (ICP-Aligned)

Based on comprehensive ICP research and EdTech market analysis, the following features have been added to the schema (`01-schema.md`):

### Skills & Competencies System
**ICP Alignment:** ICP-1 (L&D Leaders), ICP-4 (Functional Leaders)
- 8 new tables: `skills`, `competencies`, `courseSkills`, `lessonCompetencies`, `userSkillProgress`, `competencyEvidence`, `skillBadges`
- Skill taxonomy: Technical, Strategic, Leadership, Domain
- Competency tracking with evidence types (quiz, project, peer review, instructor assessment)
- Open Badges 3.0 integration for skill-level micro-credentials
- Queries: `getUserSkillProfile`, `getCourseSkillOutcomes`, `getSkillLeaderboard`, `suggestNextSkill`

### Resource Library System
**ICP Alignment:** ICP-7 (Independent Builders), ICP-3 (Change Leaders)
- 5 new tables: `resources`, `glossaryTerms`, `prompts`, `resourceInteractions`, `userBookmarks`
- Resource types: Templates, Frameworks, Checklists, Case Studies, Tool Guides, Videos, Articles
- AI Prompt Library with variables, model recommendations, and usage tracking
- Glossary with related terms, abbreviations, and skill mapping
- Access control tiers: Public, Registered, Enrolled, Course-Specific, Premium

### Learning Paths System
**ICP Alignment:** ICP-1 (L&D Leaders), ICP-5 (ELT)
- 4 new tables: `learningPaths`, `learningPathSteps`, `userPathEnrollments`, `pathCertificates`
- Course sequencing with unlock rules (immediate, sequential, time-based, completion-based)
- Bundle pricing with discounts
- Example paths: AI Foundations Track, AI Leadership Track, Domain Expert Track

### Community System
**ICP Alignment:** ICP-7 (Independent Builders), ICP-3 (Change Leaders)
- 8 new tables: `discussionThreads`, `discussionReplies`, `threadInteractions`, `replyInteractions`, `peerConnections`, `externalCommunityLinks`, `userCommunityMemberships`
- Strategy: Native for cohort Q&A, external integration (Circle/Skool/Discord) for deep community
- Peer networking with AI-suggested connections based on cohort, skills, industry
- Moderation workflows with status tracking

### Assessment System (Pre/Post ROI)
**ICP Alignment:** ICP-1 (L&D Leaders - ROI proof), ICP-4 (Functional Leaders)
- 5 new tables: `assessments`, `assessmentQuestions`, `assessmentAttempts`, `questionResponses`, `learningGainAnalytics`
- Assessment types: Pre-course, Post-course, Knowledge check, Skill assessment, Certification
- Question types: MC, Multiple select, True/False, Short answer, Rating scale, Open-ended
- Hake's normalized learning gain calculation for ROI measurement
- AI-assisted grading for open-ended questions

### Manager Dashboard System (B2B)
**ICP Alignment:** ICP-1 (L&D Leaders), ICP-4 (Functional Leaders), ICP-5 (ELT)
- 9 new tables: `organizationManagers`, `teams`, `teamMembers`, `organizationAnalytics`, `teamAnalytics`, `managerReports`, `learningReminders`, `userPrivacySettings`, `managerAccessLogs`
- Dashboard views: Executive Summary, Team Progress, Skills Heat Map
- Report types: Progress Summary, Individual Detail, Skill Matrix, ROI Analysis, Compliance
- Manager-initiated learning reminders with targeting (individual, team, at-risk, inactive)
- GDPR-compliant privacy controls

### Schema Statistics (Post v2.1)
| Category | Tables | Purpose |
|----------|--------|---------|
| Core | 18 | Users, courses, enrollments, payments |
| Skills | 8 | Competency tracking, micro-credentials |
| Resources | 5 | Templates, prompts, glossary |
| Learning Paths | 4 | Course sequencing |
| Community | 8 | Discussions, peer connections |
| Assessments | 5 | Pre/post ROI measurement |
| Manager Dashboard | 9 | B2B analytics, reports |
| **Total** | **57** | Complete learning platform |

---

## Future Roadmap

### v2.2 (Mid-term)
- **Adaptive Learning Engine** - Personalized content sequencing based on competency progress
- **AI Recommendations** - Course/content suggestions based on skills, goals, learning history

### v3.0 (Long-term)
- **Marketplace Model** - Third-party course creators
- **Enterprise SSO** - SAML/OIDC integration

### Out of Scope
- AR/VR learning experiences (hardware/content constraints)
- Full LMS feature parity (not competing with Canvas/Moodle)

---

## Version History

| Version | Date | Status | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-02 | Released | Initial SPARC specification |
| 2.0.0 | 2025-12-02 | Released | Modular split, SDK research, MCP server, Platform API |
| 2.1.0 | 2025-12-03 | Current | ICP-aligned features: Skills, Resources, Paths, Community, Assessments, Manager Dashboard |

---

## Contributing

When updating this specification:
1. Edit the relevant section file in `specs/sections/`
2. Update this index if adding new sections
3. Keep files under 25KB for token efficiency
4. Follow existing pseudocode patterns

---

*Generated with Claude Code swarm orchestration - 12 parallel agents*
