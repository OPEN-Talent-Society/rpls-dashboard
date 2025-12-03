# 8. Platform REST API

## 8.1 API Overview

The AI Enablement Academy platform provides a comprehensive REST API for integrations, automations, and custom client applications.

### Base Configuration

```
Base URL: https://api.aienablement.academy/v1
Authentication: Bearer token (API keys)
Rate Limiting: Tiered by plan (see section 8.8)
Response Format: JSON
API Version: v1 (January 2025)
```

### Design Principles

- **RESTful**: Standard HTTP verbs (GET, POST, PUT, DELETE)
- **Versioned**: API version in URL path for stability
- **Stateless**: No server-side session state
- **Idempotent**: Safe retry behavior for mutations
- **Paginated**: Cursor-based pagination for large result sets
- **Filtered**: Query parameters for filtering and searching
- **Sorted**: Configurable sort orders

### Standard Headers

```http
# Request headers
Authorization: Bearer sk_live_xxx
Content-Type: application/json
Accept: application/json
X-API-Version: v1
X-Idempotency-Key: uuid (for POST/PUT/DELETE)

# Response headers
X-RateLimit-Limit: 600
X-RateLimit-Remaining: 599
X-RateLimit-Reset: 1705315800
X-Request-ID: req_abc123xyz
```

---

## 8.2 Authentication

### API Key Creation (Admin Only)

```typescript
POST /api/admin/api-keys

// Request
{
  "name": "n8n Integration",
  "scopes": ["enrollments:read", "webhooks:manage"],
  "expiresAt": "2025-12-31T23:59:59Z", // Optional
  "metadata": {
    "integration": "n8n",
    "environment": "production"
  }
}

// Response (201 Created)
{
  "id": "key_abc123",
  "secret": "sk_live_xxx", // Only shown once - store securely!
  "name": "n8n Integration",
  "scopes": ["enrollments:read", "webhooks:manage"],
  "expiresAt": "2025-12-31T23:59:59Z",
  "createdAt": "2025-01-15T10:00:00Z",
  "lastUsedAt": null,
  "metadata": {
    "integration": "n8n",
    "environment": "production"
  }
}
```

### Using API Keys

```http
Authorization: Bearer sk_live_xxx
```

### Key Management

```typescript
// List API keys (admin)
GET /api/admin/api-keys
Response: {
  "keys": [
    {
      "id": "key_abc123",
      "name": "n8n Integration",
      "scopes": ["enrollments:read"],
      "lastUsedAt": "2025-01-15T12:30:00Z",
      "createdAt": "2025-01-15T10:00:00Z"
      // secret is never returned after creation
    }
  ]
}

// Revoke API key (admin)
DELETE /api/admin/api-keys/:id
Response: 204 No Content

// Rotate API key (admin)
POST /api/admin/api-keys/:id/rotate
Response: {
  "id": "key_abc123",
  "secret": "sk_live_yyy", // New secret - only shown once!
  "rotatedAt": "2025-01-20T14:00:00Z"
}
```

### Available Scopes

| Scope | Description |
|-------|-------------|
| `enrollments:read` | View enrollments |
| `enrollments:write` | Create/modify enrollments |
| `cohorts:read` | View cohort information |
| `cohorts:write` | Create/modify cohorts (admin) |
| `materials:read` | Access enablement kit materials |
| `bookings:read` | View office hours bookings |
| `bookings:write` | Create/cancel bookings |
| `chat:write` | Create chat conversations |
| `webhooks:manage` | Manage webhook subscriptions |
| `certificates:read` | View certificates |
| `certificates:issue` | Issue certificates (admin) |
| `admin:courses` | Full course management |
| `admin:cohorts` | Full cohort management |
| `admin:enrollments` | Full enrollment management |
| `admin:organizations` | Organization management |
| `admin:webhooks` | Full webhook management |
| `admin:analytics` | Access analytics data |

---

## 8.3 Public Endpoints (No Authentication)

### List Published Courses

```typescript
GET /courses

// Query parameters
?status=published          // Filter by status
&tier=standard            // Filter by tier (free, standard, premium)
&category=ai-foundations  // Filter by category
&page=1                   // Pagination (cursor-based)
&limit=20                 // Results per page (max 100)

// Response (200 OK)
{
  "courses": [
    {
      "id": "crs_abc123",
      "slug": "ai-prompt-engineering",
      "title": "AI Prompt Engineering Fundamentals",
      "tagline": "Master the art of communicating with AI",
      "category": "ai-foundations",
      "tier": "standard",
      "format": "intensive-2day",
      "duration": "2 days",
      "price": {
        "amount": 49900, // cents
        "currency": "USD",
        "display": "$499"
      },
      "upcomingCohorts": 3,
      "nextCohortStartDate": "2025-02-15T09:00:00Z",
      "totalEnrollments": 1247,
      "averageRating": 4.8,
      "publishedAt": "2024-11-01T00:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": true,
    "nextCursor": "crs_xyz789",
    "limit": 20
  }
}
```

### Get Course Detail

```typescript
GET /courses/:slug

// Response (200 OK)
{
  "id": "crs_abc123",
  "slug": "ai-prompt-engineering",
  "title": "AI Prompt Engineering Fundamentals",
  "tagline": "Master the art of communicating with AI",
  "description": "Full course description...",
  "category": "ai-foundations",
  "tier": "standard",
  "format": "intensive-2day",
  "duration": "2 days",
  "learningOutcomes": [
    "Craft effective prompts for various AI models",
    "Understand AI limitations and capabilities",
    "Build systematic prompt engineering workflows"
  ],
  "price": {
    "amount": 49900,
    "currency": "USD",
    "display": "$499"
  },
  "upcomingCohorts": [
    {
      "id": "coh_123",
      "startDate": "2025-02-15T09:00:00Z",
      "endDate": "2025-02-16T17:00:00Z",
      "timezone": "America/New_York",
      "availableSeats": 12,
      "maxCapacity": 25,
      "facilitator": {
        "name": "Dr. Sarah Chen",
        "avatar": "https://cdn.aienablement.academy/facilitators/sarah.jpg"
      }
    }
  ],
  "curriculum": {
    "modules": [
      {
        "title": "Foundations of Prompt Engineering",
        "topics": ["AI Model Basics", "Prompt Anatomy", "Common Patterns"]
      }
    ]
  },
  "testimonials": [
    {
      "author": "Alex Johnson",
      "role": "Product Manager",
      "rating": 5,
      "text": "Transformed how I work with AI...",
      "verifiedEnrollment": true
    }
  ],
  "publishedAt": "2024-11-01T00:00:00Z"
}
```

### Verify Certificate

```typescript
GET /certificates/:verificationCode/verify

// Example
GET /certificates/CERT-2025-ABC123/verify

// Response (200 OK)
{
  "valid": true,
  "certificate": {
    "id": "cert_xyz789",
    "verificationCode": "CERT-2025-ABC123",
    "recipient": {
      "name": "Jane Doe",
      "email": "jane@example.com" // Masked: j***@example.com
    },
    "course": {
      "title": "AI Prompt Engineering Fundamentals",
      "slug": "ai-prompt-engineering"
    },
    "cohort": {
      "startDate": "2025-01-15T09:00:00Z",
      "endDate": "2025-01-16T17:00:00Z"
    },
    "issuedAt": "2025-01-16T18:00:00Z",
    "expiresAt": null, // null = never expires
    "credentialUrl": "https://credentials.aienablement.academy/CERT-2025-ABC123"
  }
}

// Invalid certificate (404 Not Found)
{
  "valid": false,
  "error": {
    "code": "CERTIFICATE_NOT_FOUND",
    "message": "Certificate not found or has been revoked"
  }
}
```

---

## 8.4 Authenticated Endpoints

### Enrollments

#### List User's Enrollments

```typescript
GET /enrollments
Scopes: enrollments:read

// Query parameters
?status=active            // Filter by status (active, completed, refunded)
?cohortId=coh_123        // Filter by cohort
?courseId=crs_abc        // Filter by course
&page=1
&limit=20

// Response (200 OK)
{
  "enrollments": [
    {
      "id": "enr_xyz789",
      "status": "active",
      "course": {
        "id": "crs_abc123",
        "title": "AI Prompt Engineering Fundamentals",
        "slug": "ai-prompt-engineering"
      },
      "cohort": {
        "id": "coh_123",
        "startDate": "2025-02-15T09:00:00Z",
        "endDate": "2025-02-16T17:00:00Z",
        "timezone": "America/New_York"
      },
      "enrolledAt": "2025-01-10T14:30:00Z",
      "completedAt": null,
      "progress": {
        "materialsAccessed": 3,
        "totalMaterials": 12,
        "percentComplete": 25
      }
    }
  ],
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}
```

#### Get Enrollment Detail

```typescript
GET /enrollments/:id
Scopes: enrollments:read

// Response (200 OK)
{
  "id": "enr_xyz789",
  "status": "active",
  "course": {
    "id": "crs_abc123",
    "title": "AI Prompt Engineering Fundamentals",
    "slug": "ai-prompt-engineering",
    "format": "intensive-2day"
  },
  "cohort": {
    "id": "coh_123",
    "startDate": "2025-02-15T09:00:00Z",
    "endDate": "2025-02-16T17:00:00Z",
    "timezone": "America/New_York",
    "facilitator": {
      "name": "Dr. Sarah Chen",
      "avatar": "https://cdn.aienablement.academy/facilitators/sarah.jpg"
    },
    "meetingLink": "https://zoom.us/j/123456789", // Available 24h before start
    "slackChannel": "#cohort-feb-2025"
  },
  "payment": {
    "amount": 49900,
    "currency": "USD",
    "paidAt": "2025-01-10T14:30:00Z",
    "method": "stripe",
    "receiptUrl": "https://pay.stripe.com/receipts/xyz"
  },
  "progress": {
    "materialsAccessed": 3,
    "totalMaterials": 12,
    "percentComplete": 25,
    "lastAccessedAt": "2025-01-12T10:00:00Z"
  },
  "certificate": null, // Issued after completion
  "enrolledAt": "2025-01-10T14:30:00Z",
  "completedAt": null
}
```

### Cohorts

#### Get Cohort Detail

```typescript
GET /cohorts/:id
Scopes: cohorts:read
Requirement: User must be enrolled

// Response (200 OK)
{
  "id": "coh_123",
  "course": {
    "id": "crs_abc123",
    "title": "AI Prompt Engineering Fundamentals",
    "slug": "ai-prompt-engineering"
  },
  "startDate": "2025-02-15T09:00:00Z",
  "endDate": "2025-02-16T17:00:00Z",
  "timezone": "America/New_York",
  "schedule": [
    {
      "day": 1,
      "date": "2025-02-15",
      "sessions": [
        {
          "time": "09:00-12:00",
          "title": "Foundations & Frameworks",
          "type": "live-instruction"
        },
        {
          "time": "13:00-17:00",
          "title": "Hands-on Practice",
          "type": "workshop"
        }
      ]
    }
  ],
  "facilitator": {
    "id": "fac_456",
    "name": "Dr. Sarah Chen",
    "bio": "Former AI researcher at MIT...",
    "avatar": "https://cdn.aienablement.academy/facilitators/sarah.jpg",
    "credentials": ["PhD AI", "10+ years teaching"]
  },
  "capacity": {
    "enrolled": 18,
    "max": 25,
    "available": 7
  },
  "meetingLink": "https://zoom.us/j/123456789",
  "slackChannel": "#cohort-feb-2025",
  "status": "scheduled"
}
```

#### Get Cohort Materials

```typescript
GET /cohorts/:id/materials
Scopes: materials:read
Requirement: User must be enrolled

// Response (200 OK)
{
  "materials": [
    {
      "id": "mat_123",
      "title": "Pre-Work: AI Fundamentals Reading",
      "type": "document",
      "category": "pre-work",
      "url": "https://cdn.aienablement.academy/materials/mat_123.pdf",
      "size": 1024000, // bytes
      "accessedAt": "2025-01-12T10:00:00Z",
      "required": true
    },
    {
      "id": "mat_124",
      "title": "Day 1 Slides",
      "type": "presentation",
      "category": "session-materials",
      "url": "https://cdn.aienablement.academy/materials/mat_124.pdf",
      "size": 2048000,
      "accessedAt": null,
      "required": false,
      "availableAt": "2025-02-15T09:00:00Z" // Locked until cohort starts
    },
    {
      "id": "mat_125",
      "title": "Practice Exercises",
      "type": "interactive",
      "category": "exercises",
      "url": "https://app.aienablement.academy/exercises/mat_125",
      "accessedAt": null,
      "required": true
    }
  ],
  "categories": ["pre-work", "session-materials", "exercises", "resources"]
}
```

### Office Hours

#### Get Availability

```typescript
GET /office-hours/availability
Scopes: bookings:read

// Query parameters
?facilitatorId=fac_456   // Optional: specific facilitator
&startDate=2025-02-01    // ISO date
&endDate=2025-02-28
&timezone=America/New_York

// Response (200 OK)
{
  "availability": [
    {
      "facilitatorId": "fac_456",
      "facilitatorName": "Dr. Sarah Chen",
      "slots": [
        {
          "id": "slot_abc",
          "startTime": "2025-02-05T14:00:00Z",
          "endTime": "2025-02-05T14:30:00Z",
          "duration": 30, // minutes
          "available": true
        },
        {
          "id": "slot_def",
          "startTime": "2025-02-05T15:00:00Z",
          "endTime": "2025-02-05T15:30:00Z",
          "duration": 30,
          "available": false // Already booked
        }
      ]
    }
  ],
  "timezone": "America/New_York"
}
```

#### Create Booking

```typescript
POST /office-hours/book
Scopes: bookings:write

// Request
{
  "slotId": "slot_abc",
  "topic": "Struggling with multi-step prompts",
  "context": "I'm working on a customer service chatbot and having trouble with context retention across multiple exchanges.",
  "preferredPlatform": "zoom" // or "google-meet"
}

// Response (201 Created)
{
  "id": "book_xyz",
  "facilitator": {
    "name": "Dr. Sarah Chen",
    "avatar": "https://cdn.aienablement.academy/facilitators/sarah.jpg"
  },
  "startTime": "2025-02-05T14:00:00Z",
  "endTime": "2025-02-05T14:30:00Z",
  "duration": 30,
  "topic": "Struggling with multi-step prompts",
  "meetingLink": "https://zoom.us/j/987654321",
  "calendarInvite": "https://calendar.google.com/...",
  "status": "confirmed",
  "bookedAt": "2025-01-15T10:30:00Z"
}
```

#### Cancel Booking

```typescript
DELETE /office-hours/bookings/:id
Scopes: bookings:write

// Response (204 No Content)
```

### Chat

#### Create Conversation

```typescript
POST /chat/conversations
Scopes: chat:write

// Request
{
  "context": {
    "enrollmentId": "enr_xyz789", // Optional: link to enrollment
    "topic": "Prompt optimization"
  }
}

// Response (201 Created)
{
  "id": "conv_abc123",
  "createdAt": "2025-01-15T10:30:00Z",
  "context": {
    "enrollmentId": "enr_xyz789",
    "topic": "Prompt optimization"
  }
}
```

#### Send Message (Streaming)

```typescript
POST /chat/conversations/:id/messages
Scopes: chat:write
Content-Type: application/json
Accept: text/event-stream

// Request
{
  "message": "How do I improve context retention in multi-turn conversations?",
  "attachments": [] // Optional: file uploads
}

// Response (Server-Sent Events)
data: {"type":"chunk","content":"To improve context"}
data: {"type":"chunk","content":" retention, you can"}
data: {"type":"chunk","content":" use these strategies:\n\n"}
data: {"type":"chunk","content":"1. **Explicit context"}
data: {"type":"chunk","content":" summarization**"}
data: {"type":"done","messageId":"msg_xyz","tokens":247}

// Message history
GET /chat/conversations/:id/messages
Response: {
  "messages": [
    {
      "id": "msg_xyz",
      "role": "user",
      "content": "How do I improve context retention?",
      "createdAt": "2025-01-15T10:30:00Z"
    },
    {
      "id": "msg_abc",
      "role": "assistant",
      "content": "To improve context retention, you can use these strategies...",
      "createdAt": "2025-01-15T10:30:15Z",
      "tokens": 247
    }
  ]
}
```

