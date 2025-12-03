# Formbricks Research Summary: Learning Platform Survey Integration

**Research Date:** 2025-12-02
**Focus:** Post-purchase survey integration in Next.js learning platform
**Use Case:** Embedding surveys in post-purchase flow for student feedback collection

---

## Executive Summary

Formbricks is an open-source, privacy-first Experience Management platform designed as a Qualtrics alternative. It excels at in-app surveys with 6-10x better conversion rates than email surveys. The platform offers self-hosted deployment, comprehensive Next.js integration via JavaScript SDK, and robust webhook support for response collection.

**Key Strengths for Learning Platforms:**
- **Lightweight SDK** (7KB) that won't slow down your app
- **Advanced targeting** based on user attributes and actions
- **Self-hosted option** for complete data control (GDPR/CCPA compliant)
- **Native Next.js support** (App Router & Pages Router)
- **Flexible triggering** on custom events (perfect for post-purchase flows)
- **Open source** (AGPLv3) with active development

---

## 1. Survey Types

### 1.1 In-App Surveys (Primary Recommendation)
**Best for:** Post-purchase feedback in authenticated learning platform

**Characteristics:**
- **6-10x higher conversion rates** compared to email surveys
- **Tiny SDK footprint** (7KB) - loads deferred, never blocks app
- **Trigger on any user action** - button clicks, page visits, custom events
- **Pre-segmentation** - Target based on custom attributes (course purchased, subscription tier, etc.)
- **User identification** - Track feedback by authenticated userId

**Implementation:**
```javascript
formbricks.init({
  environmentId: "<environment-id>",
  apiHost: "<api-host>",
  userId: "<user-id>" // Required for app surveys
});

// Trigger survey after purchase
formbricks.track("purchase_completed");
```

**Customization:**
- No-code design editor to match your brand
- Custom CSS stylesheets supported
- Fully customizable survey appearance

### 1.2 Link Surveys
**Best for:** Email follow-ups, external sharing

**Characteristics:**
- Standalone survey pages with unique URLs
- Can be embedded in emails or shared directly
- No SDK installation required
- Good for reaching users outside your app

**Use Case:**
- Week-after-purchase follow-up surveys
- NPS campaigns via email
- External research campaigns

### 1.3 Website Surveys
**Best for:** Anonymous visitors, marketing pages

**Characteristics:**
- No user authentication required
- Works on public pages (landing pages, marketing site)
- Triggered by page visits or scroll depth
- Good for conversion optimization research

**Implementation:**
```javascript
formbricks.init({
  environmentId: "<environment-id>",
  apiHost: "<api-host>"
  // No userId = website survey mode
});
```

---

## 2. Self-Hosted Deployment

### 2.1 Docker Deployment (Recommended)

**Quick Start:**
```bash
# Create project directory
mkdir formbricks && cd formbricks

# Download docker-compose.yml
curl -o docker-compose.yml https://raw.githubusercontent.com/formbricks/formbricks/stable/docker/docker-compose.yml

# Start services
docker compose up -d
```

**Access:** http://localhost:3000 (setup wizard on first visit)

### 2.2 PostgreSQL Requirements

**Required Extension:** pgvector (for advanced features)

**Docker Image:** `pgvector/pgvector:pg17` (recommended) or `pgvector/pgvector:pg15`

**Example PostgreSQL Configuration:**
```yaml
db:
  image: pgvector/pgvector:pg17
  container_name: Formbricks-DB
  hostname: formbricks-db
  healthcheck:
    test: ["CMD", "pg_isready", "-q", "-d", "formbricks", "-U", "formbricksuser"]
    timeout: 45s
    interval: 10s
    retries: 10
  volumes:
    - /path/to/db:/var/lib/postgresql/data:rw
  environment:
    POSTGRES_DB: formbricks
    POSTGRES_USER: formbricksuser
    POSTGRES_PASSWORD: formbrickspass
```

**Default Connection String:**
```
postgresql://postgres:postgres@postgres:5432/formbricks?schema=public
```

### 2.3 Environment Configuration

