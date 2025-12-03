# PostHog Analytics Research for Learning Platform

**Research Date:** 2025-12-02
**Purpose:** Comprehensive integration guide for PostHog analytics in a Next.js-based learning platform

---

## Table of Contents
1. [Event Tracking](#1-event-tracking)
2. [Self-Hosted Deployment](#2-self-hosted-deployment)
3. [Next.js Integration](#3-nextjs-integration)
4. [Feature Flags & A/B Testing](#4-feature-flags--ab-testing)
5. [Funnels & Analytics](#5-funnels--analytics)
6. [Learning Platform Best Practices](#6-learning-platform-best-practices)
7. [Integration Patterns](#7-integration-patterns-for-nextjs)

---

## 1. Event Tracking

### 1.1 Custom Events

PostHog uses a **[object][verb]** naming convention for custom events:
- `"course viewed"` - User views a course
- `"purchase completed"` - User completes a purchase
- `"user signed up"` - New user registration
- `"video played"` - User starts a video lesson

#### Basic Event Capture
```javascript
// Client-side custom event
posthog.capture('course viewed', {
  course_id: 'intro-to-react',
  course_name: 'Introduction to React',
  price: 99.99,
  category: 'web-development'
})

// Purchase event with properties
posthog.capture('purchase completed', {
  plan: 'premium',
  amount: 299.99,
  currency: 'USD',
  payment_method: 'stripe',
  course_count: 5
})
```

#### Best Practices
- **Include more properties than needed initially** - There's no limit to event properties
- **Server-side for high-value events** - Track purchases and sign-ups server-side for reliability
- **Autocapture + Custom Events** - Use autocapture for general behavior, custom events for critical actions
- **Add data attributes** - Enhance autocapture with metadata: `data-ph-capture-attribute-course-id="123"`

### 1.2 Page Views

PostHog automatically captures pageview events on initial page load. For SPAs:

```javascript
// Configure for SPA pageview tracking
posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
  api_host: "/ingest",
  capture_pageview: false, // Manual control
  capture_pageleave: true  // Track when users leave
})

// Manual pageview tracking in Next.js App Router
import { usePathname, useSearchParams } from 'next/navigation'
import { usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function PostHogPageView() {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const posthog = usePostHog()

  useEffect(() => {
    if (pathname && posthog) {
      let url = window.origin + pathname
      if (searchParams.toString()) {
        url = url + `?${searchParams.toString()}`
      }
      posthog.capture('$pageview', { $current_url: url })
    }
  }, [pathname, searchParams, posthog])

  return null
}
```

### 1.3 User Identification

**Identify users as soon as possible after authentication:**

```javascript
// Frontend identification
posthog.identify(
  'user_12345', // Unique user ID from your database
  {
    email: 'student@example.com',
    name: 'John Doe',
    plan: 'premium',
    signup_date: '2025-01-15',
    courses_completed: 3
  }
)

// Update person properties (persistent across events)
posthog.setPersonProperties({
  subscription_status: 'active',
  total_purchases: 5,
  last_login: new Date().toISOString()
})

// Reset on logout (CRITICAL)
posthog.reset()
```

**Server-side identification:**
```javascript
// Using posthog-node
const posthog = new PostHog(
  process.env.POSTHOG_API_KEY,
  { host: process.env.POSTHOG_HOST }
)

posthog.capture({
  distinctId: 'user_12345',
  event: 'course purchased',
  properties: {
    course_id: 'advanced-nextjs',
    amount: 199.99
  }
})
```

### 1.4 Event Properties

**Person Properties** (`$set`, `$set_once`):
- Permanent user data stored across events
- Updated with each `identify()` call
- Examples: email, subscription_tier, signup_date

**Event Properties**:
- Contextual data specific to individual events
- Examples: course_id, video_progress, quiz_score

```javascript
// Event with both types
posthog.capture('quiz completed', {
  // Event properties
  quiz_id: 'react-fundamentals-quiz-1',
  score: 85,
  time_taken_seconds: 420,

  // Person properties (using $set)
  $set: {
    quizzes_completed: 12,
    average_score: 82.5,
    learning_streak_days: 7
  }
})
```

### 1.5 Session Recording Setup

Session recordings are automatically enabled with PostHog. Configure settings:

```javascript
posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
  api_host: "/ingest",
  session_recording: {
    recordCrossOriginIframes: true,  // Capture embedded content
    maskAllInputs: true,             // Privacy: mask form inputs
    maskTextSelector: '.sensitive',  // CSS selector for masking
    recordCanvas: true,              // Capture canvas elements
    sampleRate: 0.5                  // Record 50% of sessions
  }
})

// Override sampling for specific sessions
posthog.startSessionRecording({ sampling: 1.0 }) // Always record
```

**Access recordings:** PostHog automatically links recordings to events, enabling you to watch exactly what happened in a session when analyzing funnels, errors, or user behavior.

---

## 2. Self-Hosted Deployment

### 2.1 Docker Deployment

**Quick Start (Hobby/Development):**
```bash
# One-line deployment (minimum 4GB RAM recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/posthog/posthog/HEAD/bin/deploy-hobby)"
```

This deploys PostHog using Docker Compose with default configuration suitable for up to **~100k events/month**.

### 2.2 Resource Requirements

**Minimum Requirements:**
- **Memory:** 4GB RAM (8GB recommended)
- **CPU:** 4 cores minimum
- **Storage:** Depends on retention policy and event volume
- **Network:** Stable internet for initial setup

**Development (OrbStack/Docker Desktop):**
```yaml
# Docker resource settings
memory: 8GB
cpus: 4
```

**Exit Code 137:** Indicates out-of-memory error - increase RAM allocation.

### 2.3 Production Configuration

**Environment Variables** (create `.env` file):
```bash
# Core Configuration
POSTHOG_DB_NAME=posthog
POSTHOG_DB_USER=posthog
POSTHOG_DB_PASSWORD=your_secure_password
POSTHOG_REDIS_HOST=redis
POSTHOG_SECRET_KEY=your_secret_key_here

# Site Configuration
SITE_URL=https://analytics.yourlearningplatform.com
IS_BEHIND_PROXY=True

# Email Configuration (optional)
EMAIL_HOST=smtp.yourprovider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your_email@example.com
EMAIL_HOST_PASSWORD=your_email_password

# Object Storage (recommended for production)
OBJECT_STORAGE_ENABLED=True
OBJECT_STORAGE_ENDPOINT=https://s3.amazonaws.com
OBJECT_STORAGE_ACCESS_KEY_ID=your_access_key
OBJECT_STORAGE_SECRET_ACCESS_KEY=your_secret_key
OBJECT_STORAGE_BUCKET=posthog-recordings
```

**Docker Compose Configuration:**
```yaml
version: '3'

services:
  web:
    image: posthog/posthog:latest
    environment:
      - DATABASE_URL=postgres://posthog:password@postgres:5432/posthog
      - REDIS_URL=redis://redis:6379/
      - SECRET_KEY=${POSTHOG_SECRET_KEY}
      - SITE_URL=${SITE_URL}
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: posthog
      POSTGRES_USER: posthog
      POSTGRES_PASSWORD: password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  postgres-data:
```

### 2.4 Important Notes

- **No official support** for self-hosted deployments
- **MIT License** - Free for hobby use
- **Scale limits:** Hobby deployment suitable for ~100k events/month
- **Beyond scale:** Migrate to PostHog Cloud for higher volumes
- **Kubernetes:** No longer officially supported for new deployments
- **Responsibility:** You manage all infrastructure, scaling, backups, and issues

### 2.5 Instance Settings

Access at `/instance/settings` (staff users only):
- User permissions
- Authentication settings
- Event ingestion controls
- Data retention policies

---

## 3. Next.js Integration

### 3.1 Installation

```bash
# Client-side tracking
pnpm add posthog-js

# Server-side tracking
pnpm add posthog-node
```

### 3.2 Environment Variables

Create `.env.local`:
```bash
# Required for client-side (NEXT_PUBLIC_ prefix required!)
NEXT_PUBLIC_POSTHOG_KEY=phc_your_project_key_here
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com

# Server-side (no NEXT_PUBLIC_ prefix)
POSTHOG_API_KEY=phc_your_project_key_here
POSTHOG_HOST=https://us.i.posthog.com
```

### 3.3 Client-Side Setup (App Router)

**Step 1: Create Provider** (`app/providers.tsx`):
```typescript
'use client'

import posthog from 'posthog-js'
import { PostHogProvider } from 'posthog-js/react'
import { useEffect } from 'react'

if (typeof window !== 'undefined') {
  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
    api_host: '/ingest', // Reverse proxy path
    ui_host: 'https://us.posthog.com',
    person_profiles: 'identified_only', // Recommended: 4x cheaper
    capture_pageview: false, // Manual pageview tracking
    capture_pageleave: true,
    session_recording: {
      maskAllInputs: true,
      maskTextSelector: '.sensitive'
    },
    loaded: (posthog) => {
      if (process.env.NODE_ENV === 'development') {
        posthog.debug() // Enable debug mode in dev
      }
    }
  })
}

export function PHProvider({ children }: { children: React.ReactNode }) {
  return <PostHogProvider client={posthog}>{children}</PostHogProvider>
}
```

**Step 2: Wrap App** (`app/layout.tsx`):
```typescript
import { PHProvider } from './providers'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <PHProvider>
        <body>{children}</body>
      </PHProvider>
    </html>
  )
}
```

**Step 3: Pageview Tracking** (`app/posthog-pageview.tsx`):
```typescript
'use client'

import { usePathname, useSearchParams } from 'next/navigation'
import { usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function PostHogPageView() {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const posthog = usePostHog()

  useEffect(() => {
    if (pathname && posthog) {
      let url = window.origin + pathname
      if (searchParams.toString()) {
        url = url + `?${searchParams.toString()}`
      }
      posthog.capture('$pageview', { $current_url: url })
    }
  }, [pathname, searchParams, posthog])

  return null
}
```

Add to layout:
```typescript
import { PostHogPageView } from './posthog-pageview'

export default function RootLayout({ children }) {
  return (
    <html>
      <PHProvider>
        <body>
          <PostHogPageView />
          {children}
        </body>
      </PHProvider>
    </html>
  )
}
```

### 3.4 Server-Side Setup

**Create singleton** (`lib/posthog-server.ts`):
```typescript
import { PostHog } from 'posthog-node'

let posthogInstance: PostHog | null = null

export function getPostHogServer(): PostHog {
  if (!posthogInstance) {
    posthogInstance = new PostHog(
      process.env.POSTHOG_API_KEY!,
      {
        host: process.env.POSTHOG_HOST,
        flushAt: 1, // Send immediately (for testing)
        flushInterval: 0
      }
    )
  }
  return posthogInstance
}

// Graceful shutdown
if (typeof process !== 'undefined') {
  process.on('SIGTERM', async () => {
    if (posthogInstance) {
      await posthogInstance.shutdown()
    }
  })
}
```

**Usage in API Routes** (`app/api/purchase/route.ts`):
```typescript
import { getPostHogServer } from '@/lib/posthog-server'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const { userId, courseId, amount } = await req.json()

  // Process purchase...

  // Track server-side
  const posthog = getPostHogServer()

  posthog.capture({
    distinctId: userId,
    event: 'purchase completed',
    properties: {
      course_id: courseId,
      amount: amount,
      currency: 'USD',
      $set: {
        total_purchases: totalPurchases + 1,
        lifetime_value: lifetimeValue + amount
      }
    }
  })

  await posthog.flush() // Ensure event is sent

  return NextResponse.json({ success: true })
}
```

**Server-Side Feature Flags** (`app/api/feature-flag/route.ts`):
```typescript
import { getPostHogServer } from '@/lib/posthog-server'

export async function GET(req: NextRequest) {
  const userId = req.headers.get('x-user-id')
  const posthog = getPostHogServer()

  const isEnabled = await posthog.isFeatureEnabled(
    'new-course-ui',
    userId!
  )

  return NextResponse.json({ enabled: isEnabled })
}
```

### 3.5 React Hooks

**Available Hooks:**
```typescript
import {
  usePostHog,                  // Access PostHog client
  useFeatureFlagEnabled,       // Check if flag is enabled
  useFeatureFlagVariantKey,    // Get flag variant
  useFeatureFlagPayload        // Get flag payload
} from 'posthog-js/react'
```

**Example Usage:**
```typescript
'use client'

import { usePostHog, useFeatureFlagEnabled } from 'posthog-js/react'

export function CourseCard({ course }) {
  const posthog = usePostHog()
  const showNewDesign = useFeatureFlagEnabled('new-course-card-design')

  const handleEnroll = () => {
    posthog.capture('course enrolled clicked', {
      course_id: course.id,
      course_name: course.name,
      price: course.price
    })
  }

  if (showNewDesign) {
    return <NewCourseCard course={course} onEnroll={handleEnroll} />
  }

  return <LegacyCourseCard course={course} onEnroll={handleEnroll} />
}
```

### 3.6 Reverse Proxy Setup

**Why:** Prevent ad blockers from blocking tracking requests.

**Configure Next.js Rewrites** (`next.config.js`):
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: '/ingest/static/:path*',
        destination: 'https://us-assets.i.posthog.com/static/:path*',
      },
      {
        source: '/ingest/:path*',
        destination: 'https://us.i.posthog.com/:path*',
      },
    ]
  },
  // Required for PostHog trailing slash API requests
  skipTrailingSlashRedirect: true,
}

module.exports = nextConfig
```

**Important:**
- Avoid generic paths like `/analytics`, `/tracking` (easily blocked)
- Use unique, non-obvious paths like `/ingest`, `/ph`, or randomized strings
- Update `api_host` in PostHog init to match your rewrite path

---

## 4. Feature Flags & A/B Testing

### 4.1 Feature Flag Setup

**Create Feature Flag** (PostHog Dashboard):
1. Navigate to Feature Flags
2. Click "New feature flag"
3. Configure:
   - **Name:** `new-course-ui`
   - **Key:** `new-course-ui` (used in code)
   - **Rollout percentage:** 50% (gradual rollout)
   - **Filters:** Target specific cohorts or properties

### 4.2 Client-Side Feature Flags

**Using Hooks:**
```typescript
import { useFeatureFlagEnabled, useFeatureFlagVariantKey } from 'posthog-js/react'

export function CoursePage() {
  // Boolean flag
  const showNewCheckout = useFeatureFlagEnabled('new-checkout-flow')

  // Multivariate flag
  const variant = useFeatureFlagVariantKey('course-pricing-test')

  return (
    <div>
      {showNewCheckout ? <NewCheckout /> : <LegacyCheckout />}

      {variant === 'control' && <PriceDisplay price={99} />}
      {variant === 'discount' && <PriceDisplay price={79} />}
      {variant === 'premium' && <PriceDisplay price={149} />}
    </div>
  )
}
```

**Using Component:**
```typescript
import { PostHogFeature } from 'posthog-js/react'

export function CourseList() {
  return (
    <PostHogFeature flag="advanced-search" match={true}>
      <AdvancedSearchBar />
    </PostHogFeature>
  )
}
```

### 4.3 Server-Side Feature Flags

**Eliminate client-side flicker:**
```typescript
import { getPostHogServer } from '@/lib/posthog-server'
import { cookies } from 'next/headers'

export async function CoursePage({ params }) {
  const posthog = getPostHogServer()
  const userId = cookies().get('user_id')?.value

  const showNewUI = await posthog.isFeatureEnabled(
    'new-course-ui',
    userId!
  )

  return (
    <div>
      {showNewUI ? <NewCourseUI /> : <LegacyCourseUI />}
    </div>
  )
}
```

### 4.4 Rollout Strategies

**1. Percentage Rollout:**
- Start at 5-10% of users
- Monitor metrics (errors, performance, engagement)
- Gradually increase: 10% → 25% → 50% → 100%

**2. Cohort Targeting:**
```typescript
// Target premium users only
// Dashboard: Create cohort "Premium Users" (plan = "premium")
// Flag settings: Enable for cohort "Premium Users"
```

**3. User Property Targeting:**
```typescript
// Flag settings in dashboard:
// - Property: subscription_tier
// - Operator: equals
// - Value: premium
```

**4. Feature Flag Dependencies:**
```typescript
// In dashboard: Flag "advanced-analytics" depends on "premium-features"
// Users only see advanced-analytics if premium-features is also enabled
```

**5. Sticky Feature Flags:**
```typescript
posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
  persistence: 'localStorage', // Ensures consistent variant
  bootstrap: {
    featureFlags: {
      'new-course-ui': true // Initial value from server
    }
  }
})
```

### 4.5 A/B Testing (Experiments)

**Create Experiment:**
1. Navigate to Experiments in PostHog
2. Click "New experiment"
3. Configure:
   - **Name:** "Course Pricing Test"
   - **Feature flag key:** `course-pricing-test`
   - **Variants:**
     - `control` (current $99)
     - `discount` ($79)
     - `premium` ($149)
   - **Goal metric:** `purchase completed`
   - **Secondary metrics:** `course viewed`, `checkout started`

**Implement in Code:**
```typescript
'use client'

import { useFeatureFlagVariantKey, usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function CoursePricing({ courseId }) {
  const variant = useFeatureFlagVariantKey('course-pricing-test')
  const posthog = usePostHog()

  // Exposure tracking (CRITICAL for experiments)
  useEffect(() => {
    if (variant) {
      posthog.capture('$feature_flag_called', {
        $feature_flag: 'course-pricing-test',
        $feature_flag_response: variant
      })
    }
  }, [variant, posthog])

  const prices = {
    control: 99,
    discount: 79,
    premium: 149
  }

  const price = prices[variant] || prices.control

  return <PriceDisplay price={price} variant={variant} />
}
```

**Automatic Statistical Analysis:**
- PostHog tracks conversion rates per variant
- Calculates statistical significance
- Shows sample size requirements
- Provides confidence intervals

### 4.6 Local Evaluation (Performance Optimization)

**Reduce latency from 500ms to <50ms:**
```typescript
posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
  api_host: '/ingest',
  loaded: async (posthog) => {
    await posthog.onFeatureFlags(() => {
      console.log('Feature flags loaded locally')
    })
  },
  persistence: 'localStorage',
  feature_flag_request_timeout_ms: 3000
})
```

**Bootstrapping (Instant Flags):**
```typescript
// Server-side: Get flags for user
const flags = await posthog.getAllFlags(userId)

