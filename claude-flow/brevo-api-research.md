# Brevo (Sendinblue) Email API Research - Learning Platform

## Executive Summary

Brevo (formerly Sendinblue) provides a comprehensive email API platform with transactional emails, contact management, automation workflows, and webhooks. This research covers implementation details for a learning platform with focus on authentication, rate limits, deliverability best practices, and code examples.

**Key Highlights:**
- 99% delivery rate guarantee
- Supports 8 programming languages (Node.js, Python, PHP, Ruby, Go, Java, C#, TypeScript)
- Up to 5,000 emails/day for bulk senders before stricter requirements
- Comprehensive webhook support for real-time event tracking
- Template system with dynamic variables

---

## 1. Transactional Email API

### Overview
Transactional emails handle non-promotional communications like:
- Welcome emails
- Account confirmations
- Password resets
- Order notifications
- Course enrollment confirmations
- Learning progress reminders

### API Endpoint
```
POST https://api.brevo.com/v3/smtp/email
```

### Authentication
```javascript
// Header-based authentication
headers: {
  'api-key': 'your-api-key-here',
  'Content-Type': 'application/json'
}
```

**Getting Your API Key:**
1. Log into Brevo account
2. Click profile name (top right) → SMTP & API
3. Navigate to API Keys tab
4. Generate new API key
5. **Save immediately** (won't be shown again for security)

### Node.js Implementation

#### Installation
```bash
npm i @getbrevo/brevo --save
```

#### Basic Email (HTML Content)
```typescript
import { TransactionalEmailsApi, TransactionalEmailsApiApiKeys } from '@getbrevo/brevo';

const transactionalEmailsApi = new TransactionalEmailsApi();
transactionalEmailsApi.setApiKey(
  TransactionalEmailsApiApiKeys.apiKey,
  'xkeysib-YOUR_API_KEY'
);

async function sendWelcomeEmail() {
  const result = await transactionalEmailsApi.sendTransacEmail({
    sender: {
      email: 'courses@yourlearningplatform.com',
      name: 'Learning Platform'
    },
    to: [{
      email: 'student@example.com',
      name: 'Jane Student'
    }],
    subject: 'Welcome to Your Course!',
    htmlContent: `
      <html>
        <body>
          <h1>Welcome Jane!</h1>
          <p>You've successfully enrolled in Introduction to AI.</p>
        </body>
      </html>
    `
  });

  console.log('Email sent:', result.messageId);
}
```

#### Template-Based Email with Variables
```typescript
async function sendCourseReminder() {
  const result = await transactionalEmailsApi.sendTransacEmail({
    sender: {
      email: 'courses@yourlearningplatform.com',
      name: 'Learning Platform'
    },
    to: [{
      email: 'student@example.com',
      name: 'Jane Student'
    }],
    templateId: 56, // Your template ID from Brevo dashboard
    params: {
      studentName: 'Jane',
      courseName: 'Introduction to AI',
      lessonTitle: 'Neural Networks Basics',
      dueDate: '2025-12-10',
      completionPercentage: '75%'
    }
  });
}
```

### Template System

#### Template Variable Format
In Brevo templates, use this format:
```handlebars
{{ params.variableName }}
```

**Example Template:**
```html
<h1>Hi {{ params.studentName }}!</h1>
<p>Your course <strong>{{ params.courseName }}</strong> has a new lesson available.</p>
<p>Lesson: {{ params.lessonTitle }}</p>
<p>Due date: {{ params.dueDate }}</p>
<p>Your progress: {{ params.completionPercentage }}</p>
```

**Important Notes:**
- `{{ params.* }}` variables are passed via API
- `{{ contact.* }}` variables fetch from contact database (cannot be overridden via API)
- Preview templates before sending using the Template Preview API

### Batch Sending (Up to 1,000 Recipients)
```typescript
async function sendBulkCourseUpdates() {
  const result = await transactionalEmailsApi.sendTransacEmail({
    sender: {
      email: 'courses@yourlearningplatform.com',
      name: 'Learning Platform'
    },
    templateId: 58,
    messageVersions: [
      {
        to: [{ email: 'student1@example.com', name: 'Student 1' }],
        params: { courseName: 'AI Basics', progress: '80%' }
      },
      {
        to: [{ email: 'student2@example.com', name: 'Student 2' }],
        params: { courseName: 'ML Advanced', progress: '45%' }
      },
      // ... up to 1,000 message versions
    ]
  });
}
```

**Batch Limits:**
- Up to 1,000 message versions per request
- 6,000 requests per hour (100/minute)
- Maximum 30,000 emails per hour with batch endpoint

### Scheduled Emails
```typescript
async function scheduleCourseLaunch() {
  const result = await transactionalEmailsApi.sendTransacEmail({
    sender: { email: 'courses@yourlearningplatform.com', name: 'Platform' },
    to: [{ email: 'student@example.com', name: 'Jane' }],
    templateId: 60,
    params: { courseName: 'New Course Launch' },
    scheduledAt: '2025-12-15T10:00:00Z' // ISO 8601 format
  });
}
```

### Rate Limits (Transactional Emails)
- **Standard endpoint:** Dedicated rate limits (varies by plan)
- **Batch endpoint:** 5 requests/minute (30,000 emails/hour max)
- **Enterprise:** Apply for rate limit add-ons for higher throughput

---

## 2. Contact Management

### Creating Contacts

#### API Endpoint
```
POST https://api.brevo.com/v3/contacts
```

#### Basic Contact Creation
```typescript
interface ContactData {
  email?: string;
  attributes?: {
    SMS?: string;          // Phone with country code: "+1234567890"
    FIRSTNAME?: string;
    LASTNAME?: string;
    [key: string]: any;    // Custom attributes
  };
  listIds?: number[];      // Lists to add contact to
  emailBlacklisted?: boolean;
  smsBlacklisted?: boolean;
  updateEnabled?: boolean; // Update if exists
  ext_id?: string;         // External ID
}

async function createLearningContact(studentData: ContactData) {
  const response = await fetch('https://api.brevo.com/v3/contacts', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY!,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: studentData.email,
      attributes: {
        FIRSTNAME: studentData.attributes?.FIRSTNAME,
        LASTNAME: studentData.attributes?.LASTNAME,
        SMS: studentData.attributes?.SMS,
        ENROLLMENT_DATE: new Date().toISOString(),
        COURSE_TIER: 'Premium',
        LEARNING_STYLE: 'Visual'
      },
      listIds: [12, 34], // Course mailing lists
      updateEnabled: true // Update if exists
    })
  });

  const result = await response.json();
  console.log('Contact created with ID:', result.id);
  return result;
}
```

#### Updating Contacts
```
PUT https://api.brevo.com/v3/contacts/{identifier}
```

```typescript
async function updateStudentProgress(email: string, progress: number) {
  const response = await fetch(
    `https://api.brevo.com/v3/contacts/${encodeURIComponent(email)}`,
    {
      method: 'PUT',
      headers: {
        'api-key': process.env.BREVO_API_KEY!,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        attributes: {
          COURSE_PROGRESS: progress,
          LAST_ACTIVITY: new Date().toISOString(),
          ENGAGEMENT_LEVEL: progress > 80 ? 'High' : 'Medium'
        },
        listIds: [12], // Add to engaged students list
        unlinkListIds: [34] // Remove from inactive list
      })
    }
  );

  return response.json();
}
```

### Contact Attributes

#### Available Attribute Types
1. **Text** - Email, names, zip codes (non-computable)
2. **Number** - Age, progress percentage, credits earned
3. **Date** - Enrollment date, last login, course completion
4. **Category** - Learning style (Visual, Auditory, Kinesthetic)
5. **Multiple-choice** - Preferred topics (AI, ML, Data Science)
6. **Boolean** - Premium member, email verified, completed onboarding
7. **User** - Assigned instructor

**Limits:**
- Maximum 200 contact attributes per account
- Attribute names: Max 50 characters
- Only alphanumeric and underscores
- Cannot start with number or special character

#### Custom Attributes for Learning Platform
```typescript
const learningPlatformAttributes = {
  // Profile
  ENROLLMENT_DATE: '2025-01-15',
  LEARNING_STYLE: 'Visual',
  TIMEZONE: 'America/New_York',
  PREFERRED_LANGUAGE: 'en',

  // Progress
  COURSES_COMPLETED: 5,
  COURSE_PROGRESS: 75.5,
  TOTAL_HOURS: 42.5,
  LAST_ACTIVITY: '2025-12-01',

  // Engagement
  EMAIL_OPENS_30D: 12,
  LESSON_STREAK_DAYS: 7,
  ENGAGEMENT_LEVEL: 'High',

  // Subscription
  SUBSCRIPTION_TIER: 'Premium',
  SUBSCRIPTION_STATUS: 'Active',
  SUBSCRIPTION_RENEWAL: '2026-01-15',

  // Preferences
  NOTIFICATION_FREQUENCY: 'Daily',
  CONTENT_TOPICS: ['AI', 'Machine Learning', 'Data Science']
};
```

### List Management

#### Getting Lists
```
GET https://api.brevo.com/v3/contacts/lists?limit=50&offset=0
```

#### Creating Lists
```typescript
async function createCourseList(courseName: string, folderId: number) {
  const response = await fetch('https://api.brevo.com/v3/contacts/lists', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY!,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      name: `${courseName} - Enrolled Students`,
      folderId: folderId
    })
  });

  return response.json();
}
```

**Important:** As of January 1, 2025, dynamic lists become static lists (no longer auto-updated). Use segments instead for dynamic filtering.

### Segmentation

Segments are auto-updated groups based on conditions (attributes/events).

#### Segmentation Examples for Learning Platform

**High-Engagement Students (for upselling):**
```
Conditions:
- ENGAGEMENT_LEVEL is equal to "High"
- COURSE_PROGRESS > 80
- EMAIL_OPENS_30D >= 5
- SUBSCRIPTION_TIER is equal to "Free"
```

**Re-engagement Campaign (inactive students):**
```
Conditions:
- Email received > At least 3 times > In last 3 months
- Email opened = 0 times > In last 3 months
- LAST_ACTIVITY > 30 days ago
```

**Course Completion Reminder:**
```
Conditions:
- COURSE_PROGRESS between 60% and 95%
- LAST_ACTIVITY > 7 days ago
- SUBSCRIPTION_STATUS is equal to "Active"
```

**Language-Based Segmentation:**
```
Conditions:
- PREFERRED_LANGUAGE is equal to "Spanish"
- TIMEZONE contains "America"
```

**AI-Powered Segments (Aura):**
Use natural language prompts:
- "Students who enrolled in the last 30 days but haven't completed first lesson"
- "Premium members who opened all emails but haven't logged in this week"
- "Users interested in AI courses with high engagement scores"

### Rate Limits (Contact Management)
- **Contact endpoints:** 10 requests per second (36,000/hour)
- **429 status code:** Too many requests (includes reset time in headers)

---

## 3. Email Automation

### Workflow Triggers (20+ Available)

#### Contact-Based Triggers
- **Contact added to list** - New student enrollment
- **Contact updated** - Progress milestones reached
- **Contact attribute change** - Subscription tier upgrade

#### Email Engagement Triggers
- **Email opened** - Student opened course announcement
- **Link clicked** - Clicked "Start Lesson" button
- **Email not opened** - Re-engagement sequence

#### Ecommerce Triggers (Requires Brevo Tracker)
- **Cart updated** - Course added to cart
- **Order created** - Course purchased
- **Cart abandoned** - Started checkout but didn't complete

#### CRM Triggers
- **Deal created** - Enterprise sales opportunity
- **Deal stage updated** - Move through sales funnel
- **Task completed** - Follow-up action finished

#### Conversation Triggers
- **Conversation started** - Support chat initiated
- **Message received** - Student sent support message

#### Custom Event Triggers
Trigger emails based on website activity:
- Form submission
- Lesson completion
- Quiz passed/failed
- Certificate earned
- Custom event tracking

### Trigger Filters

Refine triggers with event data:

**Order Created Trigger with Filters:**
```
Trigger: Order created
Filters:
  - Product name contains "AI Fundamentals"
  - Order amount > $99
  - First purchase = true