**Core Required Variables:**
```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/formbricks

# Authentication (NextAuth)
NEXTAUTH_SECRET=<generate-with-openssl-rand-hex-32>
NEXTAUTH_URL=https://your-domain.com
WEBAPP_URL=https://your-domain.com

# Encryption (for 2FA)
ENCRYPTION_KEY=<generate-secure-key>

# Cron Jobs (for background tasks)
CRON_SECRET=<generate-secure-key>
```

**Optional Email Configuration:**
```bash
MAIL_FROM=noreply@yourdomain.com
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=<your-smtp-password>
```

**Optional S3/MinIO Storage:**
```bash
S3_ACCESS_KEY=<access-key>
S3_SECRET_KEY=<secret-key>
S3_REGION=us-east-1
S3_BUCKET_NAME=formbricks-uploads
S3_ENDPOINT_URL=https://s3.amazonaws.com
S3_FORCE_PATH_STYLE=false
```

**Generate Secrets:**
```bash
# NEXTAUTH_SECRET
openssl rand -hex 32

# Update docker-compose.yml automatically
sed -i "/NEXTAUTH_SECRET:$/s/NEXTAUTH_SECRET:.*/NEXTAUTH_SECRET: $(openssl rand -hex 32)/" docker-compose.yml
```

### 2.4 Backup Strategy

**Database Backup:**
```bash
# Create timestamped backup
docker exec formbricks-postgres-1 pg_dump -Fc -U postgres -d formbricks > \
  formbricks_backup_$(date +%Y%m%d_%H%M%S).dump

# Find container name if needed
docker ps | grep postgres
```

**Backup Before Upgrades:** Always backup before migrating to new versions.

### 2.5 Production Deployment

**Options:**
- **Docker Compose** - Simple, recommended for most use cases
- **Kubernetes** - Enterprise scale with Helm charts available
- **High-Availability Cluster** - Multi-node setup for redundancy
- **One-click setup script** - Automated installation with SSL configuration

**Port Mapping:** Port 3000 is mapped from container to host for web access.

---

## 3. Integration Options

### 3.1 JavaScript SDK

**Installation:**
```bash
npm install @formbricks/js
# or
pnpm add @formbricks/js
# or
yarn add @formbricks/js
```

**Core API Methods:**

#### `formbricks.init()`
Initialize the SDK (required first step):
```javascript
if (typeof window !== "undefined") {
  formbricks.init({
    environmentId: "<environment-id>",
    apiHost: "<api-host>",
    userId: "<user-id>" // Optional for website surveys
  });
}
```

#### `formbricks.track(eventName)`
Track custom events to trigger surveys:
```javascript
// After purchase completion
formbricks.track("purchase_completed");

// After course enrollment
formbricks.track("course_enrolled");

// Button clicks
formbricks.track("button_clicked");
```

#### `formbricks.setUserId(userId)`
Identify users (for app surveys):
```javascript
formbricks.setUserId("user-123");
```

#### `formbricks.setAttribute(key, value)`
Set custom user attributes for segmentation:
```javascript
// Single attribute
formbricks.setAttribute("plan", "pro");

// Multiple attributes
formbricks.setAttributes({
  plan: "pro",
  tier: "gold",
  purchaseDate: "2025-12-02"
});
```

**Note:** Attributes only work when userId is provided.

#### `formbricks.setLanguage(locale)`
Change survey language:
```javascript
formbricks.setLanguage("de");
```

#### `formbricks.logout()`
Clear user session and reset SDK:
```javascript
formbricks.logout();
```

#### `formbricks.registerRouteChange()`
Notify SDK of route changes (for SPAs):
```javascript
// Call after navigation
formbricks.registerRouteChange();
```

**Debug Mode:**
Add `?formbricksDebug=true` to URL to enable debug logging:
```
https://yourdomain.com?formbricksDebug=true
```

### 3.2 React Integration

**Non-Next.js React Apps:**

Update `App.js` or `App.tsx`:
```javascript
import formbricks from "@formbricks/js/website";

if (typeof window !== "undefined") {
  formbricks.init({
    environmentId: "<environment-id>",
    apiHost: "<api-host>",
  });
}

function App() {
  // Your app code
}

export default App;
```

### 3.3 Next.js Integration (Detailed)

