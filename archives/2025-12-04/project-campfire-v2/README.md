# AI Enablement Academy v2

## Overview

**Project Campfire v2** is a complete platform rebuild of the AI Enablement Academy using modern cloud-native technologies. It's a cohort-based AI learning platform designed to deliver transformative AI enablement to organizations.

### Key Features
- **Cohort-Based Learning**: Structured 2-day intensives and ongoing workshops
- **Flexible Pricing**: B2C ($749-$1,479) and B2B (manual enrollment) support
- **Real-Time Collaboration**: WebSocket-powered live sessions and peer interaction
- **Comprehensive Analytics**: Self-hosted PostHog for learning metrics
- **Survey Integration**: Built-in feedback loops with Formbricks
- **Serverless Architecture**: Scalable, maintainable, zero-ops deployment

---

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| **Next.js** | 15 | Frontend (App Router, React 19, Server Components) |
| **Convex** | Latest | Backend (serverless, real-time database, API) |
| **React** | 19 | UI component library |
| **TypeScript** | 5.x | Type safety |
| **Stripe** | Latest API | Payment processing and subscriptions |
| **Brevo** | MCP API | Email automation and marketing |
| **PostHog** | Self-hosted | Product analytics and feature flags |
| **Formbricks** | Self-hosted | Survey and feedback collection |
| **Cal.com** | Public API | Office hours and meeting scheduling |
| **OpenRouter** | Latest | AI chatbot backend (model-agnostic) |
| **Vercel** | Latest | Deployment platform and serverless functions |
| **Playwright** | 4.x | End-to-end testing |
| **Vitest** | Latest | Unit testing framework |
| **pnpm** | 9.x | Package manager (required) |

---

## Quick Start

### Prerequisites
- **Node.js**: 20.x or later
- **pnpm**: 9.x or later (`npm install -g pnpm`)
- **Convex Account**: Free tier at https://www.convex.dev
- **Environment variables**: See `.env.example`

### Installation & Development

```bash
# Clone the repository
git clone https://github.com/ai-enablement-academy/project-campfire-v2.git
cd project-campfire-v2

# Install dependencies (pnpm REQUIRED)
pnpm install

# Configure environment
cp .env.example .env.local
# Edit .env.local with your API keys

# Start Convex dev server (required first)
pnpm convex dev

# In another terminal, start Next.js
pnpm dev

# Open browser to http://localhost:3000
```

### Alternative: Faster Local Development with Bun

```bash
# Install bun (if not already installed)
curl -fsSL https://bun.sh/install | bash

# Use bun for faster startup
bun run dev

# Run tests with bun
bun test
```

### Useful Development Commands

```bash
# Database
pnpm convex dev              # Start Convex dev environment
pnpm convex shell            # Interact with database directly
pnpm convex push             # Deploy schema to production

# Frontend
pnpm dev                      # Start Next.js dev server
pnpm build                    # Production build
pnpm start                    # Run production server

# Testing
pnpm test                     # Run all tests
pnpm test:watch               # Watch mode
pnpm test:ui                  # Open test UI
pnpm e2e                      # Run Playwright E2E tests

# Code Quality
pnpm lint                     # Run ESLint
pnpm format                   # Format with Prettier
pnpm type-check               # TypeScript type checking
```

---

## Project Structure