---

## 8.5 Admin Endpoints

### Courses

```typescript
// List all courses (including drafts)
GET /admin/courses
Scopes: admin:courses

?status=all|draft|published|archived
&tier=free|standard|premium
&page=1&limit=50

// Create course
POST /admin/courses
Scopes: admin:courses

Request: {
  "slug": "ai-prompt-engineering",
  "title": "AI Prompt Engineering Fundamentals",
  "tagline": "Master the art of communicating with AI",
  "description": "Full description...",
  "category": "ai-foundations",
  "tier": "standard",
  "format": "intensive-2day",
  "duration": "2 days",
  "price": {
    "amount": 49900,
    "currency": "USD"
  },
  "curriculum": {...},
  "status": "draft"
}

Response: (201 Created) {...course object...}

// Update course
PUT /admin/courses/:id
Scopes: admin:courses

Request: {
  "title": "Updated Title",
  "price": {"amount": 59900, "currency": "USD"}
}

Response: (200 OK) {...updated course...}

// Delete course (soft delete)
DELETE /admin/courses/:id
Scopes: admin:courses

Response: (204 No Content)
```

### Cohorts

```typescript
// List cohorts
GET /admin/cohorts
Scopes: admin:cohorts

?courseId=crs_abc
&status=scheduled|active|completed|cancelled
&startDate=2025-02-01
&endDate=2025-02-28
&page=1&limit=50

// Create cohort
POST /admin/cohorts
Scopes: admin:cohorts

Request: {
  "courseId": "crs_abc123",
  "startDate": "2025-02-15T09:00:00Z",
  "endDate": "2025-02-16T17:00:00Z",
  "timezone": "America/New_York",
  "facilitatorId": "fac_456",
  "maxCapacity": 25,
  "meetingLink": "https://zoom.us/j/123456789",
  "slackChannel": "#cohort-feb-2025"
}

Response: (201 Created) {...cohort object...}

// Update cohort
PUT /admin/cohorts/:id
Scopes: admin:cohorts

Request: {
  "maxCapacity": 30,
  "status": "active"
}

Response: (200 OK) {...updated cohort...}

// Delete cohort
DELETE /admin/cohorts/:id
Scopes: admin:cohorts
Note: Only allowed if no enrollments exist

Response: (204 No Content)
```

### Enrollments

```typescript
// List all enrollments
GET /admin/enrollments
Scopes: admin:enrollments

?userId=usr_123
&cohortId=coh_456
&courseId=crs_789
&status=active|completed|refunded
&enrolledAfter=2025-01-01
&page=1&limit=50

// Create manual enrollment (B2B)
POST /admin/enrollments
Scopes: admin:enrollments

Request: {
  "userId": "usr_123",
  "cohortId": "coh_456",
  "source": "b2b-agreement",
  "organizationId": "org_abc",
  "skipPayment": true, // For B2B agreements
  "metadata": {
    "contractId": "contract_xyz",
    "seats": 5
  }
}

Response: (201 Created) {...enrollment object...}

// Update enrollment
PUT /admin/enrollments/:id
Scopes: admin:enrollments

Request: {
  "status": "completed",
  "completedAt": "2025-02-16T17:00:00Z",
  "issueCertificate": true
}

Response: (200 OK) {...updated enrollment...}

// Refund enrollment
POST /admin/enrollments/:id/refund
Scopes: admin:enrollments

Request: {
  "reason": "Customer request",
  "amount": 49900, // Full or partial refund
  "notifyUser": true
}

Response: (200 OK) {
  "refundId": "ref_xyz",
  "amount": 49900,
  "status": "processing",
  "estimatedAt": "2025-01-20T00:00:00Z"
}
```

### Organizations

```typescript
// List organizations
GET /admin/organizations
Scopes: admin:organizations

?page=1&limit=50

// Create organization
POST /admin/organizations
Scopes: admin:organizations

Request: {
  "name": "Acme Corporation",
  "domain": "acme.com", // For SSO
  "plan": "enterprise",
  "seats": 100,
  "billingEmail": "billing@acme.com",
  "metadata": {
    "industry": "technology",
    "size": "500-1000"
  }
}

Response: (201 Created) {...organization object...}

// Update organization
PUT /admin/organizations/:id
Scopes: admin:organizations

Request: {
  "seats": 150,
  "plan": "enterprise-plus"
}

Response: (200 OK) {...updated organization...}

// Send organization invites
POST /admin/organizations/:id/invites
Scopes: admin:organizations

Request: {
  "emails": [
    "user1@acme.com",
    "user2@acme.com"
  ],
  "role": "member", // or "admin"
  "message": "Welcome to our AI enablement program!"
}

Response: (200 OK) {
  "invites": [
    {
      "email": "user1@acme.com",
      "inviteId": "inv_abc",
      "status": "sent"
    },
    {
      "email": "user2@acme.com",
      "inviteId": "inv_def",
      "status": "sent"
    }
  ]
}
```

### Webhooks

```typescript
// List webhooks
GET /admin/webhooks
Scopes: admin:webhooks

Response: {
  "webhooks": [
    {
      "id": "wh_abc123",
      "url": "https://n8n.example.com/webhook/enrollments",
      "events": ["enrollment.created", "enrollment.completed"],
      "status": "active",
      "createdAt": "2025-01-10T00:00:00Z",
      "lastDeliveredAt": "2025-01-15T10:30:00Z"
    }
  ]
}

// Create webhook
POST /admin/webhooks
Scopes: admin:webhooks

Request: {
  "url": "https://n8n.example.com/webhook/enrollments",
  "events": ["enrollment.created", "enrollment.completed"],
  "secret": "whsec_xxx", // For HMAC signature verification
  "metadata": {
    "integration": "n8n",
    "environment": "production"
  }
}

Response: (201 Created) {...webhook object...}

// Update webhook
PUT /admin/webhooks/:id
Scopes: admin:webhooks

Request: {
  "events": ["enrollment.created", "enrollment.completed", "enrollment.refunded"],
  "status": "paused" // or "active"
}

Response: (200 OK) {...updated webhook...}

// Delete webhook
DELETE /admin/webhooks/:id
Scopes: admin:webhooks

Response: (204 No Content)

// List webhook deliveries
GET /admin/webhooks/:id/deliveries
Scopes: admin:webhooks

?status=success|failed|pending
&page=1&limit=50

Response: {
  "deliveries": [
    {
      "id": "del_xyz",
      "eventId": "evt_abc",
      "eventType": "enrollment.created",
      "status": "success",
      "httpStatus": 200,
      "attempts": 1,
      "deliveredAt": "2025-01-15T10:30:00Z",
      "response": "{\"received\":true}"
    },
    {
      "id": "del_uvw",
      "eventId": "evt_def",
      "eventType": "enrollment.completed",
      "status": "failed",
      "httpStatus": 500,
      "attempts": 3,
      "nextRetryAt": "2025-01-15T11:00:00Z",
      "error": "Internal Server Error"
    }
  ]
}

// Retry failed delivery
POST /admin/webhooks/:id/deliveries/:deliveryId/retry
Scopes: admin:webhooks

Response: (200 OK) {
  "id": "del_uvw",
  "status": "pending",
  "scheduledAt": "2025-01-15T10:45:00Z"
}
```

---

## 8.6 Outbound Webhook Events

### Event Types

```typescript
type WebhookEvent =
  // Enrollment lifecycle
  | "enrollment.created"
  | "enrollment.completed"
  | "enrollment.refunded"

  // Cohort lifecycle
  | "cohort.started"
  | "cohort.completed"
  | "cohort.cancelled"

  // Certificates
  | "certificate.issued"
  | "certificate.revoked"

  // Waitlist
  | "waitlist.joined"
  | "waitlist.offered"
  | "waitlist.expired"

  // Payments
  | "payment.received"
  | "payment.refunded"
  | "payment.failed"

  // Office hours
  | "booking.created"
  | "booking.cancelled"
  | "booking.completed"

  // Organizations
  | "organization.member_added"
  | "organization.member_removed";
```

### Webhook Payload Structure

```typescript
// Standard payload format
{
  "id": "evt_abc123",
  "type": "enrollment.created",
  "timestamp": "2025-01-15T10:30:00Z",
  "livemode": true, // false for test events
  "data": {
    // Event-specific data
  },
  "previousAttributes": {} // For update events
}
```

### Event Examples

```typescript
// enrollment.created
{
  "id": "evt_abc123",
  "type": "enrollment.created",
  "timestamp": "2025-01-15T10:30:00Z",
  "livemode": true,
  "data": {
    "enrollmentId": "enr_xyz789",
    "userId": "usr_123",
    "userEmail": "jane@example.com",
    "cohortId": "coh_456",
    "courseId": "crs_abc",
    "courseTitle": "AI Prompt Engineering Fundamentals",
    "cohortStartDate": "2025-02-15T09:00:00Z",
    "amount": 49900,
    "currency": "USD",
    "source": "stripe" // or "b2b", "waitlist-conversion"
  }
}

// enrollment.completed
{
  "id": "evt_def456",
  "type": "enrollment.completed",
  "timestamp": "2025-02-16T17:00:00Z",
  "livemode": true,
  "data": {
    "enrollmentId": "enr_xyz789",
    "userId": "usr_123",
    "userEmail": "jane@example.com",
    "courseTitle": "AI Prompt Engineering Fundamentals",
    "completedAt": "2025-02-16T17:00:00Z",
    "certificateId": "cert_abc",
    "verificationCode": "CERT-2025-ABC123"
  }
}

// certificate.issued
{
  "id": "evt_ghi789",
  "type": "certificate.issued",
  "timestamp": "2025-02-16T18:00:00Z",
  "livemode": true,
  "data": {
    "certificateId": "cert_abc",
    "verificationCode": "CERT-2025-ABC123",
    "userId": "usr_123",
    "userEmail": "jane@example.com",
    "userName": "Jane Doe",
    "courseTitle": "AI Prompt Engineering Fundamentals",
    "cohortStartDate": "2025-02-15T09:00:00Z",
    "cohortEndDate": "2025-02-16T17:00:00Z",
    "credentialUrl": "https://credentials.aienablement.academy/CERT-2025-ABC123"
  }
}

// payment.received
{
  "id": "evt_jkl012",
  "type": "payment.received",
  "timestamp": "2025-01-15T10:30:00Z",
  "livemode": true,
  "data": {
    "paymentId": "pay_xyz",
    "enrollmentId": "enr_xyz789",
    "userId": "usr_123",
    "amount": 49900,
    "currency": "USD",
    "method": "stripe",
    "receiptUrl": "https://pay.stripe.com/receipts/xyz"
  }
}
```

### Webhook Headers

```http
POST https://your-endpoint.com/webhook
Content-Type: application/json
X-Webhook-Signature: sha256=abc123...
X-Webhook-Event: enrollment.created
X-Webhook-Timestamp: 1705315800
X-Webhook-ID: evt_abc123
X-Webhook-Delivery: del_xyz789
```

### Retry Logic

- **Automatic retries**: Failed deliveries are retried with exponential backoff
- **Retry schedule**: 1min, 5min, 15min, 1hr, 6hr, 24hr (6 attempts total)
- **Success criteria**: HTTP 2xx response
- **Timeout**: 30 seconds per attempt
- **Manual retry**: Available via API for failed deliveries

---

## 8.7 HMAC Signature Verification

### Purpose

Webhook signatures prevent unauthorized webhook requests and ensure data integrity.

### Implementation

```typescript
import crypto from "crypto";

/**
 * Verify webhook signature using HMAC SHA-256
 *
 * @param payload - Raw request body as string
 * @param signature - X-Webhook-Signature header value
 * @param secret - Webhook secret from dashboard
 * @param timestamp - X-Webhook-Timestamp header value (Unix timestamp)
 * @returns boolean - True if signature is valid
 */
function verifyWebhookSignature(
  payload: string,
  signature: string,
  secret: string,
  timestamp: number
): boolean {
  // 1. Check timestamp freshness (5 minute window)
  const now = Math.floor(Date.now() / 1000);
  const timeDiff = Math.abs(now - timestamp);

  if (timeDiff > 300) {
    console.error("Webhook timestamp too old or too far in future");
    return false; // Replay attack protection
  }

  // 2. Compute expected signature
  const signedPayload = `${timestamp}.${payload}`;
  const expectedSignature = crypto
    .createHmac("sha256", secret)
    .update(signedPayload, "utf8")
    .digest("hex");

  // 3. Timing-safe comparison (prevents timing attacks)
  const expectedBuffer = Buffer.from(`sha256=${expectedSignature}`);
  const actualBuffer = Buffer.from(signature);

  if (expectedBuffer.length !== actualBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(expectedBuffer, actualBuffer);
}

// Example usage in Express.js
app.post("/webhook", express.raw({type: "application/json"}), (req, res) => {
  const signature = req.headers["x-webhook-signature"];
  const timestamp = parseInt(req.headers["x-webhook-timestamp"], 10);
  const payload = req.body.toString("utf8");
  const secret = process.env.WEBHOOK_SECRET; // From webhook creation

  if (!verifyWebhookSignature(payload, signature, secret, timestamp)) {
    console.error("Invalid webhook signature");
    return res.status(401).json({error: "Invalid signature"});
  }

  // Signature valid - process webhook
  const event = JSON.parse(payload);
  console.log("Received event:", event.type);

  // ... handle event ...

  res.status(200).json({received: true});
});
```

### Security Best Practices

1. **Always verify signatures** - Never trust unverified webhooks
2. **Use timing-safe comparison** - Prevents timing attacks
3. **Check timestamp freshness** - Prevents replay attacks
4. **Store secrets securely** - Use environment variables, not code
5. **Process asynchronously** - Return 200 quickly, process in background
6. **Implement idempotency** - Use event IDs to prevent duplicate processing
7. **Log failures** - Monitor webhook delivery issues

---

## 8.8 Rate Limiting

### Rate Limit Tiers

| Tier | Rate Limit | Burst Allowance | Use Case |
|------|------------|-----------------|----------|
| **Free** | 60 requests/minute | 10 requests | Testing and development |
| **Standard** | 600 requests/minute | 100 requests | Production integrations |
| **Enterprise** | 6000 requests/minute | 1000 requests | High-volume applications |

### Rate Limit Headers

Every API response includes rate limit information:

```http
X-RateLimit-Limit: 600          # Max requests per window
X-RateLimit-Remaining: 599      # Requests remaining
X-RateLimit-Reset: 1705315800   # Unix timestamp when limit resets
X-RateLimit-Window: 60          # Window duration in seconds
```

### Rate Limit Algorithm

- **Token bucket algorithm** with refill
- **Per-API-key** tracking (not per IP)
- **Sliding window** for smooth distribution
- **Burst allowance** for traffic spikes

### Exceeding Rate Limits

```typescript
// Response when rate limit exceeded (429 Too Many Requests)
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Retry after 45 seconds.",
    "retryAfter": 45, // seconds
    "limit": 600,
    "window": 60
  }
}

// Headers
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 600
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1705315845
Retry-After: 45
```

### Best Practices

1. **Respect rate limits** - Check `X-RateLimit-Remaining` header
2. **Implement backoff** - Exponential backoff for retries
3. **Batch requests** - Combine operations when possible
4. **Cache responses** - Reduce duplicate requests
5. **Use webhooks** - Push-based instead of polling

### Rate Limit Handling Example