#### Option A: App Router (Recommended for Next.js 13+)

**Step 1:** Create `app/formbricks.tsx`:
```tsx
"use client";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import formbricks from "@formbricks/js";

export default function FormbricksProvider() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    formbricks.init({
      environmentId: process.env.NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID!,
      apiHost: process.env.NEXT_PUBLIC_FORMBRICKS_API_HOST!,
      userId: "<user-id>", // Get from your auth system
    });
  }, []);

  useEffect(() => {
    formbricks?.registerRouteChange();
  }, [pathname, searchParams]);

  return null;
}
```

**Step 2:** Update `app/layout.tsx`:
```tsx
import FormbricksProvider from "./formbricks";

export default function RootLayout({
  children
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <FormbricksProvider />
      <body>{children}</body>
    </html>
  );
}
```

**Step 3:** Environment Variables (`.env.local`):
```bash
NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID=your_environment_id
NEXT_PUBLIC_FORMBRICKS_API_HOST=https://app.formbricks.com
# or your self-hosted URL: https://formbricks.yourdomain.com
```

#### Option B: Pages Router (Next.js 12 or older)

Update `pages/_app.tsx`:
```tsx
import { useRouter } from "next/router";
import { useEffect } from "react";
import formbricks from "@formbricks/js";
import type { AppProps } from "next/app";

if (typeof window !== "undefined") {
  formbricks.init({
    environmentId: process.env.NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID!,
    apiHost: process.env.NEXT_PUBLIC_FORMBRICKS_API_HOST!,
  });
}

export default function App({ Component, pageProps }: AppProps) {
  const router = useRouter();

  useEffect(() => {
    const handleRouteChange = formbricks?.registerRouteChange;
    router.events.on("routeChangeComplete", handleRouteChange);

    return () => {
      router.events.off("routeChangeComplete", handleRouteChange);
    };
  }, [router.events]);

  return <Component {...pageProps} />;
}
```

### 3.4 Post-Purchase Flow Integration Example

**Scenario:** Trigger survey after successful course purchase

**Implementation:**
```typescript
// In your purchase success page/component
import { useEffect } from 'react';
import formbricks from '@formbricks/js';

export default function PurchaseSuccessPage() {
  useEffect(() => {
    // Set user attributes for segmentation
    formbricks.setAttributes({
      courseName: "Advanced React Patterns",
      purchaseAmount: 299,
      purchaseDate: new Date().toISOString(),
      isFirstPurchase: true
    });

    // Trigger post-purchase survey
    formbricks.track("purchase_completed");
  }, []);

  return (
    <div>
      <h1>Thank you for your purchase!</h1>
      {/* Survey will appear based on your Formbricks configuration */}
    </div>
  );
}
```

**In Formbricks Dashboard:**
1. Create new survey
2. Set trigger: Action → "purchase_completed"
3. Add targeting conditions:
   - User attribute: `isFirstPurchase` equals `true`
   - User attribute: `purchaseAmount` greater than `100`
4. Configure survey questions
5. Publish survey

---

## 4. Survey Features

### 4.1 Question Types

Formbricks supports **"all question types you can think of"**, including:

**Basic Types:**
- Text input (short and long)
- Multiple choice (single select)
- Multi-select (checkboxes)
- Dropdown/combobox

**Advanced Types:**
- Rating scales (1-5, 1-10, stars)
- Net Promoter Score (NPS)
- Likert scales
- Slider inputs
- Date pickers
- File uploads

**Specialized:**
- Matrix questions
- Ranking questions
- Image choice questions

### 4.2 Logic and Branching

**Conditional Logic System:**

Formbricks uses conditions (rules) that determine when actions should execute. Logic can be:
- **Simple:** Show follow-up question based on single answer
- **Complex:** Calculate scores based on multiple answers

**Condition Types:**
- Based on previous question answer
- Based on variable value
- Based on hidden field value

**Available Actions:**

#### 1. Jump to Question
Skip to specific question based on condition:
```
IF user selects "Not satisfied"
THEN jump to Question 5 (feedback form)
ELSE continue to next question
```

#### 2. Calculate
Perform calculations on variables:
```
IF user rates "Excellent"
THEN add 10 to satisfaction_score
```