// Send to client
<PHProvider>
  <script
    dangerouslySetInnerHTML={{
      __html: `window.POSTHOG_FLAGS = ${JSON.stringify(flags)}`
    }}
  />
  {children}
</PHProvider>

// Client-side: Bootstrap with server flags
posthog.init(key, {
  bootstrap: {
    featureFlags: window.POSTHOG_FLAGS
  }
})
```

---

## 5. Funnels & Analytics

### 5.1 Conversion Funnels

**Setup in Dashboard:**
1. Navigate to Insights → Funnels
2. Define steps:
   - **Step 1:** `course viewed`
   - **Step 2:** `course detail viewed`
   - **Step 3:** `add to cart clicked`
   - **Step 4:** `checkout started`
   - **Step 5:** `purchase completed`

**Funnel Features:**
- **Drop-off visualization:** See where users abandon the flow
- **Time to convert:** Understand how long conversions take
- **Correlation analysis:** Automatically identifies factors affecting conversion
- **User lists:** Click any step to see users who completed/dropped
- **Save as cohort:** Create cohorts from funnel users for retargeting

**Example Learning Platform Funnels:**

**Enrollment Funnel:**
```
Landing Page → Course Catalog → Course Detail → Enroll → Purchase Complete
```

**Engagement Funnel:**
```
Login → Dashboard → Course Started → Lesson 1 → Lesson 5 → Course Completed
```

**Retention Funnel:**
```
First Login → Day 7 Return → Day 14 Return → Day 30 Return → Subscription Renewal
```

### 5.2 User Cohorts

**Create Cohorts:**
1. Navigate to Cohorts
2. Click "New cohort"
3. Define criteria:

**Static Cohorts:**
- Manual user lists (uploaded CSV)
- Users from funnel step (export from funnel)
- Specific date range (e.g., "January 2025 sign-ups")

**Dynamic Cohorts:**
```typescript
// "Active Learners" cohort
// Conditions:
// - Completed event "course viewed" at least 5 times in last 30 days
// - Property "subscription_status" equals "active"

