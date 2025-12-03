# AI Enablement Academy v2 - SPARC Technical Specification

**Version:** 2.1.0
**Date:** 2025-12-03
**Based on:** PRD v2.1.0
**Methodology:** SPARC (Specification, Pseudocode, Architecture, Refinement, Completion)

---

## Executive Summary

AI Enablement Academy v2 is a complete platform rebuild designed to deliver cohort-based AI education with enterprise-grade infrastructure. The platform leverages Convex for serverless, real-time backend operations and Next.js 15 for a modern, performant frontend experience deployed on Vercel.

The system supports both B2C self-service enrollment and B2B manual enrollment workflows, accommodating multiple session types including intensive cohorts, webinars, and hackathons. Eight production SDK integrations power core platform capabilities: Stripe for payments, Brevo for transactional email, PostHog for product analytics, Formbricks for user feedback, Cal.com for scheduling, OpenRouter for AI/LLM features, Convex for real-time data, and Vercel for deployment.

The platform exposes both a REST API and MCP (Model Context Protocol) Server for external integrations, enabling programmatic course management and AI agent interactions. Development follows the London School TDD approach with comprehensive service boundaries, integration testing, and webhook retry mechanisms for production reliability.

This specification provides complete implementation guidance using the SPARC methodology, from database schema through deployment architecture.

---

## Tech Stack Summary

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Frontend** | Next.js 15 (App Router) | React framework with server components |
| **UI Framework** | React 19 | Component library with concurrent features |
| **UI Components** | shadcn/ui | Accessible component system built on Radix UI |
| **Backend** | Convex | Serverless real-time database and functions |
| **Authentication** | Convex Auth | Google OAuth + Magic Links |
| **Payments** | Stripe SDK (@stripe/stripe-node) | Payment processing and subscription management |
| **Email** | Brevo SDK (@getbrevo/brevo) | Transactional email delivery |
| **Analytics** | PostHog JS (posthog-js) | Self-hosted product analytics |
| **Surveys** | Formbricks JS (@formbricks/js) | Self-hosted user feedback and NPS |
| **Scheduling** | Cal.com | Event scheduling with embed and webhooks |
| **AI/LLM** | OpenRouter SDK (@openrouter/sdk) | Multi-model AI inference |
| **Deployment** | Vercel | Edge deployment and serverless functions |
| **Package Manager** | pnpm (required) | Fast, disk-efficient package management |
| **Dev Speed** | bun (optional) | Optional faster local development runtime |

---

## Document Structure

This specification is organized into the following sections:

### 1. [Database Schema](./01-schema.md)
Complete Convex schema definition for 18 tables covering users, organizations, courses, sessions, enrollments, payments, communications, and system operations.

### 2. [SDK Integration Patterns](./02-sdk-integrations.md)
Integration architecture and patterns for all 8 production SDKs including authentication flows, error handling, webhook processing, and service boundaries.

### 3. Pseudocode Specifications
- **[3a. Learner User Flows](./03a-pseudocode-learner.md)** - B2C registration, enrollment, payment, learning journey
- **[3b. Admin User Flows](./03b-pseudocode-admin.md)** - B2B manual enrollment, course management, analytics
- **[3c. System Flows](./03c-pseudocode-system.md)** - Webhooks, cron jobs, background processes

### 4. [System Architecture](./04-architecture.md)
High-level architecture diagrams, component interactions, data flow patterns, real-time synchronization, and deployment topology.

### 5. [Edge Cases & Error Handling](./05-edge-cases.md)
Comprehensive edge case catalog covering payment failures, capacity management, webhook retries, race conditions, and recovery strategies.

### 6. [TDD Strategy & Service Boundaries](./06-tdd-strategy.md)
London School TDD implementation strategy, service boundaries, mock patterns, integration test design, and CI/CD pipeline configuration.

### 7. [Epic Definitions & Implementation Phases](./07-epics-phases.md)
Epic breakdown with acceptance criteria, dependencies, and phased implementation roadmap from MVP to production launch.

### 8. [Platform REST API](./08-platform-api.md)
External REST API specification for programmatic course management, enrollment automation, and third-party integrations.

### 9. [MCP Server Specification](./09-mcp-server.md)
Model Context Protocol server implementation for AI agent interactions, enabling Claude and other LLMs to manage courses, enrollments, and analytics programmatically.

---

## Key Design Decisions