Variables can be:
- Fixed values
- Dynamic values from previous answers
- Calculated from multiple inputs

#### 3. Require Answer
Make optional questions required dynamically:
```
IF user selects "Other"
THEN require answer for "Please specify"
```

**Multiple Actions:**
You can add multiple actions to a logic block, and they execute in order.

**Multi-Language Support:**
Surveys can be created in multiple languages with language-specific logic.

### 4.3 Response Collection and Storage

**Storage Location:**
- Self-hosted: Your PostgreSQL database
- Cloud: Formbricks servers (GDPR/CCPA compliant)

**Response Data Includes:**
- Answer data (key-value pairs)
- User metadata (userId, attributes)
- Session information (device, browser, country)
- Timestamps (created, updated, finished)
- Completion metrics (time-to-complete per question)

**Data Ownership:**
With self-hosted deployment, you own 100% of response data.

---

## 5. Webhooks and Integrations

### 5.1 Webhook Events

**Available Triggers:**
1. **`responseCreated`** - New response started (not yet finished)
2. **`responseUpdated`** - Existing response modified
3. **`responseFinished`** - Response completed by user

### 5.2 Webhook Configuration

**Setup Methods:**

#### Via UI:
1. Log in to Formbricks
2. Navigate to Configuration → Integrations
3. Click "Manage Webhooks" → "Add Webhook"
4. Enter endpoint URL
5. Select trigger events
6. Test webhook

#### Via API:
Use Management API to create webhooks programmatically.

**Authentication:**
Requires personal API key (generated in Settings).

### 5.3 Webhook Payload Structure

**Example `responseFinished` Payload:**
```json
[
  {
    "event": "responseFinished",
    "webhookId": "webhook_abc123",
    "data": {
      "id": "response_xyz789",
      "surveyId": "survey_def456",
      "displayId": "display_ghi012",
      "finished": true,
      "endingId": "ending_jkl345",
      "data": {
        "q1": "Very satisfied",
        "q2": "The course content was excellent",
        "q3": 9
      },
      "contact": null,
      "contactAttributes": null,
      "meta": {
        "url": "https://yourapp.com/purchase-success",
        "userAgent": "Mozilla/5.0...",
        "country": "US"
      },
      "ttc": {
        "_total": 45.2,
        "q1": 12.3,
        "q2": 28.1,
        "q3": 4.8
      },
      "language": "en",
      "tags": [],
      "variables": {},
      "singleUseId": null,
      "createdAt": "2025-12-02T10:30:00.000Z",
      "updatedAt": "2025-12-02T10:30:45.000Z"
    }
  }
]
```

**Example `responseCreated` Payload:**
```json
[
  {
    "event": "responseCreated",
    "webhookId": "webhook_abc123",
    "data": {
      "id": "response_xyz789",
      "surveyId": "survey_def456",
      "displayId": "display_ghi012",
      "finished": false,
      "endingId": null,
      "data": {},
      "contact": null,
      "contactAttributes": null,
      "meta": {
        "url": "https://yourapp.com/purchase-success",
        "userAgent": "Mozilla/5.0...",
        "country": "US"
      },
      "ttc": {},
      "language": "en",
      "tags": [],
      "variables": {},
      "singleUseId": null,
      "createdAt": "2025-12-02T10:30:00.000Z",
      "updatedAt": "2025-12-02T10:30:00.000Z"
    }
  }
]
```

**Key Payload Fields:**
- **`event`**: Event type (responseCreated/Updated/Finished)
- **`webhookId`**: Your webhook identifier
- **`data.id`**: Unique response ID
- **`data.surveyId`**: Survey identifier
- **`data.finished`**: Boolean completion status
- **`data.data`**: Actual form responses (question IDs → answers)
- **`data.meta`**: User context (URL, user agent, country)
- **`data.ttc`**: Time-to-complete metrics (per question + total)
- **`data.contact`**: Contact info (if user identified)
- **`data.contactAttributes`**: Custom user attributes

### 5.4 API for Fetching Responses

**Public Client API:**
No authentication required (designed for SDKs):
- **Displays API** - Mark survey as displayed
- **People API** - Create/update person with attributes
- **Responses API** - Create/update survey response