```

**Email Clicked Trigger with Filters:**
```
Trigger: Link clicked
Filters:
  - URL contains "/enroll"
  - Campaign name = "Summer Sale"
  - Clicked within 24 hours
```

### Automation Actions

Once triggered, automations can:
- **Send email** - Personalized course content
- **Wait** - Delay for optimal timing (e.g., wait 3 days)
- **Update contact** - Change engagement score
- **Add to list** - Move to "Active Learners" list
- **Remove from list** - Unsubscribe from promos
- **Create deal** - Sales team follow-up
- **Send SMS** - Urgent course reminders
- **Webhook** - Notify external system

### Example Learning Platform Automations

#### Onboarding Sequence
```
Trigger: Contact added to list (New Students)
Actions:
  1. Send email: Welcome email (immediate)
  2. Wait: 1 day
  3. Send email: Getting started guide
  4. Wait: 3 days
  5. Condition: If FIRST_LESSON_COMPLETED = false
     - Send email: "Need help getting started?"
  6. Wait: 7 days
  7. Update contact: ONBOARDING_COMPLETED = true
```

#### Course Completion Nudge
```
Trigger: Contact attribute change (COURSE_PROGRESS)
Filters: COURSE_PROGRESS between 80% and 95%
Actions:
  1. Wait: 2 days
  2. Condition: If COURSE_PROGRESS still < 100%
     - Send email: "You're almost there! Finish your course"
  3. Wait: 5 days
  4. Condition: If COURSE_PROGRESS still < 100%
     - Send email: "Special bonus for course completion"