```typescript
class APIClient {
  private rateLimitRemaining: number = 600;
  private rateLimitReset: number = 0;

  async request(endpoint: string, options: RequestInit) {
    // Check if rate limited
    if (this.rateLimitRemaining === 0) {
      const waitTime = this.rateLimitReset - Date.now();
      if (waitTime > 0) {
        console.log(`Rate limited. Waiting ${waitTime}ms`);
        await this.sleep(waitTime);
      }
    }

    // Make request
    const response = await fetch(endpoint, {
      ...options,
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        ...options.headers
      }
    });

    // Update rate limit state from headers
    this.rateLimitRemaining = parseInt(
      response.headers.get("X-RateLimit-Remaining") || "0"
    );
    this.rateLimitReset = parseInt(
      response.headers.get("X-RateLimit-Reset") || "0"
    ) * 1000;

    if (response.status === 429) {
      const retryAfter = parseInt(
        response.headers.get("Retry-After") || "60"
      ) * 1000;

      console.log(`Rate limited. Retrying after ${retryAfter}ms`);
      await this.sleep(retryAfter);

      // Retry request
      return this.request(endpoint, options);
    }

    return response;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

---

## 8.9 API Performance Requirements

### Response Time Targets

| Endpoint Type | Target | Maximum |
|---------------|--------|---------|
| Read (GET single) | <100ms | <300ms |
| Read (GET list) | <200ms | <500ms |
| Write (POST/PUT) | <300ms | <1000ms |
| Search | <500ms | <1500ms |
| Report generation | Async | N/A |

**Notes:**
- **Target**: Goal for P95 (95th percentile) response time
- **Maximum**: Hard limit for P99 (99th percentile) response time
- **Async operations**: Long-running operations (reports, batch imports) use job queue pattern

### Caching Strategy

#### Static Data Caching
**Skills, Resources, Course Catalogs:**
```http
Cache-Control: public, max-age=3600, stale-while-revalidate=86400
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
```
- **TTL**: 1 hour
- **Stale-while-revalidate**: 24 hours (background refresh)
- **Invalidation**: Manual cache bust on content updates

#### User Data Caching
**User profiles, enrollments, progress:**
```http
Cache-Control: private, max-age=60
```
- **TTL**: 60 seconds (short)
- **Private**: User-specific data, no CDN caching
- **Invalidation**: Automatic on data mutations

#### Analytics Caching
**Dashboard stats, reports:**
```http
Cache-Control: public, max-age=300
```
- **TTL**: 5 minutes
- **Public**: Aggregated data safe for CDN
- **Invalidation**: Time-based expiry only

#### List Endpoints Pagination
**Cursor-based pagination for large datasets:**
```typescript
// Request
GET /api/v1/courses?limit=50&cursor=eyJpZCI6MTIzfQ==

// Response
{
  "data": [...], // 50 items
  "pagination": {
    "nextCursor": "eyJpZCI6MTczfQ==",
    "hasMore": true,
    "limit": 50
  }
}
```
- **Default limit**: 50 items
- **Maximum limit**: 100 items
- **Cursor encoding**: Base64-encoded JSON with sort key

### Rate Limiting (Cross-Reference)

Rate limiting is defined in detail in **Section 8.8**. For performance optimization, note these limits:

| Operation Type | Rate Limit (Standard Tier) |
|----------------|----------------------------|
| **Standard endpoints** | 100 requests/minute |
| **Search endpoints** | 30 requests/minute |
| **Write operations** | 20 requests/minute |
| **AI-powered operations** | 10 requests/minute |

**Best Practices for Performance:**
1. **Batch operations** - Combine multiple writes into single request when possible
2. **Cache aggressively** - Respect `Cache-Control` headers
3. **Use ETags** - Conditional requests reduce bandwidth
4. **Implement cursor pagination** - More efficient than offset-based pagination
5. **Leverage webhooks** - Avoid polling for real-time updates

### Monitoring & Observability

#### Instrumentation

All API endpoints are instrumented with:
- **Request latency tracking** (P50, P95, P99)
- **Error rate monitoring** (4xx, 5xx)
- **Throughput metrics** (requests/second)
- **Cache hit rates** (CDN, application cache)

#### Performance Dashboards

**Real-time dashboards available at:**
- **Public status page**: `https://status.campfire.academy`
- **Admin dashboard**: Detailed metrics for operations team

**Key metrics displayed:**
| Metric | Threshold | Alert Level |
|--------|-----------|-------------|
| **P95 latency** | >500ms | Warning |
| **P99 latency** | >1000ms | Critical |
| **Error rate** | >1% | Warning |
| **Error rate** | >5% | Critical |
| **Uptime** | <99.9% | Critical |

#### Alerting

**Automated alerts triggered when:**
- P95 latency exceeds 500ms for 5+ minutes
- P99 latency exceeds 1000ms for 2+ minutes
- Error rate exceeds 5% for 1+ minute
- Any endpoint returns 503 Service Unavailable

**Alert channels:**
- PagerDuty for critical alerts
- Slack for warnings
- Email for daily summaries

#### Performance Headers

Every API response includes performance metadata:

```http
X-Response-Time: 42ms          # Time to generate response
X-Cache-Status: HIT            # MISS | HIT | BYPASS | EXPIRED
X-Request-ID: req_7Hj3k2Lp9M  # Unique request identifier for tracing
```

**Usage:**
- **X-Response-Time**: Measure perceived latency
- **X-Cache-Status**: Debug caching behavior
- **X-Request-ID**: Reference in support requests for debugging

#### Client-Side Performance Tips

**1. Connection Pooling**
```typescript
// Reuse HTTP connections
const agent = new https.Agent({
  keepAlive: true,
  maxSockets: 50
});

fetch(url, { agent });
```

**2. Request Batching**
```typescript
// Bad: Sequential requests
for (const id of userIds) {
  await fetch(`/api/v1/users/${id}`);
}

// Good: Parallel requests
const promises = userIds.map(id =>
  fetch(`/api/v1/users/${id}`)
);
await Promise.all(promises);

// Better: Batch endpoint (if available)
await fetch('/api/v1/users', {
  method: 'POST',
  body: JSON.stringify({ ids: userIds })
});
```

**3. Conditional Requests**
```typescript
// Store ETag from initial request
const initialResponse = await fetch('/api/v1/courses/123');
const etag = initialResponse.headers.get('ETag');

// Subsequent requests with If-None-Match
const cachedResponse = await fetch('/api/v1/courses/123', {
  headers: { 'If-None-Match': etag }
});

if (cachedResponse.status === 304) {
  console.log('Using cached data');
  // Use locally cached data
} else {
  const freshData = await cachedResponse.json();
  // Update cache with fresh data
}
```

**4. Query Optimization**
```typescript
// Bad: Fetch all fields
GET /api/v1/users/123

// Good: Request only needed fields
GET /api/v1/users/123?fields=id,name,email

// Good: Use includes for related data
GET /api/v1/courses/123?include=instructor,tags
```

### Service Level Objectives (SLOs)

**Availability SLO**: 99.9% uptime (Monthly)
- **Allowed downtime**: 43.8 minutes/month
- **Measurement**: Uptime monitoring from multiple regions

**Latency SLO**: 95% of requests under target latency
- **Read operations**: <200ms
- **Write operations**: <500ms
- **Measurement**: Application Performance Monitoring (APM)

**Error Budget**: 0.1% (1 in 1000 requests)
- **4xx errors**: Counted against client error budget
- **5xx errors**: Counted against server error budget
- **Measurement**: Error tracking and logging

**Support SLO**: Response times
| Priority | First Response | Resolution |
|----------|----------------|------------|
| **P0 (Critical)** | 15 minutes | 4 hours |
| **P1 (High)** | 1 hour | 24 hours |
| **P2 (Medium)** | 4 hours | 3 days |
| **P3 (Low)** | 24 hours | 7 days |

---

## 8.10 Error Responses

### Standard Error Format

```typescript
// All errors follow this structure
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {} // Optional: additional context
  }
}
```

### HTTP Status Codes & Error Codes

| HTTP Status | Error Code | Description | Action |
|-------------|------------|-------------|--------|
| **400** | `VALIDATION_ERROR` | Invalid request body or parameters | Fix request and retry |
| **400** | `INVALID_REQUEST` | Malformed request structure | Check API documentation |
| **401** | `UNAUTHORIZED` | Missing or invalid API key | Check authentication |
| **401** | `INVALID_API_KEY` | API key is invalid or revoked | Regenerate API key |
| **401** | `API_KEY_EXPIRED` | API key has expired | Create new API key |
| **403** | `FORBIDDEN` | Insufficient scopes for operation | Request additional scopes |
| **403** | `SCOPE_REQUIRED` | Specific scope missing | Add required scope to API key |
| **403** | `ENROLLMENT_REQUIRED` | User must be enrolled to access | Enroll in course |
| **404** | `NOT_FOUND` | Resource does not exist | Check resource ID |
| **404** | `COURSE_NOT_FOUND` | Course does not exist | Verify course ID or slug |
| **404** | `COHORT_NOT_FOUND` | Cohort does not exist | Verify cohort ID |
| **404** | `ENROLLMENT_NOT_FOUND` | Enrollment does not exist | Verify enrollment ID |
| **409** | `CONFLICT` | Resource already exists | Use PUT to update |
| **409** | `ALREADY_ENROLLED` | User already enrolled in cohort | Check existing enrollment |
| **409** | `COHORT_FULL` | Cohort has reached capacity | Join waitlist |
| **422** | `UNPROCESSABLE_ENTITY` | Valid syntax but invalid data | Fix data and retry |
| **429** | `RATE_LIMIT_EXCEEDED` | Too many requests | Wait and retry |
| **500** | `INTERNAL_ERROR` | Server error | Retry with backoff |
| **503** | `SERVICE_UNAVAILABLE` | Temporary unavailability | Retry with backoff |

### Error Response Examples

#### Validation Error

```typescript
// Request
POST /admin/courses
{
  "title": "AI Course",
  "price": -100 // Invalid: negative price
}

// Response (400 Bad Request)
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "fields": {
        "price.amount": "Must be a positive integer",
        "slug": "Required field missing"
      }
    }
  }
}
```

#### Authentication Error

```typescript
// Request with invalid API key
GET /enrollments
Authorization: Bearer sk_invalid_xxx

// Response (401 Unauthorized)
{
  "error": {
    "code": "INVALID_API_KEY",
    "message": "The provided API key is invalid or has been revoked"
  }
}
```

#### Permission Error

```typescript
// Request with insufficient scopes
POST /admin/courses
Authorization: Bearer sk_live_xxx
// API key only has "enrollments:read" scope

// Response (403 Forbidden)
{
  "error": {
    "code": "SCOPE_REQUIRED",
    "message": "This operation requires the 'admin:courses' scope",
    "details": {
      "requiredScopes": ["admin:courses"],
      "currentScopes": ["enrollments:read"]
    }
  }
}
```

#### Resource Not Found

```typescript
// Request
GET /enrollments/enr_nonexistent

// Response (404 Not Found)
{
  "error": {
    "code": "ENROLLMENT_NOT_FOUND",
    "message": "Enrollment not found or you don't have permission to access it"
  }
}
```

#### Conflict Error

```typescript
// Request: Enroll user already enrolled
POST /admin/enrollments
{
  "userId": "usr_123",
  "cohortId": "coh_456"
}

// Response (409 Conflict)
{
  "error": {
    "code": "ALREADY_ENROLLED",
    "message": "User is already enrolled in this cohort",
    "details": {
      "existingEnrollmentId": "enr_xyz789"
    }
  }
}
```

#### Rate Limit Error

```typescript
// Response (429 Too Many Requests)
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Retry after 45 seconds.",
    "retryAfter": 45,
    "details": {
      "limit": 600,
      "window": 60,
      "resetAt": "2025-01-15T10:45:00Z"
    }
  }
}

// Headers
X-RateLimit-Limit: 600
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1705315845
Retry-After: 45
```

#### Server Error

```typescript
// Response (500 Internal Server Error)
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred. Please try again later.",
    "requestId": "req_abc123xyz" // For support inquiries
  }
}
```

### Error Handling Best Practices

1. **Always check HTTP status** - Don't assume success
2. **Parse error responses** - Extract code and message
3. **Implement retry logic** - Exponential backoff for 5xx errors
4. **Log request IDs** - Include in support requests
5. **Handle specific errors** - Different actions for different codes
6. **User-friendly messages** - Don't expose error codes to end users

### Example Error Handler

```typescript
async function apiRequest(endpoint: string, options: RequestInit) {
  try {
    const response = await fetch(endpoint, options);

    if (!response.ok) {
      const error = await response.json();

      switch (error.error.code) {
        case "RATE_LIMIT_EXCEEDED":
          // Wait and retry
          await sleep(error.error.retryAfter * 1000);
          return apiRequest(endpoint, options);

        case "INVALID_API_KEY":
          // Critical: notify admin
          await notifyAdmin("API key invalid - regenerate required");
          throw new Error("Authentication failed");

        case "COHORT_FULL":
          // Business logic: offer waitlist
          return offerWaitlistOption(error.error.details);

        case "INTERNAL_ERROR":
          // Retry with backoff
          await exponentialBackoff();
          return apiRequest(endpoint, options);

        default:
          // Log and throw
          console.error("API Error:", error);
          throw new Error(error.error.message);
      }
    }

    return response.json();
  } catch (err) {
    console.error("Request failed:", err);
    throw err;
  }
}
```

---

## 8.11 Pagination

### Cursor-Based Pagination

All list endpoints use cursor-based pagination for consistent performance with large datasets.

```typescript
// Request
GET /courses?limit=20

// Response
{
  "courses": [...],
  "pagination": {
    "hasNext": true,
    "nextCursor": "crs_xyz789",
    "limit": 20
  }
}

// Next page
GET /courses?limit=20&cursor=crs_xyz789
```

### Pagination Parameters

| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `limit` | integer | 20 | 100 | Results per page |
| `cursor` | string | null | - | Cursor from previous response |

---

## 8.12 Idempotency

### Idempotent Requests

Use `X-Idempotency-Key` header for safe retries of POST/PUT/DELETE requests.

```http
POST /admin/enrollments
X-Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json

{
  "userId": "usr_123",
  "cohortId": "coh_456"
}
```

- **Key format**: UUID v4 recommended
- **Key lifetime**: 24 hours
- **Scope**: Per API key
- **Behavior**: Duplicate requests return original response

---

## 8.13 API Versioning

### Current Version

- **Version**: v1
- **Base URL**: `https://api.aienablement.academy/v1`
- **Released**: January 2025
- **Deprecation Policy**: 12 months notice before breaking changes

### Future Versions

Future API versions will be released as `/v2`, `/v3`, etc. with backward compatibility maintained for previous versions during deprecation period.

---

## 8.14 OpenAPI Specification

Full OpenAPI 3.0 specification available at:

```
https://api.aienablement.academy/v1/openapi.json
```

Interactive API documentation (Swagger UI):

```
https://api.aienablement.academy/docs
```

---

## 8.15 Support & Resources

- **API Documentation**: https://docs.aienablement.academy/api
- **API Status**: https://status.aienablement.academy
- **Support Email**: api-support@aienablement.academy
- **Discord Community**: https://discord.gg/aienablement
- **Changelog**: https://docs.aienablement.academy/api/changelog

---

## 8.16 Learning Paths API (v2.1)

### List Learning Paths