**Management API:**
Requires personal API key:
- **GET responses** - Fetch all responses for a survey
- **GET response by ID** - Fetch specific response
- **DELETE response** - Remove response data
- **Webhooks management** - CRUD operations on webhooks

**Example: Fetch Survey Responses**
```bash
curl -X GET \
  https://app.formbricks.com/api/v1/management/surveys/{surveyId}/responses \
  -H "x-api-key: YOUR_API_KEY"
```

### 5.5 Third-Party Integrations

**Available Integrations:**
- **Zapier** - Connect to 5000+ apps
- **Slack** - Send responses to channels
- **Airtable** - Sync responses to tables
- **Discord** - Post responses to channels
- **Gmail** - Send email notifications
- **Webhooks** - Custom integrations

**Zapier Example Workflows:**
1. New Formbricks response → Create Google Sheets row
2. Survey finished → Send Slack message
3. Response created → Add to CRM (HubSpot, Salesforce)

---

## 6. Post-Purchase Flow Recommendation

### 6.1 Implementation Architecture

```
Purchase Flow:
1. User completes purchase
2. Redirect to success page
3. Initialize Formbricks with user context
4. Set user attributes (course, price, date)
5. Trigger "purchase_completed" event
6. Formbricks displays targeted survey
7. User completes survey (optional)
8. Response sent to webhook endpoint
9. Store feedback in your database
10. Trigger follow-up actions (email, analytics)
```

### 6.2 Code Example (Complete Flow)

**`app/purchase/success/page.tsx`:**
```tsx
"use client";

import { useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import formbricks from '@formbricks/js';

export default function PurchaseSuccessPage() {
  const searchParams = useSearchParams();
  const courseId = searchParams.get('courseId');
  const userId = searchParams.get('userId');
  const amount = searchParams.get('amount');

  useEffect(() => {
    // Initialize with user ID
    if (userId) {
      formbricks.setUserId(userId);
    }

    // Set purchase context attributes
    formbricks.setAttributes({
      courseName: getCourseNameById(courseId),
      courseId: courseId,
      purchaseAmount: Number(amount),
      purchaseDate: new Date().toISOString(),
      isFirstPurchase: await checkIfFirstPurchase(userId),
      userTier: await getUserTier(userId)
    });

    // Trigger post-purchase survey
    formbricks.track("purchase_completed");
  }, [courseId, userId, amount]);

  return (
    <div className="success-page">
      <h1>Welcome to Your Course!</h1>
      <p>Your enrollment is confirmed.</p>
      {/* Survey will appear as modal or inline based on config */}
    </div>
  );
}
```

**Webhook Handler (`app/api/webhooks/formbricks/route.ts`):**
```typescript
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/database';

export async function POST(request: NextRequest) {
  const payload = await request.json();

  for (const event of payload) {
    const { event: eventType, data } = event;

    if (eventType === 'responseFinished') {
      // Store feedback in database
      await db.courseFeedback.create({
        data: {
          responseId: data.id,
          surveyId: data.surveyId,
          userId: data.contact?.userId,
          answers: data.data,
          satisfaction: data.data.nps_score,
          feedback: data.data.open_feedback,
          completionTime: data.ttc._total,
          createdAt: new Date(data.createdAt)
        }
      });

      // Trigger follow-up actions
      if (data.data.nps_score <= 6) {
        // Low satisfaction - alert support team
        await sendSlackAlert({
          message: `Low NPS score (${data.data.nps_score}) from recent purchase`,
          userId: data.contact?.userId
        });
      }

      if (data.data.wants_interview) {
        // User opted in for interview
        await scheduleInterview(data.contact?.userId);
      }
    }
  }

  return NextResponse.json({ success: true });
}
```

### 6.3 Survey Configuration

**Recommended Questions for Post-Purchase:**

1. **NPS Question:**
   - "How likely are you to recommend this course to a colleague?" (0-10 scale)

2. **Satisfaction Rating:**
   - "How satisfied are you with your purchase?" (5-star rating)

3. **Conditional Follow-up:**
   - IF score < 7: "What could we have done better?"
   - IF score >= 9: "Would you like to share a testimonial?"

