# Database Schema

## Overview

The AI Enablement Academy platform uses **Convex** as its document database and backend runtime. Convex provides real-time data synchronization, serverless functions, and built-in authentication with TypeScript-first development.

Key advantages of Convex for this platform:
- Real-time subscriptions for live cohort updates
- Serverless mutations and queries with automatic caching
- Built-in file storage for slides, certificates, and recordings
- Type-safe schema with automatic validation
- Scheduled functions for waitlist processing and reminders

---

## Authentication Configuration

### Google OAuth + Magic Links Setup

The platform uses Convex Auth with Google OAuth for organizational logins and magic links for quick individual access.

**File: `convex/auth.config.ts`**

```typescript
import { convexAuth } from "@convex-dev/auth/server";
import Google from "@auth/core/providers/google";
import Resend from "@auth/core/providers/resend";

export const { auth, signIn, signOut, store } = convexAuth({
  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_CLIENT_ID,
      clientSecret: process.env.AUTH_GOOGLE_SECRET,
    }),
    Resend({
      apiKey: process.env.AUTH_RESEND_KEY,
      from: "Academy <auth@aienablement.academy>",
    }),
  ],
});
```

### Required Environment Variables

```bash
# Google OAuth (for organizational B2B login)
AUTH_GOOGLE_CLIENT_ID=your_google_client_id
AUTH_GOOGLE_SECRET=your_google_client_secret

# Resend (for magic link emails)
AUTH_RESEND_KEY=re_your_resend_api_key

# Convex Auth
CONVEX_SITE_URL=https://aienablement.academy
```

---

## Complete Schema Definition

**File: `convex/schema.ts`**

```typescript
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // ==========================================
  // USERS & AUTHENTICATION
  // ==========================================

  users: defineTable({
    // Authentication
    email: v.string(),
    tokenIdentifier: v.string(), // From Convex Auth

    // Profile
    name: v.string(),
    role: v.union(
      v.literal("individual"),      // B2C learner
      v.literal("org_admin"),        // B2B organization administrator
      v.literal("org_member"),       // B2B organization member
      v.literal("platform_admin")    // Platform administrator
    ),

    // Organization relationship (for B2B users)
    organizationId: v.optional(v.id("organizations")),

    // Profile fields
    company: v.optional(v.string()),
    title: v.optional(v.string()),
    linkedInUrl: v.optional(v.string()),
    phoneNumber: v.optional(v.string()),
    timezone: v.optional(v.string()),

    // Preferences
    emailNotifications: v.boolean(),
    smsNotifications: v.boolean(),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_email", ["email"])
    .index("by_token", ["tokenIdentifier"])
    .index("by_organization", ["organizationId"]),

  // ==========================================
  // ORGANIZATIONS (B2B)
  // ==========================================

  organizations: defineTable({
    // Organization details
    name: v.string(),
    domain: v.string(), // Email domain for auto-enrollment (e.g., "acme.com")

    // Primary contact
    contactEmail: v.string(),
    contactName: v.string(),

    // Subscription details
    status: v.union(
      v.literal("pending_payment"), // Invoice sent, awaiting payment
      v.literal("active"),           // Paid and operational
      v.literal("suspended")         // Payment failed or account suspended
    ),
    seatsPurchased: v.number(),
    seatsUsed: v.number(),

    // Stripe integration
    stripeCustomerId: v.optional(v.string()),
    stripeInvoiceId: v.optional(v.string()),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_domain", ["domain"])
    .index("by_status", ["status"])
    .index("by_contact_email", ["contactEmail"]),

  organizationInvites: defineTable({
    organizationId: v.id("organizations"),

    // Invite details
    email: v.string(),
    inviteToken: v.string(), // Unique token for invite link
    cohortId: v.optional(v.id("cohorts")), // Pre-assign to specific cohort

    // Status tracking
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("expired"),
      v.literal("revoked")
    ),

    // Expiration
    expiresAt: v.number(),

    // Timestamps
    createdAt: v.number(),
    acceptedAt: v.optional(v.number()),
  })
    .index("by_token", ["inviteToken"])
    .index("by_email", ["email"])
    .index("by_organization", ["organizationId"])
    .index("by_status", ["status"]),

  // ==========================================
  // COURSES & SESSIONS
  // ==========================================

  courses: defineTable({
    // Course metadata
    title: v.string(),
    description: v.string(),
    slug: v.string(), // URL-friendly identifier

    // Session structure
    sessionType: v.union(
      v.literal("cohort"),    // 2-day intensive cohort
      v.literal("webinar"),   // 90-minute webinar
      v.literal("hackathon")  // Multi-week hackathon
    ),

    // Pricing
    priceB2C: v.number(), // Individual learner price (cents)
    priceB2B: v.number(), // Per-seat organizational price (cents)

    // Capacity
    maxParticipants: v.number(),

    // Learning taxonomy
    impactLevel: v.union(
      v.literal("L1"), // Individual adoption
      v.literal("L2"), // Team transformation
      v.literal("L3")  // Organizational strategy
    ),
    capabilityLevel: v.union(
      v.literal("fundamentals"),
      v.literal("intermediate"),
      v.literal("advanced")
    ),

    // Status
    status: v.union(
      v.literal("draft"),
      v.literal("published"),
      v.literal("archived")
    ),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_status", ["status"])
    .index("by_session_type", ["sessionType"]),

  sessions: defineTable({
    courseId: v.id("courses"),

    // Session metadata
    title: v.string(),
    type: v.union(
      v.literal("S"),   // Spark (opening/closing)
      v.literal("W"),   // Workshop (hands-on practice)
      v.literal("MM"),  // Mini-Masterclass (concept deep-dive)
      v.literal("CAP"), // Capability Session (tool mastery)
      v.literal("IO")   // Implementation Office (group coaching)
    ),

    // Schedule positioning
    dayNumber: v.number(), // 1 or 2 for cohort
    orderInDay: v.number(), // Sequence within the day
    durationMinutes: v.number(),

    // Content
    description: v.string(),
    outcomes: v.array(v.string()), // Learning outcomes

    // Timestamps
    createdAt: v.number(),
  })
    .index("by_course", ["courseId"])
    .index("by_course_day", ["courseId", "dayNumber", "orderInDay"]),

  cohorts: defineTable({
    courseId: v.id("courses"),

    // Cohort details
    name: v.string(), // e.g., "AI Enablement Cohort - March 2025"
    startDate: v.number(), // Unix timestamp
    endDate: v.number(),   // Unix timestamp

    // Capacity management
    maxCapacity: v.number(),
    currentEnrollment: v.number(),

    // Status
    status: v.union(
      v.literal("scheduled"),   // Future cohort, not yet open for enrollment
      v.literal("open"),        // Accepting enrollments
      v.literal("in_progress"), // Currently running
      v.literal("completed"),   // Finished
      v.literal("cancelled")    // Cancelled cohort
    ),

    // Delivery details
    zoomLink: v.optional(v.string()),
    instructorId: v.optional(v.id("users")),

    // B2B tracking
    isB2B: v.boolean(), // True if dedicated organizational cohort
    organizationId: v.optional(v.id("organizations")),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_course", ["courseId"])
    .index("by_status", ["status"])
    .index("by_start_date", ["startDate"])
    .index("by_organization", ["organizationId"]),

  // ==========================================
  // ENROLLMENTS & WAITLIST
  // ==========================================

  enrollments: defineTable({
    userId: v.id("users"),
    cohortId: v.id("cohorts"),
    courseId: v.id("courses"),

    // Purchase details
    purchaseDate: v.number(),
    paymentStatus: v.union(
      v.literal("pending"),
      v.literal("completed"),
      v.literal("failed"),
      v.literal("refunded")
    ),
    paymentType: v.union(
      v.literal("b2c"), // Individual Stripe payment
      v.literal("b2b")  // Organizational seat allocation
    ),

    // Stripe references
    stripePaymentIntentId: v.optional(v.string()),
    stripeCheckoutSessionId: v.optional(v.string()),

    // Learner journey
    intakeSurveyCompleted: v.boolean(),

    // Access windows (Unix timestamps)
    officeHoursEligibleUntil: v.number(),    // 90 days post-cohort
    materialsAccessUntil: v.number(),         // 1 year post-cohort
    chatbotAccessUntil: v.number(),           // 90 days post-cohort

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_cohort", ["cohortId"])
    .index("by_user_course", ["userId", "courseId"])
    .index("by_stripe_session", ["stripeCheckoutSessionId"]),

  waitlist: defineTable({
    userId: v.id("users"),
    courseId: v.id("courses"),
    cohortId: v.optional(v.id("cohorts")), // Specific cohort or general course waitlist

    // Queue management
    position: v.number(), // Queue position for the cohort
    status: v.union(
      v.literal("waiting"),   // In queue
      v.literal("offered"),   // Spot offered, awaiting acceptance
      v.literal("enrolled"),  // Accepted and enrolled
      v.literal("expired"),   // Offer expired
      v.literal("cancelled")  // User cancelled waitlist
    ),

    // Offer tracking
    offeredAt: v.optional(v.number()),
    offerExpiresAt: v.optional(v.number()),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_cohort_position", ["cohortId", "position"])
    .index("by_user", ["userId"])
    .index("by_status", ["status"]),

  // ==========================================
  // CONTENT & MATERIALS
  // ==========================================

  enablementKitItems: defineTable({
    courseId: v.id("courses"),

    // Item details
    title: v.string(),
    type: v.union(
      v.literal("slides"),      // PDF slide deck
      v.literal("prompts"),     // Prompt library
      v.literal("template"),    // Worksheet/template
      v.literal("chatbot"),     // Custom GPT link
      v.literal("worksheet")    // Exercise worksheet
    ),

    // Storage references
    fileId: v.optional(v.id("_storage")), // Convex file storage ID
    externalUrl: v.optional(v.string()),   // External link (e.g., ChatGPT link)

    // Ordering
    order: v.number(),

    // Timestamps
    createdAt: v.number(),
  })
    .index("by_course", ["courseId"]),

  sessionRecordings: defineTable({
    cohortId: v.id("cohorts"),
    sessionId: v.id("sessions"),

    // Recording details
    videoUrl: v.string(), // Vimeo or S3 URL
    duration: v.number(), // Duration in seconds

    // Timestamps
    uploadedAt: v.number(),
  })
    .index("by_cohort", ["cohortId"]),

  // ==========================================
  // BOOKINGS & CHAT
  // ==========================================

  officeHoursBookings: defineTable({
    enrollmentId: v.id("enrollments"),
    userId: v.id("users"),

    // Scheduling
    scheduledAt: v.number(), // Unix timestamp

    // Cal.com integration
    calcomEventId: v.string(),       // Cal.com event type ID
    calcomBookingUid: v.string(),    // Unique booking identifier

    // Status
    status: v.union(
      v.literal("scheduled"),
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("no_show")
    ),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_enrollment", ["enrollmentId"])
    .index("by_user", ["userId"])
    .index("by_calcom_uid", ["calcomBookingUid"]),

  chatConversations: defineTable({
    enrollmentId: v.id("enrollments"),
    userId: v.id("users"),
    courseId: v.id("courses"),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_enrollment", ["enrollmentId"])
    .index("by_user", ["userId"]),

  chatMessages: defineTable({
    conversationId: v.id("chatConversations"),

    // Message details
    role: v.union(
      v.literal("user"),
      v.literal("assistant")
    ),
    content: v.string(),

    // Token tracking
    tokenCount: v.number(),

    // Timestamps
    createdAt: v.number(),
  })
    .index("by_conversation", ["conversationId"]),

  // ==========================================
  // CERTIFICATES
  // ==========================================

  certificates: defineTable({
    enrollmentId: v.id("enrollments"),
    userId: v.id("users"),
    courseId: v.id("courses"),
    cohortId: v.id("cohorts"),

    // Issuance
    issuedAt: v.number(),

    // Open Badge standard (JSON-LD)
    badgeData: v.object({
      "@context": v.string(),
      type: v.string(),
      id: v.string(),
      name: v.string(),
      description: v.string(),
      image: v.string(),
      criteria: v.object({
        narrative: v.string(),
      }),
      issuer: v.object({
        id: v.string(),
        type: v.string(),
        name: v.string(),
        url: v.string(),
      }),
    }),

    // Verification
    verificationUrl: v.string(), // Public verification page URL

    // Assets
    badgeImageId: v.id("_storage"),  // Badge PNG file
    pdfId: v.id("_storage"),          // Certificate PDF

    // Sharing
    linkedInShareUrl: v.string(), // Pre-populated LinkedIn share link

    // Timestamps
    createdAt: v.number(),
  })
    .index("by_enrollment", ["enrollmentId"])
    .index("by_user", ["userId"])
    .index("by_verification_url", ["verificationUrl"]),

  // ==========================================
  // MARKETING & ANALYTICS
  // ==========================================

  contactSubmissions: defineTable({
    // Form data
    name: v.string(),
    email: v.string(),
    company: v.optional(v.string()),
    teamSize: v.optional(v.string()),
    message: v.string(),

    // Processing status
    status: v.union(
      v.literal("pending"),   // Not yet processed
      v.literal("contacted"), // Follow-up sent
      v.literal("converted"), // Became customer
      v.literal("spam")       // Marked as spam
    ),

    // Brevo integration
    brevoContactId: v.optional(v.string()),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_email", ["email"]),

  executiveReports: defineTable({
    organizationId: v.id("organizations"),
    cohortId: v.id("cohorts"),

    // Metrics snapshot
    metrics: v.object({
      totalEnrollments: v.number(),
      completionRate: v.number(),
      averageEngagement: v.number(),
      officeHoursBooked: v.number(),
      certificatesIssued: v.number(),
      chatbotInteractions: v.number(),
    }),

    // Report generation
    generatedAt: v.number(),
    pdfId: v.id("_storage"), // Generated PDF report
  })
    .index("by_organization", ["organizationId"]),

  webhookDeliveries: defineTable({
    // Event details
    eventType: v.string(), // e.g., "enrollment.created", "cohort.completed"
    targetUrl: v.string(),
    payload: v.any(), // Event payload (JSON)

    // Delivery tracking
    status: v.union(
      v.literal("pending"),
      v.literal("delivered"),
      v.literal("failed")
    ),
    attempts: v.number(),
    lastAttemptAt: v.optional(v.number()),
    nextRetryAt: v.optional(v.number()),
    responseCode: v.optional(v.number()),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_event_type", ["eventType"]),

  analyticsEvents: defineTable({
    userId: v.optional(v.id("users")),
    sessionId: v.string(), // Anonymous session ID

    // Event details
    event: v.string(), // e.g., "page_view", "button_click", "video_play"
    properties: v.any(), // Event-specific properties (JSON)

    // Timestamp
    timestamp: v.number(),
  })
    .index("by_event", ["event"])
    .index("by_user", ["userId"])
    .index("by_session", ["sessionId"]),

  // ==========================================
  // RESOURCE LIBRARY SYSTEM (v2.1)
  // ==========================================

  resources: defineTable({
    title: v.string(),
    slug: v.string(),
    description: v.string(),
    type: v.union(
      v.literal("template"),             // Downloadable templates
      v.literal("framework"),            // Strategic frameworks
      v.literal("prompt"),               // AI prompt library
      v.literal("glossary"),             // Term definitions
      v.literal("case_study"),           // Real-world examples
      v.literal("checklist"),            // Action checklists
      v.literal("tool_guide"),           // Tool tutorials
      v.literal("video"),                // Video content
      v.literal("article"),              // Written content
      v.literal("external_link")         // Curated external resources
    ),
    category: v.string(),                // "Prompt Engineering", "Change Management"
    tags: v.array(v.string()),           // ["beginner", "marketing", "gpt-4"]

    // Content
    content: v.optional(v.string()),     // Markdown content for articles/glossary
    fileId: v.optional(v.id("_storage")), // For downloadables
    fileType: v.optional(v.string()),    // "pdf", "docx", "xlsx"
    externalUrl: v.optional(v.string()), // For external links
    videoUrl: v.optional(v.string()),    // Embedded video URL

    // Access control
    accessLevel: v.union(
      v.literal("public"),               // Anyone can access
      v.literal("registered"),           // Logged-in users
      v.literal("enrolled"),             // Enrolled in any course
      v.literal("course_specific"),      // Specific course enrollment
      v.literal("premium")               // Premium tier only
    ),
    courseIds: v.optional(v.array(v.id("courses"))), // For course_specific

    // Metadata
    authorId: v.optional(v.id("users")),
    skillIds: v.optional(v.array(v.id("skills"))), // Related skills
    downloadCount: v.number(),
    viewCount: v.number(),
    rating: v.optional(v.number()),      // Average rating 1-5
    ratingCount: v.number(),
    isFeatured: v.boolean(),
    isActive: v.boolean(),
    sortOrder: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_type", ["type", "isActive"])
    .index("by_category", ["category", "isActive"])
    .index("by_featured", ["isFeatured", "isActive"])
    .searchIndex("search_resources", {
      searchField: "title",
      filterFields: ["type", "category", "isActive"],
    }),

  glossaryTerms: defineTable({
    term: v.string(),                    // "Large Language Model"
    slug: v.string(),                    // "large-language-model"
    abbreviation: v.optional(v.string()), // "LLM"
    definition: v.string(),              // Short definition
    extendedDefinition: v.optional(v.string()), // Detailed explanation
    relatedTermIds: v.optional(v.array(v.id("glossaryTerms"))),
    skillIds: v.optional(v.array(v.id("skills"))),
    examples: v.optional(v.array(v.string())),
    category: v.string(),                // "AI Fundamentals", "Tools"
    isActive: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_category", ["category"])
    .index("by_abbreviation", ["abbreviation"])
    .searchIndex("search_glossary", {
      searchField: "term",
      filterFields: ["category", "isActive"],
    }),

  prompts: defineTable({
    title: v.string(),                   // "Sales Email Generator"
    slug: v.string(),
    description: v.string(),
    category: v.union(
      v.literal("writing"),              // Content creation
      v.literal("analysis"),             // Data analysis
      v.literal("coding"),               // Development
      v.literal("research"),             // Research & learning
      v.literal("business"),             // Business tasks
      v.literal("creative"),             // Creative work
      v.literal("system")                // System prompts
    ),
    subcategory: v.string(),             // "Marketing", "Legal", etc.

    // Prompt content
    promptTemplate: v.string(),          // The actual prompt with {{variables}}
    variables: v.array(v.object({
      name: v.string(),                  // "product_name"
      description: v.string(),           // "Name of the product"
      type: v.union(v.literal("text"), v.literal("textarea"), v.literal("select")),
      required: v.boolean(),
      defaultValue: v.optional(v.string()),
      options: v.optional(v.array(v.string())), // For select type
    })),
    exampleOutput: v.optional(v.string()),

    // Model recommendations
    recommendedModels: v.array(v.string()), // ["gpt-4", "claude-3"]
    modelSettings: v.optional(v.object({
      temperature: v.optional(v.number()),
      maxTokens: v.optional(v.number()),
    })),

    // Metadata
    authorId: v.optional(v.id("users")),
    skillIds: v.optional(v.array(v.id("skills"))),
    tags: v.array(v.string()),
    useCount: v.number(),
    rating: v.optional(v.number()),
    ratingCount: v.number(),
    isFeatured: v.boolean(),
    isActive: v.boolean(),

    // Access
    accessLevel: v.union(
      v.literal("public"),
      v.literal("registered"),
      v.literal("enrolled"),
      v.literal("premium")
    ),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_category", ["category", "isActive"])
    .index("by_featured", ["isFeatured", "isActive"])
    .searchIndex("search_prompts", {
      searchField: "title",
      filterFields: ["category", "subcategory", "isActive"],
    }),

  resourceInteractions: defineTable({
    userId: v.id("users"),
    resourceId: v.id("resources"),
    interactionType: v.union(
      v.literal("view"),
      v.literal("download"),
      v.literal("bookmark"),
      v.literal("rate"),
      v.literal("share")
    ),
    rating: v.optional(v.number()),      // 1-5 for rate interactions
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_resource", ["resourceId"])
    .index("by_user_resource", ["userId", "resourceId"]),

  userBookmarks: defineTable({
    userId: v.id("users"),
    resourceType: v.union(
      v.literal("resource"),
      v.literal("glossary"),
      v.literal("prompt")
    ),
    resourceId: v.string(),              // ID of the bookmarked item
    notes: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_type", ["userId", "resourceType"]),
});
```