// "At-Risk Users" cohort
// Conditions:
// - Did NOT complete event "course viewed" in last 14 days
// - Property "subscription_status" equals "active"

// "High-Value Students" cohort
// Conditions:
// - Property "total_purchases" greater than 3
// - Property "courses_completed" greater than 2
```

**Use Cases:**
- Target specific user groups in funnels
- A/B test on specific cohorts
- Create retention reports by cohort
- Export for email campaigns

### 5.3 Retention Analysis

**Setup Retention Insight:**
1. Navigate to Insights → Retention
2. Configure:
   - **Cohort defining event:** `user signed up` (initial event)
   - **Returning event:** `course viewed` (retention indicator)
   - **Time period:** Daily, Weekly, or Monthly

**Retention Table:**
```
Week 0: 100% (baseline)
Week 1: 45% returned
Week 2: 32% returned
Week 3: 28% returned
Week 4: 25% returned (stabilized)
```

**Analyze by Cohort:**
```typescript
// Compare retention by acquisition source
// Cohort 1: Organic Search users
// Cohort 2: Paid Ads users
// Cohort 3: Referral users

// Question: Which acquisition channel has better retention?
```

**Key Metrics to Track:**
- **D1, D7, D30 Retention:** % of users returning after 1, 7, 30 days
- **Cohort curves:** Visualize retention decay over time
- **Churn analysis:** Identify when users stop engaging

### 5.4 Correlation Analysis

**Automatic insights on funnel conversion:**
- PostHog analyzes all events and properties
- Highlights statistically significant correlations
- Shows both positive and negative impacts

**Example Results:**
```
Positive Correlations (Increase Conversion):
✅ Users who completed "free trial video" → +34% conversion
✅ Property "signup_source = referral" → +28% conversion
✅ Users on "mobile device" → +15% conversion