```

#### Abandoned Cart Recovery
```
Trigger: Cart updated
Filters: Cart value > $50
Actions:
  1. Wait: 1 hour
  2. Condition: If order NOT created
     - Send email: "Complete your enrollment - 10% off"
  3. Wait: 24 hours
  4. Condition: If order NOT created
     - Send email: "Last chance - course prices increasing"
```

### Requirements for Ecommerce Triggers

Install Brevo tracker on your website:
```html
<!-- Add to <head> section -->
<script type="text/javascript">
  (function() {
    window.sib = {
      equeue: [],
      client_key: "YOUR_BREVO_TRACKER_KEY"
    };
    window.sendinblue = {};
    for (var j = ['track', 'identify', 'trackLink', 'page'], i = 0; i < j.length; i++) {
      (function(k) {
        window.sendinblue[k] = function() {
          var arg = Array.prototype.slice.call(arguments);
          (window.sib[k] || function() {
            var t = {};
            t[k] = arg;
            window.sib.equeue.push(t);
          })(arg[0], arg[1], arg[2], arg[3]);
        };
      })(j[i]);
    }
    var n = document.createElement("script"),
        i = document.getElementsByTagName("script")[0];
    n.type = "text/javascript", n.id = "sendinblue-js", n.async = !0,
    n.src = "https://sibautomation.com/sa.js?key=" + window.sib.client_key,
    i.parentNode.insertBefore(n, i);
  })();
</script>
```

Track custom events:
```javascript
// Track course enrollment
sendinblue.track('course_enrolled', {
  course_id: 'ai-101',
  course_name: 'AI Fundamentals',
  price: 99.00,
  tier: 'premium'
});

// Track lesson completion
sendinblue.track('lesson_completed', {
  lesson_id: 'neural-networks-1',
  course_id: 'ai-101',
  completion_time: 45 // minutes
});

// Identify user
sendinblue.identify('user@example.com', {
  FIRSTNAME: 'Jane',
  LEARNING_STYLE: 'Visual'
});
```

---

## 4. Webhooks

### Overview
Webhooks provide real-time HTTP POST notifications when events occur. You can create up to 40 outbound webhooks per account.

### Setting Up Webhooks

1. **Define notification URL** on your server
2. **Select event types** to monitor
3. **Configure authentication** (optional)
4. **Handle POST requests** in real-time

### Webhook Categories

#### Transactional Events
- `request` - Email request received
- `delivered` - Email successfully delivered
- `opened` - Email opened (first open)
- `click` - Link clicked
- `hard_bounce` - Permanent delivery failure
- `soft_bounce` - Temporary delivery failure
- `invalid_email` - Invalid email address
- `deferred` - Delayed delivery
- `complaint` - Marked as spam
- `unsubscribed` - User unsubscribed
- `blocked` - Blocked by Brevo
- `error` - Delivery error

#### Marketing Events
- `list_addition` - Contact added to list
- `proxy_open` - Email opened via proxy (privacy-protected)
- `opened` - Campaign email opened
- `delivered` - Campaign delivered
- `soft_bounced` - Campaign soft bounce
- `hard_bounce` - Campaign hard bounce
- `spam` - Marked as spam
- `contact_updated` - Contact information changed
- `contact_deleted` - Contact removed

### Payload Structure

#### Common Parameters (All Events)
```typescript
interface WebhookPayload {
  event: string;           // Event type
  email: string;          // Recipient email
  id: number;             // Message ID
  date: string;           // CET/CEST timezone
  ts: number;             // Timestamp (UTC)
  ts_event: number;       // Event timestamp (UTC)
  ts_epoch: number;       // Epoch time (UTC)
  message-id: string;     // Unique message ID
  subject?: string;       // Email subject
  tag?: string;           // Campaign tag
  sending_ip?: string;    // Sending IP address
  tags?: string[];        // Multiple tags
  template_id?: number;   // Template ID
  'X-Mailin-custom'?: string; // Custom data
}
```

#### Delivered Event Example
```json
{
  "event": "delivered",
  "email": "student@example.com",
  "id": 123456,
  "date": "2025-12-02 14:30:00",
  "ts": 1733148600,
  "ts_event": 1733148605,
  "ts_epoch": 1733148605000,
  "message-id": "<202512021430.123456@smtp-relay.brevo.com>",
  "subject": "Welcome to Your Course!",
  "sending_ip": "185.107.232.1",
  "tags": ["onboarding", "welcome"],
  "template_id": 56,
  "X-Mailin-custom": "{\"course_id\":\"ai-101\",\"user_id\":\"12345\"}"
}
```

#### Opened Event Example
```json
{
  "event": "opened",
  "email": "student@example.com",
  "id": 123456,
  "date": "2025-12-02 14:35:12",
  "ts": 1733148912,
  "ts_event": 1733148912,
  "ts_epoch": 1733148912000,
  "message-id": "<202512021430.123456@smtp-relay.brevo.com>",
  "subject": "Welcome to Your Course!",
  "tags": ["onboarding", "welcome"],
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"
}
```

#### Click Event Example
```json
{
  "event": "click",
  "email": "student@example.com",
  "id": 123456,
  "date": "2025-12-02 14:36:45",
  "ts": 1733149005,
  "ts_event": 1733149005,
  "ts_epoch": 1733149005000,
  "message-id": "<202512021430.123456@smtp-relay.brevo.com>",
  "subject": "Welcome to Your Course!",
  "link": "https://yourplatform.com/courses/ai-101/start",
  "tags": ["onboarding", "welcome"],
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
}
```

#### Hard Bounce Example
```json
{
  "event": "hard_bounce",
  "email": "invalid@example.com",
  "id": 123457,
  "date": "2025-12-02 14:31:00",
  "ts": 1733148660,
  "ts_event": 1733148662,
  "ts_epoch": 1733148662000,
  "message-id": "<202512021431.123457@smtp-relay.brevo.com>",
  "subject": "Welcome to Your Course!",
  "reason": "550 5.1.1 The email account that you tried to reach does not exist",
  "tags": ["onboarding", "welcome"]
}
```

#### Soft Bounce Example
```json
{
  "event": "soft_bounce",
  "email": "student@example.com",
  "id": 123458,
  "date": "2025-12-02 14:32:00",
  "ts": 1733148720,
  "ts_event": 1733148725,
  "ts_epoch": 1733148725000,
  "message-id": "<202512021432.123458@smtp-relay.brevo.com>",
  "subject": "Course Reminder",
  "reason": "Mailbox full",
  "tags": ["reminders"]
}
```

### Node.js Webhook Handler

```typescript
import express from 'express';
import crypto from 'crypto';