```typescript
GET /api/v1/paths
Scopes: None (public endpoint)

// Query parameters
?audience=individual|team|enterprise|all  // Filter by target audience
&featured=true                            // Only featured paths
&isActive=true                            // Only active paths
&limit=20
&cursor=path_xyz

// Response (200 OK)
{
  "paths": [
    {
      "id": "path_abc123",
      "slug": "ai-foundations-track",
      "title": "AI Foundations Track",
      "shortDescription": "Master AI fundamentals and practical tools in 6 weeks",
      "targetAudience": "individual",
      "targetRole": "Individual Learner",
      "estimatedDuration": "6 weeks",
      "totalCourses": 3,
      "totalHours": 48,
      "pricingModel": "bundled",
      "bundlePrice": {
        "amount": 99700, // $997.00 in cents
        "currency": "USD",
        "display": "$997"
      },
      "bundleDiscount": 23, // 23% discount
      "outcomes": [
        "Understand core AI concepts and terminology",
        "Write effective prompts for any AI tool",
        "Integrate AI tools into daily workflows",
        "Build AI-powered automation workflows"
      ],
      "enrollmentCount": 234,
      "completionCount": 156,
      "isFeatured": true,
      "thumbnailUrl": "https://cdn.aienablement.academy/paths/ai-foundations.jpg"
    }
  ],
  "pagination": {
    "hasNext": true,
    "nextCursor": "path_def456",
    "limit": 20
  }
}

// Error responses
400: VALIDATION_ERROR - Invalid query parameters
500: INTERNAL_ERROR - Server error
```

### Get Learning Path Detail

```typescript
GET /api/v1/paths/:pathId
Scopes: None (public endpoint)

// Example
GET /api/v1/paths/ai-foundations-track

// Response (200 OK)
{
  "id": "path_abc123",
  "slug": "ai-foundations-track",
  "title": "AI Foundations Track",
  "description": "Comprehensive 6-week journey from AI novice to confident practitioner...",
  "shortDescription": "Master AI fundamentals and practical tools in 6 weeks",
  "targetAudience": "individual",
  "targetRole": "Individual Learner",
  "estimatedDuration": "6 weeks",
  "totalCourses": 3,
  "totalHours": 48,
  "pricingModel": "bundled",
  "bundlePrice": {
    "amount": 99700,
    "currency": "USD",
    "display": "$997"
  },
  "bundleDiscount": 23,
  "outcomes": [
    "Understand core AI concepts and terminology",
    "Write effective prompts for any AI tool",
    "Integrate AI tools into daily workflows",
    "Build AI-powered automation workflows"
  ],
  "steps": [
    {
      "id": "step_123",
      "stepNumber": 1,
      "course": {
        "id": "crs_abc",
        "title": "AI Fundamentals",
        "slug": "ai-fundamentals",
        "duration": "2 days"
      },
      "isRequired": true,
      "unlockRule": "immediate",
      "recommendedTimeframe": "Week 1-2",
      "upcomingCohorts": [
        {
          "id": "coh_456",
          "startDate": "2025-02-15T09:00:00Z",
          "endDate": "2025-02-16T17:00:00Z",
          "availableSeats": 12
        }
      ]
    },
    {
      "id": "step_124",
      "stepNumber": 2,
      "course": {
        "id": "crs_def",
        "title": "Prompt Engineering Mastery",
        "slug": "prompt-engineering-mastery",
        "duration": "2 days"
      },
      "isRequired": true,
      "unlockRule": "after_completion",
      "unlockAfterStepId": "step_123",
      "recommendedTimeframe": "Week 3-4",
      "upcomingCohorts": [...]
    },
    {
      "id": "step_125",
      "stepNumber": 3,
      "course": {
        "id": "crs_ghi",
        "title": "AI Tools Mastery",
        "slug": "ai-tools-mastery",
        "duration": "2 days"
      },
      "isRequired": true,
      "unlockRule": "after_completion",
      "unlockAfterStepId": "step_124",
      "recommendedTimeframe": "Week 5-6",
      "upcomingCohorts": [...]
    }
  ],
  "skills": [
    {
      "id": "skill_abc",
      "name": "Prompt Engineering",
      "category": "Technical"
    },
    {
      "id": "skill_def",
      "name": "AI Tool Selection",
      "category": "Strategic"
    }
  ],
  "enrollmentCount": 234,
  "completionCount": 156,
  "averageCompletionTime": "6.2 weeks",
  "isFeatured": true,
  "createdAt": "2024-11-01T00:00:00Z"
}

// Error responses
404: PATH_NOT_FOUND - Path does not exist
500: INTERNAL_ERROR - Server error
```

### Enroll in Learning Path

```typescript
POST /api/v1/paths/:pathId/enroll
Scopes: enrollments:write
Authentication: Required

// Request
{
  "paymentType": "bundle", // or "individual", "subscription", "organization"
  "stripePaymentIntentId": "pi_xyz789", // Required for bundle/individual
  "organizationId": "org_abc" // Required for organization payment type
}

// Response (201 Created)
{
  "id": "enr_path_xyz789",
  "pathId": "path_abc123",
  "userId": "usr_123",
  "status": "active",
  "paymentType": "bundle",
  "currentStep": {
    "id": "step_123",
    "stepNumber": 1,
    "course": {
      "title": "AI Fundamentals",
      "slug": "ai-fundamentals"
    },
    "unlockStatus": "unlocked"
  },
  "progress": {
    "completedSteps": 0,
    "totalSteps": 3,
    "percentComplete": 0
  },
  "enrolledAt": "2025-01-15T10:30:00Z",
  "expiresAt": "2025-12-31T23:59:59Z", // 1 year access
  "nextActions": [
    {
      "action": "enroll_course",
      "courseId": "crs_abc",
      "cohortId": "coh_456",
      "message": "Enroll in AI Fundamentals cohort to begin"
    }
  ]
}

// Error responses
400: VALIDATION_ERROR - Invalid request body
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Insufficient permissions
404: PATH_NOT_FOUND - Path does not exist
409: ALREADY_ENROLLED - User already enrolled in this path
422: PAYMENT_FAILED - Payment processing failed
500: INTERNAL_ERROR - Server error
```

### Get User's Path Enrollments

```typescript
GET /api/v1/users/:userId/paths
Scopes: enrollments:read
Authentication: Required
Requirement: User can only access their own enrollments (unless admin)

// Query parameters
?status=active|paused|completed|expired
&limit=20
&cursor=enr_path_xyz

// Response (200 OK)
{
  "enrollments": [
    {
      "id": "enr_path_xyz789",
      "path": {
        "id": "path_abc123",
        "slug": "ai-foundations-track",
        "title": "AI Foundations Track",
        "totalCourses": 3
      },
      "status": "active",
      "paymentType": "bundle",
      "currentStep": {
        "id": "step_124",
        "stepNumber": 2,
        "course": {
          "title": "Prompt Engineering Mastery",
          "slug": "prompt-engineering-mastery"
        }
      },
      "progress": {
        "completedSteps": 1,
        "totalSteps": 3,
        "percentComplete": 33
      },
      "completedCourses": [
        {
          "stepId": "step_123",
          "courseId": "crs_abc",
          "courseTitle": "AI Fundamentals",
          "completedAt": "2025-01-20T17:00:00Z"
        }
      ],
      "enrolledAt": "2025-01-10T14:30:00Z",
      "startedAt": "2025-01-15T09:00:00Z",
      "expiresAt": "2025-12-31T23:59:59Z"
    }
  ],
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}

// Error responses
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Cannot access other user's enrollments
404: USER_NOT_FOUND - User does not exist
500: INTERNAL_ERROR - Server error
```

### Get Path Progress

```typescript
GET /api/v1/users/:userId/paths/:pathId/progress
Scopes: enrollments:read
Authentication: Required
Requirement: User can only access their own progress (unless admin)

// Response (200 OK)
{
  "enrollmentId": "enr_path_xyz789",
  "pathId": "path_abc123",
  "userId": "usr_123",
  "status": "active",
  "overallProgress": {
    "completedSteps": 1,
    "totalSteps": 3,
    "percentComplete": 33,
    "estimatedTimeRemaining": "4 weeks"
  },
  "steps": [
    {
      "id": "step_123",
      "stepNumber": 1,
      "course": {
        "id": "crs_abc",
        "title": "AI Fundamentals",
        "slug": "ai-fundamentals"
      },
      "status": "completed",
      "isRequired": true,
      "unlockRule": "immediate",
      "unlockStatus": "unlocked",
      "enrollment": {
        "enrollmentId": "enr_abc123",
        "cohortId": "coh_456",
        "enrolledAt": "2025-01-10T14:30:00Z",
        "completedAt": "2025-01-20T17:00:00Z"
      }
    },
    {
      "id": "step_124",
      "stepNumber": 2,
      "course": {
        "id": "crs_def",
        "title": "Prompt Engineering Mastery",
        "slug": "prompt-engineering-mastery"
      },
      "status": "in_progress",
      "isRequired": true,
      "unlockRule": "after_completion",
      "unlockStatus": "unlocked",
      "enrollment": {
        "enrollmentId": "enr_def456",
        "cohortId": "coh_789",
        "enrolledAt": "2025-01-25T10:00:00Z",
        "completedAt": null
      }
    },
    {
      "id": "step_125",
      "stepNumber": 3,
      "course": {
        "id": "crs_ghi",
        "title": "AI Tools Mastery",
        "slug": "ai-tools-mastery"
      },
      "status": "locked",
      "isRequired": true,
      "unlockRule": "after_completion",
      "unlockStatus": "locked",
      "unlockCondition": "Complete step 2 (Prompt Engineering Mastery)",
      "enrollment": null
    }
  ],
  "enrolledAt": "2025-01-10T14:30:00Z",
  "startedAt": "2025-01-15T09:00:00Z",
  "expiresAt": "2025-12-31T23:59:59Z"
}

// Error responses
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Cannot access other user's progress
404: ENROLLMENT_NOT_FOUND - Path enrollment does not exist
500: INTERNAL_ERROR - Server error
```

### Generate Path Certificate

```typescript
POST /api/v1/paths/:pathId/certificates
Scopes: certificates:issue (admin) or automatic on completion
Authentication: Required

// Request (admin-issued)
{
  "userId": "usr_123",
  "enrollmentId": "enr_path_xyz789"
}

// Request (automatic on completion)
// No body required - triggered when user completes all required steps

// Response (201 Created)
{
  "id": "cert_path_abc123",
  "certificateNumber": "PATH-2025-001234",
  "userId": "usr_123",
  "pathId": "path_abc123",
  "pathTitle": "AI Foundations Track",
  "enrollmentId": "enr_path_xyz789",
  "issuedAt": "2025-02-28T18:00:00Z",
  "expiresAt": null, // null = never expires
  "skillsAchieved": [
    {
      "skillId": "skill_abc",
      "name": "Prompt Engineering",
      "level": "Proficient"
    },
    {
      "skillId": "skill_def",
      "name": "AI Tool Selection",
      "level": "Competent"
    }
  ],
  "badgeData": {
    "@context": "https://w3id.org/openbadges/v3",
    "type": ["VerifiableCredential", "OpenBadgeCredential"],
    "issuer": {
      "id": "https://aienablement.academy/issuer",
      "name": "AI Enablement Academy"
    },
    "issuanceDate": "2025-02-28T18:00:00Z",
    "credentialSubject": {
      "id": "did:example:usr_123",
      "achievement": {
        "id": "https://aienablement.academy/paths/ai-foundations-track",
        "name": "AI Foundations Track",
        "description": "Completed comprehensive 6-week AI foundations learning path",
        "criteria": {
          "narrative": "Successfully completed all 3 required courses: AI Fundamentals, Prompt Engineering Mastery, and AI Tools Mastery"
        }
      }
    }
  },
  "publicUrl": "https://credentials.aienablement.academy/PATH-2025-001234",
  "pdfUrl": "https://cdn.aienablement.academy/certificates/PATH-2025-001234.pdf",
  "linkedInShareUrl": "https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME&name=AI%20Foundations%20Track&organizationId=...",
  "verificationUrl": "https://credentials.aienablement.academy/verify/PATH-2025-001234"
}

// Error responses
400: VALIDATION_ERROR - Invalid request body
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Insufficient permissions
404: ENROLLMENT_NOT_FOUND - Path enrollment does not exist
422: PATH_INCOMPLETE - User has not completed all required steps
500: INTERNAL_ERROR - Server error
```

---

## 8.17 Community API (v2.1)

### List Discussion Threads

```typescript
GET /api/v1/discussions
Scopes: None (public for course-level, authentication required for session-specific)

// Query parameters
?scope=course|session|lesson|general     // Filter by scope
&courseId=crs_abc                        // Filter by course
&sessionId=sess_123                      // Filter by session
&lessonId=lesson_456                     // Filter by lesson
&category=question|discussion|show-and-tell|resource
&isPinned=true                           // Only pinned threads
&status=active                           // Filter by status (active|hidden|flagged)
&sortBy=recent|popular|unanswered        // Sort order
&limit=20
&cursor=thread_xyz

// Response (200 OK)
{
  "threads": [
    {
      "id": "thread_abc123",
      "title": "How to handle context retention in multi-turn prompts?",
      "content": "I'm building a customer service chatbot and struggling with...",
      "author": {
        "id": "usr_123",
        "name": "Jane Doe",
        "avatar": "https://cdn.aienablement.academy/avatars/jane.jpg",
        "role": "individual" // or "org_member", "org_admin"
      },
      "scope": "course",
      "courseId": "crs_abc",
      "category": "question",
      "tags": ["prompts", "chatbot", "context"],
      "isPinned": false,
      "isAnnouncement": false,
      "isLocked": false,
      "stats": {
        "replyCount": 8,
        "viewCount": 142,
        "likeCount": 5
      },
      "hasInstructorReply": true,
      "hasBestAnswer": true,
      "lastActivity": {
        "timestamp": "2025-01-20T15:30:00Z",
        "author": {
          "name": "Dr. Sarah Chen",
          "isInstructor": true
        }
      },
      "createdAt": "2025-01-18T10:00:00Z",
      "updatedAt": "2025-01-20T15:30:00Z"
    }
  ],
  "pagination": {
    "hasNext": true,
    "nextCursor": "thread_def456",
    "limit": 20
  }
}

// Error responses
400: VALIDATION_ERROR - Invalid query parameters
401: UNAUTHORIZED - Authentication required for private scopes
403: FORBIDDEN - Insufficient permissions to view scope
500: INTERNAL_ERROR - Server error
```

### Create Discussion Thread

```typescript
POST /api/v1/discussions
Scopes: chat:write (or automatic for enrolled users)
Authentication: Required

// Request
{
  "title": "How to handle context retention in multi-turn prompts?",
  "content": "I'm building a customer service chatbot and struggling with context retention across multiple exchanges. What strategies work best?",
  "scope": "course",
  "courseId": "crs_abc", // Required if scope=course
  "sessionId": "sess_123", // Required if scope=session
  "lessonId": "lesson_456", // Required if scope=lesson
  "category": "question", // "question", "discussion", "show-and-tell", "resource"
  "tags": ["prompts", "chatbot", "context"]
}

// Response (201 Created)
{
  "id": "thread_abc123",
  "title": "How to handle context retention in multi-turn prompts?",
  "content": "I'm building a customer service chatbot and struggling with...",
  "author": {
    "id": "usr_123",
    "name": "Jane Doe",
    "avatar": "https://cdn.aienablement.academy/avatars/jane.jpg"
  },
  "scope": "course",
  "courseId": "crs_abc",
  "category": "question",
  "tags": ["prompts", "chatbot", "context"],
  "isPinned": false,
  "isAnnouncement": false,
  "isLocked": false,
  "stats": {
    "replyCount": 0,
    "viewCount": 1,
    "likeCount": 0
  },
  "status": "active",
  "createdAt": "2025-01-18T10:00:00Z",
  "updatedAt": "2025-01-18T10:00:00Z"
}

// Error responses
400: VALIDATION_ERROR - Invalid request body
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Not enrolled in course/session
404: COURSE_NOT_FOUND - Referenced course/session/lesson does not exist
422: UNPROCESSABLE_ENTITY - Content validation failed
429: RATE_LIMIT_EXCEEDED - Too many threads created
500: INTERNAL_ERROR - Server error
```

### Get Discussion Thread Detail