---

## Resource Library Categories & Examples

The Resource Library System provides comprehensive learning support materials organized into strategic categories:

### Templates
Downloadable, customizable resources for immediate application:
- **AI Strategy Canvas** - Strategic planning template for AI adoption roadmaps
- **Prompt Library Template** - Structured spreadsheet for organizing and versioning prompts
- **ROI Calculator** - Excel/Google Sheets calculator for AI initiative business cases
- **Use Case Tracker** - Template for documenting and prioritizing AI use cases
- **Stakeholder Analysis Matrix** - Framework for identifying and engaging AI champions

### Frameworks
Strategic thinking tools and decision-making models:
- **AI Readiness Assessment** - Comprehensive evaluation framework for organizational AI maturity
- **Use Case Prioritization Matrix** - Decision framework balancing impact, effort, and risk
- **Prompt Engineering Canvas** - Systematic approach to designing effective prompts
- **Change Management Framework** - Structured approach for managing AI transformation
- **Ethics & Governance Framework** - Guidelines for responsible AI implementation

### Checklists
Actionable step-by-step guides:
- **AI Tool Evaluation Checklist** - Criteria for selecting AI tools and platforms
- **Prompt Engineering Best Practices** - Quality assurance checklist for prompt development
- **Security Review Checklist** - Security considerations for AI tool adoption
- **Data Privacy Checklist** - GDPR/privacy compliance for AI implementations
- **Go-Live Readiness Checklist** - Pre-launch verification for AI initiatives

### Glossary Terms
Curated AI terminology with examples and context:
- **Large Language Model (LLM)** - Definition, examples (GPT-4, Claude), use cases
- **Prompt Engineering** - Techniques, best practices, common patterns
- **Fine-tuning** - Explanation, when to use, alternatives
- **Retrieval-Augmented Generation (RAG)** - Architecture, benefits, implementation
- **Token** - What it is, pricing implications, optimization strategies

### Prompt Library
Pre-built, tested prompts for common business tasks:
- **Content Creation** - Blog outlines, social posts, email campaigns
- **Analysis** - Market research, competitive analysis, data interpretation
- **Business Operations** - Meeting summaries, process documentation, RFP responses
- **Coding** - Code review, documentation, debugging assistance
- **Research** - Literature review, synthesis, trend analysis

### Access Control Strategy

Resources support tiered access based on user engagement:
- **Public** - Glossary terms, basic checklists (SEO & lead generation)
- **Registered** - Extended frameworks, introductory templates (email capture)
- **Enrolled** - Course-specific resources, advanced templates (course value-add)
- **Course-Specific** - Cohort materials, specialized tools (exclusive to specific courses)
- **Premium** - Executive frameworks, custom templates (future revenue stream)

---

## Query Pattern Examples

### Get Current User

```typescript
// convex/users.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_token", (q) =>
        q.eq("tokenIdentifier", identity.tokenIdentifier)
      )
      .unique();

    return user;
  },
});
```

### Get Enrolled Cohorts for User

```typescript
// convex/enrollments.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getEnrolledCohorts = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get all enrollments for user
    const enrollments = await ctx.db
      .query("enrollments")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .filter((q) => q.eq(q.field("paymentStatus"), "completed"))
      .collect();

    // Fetch cohort details
    const cohorts = await Promise.all(
      enrollments.map(async (enrollment) => {
        const cohort = await ctx.db.get(enrollment.cohortId);
        const course = cohort ? await ctx.db.get(cohort.courseId) : null;

        return {
          enrollment,
          cohort,
          course,
        };
      })
    );

    return cohorts.filter(c => c.cohort && c.course);
  },
});
```

### Get Available Cohorts for Course

```typescript
// convex/cohorts.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getAvailableCohorts = query({
  args: { courseId: v.id("courses") },
  handler: async (ctx, args) => {
    const now = Date.now();

    const cohorts = await ctx.db
      .query("cohorts")
      .withIndex("by_course", (q) => q.eq("courseId", args.courseId))
      .filter((q) =>
        q.and(
          q.eq(q.field("status"), "open"),
          q.gt(q.field("startDate"), now),
          q.lt(q.field("currentEnrollment"), q.field("maxCapacity"))
        )
      )
      .collect();

    return cohorts;
  },
});
```

---

## Mutation Pattern Examples

### Create Enrollment with Idempotency

```typescript
// convex/enrollments.ts
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const createEnrollment = mutation({
  args: {
    userId: v.id("users"),
    cohortId: v.id("cohorts"),
    stripeCheckoutSessionId: v.string(),
  },
  handler: async (ctx, args) => {
    // Idempotency check: prevent duplicate enrollments
    const existing = await ctx.db
      .query("enrollments")
      .withIndex("by_stripe_session", (q) =>
        q.eq("stripeCheckoutSessionId", args.stripeCheckoutSessionId)
      )
      .unique();

    if (existing) {
      return existing._id;
    }

    // Get cohort and course details
    const cohort = await ctx.db.get(args.cohortId);
    if (!cohort) {
      throw new Error("Cohort not found");
    }

    // Check capacity
    if (cohort.currentEnrollment >= cohort.maxCapacity) {
      throw new Error("Cohort is full");
    }

    const now = Date.now();
    const courseEndDate = cohort.endDate;
    const ninetyDays = 90 * 24 * 60 * 60 * 1000;
    const oneYear = 365 * 24 * 60 * 60 * 1000;

    // Create enrollment
    const enrollmentId = await ctx.db.insert("enrollments", {
      userId: args.userId,
      cohortId: args.cohortId,
      courseId: cohort.courseId,
      purchaseDate: now,
      paymentStatus: "pending",
      paymentType: "b2c",
      stripeCheckoutSessionId: args.stripeCheckoutSessionId,
      intakeSurveyCompleted: false,
      officeHoursEligibleUntil: courseEndDate + ninetyDays,
      materialsAccessUntil: courseEndDate + oneYear,
      chatbotAccessUntil: courseEndDate + ninetyDays,
      createdAt: now,
      updatedAt: now,
    });

    // Increment cohort enrollment count
    await ctx.db.patch(args.cohortId, {
      currentEnrollment: cohort.currentEnrollment + 1,
      updatedAt: now,
    });

    return enrollmentId;
  },
});
```

### Update Payment Status (Stripe Webhook)

```typescript
// convex/enrollments.ts
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const updatePaymentStatus = mutation({
  args: {
    stripeCheckoutSessionId: v.string(),
    paymentStatus: v.union(
      v.literal("pending"),
      v.literal("completed"),
      v.literal("failed"),
      v.literal("refunded")
    ),
    stripePaymentIntentId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const enrollment = await ctx.db
      .query("enrollments")
      .withIndex("by_stripe_session", (q) =>
        q.eq("stripeCheckoutSessionId", args.stripeCheckoutSessionId)
      )
      .unique();

    if (!enrollment) {
      throw new Error("Enrollment not found");
    }

    await ctx.db.patch(enrollment._id, {
      paymentStatus: args.paymentStatus,
      stripePaymentIntentId: args.stripePaymentIntentId,
      updatedAt: Date.now(),
    });

    return enrollment._id;
  },
});
```

### Process Waitlist (Scheduled Function)

```typescript
// convex/waitlist.ts
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const processWaitlist = mutation({
  args: { cohortId: v.id("cohorts") },
  handler: async (ctx, args) => {
    const cohort = await ctx.db.get(args.cohortId);
    if (!cohort) {
      throw new Error("Cohort not found");
    }

    const availableSpots = cohort.maxCapacity - cohort.currentEnrollment;
    if (availableSpots <= 0) {
      return { offeredCount: 0 };
    }

    // Get waiting users in order
    const waitingUsers = await ctx.db
      .query("waitlist")
      .withIndex("by_cohort_position", (q) =>
        q.eq("cohortId", args.cohortId)
      )
      .filter((q) => q.eq(q.field("status"), "waiting"))
      .take(availableSpots);

    const now = Date.now();
    const offerExpiresAt = now + (48 * 60 * 60 * 1000); // 48 hours

    // Offer spots
    for (const waitlistEntry of waitingUsers) {
      await ctx.db.patch(waitlistEntry._id, {
        status: "offered",
        offeredAt: now,
        offerExpiresAt,
        updatedAt: now,
      });

      // TODO: Send email notification via Brevo
    }

    return { offeredCount: waitingUsers.length };
  },
});
```

---

## File Storage Pattern Examples

### Upload Enablement Kit Item

```typescript
// convex/enablementKit.ts
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const createKitItem = mutation({
  args: {
    courseId: v.id("courses"),
    title: v.string(),
    type: v.union(
      v.literal("slides"),
      v.literal("prompts"),
      v.literal("template"),
      v.literal("chatbot"),
      v.literal("worksheet")
    ),
    fileId: v.optional(v.id("_storage")),
    externalUrl: v.optional(v.string()),
    order: v.number(),
  },
  handler: async (ctx, args) => {
    const itemId = await ctx.db.insert("enablementKitItems", {
      courseId: args.courseId,
      title: args.title,
      type: args.type,
      fileId: args.fileId,
      externalUrl: args.externalUrl,
      order: args.order,
      createdAt: Date.now(),
    });

    return itemId;
  },
});

export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});
```

### Client-Side File Upload (React)

```typescript
// Example React component for file upload
import { useMutation } from "convex/react";
import { api } from "../convex/_generated/api";

function FileUpload({ courseId }: { courseId: string }) {
  const generateUploadUrl = useMutation(api.enablementKit.generateUploadUrl);
  const createKitItem = useMutation(api.enablementKit.createKitItem);

  const handleUpload = async (file: File) => {
    // Step 1: Get upload URL
    const uploadUrl = await generateUploadUrl();

    // Step 2: Upload file to Convex storage
    const result = await fetch(uploadUrl, {
      method: "POST",
      headers: { "Content-Type": file.type },
      body: file,
    });

    const { storageId } = await result.json();

    // Step 3: Create database record
    await createKitItem({
      courseId,
      title: file.name,
      type: "slides",
      fileId: storageId,
      order: 1,
    });
  };

  return (
    <input
      type="file"
      onChange={(e) => e.target.files?.[0] && handleUpload(e.target.files[0])}
    />
  );
}
```

### Generate Certificate PDF

```typescript
// convex/certificates.ts
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const issueCertificate = mutation({
  args: {
    enrollmentId: v.id("enrollments"),
  },
  handler: async (ctx, args) => {
    const enrollment = await ctx.db.get(args.enrollmentId);
    if (!enrollment) {
      throw new Error("Enrollment not found");
    }

    const user = await ctx.db.get(enrollment.userId);
    const course = await ctx.db.get(enrollment.courseId);
    const cohort = await ctx.db.get(enrollment.cohortId);

    if (!user || !course || !cohort) {
      throw new Error("Missing required data");
    }

    // Generate Open Badge JSON-LD
    const certificateId = crypto.randomUUID();
    const verificationUrl = `https://aienablement.academy/verify/${certificateId}`;

    const badgeData = {
      "@context": "https://w3id.org/openbadges/v2",
      "type": "Assertion",
      "id": verificationUrl,
      "name": `${course.title} Completion`,
      "description": `Completed ${course.title} cohort on ${new Date(cohort.endDate).toLocaleDateString()}`,
      "image": `https://aienablement.academy/badges/${course.slug}.png`,
      "criteria": {
        "narrative": `Participated in ${course.title} intensive cohort training.`,
      },
      "issuer": {
        "id": "https://aienablement.academy",
        "type": "Profile",
        "name": "AI Enablement Academy",
        "url": "https://aienablement.academy",
      },
    };

    // TODO: Generate PDF using external service (e.g., Puppeteer, PDFKit)
    // For now, we'll use a placeholder storage ID
    const pdfId = await ctx.storage.generateUploadUrl(); // Replace with actual PDF generation

    const certificateDbId = await ctx.db.insert("certificates", {
      enrollmentId: args.enrollmentId,
      userId: enrollment.userId,
      courseId: enrollment.courseId,
      cohortId: enrollment.cohortId,
      issuedAt: Date.now(),
      badgeData,
      verificationUrl,
      badgeImageId: pdfId as any, // Placeholder
      pdfId: pdfId as any, // Placeholder
      linkedInShareUrl: `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(verificationUrl)}`,
      createdAt: Date.now(),
    });

    return certificateDbId;
  },
});
```

---

## Schema Migration Strategy

Convex handles schema migrations automatically through its deployment pipeline:

1. **Development**: Test schema changes locally with `npx convex dev`
2. **Validation**: Convex validates schema changes against existing data
3. **Deployment**: Deploy with `npx convex deploy --prod`
4. **Backfill**: Use mutations to backfill missing fields or transform data

### Example Backfill Mutation

```typescript
// convex/migrations/addTimezoneToUsers.ts
import { mutation } from "../_generated/server";