Negative Correlations (Decrease Conversion):
❌ Users who saw "error_displayed" → -45% conversion
❌ Property "country = FR" → -22% conversion (localization issue?)
❌ Users with "session_duration < 30s" → -67% conversion
```

**Actionable Insights:**
- Prioritize improvements that reduce negative correlations
- Double down on features that show positive correlations
- Create targeted experiments based on findings

### 5.5 Custom Dashboards

**Create Learning Platform Dashboard:**
1. Navigate to Dashboards → New Dashboard
2. Add widgets:

**Enrollment Metrics:**
- Trends: `course viewed`, `purchase completed` (daily)
- Funnel: Enrollment funnel with conversion rates
- Number: Total revenue (last 30 days)

**Engagement Metrics:**
- Trends: `video played`, `quiz completed`, `lesson completed`
- Stickiness: How many days per week users engage
- Session duration: Average time spent per session

**Retention Metrics:**
- Retention: Weekly cohort retention
- Lifecycle: Distribution of new, returning, resurrecting, dormant users
- Churn rate: % of users who stopped engaging

**Example Widget Configuration:**
```typescript
// Trends Widget: Course Views Over Time
// Event: course viewed
// Breakdown by: course_category
// Date range: Last 90 days
// Interval: Weekly

// Funnel Widget: Purchase Conversion
// Steps: course viewed → add to cart → checkout started → purchase completed
// Time frame: 7 days (allow up to 7 days for conversion)
// Breakdown by: utm_source (track acquisition channel performance)