```typescript
GET /api/v1/discussions/:threadId
Scopes: None (public for course-level, authentication required for session-specific)

// Response (200 OK)
{
  "id": "thread_abc123",
  "title": "How to handle context retention in multi-turn prompts?",
  "content": "I'm building a customer service chatbot and struggling with context retention across multiple exchanges. What strategies work best?",
  "author": {
    "id": "usr_123",
    "name": "Jane Doe",
    "avatar": "https://cdn.aienablement.academy/avatars/jane.jpg",
    "role": "individual"
  },
  "scope": "course",
  "courseId": "crs_abc",
  "category": "question",
  "tags": ["prompts", "chatbot", "context"],
  "isPinned": false,
  "isAnnouncement": false,
  "isLocked": false,
  "stats": {
    "replyCount": 8,
    "viewCount": 143,
    "likeCount": 5
  },
  "replies": [
    {
      "id": "reply_xyz789",
      "content": "Great question! Here are three strategies I've found effective:\n\n1. **Explicit context summarization**...",
      "author": {
        "id": "usr_456",
        "name": "Alex Johnson",
        "avatar": "https://cdn.aienablement.academy/avatars/alex.jpg",
        "isInstructor": false
      },
      "parentReplyId": null,
      "isInstructorReply": false,
      "isBestAnswer": false,
      "likeCount": 3,
      "createdAt": "2025-01-18T11:30:00Z"
    },
    {
      "id": "reply_uvw456",
      "content": "Building on Alex's point about explicit summarization, here's a concrete example...",
      "author": {
        "id": "fac_789",
        "name": "Dr. Sarah Chen",
        "avatar": "https://cdn.aienablement.academy/facilitators/sarah.jpg",
        "isInstructor": true
      },
      "parentReplyId": "reply_xyz789", // Nested reply
      "isInstructorReply": true,
      "isBestAnswer": true, // Marked as best answer
      "likeCount": 12,
      "createdAt": "2025-01-20T15:30:00Z"
    }
  ],
  "userInteractions": {
    "hasLiked": false,
    "hasBookmarked": true,
    "isSubscribed": true
  },
  "status": "active",
  "createdAt": "2025-01-18T10:00:00Z",
  "updatedAt": "2025-01-20T15:30:00Z"
}

// Error responses
401: UNAUTHORIZED - Authentication required for private scopes
403: FORBIDDEN - Insufficient permissions to view thread
404: THREAD_NOT_FOUND - Thread does not exist
500: INTERNAL_ERROR - Server error
```

### Add Reply to Thread

```typescript
POST /api/v1/discussions/:threadId/replies
Scopes: chat:write (or automatic for enrolled users)
Authentication: Required

// Request
{
  "content": "Great question! Here are three strategies I've found effective:\n\n1. **Explicit context summarization**...",
  "parentReplyId": "reply_xyz789" // Optional: for nested replies
}

// Response (201 Created)
{
  "id": "reply_abc123",
  "threadId": "thread_abc123",
  "content": "Great question! Here are three strategies I've found effective...",
  "author": {
    "id": "usr_456",
    "name": "Alex Johnson",
    "avatar": "https://cdn.aienablement.academy/avatars/alex.jpg",
    "isInstructor": false
  },
  "parentReplyId": null,
  "isInstructorReply": false,
  "isBestAnswer": false,
  "likeCount": 0,
  "status": "active",
  "createdAt": "2025-01-18T11:30:00Z",
  "updatedAt": "2025-01-18T11:30:00Z"
}

// Error responses
400: VALIDATION_ERROR - Invalid request body
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Thread is locked or insufficient permissions
404: THREAD_NOT_FOUND - Thread does not exist
404: PARENT_REPLY_NOT_FOUND - Parent reply does not exist
422: UNPROCESSABLE_ENTITY - Content validation failed
429: RATE_LIMIT_EXCEEDED - Too many replies created
500: INTERNAL_ERROR - Server error
```

### Request Peer Connection

```typescript
POST /api/v1/connections
Scopes: chat:write (or automatic for enrolled users)
Authentication: Required

// Request
{
  "connectedUserId": "usr_789",
  "connectionSource": "manual", // "cohort", "manual", "suggested"
  "sessionId": "sess_456", // Optional: if connecting from cohort
  "message": "Hi! I'd love to connect and discuss AI implementation strategies."
}

// Response (201 Created)
{
  "id": "conn_abc123",
  "userId": "usr_123",
  "connectedUser": {
    "id": "usr_789",
    "name": "Emily Rodriguez",
    "avatar": "https://cdn.aienablement.academy/avatars/emily.jpg",
    "company": "TechCorp Inc.",
    "title": "AI Product Manager"
  },
  "connectionSource": "manual",
  "sessionId": null,
  "status": "pending",
  "message": "Hi! I'd love to connect and discuss AI implementation strategies.",
  "createdAt": "2025-01-18T14:00:00Z"
}

// Error responses
400: VALIDATION_ERROR - Invalid request body
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Cannot connect with this user
404: USER_NOT_FOUND - Connected user does not exist
409: CONNECTION_EXISTS - Connection already exists
422: SELF_CONNECTION - Cannot connect with yourself
429: RATE_LIMIT_EXCEEDED - Too many connection requests
500: INTERNAL_ERROR - Server error
```

### Accept/Decline Connection

```typescript
PUT /api/v1/connections/:connectionId
Scopes: chat:write (or automatic for enrolled users)
Authentication: Required
Requirement: Must be the recipient of the connection request

// Request
{
  "action": "accept" // or "decline"
}

// Response (200 OK)
{
  "id": "conn_abc123",
  "userId": "usr_123",
  "connectedUser": {
    "id": "usr_789",
    "name": "Emily Rodriguez",
    "avatar": "https://cdn.aienablement.academy/avatars/emily.jpg",
    "company": "TechCorp Inc.",
    "title": "AI Product Manager",
    "email": "emily@techcorp.com" // Only visible after acceptance
  },
  "connectionSource": "manual",
  "status": "accepted", // or "declined"
  "createdAt": "2025-01-18T14:00:00Z",
  "acceptedAt": "2025-01-18T15:30:00Z",
  "message": "Hi! I'd love to connect and discuss AI implementation strategies."
}

// Error responses
400: VALIDATION_ERROR - Invalid action
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Not the recipient of this connection
404: CONNECTION_NOT_FOUND - Connection does not exist
409: INVALID_STATUS - Connection already accepted/declined
500: INTERNAL_ERROR - Server error
```

### Get User's Peer Connections

```typescript
GET /api/v1/users/:userId/connections
Scopes: chat:write (or automatic for enrolled users)
Authentication: Required
Requirement: User can only access their own connections (unless admin)

// Query parameters
?status=pending|accepted|declined       // Filter by status
&connectionSource=cohort|manual|suggested
&sessionId=sess_456                     // Filter by cohort
&limit=20
&cursor=conn_xyz

// Response (200 OK)
{
  "connections": [
    {
      "id": "conn_abc123",
      "connectedUser": {
        "id": "usr_789",
        "name": "Emily Rodriguez",
        "avatar": "https://cdn.aienablement.academy/avatars/emily.jpg",
        "company": "TechCorp Inc.",
        "title": "AI Product Manager",
        "email": "emily@techcorp.com" // Only for accepted connections
      },
      "connectionSource": "cohort",
      "sessionId": "sess_456",
      "status": "accepted",
      "sharedCohorts": [
        {
          "cohortId": "coh_123",
          "courseTitle": "AI Prompt Engineering Fundamentals",
          "startDate": "2025-01-15T09:00:00Z"
        }
      ],
      "createdAt": "2025-01-15T10:00:00Z",
      "acceptedAt": "2025-01-15T11:30:00Z"
    },
    {
      "id": "conn_def456",
      "connectedUser": {
        "id": "usr_012",
        "name": "Michael Chen",
        "avatar": "https://cdn.aienablement.academy/avatars/michael.jpg",
        "company": "StartupXYZ"
      },
      "connectionSource": "suggested",
      "status": "pending",
      "matchReason": "Similar interests: AI strategy, change management",
      "createdAt": "2025-01-18T14:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}

// Error responses
401: UNAUTHORIZED - Authentication required
403: FORBIDDEN - Cannot access other user's connections
404: USER_NOT_FOUND - User does not exist
500: INTERNAL_ERROR - Server error
```

---

### Rate Limits (v2.1 Endpoints)

| Endpoint | Rate Limit | Burst |
|----------|------------|-------|
| `POST /api/v1/discussions` | 10 threads/hour | 2 |
| `POST /api/v1/discussions/:id/replies` | 30 replies/hour | 5 |
| `POST /api/v1/connections` | 20 requests/hour | 3 |
| All other v2.1 endpoints | Standard tier limits | Standard |

### Error Codes (v2.1 Additions)

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| **404** | `PATH_NOT_FOUND` | Learning path does not exist |
| **404** | `THREAD_NOT_FOUND` | Discussion thread does not exist |
| **404** | `CONNECTION_NOT_FOUND` | Peer connection does not exist |
| **409** | `PATH_INCOMPLETE` | User has not completed required steps |
| **409** | `CONNECTION_EXISTS` | Connection already exists |
| **422** | `SELF_CONNECTION` | Cannot connect with yourself |

---

## 8.18 Skills API (v2.1)

The Skills API provides access to the comprehensive Skills & Competencies System, enabling skill-based learning tracking, competency assessment, and Open Badges 3.0 micro-credentials.

### List All Skills

```typescript
GET /api/v1/skills
Scopes: None (public endpoint)

// Query parameters
?category=technical           // Filter by category (technical, strategic, leadership, domain)
&level=practitioner          // Filter by level (foundational, practitioner, advanced, expert)
&parentSkillId=skl_abc       // Filter by parent skill (for hierarchies)
&isActive=true               // Only active skills
&limit=20
&cursor=skl_xyz

// Response (200 OK)
{
  "skills": [
    {
      "id": "skl_abc123",
      "name": "Prompt Engineering",
      "slug": "prompt-engineering",
      "description": "Ability to design effective prompts for AI systems to achieve desired outcomes",
      "category": "technical",
      "level": "practitioner",
      "parentSkillId": null,
      "prerequisites": ["skl_xyz456"], // Other skill IDs
      "iconUrl": "https://cdn.aienablement.academy/skills/prompt-engineering.svg",
      "competencyCount": 8,
      "isActive": true,
      "sortOrder": 1,
      "createdAt": "2024-11-01T00:00:00Z"
    },
    {
      "id": "skl_def456",
      "name": "Advanced Prompt Patterns",
      "slug": "advanced-prompt-patterns",
      "description": "Master complex prompting techniques including chain-of-thought and few-shot learning",
      "category": "technical",
      "level": "advanced",
      "parentSkillId": "skl_abc123", // Child of Prompt Engineering
      "prerequisites": ["skl_abc123"],
      "iconUrl": "https://cdn.aienablement.academy/skills/advanced-patterns.svg",
      "competencyCount": 12,
      "isActive": true,
      "sortOrder": 2,
      "createdAt": "2024-11-01T00:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}
```

### Get Skill Detail

```typescript
GET /api/v1/skills/:skillId
Scopes: None (public endpoint)

// Response (200 OK)
{
  "id": "skl_abc123",
  "name": "Prompt Engineering",
  "slug": "prompt-engineering",
  "description": "Ability to design effective prompts for AI systems to achieve desired outcomes",
  "category": "technical",
  "level": "practitioner",
  "parentSkillId": null,
  "prerequisites": [
    {
      "id": "skl_xyz456",
      "name": "AI Fundamentals",
      "slug": "ai-fundamentals"
    }
  ],
  "childSkills": [
    {
      "id": "skl_def456",
      "name": "Advanced Prompt Patterns",
      "level": "advanced"
    }
  ],
  "competencies": [
    {
      "id": "cmp_123",
      "name": "Write effective system prompts",
      "description": "Create clear, specific system prompts that guide AI behavior",
      "assessmentCriteria": "System prompt achieves intended AI behavior in 3+ test scenarios",
      "evidenceTypes": ["project", "instructor_assessment"],
      "passingThreshold": 80
    },
    {
      "id": "cmp_124",
      "name": "Apply prompt templates",
      "description": "Use proven prompt patterns for common tasks",
      "assessmentCriteria": "Successfully applies 5+ prompt templates to real-world scenarios",
      "evidenceTypes": ["quiz", "project"],
      "passingThreshold": 75
    }
  ],
  "relatedCourses": [
    {
      "id": "crs_abc",
      "title": "AI Prompt Engineering Fundamentals",
      "slug": "ai-prompt-engineering",
      "targetLevel": "practitioner"
    }
  ],
  "iconUrl": "https://cdn.aienablement.academy/skills/prompt-engineering.svg",
  "isActive": true,
  "createdAt": "2024-11-01T00:00:00Z",
  "updatedAt": "2025-01-10T00:00:00Z"
}
```

### Get User Skill Profile

```typescript
GET /api/v1/users/:userId/skills
Scopes: enrollments:read (own profile) or admin:users (any user)
Requirement: User must be authenticated and accessing own profile, or admin

// Query parameters
?category=technical           // Filter by skill category
&level=practitioner          // Filter by skill level
&minProgress=50              // Minimum progress percentage
&verified=true               // Only instructor-verified skills

// Response (200 OK)
{
  "userId": "usr_123",
  "skills": [
    {
      "id": "skl_abc123",
      "name": "Prompt Engineering",
      "slug": "prompt-engineering",
      "category": "technical",
      "level": "practitioner",
      "currentLevel": "practitioner",
      "progressPercent": 85,
      "evidenceCount": 6,
      "competenciesAchieved": 7,
      "competenciesTotal": 8,
      "lastAssessedAt": "2025-01-15T10:30:00Z",
      "verifiedByInstructor": true,
      "badges": [
        {
          "id": "bdg_xyz",
          "level": "practitioner",
          "earnedAt": "2025-01-15T10:30:00Z",
          "publicUrl": "https://badges.aienablement.academy/bdg_xyz"
        }
      ],
      "nextLevel": "advanced",
      "nextLevelRequirements": {
        "competenciesNeeded": 12,
        "competenciesAchieved": 0,
        "estimatedTime": "4-6 weeks"
      }
    },
    {
      "id": "skl_def456",
      "name": "AI Strategy",
      "slug": "ai-strategy",
      "category": "strategic",
      "level": "foundational",
      "currentLevel": "foundational",
      "progressPercent": 45,
      "evidenceCount": 3,
      "competenciesAchieved": 3,
      "competenciesTotal": 6,
      "lastAssessedAt": "2025-01-12T14:00:00Z",
      "verifiedByInstructor": false,
      "badges": [],
      "nextLevel": "practitioner",
      "nextLevelRequirements": {
        "competenciesNeeded": 6,
        "competenciesAchieved": 3,
        "estimatedTime": "2-3 weeks"
      }
    }
  ],
  "summary": {
    "totalSkills": 12,
    "skillsInProgress": 5,
    "skillsCompleted": 7,
    "totalBadges": 7,
    "skillsByCategory": {
      "technical": 6,
      "strategic": 3,
      "leadership": 2,
      "domain": 1
    },
    "skillsByLevel": {
      "foundational": 3,
      "practitioner": 6,
      "advanced": 2,
      "expert": 1
    }
  }
}
```

### Record Competency Evidence