```
project-campfire-v2/
├── app/                              # Next.js App Router (React Server Components)
│   ├── (auth)/                       # Authentication pages
│   ├── (dashboard)/                  # Protected routes
│   │   ├── cohorts/                  # Cohort management
│   │   ├── learning/                 # Learning experiences
│   │   ├── admin/                    # Admin dashboard
│   │   └── account/                  # User account settings
│   ├── api/                          # API routes (if needed)
│   ├── layout.tsx                    # Root layout
│   └── page.tsx                      # Homepage
│
├── components/                       # Reusable React components
│   ├── ui/                           # UI primitives (shadcn/ui)
│   ├── forms/                        # Form components
│   ├── sections/                     # Page sections
│   ├── cohorts/                      # Cohort-specific components
│   └── admin/                        # Admin components
│
├── convex/                           # Convex backend
│   ├── schema.ts                     # Database schema (18 tables)
│   ├── http.ts                       # HTTP endpoint configuration
│   ├── functions/                    # Query and mutation functions
│   │   ├── users.ts
│   │   ├── cohorts.ts
│   │   ├── enrollments.ts
│   │   ├── sessions.ts
│   │   ├── payments.ts
│   │   └── analytics.ts
│   └── auth.ts                       # Authentication setup
│
├── lib/                              # Utility functions
│   ├── auth/                         # Authentication helpers
│   ├── stripe/                       # Stripe integration
│   ├── brevo/                        # Email integration
│   ├── posthog/                      # Analytics
│   ├── validators/                   # Input validation
│   └── constants.ts                  # App constants
│
├── specs/                            # SPARC Specification (documentation)
│   ├── SPARC-SPECIFICATION.md        # Complete specification index
│   ├── PRD.md                        # Product Requirements Document v2.1.0
│   └── sections/                     # Modular specification documents
│       ├── 01-overview.md
│       ├── 02-sdk-integrations.md
│       ├── 03-database-schema.md
│       ├── 04-user-flows.md
│       ├── 05-payment-flows.md
│       ├── 06-admin-flows.md
│       ├── 07-epics-phases.md
│       └── 08-implementation-guide.md
│
├── tests/                            # Test files (mirror app structure)
│   ├── unit/                         # Unit tests (Vitest)
│   ├── integration/                  # Integration tests
│   └── e2e/                          # End-to-end tests (Playwright)
│
├── public/                           # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── .env.example                      # Environment variables template
├── .env.local                        # Local environment variables (git ignored)
├── next.config.js                    # Next.js configuration
├── tsconfig.json                     # TypeScript configuration
├── vitest.config.ts                  # Vitest configuration
├── playwright.config.ts              # Playwright configuration
├── convex.json                       # Convex project configuration
├── pnpm-lock.yaml                    # pnpm lockfile (do NOT edit manually)
└── README.md                         # This file
```

---

## Specifications & Documentation

### Complete Specification
The **SPARC Specification** (`specs/SPARC-SPECIFICATION.md`) is the single source of truth for the platform design:

- **Database Schema**: 18 tables with relationships, constraints, and example data
- **API & SDK Integration**: 8 SDKs (Stripe, Brevo, PostHog, Formbricks, Cal.com, OpenRouter, Convex, Vercel)
- **User Flows**: Complete learner journey, instructor workflows, admin operations
- **Payment Architecture**: Subscription tiers, usage-based pricing, refund logic
- **Admin Operations**: Cohort creation, roster management, analytics dashboards
- **System Architecture**: Real-time updates, WebSocket patterns, error handling
- **Implementation Phases**: 16 epics spanning 12 weeks
- **Pseudocode Examples**: Reference implementations for key flows

### Product Requirements Document (PRD)
See `specs/PRD.md` for:
- Strategic rationale and market opportunity
- Feature specifications with acceptance criteria
- Success metrics and analytics framework
- Competitive analysis and positioning
- Roadmap and future vision

### Quick Navigation
```
📋 Full Specification:    specs/SPARC-SPECIFICATION.md
📦 Product Requirements:  specs/PRD.md
🗂️  Modular Sections:    specs/sections/

Key Sections:
├── 01-overview.md              → Platform vision and positioning
├── 02-sdk-integrations.md      → Integration patterns and examples
├── 03-database-schema.md       → Complete schema with 18 tables
├── 04-user-flows.md            → Step-by-step user journeys
├── 05-payment-flows.md         → Stripe integration and pricing
├── 06-admin-flows.md           → Administrative operations
├── 07-epics-phases.md          → 16 implementation epics
└── 08-implementation-guide.md  → Getting started guide
```

---

## Environment Variables

Create `.env.local` from `.env.example` and configure:

### Required
```env
# Convex
NEXT_PUBLIC_CONVEX_URL=https://your-team.convex.cloud

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Brevo (Email)
BREVO_API_KEY=...
NEXT_PUBLIC_BREVO_EMAIL_FROM=noreply@aienablement.academy

# PostHog (Analytics)
NEXT_PUBLIC_POSTHOG_KEY=...
NEXT_PUBLIC_POSTHOG_HOST=https://posthog.yourdomain.com

# Formbricks (Surveys)
NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID=...
NEXT_PUBLIC_FORMBRICKS_API_HOST=https://formbricks.yourdomain.com
```

### Optional
```env
# Cal.com
CAL_COM_API_KEY=...

# OpenRouter
OPENROUTER_API_KEY=...
```

See `specs/sections/02-sdk-integrations.md` for complete configuration details.

---

## Development Workflow

### Testing Strategy
We follow **London School TDD** (behavior verification):

```bash
# Unit tests with Vitest
pnpm test --run                    # Single run
pnpm test --watch                  # Watch mode
pnpm test --ui                     # Test UI dashboard

# End-to-end tests with Playwright
pnpm e2e                           # Headless
pnpm e2e --headed                  # With browser
pnpm e2e --debug                   # Debug mode
```

### Code Quality
```bash
# Linting
pnpm lint

# Type checking
pnpm type-check

# Code formatting
pnpm format

# All checks at once
pnpm check-all
```

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/description

# Make changes and commit
git add .
git commit -m "feat: description"

# Push and create PR
git push origin feature/description
```

---

## Deployment

### To Staging (Vercel Preview)
```bash
# Push to staging branch
git push origin staging

# Vercel auto-deploys preview URL
# Check PR for preview link
```

### To Production (Vercel)
```bash
# Merge PR to main
git checkout main
git pull origin main

# Create release tag
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0

# Vercel auto-deploys to production
```

### Database Migrations (Convex)
```bash
# Schema changes are auto-detected
pnpm convex push

# Data migrations (if needed)
pnpm convex run script.ts --args "data"
```

---

## Architecture Decisions

### Why Convex?
- **Real-time database**: WebSocket subscriptions built-in
- **Zero ops**: Managed infrastructure, automatic scaling
- **Type-safe**: Full TypeScript in backend functions
- **Developer experience**: Hot reload, instant deployment
- **Cost-effective**: Pay only for what you use

### Why Next.js 15?
- **React 19**: Latest features (use hook, async components)
- **App Router**: Simplified routing and nested layouts
- **Server Components**: Improved performance and security
- **API Routes**: Serverless functions for custom logic
- **Vercel Integration**: Seamless deployment and edge functions

### Why Stripe + Brevo + PostHog?
- **Stripe**: Proven, PCI-compliant payment processing
- **Brevo**: Cost-effective email with transactional + marketing
- **PostHog**: Self-hosted analytics for compliance and control

---

## Key Features

### For Learners
- **Cohort Dashboard**: View enrollments, upcoming sessions, progress
- **Learning Materials**: Access slides, recordings, resources
- **Peer Network**: Connect with cohort members and alumni
- **Office Hours**: Book 1-on-1 sessions with instructors
- **Feedback Loop**: Surveys and check-ins to improve learning
- **AI Tutor**: Chat with OpenRouter-powered AI assistant

### For Instructors
- **Cohort Management**: Create, schedule, and manage cohorts
- **Roster Management**: Add learners, track attendance
- **Office Hours**: Calendar and availability management
- **Analytics**: View attendance, completion, satisfaction scores
- **Communication**: Bulk email and announcements

### For Admins
- **Platform Dashboard**: Overall platform health and metrics
- **Financial Reports**: Revenue, refunds, payment issues
- **User Management**: User accounts, roles, permissions
- **System Configuration**: Email templates, payment settings, integrations
- **Audit Logs**: Track all user actions and changes

---

## Common Tasks

### Add a New Page
```typescript
// app/dashboard/new-page/page.tsx
export default function NewPage() {
  return <div>New Page Content</div>
}
```

### Create a Convex Function
```typescript
// convex/functions/myfunction.ts
import { mutation, query } from "./_generated/server"