const app = express();
app.use(express.json());

// Webhook endpoint
app.post('/webhooks/brevo', async (req, res) => {
  const event = req.body;

  console.log('Received webhook:', event.event, 'for', event.email);

  try {
    switch (event.event) {
      case 'delivered':
        await handleDelivered(event);
        break;

      case 'opened':
        await handleOpened(event);
        break;

      case 'click':
        await handleClick(event);
        break;

      case 'hard_bounce':
      case 'invalid_email':
        await handleBounce(event);
        break;

      case 'soft_bounce':
        await handleSoftBounce(event);
        break;

      case 'complaint':
        await handleSpamComplaint(event);
        break;

      case 'unsubscribed':
        await handleUnsubscribe(event);
        break;

      default:
        console.log('Unhandled event type:', event.event);
    }

    // Always respond 200 OK to acknowledge receipt
    res.status(200).send('OK');

  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(200).send('OK'); // Still acknowledge to prevent retries
  }
});

async function handleDelivered(event: WebhookPayload) {
  // Update database: email successfully delivered
  await updateEmailStatus(event.email, event.id, 'delivered');

  // Parse custom data if present
  if (event['X-Mailin-custom']) {
    const customData = JSON.parse(event['X-Mailin-custom']);
    console.log('Custom data:', customData);
  }
}

async function handleOpened(event: WebhookPayload) {
  // Track engagement: student opened email
  await trackEngagement(event.email, 'email_open', {
    messageId: event.id,
    timestamp: new Date(event.ts_epoch),
    tags: event.tags
  });

  // Update engagement score
  await incrementEngagementScore(event.email, 5);
}

async function handleClick(event: WebhookPayload & { link?: string }) {
  // High-value engagement: student clicked link
  await trackEngagement(event.email, 'email_click', {
    messageId: event.id,
    link: event.link,
    timestamp: new Date(event.ts_epoch)
  });

  // Higher engagement score for clicks
  await incrementEngagementScore(event.email, 10);

  // Trigger follow-up actions based on link
  if (event.link?.includes('/courses/ai-101/start')) {
    await triggerCourseStartSequence(event.email);
  }
}

async function handleBounce(event: WebhookPayload & { reason?: string }) {
  // Remove invalid email from database
  await markEmailInvalid(event.email, event.reason);

  // Remove from all Brevo lists
  await removeFromBrevoLists(event.email);

  console.log('Hard bounce:', event.email, '-', event.reason);
}

async function handleSoftBounce(event: WebhookPayload & { reason?: string }) {
  // Log soft bounce but don't remove contact
  await logSoftBounce(event.email, event.reason);

  // Retry later (Brevo handles this automatically)
  console.log('Soft bounce:', event.email, '-', event.reason);
}

async function handleSpamComplaint(event: WebhookPayload) {
  // Critical: student marked email as spam
  await markAsSpamComplainer(event.email);

  // Immediately unsubscribe and alert team
  await unsubscribeUser(event.email);
  await alertTeam('Spam complaint received', event);
}

async function handleUnsubscribe(event: WebhookPayload) {
  // Respect unsubscribe request
  await unsubscribeUser(event.email);

  // Keep for transactional emails only
  await updateEmailPreferences(event.email, {
    marketing: false,
    transactional: true
  });
}

// Helper functions (implement based on your database)
async function updateEmailStatus(email: string, id: number, status: string) {
  // Update your database
}

async function trackEngagement(email: string, type: string, data: any) {
  // Track in analytics platform
}

async function incrementEngagementScore(email: string, points: number) {
  // Update engagement scoring
}

async function triggerCourseStartSequence(email: string) {
  // Trigger automation or workflow
}

async function markEmailInvalid(email: string, reason?: string) {
  // Mark in database
}

async function removeFromBrevoLists(email: string) {
  // Call Brevo API to remove from lists
}

async function logSoftBounce(email: string, reason?: string) {
  // Log for monitoring
}

async function markAsSpamComplainer(email: string) {
  // Critical flag in database
}

async function unsubscribeUser(email: string) {
  // Handle unsubscribe
}

async function updateEmailPreferences(email: string, prefs: any) {
  // Update preferences
}

async function alertTeam(message: string, data: any) {
  // Send alert to team (Slack, email, etc.)
}

app.listen(3000, () => {
  console.log('Webhook server listening on port 3000');
});
```

### Security Considerations

#### IP Whitelisting
Brevo publishes IP ranges for webhook calls. Whitelist these IPs:
```typescript
const BREVO_IPS = [
  '185.107.232.0/24',
  // Check Brevo documentation for current list
];