```typescript
POST /api/v1/users/:userId/skills/:skillId/evidence
Scopes: enrollments:write (own profile) or admin:users (any user)

// Request
{
  "competencyId": "cmp_123",
  "enrollmentId": "enr_xyz789",     // Optional: link to enrollment
  "evidenceType": "project",
  "score": 88,                      // 0-100
  "evidenceUrl": "https://github.com/user/prompt-project", // Optional
  "notes": "Successfully implemented chain-of-thought prompting for customer service chatbot",
  "assessedBy": "usr_456"           // Optional: for peer/instructor assessment
}

// Response (201 Created)
{
  "id": "evi_abc123",
  "userId": "usr_123",
  "skillId": "skl_abc123",
  "competencyId": "cmp_123",
  "evidenceType": "project",
  "score": 88,
  "passed": true,                   // Based on competency passingThreshold
  "evidenceUrl": "https://github.com/user/prompt-project",
  "notes": "Successfully implemented chain-of-thought prompting for customer service chatbot",
  "assessedBy": {
    "id": "usr_456",
    "name": "Dr. Sarah Chen",
    "role": "instructor"
  },
  "createdAt": "2025-01-15T10:30:00Z",
  "skillProfile": {
    "currentLevel": "practitioner",
    "progressPercent": 90,          // Updated progress
    "competenciesAchieved": 8,
    "competenciesTotal": 8,
    "badgeEarned": true,            // Badge issued if all competencies achieved
    "badgeId": "bdg_xyz789"
  }
}
```

### Get User Skill Badges

```typescript
GET /api/v1/users/:userId/badges
Scopes: certificates:read (own profile) or admin:users (any user)

// Query parameters
?skillId=skl_abc123              // Filter by skill
&level=practitioner              // Filter by level
&expired=false                   // Exclude expired badges

// Response (200 OK)
{
  "userId": "usr_123",
  "badges": [
    {
      "id": "bdg_xyz789",
      "skill": {
        "id": "skl_abc123",
        "name": "Prompt Engineering",
        "slug": "prompt-engineering",
        "category": "technical"
      },
      "level": "practitioner",
      "earnedAt": "2025-01-15T10:30:00Z",
      "expiresAt": null,            // null = never expires
      "publicUrl": "https://badges.aienablement.academy/bdg_xyz789",
      "verificationUrl": "https://api.aienablement.academy/v1/badges/bdg_xyz789/verify",
      "openBadge": {
        "@context": "https://w3id.org/openbadges/v3",
        "type": ["VerifiableCredential", "OpenBadgeCredential"],
        "issuer": {
          "id": "https://aienablement.academy/issuer",
          "name": "AI Enablement Academy"
        },
        "issuanceDate": "2025-01-15T10:30:00Z",
        "credentialSubject": {
          "id": "did:example:usr_123",
          "achievement": {
            "id": "https://aienablement.academy/achievements/prompt-engineering-practitioner",
            "name": "Prompt Engineering - Practitioner",
            "description": "Demonstrated proficiency in designing effective prompts for AI systems",
            "criteria": {
              "narrative": "Achieved 8 out of 8 competencies with instructor verification"
            }
          }
        }
      }
    },
    {
      "id": "bdg_abc456",
      "skill": {
        "id": "skl_def456",
        "name": "AI Strategy",
        "slug": "ai-strategy",
        "category": "strategic"
      },
      "level": "foundational",
      "earnedAt": "2025-01-10T14:00:00Z",
      "expiresAt": "2027-01-10T14:00:00Z", // Some badges expire (e.g., tool-specific)
      "publicUrl": "https://badges.aienablement.academy/bdg_abc456",
      "verificationUrl": "https://api.aienablement.academy/v1/badges/bdg_abc456/verify",
      "openBadge": {...}
    }
  ],
  "summary": {
    "totalBadges": 7,
    "activeBadges": 7,
    "expiredBadges": 0,
    "badgesByLevel": {
      "foundational": 3,
      "practitioner": 3,
      "advanced": 1,
      "expert": 0
    }
  }
}
```

### Verify Skill Badge

```typescript
GET /api/v1/badges/:badgeId/verify
Scopes: None (public endpoint)

// Response (200 OK)
{
  "valid": true,
  "badge": {
    "id": "bdg_xyz789",
    "recipient": {
      "name": "Jane Doe",
      "email": "j***@example.com"   // Masked for privacy
    },
    "skill": {
      "name": "Prompt Engineering",
      "level": "practitioner"
    },
    "earnedAt": "2025-01-15T10:30:00Z",
    "expiresAt": null,
    "publicUrl": "https://badges.aienablement.academy/bdg_xyz789",
    "openBadge": {
      "@context": "https://w3id.org/openbadges/v3",
      "type": ["VerifiableCredential", "OpenBadgeCredential"],
      "issuer": {
        "id": "https://aienablement.academy/issuer",
        "name": "AI Enablement Academy"
      },
      "credentialSubject": {
        "achievement": {
          "name": "Prompt Engineering - Practitioner",
          "description": "Demonstrated proficiency in designing effective prompts for AI systems"
        }
      }
    }
  }
}

// Invalid badge (404 Not Found)
{
  "valid": false,
  "error": {
    "code": "BADGE_NOT_FOUND",
    "message": "Badge not found or has been revoked"
  }
}
```

---

## 8.19 Resources API (v2.1)

The Resources API provides access to the Resource Library System, including templates, frameworks, glossary terms, prompt library, and curated learning materials with tiered access control.

### Browse Resources

```typescript
GET /api/v1/resources
Scopes: None (unauthenticated = public only), materials:read (authenticated access)

// Query parameters
?type=template                   // Filter by type (template, framework, prompt, glossary, etc.)
&category=Prompt Engineering     // Filter by category
&tags=beginner,marketing         // Filter by tags (comma-separated)
&accessLevel=public              // Filter by access level
&isFeatured=true                 // Only featured resources
&skillIds=skl_abc123             // Filter by related skills
&search=prompt+patterns          // Full-text search
&limit=20
&cursor=res_xyz

// Response (200 OK)
{
  "resources": [
    {
      "id": "res_abc123",
      "title": "AI Strategy Canvas Template",
      "slug": "ai-strategy-canvas",
      "description": "A comprehensive framework for planning AI implementation across your organization",
      "type": "template",
      "category": "AI Strategy",
      "tags": ["strategy", "planning", "executive"],
      "accessLevel": "registered",
      "fileType": "xlsx",
      "downloadCount": 1247,
      "viewCount": 4532,
      "rating": 4.8,
      "ratingCount": 142,
      "isFeatured": true,
      "skillIds": ["skl_def456"],
      "author": {
        "id": "usr_456",
        "name": "Dr. Sarah Chen",
        "avatar": "https://cdn.aienablement.academy/users/sarah.jpg"
      },
      "previewUrl": "https://cdn.aienablement.academy/resources/previews/res_abc123.png",
      "createdAt": "2024-11-01T00:00:00Z",
      "updatedAt": "2025-01-10T00:00:00Z"
    },
    {
      "id": "res_def456",
      "title": "Prompt Engineering Best Practices Checklist",
      "slug": "prompt-engineering-checklist",
      "description": "Quality assurance checklist for prompt development",
      "type": "checklist",
      "category": "Prompt Engineering",
      "tags": ["prompts", "quality", "beginner"],
      "accessLevel": "public",
      "downloadCount": 3421,
      "viewCount": 8765,
      "rating": 4.9,
      "ratingCount": 287,
      "isFeatured": true,
      "skillIds": ["skl_abc123"],
      "author": null,               // Platform-created content
      "previewUrl": "https://cdn.aienablement.academy/resources/previews/res_def456.png",
      "createdAt": "2024-11-01T00:00:00Z",
      "updatedAt": "2024-12-15T00:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": true,
    "nextCursor": "res_xyz789",
    "limit": 20
  }
}
```

### Get Resource Detail

```typescript
GET /api/v1/resources/:resourceId
Scopes: None (for public resources), materials:read (for restricted resources)
Requirement: Access level verification based on user status

// Response (200 OK)
{
  "id": "res_abc123",
  "title": "AI Strategy Canvas Template",
  "slug": "ai-strategy-canvas",
  "description": "A comprehensive framework for planning AI implementation across your organization",
  "type": "template",
  "category": "AI Strategy",
  "tags": ["strategy", "planning", "executive"],
  "content": null,                  // For articles/glossary (markdown)
  "fileId": "file_xyz789",          // For downloadables
  "fileType": "xlsx",
  "fileSize": 245760,               // bytes
  "externalUrl": null,
  "videoUrl": null,
  "accessLevel": "registered",
  "courseIds": [],                  // Empty = not course-specific
  "hasAccess": true,                // User's access status
  "author": {
    "id": "usr_456",
    "name": "Dr. Sarah Chen",
    "bio": "AI Strategy Consultant with 15+ years experience",
    "avatar": "https://cdn.aienablement.academy/users/sarah.jpg"
  },
  "relatedSkills": [
    {
      "id": "skl_def456",
      "name": "AI Strategy",
      "level": "practitioner"
    }
  ],
  "relatedResources": [
    {
      "id": "res_ghi789",
      "title": "AI Implementation Roadmap",
      "type": "framework",
      "slug": "ai-roadmap"
    }
  ],
  "downloadCount": 1247,
  "viewCount": 4532,
  "rating": 4.8,
  "ratingCount": 142,
  "userRating": null,               // Current user's rating (if any)
  "userBookmarked": false,
  "isFeatured": true,
  "isActive": true,
  "previewUrl": "https://cdn.aienablement.academy/resources/previews/res_abc123.png",
  "downloadUrl": "https://api.aienablement.academy/v1/resources/res_abc123/download",
  "createdAt": "2024-11-01T00:00:00Z",
  "updatedAt": "2025-01-10T00:00:00Z"
}

// Insufficient access (403 Forbidden)
{
  "error": {
    "code": "INSUFFICIENT_ACCESS",
    "message": "This resource requires enrollment in a course",
    "details": {
      "accessLevel": "enrolled",
      "requiredCourses": [
        {
          "id": "crs_abc123",
          "title": "AI Strategy Fundamentals",
          "slug": "ai-strategy"
        }
      ]
    }
  }
}
```

### Search Glossary Terms

```typescript
GET /api/v1/glossary
Scopes: None (public endpoint)

// Query parameters
?search=prompt                   // Search term
&category=technical              // Filter by category
&tags=beginner                   // Filter by tags
&limit=20
&cursor=gls_xyz

// Response (200 OK)
{
  "terms": [
    {
      "id": "gls_abc123",
      "term": "Prompt Engineering",
      "slug": "prompt-engineering",
      "definition": "The practice of designing and optimizing text inputs (prompts) to elicit desired outputs from AI language models.",
      "examples": [
        "System prompt: 'You are an expert Python developer. Provide concise, production-ready code.'",
        "Few-shot prompt: 'Example 1: Input -> Output, Example 2: Input -> Output, Now try: [New Input]'"
      ],
      "relatedTerms": [
        {
          "id": "gls_def456",
          "term": "System Prompt",
          "slug": "system-prompt"
        },
        {
          "id": "gls_ghi789",
          "term": "Few-Shot Learning",
          "slug": "few-shot-learning"
        }
      ],
      "skillIds": ["skl_abc123"],
      "tags": ["technical", "beginner"],
      "viewCount": 2341,
      "isFeatured": true,
      "createdAt": "2024-11-01T00:00:00Z"
    },
    {
      "id": "gls_def456",
      "term": "System Prompt",
      "slug": "system-prompt",
      "definition": "An initial instruction that sets the context, role, and behavior parameters for an AI assistant throughout a conversation.",
      "examples": [
        "You are a helpful, harmless, and honest assistant.",
        "You are an expert SQL developer. Respond only with valid SQL queries."
      ],
      "relatedTerms": [
        {
          "id": "gls_abc123",
          "term": "Prompt Engineering",
          "slug": "prompt-engineering"
        }
      ],
      "skillIds": ["skl_abc123"],
      "tags": ["technical", "beginner"],
      "viewCount": 1876,
      "isFeatured": false,
      "createdAt": "2024-11-01T00:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}
```

### Browse Prompt Library

```typescript
GET /api/v1/prompts
Scopes: None (unauthenticated = limited), materials:read (authenticated = full access)

// Query parameters
?category=Content Creation       // Filter by category
&tags=marketing,beginner         // Filter by tags
&useCase=blog-writing            // Filter by use case
&accessLevel=public              // Filter by access level
&limit=20
&cursor=pmt_xyz

// Response (200 OK)
{
  "prompts": [
    {
      "id": "pmt_abc123",
      "title": "Blog Post Outline Generator",
      "slug": "blog-outline-generator",
      "description": "Generate comprehensive blog post outlines with key sections and talking points",
      "category": "Content Creation",
      "tags": ["marketing", "blogging", "beginner"],
      "useCase": "blog-writing",
      "promptTemplate": "Create a detailed blog post outline for the topic: {topic}\n\nTarget audience: {audience}\nDesired tone: {tone}\nKey points to cover: {key_points}\n\nInclude:\n- Engaging headline\n- Introduction hook\n- 3-5 main sections with subpoints\n- Conclusion with call-to-action",
      "variables": [
        {
          "name": "topic",
          "description": "Main blog topic",
          "required": true,
          "example": "AI Tools for Small Business"
        },
        {
          "name": "audience",
          "description": "Target audience",
          "required": true,
          "example": "Small business owners with limited tech experience"
        },
        {
          "name": "tone",
          "description": "Desired writing tone",
          "required": false,
          "example": "Professional yet conversational"
        },
        {
          "name": "key_points",
          "description": "Key points to cover (comma-separated)",
          "required": false,
          "example": "cost savings, ease of use, real examples"
        }
      ],
      "accessLevel": "public",
      "useCount": 3247,
      "rating": 4.7,
      "ratingCount": 189,
      "skillIds": ["skl_abc123"],
      "author": {
        "id": "usr_456",
        "name": "Dr. Sarah Chen"
      },
      "createdAt": "2024-11-01T00:00:00Z",
      "updatedAt": "2025-01-10T00:00:00Z"
    },
    {
      "id": "pmt_def456",
      "title": "Customer Persona Builder",
      "slug": "customer-persona-builder",
      "description": "Create detailed customer personas with demographics, pain points, and motivations",
      "category": "Business Operations",
      "tags": ["marketing", "strategy", "intermediate"],
      "useCase": "market-research",
      "promptTemplate": "[Template available to registered users]",
      "variables": [],
      "accessLevel": "registered",
      "useCount": 1876,
      "rating": 4.9,
      "ratingCount": 124,
      "skillIds": ["skl_def456"],
      "author": null,
      "createdAt": "2024-11-01T00:00:00Z",
      "updatedAt": "2024-12-15T00:00:00Z"
    }
  ],
  "pagination": {
    "hasNext": true,
    "nextCursor": "pmt_xyz789",
    "limit": 20
  }
}
```

### Track Prompt Usage

```typescript
POST /api/v1/prompts/:promptId/use
Scopes: materials:read (authenticated users only)

// Request
{
  "variables": {
    "topic": "AI Tools for Small Business",
    "audience": "Small business owners",
    "tone": "Professional yet conversational",
    "key_points": "cost savings, ease of use, real examples"
  },
  "rating": 5,                      // Optional: 1-5 rating
  "feedback": "Great prompt! Generated excellent outline in seconds" // Optional
}

// Response (200 OK)
{
  "id": "use_abc123",
  "promptId": "pmt_abc123",
  "userId": "usr_123",
  "useCount": 3248,                 // Updated total use count
  "createdAt": "2025-01-15T10:30:00Z",
  "rating": {
    "average": 4.7,
    "count": 190,
    "userRating": 5
  }
}
```

### Create Bookmark

```typescript
POST /api/v1/bookmarks
Scopes: materials:read

// Request
{
  "resourceType": "resource",       // or "glossary", "prompt"
  "resourceId": "res_abc123",
  "notes": "Great template for Q2 planning"
}

// Response (201 Created)
{
  "id": "bkm_xyz789",
  "userId": "usr_123",
  "resourceType": "resource",
  "resourceId": "res_abc123",
  "resource": {
    "id": "res_abc123",
    "title": "AI Strategy Canvas Template",
    "type": "template",
    "slug": "ai-strategy-canvas"
  },
  "notes": "Great template for Q2 planning",
  "createdAt": "2025-01-15T10:30:00Z"
}
```

### Get User Bookmarks