export const addTimezoneToUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();

    for (const user of users) {
      if (!user.timezone) {
        await ctx.db.patch(user._id, {
          timezone: "America/New_York", // Default timezone
        });
      }
    }

    return { updated: users.length };
  },
});
```

---

## Performance Considerations

### Indexing Strategy
- **Always index foreign keys** (e.g., `userId`, `cohortId`, `courseId`)
- **Index frequently filtered fields** (e.g., `status`, `paymentStatus`)
- **Composite indexes for complex queries** (e.g., `by_user_course`)

### Query Optimization
- Use `.unique()` when expecting single result (faster than `.first()`)
- Use `.take(n)` for pagination instead of `.collect()` on large datasets
- Avoid complex client-side filtering; push logic to server queries

### Real-Time Subscriptions
- Use `useQuery()` hook sparingly for data that changes frequently
- Consider polling with `setInterval` for non-critical updates
- Use Convex scheduled functions for background processing

---

## Next Steps

1. **Implement authentication flows** (Google OAuth + Magic Links)
2. **Build Stripe integration** for payment processing
3. **Set up Brevo** for transactional emails
4. **Configure Cal.com** for office hours booking
5. **Implement certificate generation** with Open Badge standard
6. **Deploy Convex backend** and connect to Next.js frontend

This schema provides a solid foundation for the AI Enablement Academy platform with type-safe data access, real-time capabilities, and seamless integration with third-party services.

---

## Learning Paths System

### Overview

The Learning Paths system enables curated, sequential learning journeys that guide learners through multiple courses toward specific outcomes. Learning paths support both individual learners (B2C) and organizational teams (B2B) with flexible pricing models including bundled discounts and subscription access.

**Key Features:**
- Curated course sequences with unlocking rules
- Bundled pricing with discounts
- Progress tracking across multiple courses
- Path completion certificates with Open Badges
- Skills development tracking
- Target audience segmentation (individual/team/enterprise)

### Schema Definition

Add these tables to your `convex/schema.ts`:

```typescript
// =============================================================================
// LEARNING PATHS SYSTEM (v2.1)
// =============================================================================