// Number Widget: Monthly Revenue
// Event: purchase completed
// Property: amount (sum)
// Date range: This month
// Comparison: Previous month
```

---

## 6. Learning Platform Best Practices

### 6.1 Event Naming Conventions

Use the **category:object_action** framework:

```typescript
// Category = context
// Object = component/location (noun)
// Action = what happened (verb)

// Examples:
'course_catalog:filter_button_click'
'checkout:payment_form_submit'
'video_player:play_button_click'
'account_settings:password_change_complete'
'dashboard:course_card_click'
```

**Benefits:**
- Easy filtering by category
- Clear hierarchy
- Consistent structure
- Scalable as product grows

### 6.2 Key Events for Learning Platforms

**Acquisition:**
- `landing_page_viewed`
- `signup_form_displayed`
- `user_signed_up` (server-side)
- `email_verified`

**Activation:**
- `onboarding_started`
- `first_course_viewed`
- `first_lesson_completed`
- `profile_completed`

**Engagement:**
- `course_viewed`
- `lesson_started`
- `video_played`
- `video_completed`
- `quiz_attempted`
- `quiz_passed`
- `discussion_post_created`
- `certificate_earned`

**Monetization:**
- `pricing_page_viewed`
- `add_to_cart_clicked` (server-side)
- `checkout_started`
- `payment_method_added`
- `purchase_completed` (server-side)
- `subscription_upgraded`

**Retention:**
- `daily_login`
- `notification_clicked`
- `email_opened`
- `course_resumed`
- `streak_milestone_reached`

**Referral:**
- `share_button_clicked`
- `invite_sent`
- `referral_link_shared`
- `friend_signed_up`

### 6.3 Finding Power Users

**Create "Power Users" Cohort:**
```typescript
// Conditions:
// - Completed "lesson_completed" at least 20 times in last 30 days
// - Completed "course_completed" at least 2 times in last 90 days
// - Property "courses_completed" greater than 5
// - Property "account_age_days" greater than 60
```

**Analyze Power Users:**
- What courses do they engage with most?
- What features do they use regularly?
- What's their average session duration?
- What's their referral rate?

**Use Insights to:**
- Identify features that drive engagement
- Create activation funnels to turn new users into power users
- Build retention campaigns targeting similar behaviors

### 6.4 Backend vs Frontend Tracking

**Backend (Server-Side) - RECOMMENDED for:**
- ✅ User sign-ups (cannot be blocked)
- ✅ Purchases and payment events (critical revenue data)
- ✅ Subscription changes (accurate billing tracking)
- ✅ Course completions (certification requirements)
- ✅ High-value CRUD operations

**Frontend (Client-Side) - USE for:**
- ✅ User interactions (clicks, scrolls, hovers)
- ✅ Page views and navigation
- ✅ Video playback events
- ✅ Form interactions (non-sensitive)
- ✅ A/B test exposure tracking

**Why Backend is Better:**
- Ad blockers can't block server-side events
- JavaScript execution not required
- More reliable delivery
- Complete control over implementation

### 6.5 Reverse Proxy (CRITICAL)

**Why it matters:**
- Ad blockers block ~25% of analytics requests
- Tracking protection in browsers increases blocking
- Lost data = incorrect metrics = bad decisions

**Implementation:** See Section 3.6

### 6.6 Filter Internal Traffic

```typescript
// Method 1: Environment-based
posthog.init(key, {
  api_host: '/ingest',
  loaded: (posthog) => {
    if (process.env.NODE_ENV === 'development' ||
        window.location.hostname === 'localhost' ||
        window.location.hostname.includes('staging')) {
      posthog.opt_out_capturing()
    }
  }
})