```typescript
GET /api/v1/users/:userId/bookmarks
Scopes: materials:read (own bookmarks) or admin:users (any user)

// Query parameters
?resourceType=resource           // Filter by type (resource, glossary, prompt)
&limit=20
&cursor=bkm_xyz

// Response (200 OK)
{
  "bookmarks": [
    {
      "id": "bkm_xyz789",
      "resourceType": "resource",
      "resourceId": "res_abc123",
      "resource": {
        "id": "res_abc123",
        "title": "AI Strategy Canvas Template",
        "type": "template",
        "slug": "ai-strategy-canvas",
        "previewUrl": "https://cdn.aienablement.academy/resources/previews/res_abc123.png"
      },
      "notes": "Great template for Q2 planning",
      "createdAt": "2025-01-15T10:30:00Z"
    },
    {
      "id": "bkm_abc456",
      "resourceType": "prompt",
      "resourceId": "pmt_def456",
      "resource": {
        "id": "pmt_def456",
        "title": "Blog Post Outline Generator",
        "type": "prompt",
        "slug": "blog-outline-generator",
        "category": "Content Creation"
      },
      "notes": "Use for weekly blog posts",
      "createdAt": "2025-01-12T14:00:00Z"
    }
  ],
  "summary": {
    "totalBookmarks": 12,
    "byType": {
      "resource": 5,
      "glossary": 3,
      "prompt": 4
    }
  },
  "pagination": {
    "hasNext": false,
    "nextCursor": null,
    "limit": 20
  }
}
```

---

## 8.20 Assessments API (v2.1)

### List Assessments for Course

```typescript
GET /api/v1/courses/:courseId/assessments
Scopes: enrollments:read
Requirement: User must be enrolled in course

// Query parameters
?type=pre_course|post_course|knowledge_check|skill_assessment|certification|self_assessment
&isActive=true

// Response (200 OK)
{
  "assessments": [
    {
      "id": "asmt_abc123",
      "title": "AI Fundamentals - Pre-Assessment",
      "description": "Measure your current AI knowledge before the course",
      "type": "pre_course",
      "courseId": "crs_xyz789",
      "skillIds": ["skl_001", "skl_002", "skl_003"],
      "timeLimit": 30, // minutes, null = unlimited
      "passingScore": 0, // 0-100
      "allowRetake": false,
      "maxAttempts": 1,
      "questionsPerAttempt": 20,
      "randomizeQuestions": true,
      "isActive": true,
      "userProgress": {
        "attemptsTaken": 0,
        "bestScore": null,
        "lastAttemptAt": null,
        "canRetake": true
      }
    },
    {
      "id": "asmt_def456",
      "title": "AI Fundamentals - Post-Assessment",
      "description": "Measure your learning gains after completing the course",
      "type": "post_course",
      "courseId": "crs_xyz789",
      "skillIds": ["skl_001", "skl_002", "skl_003"],
      "timeLimit": 30,
      "passingScore": 70,
      "allowRetake": true,
      "maxAttempts": 3,
      "questionsPerAttempt": 20,
      "isActive": true,
      "userProgress": {
        "attemptsTaken": 0,
        "bestScore": null,
        "lastAttemptAt": null,
        "canRetake": true
      }
    }
  ]
}
```

### Get Assessment with Questions

```typescript
GET /api/v1/assessments/:assessmentId
Scopes: enrollments:read
Requirement: User must be enrolled in associated course

// Response (200 OK)
{
  "id": "asmt_abc123",
  "title": "AI Fundamentals - Pre-Assessment",
  "description": "Measure your current AI knowledge before the course",
  "type": "pre_course",
  "courseId": "crs_xyz789",
  "lessonId": null,
  "skillIds": ["skl_001", "skl_002", "skl_003"],

  // Settings
  "timeLimit": 30, // minutes
  "passingScore": 0,
  "allowRetake": false,
  "maxAttempts": 1,
  "showCorrectAnswers": "never", // never, after_submit, after_passing, after_all_attempts
  "randomizeQuestions": true,
  "randomizeAnswers": true,
  "questionsPerAttempt": 20,

  // Questions (only returned when starting a new attempt)
  "questions": [
    {
      "id": "q_001",
      "questionType": "multiple_choice",
      "questionText": "What is the primary difference between machine learning and traditional programming?",
      "questionImageId": null,
      "difficulty": "medium",
      "points": 5,
      "skillIds": ["skl_001"],
      "sortOrder": 1,
      "answers": [
        {
          "id": "mc1-a",
          "text": "Machine learning models learn patterns from data instead of following explicit instructions"
        },
        {
          "id": "mc1-b",
          "text": "Machine learning is faster than traditional programming"
        },
        {
          "id": "mc1-c",
          "text": "Machine learning uses more memory than traditional programming"
        },
        {
          "id": "mc1-d",
          "text": "Machine learning doesn't require any programming"
        }
      ]
    },
    {
      "id": "q_002",
      "questionType": "multiple_select",
      "questionText": "Which of the following are effective prompt engineering techniques? (Select all that apply)",
      "difficulty": "medium",
      "points": 10,
      "skillIds": ["skl_002"],
      "sortOrder": 2,
      "answers": [
        {
          "id": "ms1-a",
          "text": "Providing clear context and role definitions"
        },
        {
          "id": "ms1-b",
          "text": "Using all capital letters for emphasis"
        },
        {
          "id": "ms1-c",
          "text": "Breaking complex tasks into step-by-step instructions"
        },
        {
          "id": "ms1-d",
          "text": "Including examples of desired outputs"
        }
      ]
    },
    {
      "id": "q_003",
      "questionType": "rating_scale",
      "questionText": "How confident are you in your ability to write effective prompts for AI tools?",
      "difficulty": "easy",
      "points": 0,
      "scaleMin": 1,
      "scaleMax": 5,
      "scaleLabels": {
        "min": "Not confident at all",
        "max": "Very confident"
      },
      "sortOrder": 3
    },
    {
      "id": "q_004",
      "questionType": "open_ended",
      "questionText": "Describe a specific business process in your organization that could benefit from AI automation. (150-300 words)",
      "difficulty": "hard",
      "points": 15,
      "skillIds": ["skl_003"],
      "aiGradingEnabled": true,
      "sortOrder": 4
    }
  ],

  // User progress
  "userProgress": {
    "attemptsTaken": 0,
    "bestScore": null,
    "lastAttemptAt": null,
    "canRetake": true,
    "attemptsRemaining": 1
  }
}
```

### Start Assessment Attempt

```typescript
POST /api/v1/assessments/:assessmentId/attempts
Scopes: enrollments:read
Requirement: User must be enrolled in associated course

// Request (empty body for most assessments)
{}

// Response (201 Created)
{
  "attemptId": "atpt_abc123",
  "assessmentId": "asmt_abc123",
  "attemptNumber": 1,
  "status": "in_progress",
  "startedAt": "2025-01-15T10:00:00Z",
  "expiresAt": "2025-01-15T10:30:00Z", // Based on timeLimit
  "questions": [
    // Array of questions (randomized if configured)
  ],
  "pointsPossible": 100,
  "timeLimit": 30 // minutes
}

// Error responses
// 409 Conflict - Max attempts reached
{
  "error": {
    "code": "MAX_ATTEMPTS_REACHED",
    "message": "You have reached the maximum number of attempts for this assessment",
    "details": {
      "attemptsTaken": 3,
      "maxAttempts": 3,
      "bestScore": 65
    }
  }
}

// 409 Conflict - Attempt in progress
{
  "error": {
    "code": "ATTEMPT_IN_PROGRESS",
    "message": "You have an active attempt for this assessment",
    "details": {
      "activeAttemptId": "atpt_xyz789",
      "startedAt": "2025-01-15T09:45:00Z",
      "expiresAt": "2025-01-15T10:15:00Z"
    }
  }
}
```

### Submit Question Responses

```typescript
PUT /api/v1/attempts/:attemptId/responses
Scopes: enrollments:read
Requirement: User must own the attempt

// Request
{
  "responses": [
    {
      "questionId": "q_001",
      "selectedAnswerIds": ["mc1-a"] // For multiple_choice
    },
    {
      "questionId": "q_002",
      "selectedAnswerIds": ["ms1-a", "ms1-c", "ms1-d"] // For multiple_select
    },
    {
      "questionId": "q_003",
      "ratingValue": 3 // For rating_scale
    },
    {
      "questionId": "q_004",
      "textResponse": "In our marketing department, we spend 10+ hours weekly manually categorizing customer support tickets..." // For short_answer or open_ended
    }
  ],
  "autoSubmit": false // Set true to automatically complete attempt
}

// Response (200 OK)
{
  "attemptId": "atpt_abc123",
  "responsesUpdated": 4,
  "status": "in_progress", // or "submitted" if autoSubmit=true
  "timeRemaining": 1234 // seconds
}

// Error responses
// 410 Gone - Attempt expired
{
  "error": {
    "code": "ATTEMPT_EXPIRED",
    "message": "This assessment attempt has expired",
    "details": {
      "expiresAt": "2025-01-15T10:30:00Z"
    }
  }
}
```

### Complete Assessment

```typescript
POST /api/v1/attempts/:attemptId/complete
Scopes: enrollments:read
Requirement: User must own the attempt

// Request (empty body)
{}

// Response (200 OK)
{
  "attemptId": "atpt_abc123",
  "assessmentId": "asmt_abc123",
  "status": "graded", // or "submitted" if awaiting AI grading
  "submittedAt": "2025-01-15T10:25:00Z",
  "timeSpent": 1500, // seconds

  // Results (available immediately for auto-graded questions)
  "score": 85, // 0-100
  "pointsEarned": 85,
  "pointsPossible": 100,
  "passed": true,

  // Question-level feedback (based on showCorrectAnswers setting)
  "questionResults": [
    {
      "questionId": "q_001",
      "isCorrect": true,
      "pointsEarned": 5,
      "feedback": "Correct! ML models discover patterns from training data.",
      "correctAnswerIds": ["mc1-a"], // Only shown based on showCorrectAnswers
      "explanation": "Machine learning differs from traditional programming in that models learn patterns from data rather than following explicit human-written rules."
    },
    {
      "questionId": "q_002",
      "isCorrect": true,
      "pointsEarned": 10,
      "feedback": "Perfect! You identified all effective prompt engineering techniques.",
      "correctAnswerIds": ["ms1-a", "ms1-c", "ms1-d"]
    },
    {
      "questionId": "q_003",
      "ratingValue": 3,
      "pointsEarned": 0, // Self-assessment not scored
      "feedback": null
    },
    {
      "questionId": "q_004",
      "aiScore": 13, // Out of 15 points
      "aiConfidence": 0.87,
      "aiExplanation": "Your response clearly identifies a specific process (ticket categorization), describes the automation approach, and articulates expected outcomes. Minor points deducted for not addressing potential implementation challenges.",
      "feedback": "Strong use case identification! Consider adding risk mitigation strategies.",
      "status": "graded" // or "pending" if awaiting manual review
    }
  ],

  "overallFeedback": "Excellent work! You demonstrated strong understanding of AI fundamentals and practical application thinking.",

  // Learning gain (if this completes a pre/post pair)
  "learningGain": {
    "preScore": 45,
    "postScore": 85,
    "scoreImprovement": 40,
    "percentageGain": 88.9, // ((85-45)/45) * 100
    "normalizedGain": 0.73, // Hake's normalized gain: (85-45)/(100-45)
    "skillGains": [
      {
        "skillId": "skl_001",
        "skillName": "AI Concepts",
        "preScore": 40,
        "postScore": 90,
        "improvement": 50
      },
      {
        "skillId": "skl_002",
        "skillName": "Prompt Engineering",
        "preScore": 50,
        "postScore": 80,
        "improvement": 30
      }
    ]
  }
}

// Error responses
// 409 Conflict - Already completed
{
  "error": {
    "code": "ATTEMPT_ALREADY_COMPLETED",
    "message": "This attempt has already been submitted",
    "details": {
      "submittedAt": "2025-01-15T10:20:00Z",
      "score": 85
    }
  }
}
```

### Get Learning Gain Analytics

```typescript
GET /api/v1/users/:userId/learning-gain
Scopes: enrollments:read
Requirement: User must be self or have admin:analytics scope

// Query parameters
?courseId=crs_xyz789  // Optional: filter by course
&enrollmentId=enr_abc // Optional: filter by enrollment

// Response (200 OK)
{
  "userId": "usr_123",
  "overallGains": {
    "coursesWithGains": 3,
    "avgScoreImprovement": 35.7,
    "avgNormalizedGain": 0.68,
    "totalSkillsImproved": 12
  },
  "courseGains": [
    {
      "courseId": "crs_xyz789",
      "courseTitle": "AI Fundamentals",
      "enrollmentId": "enr_abc123",
      "preAssessmentId": "asmt_pre_001",
      "postAssessmentId": "asmt_post_001",
      "preScore": 45,
      "postScore": 85,
      "scoreImprovement": 40,
      "percentageGain": 88.9,
      "normalizedGain": 0.73, // Hake's gain formula
      "calculatedAt": "2025-01-16T18:00:00Z",
      "skillGains": [
        {
          "skillId": "skl_001",
          "skillName": "AI Concepts",
          "preScore": 40,
          "postScore": 90,
          "improvement": 50
        },
        {
          "skillId": "skl_002",
          "skillName": "Prompt Engineering",
          "preScore": 50,
          "postScore": 80,
          "improvement": 30
        },
        {
          "skillId": "skl_003",
          "skillName": "Use Case Identification",
          "preScore": 45,
          "postScore": 85,
          "improvement": 40
        }
      ]
    }
  ]
}
```

---

## 8.21 Manager Dashboard API (v2.1) - B2B Only

### Get Organization Analytics

```typescript
GET /api/v1/organizations/:orgId/analytics
Scopes: admin:analytics
Requirement: User must have manager role in organization

// Query parameters
?periodType=daily|weekly|monthly
&periodStart=2025-01-01  // ISO date
&periodEnd=2025-01-31    // ISO date

// Response (200 OK)
{
  "organizationId": "org_abc123",
  "organizationName": "Acme Corporation",
  "seatsPurchased": 100,
  "seatsUsed": 87,
  "seatUtilization": 0.87, // 87%

  "currentPeriod": {
    "periodType": "monthly",
    "periodStart": "2025-01-01T00:00:00Z",
    "periodEnd": "2025-01-31T23:59:59Z",

    // Enrollment metrics
    "totalEnrollments": 127,
    "activeEnrollments": 95,
    "completedEnrollments": 32,
    "completionRate": 0.25, // 32/127

    // Engagement metrics
    "totalLearningHours": 2840,
    "avgLearningHoursPerUser": 32.6,
    "lessonsCompleted": 1547,
    "avgLessonsPerUser": 17.8,

    // Performance metrics
    "avgAssessmentScore": 78.5,
    "avgLearningGain": 0.62, // Normalized gain
    "certificatesIssued": 32,

    // Skills metrics
    "skillsAcquired": 256,
    "avgSkillProgress": 0.68,

    // Comparison vs previous period
    "enrollmentsChange": 15, // +15 enrollments
    "completionRateChange": 0.05, // +5 percentage points

    "calculatedAt": "2025-01-31T23:59:59Z"
  },

  "topPerformingTeams": [
    {
      "teamId": "team_001",
      "teamName": "Marketing Team",
      "completionRate": 0.95,
      "avgScore": 85.2,
      "memberCount": 12
    },
    {
      "teamId": "team_002",
      "teamName": "Engineering Team",
      "completionRate": 0.88,
      "avgScore": 82.7,
      "memberCount": 25
    }
  ],

  "atRiskLearners": [
    {
      "userId": "usr_456",
      "userName": "Jane Doe", // Shown based on privacy settings
      "teamId": "team_003",
      "teamName": "Sales Team",
      "daysInactive": 14,
      "progressPercent": 25,
      "lastActiveAt": "2025-01-17T10:30:00Z"
    }
  ],

  "upcomingDeadlines": [
    {
      "teamId": "team_004",
      "teamName": "Support Team",
      "courseId": "crs_xyz",
      "courseTitle": "AI Customer Service Excellence",
      "deadline": "2025-02-15T23:59:59Z",
      "daysRemaining": 15,
      "onTrackCount": 8,
      "behindScheduleCount": 4
    }
  ]
}
```