4. **Feature Feedback:**
   - "What feature are you most excited to use?" (Multiple choice)

5. **Interview Opt-in:**
   - "Would you be interested in a 15-minute feedback interview?" (Yes/No)
   - IF yes: "What's the best email to reach you?" (Email input)

**Targeting Rules:**
- Show only to users with `isFirstPurchase: true`
- Don't show if user has completed survey in last 30 days
- Show 5 seconds after page load (give time to read success message)

### 6.4 Best Practices

1. **Timing:**
   - Wait 3-5 seconds before triggering survey
   - Don't interrupt critical post-purchase actions
   - Consider email follow-up for non-responders

2. **Keep it Short:**
   - 2-4 questions maximum for in-app surveys
   - Use logic to show relevant follow-ups only
   - Save detailed surveys for email

3. **Incentivize Completion:**
   - Offer bonus content for feedback
   - Entry into prize drawing
   - Early access to new features

4. **Respect User Choice:**
   - Easy dismiss/close button
   - Don't show repeatedly if dismissed
   - Provide "Remind me later" option

5. **Data Privacy:**
   - Clear privacy notice in survey
   - Allow anonymous feedback option
   - GDPR/CCPA compliant storage

---

## 7. Cost Analysis

### 7.1 Self-Hosted (Free)

**Costs:**
- Infrastructure: $10-50/month (VPS or cloud hosting)
- Database: $0 (included in hosting) or $10-20/month (managed PostgreSQL)
- Total: $10-70/month

**Benefits:**
- Unlimited surveys
- Unlimited responses
- Complete data ownership
- No per-seat pricing
- Full customization

### 7.2 Cloud Hosted (Formbricks)

**Pricing Tiers:**
- **Free Plan:** Limited features, up to 250 responses/month
- **Pro Plan:** ~$49/month (estimated, check website)
- **Enterprise:** Custom pricing

**Benefits:**
- No infrastructure management
- Automatic updates
- Built-in backups
- Email support

### 7.3 Recommendation for Learning Platform

**Self-Hosted is Recommended if:**
- You expect >1000 responses/month
- You need custom branding
- You want complete data control
- You have DevOps resources
- You need GDPR compliance with data residency

**Cloud Hosted is Recommended if:**
- You're testing/prototyping
- You want fastest time to market
- You don't want to manage infrastructure
- You expect <1000 responses/month

---

## 8. Technical Considerations

### 8.1 Performance