export const getItems = query(async (ctx) => {
  return await ctx.db.query("items").collect()
})

export const addItem = mutation(
  async (ctx, { name }: { name: string }) => {
    return await ctx.db.insert("items", { name, createdAt: Date.now() })
  }
)
```

### Use a Convex Function in React
```typescript
import { useQuery, useMutation } from "convex/react"
import { api } from "@/convex/_generated/api"

export function MyComponent() {
  const items = useQuery(api.functions.getItems)
  const addItem = useMutation(api.functions.addItem)

  return (
    <div>
      {items?.map((item) => <div key={item._id}>{item.name}</div>)}
      <button onClick={() => addItem({ name: "New Item" })}>Add</button>
    </div>
  )
}
```

### Add Stripe Payment
```typescript
// See specs/sections/05-payment-flows.md for complete flow
const session = await stripe.checkout.sessions.create({
  payment_method_types: ["card"],
  line_items: [{ price: "price_xxx", quantity: 1 }],
  mode: "subscription",
  success_url: "https://yourdomain.com/success",
  cancel_url: "https://yourdomain.com/cancel",
})
```

---

## Testing Examples

### Unit Test (Vitest)
```typescript
// tests/unit/utils.test.ts
import { describe, it, expect } from "vitest"
import { calculatePrice } from "@/lib/pricing"

describe("calculatePrice", () => {
  it("should apply discount for annual billing", () => {
    expect(calculatePrice(100, "annual")).toBe(900) // 10% discount
  })
})
```

### E2E Test (Playwright)
```typescript
// tests/e2e/auth.spec.ts
import { test, expect } from "@playwright/test"

test("user can sign up", async ({ page }) => {
  await page.goto("/auth/signup")
  await page.fill('input[name="email"]', "test@example.com")
  await page.fill('input[name="password"]', "SecurePass123")
  await page.click("button[type='submit']")
  await expect(page).toHaveURL("/dashboard")
})
```

---

## Troubleshooting

### Convex Connection Issues
```bash
# Check Convex status
pnpm convex status

# Re-authenticate
pnpm convex login

# Restart dev server
pnpm convex dev
```

### TypeScript Errors
```bash
# Generate Convex types
pnpm convex codegen

# Check all types
pnpm type-check
```

### Port Already in Use
```bash
# Find process on port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

---

## Contributing

### Code Standards
- **TypeScript**: Strict mode enabled
- **React**: Functional components, hooks
- **Testing**: 80% coverage minimum
- **Commits**: Conventional commits (feat, fix, docs, etc.)
- **PR Reviews**: Required before merge

### Commit Message Format
```
feat(cohorts): add cohort scheduling feature
fix(payments): resolve Stripe webhook timeout
docs(readme): update deployment instructions
test(users): add authentication tests
```

---

## License & Rights

**Proprietary** - AI Enablement Academy
All rights reserved. Unauthorized use, reproduction, or distribution is prohibited.

---

## Support & Resources

### Documentation
- [Full SPARC Specification](specs/SPARC-SPECIFICATION.md)
- [PRD v2.1.0](specs/PRD.md)
- [SDK Integration Guide](specs/sections/02-sdk-integrations.md)
- [Database Schema](specs/sections/03-database-schema.md)

### External Resources
- [Next.js Docs](https://nextjs.org/docs)
- [Convex Docs](https://docs.convex.dev)
- [React 19 Docs](https://react.dev)
- [Stripe API Docs](https://stripe.com/docs)
- [Playwright Docs](https://playwright.dev)

### Getting Help
- Check the specification first: `specs/SPARC-SPECIFICATION.md`
- Review PR comments and commit history for context
- Ask in team Slack or create a GitHub issue

---

**Last Updated**: 2025-12-02
**Version**: v2.0.0