function isBrevoIP(clientIP: string): boolean {
  // Implement IP range checking
  return BREVO_IPS.some(range => ipInRange(clientIP, range));
}

app.post('/webhooks/brevo', (req, res, next) => {
  if (!isBrevoIP(req.ip)) {
    return res.status(403).send('Forbidden');
  }
  next();
});
```

#### Basic Authentication
Configure username/password in Brevo dashboard:
```typescript
app.post('/webhooks/brevo', (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).send('Unauthorized');

  const [type, credentials] = auth.split(' ');
  if (type !== 'Basic') return res.status(401).send('Unauthorized');

  const [username, password] = Buffer.from(credentials, 'base64')
    .toString().split(':');

  if (username !== process.env.WEBHOOK_USER ||
      password !== process.env.WEBHOOK_PASS) {
    return res.status(401).send('Unauthorized');
  }

  next();
});
```

#### Signature Verification (Custom Implementation)
```typescript
function verifyWebhookSignature(
  payload: string,
  signature: string,
  secret: string
): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}
```

### Retry Mechanism

Brevo automatically retries failed webhook deliveries. Your endpoint should:
1. **Respond quickly** (< 5 seconds)
2. **Always return 200 OK** (even if processing fails internally)
3. **Process asynchronously** (queue for background processing)
4. **Be idempotent** (handle duplicate events gracefully)

```typescript
import { Queue } from 'bull';

const webhookQueue = new Queue('brevo-webhooks', {
  redis: { port: 6379, host: 'localhost' }
});

app.post('/webhooks/brevo', async (req, res) => {
  // Immediately queue and respond
  await webhookQueue.add('process', req.body, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 }
  });

  res.status(200).send('OK');
});

// Process in background
webhookQueue.process('process', async (job) => {
  const event = job.data;
  await processWebhookEvent(event);
});
```

### Important Notes

**Timezone Handling:**
- `ts_epoch`, `ts_event`: UTC timezone
- `date`: CET/CEST timezone
- `ts_sent`, `date_sent` (marketing): Local/UTC varies

**Event Ordering:**
Events may arrive out of order. You might receive "delivered" before "queued". Implement logic to handle this:
```typescript
const eventOrder = {
  'request': 1,
  'delivered': 2,
  'opened': 3,
  'click': 4
};

function isValidTransition(currentState: string, newState: string): boolean {
  return eventOrder[newState] >= eventOrder[currentState];
}
```

**First vs. Subsequent Opens:**
- Enable "First opening" only to track unique opens
- Enable both "First opening" and "Known open" to track all opens

---

## 5. Best Practices

### DNS Setup & Email Authentication

#### SPF (Sender Policy Framework)
**Brevo Users:** No manual SPF setup needed! Brevo manages SPF through the Envelope Sender automatically.

- Don't add `include:spf.sendinblue.com` to your SPF record
- SPF authentication will fail even if added (by design)
- DMARC requires either SPF OR DKIM - you'll pass with DKIM only

#### DKIM (DomainKeys Identified Mail)
**Setup Process:**
1. Go to Brevo dashboard → Senders → Domains
2. Add your domain name
3. Copy provided DNS records (Brevo code + DKIM)
4. Add records to your domain host (GoDaddy, Cloudflare, etc.)
5. Wait 24-48 hours for verification
6. Green checkmark = emails signed with your domain

**DNS Record Format:**
```
Type: TXT
Name: mail._domainkey.yourdomain.com
Value: v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA... (from Brevo)
```

**Verification:**
```bash
dig TXT mail._domainkey.yourdomain.com
```

#### DMARC (Domain-based Message Authentication)
**Why Critical:** Required by Microsoft (Outlook/Hotmail). Emails rejected or marked spam without DMARC.

**Setup DMARC Record:**
```
Type: TXT
Name: _dmarc.yourdomain.com
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com,mailto:dmarc@rua.brevo.com; pct=100; adkim=r; aspf=r
```

**DMARC Policy Levels:**
- `p=none` - Monitor only (start here)
- `p=quarantine` - Send to spam if fails
- `p=reject` - Block delivery if fails (most strict)

**Progressive DMARC Implementation:**
```
Week 1-2:   p=none; pct=100  (Monitor all emails)
Week 3-4:   p=quarantine; pct=10  (Quarantine 10%)
Week 5-6:   p=quarantine; pct=50  (Quarantine 50%)
Week 7+:    p=quarantine; pct=100  (Full enforcement)
```

**If You Already Have DMARC:**
Add Brevo's reporting tag:
```
v=DMARC1; p=quarantine; rua=mailto:your-existing@email.com,mailto:dmarc@rua.brevo.com
```

### Gmail, Yahoo, Microsoft Requirements (2024+)

#### For Bulk Senders (5,000+ emails/day)
**MANDATORY:**
- Set up SPF (Brevo handles this)
- Set up DKIM ✓ (see above)
- Set up DMARC ✓ (see above)
- Domain alignment (from address domain = authenticated domain)
- Keep spam rate < 0.3% (monitor in Gmail Postmaster Tools)
- One-click unsubscribe (Brevo handles this)

#### Domain Alignment
If sending 5,000+ emails/day on dedicated IP:
```typescript
// ✓ CORRECT: Domain matches
sender: {
  email: 'courses@yourlearningplatform.com', // Domain: yourlearningplatform.com
  name: 'Learning Platform'
}
// Authenticated domain in Brevo: yourlearningplatform.com

// ✗ WRONG: Domain mismatch
sender: {
  email: 'noreply@notifications.example.com', // Domain: notifications.example.com
  name: 'Learning Platform'
}
// Authenticated domain in Brevo: yourlearningplatform.com
```

### Deliverability Best Practices

#### 1. Use Double Opt-In
```typescript
async function requestDoubleOptIn(email: string) {
  // Create unconfirmed contact
  await createContact({
    email: email,
    attributes: { EMAIL_CONFIRMED: false },
    listIds: [], // Don't add to marketing lists yet
    emailBlacklisted: true // Block marketing emails
  });

  // Send confirmation email
  await sendTransacEmail({
    templateId: 100, // Confirmation template
    to: [{ email }],
    params: {
      confirmationLink: `https://yourplatform.com/confirm?token=${token}`
    }
  });
}