**SDK Impact:**
- **Bundle size:** 7KB (minified + gzipped)
- **Loading:** Deferred (doesn't block page load)
- **Runtime:** Minimal CPU/memory footprint

**Optimization:**
- Lazy load SDK after critical content
- Use Next.js dynamic imports if needed
- Cache survey definitions

### 8.2 Security

**Self-Hosted Security:**
- Regular updates required (monitor GitHub releases)
- SSL/TLS required (Let's Encrypt recommended)
- Strong NEXTAUTH_SECRET and ENCRYPTION_KEY
- Database encryption at rest
- Regular backups (automated recommended)

**Data Privacy:**
- GDPR compliant (with proper configuration)
- CCPA compliant
- Working towards SOC 2 Type II certification
- No third-party tracking by default

### 8.3 Scalability

**Database:**
- PostgreSQL with pgvector handles millions of responses
- Index response tables for performance
- Regular VACUUM operations recommended

**Application:**
- Horizontal scaling supported (Kubernetes)
- High-availability cluster configuration available
- CDN recommended for static assets

**Rate Limits:**
- No rate limits on self-hosted
- Cloud version has per-plan limits

### 8.4 Monitoring

**Recommended Monitoring:**
- Application uptime (Uptime Robot, Pingdom)
- Database performance (pg_stat_statements)
- Response times (Grafana, Prometheus)
- Error tracking (Sentry integration recommended)

---

## 9. Migration Path

If you outgrow Formbricks or need to migrate:

**Export Options:**
- **API export:** Fetch all responses via Management API
- **Database export:** Direct PostgreSQL dump
- **CSV export:** Built-in export to CSV

**Data Format:**
Standard JSON format makes migration straightforward.

---

## 10. Alternatives Considered

For context, here are alternatives and why Formbricks stands out:

**Typeform:**
- ❌ Expensive ($25-83/month)
- ❌ Proprietary/closed source
- ❌ Limited branching logic
- ✅ Beautiful UI

**Google Forms:**
- ✅ Free
- ❌ Basic logic only (simple go-to-section)
- ❌ Limited customization
- ❌ No in-app embedding
- ❌ Google data ownership concerns

**SurveyMonkey:**
- ❌ Very expensive ($30-99/month)
- ❌ Proprietary
- ❌ Limited API access on lower tiers

**Qualtrics:**
- ❌ Enterprise pricing ($$$$)
- ❌ Overkill for most use cases
- ✅ Advanced features
- ✅ Enterprise support

**Formbricks Advantages:**
- ✅ Open source (AGPLv3)
- ✅ Self-hosted option
- ✅ Complete data ownership
- ✅ Native Next.js support
- ✅ Advanced conditional logic
- ✅ Active development (check GitHub)
- ✅ 7KB SDK (smallest in class)
- ✅ 6-10x better conversion rates (in-app)

---

## 11. Implementation Timeline

**Estimated Timeline for Learning Platform Integration:**

### Week 1: Setup (3-5 days)
- [ ] Deploy self-hosted Formbricks (1 day)
  - Set up VPS/cloud server
  - Configure Docker Compose
  - Set up PostgreSQL with pgvector
  - Configure environment variables
  - Set up SSL certificate
- [ ] Create Formbricks account and project (1 hour)
- [ ] Install SDK in Next.js app (2-4 hours)
  - Install @formbricks/js package
  - Create FormbricksProvider component
  - Update layout.tsx
  - Configure environment variables
- [ ] Test basic survey trigger (1 day)

### Week 2: Survey Design (5-7 days)
- [ ] Design post-purchase survey questions (1 day)
  - Draft questions
  - Get stakeholder approval
  - Design branching logic
- [ ] Configure survey in Formbricks dashboard (1 day)
  - Create survey
  - Add questions
  - Set up conditional logic
  - Configure targeting rules
  - Design survey appearance
- [ ] Set up webhook endpoint (1 day)
  - Create API route
  - Implement response storage
  - Test webhook delivery
- [ ] Integrate with post-purchase flow (2 days)
  - Add SDK calls to success page
  - Set user attributes
  - Trigger custom events
  - Test end-to-end flow
- [ ] QA testing (1-2 days)

### Week 3: Launch and Monitor (ongoing)
- [ ] Soft launch to 10% of users (1 day)
- [ ] Monitor response rates and technical issues (3 days)
- [ ] Iterate based on feedback (ongoing)
- [ ] Full launch to 100% of users (1 day)

**Total Time:** 2-3 weeks from start to full launch

---

## 12. Key Decision Points

### Should You Use Formbricks?

**✅ YES if:**
- You need in-app surveys with high conversion rates
- You want complete control over your data
- You have DevOps resources for self-hosting
- You need advanced conditional logic
- You want to avoid per-response pricing
- You need GDPR-compliant data residency
- You prefer open-source solutions

**❌ MAYBE NOT if:**
- You need enterprise sales features (CRM integration, etc.)
- You want white-glove support (Qualtrics level)
- You have no technical team for self-hosting
- You only need simple surveys (<5 questions, no logic)
- You need advanced analytics dashboards out-of-the-box

---

## 13. Support and Resources

### Official Documentation
- Main Docs: https://formbricks.com/docs
- Developer Docs: https://formbricks.com/docs/developer-docs/overview
- API Reference: https://formbricks.com/docs/developer-docs/rest-api
- Webhook Guide: https://formbricks.com/docs/developer-docs/webhooks

### GitHub
- Repository: https://github.com/formbricks/formbricks
- Issues: https://github.com/formbricks/formbricks/issues
- Releases: https://github.com/formbricks/formbricks/releases

### Community
- Discord: [Check website for invite]
- GitHub Discussions: Active community support
- Twitter/X: @formbricks

### NPM Package
- Package: https://www.npmjs.com/package/@formbricks/js
- Current Version: Check npm for latest

### Self-Hosting Guides
- Docker Setup: https://formbricks.com/docs/self-hosting/docker
- Environment Variables: [Available in docs]
- Migration Guide: https://formbricks.com/docs/self-hosting/migration-guide

---

## 14. Next Steps

### Immediate Actions:

1. **Proof of Concept (1 week):**
   - Deploy Formbricks locally with Docker
   - Create test Next.js app with integration
   - Build sample post-purchase survey
   - Test webhook delivery
   - Evaluate UX and technical fit

2. **Production Planning (1 week):**
   - Choose hosting provider (AWS, DigitalOcean, etc.)
   - Design production survey questions
   - Plan data storage schema
   - Design analytics dashboard

3. **Implementation (2 weeks):**
   - Follow Week 1-3 timeline above
   - Soft launch and iterate

### Questions to Answer:

- [ ] What hosting provider will you use?
- [ ] What survey questions are most important?
- [ ] How will you use the feedback data?
- [ ] What's your expected response volume?
- [ ] Do you need custom branding?
- [ ] What's your data retention policy?

---

## 15. Conclusion

Formbricks is an excellent choice for embedding post-purchase surveys in a Next.js learning platform:

**Strengths:**
- **High conversion rates** (6-10x better than email)
- **Lightweight** (7KB SDK)
- **Open source** with active development
- **Self-hosted option** for complete control
- **Advanced logic** for sophisticated surveys
- **Native Next.js support**

**Best Use Case:**
In-app surveys triggered after course purchase, with conditional logic to gather targeted feedback and identify power users for testimonials/interviews.

**Recommendation:**
Start with self-hosted deployment for data ownership and cost efficiency. Use the App Router integration pattern. Design a short (2-3 question) post-purchase survey with conditional logic. Monitor webhook responses and iterate based on completion rates.

---

## Research Sources

All information compiled from official Formbricks documentation and community resources (2025-12-02):

1. [The Open Source Qualtrics Alternative](https://formbricks.com/)
2. [In-app Surveys, Open Source - Formbricks](https://formbricks.com/in-app-survey)
3. [GitHub - formbricks/formbricks](https://github.com/formbricks/formbricks)
4. [Embed Surveys - Documentation](https://formbricks.com/docs/xm-and-surveys/surveys/link-surveys/embed-surveys)
5. [Formbricks Quickstart Guide: In-App Surveys](https://formbricks.com/docs/getting-started/quickstart-in-app-survey)
6. [Guide to Deploying Formbricks Using Docker](https://formbricks.com/docs/self-hosting/docker)
7. [Docker Setup - Documentation](https://formbricks.com/docs/self-hosting/setup/docker)
8. [Understanding Formbricks Self-hosting](https://formbricks.com/blog/understanding-formbricks-self-hosting)
9. [Framework Guides - Documentation](https://formbricks.com/docs/xm-and-surveys/surveys/website-app-surveys/framework-guides)
10. [Integrate Formbricks: Framework Guide](https://formbricks.com/docs/app-surveys/framework-guides)
11. [Formbricks JS SDK - Formbricks Docs](https://formbricks.com/docs/developer-docs/js-sdk)
12. [@formbricks/js - npm](https://www.npmjs.com/package/@formbricks/js)
13. [Webhooks - Documentation](https://formbricks.com/docs/xm-and-surveys/core-features/integrations/webhooks)
14. [Formbricks Webhooks Overview](https://formbricks.com/docs/developer-docs/webhooks)
15. [Formbricks API Overview](https://formbricks.com/docs/developer-docs/rest-api)
16. [Conditional Logic - Documentation](https://formbricks.com/docs/xm-and-surveys/surveys/general-features/conditional-logic)
17. [Configure Formbricks with External auth providers](https://formbricks.com/docs/self-hosting/configuration)
18. [formbricks/.env.example](https://github.com/formbricks/formbricks/blob/main/.env.example)
19. [Formbricks E-Commerce Survey Tool](https://formbricks.com/industry/ecommerce-survey-software)

---

**Document Version:** 1.0
**Last Updated:** 2025-12-02
**Maintained By:** Research Team