### Authentication Strategy
**Decision:** Convex Auth with Google OAuth + Magic Links
**Rationale:**
- Convex Auth provides built-in session management and secure token handling
- Google OAuth reduces friction for professional learners (common work accounts)
- Magic links provide fallback for users without Google accounts or corporate SSO restrictions
- No password management reduces security surface area and support burden

### B2B Enrollment Model
**Decision:** Manual admin-driven process with manual Stripe invoicing
**Rationale:**
- Initial B2B volume doesn't justify automated billing infrastructure
- Manual process allows flexible pricing negotiation and custom contracts
- Admin creates organization, bulk-creates user accounts, sends magic link invites
- Stripe invoices sent manually outside platform for payment tracking
- Reduces development complexity for MVP while maintaining audit trail

### Multi-Session Type Architecture
**Decision:** One course can support multiple session types (cohorts, webinars, hackathons)
**Rationale:**
- Same course content delivered in different formats for different learner preferences
- Cohorts: intensive 2-day workshops with limited capacity and high touch
- Webinars: scalable live sessions with Q&A and recordings
- Hackathons: project-based collaborative events with team coordination
- Shared curriculum with type-specific scheduling and capacity rules

### Capacity Management & FOMO
**Decision:** Hard capacity limits with waitlist, FOMO triggers, and cross-sell
**Rationale:**
- Hard limits maintain cohort quality and instructor availability
- Waitlist with FIFO (first-in-first-out) promotion ensures fairness
- FOMO triggers (e.g., "3 spots left", "50% full") drive conversion
- Cross-sell alternative sessions when capacity reached
- Real-time capacity updates via Convex prevent race conditions

### Webhook & Cron Strategy
**Decision:** Hybrid approach using Convex crons + n8n for complex workflows
**Rationale:**
- Convex crons handle simple scheduled tasks (reminders, session start notifications)
- n8n handles complex multi-step workflows (payment reconciliation, analytics aggregation)
- Webhook retry with exponential backoff (1s, 5s, 30s, 5m, 30m)
- Dead letter queue for failed webhooks after 5 retry attempts
- Idempotency keys prevent duplicate processing

### Real-Time Updates
**Decision:** Convex subscriptions for live data synchronization
**Rationale:**
- Course capacity updates in real-time across all client sessions
- Live enrollment counts and waitlist positions
- Instant notification delivery for critical updates
- Reduces polling overhead and improves UX responsiveness

### TDD Approach
**Decision:** London School TDD with strict service boundaries
**Rationale:**
- Outside-in development from user stories to implementation
- Mock external SDKs (Stripe, Brevo, etc.) for fast unit tests
- Integration tests verify SDK contracts in isolated environments
- Service boundaries prevent coupling and enable parallel development
- CI/CD runs full test suite on every commit to main

### Package Management
**Decision:** pnpm required, bun optional for local dev
**Rationale:**
- pnpm provides fast, disk-efficient installs with strict dependency resolution
- Required for CI/CD consistency across team and deployment environments
- bun optional for individual developers who want faster local dev server startup
- Both compatible with same package.json and lock files

### API & MCP Server
**Decision:** Dual external interface - REST API + MCP Server
**Rationale:**
- REST API serves traditional integrations (CRM, marketing automation, analytics)
- MCP Server enables AI agent interactions for course management and learner support
- Both share same Convex backend for consistency
- MCP Server provides structured tool interface for LLM function calling
- Enables future AI-driven course recommendations and automated support

---

## Next Steps

1. **Schema Review** - Validate database design with stakeholders (Section 01)
2. **SDK Integration** - Configure and test all 8 production SDKs (Section 02)
3. **Flow Implementation** - Build core user flows following TDD (Sections 03, 06)
4. **Architecture Validation** - Review deployment topology and scaling plan (Section 04)
5. **Edge Case Testing** - Implement comprehensive error handling (Section 05)
6. **Epic Planning** - Prioritize implementation phases with product team (Section 07)
7. **API Development** - Build and document external integrations (Sections 08, 09)

---

## Document Conventions

Throughout this specification:
- **MUST** indicates required implementation
- **SHOULD** indicates recommended best practice
- **MAY** indicates optional enhancement
- Code examples use TypeScript with Convex types
- Pseudocode follows structured natural language format
- Edge cases include both prevention and recovery strategies

---

**Document Status:** Draft v2.1.0
**Last Updated:** 2025-12-03
**Contributors:** Product, Engineering, Design
**Review Cycle:** Weekly until implementation complete