async function confirmOptIn(email: string) {
  // Update contact
  await updateContact(email, {
    attributes: { EMAIL_CONFIRMED: true },
    listIds: [12], // Add to marketing lists
    emailBlacklisted: false // Enable marketing
  });
}
```

#### 2. Monitor Spam Rates
Use Gmail Postmaster Tools:
1. Add domain to Postmaster Tools
2. Monitor spam rate dashboard
3. Keep rate below 0.3%
4. Investigate spikes immediately

#### 3. Use Custom Domain
```
✗ WRONG: courses@gmail.com
✓ RIGHT: courses@yourlearningplatform.com
```

Benefits:
- Professional appearance
- Better deliverability
- Brand trust
- DKIM/DMARC alignment

#### 4. Warm Up New IPs/Domains
If on dedicated IP, gradually increase volume:
```
Day 1:    100 emails
Day 2:    200 emails
Day 3:    500 emails
Day 4:    1,000 emails
Week 2:   5,000 emails/day
Week 3:   10,000 emails/day
Week 4+:  Full volume
```

#### 5. Segment and Personalize
```typescript
// Generic (low engagement):
subject: "New courses available"
body: "Check out our courses"

// Personalized (high engagement):
subject: "{{ params.name }}, your AI course continues tomorrow"
body: "Hi {{ params.name }}, you're 75% done with {{ params.courseName }}..."
```

#### 6. Clean Your List Regularly
```typescript
async function cleanInactiveContacts() {
  // Find contacts with no engagement in 6 months
  const inactive = await queryContacts({
    where: '(LAST_ACTIVITY,before,6 months ago)~(EMAIL_OPENS_30D,eq,0)'
  });

  // Send re-engagement campaign
  for (const contact of inactive) {
    await sendReengagementEmail(contact.email);
  }

  // After 30 days, remove if still no engagement
  setTimeout(async () => {
    const stillInactive = await checkEngagement(inactive.map(c => c.email));
    for (const email of stillInactive) {
      await deleteContact(email);
    }
  }, 30 * 24 * 60 * 60 * 1000);
}
```

#### 7. Handle Bounces Properly
```typescript
// Hard bounces: Remove immediately
async function handleHardBounce(email: string) {
  await deleteContact(email);
}

// Soft bounces: Retry, then remove
const softBounceCount = new Map<string, number>();

async function handleSoftBounce(email: string) {
  const count = (softBounceCount.get(email) || 0) + 1;
  softBounceCount.set(email, count);

  if (count >= 5) {
    // Too many soft bounces, treat as hard bounce
    await deleteContact(email);
  }
}
```

#### 8. Optimize Send Times
```typescript
// Use timezone and activity data
async function calculateOptimalSendTime(email: string): Promise<Date> {
  const contact = await getContact(email);
  const timezone = contact.attributes.TIMEZONE || 'America/New_York';
  const preferredTime = contact.attributes.PREFERRED_SEND_TIME || '10:00';

  // Calculate next send time in user's timezone
  return calculateNextSendTime(timezone, preferredTime);
}
```

#### 9. Use Proper Email Structure
```html
<!-- ✓ GOOD: Proper HTML structure -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{ params.subject }}</title>
</head>
<body>
  <table width="100%" cellpadding="0" cellspacing="0">
    <!-- Content -->
  </table>
  <p style="font-size: 11px; color: #999;">
    <a href="{{ unsubscribe }}">Unsubscribe</a>
  </p>
</body>
</html>
```

#### 10. Test Before Sending
```typescript
// Preview template with test data
const preview = await transactionalEmailsApi.testTemplate({
  templateId: 56,
  params: {
    studentName: 'Test Student',
    courseName: 'Test Course',
    progress: '50%'
  }
});