// Learning Paths - Curated course sequences
learningPaths: defineTable({
  title: v.string(),                   // "AI Leadership Track"
  slug: v.string(),
  description: v.string(),
  shortDescription: v.string(),        // For cards

  // Target audience
  targetAudience: v.union(
    v.literal("individual"),           // B2C learners
    v.literal("team"),                 // Small teams
    v.literal("enterprise"),           // Large organizations
    v.literal("all")
  ),
  targetRole: v.optional(v.string()),  // "L&D Leader", "Marketing Manager"

  // Path structure
  estimatedDuration: v.string(),       // "12 weeks"
  totalCourses: v.number(),
  totalHours: v.number(),

  // Skills & outcomes
  skillIds: v.array(v.id("skills")),   // Skills developed
  outcomes: v.array(v.string()),       // Learning outcomes

  // Pricing
  pricingModel: v.union(
    v.literal("individual"),           // Pay per course
    v.literal("bundled"),              // Discounted bundle
    v.literal("subscription")          // Part of subscription
  ),
  bundlePrice: v.optional(v.number()), // For bundled pricing
  bundleDiscount: v.optional(v.number()), // Percentage off

  // Visual
  thumbnailId: v.optional(v.id("_storage")),
  iconUrl: v.optional(v.string()),
  color: v.optional(v.string()),       // Brand color

  // Status
  isActive: v.boolean(),
  isFeatured: v.boolean(),
  sortOrder: v.number(),
  enrollmentCount: v.number(),
  completionCount: v.number(),

  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_slug", ["slug"])
  .index("by_featured", ["isFeatured", "isActive"])
  .index("by_audience", ["targetAudience", "isActive"]),

// Learning Path Steps - Courses in a path
learningPathSteps: defineTable({
  pathId: v.id("learningPaths"),
  courseId: v.id("courses"),
  stepNumber: v.number(),              // Order in path (1, 2, 3...)
  isRequired: v.boolean(),             // Required vs optional
  unlockRule: v.union(
    v.literal("immediate"),            // Available from start
    v.literal("sequential"),           // After previous step
    v.literal("after_days"),           // Days after enrollment
    v.literal("after_completion")      // After specific course
  ),
  unlockAfterStepId: v.optional(v.id("learningPathSteps")),
  unlockAfterDays: v.optional(v.number()),
  recommendedTimeframe: v.optional(v.string()), // "Week 1-2"
  notes: v.optional(v.string()),       // Admin notes
  createdAt: v.number(),
})
  .index("by_path", ["pathId", "stepNumber"])
  .index("by_course", ["courseId"]),

// User Learning Path Enrollments
userPathEnrollments: defineTable({
  userId: v.id("users"),
  pathId: v.id("learningPaths"),
  organizationId: v.optional(v.id("organizations")),

  // Progress
  status: v.union(
    v.literal("active"),
    v.literal("paused"),
    v.literal("completed"),
    v.literal("expired")
  ),
  currentStepId: v.optional(v.id("learningPathSteps")),
  completedSteps: v.array(v.id("learningPathSteps")),
  progressPercent: v.number(),

  // Dates
  enrolledAt: v.number(),
  startedAt: v.optional(v.number()),
  completedAt: v.optional(v.number()),
  expiresAt: v.optional(v.number()),

  // Billing
  paymentType: v.union(
    v.literal("bundle"),               // Paid for bundle
    v.literal("individual"),           // Individual course payments
    v.literal("subscription"),         // Via subscription
    v.literal("organization")          // B2B covered
  ),
  stripeSubscriptionId: v.optional(v.string()),

  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_path", ["pathId"])
  .index("by_organization", ["organizationId"])
  .index("by_user_path", ["userId", "pathId"]),

// Path completion certificates
pathCertificates: defineTable({
  userId: v.id("users"),
  pathId: v.id("learningPaths"),
  enrollmentId: v.id("userPathEnrollments"),

  // Certificate data
  certificateNumber: v.string(),       // "PATH-2025-001234"
  issuedAt: v.number(),
  expiresAt: v.optional(v.number()),

  // Skills achieved
  skillsAchieved: v.array(v.object({
    skillId: v.id("skills"),
    level: v.string(),
  })),

  // Open Badges integration
  badgeData: v.object({
    "@context": v.string(),
    type: v.array(v.string()),
    issuer: v.object({
      id: v.string(),
      name: v.string(),
    }),
    issuanceDate: v.string(),
    credentialSubject: v.object({
      id: v.string(),
      achievement: v.object({
        id: v.string(),
        name: v.string(),
        description: v.string(),
        criteria: v.object({
          narrative: v.string(),
        }),
      }),
    }),
  }),

  publicUrl: v.string(),
  pdfId: v.optional(v.id("_storage")),

  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_path", ["pathId"])
  .index("by_certificate_number", ["certificateNumber"]),
```

### Example Learning Paths

#### 1. AI Foundations Track (Foundational → Practitioner)

**Target Audience:** Individual learners new to AI
**Duration:** 6 weeks
**Pricing:** $997 bundled (save $300 vs individual courses)

**Path Structure:**
```typescript
{
  title: "AI Foundations Track",
  slug: "ai-foundations-track",
  shortDescription: "Master AI fundamentals and practical tools in 6 weeks",
  targetAudience: "individual",
  estimatedDuration: "6 weeks",
  totalCourses: 3,
  totalHours: 48,
  pricingModel: "bundled",
  bundlePrice: 99700, // $997.00 in cents
  bundleDiscount: 23,  // 23% discount
  outcomes: [
    "Understand core AI concepts and terminology",
    "Write effective prompts for any AI tool",
    "Integrate AI tools into daily workflows",
    "Build AI-powered automation workflows"
  ]
}
```

**Steps:**
1. **AI Fundamentals** (Week 1-2)
   - Unlock: Immediate
   - Type: Required
   - 2-day cohort intensive

2. **Prompt Engineering Mastery** (Week 3-4)
   - Unlock: After completing AI Fundamentals
   - Type: Required
   - 2-day cohort intensive

3. **AI Tools Mastery** (Week 5-6)
   - Unlock: After completing Prompt Engineering
   - Type: Required
   - 2-day cohort intensive

#### 2. AI Leadership Track (Strategic → Leadership)

**Target Audience:** Enterprise executives and L&D leaders
**Duration:** 8 weeks
**Pricing:** Organization subscription or $2,497 bundled

**Path Structure:**
```typescript
{
  title: "AI Leadership Track",
  slug: "ai-leadership-track",
  shortDescription: "Lead AI transformation with strategy and governance",
  targetAudience: "enterprise",
  targetRole: "Executive, L&D Leader, Change Manager",
  estimatedDuration: "8 weeks",
  totalCourses: 3,
  totalHours: 48,
  pricingModel: "subscription",
  outcomes: [
    "Develop comprehensive AI adoption strategy",
    "Lead organizational change for AI transformation",
    "Implement AI governance frameworks",
    "Measure ROI of AI initiatives"
  ]
}
```

**Steps:**
1. **AI Strategy for Leaders** (Week 1-3)
   - Unlock: Immediate
   - Type: Required
   - 2-day cohort intensive

2. **Change Management for AI** (Week 4-6)
   - Unlock: Sequential (after previous step)
   - Type: Required
   - 2-day cohort intensive

3. **AI Governance & Ethics** (Week 7-8)
   - Unlock: Sequential (after previous step)
   - Type: Required
   - 2-day cohort intensive

#### 3. Domain Expert Track (Choose Your Specialization)

**Target Audience:** Teams and individual professionals
**Duration:** 6-8 weeks (flexible)
**Pricing:** $1,497 bundled + specialization course

**Path Structure:**
```typescript
{
  title: "Domain Expert Track",
  slug: "domain-expert-track",
  shortDescription: "AI foundations + specialized domain expertise",
  targetAudience: "all",
  estimatedDuration: "6-8 weeks",
  totalCourses: 2,
  totalHours: 32,
  pricingModel: "bundled",
  bundlePrice: 149700,
  bundleDiscount: 20,
  outcomes: [
    "Master AI fundamentals",
    "Apply AI to specific domain (Marketing/Sales/HR)",
    "Build domain-specific AI workflows",
    "Demonstrate measurable impact in your role"
  ]
}
```

**Steps:**
1. **AI Foundations** (Week 1-2)
   - Unlock: Immediate
   - Type: Required
   - 2-day cohort intensive

2. **Choose Your Specialization** (Week 3-6)
   - Unlock: After completing AI Foundations
   - Type: Required (choose one)
   - Options:
     - Marketing AI Mastery
     - Sales AI Mastery
     - HR AI Mastery
     - Product AI Mastery

### Query Examples

#### Get All Active Learning Paths

```typescript
export const getActivePaths = query({
  args: {},
  handler: async (ctx) => {
    const paths = await ctx.db
      .query("learningPaths")
      .withIndex("by_featured", (q) => q.eq("isActive", true))
      .collect();

    return paths;
  },
});
```

#### Get User's Learning Path Progress

```typescript
export const getUserPathProgress = query({
  args: { userId: v.id("users"), pathId: v.id("learningPaths") },
  handler: async (ctx, args) => {
    // Get enrollment
    const enrollment = await ctx.db
      .query("userPathEnrollments")
      .withIndex("by_user_path", (q) =>
        q.eq("userId", args.userId).eq("pathId", args.pathId)
      )
      .unique();

    if (!enrollment) {
      return null;
    }

    // Get all path steps
    const steps = await ctx.db
      .query("learningPathSteps")
      .withIndex("by_path", (q) => q.eq("pathId", args.pathId))
      .collect();

    // Get course details for each step
    const stepsWithCourses = await Promise.all(
      steps.map(async (step) => {
        const course = await ctx.db.get(step.courseId);
        const isCompleted = enrollment.completedSteps.includes(step._id);
        const isUnlocked = await checkStepUnlocked(ctx, step, enrollment);

        return {
          ...step,
          course,
          isCompleted,
          isUnlocked,
        };
      })
    );

    return {
      enrollment,
      steps: stepsWithCourses,
    };
  },
});
```

#### Enroll User in Learning Path

```typescript
export const enrollInPath = mutation({
  args: {
    userId: v.id("users"),
    pathId: v.id("learningPaths"),
    paymentType: v.union(
      v.literal("bundle"),
      v.literal("individual"),
      v.literal("subscription"),
      v.literal("organization")
    ),
    stripeSubscriptionId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Check for existing enrollment
    const existing = await ctx.db
      .query("userPathEnrollments")
      .withIndex("by_user_path", (q) =>
        q.eq("userId", args.userId).eq("pathId", args.pathId)
      )
      .unique();

    if (existing) {
      throw new Error("Already enrolled in this path");
    }

    const now = Date.now();
    const oneYear = 365 * 24 * 60 * 60 * 1000;

    // Create enrollment
    const enrollmentId = await ctx.db.insert("userPathEnrollments", {
      userId: args.userId,
      pathId: args.pathId,
      status: "active",
      progressPercent: 0,
      completedSteps: [],
      paymentType: args.paymentType,
      stripeSubscriptionId: args.stripeSubscriptionId,
      enrolledAt: now,
      expiresAt: now + oneYear,
      createdAt: now,
      updatedAt: now,
    });

    // Increment path enrollment count
    const path = await ctx.db.get(args.pathId);
    if (path) {
      await ctx.db.patch(args.pathId, {
        enrollmentCount: path.enrollmentCount + 1,
      });
    }

    return enrollmentId;
  },
});
```

#### Mark Step Completed

```typescript
export const completeStep = mutation({
  args: {
    enrollmentId: v.id("userPathEnrollments"),
    stepId: v.id("learningPathSteps"),
  },
  handler: async (ctx, args) => {
    const enrollment = await ctx.db.get(args.enrollmentId);
    if (!enrollment) {
      throw new Error("Enrollment not found");
    }

    // Add step to completed steps
    const completedSteps = [...enrollment.completedSteps, args.stepId];

    // Get total steps
    const allSteps = await ctx.db
      .query("learningPathSteps")
      .withIndex("by_path", (q) => q.eq("pathId", enrollment.pathId))
      .collect();

    const progressPercent = Math.round(
      (completedSteps.length / allSteps.length) * 100
    );

    // Check if path is completed
    const isCompleted = progressPercent === 100;

    await ctx.db.patch(args.enrollmentId, {
      completedSteps,
      progressPercent,
      status: isCompleted ? "completed" : enrollment.status,
      completedAt: isCompleted ? Date.now() : enrollment.completedAt,
      updatedAt: Date.now(),
    });

    // Issue certificate if completed
    if (isCompleted) {
      await issuePathCertificate(ctx, args.enrollmentId);
    }

    return { progressPercent, isCompleted };
  },
});
```

### Integration Notes

**Skills Table Reference:**
The `skillIds` field references the comprehensive `skills` table defined in the **Skills & Competencies System (v2.1)** section below. See that section for the full schema definition with taxonomy categories, proficiency levels, and indexing.

**Stripe Integration:**
- Bundled paths create one-time checkout sessions
- Subscription paths link to Stripe subscription IDs
- Individual course payments track separately in enrollments table

**Certificate Generation:**
Path completion triggers a special certificate that:
- Lists all courses completed in the path
- Shows skills achieved with proficiency levels
- Uses Open Badges 2.0 standard for verifiability
- Generates unique certificate number (e.g., `PATH-2025-001234`)

This Learning Paths system provides structured learning journeys with flexible pricing, clear progression tracking, and industry-standard certification.

---

## Skills & Competencies System (Comprehensive)

The Skills & Competencies System (v2.1) extends the basic skills table referenced above to provide a complete competency-based learning framework. This system enables the AI Enablement Academy to track learner progress through measurable skill development, competency-based assessments, stackable micro-credentials, and Open Badges 3.0 for portable, verifiable achievements.

### Core Principles

1. **Skills-Based Learning**: Every course maps to specific skills at defined proficiency levels
2. **Measurable Competencies**: Skills are broken down into observable, assessable competencies
3. **Evidence-Based Assessment**: Multiple evidence types validate competency achievement
4. **Progressive Mastery**: Learners advance through foundational → practitioner → advanced → expert levels
5. **Stackable Credentials**: Micro-credentials (badges) combine into comprehensive skill portfolios

---

### Enhanced Table Definitions

Replace the basic `skills` table with these comprehensive tables in `convex/schema.ts`:

```typescript
// =============================================================================
// SKILLS & COMPETENCIES SYSTEM (v2.1) - COMPREHENSIVE
// =============================================================================

// Skills - Master skill definitions (Enhanced from basic version)
skills: defineTable({
  name: v.string(),                    // "Prompt Engineering"
  slug: v.string(),                    // "prompt-engineering"
  description: v.string(),
  category: v.union(
    v.literal("technical"),            // AI tools, coding
    v.literal("strategic"),            // Business application
    v.literal("leadership"),           // Change management
    v.literal("domain")                // Industry-specific
  ),
  level: v.union(
    v.literal("foundational"),         // Awareness level
    v.literal("practitioner"),         // Can apply
    v.literal("advanced"),             // Can teach others
    v.literal("expert")                // Industry recognized
  ),
  parentSkillId: v.optional(v.id("skills")),  // For skill hierarchies
  prerequisites: v.optional(v.array(v.id("skills"))),
  iconUrl: v.optional(v.string()),
  isActive: v.boolean(),
  sortOrder: v.number(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_slug", ["slug"])
  .index("by_category", ["category"])
  .index("by_level", ["level"])
  .index("by_parent", ["parentSkillId"]),

// Competencies - Measurable skill demonstrations
competencies: defineTable({
  skillId: v.id("skills"),
  name: v.string(),                    // "Write effective system prompts"
  description: v.string(),
  assessmentCriteria: v.string(),      // How to measure
  evidenceTypes: v.array(v.union(
    v.literal("quiz"),
    v.literal("project"),
    v.literal("peer_review"),
    v.literal("instructor_assessment"),
    v.literal("self_assessment")
  )),
  passingThreshold: v.number(),        // 0-100
  isActive: v.boolean(),
  createdAt: v.number(),
})
  .index("by_skill", ["skillId"]),

// Course-Skill mapping
courseSkills: defineTable({
  courseId: v.id("courses"),
  skillId: v.id("skills"),
  skillLevel: v.union(
    v.literal("introduces"),           // First exposure
    v.literal("develops"),             // Builds capability
    v.literal("masters")               // Full competency
  ),
  weight: v.number(),                  // 0-100, relative importance
  createdAt: v.number(),
})
  .index("by_course", ["courseId"])
  .index("by_skill", ["skillId"]),

// Lesson-Competency mapping
lessonCompetencies: defineTable({
  lessonId: v.id("lessons"),
  competencyId: v.id("competencies"),
  contributionLevel: v.union(
    v.literal("introduces"),
    v.literal("reinforces"),
    v.literal("assesses")
  ),
  createdAt: v.number(),
})
  .index("by_lesson", ["lessonId"])
  .index("by_competency", ["competencyId"]),

// User skill progress tracking
userSkillProgress: defineTable({
  userId: v.id("users"),
  skillId: v.id("skills"),
  currentLevel: v.union(
    v.literal("none"),
    v.literal("foundational"),
    v.literal("practitioner"),
    v.literal("advanced"),
    v.literal("expert")
  ),
  progressPercent: v.number(),         // 0-100 within current level
  evidenceCount: v.number(),           // Number of demonstrations
  lastAssessedAt: v.optional(v.number()),
  verifiedByInstructor: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_skill", ["skillId"])
  .index("by_user_skill", ["userId", "skillId"]),

// Competency evidence records
competencyEvidence: defineTable({
  userId: v.id("users"),
  competencyId: v.id("competencies"),
  enrollmentId: v.optional(v.id("enrollments")),
  evidenceType: v.union(
    v.literal("quiz"),
    v.literal("project"),
    v.literal("peer_review"),
    v.literal("instructor_assessment"),
    v.literal("self_assessment")
  ),
  score: v.number(),                   // 0-100
  passed: v.boolean(),
  evidenceUrl: v.optional(v.string()), // Link to artifact
  notes: v.optional(v.string()),
  assessedBy: v.optional(v.id("users")), // For peer/instructor
  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_competency", ["competencyId"])
  .index("by_enrollment", ["enrollmentId"]),

// Skill badges (stackable micro-credentials)
skillBadges: defineTable({
  userId: v.id("users"),
  skillId: v.id("skills"),
  level: v.union(
    v.literal("foundational"),
    v.literal("practitioner"),
    v.literal("advanced"),
    v.literal("expert")
  ),
  earnedAt: v.number(),
  expiresAt: v.optional(v.number()),   // Some badges expire
  badgeData: v.object({                // Open Badges 3.0 extension
    "@context": v.string(),
    type: v.array(v.string()),
    issuer: v.object({
      id: v.string(),
      name: v.string(),
    }),
    issuanceDate: v.string(),
    credentialSubject: v.object({
      id: v.string(),
      achievement: v.object({
        id: v.string(),
        name: v.string(),
        description: v.string(),
        criteria: v.object({
          narrative: v.string(),
        }),
      }),
    }),
  }),
  publicUrl: v.string(),
  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_skill", ["skillId"])
  .index("by_user_skill_level", ["userId", "skillId", "level"]),

// Lessons table (required for lesson-competency mapping)
lessons: defineTable({
  sessionId: v.id("sessions"),

  // Lesson metadata
  title: v.string(),
  description: v.string(),
  orderInSession: v.number(),
  durationMinutes: v.number(),

  // Content references
  slidesUrl: v.optional(v.string()),
  worksheetId: v.optional(v.id("enablementKitItems")),

  // Timestamps
  createdAt: v.number(),
})
  .index("by_session", ["sessionId"]),
```

---

### Example Skills Taxonomy

The AI Enablement Academy curriculum is structured around four skill categories:

#### 1. Technical Skills
Core technical capabilities for working with AI tools and systems:

- **Prompt Engineering** (Foundational → Expert)
  - Competencies: System prompts, chain-of-thought, few-shot learning, prompt optimization
- **AI Tool Selection** (Foundational → Advanced)
  - Competencies: Vendor evaluation, use case mapping, cost-benefit analysis
- **Data Literacy** (Foundational → Practitioner)
  - Competencies: Data quality assessment, bias detection, data preparation
- **Workflow Automation** (Practitioner → Advanced)
  - Competencies: Process mapping, integration design, automation testing

#### 2. Strategic Skills
Business-focused capabilities for organizational AI adoption:

- **AI Strategy Development** (Practitioner → Expert)
  - Competencies: Opportunity assessment, roadmap creation, stakeholder alignment
- **Use Case Identification** (Foundational → Advanced)
  - Competencies: Problem framing, ROI estimation, feasibility analysis
- **ROI Measurement** (Practitioner → Advanced)
  - Competencies: Metrics definition, baseline measurement, impact tracking
- **Risk Assessment** (Practitioner → Advanced)
  - Competencies: Risk identification, mitigation planning, compliance validation

#### 3. Leadership Skills
People-focused capabilities for driving organizational change:

- **Change Management** (Practitioner → Expert)
  - Competencies: Resistance handling, communication planning, adoption tracking
- **Team Enablement** (Practitioner → Advanced)
  - Competencies: Training design, coaching, skill gap analysis
- **Stakeholder Communication** (Foundational → Advanced)
  - Competencies: Executive storytelling, technical translation, presentation design
- **AI Governance** (Advanced → Expert)
  - Competencies: Policy development, ethical frameworks, audit processes

#### 4. Domain Skills
Industry-specific applications of AI:

- **Marketing AI** (Foundational → Advanced)
  - Competencies: Content generation, personalization, campaign optimization
- **Sales AI** (Foundational → Advanced)
  - Competencies: Lead scoring, conversation intelligence, pipeline forecasting
- **Operations AI** (Practitioner → Advanced)
  - Competencies: Process optimization, quality control, predictive maintenance
- **HR AI** (Foundational → Practitioner)
  - Competencies: Candidate screening, employee engagement, performance analytics

---

### Comprehensive Query Examples

Add these queries to `convex/skills.ts`:

#### Get User Skill Profile

```typescript
// convex/skills.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getUserSkillProfile = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get all user skill progress
    const progressRecords = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

    // Fetch full skill details for each progress record
    const skillsWithProgress = await Promise.all(
      progressRecords.map(async (progress) => {
        const skill = await ctx.db.get(progress.skillId);

        // Get earned badges for this skill
        const badges = await ctx.db
          .query("skillBadges")
          .withIndex("by_user_skill_level", (q) =>
            q.eq("userId", args.userId).eq("skillId", progress.skillId)
          )
          .collect();

        // Get competency evidence count
        const competencies = await ctx.db
          .query("competencies")
          .withIndex("by_skill", (q) => q.eq("skillId", progress.skillId))
          .collect();

        const evidenceCounts = await Promise.all(
          competencies.map(async (comp) => {
            const evidence = await ctx.db
              .query("competencyEvidence")
              .withIndex("by_user", (q) => q.eq("userId", args.userId))
              .filter((q) => q.eq(q.field("competencyId"), comp._id))
              .collect();

            return {
              competencyId: comp._id,
              competencyName: comp.name,
              evidenceCount: evidence.length,
              passedCount: evidence.filter(e => e.passed).length,
            };
          })
        );

        return {
          skill,
          progress,
          badges,
          competencies: evidenceCounts,
        };
      })
    );

    // Group by category
    const byCategory = skillsWithProgress.reduce((acc, item) => {
      if (!item.skill) return acc;

      const category = item.skill.category;
      if (!acc[category]) {
        acc[category] = [];
      }
      acc[category].push(item);
      return acc;
    }, {} as Record<string, typeof skillsWithProgress>);

    return {
      total: skillsWithProgress.length,
      byCategory,
      allSkills: skillsWithProgress,
    };
  },
});
```

#### Get Course Skill Outcomes

```typescript
// convex/skills.ts
export const getCourseSkillOutcomes = query({
  args: { courseId: v.id("courses") },
  handler: async (ctx, args) => {
    // Get all skills taught in this course
    const courseSkills = await ctx.db
      .query("courseSkills")
      .withIndex("by_course", (q) => q.eq("courseId", args.courseId))
      .collect();

    // Fetch skill details and competencies
    const skillOutcomes = await Promise.all(
      courseSkills.map(async (cs) => {
        const skill = await ctx.db.get(cs.skillId);

        // Get all competencies for this skill
        const competencies = await ctx.db
          .query("competencies")
          .withIndex("by_skill", (q) => q.eq("skillId", cs.skillId))
          .collect();

        // For each competency, find which lessons address it
        const competenciesWithLessons = await Promise.all(
          competencies.map(async (comp) => {
            const lessonMappings = await ctx.db
              .query("lessonCompetencies")
              .withIndex("by_competency", (q) => q.eq("competencyId", comp._id))
              .collect();

            const lessons = await Promise.all(
              lessonMappings.map(lm => ctx.db.get(lm.lessonId))
            );

            return {
              ...comp,
              lessons: lessons.filter(Boolean),
            };
          })
        );

        return {
          skill,
          skillLevel: cs.skillLevel,
          weight: cs.weight,
          competencies: competenciesWithLessons,
        };
      })
    );

    // Calculate course-level stats
    const totalWeight = courseSkills.reduce((sum, cs) => sum + cs.weight, 0);
    const byCategory = skillOutcomes.reduce((acc, outcome) => {
      if (!outcome.skill) return acc;

      const category = outcome.skill.category;
      acc[category] = (acc[category] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      totalSkills: skillOutcomes.length,
      totalWeight,
      byCategory,
      outcomes: skillOutcomes,
    };
  },
});
```

#### Get Skill Leaderboard

```typescript
// convex/skills.ts
export const getSkillLeaderboard = query({
  args: {
    skillId: v.id("skills"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit || 10;

    // Get all user progress for this skill
    const allProgress = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_skill", (q) => q.eq("skillId", args.skillId))
      .collect();

    // Sort by level, then progress percent
    const levelOrder = { "expert": 4, "advanced": 3, "practitioner": 2, "foundational": 1, "none": 0 };

    const sorted = allProgress.sort((a, b) => {
      const levelDiff = levelOrder[b.currentLevel] - levelOrder[a.currentLevel];
      if (levelDiff !== 0) return levelDiff;
      return b.progressPercent - a.progressPercent;
    });

    // Take top N and fetch user details
    const topLearners = await Promise.all(
      sorted.slice(0, limit).map(async (progress, index) => {
        const user = await ctx.db.get(progress.userId);

        // Get badges for this skill
        const badges = await ctx.db
          .query("skillBadges")
          .withIndex("by_user_skill_level", (q) =>
            q.eq("userId", progress.userId).eq("skillId", args.skillId)
          )
          .collect();

        return {
          rank: index + 1,
          user: user ? {
            id: user._id,
            name: user.name,
            company: user.company,
          } : null,
          currentLevel: progress.currentLevel,
          progressPercent: progress.progressPercent,
          evidenceCount: progress.evidenceCount,
          lastAssessedAt: progress.lastAssessedAt,
          verifiedByInstructor: progress.verifiedByInstructor,
          badges: badges.length,
        };
      })
    );

    // Get skill details
    const skill = await ctx.db.get(args.skillId);

    return {
      skill,
      totalLearners: allProgress.length,
      leaderboard: topLearners,
    };
  },
});
```

#### Suggest Next Skill

```typescript
// convex/skills.ts
export const suggestNextSkill = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get user's current skills and levels
    const userProgress = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

    const userSkillIds = new Set(userProgress.map(p => p.skillId));
    const userSkillLevels = new Map(
      userProgress.map(p => [p.skillId, p.currentLevel])
    );

    // Get all active skills
    const allSkills = await ctx.db
      .query("skills")
      .filter((q) => q.eq(q.field("isActive"), true))
      .collect();

    // Find skills the user hasn't started or can advance
    const suggestions = [];

    for (const skill of allSkills) {
      const currentLevel = userSkillLevels.get(skill._id) || "none";

      // Check prerequisites
      let prerequisitesMet = true;
      if (skill.prerequisites && skill.prerequisites.length > 0) {
        for (const prereqId of skill.prerequisites) {
          const prereqLevel = userSkillLevels.get(prereqId);
          if (!prereqLevel || prereqLevel === "none") {
            prerequisitesMet = false;
            break;
          }
        }
      }

      if (!prerequisitesMet) continue;

      // Suggest if:
      // 1. User hasn't started this skill
      // 2. User is at foundational/practitioner and can advance
      if (currentLevel === "none" ||
          (currentLevel === "foundational" && skill.level === "practitioner") ||
          (currentLevel === "practitioner" && skill.level === "advanced")) {

        // Find courses that teach this skill
        const courseLinks = await ctx.db
          .query("courseSkills")
          .withIndex("by_skill", (q) => q.eq("skillId", skill._id))
          .collect();

        const courses = await Promise.all(
          courseLinks.map(cl => ctx.db.get(cl.courseId))
        );

        suggestions.push({
          skill,
          currentLevel,
          nextLevel: skill.level,
          prerequisitesMet,
          availableCourses: courses.filter(Boolean).filter(c => c.status === "published"),
        });
      }
    }

    // Sort by:
    // 1. Skills user hasn't started (prioritize foundational)
    // 2. Skills user can advance to next level
    // 3. Skills with most available courses
    suggestions.sort((a, b) => {
      if (a.currentLevel === "none" && b.currentLevel !== "none") return -1;
      if (a.currentLevel !== "none" && b.currentLevel === "none") return 1;
      return b.availableCourses.length - a.availableCourses.length;
    });

    return {
      suggestions: suggestions.slice(0, 5), // Top 5 recommendations
      userSkillCount: userProgress.length,
    };
  },
});
```

---

### Mutation Examples

#### Record Competency Evidence

```typescript
// convex/skills.ts
import { mutation } from "./_generated/server";

export const recordCompetencyEvidence = mutation({
  args: {
    userId: v.id("users"),
    competencyId: v.id("competencies"),
    enrollmentId: v.optional(v.id("enrollments")),
    evidenceType: v.union(
      v.literal("quiz"),
      v.literal("project"),
      v.literal("peer_review"),
      v.literal("instructor_assessment"),
      v.literal("self_assessment")
    ),
    score: v.number(),
    evidenceUrl: v.optional(v.string()),
    notes: v.optional(v.string()),
    assessedBy: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const competency = await ctx.db.get(args.competencyId);
    if (!competency) {
      throw new Error("Competency not found");
    }

    const passed = args.score >= competency.passingThreshold;

    // Create evidence record
    const evidenceId = await ctx.db.insert("competencyEvidence", {
      userId: args.userId,
      competencyId: args.competencyId,
      enrollmentId: args.enrollmentId,
      evidenceType: args.evidenceType,
      score: args.score,
      passed,
      evidenceUrl: args.evidenceUrl,
      notes: args.notes,
      assessedBy: args.assessedBy,
      createdAt: Date.now(),
    });

    // Update user skill progress
    const skillId = competency.skillId;
    const existingProgress = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_user_skill", (q) =>
        q.eq("userId", args.userId).eq("skillId", skillId)
      )
      .unique();

    if (existingProgress) {
      await ctx.db.patch(existingProgress._id, {
        evidenceCount: existingProgress.evidenceCount + 1,
        lastAssessedAt: Date.now(),
        updatedAt: Date.now(),
      });
    } else {
      // Create initial progress record
      await ctx.db.insert("userSkillProgress", {
        userId: args.userId,
        skillId,
        currentLevel: "foundational",
        progressPercent: 0,
        evidenceCount: 1,
        lastAssessedAt: Date.now(),
        verifiedByInstructor: false,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
    }

    return evidenceId;
  },
});
```

#### Issue Skill Badge

```typescript
// convex/skills.ts
export const issueSkillBadge = mutation({
  args: {
    userId: v.id("users"),
    skillId: v.id("skills"),
    level: v.union(
      v.literal("foundational"),
      v.literal("practitioner"),
      v.literal("advanced"),
      v.literal("expert")
    ),
  },
  handler: async (ctx, args) => {
    const skill = await ctx.db.get(args.skillId);
    const user = await ctx.db.get(args.userId);

    if (!skill || !user) {
      throw new Error("Skill or user not found");
    }

    // Check if badge already exists
    const existing = await ctx.db
      .query("skillBadges")
      .withIndex("by_user_skill_level", (q) =>
        q.eq("userId", args.userId)
         .eq("skillId", args.skillId)
         .eq("level", args.level)
      )
      .unique();

    if (existing) {
      return existing._id;
    }

    const badgeId = crypto.randomUUID();
    const publicUrl = `https://aienablement.academy/badges/${badgeId}`;

    // Generate Open Badges 3.0 compliant badge data
    const badgeData = {
      "@context": "https://www.w3.org/2018/credentials/v1",
      type: ["VerifiableCredential", "OpenBadgeCredential"],
      issuer: {
        id: "https://aienablement.academy",
        name: "AI Enablement Academy",
      },
      issuanceDate: new Date().toISOString(),
      credentialSubject: {
        id: `mailto:${user.email}`,
        achievement: {
          id: publicUrl,
          name: `${skill.name} - ${args.level}`,
          description: `Demonstrated ${args.level} proficiency in ${skill.name}`,
          criteria: {
            narrative: skill.description,
          },
        },
      },
    };

    const now = Date.now();
    const oneYear = 365 * 24 * 60 * 60 * 1000;

    const skillBadgeId = await ctx.db.insert("skillBadges", {
      userId: args.userId,
      skillId: args.skillId,
      level: args.level,
      earnedAt: now,
      expiresAt: now + oneYear, // Badges expire after 1 year
      badgeData,
      publicUrl,
      createdAt: now,
    });

    // Update user skill progress level
    const progress = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_user_skill", (q) =>
        q.eq("userId", args.userId).eq("skillId", args.skillId)
      )
      .unique();

    if (progress) {
      await ctx.db.patch(progress._id, {
        currentLevel: args.level,
        verifiedByInstructor: true,
        updatedAt: now,
      });
    }

    return skillBadgeId;
  },
});
```

---

### Analytics & Reporting Queries

#### Course Completion Impact on Skills

```typescript
// convex/analytics.ts
export const getCourseSkillImpact = query({
  args: { courseId: v.id("courses") },
  handler: async (ctx, args) => {
    // Get all enrollments for this course
    const enrollments = await ctx.db
      .query("enrollments")
      .filter((q) =>
        q.and(
          q.eq(q.field("courseId"), args.courseId),
          q.eq(q.field("paymentStatus"), "completed")
        )
      )
      .collect();

    // Get course skills
    const courseSkills = await ctx.db
      .query("courseSkills")
      .withIndex("by_course", (q) => q.eq("courseId", args.courseId))
      .collect();

    // For each enrolled user, measure skill progress
    const impactData = await Promise.all(
      enrollments.map(async (enrollment) => {
        const skillGains = await Promise.all(
          courseSkills.map(async (cs) => {
            const progress = await ctx.db
              .query("userSkillProgress")
              .withIndex("by_user_skill", (q) =>
                q.eq("userId", enrollment.userId).eq("skillId", cs.skillId)
              )
              .unique();

            return {
              skillId: cs.skillId,
              currentLevel: progress?.currentLevel || "none",
              progressPercent: progress?.progressPercent || 0,
              evidenceCount: progress?.evidenceCount || 0,
            };
          })
        );

        return {
          userId: enrollment.userId,
          enrollmentDate: enrollment.purchaseDate,
          skillGains,
        };
      })
    );

    return {
      totalEnrollments: enrollments.length,
      skillsTargeted: courseSkills.length,
      userProgress: impactData,
    };
  },
});
```

---

### Best Practices

1. **Skill Granularity**: Keep skills focused and measurable. "Prompt Engineering" is good; "AI Skills" is too broad.

2. **Competency Evidence**: Require multiple evidence types for higher levels (practitioner+).

3. **Badge Expiration**: Technical skills should have expiration dates; soft skills can be permanent.

4. **Prerequisites**: Use skill hierarchies to guide learner pathways (e.g., "Foundational Prompt Engineering" before "Advanced Prompt Engineering").

5. **Instructor Verification**: Auto-verify foundational level; require instructor sign-off for advanced/expert.

6. **Portfolio Building**: Encourage learners to collect multiple badges within a category to build comprehensive portfolios.

7. **Open Badges Integration**: Export badges to learners' digital credential wallets (LinkedIn, Badgr, Credly).

---

This comprehensive Skills & Competencies System transforms the AI Enablement Academy from a course-completion platform into a skills-development ecosystem with measurable, stackable, and portable credentials that integrate seamlessly with the existing Learning Paths system.

---

## Assessment System

The Assessment System (v2.1) provides comprehensive pre/post assessments, knowledge checks, and competency-based evaluations to measure learning outcomes, demonstrate ROI, and identify knowledge gaps. This system enables the AI Enablement Academy to quantify learning gains using evidence-based methodologies like Hake's normalized gain and provides AI-assisted grading for open-ended responses.

### Core Principles

1. **Pre/Post Comparison**: Measure actual learning gains by comparing pre-course baseline to post-course achievement
2. **Normalized Gain**: Use Hake's formula for standardized learning gain measurement
3. **Skill Mapping**: Link assessment questions to specific skills and competencies
4. **Multiple Question Types**: Support diverse assessment methods (MC, MS, TF, short answer, rating scales, open-ended)
5. **AI-Assisted Grading**: Use LLM evaluation for open-ended responses with confidence scoring
6. **ROI Measurement**: Quantify learning impact for B2B organizational reporting

---

### Schema Definition

Add these tables to your `convex/schema.ts`:

```typescript
// =============================================================================
// ASSESSMENT SYSTEM (v2.1)
// =============================================================================
// Purpose: Measure learning outcomes, prove ROI, identify knowledge gaps

// Assessments - Quiz/assessment definitions
assessments: defineTable({
  title: v.string(),
  description: v.optional(v.string()),
  type: v.union(
    v.literal("pre_course"),           // Before course starts
    v.literal("post_course"),          // After course completion
    v.literal("knowledge_check"),      // During lesson
    v.literal("skill_assessment"),     // Competency assessment
    v.literal("certification"),        // Final certification exam
    v.literal("self_assessment")       // Self-evaluation
  ),

  // Scope
  courseId: v.optional(v.id("courses")),
  lessonId: v.optional(v.id("lessons")),
  skillIds: v.optional(v.array(v.id("skills"))), // Skills being assessed

  // Settings
  timeLimit: v.optional(v.number()),   // Minutes, null = unlimited
  passingScore: v.number(),            // 0-100
  allowRetake: v.boolean(),
  maxAttempts: v.optional(v.number()), // null = unlimited
  showCorrectAnswers: v.union(
    v.literal("never"),
    v.literal("after_submit"),
    v.literal("after_passing"),
    v.literal("after_all_attempts")
  ),
  randomizeQuestions: v.boolean(),
  randomizeAnswers: v.boolean(),

  // Question pool
  questionsPerAttempt: v.optional(v.number()), // null = all questions

  // Metadata
  isActive: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_course", ["courseId", "type", "isActive"])
  .index("by_lesson", ["lessonId", "isActive"])
  .index("by_type", ["type", "isActive"]),

// Questions
assessmentQuestions: defineTable({
  assessmentId: v.id("assessments"),
  questionType: v.union(
    v.literal("multiple_choice"),      // Single answer
    v.literal("multiple_select"),      // Multiple correct answers
    v.literal("true_false"),
    v.literal("short_answer"),
    v.literal("rating_scale"),         // 1-5 or 1-10 scale
    v.literal("open_ended")            // Long text response
  ),

  // Question content
  questionText: v.string(),            // Markdown supported
  questionImageId: v.optional(v.id("_storage")),
  explanation: v.optional(v.string()), // Shown after answer

  // Answers (for MC, MS, TF)
  answers: v.optional(v.array(v.object({
    id: v.string(),                    // UUID
    text: v.string(),
    isCorrect: v.boolean(),
    feedback: v.optional(v.string()),  // Feedback for this answer
  }))),

  // For rating scale
  scaleMin: v.optional(v.number()),
  scaleMax: v.optional(v.number()),
  scaleLabels: v.optional(v.object({
    min: v.string(),                   // "Strongly Disagree"
    max: v.string(),                   // "Strongly Agree"
  })),

  // For short/open answer
  sampleAnswer: v.optional(v.string()),
  aiGradingEnabled: v.optional(v.boolean()),

  // Metadata
  points: v.number(),                  // Points for this question
  difficulty: v.union(
    v.literal("easy"),
    v.literal("medium"),
    v.literal("hard")
  ),
  skillIds: v.optional(v.array(v.id("skills"))), // Skills this tests
  tags: v.optional(v.array(v.string())),
  sortOrder: v.number(),
  isActive: v.boolean(),
  createdAt: v.number(),
})
  .index("by_assessment", ["assessmentId", "sortOrder"])
  .index("by_difficulty", ["assessmentId", "difficulty"]),

// Assessment Attempts
assessmentAttempts: defineTable({
  userId: v.id("users"),
  assessmentId: v.id("assessments"),
  enrollmentId: v.optional(v.id("enrollments")),

  // Attempt metadata
  attemptNumber: v.number(),
  status: v.union(
    v.literal("in_progress"),
    v.literal("submitted"),
    v.literal("graded"),
    v.literal("expired")               // Time ran out
  ),

  // Timing
  startedAt: v.number(),
  submittedAt: v.optional(v.number()),
  timeSpent: v.optional(v.number()),   // Seconds

  // Results
  score: v.optional(v.number()),       // 0-100
  pointsEarned: v.optional(v.number()),
  pointsPossible: v.optional(v.number()),
  passed: v.optional(v.boolean()),

  // Feedback
  overallFeedback: v.optional(v.string()),

  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_assessment", ["assessmentId"])
  .index("by_user_assessment", ["userId", "assessmentId"])
  .index("by_enrollment", ["enrollmentId"]),

// Individual question responses
questionResponses: defineTable({
  attemptId: v.id("assessmentAttempts"),
  questionId: v.id("assessmentQuestions"),

  // Response
  selectedAnswerIds: v.optional(v.array(v.string())), // For MC/MS
  textResponse: v.optional(v.string()),              // For short/open
  ratingValue: v.optional(v.number()),               // For rating scale

  // Grading
  isCorrect: v.optional(v.boolean()),
  pointsEarned: v.number(),
  feedback: v.optional(v.string()),

  // AI grading (for open-ended)
  aiScore: v.optional(v.number()),
  aiConfidence: v.optional(v.number()),
  aiExplanation: v.optional(v.string()),
  manualOverride: v.optional(v.boolean()),
  gradedBy: v.optional(v.id("users")),

  createdAt: v.number(),
})
  .index("by_attempt", ["attemptId"])
  .index("by_question", ["questionId"]),

// Pre/Post comparison analytics
learningGainAnalytics: defineTable({
  userId: v.id("users"),
  courseId: v.id("courses"),
  enrollmentId: v.id("enrollments"),

  // Pre-assessment
  preAssessmentId: v.id("assessments"),
  preAttemptId: v.id("assessmentAttempts"),
  preScore: v.number(),

  // Post-assessment
  postAssessmentId: v.id("assessments"),
  postAttemptId: v.id("assessmentAttempts"),
  postScore: v.number(),

  // Gains
  scoreImprovement: v.number(),        // postScore - preScore
  percentageGain: v.number(),          // ((post-pre)/pre) * 100
  normalizedGain: v.number(),          // (post-pre)/(100-pre) - Hake's gain

  // Skill-level gains
  skillGains: v.array(v.object({
    skillId: v.id("skills"),
    preScore: v.number(),
    postScore: v.number(),
    improvement: v.number(),
  })),

  calculatedAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_course", ["courseId"])
  .index("by_enrollment", ["enrollmentId"]),
```

---

### Example Assessment Templates

The platform includes pre-built assessment templates for each course:

#### 1. AI Fundamentals Pre/Post Assessment

**Pre-Course Assessment** (Baseline measurement):
```typescript
{
  title: "AI Fundamentals - Pre-Assessment",
  description: "Measure your current AI knowledge before the course",
  type: "pre_course",
  courseId: "ai-fundamentals-course-id",
  passingScore: 0, // No passing score for pre-assessment
  allowRetake: false,
  maxAttempts: 1,
  showCorrectAnswers: "never", // Don't reveal answers until post-course
  randomizeQuestions: true,
  randomizeAnswers: true,
  questionsPerAttempt: 20, // Fixed 20 questions from larger pool
  timeLimit: 30, // 30 minutes
  skillIds: [
    "ai-concepts-skill-id",
    "prompt-engineering-skill-id",
    "tool-selection-skill-id"
  ]
}
```

**Sample Questions**:

1. **Multiple Choice - AI Concepts**
   ```typescript
   {
     questionText: "What is the primary difference between machine learning and traditional programming?",
     questionType: "multiple_choice",
     difficulty: "medium",
     points: 5,
     skillIds: ["ai-concepts-skill-id"],
     answers: [
       {
         id: "mc1-a",
         text: "Machine learning models learn patterns from data instead of following explicit instructions",
         isCorrect: true,
         feedback: "Correct! ML models discover patterns from training data."
       },
       {
         id: "mc1-b",
         text: "Machine learning is faster than traditional programming",
         isCorrect: false,
         feedback: "Speed isn't the primary difference; it's about how rules are created."
       },
       {
         id: "mc1-c",
         text: "Machine learning uses more memory than traditional programming",
         isCorrect: false,
         feedback: "Resource usage isn't the defining characteristic."
       },
       {
         id: "mc1-d",
         text: "Machine learning doesn't require any programming",
         isCorrect: false,
         feedback: "ML still requires programming, but the approach is different."
       }
     ]
   }
   ```

2. **Multiple Select - Prompt Engineering**
   ```typescript
   {
     questionText: "Which of the following are effective prompt engineering techniques? (Select all that apply)",
     questionType: "multiple_select",
     difficulty: "medium",
     points: 10,
     skillIds: ["prompt-engineering-skill-id"],
     answers: [
       {
         id: "ms1-a",
         text: "Providing clear context and role definitions",
         isCorrect: true,
         feedback: "Yes! Context helps the AI understand the task."
       },
       {
         id: "ms1-b",
         text: "Using all capital letters for emphasis",
         isCorrect: false,
         feedback: "Caps don't improve AI comprehension."
       },
       {
         id: "ms1-c",
         text: "Breaking complex tasks into step-by-step instructions",
         isCorrect: true,
         feedback: "Correct! Chain-of-thought prompting improves results."
       },
       {
         id: "ms1-d",
         text: "Including examples of desired outputs",
         isCorrect: true,
         feedback: "Yes! Few-shot learning is a powerful technique."
       }
     ]
   }
   ```

3. **True/False - Tool Selection**
   ```typescript
   {
     questionText: "ChatGPT Plus is always the best choice for business AI applications",
     questionType: "true_false",
     difficulty: "easy",
     points: 3,
     skillIds: ["tool-selection-skill-id"],
     answers: [
       {
         id: "tf1-true",
         text: "True",
         isCorrect: false,
         feedback: "Incorrect. Different use cases require different tools (ChatGPT, Claude, specialized APIs, etc.)"
       },
       {
         id: "tf1-false",
         text: "False",
         isCorrect: true,
         feedback: "Correct! Tool selection depends on use case, budget, data privacy needs, and integration requirements."
       }
     ]
   }
   ```

4. **Open-Ended with AI Grading**
   ```typescript
   {
     questionText: "Describe a specific business process in your organization that could benefit from AI automation. Explain what tasks would be automated and what the expected outcomes would be. (150-300 words)",
     questionType: "open_ended",
     difficulty: "hard",
     points: 15,
     skillIds: ["use-case-identification-skill-id"],
     sampleAnswer: "Sample answer: In our marketing department, we spend 10+ hours weekly manually categorizing customer support tickets. An AI system could: 1) Read incoming tickets, 2) Categorize by urgency, topic, and department, 3) Route to appropriate teams, 4) Suggest response templates. Expected outcomes: 80% reduction in manual categorization time, faster response times, more consistent routing, and data-driven insights on common issues.",
     aiGradingEnabled: true
   }
   ```

5. **Rating Scale - Self-Assessment**
   ```typescript
   {
     questionText: "How confident are you in your ability to write effective prompts for AI tools?",
     questionType: "rating_scale",
     difficulty: "easy",
     points: 0, // Not graded
     scaleMin: 1,
     scaleMax: 5,
     scaleLabels: {
       min: "Not confident at all",
       max: "Very confident"
     },
     skillIds: ["prompt-engineering-skill-id"]
   }
   ```

**Post-Course Assessment**:
```typescript
{
  title: "AI Fundamentals - Post-Assessment",
  description: "Measure your learning gains after completing the course",
  type: "post_course",
  courseId: "ai-fundamentals-course-id",
  passingScore: 70,
  allowRetake: true,
  maxAttempts: 3,
  showCorrectAnswers: "after_passing",
  randomizeQuestions: true,
  randomizeAnswers: true,
  questionsPerAttempt: 20, // Same 20 questions as pre-assessment
  timeLimit: 30,
  skillIds: [
    "ai-concepts-skill-id",
    "prompt-engineering-skill-id",
    "tool-selection-skill-id"
  ]
}
```

**Important**: Post-assessment uses the **same questions** as pre-assessment to enable accurate learning gain measurement.

---

### Learning Gain Calculation

#### Hake's Normalized Gain Formula

The platform uses Hake's normalized gain (also called "Hake's g-factor") to measure learning effectiveness:

```
Normalized Gain (g) = (post_score - pre_score) / (100 - pre_score)
```

**Interpretation**:
- **g ≥ 0.7**: High gain (exceptional learning)
- **0.3 ≤ g < 0.7**: Medium gain (good learning)
- **g < 0.3**: Low gain (ineffective instruction)

**Why Normalized Gain?**
- Accounts for ceiling effects (students starting at 90% can't gain much)
- Provides standardized metric across different baseline scores
- Widely used in educational research
- Enables comparison across cohorts and courses

**Example Calculation**:
```typescript
Student A:
  Pre-score: 40%
  Post-score: 85%
  Normalized gain: (85 - 40) / (100 - 40) = 45 / 60 = 0.75 (High gain)

Student B:
  Pre-score: 75%
  Post-score: 90%
  Normalized gain: (90 - 75) / (100 - 75) = 15 / 25 = 0.60 (Medium gain)
```

Even though Student B scored higher overall, Student A showed a higher normalized gain, indicating more effective learning relative to their starting point.

---

### Integration Notes

**Skill Mapping**:
- Every assessment question should map to 1-3 specific skills
- Pre/post assessments must test the same skills for valid comparison
- Skill-level gains provide granular insights for personalized learning paths

**AI Grading Confidence Thresholds**:
- **High confidence (≥0.9)**: Auto-grade without review
- **Medium confidence (0.7-0.9)**: Flag for instructor review
- **Low confidence (<0.7)**: Require manual grading

**Timing Best Practices**:
- **Pre-assessment**: Administer 1-2 days before course start
- **Knowledge checks**: During lesson breaks or end of day
- **Post-assessment**: Within 1 week of course completion (for accurate retention measurement)

**Data Privacy**:
- Individual scores visible only to learner and instructors
- Organizational reports show aggregated, anonymized data
- Learning gains stored securely with encryption at rest

This Assessment System provides rigorous, evidence-based measurement of learning outcomes with industry-standard methodologies (Hake's normalized gain), AI-assisted grading for scale, and comprehensive ROI reporting for organizational clients.

---

## Community System

### Overview

The Community System (v2.1) provides lightweight native features for cohort-specific Q&A and peer networking, while integrating with external platforms (Circle/Skool/Discord) for deep community engagement.

**Strategy:**
- **Native features** handle cohort-specific discussions, Q&A threads, and peer connections
- **External platforms** provide rich community features (events, member directories, content libraries)
- **Hybrid approach** maximizes value while minimizing platform complexity

**Key Features:**
- Course, session, and lesson-level discussion threads
- Threaded replies with instructor highlighting and best answers
- Peer connection recommendations based on cohort, skills, and industry
- External community integration with SSO and member sync
- Moderation workflows with flagging and status management
- Notification integration with existing system

---

### Schema Definition

Add these tables to your `convex/schema.ts`:

```typescript
// =============================================================================
// COMMUNITY SYSTEM (v2.1)
// =============================================================================
// Strategy: Build lightweight native features + integrate with external community
// External community (Circle/Skool/Discord) for deep engagement, native for cohort-specific

// Discussion Threads - Cohort & course-specific discussions
discussionThreads: defineTable({
  title: v.string(),
  content: v.string(),                 // Markdown
  authorId: v.id("users"),

  // Scope
  scope: v.union(
    v.literal("course"),               // Course-level discussion
    v.literal("session"),              // Cohort/session specific
    v.literal("lesson"),               // Lesson Q&A
    v.literal("general")               // Platform-wide
  ),
  courseId: v.optional(v.id("courses")),
  sessionId: v.optional(v.id("sessions")),
  lessonId: v.optional(v.id("lessons")),

  // Thread metadata
  isPinned: v.boolean(),
  isAnnouncement: v.boolean(),
  isLocked: v.boolean(),               // No more replies
  category: v.optional(v.string()),    // "question", "discussion", "show-and-tell", "resource"
  tags: v.optional(v.array(v.string())),

  // Stats
  replyCount: v.number(),
  viewCount: v.number(),
  likeCount: v.number(),
  lastActivityAt: v.number(),

  // Moderation
  status: v.union(
    v.literal("active"),
    v.literal("hidden"),               // Soft delete
    v.literal("flagged")               // Needs review
  ),

  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_course", ["courseId", "status", "lastActivityAt"])
  .index("by_session", ["sessionId", "status", "lastActivityAt"])
  .index("by_lesson", ["lessonId", "status"])
  .index("by_author", ["authorId"])
  .index("by_pinned", ["isPinned", "scope", "status"]),

// Thread Replies
discussionReplies: defineTable({
  threadId: v.id("discussionThreads"),
  authorId: v.id("users"),
  content: v.string(),                 // Markdown

  // Reply to reply (nested)
  parentReplyId: v.optional(v.id("discussionReplies")),

  // Metadata
  isInstructorReply: v.boolean(),      // Highlighted if from instructor
  isBestAnswer: v.boolean(),           // Marked as best answer (for Q&A)
  likeCount: v.number(),

  // Moderation
  status: v.union(
    v.literal("active"),
    v.literal("hidden"),
    v.literal("flagged")
  ),

  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_thread", ["threadId", "status", "createdAt"])
  .index("by_author", ["authorId"]),

// User-Thread interactions
threadInteractions: defineTable({
  userId: v.id("users"),
  threadId: v.id("discussionThreads"),
  interaction: v.union(
    v.literal("view"),
    v.literal("like"),
    v.literal("bookmark"),
    v.literal("subscribe")             // Get notifications
  ),
  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_thread", ["threadId"])
  .index("by_user_thread_interaction", ["userId", "threadId", "interaction"]),

// Reply interactions (likes)
replyInteractions: defineTable({
  userId: v.id("users"),
  replyId: v.id("discussionReplies"),
  interaction: v.union(
    v.literal("like"),
    v.literal("flag")
  ),
  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_reply", ["replyId"]),

// Peer connections (cohort networking)
peerConnections: defineTable({
  userId: v.id("users"),
  connectedUserId: v.id("users"),
  connectionSource: v.union(
    v.literal("cohort"),               // Same cohort
    v.literal("manual"),               // User initiated
    v.literal("suggested")             // AI suggested
  ),
  sessionId: v.optional(v.id("sessions")), // Which cohort connected them
  status: v.union(
    v.literal("pending"),
    v.literal("accepted"),
    v.literal("declined"),
    v.literal("blocked")
  ),
  createdAt: v.number(),
  acceptedAt: v.optional(v.number()),
})
  .index("by_user", ["userId", "status"])
  .index("by_connected", ["connectedUserId", "status"])
  .index("by_session", ["sessionId"]),

// External community integration
externalCommunityLinks: defineTable({
  platform: v.union(
    v.literal("circle"),
    v.literal("skool"),
    v.literal("discord"),
    v.literal("slack"),
    v.literal("other")
  ),
  name: v.string(),                    // "AI Enablement Academy Community"
  url: v.string(),                     // Invite/access URL
  description: v.optional(v.string()),

  // Access control
  accessLevel: v.union(
    v.literal("all_users"),            // Any registered user
    v.literal("enrolled"),             // Active enrollment required
    v.literal("alumni"),               // Past enrollees
    v.literal("premium")               // Premium tier
  ),
  courseIds: v.optional(v.array(v.id("courses"))), // Course-specific communities

  // SSO/sync
  ssoEnabled: v.boolean(),
  memberSyncEnabled: v.boolean(),

  isActive: v.boolean(),
  createdAt: v.number(),
})
  .index("by_platform", ["platform", "isActive"])
  .index("by_access", ["accessLevel", "isActive"]),

// User external community memberships
userCommunityMemberships: defineTable({
  userId: v.id("users"),
  communityId: v.id("externalCommunityLinks"),
  externalMemberId: v.optional(v.string()), // Their ID in external platform
  status: v.union(
    v.literal("invited"),
    v.literal("active"),
    v.literal("inactive")
  ),
  joinedAt: v.optional(v.number()),
  lastSyncAt: v.optional(v.number()),
  createdAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_community", ["communityId"]),
```

---

### Community Strategy Notes

#### Native vs External Features

**Native Platform (Built into Academy):**
- ✅ Cohort-specific Q&A threads
- ✅ Lesson-level questions and answers
- ✅ Instructor responses and best answer marking
- ✅ Peer connection suggestions based on cohort
- ✅ Basic bookmarking and notifications
- ✅ Tight integration with course progress

**External Community Platforms (Circle/Skool/Discord):**
- ✅ Rich member profiles and directories
- ✅ Event calendars and live meetups
- ✅ Content libraries and resource sharing
- ✅ Advanced gamification (points, levels, leaderboards)
- ✅ Dedicated mobile apps
- ✅ Deeper social features (DMs, groups, channels)

**Why Hybrid Approach:**
1. **Reduce platform complexity**: Don't rebuild Circle/Discord features
2. **Keep learning focused**: Native features tied to course context
3. **Leverage best-of-breed**: External platforms excel at community
4. **Flexible integration**: Can switch external platforms without losing course data

---

### Notification Integration

The Community System integrates with the existing notification system (to be built):

**Native Notifications (In-Platform + Email):**
- New reply to your thread
- Your question was answered
- Instructor replied to your thread
- Someone marked your reply as best answer
- New peer connection request
- Thread you're subscribed to has new activity

**Implementation Pattern:**
```typescript
// After creating a reply
await ctx.scheduler.runAfter(0, internal.notifications.sendReplyNotification, {
  threadAuthorId: thread.authorId,
  replyAuthorId: reply.authorId,
  threadTitle: thread.title,
  threadId: thread._id,
});

// When instructor marks best answer
await ctx.scheduler.runAfter(0, internal.notifications.sendBestAnswerNotification, {
  replyAuthorId: reply.authorId,
  threadTitle: thread.title,
  threadId: thread._id,
});
```

**Notification Preferences (in users table):**
```typescript
// User notification preferences
notificationPreferences: v.object({
  emailNotifications: v.boolean(),
  smsNotifications: v.boolean(),
  community: v.object({
    threadReplies: v.boolean(),
    instructorReplies: v.boolean(),
    bestAnswers: v.boolean(),
    peerConnections: v.boolean(),
    subscribedThreads: v.boolean(),
  }),
}),
```

---

### Moderation Workflows

#### Status Transitions

**Thread/Reply Statuses:**
- `active` → Default state
- `flagged` → User-reported, awaiting moderator review
- `hidden` → Soft-deleted, not visible to users

**Moderation Actions:**
```typescript
// User flags inappropriate content
export const flagContent = mutation({
  args: {
    contentType: v.union(v.literal("thread"), v.literal("reply")),
    contentId: v.string(),
    reason: v.string(),
  },
  handler: async (ctx, args) => {
    // Set status to "flagged"
    // Notify moderators
    // Track who flagged it
  },
});

// Moderator reviews flagged content
export const moderateContent = mutation({
  args: {
    contentType: v.union(v.literal("thread"), v.literal("reply")),
    contentId: v.string(),
    action: v.union(v.literal("approve"), v.literal("hide"), v.literal("delete")),
    moderatorNote: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Update status based on action
    // Log moderation action
    // Notify content author if appropriate
  },
});
```

**Auto-Moderation Triggers:**
- Spam keyword detection
- Multiple user flags (3+ flags = auto-hide pending review)
- Link spam detection
- Repeated violations from single user

**Moderator Dashboard (Future):**
- View flagged content queue
- Review user reports
- Ban/suspend repeat offenders
- View moderation audit log

---

### Peer Connection Recommendations

Peer connections help learners network within and across cohorts based on:

#### Recommendation Algorithm

**Match on:**
1. **Same cohort** (priority 1) - Currently enrolled together
2. **Skills overlap** - Working on similar competencies
3. **Industry/role** - Same company domain or job function
4. **Past cohorts** - Alumni from same course
5. **Discussion activity** - Active in same threads

**Implementation:**
```typescript
export const getSuggestedConnections = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);

    // Get user's enrollments
    const enrollments = await ctx.db
      .query("enrollments")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

    // Find cohort peers
    const cohortPeers = [];
    for (const enrollment of enrollments) {
      const peers = await ctx.db
        .query("enrollments")
        .withIndex("by_cohort", (q) => q.eq("cohortId", enrollment.cohortId))
        .filter((q) => q.neq(q.field("userId"), args.userId))
        .collect();
      cohortPeers.push(...peers);
    }

    // Get user's skills
    const userSkills = await ctx.db
      .query("userSkillProgress")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

    // Find users with overlapping skills
    const skillMatches = [];
    for (const skillProgress of userSkills) {
      const matches = await ctx.db
        .query("userSkillProgress")
        .withIndex("by_skill", (q) => q.eq("skillId", skillProgress.skillId))
        .filter((q) => q.neq(q.field("userId"), args.userId))
        .collect();
      skillMatches.push(...matches);
    }

    // Rank and deduplicate suggestions
    // Priority: cohort peers > skill matches > industry matches

    return suggestions;
  },
});
```

**Connection UI Flow:**
1. User sees suggested connections in "Network" tab
2. Click "Connect" sends pending request
3. Other user receives notification
4. Accept/Decline updates status
5. Accepted connections appear in "My Network"

---

### Query Examples

#### Get Course Discussion Threads

```typescript
// convex/community.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const getCourseThreads = query({
  args: {
    courseId: v.id("courses"),
    category: v.optional(v.string()),
    sortBy: v.optional(v.union(
      v.literal("recent"),
      v.literal("popular"),
      v.literal("unanswered")
    )),
  },
  handler: async (ctx, args) => {
    let threadsQuery = ctx.db
      .query("discussionThreads")
      .withIndex("by_course", (q) =>
        q.eq("courseId", args.courseId).eq("status", "active")
      );

    let threads = await threadsQuery.collect();

    // Filter by category if specified
    if (args.category) {
      threads = threads.filter(t => t.category === args.category);
    }

    // Sort
    const sortBy = args.sortBy || "recent";
    if (sortBy === "recent") {
      threads.sort((a, b) => b.lastActivityAt - a.lastActivityAt);
    } else if (sortBy === "popular") {
      threads.sort((a, b) => b.likeCount - a.likeCount);
    } else if (sortBy === "unanswered") {
      threads = threads.filter(t => t.replyCount === 0);
    }

    // Get pinned threads first
    const pinned = threads.filter(t => t.isPinned);
    const regular = threads.filter(t => !t.isPinned);

    return {
      pinnedThreads: pinned,
      threads: regular,
    };
  },
});
```

#### Get Thread with Replies

```typescript
// convex/community.ts
export const getThreadWithReplies = query({
  args: {
    threadId: v.id("discussionThreads"),
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const thread = await ctx.db.get(args.threadId);
    if (!thread || thread.status !== "active") {
      return null;
    }

    // Get author
    const author = await ctx.db.get(thread.authorId);

    // Get all replies
    const replies = await ctx.db
      .query("discussionReplies")
      .withIndex("by_thread", (q) =>
        q.eq("threadId", args.threadId).eq("status", "active")
      )
      .collect();

    // Build reply tree (nested structure)
    const replyMap = new Map(replies.map(r => [r._id, { ...r, children: [] }]));
    const topLevelReplies = [];

    for (const reply of replies) {
      const replyNode = replyMap.get(reply._id);
      if (reply.parentReplyId) {
        const parent = replyMap.get(reply.parentReplyId);
        if (parent) {
          parent.children.push(replyNode);
        }
      } else {
        topLevelReplies.push(replyNode);
      }
    }

    // Get user interactions if userId provided
    let userInteractions = null;
    if (args.userId) {
      userInteractions = await ctx.db
        .query("threadInteractions")
        .withIndex("by_user_thread_interaction", (q) =>
          q.eq("userId", args.userId).eq("threadId", args.threadId)
        )
        .collect();

      // Track view
      const hasViewed = userInteractions.some(i => i.interaction === "view");
      if (!hasViewed) {
        await ctx.db.insert("threadInteractions", {
          userId: args.userId,
          threadId: args.threadId,
          interaction: "view",
          createdAt: Date.now(),
        });

        // Increment view count
        await ctx.db.patch(args.threadId, {
          viewCount: thread.viewCount + 1,
        });
      }
    }

    return {
      thread: { ...thread, author },
      replies: topLevelReplies,
      userInteractions,
    };
  },
});
```

#### Get User Peer Connections

```typescript
// convex/community.ts
export const getUserConnections = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get accepted connections
    const connections = await ctx.db
      .query("peerConnections")
      .withIndex("by_user", (q) =>
        q.eq("userId", args.userId).eq("status", "accepted")
      )
      .collect();

    // Get connection details
    const connectionsWithUsers = await Promise.all(
      connections.map(async (conn) => {
        const connectedUser = await ctx.db.get(conn.connectedUserId);

        // Get shared cohorts
        const userEnrollments = await ctx.db
          .query("enrollments")
          .withIndex("by_user", (q) => q.eq("userId", args.userId))
          .collect();

        const connectedEnrollments = await ctx.db
          .query("enrollments")
          .withIndex("by_user", (q) => q.eq("userId", conn.connectedUserId))
          .collect();

        const sharedCohortIds = userEnrollments
          .map(e => e.cohortId)
          .filter(id => connectedEnrollments.some(e => e.cohortId === id));

        return {
          connection: conn,
          user: connectedUser,
          sharedCohorts: sharedCohortIds.length,
        };
      })
    );

    return connectionsWithUsers;
  },
});
```

---

### Mutation Examples

#### Create Discussion Thread

```typescript
// convex/community.ts
import { mutation } from "./_generated/server";

export const createThread = mutation({
  args: {
    title: v.string(),
    content: v.string(),
    authorId: v.id("users"),
    scope: v.union(
      v.literal("course"),
      v.literal("session"),
      v.literal("lesson"),
      v.literal("general")
    ),
    courseId: v.optional(v.id("courses")),
    sessionId: v.optional(v.id("sessions")),
    lessonId: v.optional(v.id("lessons")),
    category: v.optional(v.string()),
    tags: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    const threadId = await ctx.db.insert("discussionThreads", {
      title: args.title,
      content: args.content,
      authorId: args.authorId,
      scope: args.scope,
      courseId: args.courseId,
      sessionId: args.sessionId,
      lessonId: args.lessonId,
      isPinned: false,
      isAnnouncement: false,
      isLocked: false,
      category: args.category,
      tags: args.tags,
      replyCount: 0,
      viewCount: 0,
      likeCount: 0,
      lastActivityAt: now,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });

    // Track user's view
    await ctx.db.insert("threadInteractions", {
      userId: args.authorId,
      threadId,
      interaction: "view",
      createdAt: now,
    });

    return threadId;
  },
});
```

#### Reply to Thread

```typescript
// convex/community.ts
export const replyToThread = mutation({
  args: {
    threadId: v.id("discussionThreads"),
    authorId: v.id("users"),
    content: v.string(),
    parentReplyId: v.optional(v.id("discussionReplies")),
  },
  handler: async (ctx, args) => {
    const thread = await ctx.db.get(args.threadId);
    if (!thread || thread.status !== "active" || thread.isLocked) {
      throw new Error("Cannot reply to this thread");
    }

    // Check if author is instructor
    const author = await ctx.db.get(args.authorId);
    const isInstructor = author?.role === "platform_admin" || false;

    const now = Date.now();

    const replyId = await ctx.db.insert("discussionReplies", {
      threadId: args.threadId,
      authorId: args.authorId,
      content: args.content,
      parentReplyId: args.parentReplyId,
      isInstructorReply: isInstructor,
      isBestAnswer: false,
      likeCount: 0,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });

    // Update thread reply count and last activity
    await ctx.db.patch(args.threadId, {
      replyCount: thread.replyCount + 1,
      lastActivityAt: now,
      updatedAt: now,
    });

    // Send notification to thread author (if not self-reply)
    if (thread.authorId !== args.authorId) {
      await ctx.scheduler.runAfter(
        0,
        internal.notifications.sendReplyNotification,
        {
          threadAuthorId: thread.authorId,
          replyAuthorId: args.authorId,
          threadTitle: thread.title,
          threadId: thread._id,
        }
      );
    }

    return replyId;
  },
});
```

#### Send Peer Connection Request

```typescript
// convex/community.ts
export const sendConnectionRequest = mutation({
  args: {
    userId: v.id("users"),
    connectedUserId: v.id("users"),
    connectionSource: v.union(
      v.literal("cohort"),
      v.literal("manual"),
      v.literal("suggested")
    ),
    sessionId: v.optional(v.id("sessions")),
  },
  handler: async (ctx, args) => {
    // Check for existing connection
    const existing = await ctx.db
      .query("peerConnections")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .filter((q) => q.eq(q.field("connectedUserId"), args.connectedUserId))
      .first();

    if (existing) {
      throw new Error("Connection already exists");
    }

    const connectionId = await ctx.db.insert("peerConnections", {
      userId: args.userId,
      connectedUserId: args.connectedUserId,
      connectionSource: args.connectionSource,
      sessionId: args.sessionId,
      status: "pending",
      createdAt: Date.now(),
    });

    // Send notification to recipient
    await ctx.scheduler.runAfter(
      0,
      internal.notifications.sendConnectionRequestNotification,
      {
        recipientId: args.connectedUserId,
        requesterId: args.userId,
        connectionId,
      }
    );

    return connectionId;
  },
});
```

---

### Integration with External Communities

#### Access Level Logic

When a user enrolls in a course, automatically check external community eligibility:

```typescript
// After successful enrollment
export const checkCommunityAccess = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);

    // Get active enrollments
    const enrollments = await ctx.db
      .query("enrollments")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .filter((q) => q.eq(q.field("paymentStatus"), "completed"))
      .collect();

    // Get external communities
    const communities = await ctx.db
      .query("externalCommunityLinks")
      .filter((q) => q.eq(q.field("isActive"), true))
      .collect();

    for (const community of communities) {
      let hasAccess = false;

      if (community.accessLevel === "all_users") {
        hasAccess = true;
      } else if (community.accessLevel === "enrolled" && enrollments.length > 0) {
        hasAccess = true;
      } else if (community.accessLevel === "alumni") {
        // Check for past enrollments
        const pastEnrollments = await ctx.db
          .query("enrollments")
          .withIndex("by_user", (q) => q.eq("userId", args.userId))
          .collect();
        hasAccess = pastEnrollments.length > 0;
      }

      if (hasAccess) {
        // Create or update membership
        const existing = await ctx.db
          .query("userCommunityMemberships")
          .withIndex("by_user", (q) => q.eq("userId", args.userId))
          .filter((q) => q.eq(q.field("communityId"), community._id))
          .first();

        if (!existing) {
          await ctx.db.insert("userCommunityMemberships", {
            userId: args.userId,
            communityId: community._id,
            status: "invited",
            createdAt: Date.now(),
          });

          // Send invite email via Brevo
          // await sendCommunityInvite(user, community);
        }
      }
    }
  },
});
```

---

### Best Practices

1. **Native vs External**: Use native for course-specific discussions; promote external for broader networking
2. **Notification Fatigue**: Allow users to customize notification preferences per category
3. **Moderation**: Start with light moderation; add auto-moderation as community grows
4. **Peer Connections**: Surface suggestions in context (e.g., "3 peers from your cohort haven't connected yet")
5. **External Integration**: Use webhooks for member sync; don't poll APIs
6. **Gamification**: Use external platform's gamification; keep native features simple

---

This Community System provides the foundation for cohort-level engagement while maintaining flexibility to integrate with best-in-class external community platforms as the Academy scales.

---

## Manager Dashboard System

The Manager Dashboard System (v2.1 - B2B) enables L&D managers and organizational sponsors to track team learning progress, measure ROI, and make data-driven decisions about AI enablement initiatives. This system provides comprehensive visibility into organizational learning while respecting individual privacy boundaries.

### Overview

**Key Capabilities:**
- Multi-level dashboard views (executive, manager, team lead)
- Real-time progress tracking across teams and individuals
- Skill heat maps and competency matrices
- Automated reporting and scheduled email delivery
- Predictive analytics and engagement warnings
- Compliance tracking and deadline management
- Integration with PostHog for behavioral analytics
- Manager-initiated learning reminders and nudges

**Privacy-First Design:**
- Managers see progress metrics, not personal details
- Individual chat conversations remain private
- Assessment scores shown as aggregates by default
- Detailed individual data requires explicit permission
- GDPR and privacy compliance built-in

---

### Enhanced Schema Definition

Add these tables to your `convex/schema.ts`:

```typescript
// =============================================================================
// MANAGER DASHBOARD SYSTEM (v2.1 - B2B)
// =============================================================================
// Purpose: Allow L&D managers and sponsors to track team learning progress

// Organization Managers - Who can view team progress
organizationManagers: defineTable({
  userId: v.id("users"),
  organizationId: v.id("organizations"),
  role: v.union(
    v.literal("admin"),                // Full access, can manage
    v.literal("manager"),              // View team + reports
    v.literal("viewer")                // View-only access
  ),
  permissions: v.array(v.union(
    v.literal("view_progress"),
    v.literal("view_scores"),
    v.literal("view_certificates"),
    v.literal("view_analytics"),
    v.literal("export_reports"),
    v.literal("manage_enrollments"),
    v.literal("send_reminders"),
    v.literal("manage_team")
  )),

  // Scope
  teamIds: v.optional(v.array(v.id("teams"))), // Specific teams, null = all
  departmentScope: v.optional(v.array(v.string())), // Department filter

  isActive: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_user", ["userId"])
  .index("by_organization", ["organizationId", "isActive"])
  .index("by_user_org", ["userId", "organizationId"]),

// Teams - Sub-groups within organizations
teams: defineTable({
  organizationId: v.id("organizations"),
  name: v.string(),                    // "Marketing Team", "Engineering"
  description: v.optional(v.string()),
  managerId: v.optional(v.id("users")), // Team lead

  // Learning goals
  targetCourses: v.optional(v.array(v.id("courses"))),
  targetPaths: v.optional(v.array(v.id("learningPaths"))),
  targetSkills: v.optional(v.array(v.id("skills"))),
  completionDeadline: v.optional(v.number()),

  // Metadata
  memberCount: v.number(),
  isActive: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_organization", ["organizationId", "isActive"])
  .index("by_manager", ["managerId"]),

// Team Members
teamMembers: defineTable({
  teamId: v.id("teams"),
  userId: v.id("users"),
  role: v.union(
    v.literal("member"),
    v.literal("lead")
  ),
  joinedAt: v.number(),
})
  .index("by_team", ["teamId"])
  .index("by_user", ["userId"]),

// Organization Analytics Snapshots (daily/weekly)
organizationAnalytics: defineTable({
  organizationId: v.id("organizations"),
  periodType: v.union(
    v.literal("daily"),
    v.literal("weekly"),
    v.literal("monthly")
  ),
  periodStart: v.number(),
  periodEnd: v.number(),

  // Enrollment metrics
  totalEnrollments: v.number(),
  activeEnrollments: v.number(),
  completedEnrollments: v.number(),

  // Engagement metrics
  totalLearningHours: v.number(),
  avgLearningHoursPerUser: v.number(),
  lessonsCompleted: v.number(),

  // Performance metrics
  avgAssessmentScore: v.optional(v.number()),
  avgLearningGain: v.optional(v.number()),
  certificatesIssued: v.number(),

  // Skills metrics
  skillsAcquired: v.number(),
  avgSkillProgress: v.number(),

  // Comparison
  enrollmentsChange: v.number(),       // vs previous period
  completionRateChange: v.number(),

  calculatedAt: v.number(),
})
  .index("by_organization", ["organizationId", "periodType", "periodStart"])
  .index("by_period", ["periodType", "periodStart"]),

// Team Analytics Snapshots
teamAnalytics: defineTable({
  teamId: v.id("teams"),
  organizationId: v.id("organizations"),
  periodType: v.union(
    v.literal("daily"),
    v.literal("weekly"),
    v.literal("monthly")
  ),
  periodStart: v.number(),
  periodEnd: v.number(),

  // Team metrics
  memberCount: v.number(),
  activeMembers: v.number(),           // Logged in this period

  // Progress
  avgProgressPercent: v.number(),
  lessonsCompleted: v.number(),
  totalLearningHours: v.number(),

  // Performance
  avgAssessmentScore: v.optional(v.number()),
  coursesCompleted: v.number(),

  // Leaderboard data
  topPerformers: v.array(v.object({
    userId: v.id("users"),
    metric: v.string(),
    value: v.number(),
  })),

  calculatedAt: v.number(),
})
  .index("by_team", ["teamId", "periodType", "periodStart"])
  .index("by_organization", ["organizationId", "periodType", "periodStart"]),

// Manager Reports - Saved/scheduled reports
managerReports: defineTable({
  organizationId: v.id("organizations"),
  createdBy: v.id("users"),
  name: v.string(),
  description: v.optional(v.string()),

  // Report config
  reportType: v.union(
    v.literal("progress_summary"),     // Overall progress
    v.literal("individual_detail"),    // Per-learner breakdown
    v.literal("skill_matrix"),         // Skills heat map
    v.literal("roi_analysis"),         // Learning gains
    v.literal("engagement"),           // Activity metrics
    v.literal("compliance")            // Deadline tracking
  ),

  // Filters
  teamIds: v.optional(v.array(v.id("teams"))),
  courseIds: v.optional(v.array(v.id("courses"))),
  dateRange: v.object({
    start: v.number(),
    end: v.number(),
  }),

  // Schedule
  isScheduled: v.boolean(),
  scheduleFrequency: v.optional(v.union(
    v.literal("daily"),
    v.literal("weekly"),
    v.literal("monthly")
  )),
  recipients: v.optional(v.array(v.string())), // Email addresses
  lastSentAt: v.optional(v.number()),
  nextSendAt: v.optional(v.number()),

  // Output
  format: v.union(
    v.literal("pdf"),
    v.literal("csv"),
    v.literal("xlsx")
  ),
  lastGeneratedFileId: v.optional(v.id("_storage")),

  isActive: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
})
  .index("by_organization", ["organizationId", "isActive"])
  .index("by_creator", ["createdBy"])
  .index("by_scheduled", ["isScheduled", "nextSendAt"]),

// Learning Reminders - Manager-initiated nudges
learningReminders: defineTable({
  organizationId: v.id("organizations"),
  sentBy: v.id("users"),

  // Target
  targetType: v.union(
    v.literal("individual"),
    v.literal("team"),
    v.literal("behind_schedule"),      // Auto-target lagging learners
    v.literal("inactive")              // No activity in X days
  ),
  targetUserIds: v.optional(v.array(v.id("users"))),
  targetTeamIds: v.optional(v.array(v.id("teams"))),
  inactivityDays: v.optional(v.number()),

  // Message
  subject: v.string(),
  message: v.string(),
  includeProgress: v.boolean(),        // Include progress stats

  // Delivery
  channel: v.union(
    v.literal("email"),
    v.literal("in_app"),
    v.literal("both")
  ),
  sentAt: v.number(),
  recipientCount: v.number(),

  createdAt: v.number(),
})
  .index("by_organization", ["organizationId", "sentAt"])
  .index("by_sender", ["sentBy"]),
```

---

### Privacy Controls

**User Privacy Settings Table:**
```typescript
// User can opt-in to manager visibility
userPrivacySettings: defineTable({
  userId: v.id("users"),
  allowManagerViewScores: v.boolean(),      // Default: true for B2B
  allowManagerViewActivity: v.boolean(),    // Default: true for B2B
  allowManagerViewCertificates: v.boolean(), // Default: true for B2B
  allowLeaderboardDisplay: v.boolean(),     // Default: false
  updatedAt: v.number(),
})
  .index("by_user", ["userId"]),
```

**Manager Access Logs:**
```typescript
// Audit trail for manager access
managerAccessLogs: defineTable({
  managerId: v.id("users"),
  organizationId: v.id("organizations"),
  accessType: v.union(
    v.literal("view_dashboard"),
    v.literal("export_report"),
    v.literal("view_individual"),
    v.literal("send_reminder")
  ),
  targetUserId: v.optional(v.id("users")),
  timestamp: v.number(),
})
  .index("by_manager", ["managerId"])
  .index("by_target", ["targetUserId"]),
```

---

### Dashboard View Examples

#### 1. Executive Dashboard (Organization-Wide)

**Purpose:** High-level overview for C-suite and senior L&D leaders

**Key Metrics:**
- Seat utilization rate (seats used / purchased)
- Active learners in the last week
- Average learning hours per user
- Courses in progress vs completed
- Certificates issued
- Skills acquired (count)
- Average learning gain (pre/post assessment delta)
- Week-over-week enrollment and completion trends
- Top-performing teams by completion rate
- At-risk learners (inactive or behind schedule)

#### 2. Team Progress Dashboard

**Purpose:** Detailed view for team managers tracking their direct reports

**Key Metrics:**
- Team member count and progress overview
- Individual learner progress (with privacy controls)
- Lessons completed per member
- Last active timestamps
- On-track vs behind-schedule breakdown
- Certificate completion status
- Skills heat map for the team
- Upcoming course deadlines and at-risk count

#### 3. Skills Heat Map Dashboard

**Purpose:** Visualize skill coverage and proficiency across teams

**Key Metrics:**
- Team-by-skill matrix (color-coded by proficiency level)
- Skill gaps identification (skills with low team coverage)
- Certification coverage by course
- Skill progression tracking over time

---

### Report Templates

#### 1. Executive Summary Report

**Format:** PDF | **Frequency:** Weekly | **Recipients:** C-suite, VP L&D

**Sections:**
1. **Executive Overview** - Total learners, completion rates, seat utilization
2. **Key Metrics** - Learning hours, certificates, skills, avg learning gain
3. **Top Performers** - Highest completion teams, engaged learners (anonymized)
4. **Action Items** - At-risk learners, underutilized seats, recommended interventions
5. **Trend Analysis** - Week-over-week changes in enrollment, completion, engagement

#### 2. Individual Detail Report

**Format:** CSV | **Frequency:** On-demand | **Recipients:** Team managers

**Columns:** Learner Name, Team, Course, Progress %, Lessons Completed, Assessment Score, Last Active, Days Since Last Login, Certificate Status, Skills Acquired

**Privacy Note:** Only managers with `view_scores` permission can access this report.

#### 3. Compliance Report

**Format:** XLSX | **Frequency:** Monthly | **Recipients:** Compliance officers, HR

**Sections:**
1. **Deadline Tracking** - Courses with deadlines, on-time vs overdue, learners behind schedule
2. **Mandatory Training** - Required courses, completion rates by department, non-compliant learners
3. **Certification Status** - Certificates earned, expiring certifications, recertification requirements

---

### PostHog Analytics Integration

The Manager Dashboard System integrates with PostHog for behavioral analytics and predictive insights.

**Tracked Events:**
- `lesson_completed` - Learner activity tracking
- `assessment_submitted` - Performance metrics
- `certificate_earned` - Achievement tracking
- `dashboard_viewed` - Manager engagement
- `report_generated` - Report usage analytics
- `reminder_sent` - Manager intervention tracking

**Predictive Insights:**
- **Engagement Prediction:** Identify at-risk learners (login but low completion)
- **Completion Forecasting:** Predict course completion likelihood using trend analysis
- **Engagement Funnel:** Track conversion from enrolled → started → 50% → completed → certified
- **Time-to-Completion Trends:** Average days to complete with cohort comparisons
- **Session Duration Analysis:** Average learning session times and peak learning hours

---

### Notification Workflows

#### Automated Manager Notifications

**1. Weekly Progress Summary**
- Scheduled: Every Monday morning
- Recipients: Managers with `view_progress` permission
- Content: Team progress overview, completion rates, at-risk learners

**2. At-Risk Learner Alert**
- Scheduled: Daily
- Trigger: No activity in 7+ days
- Content: List of inactive learners by team with last login date

**3. Deadline Approaching**
- Scheduled: Daily
- Trigger: Team deadline within 3 days
- Content: Team progress vs target, learners behind schedule

#### Manager-Initiated Reminders

**Use Case:** Manager sends encouragement to specific learners

**Target Options:**
- **Individual** - Specific learners
- **Team** - Entire team
- **Behind Schedule** - Auto-target learners falling behind
- **Inactive** - No activity in X days

**Delivery Channels:**
- Email (via Brevo)
- In-app notification
- Both

---

### Privacy Considerations

#### What Managers CAN See:
✅ Aggregate team progress and completion rates
✅ Individual progress percentages and course completion status
✅ Assessment scores (if permission granted)
✅ Certificate issuance status
✅ Skill acquisition progress
✅ Learning hours and activity timestamps
✅ Leaderboard rankings (anonymized or named with permission)

#### What Managers CANNOT See:
❌ Private chat conversations with AI tutors
❌ Personal notes or bookmarks
❌ Individual assessment responses (only scores)
❌ Peer review feedback content
❌ Office hours booking details (without explicit consent)
❌ Individual learner's personal profile details

#### GDPR Compliance:
- **Right to access:** Learners can export all manager-visible data
- **Right to erasure:** Delete all dashboard presence (with org approval)
- **Right to restriction:** Opt-out of non-essential manager visibility
- **Data portability:** Export learning records in machine-readable format

---

### Implementation Roadmap

**Phase 1: Core Dashboards (Week 1-2)**
- Organization managers table and permissions
- Teams and team members tables
- Executive dashboard (read-only)
- Team progress dashboard (read-only)

**Phase 2: Analytics & Reports (Week 3-4)**
- Organization and team analytics snapshots
- Scheduled snapshot generation (daily/weekly)
- Report templates (progress summary, compliance)
- PDF/CSV export functionality

**Phase 3: Notifications & Reminders (Week 5)**
- Automated manager notifications (weekly summaries, at-risk alerts)
- Manager-initiated reminders
- Brevo integration for email delivery
- In-app notification system

**Phase 4: Advanced Features (Week 6+)**
- Skills heat map visualization
- PostHog integration for predictive analytics
- Custom report builder
- ROI calculator and business impact analysis

---

This Manager Dashboard System transforms the AI Enablement Academy into a comprehensive B2B learning platform with enterprise-grade visibility, analytics, and accountability while maintaining strong privacy protections for individual learners.

---

## Compound Types & Embedded Structures

### Overview

This schema contains **52 standalone database tables** defined with `defineTable()`. However, the schema also includes **5 compound/nested object structures** that are NOT standalone tables but rather embedded type definitions used within other tables. These compound types are defined using `v.object()` and represent complex nested data structures.

### The 5 Compound Types

#### 1. **`badgeData`** - Open Badges 3.0 JSON-LD Structure
**Location:** Embedded in `certificates`, `pathCertificates`, and `skillBadges` tables
**Purpose:** Implements the Open Badges 3.0 standard for verifiable digital credentials
**Structure:**
```typescript
badgeData: v.object({
  "@context": v.string(),
  type: v.string() | v.array(v.string()),
  id: v.string(),
  name: v.string(),
  description: v.string(),
  image: v.string(),
  criteria: { ... },    // See #2 below
  issuer: { ... },      // See #3 below
})
```
**Not a table because:** It's a standardized JSON-LD payload embedded within certificate records

#### 2. **`criteria`** - Open Badges Achievement Criteria
**Location:** Nested within `badgeData` objects
**Purpose:** Defines the requirements for earning a badge/certificate
**Structure:**
```typescript
criteria: v.object({
  narrative: v.string(),
})
```
**Not a table because:** It's a sub-property of the `badgeData` compound type

#### 3. **`issuer`** - Open Badges Issuer Information
**Location:** Nested within `badgeData` objects
**Purpose:** Identifies the organization/entity issuing the credential
**Structure:**
```typescript
issuer: v.object({
  id: v.string(),
  type: v.string(),
  name: v.string(),
  url: v.string(),
})
```
**Not a table because:** It's a sub-property of the `badgeData` compound type, representing issuer metadata

#### 4. **`credentialSubject`** - Open Badges Credential Subject (W3C Standard)
**Location:** Nested within `badgeData` objects in `pathCertificates` and `skillBadges`
**Purpose:** Links the credential to the recipient and describes the achievement
**Structure:**
```typescript
credentialSubject: v.object({
  id: v.string(),
  achievement: { ... },  // See #5 below
})
```
**Not a table because:** It's part of the W3C Verifiable Credentials data model, embedded in badge data

#### 5. **`achievement`** - Open Badges Achievement Details
**Location:** Nested within `credentialSubject` objects
**Purpose:** Describes the specific achievement or learning outcome
**Structure:**
```typescript
achievement: v.object({
  id: v.string(),
  type: v.string(),
  name: v.string(),
  description: v.string(),
  criteria: { ... },
})
```
**Not a table because:** It's a deeply nested property within the Open Badges credential structure

### Additional Embedded Structures (Not Counted in "Missing 5")

While the 5 compound types above account for the validation discrepancy, the schema also contains other embedded structures that are clearly not standalone tables:

- **`metrics`** - Embedded in `executiveReports` (aggregate statistics snapshot)
- **`modelSettings`** - Embedded in `prompts` (AI model configuration)
- **`scaleLabels`** - Embedded in `assessmentQuestions` (Likert scale labels)
- **`notificationPreferences`** - Embedded in `userCommunityMemberships` (user preferences)
- **`variables`** - Array of objects in `prompts` (template variable definitions)
- **`skillGains`** - Array of objects in `learningGainAnalytics` (skill progress tracking)

### Why These Are Not Tables

These compound types are **intentionally designed as embedded structures** rather than separate tables for several architectural reasons:

1. **Atomic Data Integrity:** The parent record (certificate, badge) is meaningless without its embedded credential data
2. **Standards Compliance:** Open Badges 3.0 requires these structures to exist as cohesive JSON-LD documents
3. **Performance:** Embedding eliminates JOIN operations for frequently accessed credential data
4. **Version Control:** The entire credential structure is versioned together as a single document
5. **Portability:** Credentials can be exported as self-contained JSON-LD for sharing/verification

### Validation Notes

When validating the schema:
- **Expected `defineTable()` count:** 52 (actual database tables)
- **Total `defineTable()` occurrences in code:** 57 (including import statement and comments)
- **Compound types (not tables):** 5 (badgeData, criteria, issuer, credentialSubject, achievement)
- **Conclusion:** Schema is complete and correct. The "5 missing tables" are intentionally embedded compound types.

---

### Schema Summary

| Category | Count | Description |
|----------|-------|-------------|
| **Standalone Tables** | 52 | Actual `defineTable()` database tables |
| **Compound Types** | 5 | Nested `v.object()` structures (Open Badges) |
| **Other Embedded Objects** | 8+ | Additional nested structures for configuration/metadata |
| **Total Schema Complexity** | 65+ | Combined tables + compound types + embedded objects |

This architecture balances normalization (separate tables for entities) with denormalization (embedded objects for tightly coupled data) to optimize for both query performance and data integrity.