### Get Team Analytics

```typescript
GET /api/v1/teams/:teamId/analytics
Scopes: admin:analytics
Requirement: User must have manager role for this team

// Query parameters
?periodType=daily|weekly|monthly
&periodStart=2025-01-01
&periodEnd=2025-01-31

// Response (200 OK)
{
  "teamId": "team_001",
  "teamName": "Marketing Team",
  "organizationId": "org_abc123",
  "managerId": "usr_789",
  "managerName": "John Smith",

  "currentPeriod": {
    "periodType": "monthly",
    "periodStart": "2025-01-01T00:00:00Z",
    "periodEnd": "2025-01-31T23:59:59Z",

    // Team composition
    "memberCount": 12,
    "activeMembers": 11, // Logged in this period

    // Progress metrics
    "avgProgressPercent": 75.5,
    "lessonsCompleted": 342,
    "totalLearningHours": 456,
    "avgLearningHoursPerMember": 38,

    // Performance metrics
    "avgAssessmentScore": 82.3,
    "coursesCompleted": 23,
    "certificatesIssued": 9,

    // Top performers (anonymized or named based on privacy settings)
    "topPerformers": [
      {
        "userId": "usr_101",
        "userName": "Alice Johnson", // Only shown if allowLeaderboardDisplay=true
        "metric": "completion_rate",
        "value": 1.0,
        "coursesCompleted": 3
      },
      {
        "userId": "usr_102",
        "userName": "Bob Williams",
        "metric": "assessment_score",
        "value": 95.5,
        "coursesCompleted": 2
      }
    ],

    "calculatedAt": "2025-01-31T23:59:59Z"
  },

  // Individual member progress (respects privacy settings)
  "memberProgress": [
    {
      "userId": "usr_101",
      "userName": "Alice Johnson",
      "enrollmentsCount": 3,
      "avgProgress": 100,
      "lessonsCompleted": 45,
      "lastActiveAt": "2025-01-31T16:45:00Z",
      "certificatesEarned": 3,
      "avgAssessmentScore": 92.5, // Only shown if allowManagerViewScores=true
      "status": "on_track"
    },
    {
      "userId": "usr_102",
      "userName": "Bob Williams",
      "enrollmentsCount": 2,
      "avgProgress": 85,
      "lessonsCompleted": 38,
      "lastActiveAt": "2025-01-30T14:20:00Z",
      "certificatesEarned": 2,
      "avgAssessmentScore": 88.0,
      "status": "on_track"
    },
    {
      "userId": "usr_103",
      "userName": "Carol Davis",
      "enrollmentsCount": 2,
      "avgProgress": 35,
      "lessonsCompleted": 12,
      "lastActiveAt": "2025-01-24T09:15:00Z",
      "certificatesEarned": 0,
      "avgAssessmentScore": null, // No assessments completed
      "status": "behind_schedule",
      "daysInactive": 7
    }
  ],

  "targetCourses": [
    {
      "courseId": "crs_xyz",
      "courseTitle": "AI Marketing Fundamentals",
      "targetCompletionDate": "2025-02-28T23:59:59Z",
      "enrolledCount": 12,
      "completedCount": 4,
      "inProgressCount": 8,
      "avgProgress": 62.5
    }
  ]
}
```

### Get Skills Heat Map

```typescript
GET /api/v1/teams/:teamId/skills-heatmap
Scopes: admin:analytics
Requirement: User must have manager role for this team

// Query parameters
?courseIds=crs_001,crs_002  // Optional: filter by specific courses
&skillIds=skl_001,skl_002   // Optional: filter by specific skills

// Response (200 OK)
{
  "teamId": "team_001",
  "teamName": "Marketing Team",
  "organizationId": "org_abc123",
  "memberCount": 12,

  "skills": [
    {
      "skillId": "skl_001",
      "skillName": "AI Concepts",
      "category": "fundamentals",
      "proficiencyLevels": {
        "none": 1,        // Members with no progress
        "foundational": 2, // Beginner level
        "practitioner": 5, // Intermediate level
        "advanced": 3,     // Advanced level
        "expert": 1        // Expert level
      },
      "avgProficiency": 2.67, // 0-4 scale
      "coveragePercent": 0.92, // 11/12 members have some level
      "completionPercent": 0.33 // 4/12 members at advanced/expert
    },
    {
      "skillId": "skl_002",
      "skillName": "Prompt Engineering",
      "category": "practitioner",
      "proficiencyLevels": {
        "none": 3,
        "foundational": 4,
        "practitioner": 3,
        "advanced": 2,
        "expert": 0
      },
      "avgProficiency": 1.83,
      "coveragePercent": 0.75,
      "completionPercent": 0.17
    },
    {
      "skillId": "skl_003",
      "skillName": "Use Case Identification",
      "category": "strategic",
      "proficiencyLevels": {
        "none": 5,
        "foundational": 3,
        "practitioner": 2,
        "advanced": 1,
        "expert": 1
      },
      "avgProficiency": 1.42,
      "coveragePercent": 0.58,
      "completionPercent": 0.17
    }
  ],

  "skillGaps": [
    {
      "skillId": "skl_003",
      "skillName": "Use Case Identification",
      "coveragePercent": 0.58,
      "recommendation": "Consider enrolling more team members in AI Strategy courses",
      "suggestedCourses": ["crs_005", "crs_006"]
    }
  ],

  "heatmapMatrix": [
    // Visual representation: skills (rows) x proficiency levels (columns)
    ["skl_001", 1, 2, 5, 3, 1], // [skillId, none, foundational, practitioner, advanced, expert]
    ["skl_002", 3, 4, 3, 2, 0],
    ["skl_003", 5, 3, 2, 1, 1]
  ],

  "generatedAt": "2025-01-31T18:00:00Z"
}
```

### Generate Manager Report

```typescript
POST /api/v1/reports
Scopes: admin:analytics
Requirement: User must have export_reports permission

// Request
{
  "reportType": "progress_summary", // progress_summary, individual_detail, skill_matrix, roi_analysis, engagement, compliance
  "organizationId": "org_abc123",
  "name": "January Progress Report",
  "description": "Monthly progress summary for executive review",

  // Filters
  "teamIds": ["team_001", "team_002"], // Optional: specific teams
  "courseIds": ["crs_xyz"], // Optional: specific courses
  "dateRange": {
    "start": "2025-01-01T00:00:00Z",
    "end": "2025-01-31T23:59:59Z"
  },

  // Schedule (optional - for recurring reports)
  "isScheduled": false,
  "scheduleFrequency": "weekly", // daily, weekly, monthly
  "recipients": ["manager@acme.com", "sponsor@acme.com"], // Email addresses

  // Output format
  "format": "pdf" // pdf, csv, xlsx
}

// Response (201 Created)
{
  "reportId": "rpt_abc123",
  "reportType": "progress_summary",
  "status": "generating", // generating, completed, failed
  "estimatedCompletionAt": "2025-01-31T18:05:00Z",
  "createdAt": "2025-01-31T18:00:00Z"
}
```

### Get Generated Report

```typescript
GET /api/v1/reports/:reportId
Scopes: admin:analytics
Requirement: User must have export_reports permission

// Response (200 OK)
{
  "reportId": "rpt_abc123",
  "organizationId": "org_abc123",
  "createdBy": "usr_789",
  "createdByName": "John Smith",

  "name": "January Progress Report",
  "description": "Monthly progress summary for executive review",
  "reportType": "progress_summary",

  // Filters applied
  "teamIds": ["team_001", "team_002"],
  "courseIds": ["crs_xyz"],
  "dateRange": {
    "start": "2025-01-01T00:00:00Z",
    "end": "2025-01-31T23:59:59Z"
  },

  // Generation status
  "status": "completed", // generating, completed, failed
  "format": "pdf",
  "fileId": "file_abc123", // Convex storage ID
  "downloadUrl": "https://api.aienablement.academy/v1/reports/rpt_abc123/download",
  "expiresAt": "2025-02-07T18:00:00Z", // 7 days from generation

  // Scheduling info (if applicable)
  "isScheduled": false,
  "scheduleFrequency": null,
  "recipients": null,
  "lastSentAt": null,
  "nextSendAt": null,

  // Summary metrics (preview)
  "summary": {
    "teamsIncluded": 2,
    "learnersIncluded": 37,
    "coursesIncluded": 1,
    "totalEnrollments": 45,
    "completionRate": 0.68,
    "avgLearningGain": 0.55
  },

  "generatedAt": "2025-01-31T18:03:45Z",
  "createdAt": "2025-01-31T18:00:00Z",
  "updatedAt": "2025-01-31T18:03:45Z"
}

// Download endpoint
GET /api/v1/reports/:reportId/download
// Returns file with appropriate Content-Type and Content-Disposition headers
```

### Send Learning Reminder

```typescript
POST /api/v1/reminders
Scopes: admin:analytics
Requirement: User must have send_reminders permission

// Request
{
  "organizationId": "org_abc123",
  "targetType": "behind_schedule", // individual, team, behind_schedule, inactive

  // Target users (for individual targeting)
  "targetUserIds": ["usr_101", "usr_102"], // Optional

  // Target teams (for team targeting)
  "targetTeamIds": ["team_001"], // Optional

  // Auto-targeting criteria
  "inactivityDays": 7, // For inactive targeting
  "progressThreshold": 50, // For behind_schedule targeting (%)

  // Message
  "subject": "Complete Your AI Training by Month End",
  "message": "Hi {name},\n\nYou're doing great so far! We noticed you're {progress}% through the AI Fundamentals course. The team deadline is coming up on February 28th.\n\nLet's finish strong!\n\nBest,\n{managerName}",
  "includeProgress": true, // Include individual progress stats

  // Delivery
  "channel": "both", // email, in_app, both
  "sendAt": "2025-02-01T09:00:00Z" // Optional: schedule for future
}

// Response (201 Created)
{
  "reminderId": "rem_abc123",
  "organizationId": "org_abc123",
  "sentBy": "usr_789",
  "sentByName": "John Smith",

  "targetType": "behind_schedule",
  "recipientCount": 8, // Users who met criteria
  "recipients": [
    {
      "userId": "usr_103",
      "userName": "Carol Davis",
      "email": "carol@acme.com",
      "status": "sent"
    }
    // ... more recipients
  ],

  "subject": "Complete Your AI Training by Month End",
  "channel": "both",
  "sentAt": "2025-02-01T09:00:00Z",
  "createdAt": "2025-02-01T08:55:00Z"
}

// Error responses
// 403 Forbidden - Insufficient permissions
{
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "You do not have permission to send reminders",
    "details": {
      "requiredPermission": "send_reminders",
      "currentPermissions": ["view_progress", "view_analytics"]
    }
  }
}
```

### Get Privacy Settings

```typescript
GET /api/v1/users/:userId/privacy-settings
Scopes: enrollments:read
Requirement: User must be self or have admin:analytics scope

// Response (200 OK)
{
  "userId": "usr_123",
  "privacySettings": {
    "allowManagerViewScores": true,      // Managers can see assessment scores
    "allowManagerViewActivity": true,    // Managers can see activity timestamps
    "allowManagerViewCertificates": true, // Managers can see certificate status
    "allowLeaderboardDisplay": false,    // Opt-out of leaderboards
    "updatedAt": "2025-01-15T10:00:00Z"
  },

  "organizationId": "org_abc123",
  "organizationName": "Acme Corporation",
  "managersWithAccess": [
    {
      "managerId": "usr_789",
      "managerName": "John Smith",
      "role": "manager",
      "permissions": ["view_progress", "view_scores", "view_analytics", "send_reminders"]
    }
  ]
}
```

### Update Privacy Settings

```typescript
PUT /api/v1/users/:userId/privacy-settings
Scopes: enrollments:read
Requirement: User must be self

// Request
{
  "allowManagerViewScores": false,      // Opt-out of score visibility
  "allowManagerViewActivity": true,     // Keep activity visible
  "allowManagerViewCertificates": true,
  "allowLeaderboardDisplay": false
}

// Response (200 OK)
{
  "userId": "usr_123",
  "privacySettings": {
    "allowManagerViewScores": false,
    "allowManagerViewActivity": true,
    "allowManagerViewCertificates": true,
    "allowLeaderboardDisplay": false,
    "updatedAt": "2025-01-31T18:30:00Z"
  },
  "message": "Privacy settings updated successfully"
}

// Note: Changes take effect immediately
// Managers will see "[Privacy Protected]" for restricted data
```

---

### Additional Skills API Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| **404** | `SKILL_NOT_FOUND` | Skill does not exist |
| **404** | `COMPETENCY_NOT_FOUND` | Competency does not exist |
| **404** | `BADGE_NOT_FOUND` | Badge not found or revoked |
| **403** | `SKILL_VERIFICATION_REQUIRED` | Skill assessment requires instructor verification |
| **409** | `BADGE_ALREADY_EARNED` | User already has this skill badge at this level |
| **422** | `INSUFFICIENT_COMPETENCIES` | Not all competencies achieved for badge issuance |

### Additional Resources API Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| **404** | `RESOURCE_NOT_FOUND` | Resource does not exist |
| **404** | `PROMPT_NOT_FOUND` | Prompt does not exist |
| **404** | `GLOSSARY_TERM_NOT_FOUND` | Glossary term does not exist |
| **403** | `INSUFFICIENT_ACCESS` | User lacks required access level for resource |
| **403** | `ENROLLMENT_REQUIRED` | Resource requires enrollment in specific course |
| **403** | `PREMIUM_REQUIRED` | Resource requires premium subscription |
| **409** | `BOOKMARK_ALREADY_EXISTS` | User already bookmarked this resource |

### Assessments API Error Codes (v2.1)

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| **404** | `ASSESSMENT_NOT_FOUND` | Assessment does not exist |
| **404** | `ATTEMPT_NOT_FOUND` | Assessment attempt does not exist |
| **404** | `QUESTION_NOT_FOUND` | Assessment question does not exist |
| **403** | `ENROLLMENT_REQUIRED` | User must be enrolled in course to access assessment |
| **409** | `MAX_ATTEMPTS_REACHED` | User has reached maximum attempts for assessment |
| **409** | `ATTEMPT_IN_PROGRESS` | User has an active attempt for this assessment |
| **409** | `ATTEMPT_ALREADY_COMPLETED` | Attempt has already been submitted |
| **410** | `ATTEMPT_EXPIRED` | Assessment attempt time limit expired |
| **422** | `INVALID_RESPONSE_FORMAT` | Response format does not match question type |

### Manager Dashboard API Error Codes (v2.1 - B2B)

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| **404** | `ORGANIZATION_NOT_FOUND` | Organization does not exist |
| **404** | `TEAM_NOT_FOUND` | Team does not exist |
| **404** | `REPORT_NOT_FOUND` | Report does not exist |
| **404** | `REMINDER_NOT_FOUND` | Reminder does not exist |
| **403** | `PERMISSION_DENIED` | User lacks required manager permission |
| **403** | `PRIVACY_PROTECTED` | User privacy settings prevent access to requested data |
| **403** | `TEAM_ACCESS_DENIED` | Manager does not have access to this team |
| **409** | `REPORT_GENERATING` | Report is currently being generated |
| **422** | `INVALID_DATE_RANGE` | Date range exceeds maximum allowed period |
| **422** | `INVALID_REPORT_TYPE` | Report type not supported for selected filters |
| **429** | `REMINDER_RATE_LIMIT` | Too many reminders sent in short period |

---

**End of Platform API Specification**