// Send test email
await transactionalEmailsApi.sendTestEmail({
  templateId: 56,
  emailTo: ['test@yourcompany.com']
});
```

### Rate Limiting Best Practices

#### Implement Exponential Backoff
```typescript
async function sendWithRetry(
  emailFunc: () => Promise<any>,
  maxRetries: number = 3
): Promise<any> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await emailFunc();
    } catch (error: any) {
      if (error.status === 429) {
        // Rate limit hit
        const retryAfter = error.headers?.['retry-after'];
        const delay = retryAfter
          ? parseInt(retryAfter) * 1000
          : Math.pow(2, i) * 1000; // Exponential: 1s, 2s, 4s

        console.log(`Rate limited. Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        throw error;
      }
    }
  }
  throw new Error('Max retries exceeded');
}

// Usage
await sendWithRetry(() =>
  transactionalEmailsApi.sendTransacEmail({
    templateId: 56,
    to: [{ email: 'student@example.com' }],
    params: { name: 'Jane' }
  })
);
```

#### Batch Operations Efficiently
```typescript
// Process in chunks to respect rate limits
async function batchProcessContacts(contacts: Contact[], batchSize: number = 10) {
  for (let i = 0; i < contacts.length; i += batchSize) {
    const batch = contacts.slice(i, i + batchSize);

    // Process batch
    await Promise.all(batch.map(contact =>
      updateContact(contact.email, contact.attributes)
    ));

    // Rate limit: 10 requests/second
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}
```

#### Use Webhooks Instead of Polling
```typescript
// ✗ WRONG: Poll for email statistics (hits rate limits)
setInterval(async () => {
  const stats = await getEmailStats(); // Hits rate limits!
}, 5000);

// ✓ RIGHT: Use webhooks for real-time updates
app.post('/webhooks/brevo', (req, res) => {
  handleEmailEvent(req.body); // Real-time, no API calls
  res.status(200).send('OK');
});
```

### Security Best Practices

#### 1. Store API Keys Securely
```typescript
// ✗ WRONG: Hardcoded API key
const apiKey = 'xkeysib-123456789abcdef';

// ✓ RIGHT: Environment variables
const apiKey = process.env.BREVO_API_KEY!;

// Use .env file (never commit to git)
BREVO_API_KEY=xkeysib-your-actual-key-here
```

#### 2. Use Role-Based Access Control
```typescript
// Limit API key permissions in Brevo dashboard
// Create separate keys for different purposes:
// - Marketing key: Campaign management only
// - Transactional key: Send emails only
// - Analytics key: Read-only statistics
```

#### 3. Rotate API Keys Regularly
```typescript
// Implement key rotation every 90 days
const keyAge = Date.now() - API_KEY_CREATED_AT;
const maxAge = 90 * 24 * 60 * 60 * 1000; // 90 days

if (keyAge > maxAge) {
  console.warn('API key is older than 90 days. Consider rotating.');
}
```

#### 4. Encrypt Custom Data
```typescript
import crypto from 'crypto';

function encryptCustomData(data: object, secret: string): string {
  const json = JSON.stringify(data);
  const cipher = crypto.createCipher('aes-256-cbc', secret);
  let encrypted = cipher.update(json, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

// Send with encrypted custom data
await sendTransacEmail({
  templateId: 56,
  to: [{ email: 'student@example.com' }],
  headers: {
    'X-Mailin-custom': encryptCustomData({
      user_id: 12345,
      course_id: 'ai-101'
    }, process.env.ENCRYPTION_SECRET!)
  }
});
```

#### 5. Implement Request Signing
```typescript
function signRequest(payload: string, secret: string): string {
  return crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
}

// Include signature in custom header
const payload = JSON.stringify(emailData);
const signature = signRequest(payload, process.env.SIGNING_SECRET!);

await sendTransacEmail({
  ...emailData,
  headers: {
    'X-Signature': signature
  }
});
```

### Monitoring & Alerting

#### Track Key Metrics
```typescript
const metrics = {
  // Deliverability
  deliveryRate: 0.99,        // Target: > 98%
  bounceRate: 0.02,          // Target: < 3%
  spamComplaintRate: 0.001,  // Target: < 0.1%

  // Engagement
  openRate: 0.25,            // Benchmark: 20-30%
  clickRate: 0.05,           // Benchmark: 2-5%
  unsubscribeRate: 0.002,    // Target: < 0.5%

  // Performance
  avgDeliveryTime: 2.5,      // seconds
  webhookLatency: 0.8,       // seconds
  apiLatency: 0.3            // seconds
};

// Alert if metrics degrade
if (metrics.deliveryRate < 0.95) {
  await alertTeam('Delivery rate dropped below 95%');
}

if (metrics.spamComplaintRate > 0.003) {
  await alertTeam('Spam complaint rate exceeded 0.3%!');
}
```

#### Log All Operations
```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'brevo-error.log', level: 'error' }),
    new winston.transports.File({ filename: 'brevo-combined.log' })
  ]
});

async function sendEmailWithLogging(emailData: any) {
  logger.info('Sending email', {
    to: emailData.to[0].email,
    template: emailData.templateId
  });

  try {
    const result = await transactionalEmailsApi.sendTransacEmail(emailData);
    logger.info('Email sent successfully', {
      messageId: result.messageId,
      to: emailData.to[0].email
    });
    return result;
  } catch (error: any) {
    logger.error('Email send failed', {
      error: error.message,
      to: emailData.to[0].email,
      statusCode: error.status
    });
    throw error;
  }
}
```

---

## 6. Learning Platform Implementation Checklist

### Phase 1: Foundation (Week 1)
- [ ] Create Brevo account and verify domain
- [ ] Set up DKIM authentication
- [ ] Set up DMARC record
- [ ] Generate API keys (transactional, marketing, analytics)
- [ ] Install `@getbrevo/brevo` npm package
- [ ] Create basic transactional email templates (welcome, confirmation)
- [ ] Implement webhook endpoint
- [ ] Test email sending in development

### Phase 2: Contact Management (Week 2)
- [ ] Define custom contact attributes for learning platform
- [ ] Create contact lists (by course, engagement level, subscription tier)
- [ ] Implement double opt-in flow
- [ ] Build contact creation/update logic
- [ ] Set up segmentation for targeted campaigns
- [ ] Implement bounce handling
- [ ] Create re-engagement automation

### Phase 3: Automation (Week 3)
- [ ] Onboarding email sequence (Day 0, 1, 3, 7)
- [ ] Course completion nudges (progress-based triggers)
- [ ] Abandoned cart recovery (if applicable)
- [ ] Inactive student re-engagement
- [ ] Weekly progress reports
- [ ] Certificate delivery automation
- [ ] Upsell campaigns for high-engagement students

### Phase 4: Monitoring & Optimization (Week 4)
- [ ] Set up Gmail Postmaster Tools
- [ ] Implement comprehensive webhook processing
- [ ] Build engagement tracking dashboard
- [ ] Set up alerting for deliverability issues
- [ ] Monitor spam complaint rates
- [ ] A/B test email subject lines
- [ ] Optimize send times based on user timezone
- [ ] Clean inactive contacts monthly

### Phase 5: Advanced Features (Ongoing)
- [ ] Implement Brevo tracker for ecommerce events
- [ ] Advanced segmentation with AI (Aura)
- [ ] Multi-language email support
- [ ] SMS notifications for critical events
- [ ] Dynamic content based on learning style
- [ ] Predictive churn prevention campaigns
- [ ] Referral program automation

---

## 7. Code Examples Summary

### Complete Node.js Integration Example

```typescript
// src/email/brevo-client.ts
import {
  TransactionalEmailsApi,
  TransactionalEmailsApiApiKeys,
  ContactsApi,
  ContactsApiApiKeys
} from '@getbrevo/brevo';

export class BrevoClient {
  private transactionalApi: TransactionalEmailsApi;
  private contactsApi: ContactsApi;

  constructor(apiKey: string) {
    // Initialize transactional emails API
    this.transactionalApi = new TransactionalEmailsApi();
    this.transactionalApi.setApiKey(
      TransactionalEmailsApiApiKeys.apiKey,
      apiKey
    );

    // Initialize contacts API
    this.contactsApi = new ContactsApi();
    this.contactsApi.setApiKey(
      ContactsApiApiKeys.apiKey,
      apiKey
    );
  }

  // Send welcome email
  async sendWelcomeEmail(email: string, name: string, courseName: string) {
    return this.transactionalApi.sendTransacEmail({
      sender: { email: 'courses@platform.com', name: 'Learning Platform' },
      to: [{ email, name }],
      templateId: 1,
      params: { name, courseName }
    });
  }

  // Create student contact
  async createStudent(email: string, attributes: any, listIds: number[]) {
    return this.contactsApi.createContact({
      email,
      attributes,
      listIds,
      updateEnabled: true
    });
  }

  // Update progress
  async updateStudentProgress(email: string, progress: number) {
    return this.contactsApi.updateContact(email, {
      attributes: {
        COURSE_PROGRESS: progress,
        LAST_ACTIVITY: new Date().toISOString()
      }
    });
  }
}

// Usage
const brevo = new BrevoClient(process.env.BREVO_API_KEY!);

// Send welcome email
await brevo.sendWelcomeEmail(
  'student@example.com',
  'Jane Student',
  'AI Fundamentals'
);

// Create contact
await brevo.createStudent(
  'student@example.com',
  {
    FIRSTNAME: 'Jane',
    LASTNAME: 'Student',
    ENROLLMENT_DATE: '2025-12-02',
    SUBSCRIPTION_TIER: 'Premium'
  },
  [12, 34] // List IDs
);

// Update progress
await brevo.updateStudentProgress('student@example.com', 75);
```

---

## 8. API Reference Quick Links

### Official Documentation
- **Main Developer Portal:** https://developers.brevo.com/
- **API Reference:** https://developers.brevo.com/reference/getting-started-1
- **Node.js SDK:** https://github.com/getbrevo/brevo-node

### Key Endpoints
- **Send Transactional Email:** https://developers.brevo.com/docs/send-a-transactional-email
- **Batch Send:** https://developers.brevo.com/docs/batch-send-transactional-emails
- **Create Contact:** https://developers.brevo.com/reference/createcontact
- **Update Contact:** https://developers.brevo.com/reference/updatecontact
- **Get Lists:** https://developers.brevo.com/reference/getlists
- **Webhooks Guide:** https://developers.brevo.com/docs/how-to-use-webhooks
- **Transactional Webhooks:** https://developers.brevo.com/docs/transactional-webhooks
- **Marketing Webhooks:** https://developers.brevo.com/docs/marketing-webhooks

### Support Resources
- **Help Center:** https://help.brevo.com/
- **API Limits:** https://developers.brevo.com/docs/api-limits
- **Platform Quotas:** https://developers.brevo.com/docs/platform-quotas
- **Changelog:** https://developers.brevo.com/changelog

---

## 9. Important 2025 Changes

### Event Retention Policy (Effective Jan 1, 2025)
- Events older than 24 months will be automatically deleted
- Accounts with 10+ million events affected
- Download monthly reports to preserve historical data
- No changes for accounts under 10 million events

### Dynamic Lists Deprecation (Effective Jan 1, 2025)
- Dynamic lists convert to static lists
- No longer auto-updated
- Use segments for dynamic filtering instead
- Existing lists remain accessible but frozen

### Authentication Requirements (Since Feb 2024)
- Gmail: SPF + DKIM required for 5,000+ emails/day
- Yahoo: Similar requirements
- Microsoft: DMARC mandatory or emails marked as spam
- One-click unsubscribe required (Brevo handles automatically)

---

## Sources

### Transactional Email API
- [Send a transactional email](https://developers.brevo.com/docs/send-a-transactional-email)
- [Batch send customised transactional emails](https://developers.brevo.com/docs/batch-send-transactional-emails)
- [Schedule transactional emails](https://developers.brevo.com/docs/schedule-batch-sendings)
- [How to Send Transactional Emails with Brevo API in Node.js](https://www.suprsend.com/post/how-to-send-transactional-emails-with-brevo-api-in-node-js)
- [Brevo Node.js GitHub](https://github.com/getbrevo/brevo-node)

### Contact Management
- [Create a contact](https://developers.brevo.com/reference/createcontact)
- [Import your contacts to Brevo](https://developers.brevo.com/docs/synchronise-contact-lists)
- [About contact attributes](https://help.brevo.com/hc/en-us/articles/10582214160274-About-contact-attributes)
- [Create and manage custom contact attributes](https://help.brevo.com/hc/en-us/articles/10617359589906-Create-and-manage-custom-contact-attributes)

### Segmentation
- [Examples of segments](https://help.brevo.com/hc/en-us/articles/4407116794002-Examples-of-segments)
- [Create a segment to filter your contacts](https://help.brevo.com/hc/en-us/articles/7943906808594-Create-a-segment-to-filter-your-contacts)
- [About segments](https://help.brevo.com/hc/en-us/articles/360021703959-About-segments)

### Email Automation
- [Available triggers, actions, and rules in an automation](https://help.brevo.com/hc/en-us/articles/15445989568402-Available-triggers-actions-and-rules-in-an-automation)
- [Getting started with Automations](https://help.brevo.com/hc/en-us/articles/14611647354002-Getting-started-with-Automations)
- [Use a trigger to start an automation](https://help.brevo.com/hc/en-us/articles/21203352470034-Use-a-trigger-to-start-an-automation)

### Webhooks
- [Getting started with webhooks](https://developers.brevo.com/docs/how-to-use-webhooks)
- [Transactional webhooks](https://developers.brevo.com/docs/transactional-webhooks)
- [Marketing webhooks](https://developers.brevo.com/docs/marketing-webhooks)

### Authentication & Deliverability
- [What are SPF, DKIM, and DMARC?](https://www.brevo.com/blog/understanding-spf-dkim-dmarc/)
- [Comply with Gmail, Yahoo, and Microsoft's requirements](https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders)
- [How to configure SPF, DKIM, and DMARC records for Brevo](https://dmarcreport.com/blog/how-to-configure-spf-dkim-and-dmarc-records-for-brevo/)
- [An Email Marketer's Guide to Email Authentication](https://www.brevo.com/blog/email-authentication/)

### API Rate Limits
- [API rate limits](https://developers.brevo.com/docs/api-limits)
- [Platform quotas](https://developers.brevo.com/docs/platform-quotas)
- [About API rate limits in Brevo](https://docs.supermetrics.com/docs/about-api-rate-limits-in-brevo)

### Main Portal
- [Brevo Developer Portal](https://developers.brevo.com/)
- [API Reference](https://developers.brevo.com/reference/getting-started-1)