// Method 2: Dashboard filters
// Settings → Project → Filter Internal Users
// Add IP ranges: 192.168.1.0/24, your office IP, etc.

// Method 3: User property
posthog.identify(userId, {
  email: user.email,
  is_internal: user.email.endsWith('@yourcompany.com')
})

// Then filter events where "is_internal = false"
```

### 6.7 Privacy & Compliance

**Mask Sensitive Data:**
```typescript
posthog.init(key, {
  session_recording: {
    maskAllInputs: true,              // Mask all form inputs
    maskTextSelector: '.sensitive',   // CSS selector for masking
    maskAllText: false,               // Don't mask all text (breaks UX analysis)
  }
})

// Or mask specific elements:
<input
  type="password"
  className="ph-no-capture"  // PostHog ignores this element
/>
```

**Respect User Consent:**
```typescript
'use client'

import { useEffect } from 'react'
import { usePostHog } from 'posthog-js/react'

export function CookieConsent() {
  const posthog = usePostHog()

  const handleAccept = () => {
    posthog.opt_in_capturing()
    localStorage.setItem('analytics-consent', 'true')
  }

  const handleDecline = () => {
    posthog.opt_out_capturing()
    localStorage.setItem('analytics-consent', 'false')
  }

  useEffect(() => {
    const consent = localStorage.getItem('analytics-consent')
    if (consent === 'false') {
      posthog.opt_out_capturing()
    }
  }, [posthog])

  return <ConsentBanner onAccept={handleAccept} onDecline={handleDecline} />
}
```

**Anonymous vs Identified Events:**
```typescript
// Anonymous events (4x cheaper, GDPR-friendly)
posthog.init(key, {
  person_profiles: 'identified_only' // Only create profiles for identified users
})

// Before login: Events are anonymous
posthog.capture('course_viewed', { course_id: '123' })

// After login: Link to user profile
posthog.identify(userId, { email: user.email })
```

---

## 7. Integration Patterns for Next.js

### 7.1 Complete Setup Checklist

**1. Installation:**
```bash
pnpm add posthog-js posthog-node
```

**2. Environment Variables:**
```bash
# .env.local
NEXT_PUBLIC_POSTHOG_KEY=phc_xxx
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
POSTHOG_API_KEY=phc_xxx
POSTHOG_HOST=https://us.i.posthog.com
```

**3. Reverse Proxy:**
```javascript
// next.config.js
module.exports = {
  async rewrites() {
    return [
      {
        source: '/ingest/static/:path*',
        destination: 'https://us-assets.i.posthog.com/static/:path*',
      },
      {
        source: '/ingest/:path*',
        destination: 'https://us.i.posthog.com/:path*',
      },
    ]
  },
  skipTrailingSlashRedirect: true,
}
```

**4. Provider Setup:**
```typescript
// app/providers.tsx
'use client'
import posthog from 'posthog-js'
import { PostHogProvider } from 'posthog-js/react'

if (typeof window !== 'undefined') {
  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
    api_host: '/ingest',
    person_profiles: 'identified_only',
    capture_pageview: false
  })
}

export function PHProvider({ children }) {
  return <PostHogProvider client={posthog}>{children}</PostHogProvider>
}
```

**5. Layout Integration:**
```typescript
// app/layout.tsx
import { PHProvider } from './providers'
import { PostHogPageView } from './posthog-pageview'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <PHProvider>
        <body>
          <PostHogPageView />
          {children}
        </body>
      </PHProvider>
    </html>
  )
}
```

**6. Server-Side Setup:**
```typescript
// lib/posthog-server.ts
import { PostHog } from 'posthog-node'

let posthogInstance: PostHog | null = null

export function getPostHogServer(): PostHog {
  if (!posthogInstance) {
    posthogInstance = new PostHog(
      process.env.POSTHOG_API_KEY!,
      { host: process.env.POSTHOG_HOST }
    )
  }
  return posthogInstance
}
```

### 7.2 Authentication Integration

**On Login:**
```typescript
// app/api/auth/login/route.ts
import { getPostHogServer } from '@/lib/posthog-server'

export async function POST(req: Request) {
  const { email, password } = await req.json()

  // Authenticate user...
  const user = await authenticateUser(email, password)

  if (user) {
    // Track server-side
    const posthog = getPostHogServer()
    posthog.capture({
      distinctId: user.id,
      event: 'user logged in',
      properties: {
        $set: {
          email: user.email,
          name: user.name,
          plan: user.plan,
          signup_date: user.createdAt
        }
      }
    })
    await posthog.flush()

    // Set cookie for client-side identification
    return NextResponse.json(
      { success: true, userId: user.id },
      {
        headers: {
          'Set-Cookie': `user_id=${user.id}; Path=/; HttpOnly; Secure`
        }
      }
    )
  }

  return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 })
}
```

**Client-Side Identification:**
```typescript
// app/components/auth-handler.tsx
'use client'

import { usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function AuthHandler({ user }: { user: User | null }) {
  const posthog = usePostHog()

  useEffect(() => {
    if (user) {
      posthog.identify(user.id, {
        email: user.email,
        name: user.name,
        plan: user.plan
      })
    } else {
      posthog.reset() // Clear on logout
    }
  }, [user, posthog])

  return null
}
```

### 7.3 Purchase Tracking Pattern

**Client-Side (Button Click):**
```typescript
'use client'

import { usePostHog } from 'posthog-js/react'

export function EnrollButton({ course }) {
  const posthog = usePostHog()

  const handleClick = async () => {
    // Track intent
    posthog.capture('enroll button clicked', {
      course_id: course.id,
      price: course.price
    })

    // Process enrollment
    const response = await fetch('/api/enroll', {
      method: 'POST',
      body: JSON.stringify({ courseId: course.id })
    })

    if (response.ok) {
      // Client-side success tracking
      posthog.capture('enrollment started', {
        course_id: course.id
      })
    }
  }

  return <button onClick={handleClick}>Enroll Now</button>
}
```

**Server-Side (Purchase Completion):**
```typescript
// app/api/enroll/route.ts
import { getPostHogServer } from '@/lib/posthog-server'

export async function POST(req: Request) {
  const { courseId } = await req.json()
  const userId = req.headers.get('x-user-id')

  // Process payment with Stripe...
  const payment = await stripe.paymentIntents.create({...})

  if (payment.status === 'succeeded') {
    const posthog = getPostHogServer()

    // Track purchase (server-side = reliable)
    posthog.capture({
      distinctId: userId!,
      event: 'purchase completed',
      properties: {
        course_id: courseId,
        amount: payment.amount / 100,
        currency: payment.currency,
        payment_method: payment.payment_method,
        $set: {
          total_purchases: userPurchaseCount + 1,
          lifetime_value: userLifetimeValue + (payment.amount / 100)
        }
      }
    })

    await posthog.flush()

    return NextResponse.json({ success: true })
  }

  return NextResponse.json({ error: 'Payment failed' }, { status: 400 })
}
```

### 7.4 Video Engagement Tracking

```typescript
'use client'

import { usePostHog } from 'posthog-js/react'
import { useRef, useEffect } from 'react'

export function VideoPlayer({ lessonId, videoUrl }) {
  const posthog = usePostHog()
  const videoRef = useRef<HTMLVideoElement>(null)
  const watchTimeRef = useRef(0)
  const milestones = useRef(new Set())

  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    // Track play
    const handlePlay = () => {
      posthog.capture('video played', {
        lesson_id: lessonId,
        video_url: videoUrl
      })
    }

    // Track progress milestones
    const handleTimeUpdate = () => {
      const progress = (video.currentTime / video.duration) * 100

      // Track 25%, 50%, 75%, 100%
      const milestone = Math.floor(progress / 25) * 25
      if (milestone > 0 && !milestones.current.has(milestone)) {
        milestones.current.add(milestone)
        posthog.capture('video progress', {
          lesson_id: lessonId,
          progress_percent: milestone,
          current_time: video.currentTime,
          duration: video.duration
        })
      }

      watchTimeRef.current = video.currentTime
    }

    // Track completion
    const handleEnded = () => {
      posthog.capture('video completed', {
        lesson_id: lessonId,
        watch_time: video.duration,
        completion_rate: 100
      })
    }

    // Track pause/exit
    const handlePause = () => {
      posthog.capture('video paused', {
        lesson_id: lessonId,
        current_time: video.currentTime,
        progress_percent: (video.currentTime / video.duration) * 100
      })
    }

    video.addEventListener('play', handlePlay)
    video.addEventListener('timeupdate', handleTimeUpdate)
    video.addEventListener('ended', handleEnded)
    video.addEventListener('pause', handlePause)

    return () => {
      video.removeEventListener('play', handlePlay)
      video.removeEventListener('timeupdate', handleTimeUpdate)
      video.removeEventListener('ended', handleEnded)
      video.removeEventListener('pause', handlePause)
    }
  }, [lessonId, videoUrl, posthog])

  return <video ref={videoRef} src={videoUrl} controls />
}
```

### 7.5 Error Tracking Integration

```typescript
'use client'

import { usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function ErrorBoundaryTracking() {
  const posthog = usePostHog()

  useEffect(() => {
    // Track JavaScript errors
    const handleError = (event: ErrorEvent) => {
      posthog.capture('javascript error', {
        error_message: event.message,
        error_stack: event.error?.stack,
        error_filename: event.filename,
        error_line: event.lineno,
        error_column: event.colno
      })
    }

    // Track unhandled promise rejections
    const handleRejection = (event: PromiseRejectionEvent) => {
      posthog.capture('unhandled promise rejection', {
        error_message: event.reason?.message || String(event.reason),
        error_stack: event.reason?.stack
      })
    }

    window.addEventListener('error', handleError)
    window.addEventListener('unhandledrejection', handleRejection)

    return () => {
      window.removeEventListener('error', handleError)
      window.removeEventListener('unhandledrejection', handleRejection)
    }
  }, [posthog])

  return null
}
```

### 7.6 Testing Feature Flags Locally

```typescript
// app/components/feature-flag-debugger.tsx
'use client'

import { usePostHog } from 'posthog-js/react'
import { useEffect, useState } from 'react'

export function FeatureFlagDebugger() {
  const posthog = usePostHog()
  const [flags, setFlags] = useState<Record<string, boolean | string>>({})

  useEffect(() => {
    if (process.env.NODE_ENV !== 'development') return

    posthog.onFeatureFlags(() => {
      const activeFlags = posthog.getAllFlags()
      setFlags(activeFlags)
    })
  }, [posthog])

  if (process.env.NODE_ENV !== 'development') return null

  return (
    <div className="fixed bottom-4 right-4 bg-gray-800 text-white p-4 rounded-lg shadow-lg max-w-sm">
      <h3 className="font-bold mb-2">Feature Flags</h3>
      <div className="space-y-1 text-sm">
        {Object.entries(flags).map(([key, value]) => (
          <div key={key} className="flex justify-between">
            <span>{key}:</span>
            <span className="font-mono">
              {typeof value === 'boolean' ? (value ? '✅' : '❌') : value}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}
```

---

## Sources

### Event Tracking
- [Send events - PostHog Docs](https://posthog.com/docs/getting-started/send-events)
- [Complete guide to event tracking - PostHog](https://posthog.com/tutorials/event-tracking-guide)
- [Autocapture - PostHog Docs](https://posthog.com/docs/product-analytics/autocapture)
- [Capturing events - PostHog Docs](https://posthog.com/docs/product-analytics/capture-events)

### User Identification
- [Identify users - PostHog Docs](https://posthog.com/docs/getting-started/identify-users)
- [Identifying users - PostHog Docs](https://posthog.com/docs/product-analytics/identify)
- [Anonymous vs identified events - PostHog Docs](https://posthog.com/docs/data/anonymous-vs-identified-events)
- [Sessions - PostHog Docs](https://posthog.com/docs/data/sessions)

### Self-Hosting
- [Self-host PostHog - PostHog Docs](https://posthog.com/docs/self-host)
- [Developing locally - PostHog Handbook](https://posthog.com/handbook/engineering/developing-locally)
- [Open-source self-hosted support - PostHog Docs](https://posthog.com/docs/self-host/open-source/support)
- [Instance settings - PostHog Docs](https://posthog.com/docs/self-host/configure/instance-settings)

### Next.js Integration
- [Next.js - PostHog Docs](https://posthog.com/docs/libraries/next-js)
- [How to set up Next.js analytics, feature flags, and more - PostHog](https://posthog.com/tutorials/nextjs-analytics)
- [Using PostHog with the Next.js App Router and Vercel](https://vercel.com/kb/guide/posthog-nextjs-vercel-feature-flags-analytics)
- [PostHog integration in Next.JS App Router - Reetesh Kumar](https://reetesh.in/blog/posthog-integration-in-next.js-app-router)

### React Integration
- [React - PostHog Docs](https://posthog.com/docs/libraries/react)
- [posthog-js - npm](https://www.npmjs.com/package/posthog-js)
- [How to set up React feature flags with Vite - PostHog](https://posthog.com/tutorials/react-feature-flags)

### Feature Flags & A/B Testing
- [Feature Flags – Ship safely and control rollouts with PostHog](https://posthog.com/feature-flags)
- [Feature flags - PostHog Docs](https://posthog.com/docs/feature-flags)
- [Feature flag best practices - PostHog Docs](https://posthog.com/docs/feature-flags/best-practices)
- [How to create sticky feature flags - PostHog](https://posthog.com/tutorials/sticky-feature-flags)

### Funnels & Analytics
- [Funnels - PostHog Docs](https://posthog.com/docs/product-analytics/funnels)
- [Cohorts - PostHog Docs](https://posthog.com/docs/data/cohorts)
- [How to Create and Analyze Funnels in PostHog - Vision Labs](https://visionlabs.com/academy/posthog/funnels/)
- [Group analytics - PostHog Docs](https://posthog.com/docs/product-analytics/group-analytics)

### Best Practices
- [Product analytics best practices - PostHog Docs](https://posthog.com/docs/product-analytics/best-practices)
- [22 ways PostHog makes it easier to build great products - PostHog](https://posthog.com/blog/using-posthog)
- [5 ways to improve your analytics data - PostHog](https://posthog.com/tutorials/event-tracking-guide)

### Reverse Proxy
- [Using Next.js rewrites as a reverse proxy - PostHog Docs](https://posthog.com/docs/advanced/proxy/nextjs)
- [Using Next.js middleware as a reverse proxy - PostHog Docs](https://posthog.com/docs/advanced/proxy/nextjs-middleware)
- [Deploying a reverse proxy to PostHog Cloud - PostHog Docs](https://posthog.com/docs/advanced/proxy)

---

## Summary

PostHog is a comprehensive product analytics platform with strong Next.js support. Key takeaways:

1. **Easy Setup:** Client-side via PostHogProvider, server-side via posthog-node
2. **Reliable Tracking:** Use reverse proxy to bypass ad blockers (25% data recovery)
3. **Cost Optimization:** Use `person_profiles: 'identified_only'` for 4x cheaper events
4. **Feature Flags:** Low latency (<50ms) with local evaluation and bootstrapping
5. **Self-Hosting:** Docker Compose available (4GB+ RAM, 4+ CPU cores recommended)
6. **A/B Testing:** Built-in experiments with automatic statistical significance
7. **Analytics:** Funnels, cohorts, retention, and correlation analysis included

**Recommended Architecture for Learning Platform:**
- Client-side: User interactions, pageviews, video engagement
- Server-side: Purchases, enrollments, course completions
- Reverse proxy: Deployed via Next.js rewrites
- Feature flags: Server-rendered for instant display
- Funnels: Enrollment, engagement, retention tracking
- Cohorts: Power users, at-risk users, high-value students

This setup provides enterprise-grade analytics with minimal integration effort and maximum data reliability.
