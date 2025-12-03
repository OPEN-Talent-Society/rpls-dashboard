# 8. MCP Server Specification

## 8.1 MCP Server Overview

The AI Enablement Academy provides a Model Context Protocol (MCP) server to enable AI agents (like Claude Code) to interact with the platform programmatically.

### Purpose
- Enable AI agents to query and interact with Academy data
- Provide learners with conversational access to their courses
- Enable administrators to manage cohorts and enrollments via AI tools
- Support integration with external AI workflows

### Transport Protocols
- **stdio**: Primary protocol for Claude Code integration
- **HTTP**: Secondary protocol for web-based MCP clients (future)

### Authentication
- API keys with scope-based permissions
- User-associated keys for learner operations
- Admin keys for management operations
- JWT tokens for session-based access (HTTP only)

### Rate Limiting
- Default: 60 requests/minute per API key
- Chat operations: 20 requests/minute per user
- Admin operations: 120 requests/minute per API key
- Burst allowance: 10 requests (1 second window)

### Server Configuration
```typescript
{
  name: "ai-enablement-academy",
  version: "1.0.0",
  description: "MCP server for AI Enablement Academy platform",
  vendor: "AI Enablement Academy",
  capabilities: {
    tools: true,
    resources: true,
    prompts: false,
    logging: true
  }
}
```

---

## 8.2 Tool Definitions

The MCP server exposes 10 tools divided into learner operations (6 tools) and admin operations (4 tools).

### Learner Tools

#### 8.2.1 Get Enrollments
Retrieves user's course enrollments with access status and progress information.

```typescript
{
  name: "academy_get_enrollments",
  description: "Get user's course enrollments with access status, progress, and cohort information",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      status: {
        type: "string",
        enum: ["active", "completed", "expired", "all"],
        description: "Filter by enrollment status (default: active)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  enrollments: [
    {
      id: "enr_123",
      courseId: "crs_ai_foundations",
      courseName: "AI Foundations for Business Leaders",
      cohortId: "coh_456",
      cohortName: "December 2024 Cohort",
      status: "active",
      enrolledAt: "2024-12-01T10:00:00Z",
      expiresAt: "2025-02-01T10:00:00Z",
      progress: {
        materialsAccessed: 12,
        totalMaterials: 15,
        chatMessages: 45,
        officeHoursBooked: 2,
        certificateEarned: false
      },
      access: {
        materials: true,
        chat: true,
        officeHours: true,
        certificate: false
      }
    }
  ]
}
```

**Required Scope:** `enrollments:read`

---

#### 8.2.2 Get Course Materials
Retrieves enablement kit items (slides, prompts, templates, worksheets) for a course.

```typescript
{
  name: "academy_get_materials",
  description: "Get enablement kit items for a course (slides, prompts, templates, worksheets)",
  inputSchema: {
    type: "object",
    properties: {
      courseId: {
        type: "string",
        description: "Course ID"
      },
      type: {
        type: "string",
        enum: ["slides", "prompts", "template", "worksheet", "all"],
        description: "Material type filter (default: all)"
      },
      format: {
        type: "string",
        enum: ["metadata", "content", "download_url"],
        description: "Response format (default: metadata)"
      }
    },
    required: ["courseId"]
  }
}
```

**Response Format:**
```typescript
{
  materials: [
    {
      id: "mat_789",
      type: "slides",
      name: "Module 1: AI Fundamentals",
      description: "Introduction to AI concepts and business applications",
      format: "pdf",
      size: 2458624, // bytes
      pageCount: 45,
      downloadUrl: "https://academy.com/materials/mat_789/download?token=xxx",
      expiresAt: "2024-12-02T10:00:00Z", // download link expiry
      metadata: {
        module: 1,
        session: "Day 1 Morning",
        tags: ["fundamentals", "business-value"]
      }
    },
    {
      id: "mat_790",
      type: "prompts",
      name: "Prompt Engineering Templates",
      description: "50 ready-to-use prompts for business scenarios",
      format: "markdown",
      size: 125440,
      downloadUrl: "https://academy.com/materials/mat_790/download?token=yyy",
      expiresAt: "2024-12-02T10:00:00Z",
      metadata: {
        promptCount: 50,
        categories: ["analysis", "writing", "strategy"]
      }
    }
  ]
}
```

**Required Scope:** `materials:read`

**Access Control:** User must have active enrollment in the course

---

#### 8.2.3 Chat with Course Knowledge
Send questions to the course chatbot powered by RAG (Retrieval-Augmented Generation).

```typescript
{
  name: "academy_chat",
  description: "Ask questions about course content using RAG-powered chatbot",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Enrollment ID for context"
      },
      message: {
        type: "string",
        description: "User question or message"
      },
      conversationId: {
        type: "string",
        description: "Optional conversation ID to continue existing chat"
      },
      includeContext: {
        type: "boolean",
        description: "Include retrieved context chunks in response (default: false)"
      }
    },
    required: ["enrollmentId", "message"]
  }
}
```

**Response Format:**
```typescript
{
  conversationId: "conv_abc123",
  messageId: "msg_def456",
  response: {
    text: "Prompt engineering is the practice of designing and refining inputs to AI models...",
    confidence: 0.92,
    sources: [
      {
        materialId: "mat_789",
        materialName: "Module 1: AI Fundamentals",
        page: 12,
        relevanceScore: 0.89
      }
    ]
  },
  context: [ // Only if includeContext: true
    {
      text: "Prompt engineering involves...",
      source: "mat_789",
      page: 12
    }
  ],
  metadata: {
    tokensUsed: 1250,
    processingTime: 850 // milliseconds
  }
}
```

**Required Scope:** `chat:write`

**Rate Limit:** 20 requests/minute per user

---

#### 8.2.4 Get Office Hours Availability
Retrieve available office hours slots for booking.

```typescript
{
  name: "academy_get_availability",
  description: "Get available office hours slots for a course enrollment",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Enrollment ID"
      },
      dateRange: {
        type: "object",
        properties: {
          start: { type: "string", format: "date", description: "Start date (YYYY-MM-DD)" },
          end: { type: "string", format: "date", description: "End date (YYYY-MM-DD)" }
        },
        description: "Optional date range (defaults to next 30 days)"
      },
      timezone: {
        type: "string",
        description: "IANA timezone (e.g., America/New_York, default: user's timezone)"
      }
    },
    required: ["enrollmentId"]
  }
}
```

**Response Format:**
```typescript
{
  slots: [
    {
      id: "slot_123",
      startTime: "2024-12-05T14:00:00Z",
      endTime: "2024-12-05T14:30:00Z",
      duration: 30, // minutes
      type: "1-on-1",
      instructor: {
        id: "ins_789",
        name: "Sarah Johnson",
        title: "Senior AI Enablement Instructor"
      },
      available: true,
      capacity: 1,
      booked: 0
    },
    {
      id: "slot_124",
      startTime: "2024-12-05T15:00:00Z",
      endTime: "2024-12-05T16:00:00Z",
      duration: 60,
      type: "group",
      instructor: {
        id: "ins_789",
        name: "Sarah Johnson",
        title: "Senior AI Enablement Instructor"
      },
      available: true,
      capacity: 5,
      booked: 3
    }
  ],
  metadata: {
    totalSlots: 24,
    availableSlots: 18,
    userBookedCount: 2,
    userBookingLimit: 4
  }
}
```

**Required Scope:** `bookings:read`

---

#### 8.2.5 Book Office Hours
Book an office hours session.

```typescript
{
  name: "academy_book_office_hours",
  description: "Book an office hours session with an instructor",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Enrollment ID"
      },
      slotId: {
        type: "string",
        description: "Slot ID from availability response"
      },
      topic: {
        type: "string",
        description: "Optional topic or question for the session"
      },
      sendReminder: {
        type: "boolean",
        description: "Send email reminder (default: true)"
      }
    },
    required: ["enrollmentId", "slotId"]
  }
}
```

**Response Format:**
```typescript
{
  booking: {
    id: "book_456",
    slotId: "slot_123",
    enrollmentId: "enr_123",
    status: "confirmed",
    startTime: "2024-12-05T14:00:00Z",
    endTime: "2024-12-05T14:30:00Z",
    meetingUrl: "https://meet.academy.com/book_456",
    instructor: {
      id: "ins_789",
      name: "Sarah Johnson",
      email: "sarah@academy.com"
    },
    calendarInvite: {
      icsUrl: "https://academy.com/bookings/book_456/calendar.ics"
    }
  }
}
```

**Required Scope:** `bookings:write`

**Side Effects:**
- Sends confirmation email to user
- Sends notification to instructor
- Creates calendar event

---

#### 8.2.6 Get Certificate
Retrieve certificate details and verification URL.

```typescript
{
  name: "academy_get_certificate",
  description: "Get certificate details and verification URL for completed enrollment",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Enrollment ID"
      },
      format: {
        type: "string",
        enum: ["metadata", "pdf_url", "image_url"],
        description: "Response format (default: metadata)"
      }
    },
    required: ["enrollmentId"]
  }
}
```

**Response Format:**
```typescript
{
  certificate: {
    id: "cert_789",
    enrollmentId: "enr_123",
    status: "issued",
    issuedAt: "2024-12-15T10:00:00Z",
    verificationUrl: "https://academy.com/verify/cert_789",
    credential: {
      type: "completion",
      courseName: "AI Foundations for Business Leaders",
      learnerName: "John Doe",
      completionDate: "2024-12-15",
      credentialId: "AIEA-2024-123456"
    },
    downloads: {
      pdf: "https://academy.com/certificates/cert_789.pdf?token=xxx",
      png: "https://academy.com/certificates/cert_789.png?token=xxx",
      svg: "https://academy.com/certificates/cert_789.svg?token=xxx"
    },
    blockchain: {
      network: "polygon",
      contractAddress: "0x...",
      tokenId: "123456",
      txHash: "0x...",
      explorerUrl: "https://polygonscan.com/tx/0x..."
    }
  }
}
```

**Required Scope:** `certificates:read`

**Access Control:** User must have completed the course

---

### Admin Tools

#### 8.2.7 List Cohorts
List cohorts with filtering and pagination.

```typescript
{
  name: "academy_admin_list_cohorts",
  description: "List all cohorts with filters (admin only)",
  inputSchema: {
    type: "object",
    properties: {
      status: {
        type: "string",
        enum: ["scheduled", "open", "in_progress", "completed", "all"],
        description: "Filter by cohort status (default: all)"
      },
      courseId: {
        type: "string",
        description: "Filter by course ID"
      },
      limit: {
        type: "number",
        default: 50,
        description: "Number of results per page (max: 100)"
      },
      offset: {
        type: "number",
        default: 0,
        description: "Pagination offset"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  cohorts: [
    {
      id: "coh_456",
      courseId: "crs_ai_foundations",
      courseName: "AI Foundations for Business Leaders",
      name: "December 2024 Cohort",
      status: "in_progress",
      schedule: {
        startDate: "2024-12-01",
        endDate: "2024-12-15",
        sessions: [
          { date: "2024-12-01", type: "in-person" },
          { date: "2024-12-02", type: "in-person" }
        ]
      },
      enrollments: {
        total: 24,
        active: 22,
        completed: 0,
        dropped: 2
      },
      capacity: {
        max: 25,
        available: 1
      }
    }
  ],
  pagination: {
    total: 156,
    limit: 50,
    offset: 0,
    hasMore: true
  }
}
```

**Required Scope:** `admin:cohorts`

---

#### 8.2.8 Get Enrollment Statistics
Get detailed enrollment statistics for a cohort.

```typescript
{
  name: "academy_admin_enrollment_stats",
  description: "Get enrollment statistics and analytics for a cohort (admin only)",
  inputSchema: {
    type: "object",
    properties: {
      cohortId: {
        type: "string",
        description: "Cohort ID"
      },
      metrics: {
        type: "array",
        items: {
          type: "string",
          enum: ["engagement", "materials", "chat", "office_hours", "completion"]
        },
        description: "Metrics to include (default: all)"
      }
    },
    required: ["cohortId"]
  }
}
```

**Response Format:**
```typescript
{
  cohortId: "coh_456",
  period: {
    start: "2024-12-01T00:00:00Z",
    end: "2024-12-15T23:59:59Z"
  },
  enrollments: {
    total: 24,
    active: 22,
    completed: 0,
    dropped: 2,
    b2b: 18,
    b2c: 6
  },
  engagement: {
    averageMaterialsAccessed: 12.5,
    averageChatMessages: 45.2,
    averageOfficeHoursBooked: 2.1,
    activeUsers: {
      daily: 18,
      weekly: 22
    }
  },
  materials: {
    mostAccessed: [
      { id: "mat_789", name: "Module 1 Slides", accessCount: 88 }
    ],
    downloadRate: 0.85 // 85% of enrollees downloaded materials
  },
  chat: {
    totalMessages: 1085,
    averageResponseTime: 2.4, // seconds
    satisfactionScore: 4.7, // out of 5
    topTopics: ["prompt engineering", "use cases", "implementation"]
  },
  officeHours: {
    totalBookings: 51,
    completedSessions: 48,
    noShows: 3,
    averageRating: 4.9
  },
  completion: {
    onTrack: 20,
    atRisk: 2,
    projectedCompletionRate: 0.91 // 91%
  }
}
```

**Required Scope:** `admin:enrollments`

---

#### 8.2.9 Send Bulk Email
Send templated email to cohort enrollees.

```typescript
{
  name: "academy_admin_send_email",
  description: "Send templated email to cohort enrollees (admin only)",
  inputSchema: {
    type: "object",
    properties: {
      cohortId: {
        type: "string",
        description: "Cohort ID (required if enrollmentIds not provided)"
      },
      enrollmentIds: {
        type: "array",
        items: { type: "string" },
        description: "Specific enrollment IDs (overrides cohortId)"
      },
      templateId: {
        type: "number",
        description: "Brevo template ID"
      },
      params: {
        type: "object",
        description: "Template variables (e.g., {cohortName, startDate})"
      },
      scheduledAt: {
        type: "string",
        format: "date-time",
        description: "Schedule email for later (optional)"
      },
      dryRun: {
        type: "boolean",
        description: "Test mode - don't actually send (default: false)"
      }
    },
    required: ["templateId", "params"]
  }
}
```

**Response Format:**
```typescript
{
  campaign: {
    id: "camp_123",
    status: "sent", // or "scheduled"
    sentAt: "2024-12-02T10:00:00Z",
    recipients: {
      total: 24,
      sent: 24,
      failed: 0
    },
    template: {
      id: 42,
      name: "Cohort Welcome Email"
    },
    dryRun: false
  },
  errors: [] // Array of errors if any sends failed
}
```

**Required Scope:** `admin:email`

**Rate Limit:** Special handling - queued for batch processing

---

#### 8.2.10 Create Manual Enrollment
Create B2B enrollment for a user (manual enrollment for corporate partners).

```typescript
{
  name: "academy_admin_create_enrollment",
  description: "Create B2B enrollment for a user (admin only)",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (will create user if doesn't exist)"
      },
      email: {
        type: "string",
        format: "email",
        description: "User email (required if userId not provided)"
      },
      cohortId: {
        type: "string",
        description: "Cohort ID"
      },
      organizationId: {
        type: "string",
        description: "Organization ID for B2B enrollment"
      },
      sendWelcomeEmail: {
        type: "boolean",
        description: "Send welcome email to user (default: true)"
      },
      metadata: {
        type: "object",
        description: "Additional metadata (e.g., employee ID, department)"
      }
    },
    required: ["cohortId", "organizationId"]
  }
}
```

**Response Format:**
```typescript
{
  enrollment: {
    id: "enr_789",
    userId: "usr_456",
    cohortId: "coh_123",
    organizationId: "org_789",
    status: "active",
    createdAt: "2024-12-02T10:00:00Z",
    expiresAt: "2025-02-01T10:00:00Z",
    access: {
      materials: true,
      chat: true,
      officeHours: true
    }
  },
  user: {
    id: "usr_456",
    email: "john@company.com",
    created: false // true if user was created, false if existed
  },
  notifications: {
    welcomeEmailSent: true
  }
}
```

**Required Scope:** `admin:enrollments`

**Side Effects:**
- Creates user if doesn't exist
- Sends welcome email (if enabled)
- Decrements cohort capacity

---

## 8.3 Resource URIs

Resources provide read-only context accessible via URI patterns.

### 8.3.1 Resource Definitions

```typescript
{
  name: "academy_resources",
  resources: [
    {
      uri: "academy://courses",
      name: "Course Catalog",
      description: "List of all published courses with metadata",
      mimeType: "application/json"
    },
    {
      uri: "academy://courses/{courseId}",
      name: "Course Detail",
      description: "Detailed course information including syllabus and enablement kit",
      mimeType: "application/json"
    },
    {
      uri: "academy://enrollments/{userId}",
      name: "User Enrollments",
      description: "Complete enrollment history for a user",
      mimeType: "application/json"
    },
    {
      uri: "academy://cohorts/{cohortId}/roster",
      name: "Cohort Roster",
      description: "List of enrolled users with progress (admin only)",
      mimeType: "application/json"
    },
    {
      uri: "academy://organizations/{orgId}/dashboard",
      name: "Organization Dashboard",
      description: "B2B organization metrics and enrollment data (admin only)",
      mimeType: "application/json"
    }
  ]
}
```

### 8.3.2 Resource Response Formats

#### Course Catalog (academy://courses)
```typescript
{
  courses: [
    {
      id: "crs_ai_foundations",
      title: "AI Foundations for Business Leaders",
      description: "Comprehensive introduction to AI for business professionals",
      format: "2-day intensive",
      level: "beginner",
      enablementKit: {
        slides: 4,
        prompts: 1,
        templates: 2,
        worksheets: 3
      },
      pricing: {
        b2c: 2500,
        b2b: 2000
      },
      nextCohort: {
        id: "coh_456",
        startDate: "2024-12-15",
        spotsAvailable: 8
      }
    }
  ]
}
```

#### Course Detail (academy://courses/{courseId})
```typescript
{
  id: "crs_ai_foundations",
  title: "AI Foundations for Business Leaders",
  description: "Comprehensive introduction to AI for business professionals",
  syllabus: {
    day1: [
      {
        time: "9:00 AM - 12:00 PM",
        topic: "AI Fundamentals & Business Value",
        activities: ["Lecture", "Case Studies", "Group Discussion"]
      }
    ],
    day2: [
      {
        time: "9:00 AM - 12:00 PM",
        topic: "Practical AI Implementation",
        activities: ["Hands-on Workshop", "Prompt Engineering Lab"]
      }
    ]
  },
  enablementKit: [
    {
      id: "mat_789",
      type: "slides",
      name: "Module 1: AI Fundamentals",
      description: "Introduction to AI concepts"
    }
  ],
  instructors: [
    {
      id: "ins_789",
      name: "Sarah Johnson",
      bio: "15 years experience in AI education"
    }
  ]
}
```

#### User Enrollments (academy://enrollments/{userId})
```typescript
{
  userId: "usr_456",
  enrollments: [
    {
      id: "enr_123",
      courseId: "crs_ai_foundations",
      cohortId: "coh_456",
      status: "active",
      enrolledAt: "2024-12-01T10:00:00Z",
      progress: {
        materialsAccessed: 12,
        chatMessages: 45,
        officeHoursBooked: 2
      }
    }
  ],
  statistics: {
    totalEnrollments: 3,
    completedCourses: 1,
    certificatesEarned: 1
  }
}
```

#### Cohort Roster (academy://cohorts/{cohortId}/roster) - Admin Only
```typescript
{
  cohortId: "coh_456",
  enrollments: [
    {
      id: "enr_123",
      user: {
        id: "usr_456",
        email: "john@company.com",
        name: "John Doe"
      },
      organization: {
        id: "org_789",
        name: "Acme Corp"
      },
      status: "active",
      progress: {
        materialsAccessed: 12,
        totalMaterials: 15,
        engagementScore: 0.87
      }
    }
  ]
}
```

#### Organization Dashboard (academy://organizations/{orgId}/dashboard) - Admin Only
```typescript
{
  organizationId: "org_789",
  name: "Acme Corp",
  enrollments: {
    total: 156,
    active: 42,
    completed: 114
  },
  engagement: {
    averageMaterialsAccessed: 14.2,
    averageChatMessages: 52.1,
    completionRate: 0.94
  },
  cohorts: [
    {
      cohortId: "coh_456",
      courseName: "AI Foundations",
      enrollmentCount: 24,
      status: "in_progress"
    }
  ]
}
```

---

## 8.4 Authentication & Scopes

### 8.4.1 Scope Definitions

```typescript
const SCOPES = {
  // Learner scopes
  "enrollments:read": {
    description: "Read enrollment data for authenticated user",
    tools: ["academy_get_enrollments"],
    resources: ["academy://enrollments/{userId}"]
  },
  "materials:read": {
    description: "Access course materials and enablement kits",
    tools: ["academy_get_materials"],
    resources: ["academy://courses", "academy://courses/{courseId}"]
  },
  "chat:write": {
    description: "Send chat messages to course chatbot",
    tools: ["academy_chat"],
    rateLimit: "20/min"
  },
  "bookings:read": {
    description: "View office hours availability",
    tools: ["academy_get_availability"]
  },
  "bookings:write": {
    description: "Create office hours bookings",
    tools: ["academy_book_office_hours"]
  },
  "certificates:read": {
    description: "Access earned certificates",
    tools: ["academy_get_certificate"]
  },

  // Admin scopes
  "admin:cohorts": {
    description: "Manage cohorts and view all cohort data",
    tools: ["academy_admin_list_cohorts"],
    resources: ["academy://cohorts/{cohortId}/roster"]
  },
  "admin:enrollments": {
    description: "Manage enrollments and view enrollment statistics",
    tools: ["academy_admin_enrollment_stats", "academy_admin_create_enrollment"]
  },
  "admin:email": {
    description: "Send bulk emails to enrollees",
    tools: ["academy_admin_send_email"]
  },
  "admin:organizations": {
    description: "Manage B2B organizations and view dashboards",
    tools: [],
    resources: ["academy://organizations/{orgId}/dashboard"]
  }
};
```

### 8.4.2 API Key Format

```typescript
// API key structure
{
  apiKey: "sk_mcp_live_abc123...", // Live key
  // or
  apiKey: "sk_mcp_test_xyz789...", // Test key

  scopes: [
    "enrollments:read",
    "materials:read",
    "chat:write",
    "bookings:read",
    "bookings:write"
  ],

  userId: "usr_123", // Associated user for learner operations

  metadata: {
    name: "Claude Code Integration",
    createdAt: "2024-12-01T10:00:00Z",
    lastUsedAt: "2024-12-02T10:00:00Z",
    environment: "production" // or "development"
  }
}
```

### 8.4.3 Scope Validation

```typescript
// Tool execution flow
async function executeTool(toolName: string, args: object, apiKey: string) {
  // 1. Validate API key
  const key = await validateApiKey(apiKey);
  if (!key) throw new Error("INVALID_API_KEY");

  // 2. Check required scope
  const requiredScope = getRequiredScope(toolName);
  if (!key.scopes.includes(requiredScope)) {
    throw new Error(`SCOPE_REQUIRED: ${requiredScope}`);
  }

  // 3. Check rate limit
  const allowed = await checkRateLimit(key, requiredScope);
  if (!allowed) throw new Error("RATE_LIMITED");

  // 4. Execute tool
  return await tools[toolName](args, key);
}
```

---

## 8.5 Rate Limiting

### 8.5.1 Rate Limit Tiers

| Scope | Rate | Window | Burst |
|-------|------|--------|-------|
| Default | 60 req/min | 60 seconds | 10 |
| chat:write | 20 req/min | 60 seconds | 5 |
| admin:* | 120 req/min | 60 seconds | 20 |
| materials:read | 30 req/min | 60 seconds | 10 |
| bookings:write | 10 req/min | 60 seconds | 3 |

### 8.5.2 Rate Limit Headers

Every response includes rate limit information:

```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1701518400
X-RateLimit-Scope: enrollments:read
```

### 8.5.3 Rate Limit Response

When rate limit exceeded:

```typescript
{
  error: {
    code: "RATE_LIMITED",
    message: "Rate limit exceeded for scope 'chat:write'",
    retryAfter: 42, // seconds until reset
    limit: {
      scope: "chat:write",
      maxRequests: 20,
      window: 60,
      resetAt: "2024-12-02T10:15:00Z"
    }
  }
}
```

---

## 8.6 Error Handling

### 8.6.1 Error Codes

| Code | HTTP Status | Description | Retry? |
|------|-------------|-------------|--------|
| INVALID_API_KEY | 401 | API key not found or expired | No |
| SCOPE_REQUIRED | 403 | Missing required scope | No |
| RATE_LIMITED | 429 | Too many requests | Yes |
| ACCESS_DENIED | 403 | User doesn't have access to resource | No |
| RESOURCE_NOT_FOUND | 404 | Resource doesn't exist | No |
| VALIDATION_ERROR | 400 | Invalid input parameters | No |
| ENROLLMENT_EXPIRED | 403 | User's enrollment has expired | No |
| COHORT_FULL | 409 | Cohort has reached capacity | No |
| BOOKING_CONFLICT | 409 | Time slot no longer available | No |
| SERVER_ERROR | 500 | Internal server error | Yes |

### 8.6.2 Error Response Format

```typescript
{
  error: {
    code: "SCOPE_REQUIRED",
    message: "This tool requires the 'admin:cohorts' scope",
    details: {
      requiredScope: "admin:cohorts",
      currentScopes: ["enrollments:read", "materials:read"],
      documentation: "https://docs.academy.com/mcp/scopes"
    },
    requestId: "req_abc123", // For support debugging
    timestamp: "2024-12-02T10:00:00Z"
  }
}
```

### 8.6.3 Error Handling Examples

```typescript
// Handling scope errors
try {
  await mcp.callTool("academy_admin_list_cohorts", {});
} catch (error) {
  if (error.code === "SCOPE_REQUIRED") {
    console.log(`Missing scope: ${error.details.requiredScope}`);
    console.log("Request this scope from your API key administrator");
  }
}

// Handling rate limits
try {
  await mcp.callTool("academy_chat", { message: "..." });
} catch (error) {
  if (error.code === "RATE_LIMITED") {
    const waitTime = error.retryAfter;
    console.log(`Rate limited. Retry in ${waitTime} seconds`);
    await sleep(waitTime * 1000);
    // Retry request
  }
}

// Handling enrollment access
try {
  await mcp.callTool("academy_get_materials", { courseId: "crs_123" });
} catch (error) {
  if (error.code === "ACCESS_DENIED") {
    console.log("You need an active enrollment to access these materials");
  }
}
```

---

## 8.7 Example Usage with Claude Code

### 8.7.1 Configuration

Add the MCP server to Claude Code's configuration:

```json
// .claude/mcp.json
{
  "mcpServers": {
    "ai-enablement-academy": {
      "command": "node",
      "args": ["/path/to/academy-mcp-server/dist/index.js"],
      "env": {
        "ACADEMY_API_KEY": "sk_mcp_live_abc123...",
        "ACADEMY_BASE_URL": "https://api.academy.com"
      }
    }
  }
}
```

### 8.7.2 Conversation Examples

#### Example 1: Viewing Enrollments
```
User: What courses am I enrolled in?

Claude: [Uses academy_get_enrollments tool]

Claude: You're enrolled in 2 courses:

1. **AI Foundations for Business Leaders** (December 2024 Cohort)
   - Status: Active
   - Progress: 12/15 materials accessed (80%)
   - Office Hours: 2 booked
   - Expires: February 1, 2025

2. **Advanced Prompt Engineering** (November 2024 Cohort)
   - Status: Completed
   - Certificate: Available for download
   - Completion Date: November 30, 2024
```

#### Example 2: Accessing Materials
```
User: Download the slides from the AI Foundations course

Claude: [Uses academy_get_materials tool with type="slides"]

Claude: I found 4 slide decks from your AI Foundations course:

1. Module 1: AI Fundamentals (45 pages, 2.4 MB)
2. Module 2: Prompt Engineering (38 pages, 1.8 MB)
3. Module 3: Use Case Development (42 pages, 2.1 MB)
4. Module 4: Implementation Strategy (35 pages, 1.6 MB)

I can provide download links for any of these. Which would you like?

User: All of them

Claude: Here are the download links (valid for 24 hours):

1. [Module 1 Slides](https://academy.com/materials/mat_789/download?token=...)
2. [Module 2 Slides](https://academy.com/materials/mat_790/download?token=...)
3. [Module 3 Slides](https://academy.com/materials/mat_791/download?token=...)
4. [Module 4 Slides](https://academy.com/materials/mat_792/download?token=...)
```

#### Example 3: Course Chatbot
```
User: Ask the course chatbot about prompt engineering best practices

Claude: [Uses academy_chat tool]

Claude: Based on your course materials, here are the key prompt engineering best practices:

1. **Be Specific**: Clearly define the task, context, and desired output format
2. **Use Examples**: Provide 2-3 examples of desired output (few-shot learning)
3. **Set Constraints**: Define length, tone, and complexity requirements
4. **Iterate**: Refine prompts based on results - treat it as an iterative process
5. **Test Edge Cases**: Verify prompt performance with unusual inputs

This guidance comes from Module 2 (pages 12-18) of your AI Foundations course.

Would you like me to elaborate on any of these practices?
```

#### Example 4: Booking Office Hours
```
User: Book office hours for next week to discuss implementing AI in my company

Claude: [Uses academy_get_availability tool]

Claude: I found 6 available office hours slots next week:

**1-on-1 Sessions (30 min):**
- Monday, Dec 9 at 2:00 PM EST with Sarah Johnson
- Wednesday, Dec 11 at 10:00 AM EST with Sarah Johnson
- Friday, Dec 13 at 3:00 PM EST with Sarah Johnson

**Group Sessions (60 min):**
- Tuesday, Dec 10 at 11:00 AM EST with Michael Chen (3/5 spots available)
- Thursday, Dec 12 at 2:00 PM EST with Sarah Johnson (1/5 spots available)

Which session works best for you?

User: Monday at 2 PM

Claude: [Uses academy_book_office_hours tool with topic="implementing AI in my company"]

Claude: ✅ Booked! Your office hours session is confirmed:

**Session Details:**
- Date/Time: Monday, December 9, 2024 at 2:00 PM EST
- Duration: 30 minutes
- Instructor: Sarah Johnson
- Topic: Implementing AI in my company
- Meeting Link: https://meet.academy.com/book_456

I've sent a calendar invite to your email. You'll also receive a reminder 24 hours before the session.
```

#### Example 5: Admin Operations
```
User: Show me enrollment stats for the December AI Foundations cohort

Claude: [Uses academy_admin_enrollment_stats tool]

Claude: **December 2024 AI Foundations Cohort Stats**

**Enrollments:**
- Total: 24 (18 B2B, 6 B2C)
- Active: 22
- Dropped: 2

**Engagement (Average per learner):**
- Materials Accessed: 12.5 / 15 (83%)
- Chat Messages: 45.2
- Office Hours Booked: 2.1

**Top Performing Materials:**
1. Module 1 Slides - 88 accesses
2. Prompt Templates - 76 accesses
3. Use Case Worksheet - 68 accesses

**Chat Analytics:**
- Total Messages: 1,085
- Avg Response Time: 2.4 seconds
- Satisfaction Score: 4.7/5
- Top Topics: prompt engineering, use cases, implementation

**Office Hours:**
- Total Bookings: 51
- Completed: 48
- No-shows: 3
- Avg Rating: 4.9/5

**Completion Projection:**
- On Track: 20 learners (91%)
- At Risk: 2 learners (9%)
- Projected Completion Rate: 91%
```

---

## 8.8 Server Implementation

### 8.8.1 Server Entry Point

```typescript
// src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
  ListResourcesRequestSchema
} from "@modelcontextprotocol/sdk/types.js";

// Initialize server
const server = new Server({
  name: "ai-enablement-academy",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {},
    resources: {},
    logging: {}
  }
});

// Configuration from environment
const config = {
  apiKey: process.env.ACADEMY_API_KEY,
  baseUrl: process.env.ACADEMY_BASE_URL || "https://api.academy.com",
  environment: process.env.ACADEMY_ENV || "production"
};

// Validate configuration
if (!config.apiKey) {
  throw new Error("ACADEMY_API_KEY environment variable is required");
}

// Tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "academy_get_enrollments",
        description: "Get user's course enrollments with access status",
        inputSchema: {
          type: "object",
          properties: {
            userId: { type: "string" },
            status: {
              type: "string",
              enum: ["active", "completed", "expired", "all"]
            }
          }
        }
      },
      // ... other tools
    ]
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "academy_get_enrollments":
        return await handleGetEnrollments(args);
      case "academy_get_materials":
        return await handleGetMaterials(args);
      case "academy_chat":
        return await handleChat(args);
      case "academy_get_availability":
        return await handleGetAvailability(args);
      case "academy_book_office_hours":
        return await handleBookOfficeHours(args);
      case "academy_get_certificate":
        return await handleGetCertificate(args);
      case "academy_admin_list_cohorts":
        return await handleAdminListCohorts(args);
      case "academy_admin_enrollment_stats":
        return await handleAdminEnrollmentStats(args);
      case "academy_admin_send_email":
        return await handleAdminSendEmail(args);
      case "academy_admin_create_enrollment":
        return await handleAdminCreateEnrollment(args);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return formatError(error);
  }
});

// Resource handlers
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: "academy://courses",
        name: "Course Catalog",
        mimeType: "application/json"
      },
      {
        uri: "academy://courses/{courseId}",
        name: "Course Detail",
        mimeType: "application/json"
      },
      {
        uri: "academy://enrollments/{userId}",
        name: "User Enrollments",
        mimeType: "application/json"
      },
      {
        uri: "academy://cohorts/{cohortId}/roster",
        name: "Cohort Roster",
        mimeType: "application/json"
      },
      {
        uri: "academy://organizations/{orgId}/dashboard",
        name: "Organization Dashboard",
        mimeType: "application/json"
      }
    ]
  };
});

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  try {
    return await handleResourceRead(uri);
  } catch (error) {
    return formatError(error);
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("AI Enablement Academy MCP Server running on stdio");
}

main().catch(console.error);
```

### 8.8.2 Tool Handlers

```typescript
// src/handlers/enrollments.ts
import { apiClient } from '../api';

export async function handleGetEnrollments(args: any) {
  const { userId, status = "active" } = args;

  // Validate API key and scope
  await validateScope("enrollments:read");

  // Check rate limit
  await checkRateLimit("enrollments:read");

  // Fetch enrollments
  const response = await apiClient.get("/api/enrollments", {
    params: { userId, status }
  });

  return {
    content: [{
      type: "text",
      text: JSON.stringify(response.data, null, 2)
    }]
  };
}

export async function handleGetMaterials(args: any) {
  const { courseId, type = "all", format = "metadata" } = args;

  await validateScope("materials:read");
  await checkRateLimit("materials:read");

  // Verify user has access to course
  await verifyEnrollmentAccess(courseId);

  const response = await apiClient.get(`/api/courses/${courseId}/materials`, {
    params: { type, format }
  });

  return {
    content: [{
      type: "text",
      text: JSON.stringify(response.data, null, 2)
    }]
  };
}

export async function handleChat(args: any) {
  const { enrollmentId, message, conversationId, includeContext = false } = args;

  await validateScope("chat:write");
  await checkRateLimit("chat:write");

  const response = await apiClient.post("/api/chat", {
    enrollmentId,
    message,
    conversationId,
    includeContext
  });

  return {
    content: [{
      type: "text",
      text: JSON.stringify(response.data, null, 2)
    }]
  };
}
```

### 8.8.3 Scope Validation

```typescript
// src/auth/scopes.ts
const SCOPE_MAP = {
  "academy_get_enrollments": "enrollments:read",
  "academy_get_materials": "materials:read",
  "academy_chat": "chat:write",
  "academy_get_availability": "bookings:read",
  "academy_book_office_hours": "bookings:write",
  "academy_get_certificate": "certificates:read",
  "academy_admin_list_cohorts": "admin:cohorts",
  "academy_admin_enrollment_stats": "admin:enrollments",
  "academy_admin_send_email": "admin:email",
  "academy_admin_create_enrollment": "admin:enrollments"
};

export async function validateScope(requiredScope: string) {
  const apiKey = config.apiKey;

  // Fetch API key details from database
  const keyData = await db.apiKeys.findOne({ key: apiKey });

  if (!keyData) {
    throw new MCPError("INVALID_API_KEY", "API key not found or expired");
  }

  if (!keyData.scopes.includes(requiredScope)) {
    throw new MCPError(
      "SCOPE_REQUIRED",
      `This tool requires the '${requiredScope}' scope`,
      { requiredScope, currentScopes: keyData.scopes }
    );
  }

  return keyData;
}
```

### 8.8.4 Rate Limiting

```typescript
// src/ratelimit/index.ts
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

const RATE_LIMITS = {
  "default": { max: 60, window: 60 },
  "chat:write": { max: 20, window: 60 },
  "admin:*": { max: 120, window: 60 }
};

export async function checkRateLimit(scope: string): Promise<void> {
  const key = `ratelimit:${config.apiKey}:${scope}`;
  const limit = RATE_LIMITS[scope] || RATE_LIMITS["default"];

  const current = await redis.incr(key);

  if (current === 1) {
    await redis.expire(key, limit.window);
  }

  if (current > limit.max) {
    const ttl = await redis.ttl(key);
    throw new MCPError(
      "RATE_LIMITED",
      `Rate limit exceeded for scope '${scope}'`,
      { retryAfter: ttl, limit }
    );
  }
}
```

### 8.8.5 Error Formatting

```typescript
// src/errors/index.ts
export class MCPError extends Error {
  constructor(
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message);
  }
}

export function formatError(error: any) {
  if (error instanceof MCPError) {
    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          error: {
            code: error.code,
            message: error.message,
            details: error.details,
            timestamp: new Date().toISOString()
          }
        }, null, 2)
      }],
      isError: true
    };
  }

  // Unknown error
  return {
    content: [{
      type: "text",
      text: JSON.stringify({
        error: {
          code: "SERVER_ERROR",
          message: error.message || "An unexpected error occurred",
          timestamp: new Date().toISOString()
        }
      }, null, 2)
    }],
    isError: true
  };
}
```

---

## 8.9 Testing

### 8.9.1 MCP Inspector

Use the MCP Inspector to test tools during development:

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Test the server
mcp-inspector node dist/index.js
```

### 8.9.2 Integration Tests

```typescript
// tests/integration/tools.test.ts
import { MCPClient } from "@modelcontextprotocol/sdk/client";

describe("MCP Tools", () => {
  let client: MCPClient;

  beforeAll(async () => {
    client = await createTestClient();
  });

  test("academy_get_enrollments returns user enrollments", async () => {
    const result = await client.callTool("academy_get_enrollments", {
      userId: "test_user_123"
    });

    expect(result).toHaveProperty("enrollments");
    expect(Array.isArray(result.enrollments)).toBe(true);
  });

  test("academy_chat requires valid enrollment", async () => {
    await expect(
      client.callTool("academy_chat", {
        enrollmentId: "invalid_enrollment",
        message: "test message"
      })
    ).rejects.toThrow("ACCESS_DENIED");
  });

  test("admin tools require admin scope", async () => {
    await expect(
      client.callTool("academy_admin_list_cohorts", {})
    ).rejects.toThrow("SCOPE_REQUIRED");
  });
});
```

---

## 8.10 Deployment

### 8.10.1 Package Structure

```
academy-mcp-server/
├── src/
│   ├── index.ts              # Server entry point
│   ├── handlers/             # Tool handlers
│   │   ├── enrollments.ts
│   │   ├── materials.ts
│   │   ├── chat.ts
│   │   ├── bookings.ts
│   │   └── admin.ts
│   ├── resources/            # Resource handlers
│   │   └── index.ts
│   ├── auth/                 # Authentication
│   │   └── scopes.ts
│   ├── ratelimit/            # Rate limiting
│   │   └── index.ts
│   └── errors/               # Error handling
│       └── index.ts
├── package.json
├── tsconfig.json
└── README.md
```

### 8.10.2 Package.json

```json
{
  "name": "@academy/mcp-server",
  "version": "1.0.0",
  "type": "module",
  "bin": {
    "academy-mcp": "./dist/index.js"
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "test": "jest"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.5.0",
    "axios": "^1.6.0",
    "ioredis": "^5.3.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.3.0",
    "jest": "^29.7.0"
  }
}
```

### 8.10.3 Distribution

```bash
# Build for production
pnpm run build

# Publish to npm
pnpm publish --access public

# Install in Claude Code
claude mcp add academy pnpm dlx @academy/mcp-server
```

---

## 8.11 Security Considerations

### 8.11.1 API Key Management
- API keys stored hashed in database (bcrypt)
- Key rotation supported (generate new, revoke old)
- Automatic expiration after 90 days (configurable)
- Audit log for all API key usage

### 8.11.2 Data Access Controls
- User can only access their own enrollments (unless admin)
- Materials require active enrollment verification
- Admin tools check organization membership
- Resource URIs enforce access policies

### 8.11.3 Input Validation
- All tool inputs validated against JSON schemas
- SQL injection prevention (parameterized queries)
- XSS prevention (sanitize all user inputs)
- File path traversal prevention (materials downloads)

### 8.11.4 Monitoring
- Log all tool executions with request IDs
- Track failed authentication attempts
- Monitor rate limit violations
- Alert on suspicious patterns

---

## 8.11 v2.1 Feature Tools (Learning Paths, Community, Assessments, Manager Dashboard)

The v2.1 release extends the MCP server with advanced features for structured learning journeys, community engagement, learning measurement, and organizational management.

### Learning Path Tools

#### 8.11.1 Get Learning Paths

Retrieve available learning paths with filtering options.

```typescript
{
  name: "academy_get_learning_paths",
  description: "Get curated learning path sequences with courses and pricing",
  inputSchema: {
    type: "object",
    properties: {
      targetAudience: {
        type: "string",
        enum: ["individual", "team", "enterprise", "all"],
        description: "Filter by target audience"
      },
      isFeatured: {
        type: "boolean",
        description: "Only show featured paths"
      },
      includeProgress: {
        type: "boolean",
        default: false,
        description: "Include user progress (requires userId)"
      },
      userId: {
        type: "string",
        description: "User ID for progress tracking"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  paths: [
    {
      id: "path_123",
      title: "AI Foundations Track",
      slug: "ai-foundations-track",
      description: "Master AI fundamentals and practical tools in 6 weeks",
      shortDescription: "Build strong AI foundations with 3 comprehensive courses",
      targetAudience: "individual",
      targetRole: "Business professionals new to AI",
      estimatedDuration: "6 weeks",
      totalCourses: 3,
      totalHours: 48,
      skillIds: ["skill_ai_concepts", "skill_prompt_eng", "skill_tool_selection"],
      outcomes: [
        "Understand core AI concepts and terminology",
        "Write effective prompts for any AI tool",
        "Integrate AI tools into daily workflows",
        "Build AI-powered automation workflows"
      ],
      pricing: {
        model: "bundled",
        bundlePrice: 99700, // $997.00 in cents
        bundleDiscount: 23, // 23% off vs individual courses
        individualTotal: 129700, // Total if purchased separately
        savings: 30000
      },
      thumbnailUrl: "https://academy.com/paths/ai-foundations-track.jpg",
      isFeatured: true,
      enrollmentCount: 342,
      completionCount: 156,
      avgCompletionTime: "7 weeks",
      rating: 4.8,
      ratingCount: 128,
      userProgress: null // Only if includeProgress=true
    }
  ]
}
```

**Required Scope:** `learning_paths:read`

---

#### 8.11.2 Get Learning Path Details

Get detailed learning path with step-by-step course sequence.

```typescript
{
  name: "academy_get_path_details",
  description: "Get learning path details with course steps and unlock rules",
  inputSchema: {
    type: "object",
    properties: {
      pathId: {
        type: "string",
        description: "Learning path ID"
      },
      userId: {
        type: "string",
        description: "User ID for progress and unlock status"
      }
    },
    required: ["pathId"]
  }
}
```

**Response Format:**
```typescript
{
  path: {
    id: "path_123",
    title: "AI Foundations Track",
    description: "Master AI fundamentals...",
    totalCourses: 3,
    totalHours: 48,
    estimatedDuration: "6 weeks"
  },
  steps: [
    {
      stepNumber: 1,
      course: {
        id: "crs_ai_foundations",
        title: "AI Fundamentals",
        sessionType: "cohort",
        hours: 16
      },
      isRequired: true,
      unlockRule: "immediate",
      recommendedTimeframe: "Week 1-2",
      status: "available", // "available", "locked", "in_progress", "completed"
      userEnrollment: null,
      nextCohorts: [
        {
          cohortId: "coh_456",
          startDate: "2025-01-15",
          spotsAvailable: 8
        }
      ]
    },
    {
      stepNumber: 2,
      course: {
        id: "crs_prompt_engineering",
        title: "Prompt Engineering Mastery",
        sessionType: "cohort",
        hours: 16
      },
      isRequired: true,
      unlockRule: "sequential",
      unlockAfterStep: 1,
      recommendedTimeframe: "Week 3-4",
      status: "locked",
      unlockMessage: "Complete AI Fundamentals to unlock this course",
      nextCohorts: []
    }
  ],
  userProgress: {
    pathEnrollmentId: "path_enr_789",
    status: "active",
    currentStepNumber: 1,
    completedSteps: 0,
    progressPercent: 0,
    enrolledAt: "2024-12-03T10:00:00Z",
    estimatedCompletionDate: "2025-01-15"
  }
}
```

**Required Scope:** `learning_paths:read`

---

### Community Tools

#### 8.11.3 Create Discussion Thread

Create a new discussion thread in the native community system.

```typescript
{
  name: "academy_create_discussion",
  description: "Create a discussion thread scoped to course, session, or lesson",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (defaults to authenticated user)"
      },
      scope: {
        type: "string",
        enum: ["course", "session", "lesson", "general"],
        description: "Discussion scope level"
      },
      scopeId: {
        type: "string",
        description: "ID of the course/session/lesson (not required for general)"
      },
      title: {
        type: "string",
        description: "Thread title"
      },
      content: {
        type: "string",
        description: "Thread content (Markdown supported)"
      },
      category: {
        type: "string",
        enum: ["question", "discussion", "show-and-tell", "resource"],
        description: "Thread category (default: discussion)"
      },
      tags: {
        type: "array",
        items: { type: "string" },
        description: "Optional tags for filtering"
      }
    },
    required: ["scope", "title", "content"]
  }
}
```

**Response Format:**
```typescript
{
  thread: {
    id: "thrd_123",
    title: "How to use prompt chaining effectively?",
    content: "I'm working on a complex workflow...",
    authorId: "usr_456",
    scope: "lesson",
    lessonId: "lsn_789",
    isPinned: false,
    isAnnouncement: false,
    isLocked: false,
    category: "question",
    tags: ["prompt-engineering", "advanced"],
    replyCount: 0,
    viewCount: 1,
    likeCount: 0,
    status: "active",
    url: "https://academy.com/community/threads/thrd_123",
    createdAt: "2024-12-03T10:00:00Z"
  }
}
```

**Required Scope:** `community:write`

**Side Effects:**
- Creates notification for course instructors (if scope is course/session/lesson)
- Triggers content moderation scan
- Updates user activity metrics

**Error Codes:**
- `INVALID_SCOPE_ID` - Scope ID doesn't match scope type
- `CONTENT_MODERATION_FAILED` - Content flagged by auto-moderation
- `ENROLLMENT_REQUIRED` - User must be enrolled in course/session

---

#### 8.11.4 Get Thread with Replies

Retrieve a discussion thread with all replies (nested structure).

```typescript
{
  name: "academy_get_thread",
  description: "Get discussion thread with nested replies and interaction counts",
  inputSchema: {
    type: "object",
    properties: {
      threadId: {
        type: "string",
        description: "Thread ID"
      },
      includeReplies: {
        type: "boolean",
        default: true,
        description: "Include replies in response"
      },
      sortReplies: {
        type: "string",
        enum: ["chronological", "top_voted", "instructor_first"],
        default: "chronological",
        description: "Reply sorting method"
      }
    },
    required: ["threadId"]
  }
}
```

**Response Format:**
```typescript
{
  thread: {
    id: "thrd_123",
    title: "How to use prompt chaining effectively?",
    content: "I'm working on a complex workflow...",
    author: {
      id: "usr_456",
      name: "John Doe",
      isInstructor: false
    },
    scope: "lesson",
    lessonId: "lsn_789",
    lessonTitle: "Advanced Prompt Engineering",
    category: "question",
    tags: ["prompt-engineering", "advanced"],
    isPinned: false,
    isAnnouncement: false,
    isLocked: false,
    status: "active",
    replyCount: 3,
    viewCount: 24,
    likeCount: 5,
    userInteractions: {
      viewed: true,
      liked: false,
      bookmarked: true,
      subscribed: true
    },
    createdAt: "2024-12-03T10:00:00Z",
    lastActivityAt: "2024-12-03T14:30:00Z"
  },
  replies: [
    {
      id: "rep_789",
      threadId: "thrd_123",
      parentReplyId: null,
      content: "Great question! Prompt chaining works by...",
      author: {
        id: "usr_101",
        name: "Sarah Johnson",
        isInstructor: true,
        title: "Senior AI Instructor"
      },
      isInstructorReply: true,
      isBestAnswer: true,
      likeCount: 8,
      status: "active",
      userLiked: false,
      createdAt: "2024-12-03T10:15:00Z",
      replies: [
        {
          id: "rep_790",
          parentReplyId: "rep_789",
          content: "Thanks! This is exactly what I needed.",
          author: {
            id: "usr_456",
            name: "John Doe",
            isInstructor: false
          },
          isInstructorReply: false,
          isBestAnswer: false,
          likeCount: 2,
          status: "active",
          createdAt: "2024-12-03T10:30:00Z",
          replies: []
        }
      ]
    }
  ]
}
```

**Required Scope:** `community:read`

**Access Control:** User must have access to the thread's scope (e.g., enrolled in course)

**Performance Note:** Large threads (100+ replies) may be paginated automatically

---

#### 8.11.5 Suggest Peer Connections

AI-powered peer connection suggestions based on cohort, skills, and industry.

```typescript
{
  name: "academy_suggest_connections",
  description: "Get AI-powered peer connection suggestions for networking",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (defaults to authenticated user)"
      },
      limit: {
        type: "number",
        default: 10,
        description: "Number of suggestions to return"
      },
      filters: {
        type: "object",
        properties: {
          sameCohort: { type: "boolean", description: "Prioritize current cohort peers" },
          skillOverlap: { type: "boolean", description: "Match on similar skills" },
          industryMatch: { type: "boolean", description: "Match on company/industry" }
        },
        description: "Optional filters for suggestions"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  suggestions: [
    {
      user: {
        id: "usr_202",
        name: "Emily Chen",
        company: "TechCorp",
        title: "Product Manager",
        profilePictureUrl: "https://academy.com/avatars/usr_202.jpg"
      },
      matchScore: 0.92,
      matchReasons: [
        {
          type: "cohort",
          description: "Currently enrolled in AI Foundations - March 2025 Cohort",
          weight: 0.4
        },
        {
          type: "skills",
          description: "Working on similar skills: Prompt Engineering, Use Case Development",
          weight: 0.3
        },
        {
          type: "industry",
          description: "Both in B2B SaaS industry",
          weight: 0.22
        }
      ],
      connectionStatus: "none", // "none", "pending", "accepted"
      mutualConnections: 3
    }
  ],
  metadata: {
    totalAvailable: 47,
    filtersApplied: ["sameCohort", "skillOverlap"],
    refreshRecommended: "2024-12-10T10:00:00Z"
  }
}
```

**Required Scope:** `community:read`

**Algorithm Details:**
- **Cohort matching** (weight: 0.4): Currently enrolled together
- **Skills overlap** (weight: 0.3): Working on similar competencies
- **Industry match** (weight: 0.2): Same company domain or job function
- **Discussion activity** (weight: 0.1): Active in same threads

**Refresh Rate:** Suggestions recalculated weekly or on user request

---

#### 8.11.6 Moderate Content

Apply moderation actions to threads or replies (admin only).

```typescript
{
  name: "academy_moderate_content",
  description: "Apply moderation action to thread or reply (admin/instructor only)",
  inputSchema: {
    type: "object",
    properties: {
      adminId: {
        type: "string",
        description: "Admin/instructor user ID"
      },
      contentType: {
        type: "string",
        enum: ["thread", "reply"],
        description: "Type of content to moderate"
      },
      contentId: {
        type: "string",
        description: "Thread or reply ID"
      },
      action: {
        type: "string",
        enum: ["pin", "unpin", "lock", "unlock", "hide", "unhide", "flag", "mark_best_answer"],
        description: "Moderation action to apply"
      },
      reason: {
        type: "string",
        description: "Reason for moderation (required for hide/flag actions)"
      }
    },
    required: ["adminId", "contentType", "contentId", "action"]
  }
}
```

**Response Format:**
```typescript
{
  success: true,
  content: {
    id: "thrd_123",
    type: "thread",
    status: "active",
    isPinned: true,
    isLocked: false,
    moderationLog: {
      action: "pin",
      moderatorId: "usr_999",
      moderatorName: "Admin User",
      reason: "Important course announcement",
      timestamp: "2024-12-03T10:00:00Z"
    }
  },
  notifications: {
    sent: true,
    recipients: ["usr_456"] // Thread author notified
  }
}
```

**Required Scope:** `admin:moderation`

**Access Control:** Requires admin role or instructor role for course-scoped content

**Moderation Actions:**
- `pin` / `unpin` - Pin thread to top of list
- `lock` / `unlock` - Prevent/allow new replies
- `hide` / `unhide` - Soft delete/restore content
- `flag` - Mark for admin review
- `mark_best_answer` - Highlight reply as accepted answer (replies only)

---

### Assessment Tools

#### 8.11.7 Get Assessment Questions

Retrieve assessment with randomized questions for a user attempt.

```typescript
{
  name: "academy_get_assessment",
  description: "Get assessment with randomized questions for user attempt",
  inputSchema: {
    type: "object",
    properties: {
      assessmentId: {
        type: "string",
        description: "Assessment ID"
      },
      userId: {
        type: "string",
        description: "User ID (defaults to authenticated user)"
      },
      enrollmentId: {
        type: "string",
        description: "Enrollment ID for context"
      }
    },
    required: ["assessmentId"]
  }
}
```

**Response Format:**
```typescript
{
  assessment: {
    id: "asmt_123",
    title: "AI Fundamentals - Pre-Assessment",
    description: "Measure your current AI knowledge before the course",
    type: "pre_course",
    courseId: "crs_ai_foundations",
    courseName: "AI Foundations for Business Leaders",
    timeLimit: 30, // minutes, null = unlimited
    passingScore: 70,
    allowRetake: false,
    maxAttempts: 1,
    questionsPerAttempt: 20,
    showCorrectAnswers: "never"
  },
  attempt: {
    id: "atpt_456",
    attemptNumber: 1,
    status: "in_progress",
    startedAt: "2024-12-03T10:00:00Z",
    expiresAt: "2024-12-03T10:30:00Z",
    remainingTime: 1800 // seconds
  },
  questions: [
    {
      id: "qst_789",
      questionType: "multiple_choice",
      questionText: "What is the primary difference between machine learning and traditional programming?",
      answers: [
        {
          id: "ans_001",
          text: "Machine learning models learn patterns from data instead of following explicit instructions"
        }
      ],
      points: 5,
      difficulty: "medium",
      order: 1
    }
  ],
  metadata: {
    totalQuestions: 20,
    totalPoints: 100,
    estimatedDuration: "30 minutes",
    skillsAssessed: ["ai-concepts", "prompt-engineering", "tool-selection"]
  }
}
```

**Required Scope:** `assessments:read`

**Access Control:** User must have active enrollment in the course

**Randomization:**
- Questions randomized per attempt (if `randomizeQuestions: true`)
- Answer options randomized per attempt (if `randomizeAnswers: true`)
- Questions pulled from pool (if `questionsPerAttempt` < total question count)

---

#### 8.11.8 Submit Assessment

Submit completed assessment for grading.

```typescript
{
  name: "academy_submit_assessment",
  description: "Submit completed assessment responses for grading",
  inputSchema: {
    type: "object",
    properties: {
      attemptId: {
        type: "string",
        description: "Assessment attempt ID"
      },
      responses: {
        type: "array",
        items: {
          type: "object",
          properties: {
            questionId: { type: "string" },
            selectedAnswerIds: {
              type: "array",
              items: { type: "string" },
              description: "For MC/MS questions"
            },
            textResponse: {
              type: "string",
              description: "For short/open answer questions"
            },
            ratingValue: {
              type: "number",
              description: "For rating scale questions"
            }
          },
          required: ["questionId"]
        },
        description: "Array of question responses"
      }
    },
    required: ["attemptId", "responses"]
  }
}
```

**Response Format:**
```typescript
{
  attempt: {
    id: "atpt_456",
    assessmentId: "asmt_123",
    userId: "usr_456",
    attemptNumber: 1,
    status: "graded",
    score: 78,
    pointsEarned: 78,
    pointsPossible: 100,
    passed: true,
    percentile: 65
  },
  breakdown: {
    correctCount: 16,
    incorrectCount: 3,
    partialCredit: 1,
    bySkill: [
      {
        skillId: "skill_ai_concepts",
        skillName: "AI Concepts",
        score: 85,
        questionsAnswered: 8
      }
    ]
  },
  feedback: {
    overall: "Great work! You demonstrated strong understanding of AI concepts.",
    weakestAreas: ["Prompt chaining", "Few-shot learning"],
    recommendedResources: [
      {
        resourceId: "res_123",
        title: "Advanced Prompt Engineering Guide",
        type: "article"
      }
    ]
  },
  nextSteps: {
    allowRetake: false,
    postAssessmentAvailable: true,
    postAssessmentId: "asmt_124",
    certificateEligible: false
  }
}
```

**Required Scope:** `assessments:write`

**Grading Process:**
1. **Immediate Grading** (MC, MS, TF, rating scale): Auto-graded instantly
2. **AI-Assisted Grading** (short answer, open-ended): GPT-4 evaluates with confidence scoring
3. **Manual Grading** (if required): Low confidence (<0.7) flagged for instructor review

**Learning Gain Calculation:**
- If post-assessment, calculates Hake's normalized gain
- Pre-score vs post-score comparison
- Interpretation: Low (<0.3), Medium (0.3-0.7), High (>0.7)

---

#### 8.11.9 Calculate Learning Gain

Calculate Hake's normalized learning gain for pre/post assessments.

```typescript
{
  name: "academy_calculate_learning_gain",
  description: "Calculate learning gain using Hake's normalized gain formula",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID"
      },
      courseId: {
        type: "string",
        description: "Course ID"
      },
      enrollmentId: {
        type: "string",
        description: "Enrollment ID"
      }
    },
    required: ["userId", "courseId"]
  }
}
```

**Response Format:**
```typescript
{
  learningGain: {
    id: "gain_123",
    userId: "usr_456",
    courseId: "crs_ai_foundations",
    enrollmentId: "enr_789",
    preAssessment: {
      id: "asmt_123",
      attemptId: "atpt_456",
      score: 45,
      completedAt: "2024-11-28T10:00:00Z"
    },
    postAssessment: {
      id: "asmt_124",
      attemptId: "atpt_789",
      score: 78,
      completedAt: "2024-12-03T10:00:00Z"
    },
    gains: {
      scoreImprovement: 33,
      percentageGain: 73.3,
      normalizedGain: 0.60,
      gainCategory: "medium",
      interpretation: "Moderate learning gain. You made significant progress but have room for mastery."
    },
    skillBreakdown: [
      {
        skillId: "skill_ai_concepts",
        skillName: "AI Concepts",
        preScore: 50,
        postScore: 85,
        improvement: 35,
        normalizedGain: 0.70,
        gainCategory: "medium"
      }
    ],
    comparison: {
      cohortAvgGain: 0.55,
      cohortPercentile: 68,
      industryBenchmark: 0.52
    }
  }
}
```

**Required Scope:** `assessments:read`

**Hake's Normalized Gain Formula:**
```
g = (S_post - S_pre) / (100 - S_pre)
```

**Interpretation Guidelines:**
- **High Gain (g > 0.7)**: Exceptional learning progress
- **Medium Gain (0.3 < g ≤ 0.7)**: Moderate learning progress
- **Low Gain (g ≤ 0.3)**: Minimal learning progress, intervention recommended

---

#### 8.11.10 Get AI Grading Queue

Get assessment responses pending AI or manual grading (admin/instructor only).

```typescript
{
  name: "academy_get_grading_queue",
  description: "Get assessment responses needing AI or manual grading review",
  inputSchema: {
    type: "object",
    properties: {
      courseId: {
        type: "string",
        description: "Filter by course ID"
      },
      status: {
        type: "string",
        enum: ["pending", "low_confidence", "all"],
        default: "all",
        description: "Filter by grading status"
      },
      limit: {
        type: "number",
        default: 50,
        description: "Number of responses to return"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  queue: [
    {
      response: {
        id: "resp_123",
        attemptId: "atpt_456",
        questionId: "qst_789",
        textResponse: "Prompt engineering is the practice of designing effective inputs...",
        status: "low_confidence"
      },
      question: {
        id: "qst_789",
        questionText: "In your own words, explain what prompt engineering is...",
        questionType: "open_ended",
        sampleAnswer: "Prompt engineering is the process of crafting...",
        points: 10
      },
      attempt: {
        id: "atpt_456",
        assessmentId: "asmt_123",
        assessmentTitle: "AI Fundamentals - Post-Assessment",
        userId: "usr_456",
        userName: "John Doe"
      },
      aiGrading: {
        score: 7.5,
        confidence: 0.65,
        explanation: "Response covers basic concepts but lacks detail...",
        suggestedFeedback: "Good start! Consider elaborating on business impact."
      },
      submittedAt: "2024-12-03T10:30:00Z",
      priority: "medium"
    }
  ],
  metadata: {
    total: 12,
    pending: 3,
    lowConfidence: 9,
    avgWaitTime: 45,
    oldestSubmission: "2024-12-02T14:00:00Z"
  }
}
```

**Required Scope:** `admin:grading`

**Access Control:** Instructors can grade for their assigned courses; admins can grade all

**Priority Calculation:**
- **High**: Pre-assessments (time-sensitive), > 24 hours old
- **Medium**: Post-assessments, 6-24 hours old
- **Low**: Knowledge checks, < 6 hours old

---

### Manager Dashboard Tools

#### 8.11.11 Get Team Analytics

Get team progress and engagement analytics for manager dashboard.

```typescript
{
  name: "academy_get_team_analytics",
  description: "Get comprehensive team learning analytics and progress metrics",
  inputSchema: {
    type: "object",
    properties: {
      managerId: {
        type: "string",
        description: "Manager user ID"
      },
      teamId: {
        type: "string",
        description: "Team ID (optional, returns all teams if not specified)"
      },
      period: {
        type: "string",
        enum: ["day", "week", "month", "quarter", "all_time"],
        default: "week",
        description: "Analytics time period"
      },
      includeIndividuals: {
        type: "boolean",
        default: false,
        description: "Include individual learner breakdowns (requires permission)"
      }
    },
    required: ["managerId"]
  }
}
```

**Response Format:**
```typescript
{
  team: {
    id: "team_123",
    name: "Marketing Team",
    organizationId: "org_456",
    memberCount: 24,
    activeMembers: 18
  },
  period: {
    type: "week",
    start: "2024-11-27T00:00:00Z",
    end: "2024-12-03T23:59:59Z"
  },
  summary: {
    enrollments: {
      total: 24,
      active: 18,
      completed: 3,
      notStarted: 3
    },
    progress: {
      avgProgressPercent: 62,
      onTrack: 15,
      behindSchedule: 6,
      atRisk: 3
    },
    engagement: {
      totalLearningHours: 186,
      avgHoursPerLearner: 7.75,
      lessonsCompleted: 142,
      avgLessonsPerLearner: 5.9,
      discussionThreads: 12,
      discussionReplies: 34
    },
    performance: {
      avgAssessmentScore: 76,
      coursesCompleted: 3,
      certificatesEarned: 3,
      skillsAcquired: 18
    }
  },
  trends: {
    weekOverWeek: {
      learningHours: { current: 186, previous: 142, change: 31 },
      lessonsCompleted: { current: 142, previous: 98, change: 45 },
      activeMembers: { current: 18, previous: 16, change: 13 }
    }
  },
  atRiskLearners: [
    {
      userId: "usr_501",
      name: "Alex Thompson",
      lastActive: "2024-11-20T14:00:00Z",
      daysSinceActive: 13,
      progressPercent: 25,
      riskFactors: ["inactive_2_weeks", "low_progress", "no_assessments"]
    }
  ],
  topPerformers: [
    {
      userId: "usr_503",
      name: "Morgan Davis",
      metric: "completion_rate",
      value: 100,
      lessonsCompleted: 15,
      certificatesEarned: 2
    }
  ],
  recommendations: [
    {
      type: "send_reminder",
      priority: "high",
      description: "3 learners inactive for 7+ days",
      action: "Send engagement reminder to at-risk learners",
      targetUserIds: ["usr_501", "usr_502", "usr_505"]
    }
  ]
}
```

**Required Scope:** `manager:analytics`

**Access Control:**
- Manager must have permission to view team analytics
- Individual learner data requires `view_individual_data` permission
- Respects user privacy settings

**Metrics Calculation:**
- **Active Members**: Logged in during period
- **Learning Hours**: Total time spent in lessons/assessments
- **On Track**: Progress >= expected progress
- **At Risk**: Inactive 7+ days OR < 25% progress after 2 weeks

---

#### 8.11.12 Get Skills Heatmap

Get team skills coverage and proficiency heatmap.

```typescript
{
  name: "academy_get_skills_heatmap",
  description: "Get matrix of team members x skills with proficiency levels",
  inputSchema: {
    type: "object",
    properties: {
      teamId: {
        type: "string",
        description: "Team ID"
      },
      skillIds: {
        type: "array",
        items: { type: "string" },
        description: "Filter by specific skills (optional)"
      },
      includeNames: {
        type: "boolean",
        default: false,
        description: "Include learner names (requires permission)"
      }
    },
    required: ["teamId"]
  }
}
```

**Response Format:**
```typescript
{
  team: {
    id: "team_123",
    name: "Marketing Team",
    memberCount: 24
  },
  skills: [
    {
      id: "skill_ai_concepts",
      name: "AI Fundamentals",
      category: "Foundation",
      targetLevel: "practitioner"
    }
  ],
  heatmap: [
    {
      userId: "usr_503",
      userName: "Morgan Davis",
      skills: [
        {
          skillId: "skill_ai_concepts",
          level: "practitioner",
          score: 85,
          status: "achieved",
          completedAt: "2024-11-28T10:00:00Z"
        }
      ],
      totalSkillsAchieved: 3,
      totalSkillsInProgress: 1
    }
  ],
  coverage: {
    skill_ai_concepts: {
      achieved: 18,
      inProgress: 4,
      notStarted: 2,
      avgScore: 81,
      coveragePercent: 92
    }
  },
  gaps: [
    {
      skillId: "skill_use_case_dev",
      skillName: "Use Case Development",
      targetLevel: "advanced",
      currentCoverage: 50,
      gap: "Only 3/24 members achieved target level",
      recommendation: "Schedule advanced use case workshop for team"
    }
  ],
  visualization: {
    colorScale: [
      { status: "not_started", color: "#E5E7EB", label: "Not Started" },
      { status: "in_progress", color: "#FDE68A", label: "In Progress" },
      { status: "achieved", color: "#86EFAC", label: "Achieved" }
    ],
    chartDataUrl: "https://academy.com/api/charts/heatmap/team_123.png"
  }
}
```

**Required Scope:** `manager:analytics`

**Access Control:** Manager must have `view_progress` permission for team

**Skill Status Logic:**
- `not_started`: No evidence submitted for skill
- `in_progress`: 1+ evidence submitted, target level not achieved
- `achieved`: Target proficiency level reached

---

#### 8.11.13 Generate Manager Report

Generate downloadable report (PDF/CSV/XLSX).

```typescript
{
  name: "academy_generate_report",
  description: "Generate and download manager report in specified format",
  inputSchema: {
    type: "object",
    properties: {
      managerId: {
        type: "string",
        description: "Manager user ID"
      },
      reportType: {
        type: "string",
        enum: ["progress_summary", "individual_detail", "skill_matrix", "roi_analysis", "engagement", "compliance"],
        description: "Type of report to generate"
      },
      filters: {
        type: "object",
        properties: {
          teamIds: {
            type: "array",
            items: { type: "string" }
          },
          courseIds: {
            type: "array",
            items: { type: "string" }
          },
          dateRange: {
            type: "object",
            properties: {
              start: { type: "string", format: "date" },
              end: { type: "string", format: "date" }
            }
          }
        }
      },
      format: {
        type: "string",
        enum: ["pdf", "csv", "xlsx"],
        default: "pdf",
        description: "Output file format"
      },
      schedule: {
        type: "object",
        properties: {
          enabled: { type: "boolean" },
          frequency: {
            type: "string",
            enum: ["daily", "weekly", "monthly"]
          },
          recipients: {
            type: "array",
            items: { type: "string", format: "email" }
          }
        }
      }
    },
    required: ["managerId", "reportType", "format"]
  }
}
```

**Response Format:**
```typescript
{
  report: {
    id: "rpt_123",
    name: "Marketing Team - Weekly Progress Summary",
    type: "progress_summary",
    format: "pdf",
    status: "generating",
    estimatedReadyAt: "2024-12-03T10:05:00Z",
    createdAt: "2024-12-03T10:00:00Z"
  },
  schedule: {
    enabled: true,
    frequency: "weekly",
    recipients: ["manager@company.com"],
    nextSendAt: "2024-12-10T09:00:00Z"
  },
  polling: {
    checkStatusUrl: "https://api.academy.com/reports/rpt_123/status",
    pollingInterval: 5000
  }
}
```

**When Report Ready:**
```typescript
{
  report: {
    id: "rpt_123",
    name: "Marketing Team - Weekly Progress Summary",
    type: "progress_summary",
    format: "pdf",
    status: "ready",
    downloadUrl: "https://academy.com/reports/rpt_123/download?token=xxx",
    expiresAt: "2024-12-10T10:00:00Z",
    fileSize: 2458624,
    pageCount: 8,
    generatedAt: "2024-12-03T10:03:00Z"
  }
}
```

**Required Scope:** `manager:reports`

**Report Types:**
1. **Progress Summary** (PDF): Executive overview with key metrics
2. **Individual Detail** (CSV): Learner-by-learner breakdown
3. **Skill Matrix** (XLSX): Team members x skills heatmap
4. **ROI Analysis** (PDF): Pre/post assessment scores and learning gains
5. **Engagement** (PDF): Activity patterns and content consumption
6. **Compliance** (XLSX): Mandatory training completion and deadlines

**Generation Time:**
- Small reports (<100 learners): 30-60 seconds
- Medium reports (100-500 learners): 2-3 minutes
- Large reports (500+ learners): 5-10 minutes

---

#### 8.11.14 Send Learning Reminder

Send reminder notification to learner(s).

```typescript
{
  name: "academy_send_reminder",
  description: "Send learning reminder notification to individual or group",
  inputSchema: {
    type: "object",
    properties: {
      managerId: {
        type: "string",
        description: "Manager user ID sending the reminder"
      },
      targetType: {
        type: "string",
        enum: ["individual", "team", "behind_schedule", "inactive"],
        description: "Who to send reminder to"
      },
      targetId: {
        type: "string",
        description: "User ID (individual) or Team ID (team)"
      },
      inactivityDays: {
        type: "number",
        description: "For 'inactive' target type, minimum days inactive (default: 7)"
      },
      message: {
        type: "object",
        properties: {
          subject: { type: "string" },
          body: { type: "string", description: "Markdown supported" },
          includeProgress: {
            type: "boolean",
            default: true,
            description: "Include learner's progress stats"
          },
          includeCTA: {
            type: "boolean",
            default: true,
            description: "Include call-to-action button"
          }
        },
        required: ["subject", "body"]
      },
      channel: {
        type: "string",
        enum: ["email", "in_app", "both"],
        default: "both",
        description: "Notification delivery channel"
      },
      scheduledFor: {
        type: "string",
        format: "date-time",
        description: "Schedule for later (optional)"
      }
    },
    required: ["managerId", "targetType", "message"]
  }
}
```

**Response Format:**
```typescript
{
  reminder: {
    id: "rem_123",
    sentBy: {
      id: "mgr_456",
      name: "Sarah Johnson",
      role: "Team Manager"
    },
    targetType: "behind_schedule",
    message: {
      subject: "Quick Check-In: Your AI Enablement Journey",
      body: "Hi there! I noticed you're a bit behind schedule...",
      includeProgress: true,
      includeCTA: true
    },
    channel: "both",
    status: "sent",
    sentAt: "2024-12-03T10:00:00Z"
  },
  recipients: {
    count: 6,
    users: [
      {
        userId: "usr_501",
        name: "Alex Thompson",
        email: "alex@company.com",
        progress: {
          courseId: "crs_ai_foundations",
          progressPercent: 25,
          lastActive: "2024-11-20T14:00:00Z",
          daysSinceActive: 13
        },
        delivered: {
          email: "queued",
          inApp: "delivered"
        }
      }
    ]
  },
  metrics: {
    totalSent: 6,
    emailQueued: 6,
    inAppDelivered: 6,
    failed: 0
  },
  tracking: {
    trackOpenRate: true,
    trackClickRate: true,
    trackingId: "trk_abc123"
  }
}
```

**Required Scope:** `manager:reminders`

**Access Control:** Manager must have `send_reminders` permission

**Target Type Logic:**
1. **individual**: Send to specific user
2. **team**: Send to all team members
3. **behind_schedule**: Auto-target lagging learners
4. **inactive**: Auto-target inactive learners (default: 7+ days)

**Message Personalization:**
- `{{name}}`: Learner first name
- `{{progress}}`: Current progress percentage
- `{{course}}`: Course name
- `{{deadline}}`: Course deadline
- `{{manager_name}}`: Manager name
- `{{last_active}}`: Last activity date

**Rate Limiting:**
- Maximum 50 reminders per day per manager
- Minimum 3-day gap between reminders to same user

---

## 8.12 Future Enhancements

### Phase 2 (Q1 2025)
- **Prompts**: Pre-defined conversational prompts
- **HTTP Transport**: Support for web-based MCP clients
- **Webhooks**: Real-time event notifications
- **Batch Operations**: Bulk enrollment creation, material downloads

### Phase 3 (Q2 2025)
- **Streaming**: Real-time chat streaming responses
- **File Uploads**: Submit assignments via MCP
- **Voice Support**: Audio office hours transcripts
- **Analytics**: Custom dashboard queries via MCP

---

---

## 8.13 v2.1 MCP Tools - Skills, Resources & Learning Paths

The v2.1 release extends the MCP server with 9 additional tools supporting the Skills & Competencies System, Resource Library, and Learning Paths features.

### Skills Tools

#### 8.13.1 Get User Skill Profile
Retrieves a user's complete skill profile with competency progress, proficiency levels, and earned badges.

```typescript
{
  name: "academy_get_user_skill_profile",
  description: "Get user's complete skill profile with progress, levels, and badges",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      includeCompetencies: {
        type: "boolean",
        description: "Include detailed competency breakdown (default: false)"
      },
      skillIds: {
        type: "array",
        items: { type: "string" },
        description: "Filter by specific skill IDs (optional)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  userId: "usr_456",
  totalSkills: 12,
  completedSkills: 5,
  skills: [
    {
      skillId: "skl_789",
      skillName: "Prompt Engineering",
      category: "technical",
      currentLevel: "practitioner",
      progressPercent: 75,
      competenciesCompleted: 6,
      competenciesTotal: 8,
      badges: [
        {
          badgeId: "bdg_123",
          name: "Prompt Engineering Practitioner",
          earnedAt: "2024-12-01T10:00:00Z",
          verificationUrl: "https://academy.com/verify/bdg_123"
        }
      ],
      competencies: [ // Only if includeCompetencies: true
        {
          competencyId: "comp_456",
          name: "Write effective system prompts",
          status: "completed",
          evidenceCount: 3,
          completedAt: "2024-12-01T10:00:00Z"
        },
        {
          competencyId: "comp_457",
          name: "Apply few-shot learning techniques",
          status: "in_progress",
          progressPercent: 50,
          evidenceCount: 1
        }
      ],
      lastActivityAt: "2024-12-15T14:30:00Z"
    }
  ],
  statistics: {
    totalBadgesEarned: 8,
    skillsInProgress: 7,
    averageProgressPercent: 62,
    lastSkillCompleted: {
      skillId: "skl_790",
      skillName: "AI Use Case Development",
      completedAt: "2024-12-10T10:00:00Z"
    }
  }
}
```

**Required Scope:** `skills:read`

**Access Control:** Users can only view their own profile unless they have `admin:skills` scope

---

#### 8.13.2 Suggest Next Skill
AI-powered skill recommendation based on user's current progress, learning path, and market demand.

```typescript
{
  name: "academy_suggest_next_skill",
  description: "Get AI-powered skill recommendations for a user",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      limit: {
        type: "number",
        description: "Number of recommendations to return (default: 5, max: 10)"
      },
      focusArea: {
        type: "string",
        enum: ["technical", "strategic", "leadership", "domain"],
        description: "Filter recommendations by skill category (optional)"
      },
      considerPrerequisites: {
        type: "boolean",
        description: "Only suggest skills with met prerequisites (default: true)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  recommendations: [
    {
      skillId: "skl_891",
      skillName: "Advanced RAG Architectures",
      category: "technical",
      level: "advanced",
      relevanceScore: 0.92, // 0-1 score
      reasoning: "Natural progression from your Prompt Engineering proficiency. This skill is trending in your industry.",
      prerequisites: [
        {
          skillId: "skl_789",
          skillName: "Prompt Engineering",
          status: "completed"
        }
      ],
      availableIn: [
        {
          type: "course",
          courseId: "crs_ai_advanced",
          courseName: "Advanced AI Implementation",
          nextCohortDate: "2025-01-15"
        },
        {
          type: "learning_path",
          pathId: "path_456",
          pathName: "AI Technical Mastery",
          enrollmentAvailable: true
        }
      ],
      marketDemand: "high",
      estimatedTimeToComplete: "4 weeks",
      badges: [
        {
          badgeId: "bdg_234",
          name: "RAG Architecture Specialist"
        }
      ]
    }
  ],
  metadata: {
    totalSuggestedSkills: 15,
    recommendationsShown: 5,
    basedOnCourses: 3,
    basedOnPeers: true,
    generatedAt: "2024-12-15T10:00:00Z"
  }
}
```

**Required Scope:** `skills:read`

**Rate Limit:** 30 requests/minute per user (AI-powered recommendations are compute-intensive)

---

#### 8.13.3 Record Competency Evidence
Records evidence of competency achievement (quiz results, project submissions, peer reviews).

```typescript
{
  name: "academy_record_competency_evidence",
  description: "Record evidence of competency achievement with automatic badge award",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      skillId: {
        type: "string",
        description: "Skill ID"
      },
      competencyId: {
        type: "string",
        description: "Competency ID"
      },
      evidenceType: {
        type: "string",
        enum: ["quiz", "project", "peer_review", "instructor_assessment", "self_assessment"],
        description: "Type of evidence being submitted"
      },
      evidenceData: {
        type: "object",
        description: "Evidence details (structure varies by type)",
        properties: {
          score: { type: "number", description: "Score (0-100) for quiz/assessment" },
          submissionUrl: { type: "string", description: "URL to project submission" },
          reviewerComments: { type: "string", description: "Comments from peer/instructor" },
          artifacts: { type: "array", items: { type: "string" }, description: "File IDs or URLs" }
        }
      },
      notes: {
        type: "string",
        description: "Optional notes about the evidence"
      }
    },
    required: ["skillId", "competencyId", "evidenceType", "evidenceData"]
  }
}
```

**Response Format:**
```typescript
{
  evidence: {
    id: "evd_123",
    userId: "usr_456",
    skillId: "skl_789",
    competencyId: "comp_456",
    evidenceType: "quiz",
    score: 92,
    submittedAt: "2024-12-15T10:00:00Z",
    status: "validated" // or "pending_review" for peer_review/instructor_assessment
  },
  competencyProgress: {
    competencyId: "comp_456",
    status: "completed", // or "in_progress"
    progressPercent: 100,
    evidenceCount: 3,
    completedAt: "2024-12-15T10:00:00Z"
  },
  skillProgress: {
    skillId: "skl_789",
    currentLevel: "practitioner",
    progressPercent: 87, // Updated progress
    competenciesCompleted: 7,
    competenciesTotal: 8
  },
  badgeAwarded: { // Only present if badge was earned
    badgeId: "bdg_234",
    name: "Prompt Engineering Practitioner",
    description: "Demonstrated proficiency in prompt engineering techniques",
    awardedAt: "2024-12-15T10:00:00Z",
    verificationUrl: "https://academy.com/verify/bdg_234",
    openBadgeUrl: "https://academy.com/badges/bdg_234.json",
    badgeImageUrl: "https://academy.com/badges/bdg_234.png"
  },
  levelUp: { // Only present if user advanced to next level
    previousLevel: "foundational",
    newLevel: "practitioner",
    message: "Congratulations! You've advanced to Practitioner level in Prompt Engineering."
  }
}
```

**Required Scope:** `skills:write`

**Side Effects:**
- Creates evidence record in database
- Updates user skill progress
- Awards badge if competency threshold reached
- Triggers notification email if level-up occurs
- Updates leaderboard rankings

---

#### 8.13.4 Get Skill Leaderboard
Retrieves top performers for a specific skill with optional organizational filtering.

```typescript
{
  name: "academy_get_skill_leaderboard",
  description: "Get top performers for a skill (global or organizational)",
  inputSchema: {
    type: "object",
    properties: {
      skillId: {
        type: "string",
        description: "Skill ID"
      },
      organizationId: {
        type: "string",
        description: "Filter by organization (optional, for B2B leaderboards)"
      },
      limit: {
        type: "number",
        description: "Number of top performers to return (default: 10, max: 50)"
      },
      level: {
        type: "string",
        enum: ["foundational", "practitioner", "advanced", "expert"],
        description: "Filter by proficiency level (optional)"
      },
      timeframe: {
        type: "string",
        enum: ["all_time", "this_year", "this_quarter", "this_month"],
        description: "Timeframe for leaderboard (default: all_time)"
      }
    },
    required: ["skillId"]
  }
}
```

**Response Format:**
```typescript
{
  skillId: "skl_789",
  skillName: "Prompt Engineering",
  leaderboard: [
    {
      rank: 1,
      userId: "usr_456",
      userName: "Sarah Johnson",
      organization: "Acme Corp", // Only if organizationId provided
      currentLevel: "expert",
      progressPercent: 100,
      competenciesCompleted: 12,
      badgesEarned: 4,
      totalEvidenceCount: 28,
      lastActivityAt: "2024-12-14T10:00:00Z",
      badges: [
        {
          badgeId: "bdg_123",
          name: "Prompt Engineering Expert",
          earnedAt: "2024-11-20T10:00:00Z"
        }
      ]
    },
    {
      rank: 2,
      userId: "usr_457",
      userName: "Michael Chen",
      organization: "Acme Corp",
      currentLevel: "advanced",
      progressPercent: 95,
      competenciesCompleted: 11,
      badgesEarned: 3,
      totalEvidenceCount: 22,
      lastActivityAt: "2024-12-15T09:00:00Z"
    }
  ],
  currentUserRank: { // Only present if authenticated user has progress in this skill
    rank: 8,
    userId: "usr_789",
    currentLevel: "practitioner",
    progressPercent: 78
  },
  metadata: {
    totalParticipants: 124,
    timeframe: "all_time",
    organizationName: "Acme Corp", // If organizationId provided
    generatedAt: "2024-12-15T10:00:00Z"
  }
}
```

**Required Scope:** `skills:read`

**Access Control:**
- Global leaderboards are public (anonymized names for privacy)
- Organizational leaderboards require user to be member of that organization
- Full user details only visible to `admin:skills` scope

---

### Resource Tools

#### 8.13.5 Search Resources
Searches the resource library with access control, full-text search, and advanced filtering.

```typescript
{
  name: "academy_search_resources",
  description: "Search resource library with filters and access control",
  inputSchema: {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "Search query (searches title, description, tags, content)"
      },
      resourceType: {
        type: "string",
        enum: ["template", "framework", "prompt", "glossary", "case_study", "checklist", "tool_guide", "video", "article", "external_link", "all"],
        description: "Filter by resource type (default: all)"
      },
      category: {
        type: "string",
        description: "Filter by category (e.g., 'Prompt Engineering', 'Change Management')"
      },
      tags: {
        type: "array",
        items: { type: "string" },
        description: "Filter by tags (e.g., ['beginner', 'marketing', 'gpt-4'])"
      },
      accessLevel: {
        type: "string",
        enum: ["free", "course_specific", "enrollment_only"],
        description: "Filter by access level (default: show all accessible to user)"
      },
      courseId: {
        type: "string",
        description: "Filter by specific course (for course_specific resources)"
      },
      featured: {
        type: "boolean",
        description: "Only show featured resources (default: false)"
      },
      sortBy: {
        type: "string",
        enum: ["relevance", "recent", "popular", "rating"],
        description: "Sort order (default: relevance)"
      },
      limit: {
        type: "number",
        description: "Number of results (default: 20, max: 100)"
      },
      offset: {
        type: "number",
        description: "Pagination offset (default: 0)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  resources: [
    {
      id: "res_456",
      type: "template",
      title: "Prompt Engineering Worksheet",
      slug: "prompt-engineering-worksheet",
      description: "Comprehensive worksheet for developing effective AI prompts",
      category: "Prompt Engineering",
      tags: ["beginner", "worksheet", "prompts"],
      accessLevel: "course_specific",
      courseIds: ["crs_ai_foundations"],
      author: {
        id: "usr_123",
        name: "Sarah Johnson"
      },
      skills: [
        {
          skillId: "skl_789",
          skillName: "Prompt Engineering",
          level: "practitioner"
        }
      ],
      downloads: 1284,
      views: 3456,
      rating: 4.8,
      ratingCount: 156,
      isFeatured: true,
      file: {
        type: "pdf",
        size: 245824,
        downloadUrl: "https://academy.com/resources/res_456/download?token=xxx",
        expiresAt: "2024-12-16T10:00:00Z"
      },
      createdAt: "2024-10-01T10:00:00Z",
      updatedAt: "2024-12-01T10:00:00Z"
    },
    {
      id: "res_457",
      type: "prompt",
      title: "Marketing Campaign Brainstorm Prompt",
      slug: "marketing-campaign-brainstorm",
      description: "AI prompt for generating creative marketing campaign ideas",
      category: "Marketing",
      tags: ["marketing", "brainstorm", "creativity"],
      accessLevel: "free",
      content: "You are a creative marketing strategist...", // Prompt text
      variables: ["product_name", "target_audience", "budget"],
      useCount: 892,
      rating: 4.6,
      ratingCount: 89,
      isFeatured: false,
      createdAt: "2024-11-15T10:00:00Z"
    }
  ],
  pagination: {
    total: 156,
    limit: 20,
    offset: 0,
    hasMore: true
  },
  facets: { // Aggregated filter options
    types: {
      "template": 45,
      "prompt": 62,
      "case_study": 18,
      "video": 31
    },
    categories: {
      "Prompt Engineering": 34,
      "Change Management": 22,
      "AI Strategy": 18
    },
    topTags: [
      { tag: "beginner", count: 78 },
      { tag: "advanced", count: 45 },
      { tag: "marketing", count: 34 }
    ]
  }
}
```

**Required Scope:** `resources:read`

**Access Control:**
- `free` resources: Available to all users
- `course_specific` resources: Require active enrollment in specified course(s)
- `enrollment_only` resources: Require any active enrollment

**Rate Limit:** 30 requests/minute per user

---

#### 8.13.6 Get Glossary Term
Retrieves a glossary term definition with related terms and skill connections.

```typescript
{
  name: "academy_get_glossary_term",
  description: "Get glossary term definition with related terms and examples",
  inputSchema: {
    type: "object",
    properties: {
      term: {
        type: "string",
        description: "Term name or slug (e.g., 'Large Language Model' or 'large-language-model')"
      },
      termId: {
        type: "string",
        description: "Alternative to term - lookup by ID"
      },
      includeRelated: {
        type: "boolean",
        description: "Include related terms (default: true)"
      },
      includeExamples: {
        type: "boolean",
        description: "Include usage examples (default: true)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  termId: "gls_789",
  term: "Large Language Model",
  slug: "large-language-model",
  abbreviation: "LLM",
  definition: "An AI model trained on vast amounts of text data that can understand and generate human-like text.",
  extendedDefinition: "Large Language Models (LLMs) are neural networks with billions or trillions of parameters, trained on diverse text corpora...",
  category: "AI Fundamentals",
  relatedTerms: [
    {
      termId: "gls_790",
      term: "Transformer Architecture",
      slug: "transformer-architecture",
      definition: "The neural network architecture underlying modern LLMs",
      relationship: "technical_foundation"
    },
    {
      termId: "gls_791",
      term: "Fine-tuning",
      slug: "fine-tuning",
      definition: "Process of adapting a pre-trained LLM for specific tasks",
      relationship: "related_concept"
    }
  ],
  skills: [
    {
      skillId: "skl_456",
      skillName: "AI Fundamentals",
      level: "foundational"
    },
    {
      skillId: "skl_789",
      skillName: "Prompt Engineering",
      level: "practitioner"
    }
  ],
  examples: [
    "GPT-4, Claude, and Llama are examples of Large Language Models",
    "LLMs power chatbots, content generation tools, and code assistants"
  ],
  resources: [
    {
      resourceId: "res_123",
      title: "Introduction to LLMs",
      type: "article"
    }
  ],
  metadata: {
    viewCount: 2345,
    lastUpdated: "2024-11-15T10:00:00Z",
    isActive: true
  }
}
```

**Required Scope:** `resources:read`

**Access Control:** Glossary terms are freely accessible to all users

---

#### 8.13.7 Get Prompt Template
Retrieves a prompt template with variables, configuration, and usage examples.

```typescript
{
  name: "academy_get_prompt_template",
  description: "Get prompt template with variables and usage examples",
  inputSchema: {
    type: "object",
    properties: {
      promptId: {
        type: "string",
        description: "Prompt template ID"
      },
      slug: {
        type: "string",
        description: "Alternative to promptId - lookup by slug"
      },
      fillVariables: {
        type: "object",
        description: "Optional - populate template variables (e.g., {product_name: 'Widget', target_audience: 'CTOs'})"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  promptId: "prm_456",
  title: "Marketing Campaign Brainstorm",
  slug: "marketing-campaign-brainstorm",
  description: "Generate creative marketing campaign ideas for your product",
  category: "Marketing",
  subcategory: "Campaign Planning",
  template: "You are a creative marketing strategist with 15 years of experience...\n\nProduct: {product_name}\nTarget Audience: {target_audience}\nBudget: {budget}\n\nGenerate 5 innovative marketing campaign ideas...",
  variables: [
    {
      name: "product_name",
      type: "string",
      description: "Name of the product or service",
      required: true,
      defaultValue: null
    },
    {
      name: "target_audience",
      type: "string",
      description: "Primary target audience (e.g., 'B2B SaaS CTOs')",
      required: true,
      defaultValue: null
    },
    {
      name: "budget",
      type: "string",
      description: "Marketing budget range",
      required: false,
      defaultValue: "Medium"
    }
  ],
  populatedTemplate: "You are a creative marketing strategist...\n\nProduct: Widget\nTarget Audience: CTOs...", // Only if fillVariables provided
  modelConfigurations: [
    {
      provider: "anthropic",
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.8,
      maxTokens: 2000
    },
    {
      provider: "openai",
      model: "gpt-4-turbo",
      temperature: 0.9,
      maxTokens: 2000
    }
  ],
  usageExamples: [
    {
      input: {
        product_name: "CloudSync Pro",
        target_audience: "Enterprise IT Directors",
        budget: "$50K-$100K"
      },
      output: "Campaign 1: 'Zero-Downtime Migration Challenge' - Partner with tech podcasts..."
    }
  ],
  author: {
    userId: "usr_123",
    name: "Sarah Johnson",
    title: "Marketing AI Specialist"
  },
  skills: [
    {
      skillId: "skl_891",
      skillName: "AI-Powered Marketing",
      level: "practitioner"
    }
  ],
  tags: ["marketing", "brainstorm", "campaigns", "creativity"],
  statistics: {
    useCount: 1284,
    rating: 4.7,
    ratingCount: 145,
    lastUsed: "2024-12-15T09:30:00Z"
  },
  accessLevel: "free",
  isFeatured: true,
  createdAt: "2024-10-15T10:00:00Z",
  updatedAt: "2024-12-01T10:00:00Z"
}
```

**Required Scope:** `resources:read`

**Access Control:** Same as search_resources (based on accessLevel field)

---

#### 8.13.8 Track Resource Usage
Records when a user views, downloads, or uses a resource (for analytics and recommendations).

```typescript
{
  name: "academy_track_resource_usage",
  description: "Track resource interaction for analytics and recommendations",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      resourceId: {
        type: "string",
        description: "Resource ID"
      },
      interactionType: {
        type: "string",
        enum: ["view", "download", "use", "bookmark", "rate", "share"],
        description: "Type of interaction"
      },
      metadata: {
        type: "object",
        description: "Optional metadata about the interaction",
        properties: {
          rating: { type: "number", description: "Rating (1-5) for 'rate' interaction" },
          timeSpent: { type: "number", description: "Time spent viewing (seconds)" },
          completionPercent: { type: "number", description: "Percent of resource completed (for videos)" }
        }
      }
    },
    required: ["resourceId", "interactionType"]
  }
}
```

**Response Format:**
```typescript
{
  interaction: {
    id: "int_789",
    userId: "usr_456",
    resourceId: "res_456",
    interactionType: "download",
    timestamp: "2024-12-15T10:00:00Z",
    metadata: {}
  },
  resourceStats: {
    resourceId: "res_456",
    totalViews: 3457, // Updated
    totalDownloads: 1285, // Updated
    totalUses: 892,
    averageRating: 4.8,
    ratingCount: 157 // Updated if rating was provided
  },
  recommendations: [ // Personalized recommendations based on this interaction
    {
      resourceId: "res_457",
      title: "Advanced Prompt Patterns",
      relevanceScore: 0.89,
      reason: "Users who downloaded this also found this helpful"
    }
  ]
}
```

**Required Scope:** `resources:write`

**Side Effects:**
- Creates interaction record
- Updates resource statistics
- Triggers recommendation engine update
- May award skill progress if interaction contributes to competency evidence

**Rate Limit:** 60 requests/minute per user (high frequency for video progress tracking)

---

### Learning Path Tools

#### 8.13.9 Get Path Progress
Retrieves detailed progress through a learning path with step statuses and unlock logic.

```typescript
{
  name: "academy_get_path_progress",
  description: "Get detailed progress through a learning path with unlock status",
  inputSchema: {
    type: "object",
    properties: {
      userId: {
        type: "string",
        description: "User ID (optional, defaults to authenticated user)"
      },
      pathId: {
        type: "string",
        description: "Learning path ID"
      },
      enrollmentId: {
        type: "string",
        description: "Path enrollment ID (alternative to userId + pathId)"
      },
      includeStepDetails: {
        type: "boolean",
        description: "Include detailed step information (default: true)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  pathId: "path_456",
  pathName: "AI Leadership Track",
  enrollmentId: "enr_path_789",
  userId: "usr_456",
  enrolledAt: "2024-10-01T10:00:00Z",
  status: "in_progress", // active, in_progress, completed, paused
  overallProgress: {
    completionPercent: 60,
    stepsCompleted: 3,
    stepsTotal: 5,
    estimatedTimeRemaining: "4 weeks",
    onTrack: true
  },
  steps: [
    {
      stepId: "stp_123",
      courseId: "crs_ai_foundations",
      courseName: "AI Foundations for Business Leaders",
      stepNumber: 1,
      status: "completed",
      unlockedAt: "2024-10-01T10:00:00Z",
      completedAt: "2024-10-15T10:00:00Z",
      cohortId: "coh_456",
      cohortName: "October 2024 Cohort",
      certificateEarned: true,
      certificateId: "cert_789"
    },
    {
      stepId: "stp_124",
      courseId: "crs_ai_strategy",
      courseName: "AI Strategy for Executives",
      stepNumber: 2,
      status: "completed",
      unlockedAt: "2024-10-15T10:00:00Z",
      completedAt: "2024-11-05T10:00:00Z",
      cohortId: "coh_457",
      certificateEarned: true
    },
    {
      stepId: "stp_125",
      courseId: "crs_change_management",
      courseName: "AI Change Management",
      stepNumber: 3,
      status: "in_progress",
      unlockedAt: "2024-11-05T10:00:00Z",
      startedAt: "2024-11-10T10:00:00Z",
      cohortId: "coh_458",
      cohortStatus: "in_progress",
      progressPercent: 45
    },
    {
      stepId: "stp_126",
      courseId: "crs_implementation",
      courseName: "AI Implementation Workshop",
      stepNumber: 4,
      status: "locked",
      unlockCondition: {
        type: "prerequisite_completion",
        prerequisiteStepId: "stp_125",
        message: "Complete AI Change Management to unlock"
      },
      nextAvailableCohort: {
        cohortId: "coh_459",
        startDate: "2025-01-15",
        spotsAvailable: 12
      }
    },
    {
      stepId: "stp_127",
      courseId: "crs_capstone",
      courseName: "AI Leadership Capstone",
      stepNumber: 5,
      status: "locked",
      unlockCondition: {
        type: "time_based",
        prerequisiteStepId: "stp_126",
        daysAfterPrevious: 30,
        message: "Available 30 days after completing Implementation Workshop"
      }
    }
  ],
  skillsProgress: [
    {
      skillId: "skl_789",
      skillName: "AI Strategy",
      targetLevel: "advanced",
      currentLevel: "practitioner",
      progressPercent: 75
    },
    {
      skillId: "skl_890",
      skillName: "Change Leadership",
      targetLevel: "advanced",
      currentLevel: "foundational",
      progressPercent: 30
    }
  ],
  pathCertificate: { // Only present if path completed
    certificateId: null,
    eligibleForCertificate: false,
    requirementsRemaining: [
      "Complete AI Change Management course",
      "Complete AI Implementation Workshop",
      "Complete AI Leadership Capstone"
    ]
  },
  pricing: {
    pricingModel: "bundled",
    bundlePrice: 12000, // cents
    totalIndividualPrice: 15000, // cents
    savings: 3000, // cents (20% discount)
    paymentStatus: "completed"
  }
}
```

**Required Scope:** `enrollments:read`

**Access Control:** Users can only view their own path progress unless `admin:enrollments` scope

---

#### 8.13.10 Check Step Unlock
Checks if the next learning path step should unlock based on completion rules.

```typescript
{
  name: "academy_check_step_unlock",
  description: "Check if next step in learning path should unlock",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Path enrollment ID"
      },
      stepId: {
        type: "string",
        description: "Step ID to check unlock status"
      },
      autoUnlock: {
        type: "boolean",
        description: "Automatically unlock if conditions met (default: false)"
      }
    },
    required: ["enrollmentId", "stepId"]
  }
}
```

**Response Format:**
```typescript
{
  stepId: "stp_126",
  courseName: "AI Implementation Workshop",
  unlockStatus: "ready", // locked, ready, unlocked, countdown
  canUnlock: true,
  unlockCondition: {
    type: "prerequisite_completion",
    prerequisiteStepId: "stp_125",
    prerequisiteStepName: "AI Change Management",
    requirement: "complete_with_certificate",
    met: true,
    metAt: "2024-11-30T10:00:00Z"
  },
  additionalConditions: [
    {
      type: "time_based",
      daysAfterPrevious: 7,
      met: true,
      metAt: "2024-12-07T10:00:00Z",
      message: "Minimum 7-day interval between courses"
    }
  ],
  countdown: null, // Present if time_based condition not yet met
  nextActions: [
    {
      action: "enroll",
      message: "Enroll in the next available cohort",
      availableCohorts: [
        {
          cohortId: "coh_459",
          startDate: "2025-01-15",
          spotsAvailable: 12
        },
        {
          cohortId: "coh_460",
          startDate: "2025-02-10",
          spotsAvailable: 25
        }
      ]
    }
  ],
  unlocked: true, // True if autoUnlock was true and unlock was performed
  unlockedAt: "2024-12-15T10:00:00Z"
}
```

**Required Scope:** `enrollments:write` (if autoUnlock is true), otherwise `enrollments:read`

**Side Effects (if autoUnlock: true):**
- Updates step status to "unlocked"
- Sends notification email to user
- Updates path progress
- Logs unlock event

---

#### 8.13.11 Generate Path Certificate
Generates a completion certificate for a learning path with all courses and skills achieved.

```typescript
{
  name: "academy_generate_path_certificate",
  description: "Generate completion certificate for learning path",
  inputSchema: {
    type: "object",
    properties: {
      enrollmentId: {
        type: "string",
        description: "Path enrollment ID"
      },
      format: {
        type: "string",
        enum: ["metadata", "pdf_url", "badge_json", "all"],
        description: "Response format (default: all)"
      }
    },
    required: ["enrollmentId"]
  }
}
```

**Response Format:**
```typescript
{
  certificate: {
    id: "cert_path_123",
    type: "learning_path_completion",
    pathId: "path_456",
    pathName: "AI Leadership Track",
    enrollmentId: "enr_path_789",
    userId: "usr_456",
    learnerName: "Sarah Johnson",
    issuedAt: "2024-12-15T10:00:00Z",
    credentialId: "PATH-2025-001234",
    verificationUrl: "https://academy.com/verify/cert_path_123"
  },
  coursesCompleted: [
    {
      courseId: "crs_ai_foundations",
      courseName: "AI Foundations for Business Leaders",
      completedAt: "2024-10-15T10:00:00Z",
      certificateId: "cert_789"
    },
    {
      courseId: "crs_ai_strategy",
      courseName: "AI Strategy for Executives",
      completedAt: "2024-11-05T10:00:00Z",
      certificateId: "cert_790"
    },
    {
      courseId: "crs_change_management",
      courseName: "AI Change Management",
      completedAt: "2024-11-30T10:00:00Z",
      certificateId: "cert_791"
    },
    {
      courseId: "crs_implementation",
      courseName: "AI Implementation Workshop",
      completedAt: "2024-12-10T10:00:00Z",
      certificateId: "cert_792"
    },
    {
      courseId: "crs_capstone",
      courseName: "AI Leadership Capstone",
      completedAt: "2024-12-15T10:00:00Z",
      certificateId: "cert_793"
    }
  ],
  skillsAchieved: [
    {
      skillId: "skl_789",
      skillName: "AI Strategy",
      level: "advanced",
      badgeId: "bdg_456"
    },
    {
      skillId: "skl_890",
      skillName: "Change Leadership",
      level: "advanced",
      badgeId: "bdg_457"
    },
    {
      skillId: "skl_891",
      skillName: "AI Implementation",
      level: "practitioner",
      badgeId: "bdg_458"
    }
  ],
  pathStats: {
    totalDuration: "12 weeks",
    totalCourses: 5,
    totalHours: 72,
    startDate: "2024-10-01",
    completionDate: "2024-12-15"
  },
  badge: {
    badgeId: "bdg_path_234",
    name: "AI Leadership Track - Path Completion",
    description: "Successfully completed comprehensive AI Leadership Track including strategy, change management, and implementation courses",
    badgeImageUrl: "https://academy.com/badges/path_456.png",
    openBadgeUrl: "https://academy.com/badges/path_456.json",
    openBadgeData: {
      "@context": "https://w3id.org/openbadges/v2",
      "type": "Assertion",
      "id": "https://academy.com/badges/path_456.json",
      "badge": {
        "type": "BadgeClass",
        "id": "https://academy.com/badge-classes/ai-leadership-track",
        "name": "AI Leadership Track Completion",
        "description": "Comprehensive leadership program...",
        "image": "https://academy.com/badges/path_456.png",
        "criteria": {
          "narrative": "Complete all 5 courses in AI Leadership Track..."
        },
        "issuer": {
          "type": "Profile",
          "id": "https://academy.com/issuer",
          "name": "AI Enablement Academy",
          "url": "https://aienablement.academy"
        }
      },
      "recipient": {
        "type": "email",
        "hashed": false,
        "identity": "sarah@company.com"
      },
      "issuedOn": "2024-12-15T10:00:00Z",
      "verification": {
        "type": "hosted",
        "url": "https://academy.com/verify/cert_path_123"
      }
    }
  },
  downloads: {
    pdf: "https://academy.com/certificates/cert_path_123.pdf?token=xxx",
    png: "https://academy.com/certificates/cert_path_123.png?token=xxx",
    badge: "https://academy.com/badges/path_456.png?token=xxx"
  },
  sharing: {
    linkedInShareUrl: "https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Facademy.com%2Fverify%2Fcert_path_123",
    twitterShareUrl: "https://twitter.com/intent/tweet?text=I%20completed%20the%20AI%20Leadership%20Track...",
    emailSubject: "I completed the AI Leadership Track at AI Enablement Academy",
    emailBody: "I'm excited to share that I completed..."
  }
}
```

**Required Scope:** `certificates:read`

**Access Control:** User must have completed all path steps and have active enrollment

**Side Effects:**
- Generates certificate PDF
- Creates badge record
- Publishes Open Badge JSON
- Sends congratulations email
- Updates path completion statistics

---

### Performance & Analytics Tools

#### tool: academy_get_performance_metrics
Get Lighthouse and Core Web Vitals metrics for monitoring platform performance.

```typescript
{
  name: "academy_get_performance_metrics",
  description: "Get Lighthouse and Core Web Vitals metrics with trends",
  inputSchema: {
    type: "object",
    properties: {
      pageUrl: {
        type: "string",
        description: "Specific page URL to get metrics for (optional, defaults to dashboard)"
      },
      period: {
        type: "string",
        enum: ["day", "week", "month"],
        description: "Time period for metrics (default: day)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  pageUrl: "https://academy.com/dashboard",
  period: "day",
  timestamp: "2024-12-15T10:00:00Z",
  coreWebVitals: {
    lcp: {
      value: 1.8,
      unit: "seconds",
      rating: "good", // good, needs-improvement, poor
      threshold: { good: 2.5, poor: 4.0 },
      trend: {
        previous: 2.1,
        change: -14.3,
        direction: "improving"
      }
    },
    inp: {
      value: 120,
      unit: "milliseconds",
      rating: "good",
      threshold: { good: 200, poor: 500 },
      trend: {
        previous: 140,
        change: -14.3,
        direction: "improving"
      }
    },
    cls: {
      value: 0.08,
      unit: "score",
      rating: "good",
      threshold: { good: 0.1, poor: 0.25 },
      trend: {
        previous: 0.12,
        change: -33.3,
        direction: "improving"
      }
    },
    fcp: {
      value: 1.2,
      unit: "seconds",
      rating: "good",
      threshold: { good: 1.8, poor: 3.0 },
      trend: {
        previous: 1.5,
        change: -20.0,
        direction: "improving"
      }
    }
  },
  lighthouseScores: {
    performance: {
      score: 92,
      rating: "good",
      trend: { previous: 88, change: 4.5 }
    },
    accessibility: {
      score: 98,
      rating: "good",
      trend: { previous: 97, change: 1.0 }
    },
    bestPractices: {
      score: 95,
      rating: "good",
      trend: { previous: 93, change: 2.2 }
    },
    seo: {
      score: 100,
      rating: "good",
      trend: { previous: 100, change: 0.0 }
    }
  },
  fieldData: {
    sampleSize: 1284,
    p75Values: { // 75th percentile (real user measurements)
      lcp: 2.1,
      inp: 150,
      cls: 0.09,
      fcp: 1.4
    }
  },
  recommendations: [
    {
      priority: "high",
      metric: "LCP",
      issue: "Slow server response time",
      suggestion: "Optimize database queries for dashboard data"
    }
  ]
}
```

**Required Scope:** `analytics:read`

**Notes:**
- Metrics are aggregated from real user monitoring (RUM)
- Field data represents actual user experiences
- Trends compare to previous period of same length
- Recommendations prioritized by impact on user experience

**Rate Limit:** 10 requests/minute per API key

---

#### tool: academy_get_error_rates
Get error rates and types for monitoring platform stability.

```typescript
{
  name: "academy_get_error_rates",
  description: "Get error rates and types with trends",
  inputSchema: {
    type: "object",
    properties: {
      period: {
        type: "string",
        enum: ["day", "week", "month"],
        description: "Time period for error data (default: day)"
      },
      severity: {
        type: "string",
        enum: ["critical", "error", "warning", "all"],
        description: "Filter by severity level (default: all)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  period: "day",
  severity: "all",
  timestamp: "2024-12-15T10:00:00Z",
  summary: {
    totalErrors: 42,
    errorRate: 0.12, // Errors per 100 requests
    affectedUsers: 18,
    affectedUserRate: 0.05, // 5% of active users
    trend: {
      previousTotal: 38,
      change: 10.5,
      direction: "increasing"
    }
  },
  errorsByType: [
    {
      type: "API_ERROR",
      errorCode: "ERR_TIMEOUT",
      count: 15,
      percentage: 35.7,
      severity: "error",
      affectedUsers: 8,
      examples: [
        {
          message: "Request timeout fetching course data",
          endpoint: "/api/courses/:id",
          timestamp: "2024-12-15T09:45:23Z",
          userId: "usr_456"
        }
      ],
      trend: {
        previous: 10,
        change: 50.0,
        direction: "increasing"
      }
    },
    {
      type: "VALIDATION_ERROR",
      errorCode: "ERR_INVALID_INPUT",
      count: 12,
      percentage: 28.6,
      severity: "warning",
      affectedUsers: 7,
      examples: [
        {
          message: "Invalid email format in profile update",
          endpoint: "/api/users/:id/profile",
          timestamp: "2024-12-15T09:30:15Z",
          userId: "usr_789"
        }
      ],
      trend: {
        previous: 15,
        change: -20.0,
        direction: "improving"
      }
    },
    {
      type: "CLIENT_ERROR",
      errorCode: "ERR_4XX",
      count: 10,
      percentage: 23.8,
      severity: "warning",
      affectedUsers: 5,
      examples: [
        {
          message: "404 Not Found: Resource not found",
          endpoint: "/api/resources/res_999",
          timestamp: "2024-12-15T08:15:42Z",
          userId: "usr_321"
        }
      ],
      trend: {
        previous: 8,
        change: 25.0,
        direction: "increasing"
      }
    },
    {
      type: "SERVER_ERROR",
      errorCode: "ERR_5XX",
      count: 5,
      percentage: 11.9,
      severity: "critical",
      affectedUsers: 4,
      examples: [
        {
          message: "500 Internal Server Error: Database connection failed",
          endpoint: "/api/courses",
          timestamp: "2024-12-15T07:22:11Z",
          userId: "usr_654"
        }
      ],
      trend: {
        previous: 5,
        change: 0.0,
        direction: "stable"
      }
    }
  ],
  topAffectedEndpoints: [
    {
      endpoint: "/api/courses/:id",
      errorCount: 15,
      errorRate: 0.25,
      primaryErrorType: "API_ERROR"
    },
    {
      endpoint: "/api/users/:id/profile",
      errorCount: 12,
      errorRate: 0.18,
      primaryErrorType: "VALIDATION_ERROR"
    }
  ],
  severityBreakdown: {
    critical: { count: 5, percentage: 11.9 },
    error: { count: 25, percentage: 59.5 },
    warning: { count: 12, percentage: 28.6 }
  }
}
```

**Required Scope:** `analytics:read`

**Notes:**
- Error rates exclude expected user errors (e.g., wrong password)
- Affected user count is deduplicated
- Examples limited to 3 most recent per error type
- User IDs included only for `admin:analytics` scope
- Trends compare to previous period of same length

**Rate Limit:** 10 requests/minute per API key

---

#### tool: academy_get_user_analytics
Get aggregated user behavior analytics respecting privacy.

```typescript
{
  name: "academy_get_user_analytics",
  description: "Get aggregated user behavior analytics with privacy controls",
  inputSchema: {
    type: "object",
    properties: {
      period: {
        type: "string",
        enum: ["day", "week", "month"],
        description: "Time period for analytics (default: day)"
      },
      metrics: {
        type: "array",
        items: {
          type: "string",
          enum: [
            "pageviews",
            "sessions",
            "active_users",
            "engagement",
            "retention",
            "conversion",
            "all"
          ]
        },
        description: "Specific metrics to retrieve (default: all)"
      }
    }
  }
}
```

**Response Format:**
```typescript
{
  period: "day",
  timestamp: "2024-12-15T10:00:00Z",
  dateRange: {
    start: "2024-12-15T00:00:00Z",
    end: "2024-12-15T23:59:59Z"
  },
  pageviews: {
    total: 15284,
    unique: 3421,
    averagePerUser: 4.5,
    trend: {
      previous: 14120,
      change: 8.2,
      direction: "increasing"
    },
    topPages: [
      {
        path: "/dashboard",
        views: 3284,
        uniqueVisitors: 1821,
        avgTimeOnPage: 120 // seconds
      },
      {
        path: "/courses/ai-foundations",
        views: 2156,
        uniqueVisitors: 987,
        avgTimeOnPage: 360
      },
      {
        path: "/resources",
        views: 1843,
        uniqueVisitors: 756,
        avgTimeOnPage: 240
      }
    ]
  },
  sessions: {
    total: 4521,
    averageDuration: 480, // seconds (8 minutes)
    bounceRate: 0.32, // 32%
    trend: {
      previous: 4123,
      change: 9.7,
      direction: "increasing"
    }
  },
  activeUsers: {
    total: 3421,
    new: 284,
    returning: 3137,
    trend: {
      previous: 3156,
      change: 8.4,
      direction: "increasing"
    },
    usersByActivity: {
      daily: 3421,
      weekly: 8234,
      monthly: 12847
    }
  },
  engagement: {
    averageSessionsPerUser: 1.32,
    averagePageviewsPerSession: 3.4,
    averageEngagementTime: 6.2, // minutes
    engagementRate: 0.78, // 78% of sessions show meaningful engagement
    trend: {
      previous: 0.74,
      change: 5.4,
      direction: "increasing"
    }
  },
  retention: {
    day1: 0.82, // 82% return next day
    day7: 0.65, // 65% return within 7 days
    day30: 0.54, // 54% return within 30 days
    cohortAnalysis: {
      cohortDate: "2024-11-15",
      cohortSize: 284,
      retainedUsers: 189,
      retentionRate: 0.67
    }
  },
  conversion: {
    enrollmentRate: 0.24, // 24% of visitors enroll in a course
    completionRate: 0.68, // 68% of enrollments complete
    certificateRate: 0.58, // 58% earn certificates
    funnelSteps: [
      {
        step: "landing_page",
        users: 3421,
        dropoffRate: 0.0
      },
      {
        step: "course_view",
        users: 2156,
        dropoffRate: 0.37
      },
      {
        step: "enrollment",
        users: 821,
        dropoffRate: 0.62
      },
      {
        step: "module_start",
        users: 756,
        dropoffRate: 0.08
      },
      {
        step: "course_complete",
        users: 514,
        dropoffRate: 0.32
      }
    ]
  },
  trafficSources: [
    {
      source: "direct",
      sessions: 1584,
      percentage: 35.0,
      bounceRate: 0.28
    },
    {
      source: "organic_search",
      sessions: 1356,
      percentage: 30.0,
      bounceRate: 0.35
    },
    {
      source: "referral",
      sessions: 905,
      percentage: 20.0,
      bounceRate: 0.32
    },
    {
      source: "social",
      sessions: 452,
      percentage: 10.0,
      bounceRate: 0.42
    },
    {
      source: "email",
      sessions: 224,
      percentage: 5.0,
      bounceRate: 0.18
    }
  ],
  devices: {
    desktop: { sessions: 2713, percentage: 60.0 },
    mobile: { sessions: 1356, percentage: 30.0 },
    tablet: { sessions: 452, percentage: 10.0 }
  }
}
```

**Required Scope:** `analytics:read`

**Privacy & Compliance:**
- All data is aggregated and anonymized
- No personally identifiable information (PII) included
- Compliant with GDPR, CCPA privacy requirements
- Individual user tracking requires explicit consent
- Data retention follows privacy policy (90 days)
- Users can opt-out via privacy settings

**Notes:**
- Metrics use privacy-preserving aggregation
- Trends compare to previous period of same length
- Engagement time excludes idle/background time
- Bounce rate: sessions with <10s engagement
- Conversion funnel shows typical user journey

**Rate Limit:** 10 requests/minute per API key

---

## 8.14 v2.1 Scope Additions

Update the `SCOPES` definition to include new v2.1 scopes:

```typescript
const SCOPES_V2_1 = {
  // Skills scopes
  "skills:read": {
    description: "Read user skill profiles, progress, and leaderboards",
    tools: [
      "academy_get_user_skill_profile",
      "academy_suggest_next_skill",
      "academy_get_skill_leaderboard"
    ]
  },
  "skills:write": {
    description: "Record competency evidence and update skill progress",
    tools: ["academy_record_competency_evidence"]
  },
  "admin:skills": {
    description: "Manage skills, competencies, and view all learner progress",
    tools: [], // Admin dashboard operations
    resources: ["academy://skills/leaderboards", "academy://skills/analytics"]
  },

  // Resources scopes
  "resources:read": {
    description: "Search and access resource library based on access level",
    tools: [
      "academy_search_resources",
      "academy_get_glossary_term",
      "academy_get_prompt_template"
    ]
  },
  "resources:write": {
    description: "Track resource usage for analytics",
    tools: ["academy_track_resource_usage"]
  },

  // Learning paths scopes (extends existing enrollments scopes)
  "paths:read": {
    description: "View learning path progress and unlock status",
    tools: [
      "academy_get_path_progress",
      "academy_check_step_unlock"
    ]
  },
  "paths:write": {
    description: "Unlock path steps and generate certificates",
    tools: ["academy_generate_path_certificate"],
    requires: ["enrollments:write"]
  },

  // Analytics scopes
  "analytics:read": {
    description: "Access aggregated performance metrics, error rates, and user analytics",
    tools: [
      "academy_get_performance_metrics",
      "academy_get_error_rates",
      "academy_get_user_analytics"
    ]
  },
  "admin:analytics": {
    description: "Access detailed analytics including user identifiers and raw data",
    tools: [
      "academy_get_performance_metrics",
      "academy_get_error_rates",
      "academy_get_user_analytics"
    ],
    resources: ["academy://analytics/raw", "academy://analytics/users"]
  }
};
```

---

## 8.15 v2.1 Resource URIs

Add these resource URIs for v2.1 features:

```typescript
const RESOURCES_V2_1 = [
  {
    uri: "academy://skills",
    name: "Skills Catalog",
    description: "Complete skills taxonomy with categories and levels",
    mimeType: "application/json"
  },
  {
    uri: "academy://skills/{skillId}/leaderboard",
    name: "Skill Leaderboard",
    description: "Top performers for a specific skill",
    mimeType: "application/json"
  },
  {
    uri: "academy://resources/catalog",
    name: "Resource Library Catalog",
    description: "Searchable resource library with filters",
    mimeType: "application/json"
  },
  {
    uri: "academy://resources/glossary",
    name: "AI Glossary",
    description: "Complete glossary of AI terms and concepts",
    mimeType: "application/json"
  },
  {
    uri: "academy://resources/prompts",
    name: "Prompt Library",
    description: "Curated prompt templates by category",
    mimeType: "application/json"
  },
  {
    uri: "academy://paths",
    name: "Learning Paths Catalog",
    description: "Available learning paths with pricing",
    mimeType: "application/json"
  },
  {
    uri: "academy://paths/{pathId}/progress/{userId}",
    name: "Path Progress",
    description: "Detailed progress through a learning path",
    mimeType: "application/json"
  }
];
```

---

## 8.16 v2.1 Error Codes

Additional error codes for v2.1 features:

| Code | HTTP Status | Description | Retry? |
|------|-------------|-------------|--------|
| SKILL_NOT_FOUND | 404 | Skill ID not found | No |
| COMPETENCY_NOT_FOUND | 404 | Competency ID not found | No |
| EVIDENCE_VALIDATION_FAILED | 400 | Evidence data invalid or incomplete | No |
| SKILL_PREREQUISITE_NOT_MET | 403 | Skill requires prerequisite completion | No |
| RESOURCE_ACCESS_DENIED | 403 | User lacks access level for resource | No |
| GLOSSARY_TERM_NOT_FOUND | 404 | Glossary term not found | No |
| PROMPT_VARIABLE_MISSING | 400 | Required prompt variable not provided | No |
| PATH_NOT_FOUND | 404 | Learning path not found | No |
| PATH_STEP_LOCKED | 403 | Step cannot be unlocked yet | No |
| PATH_NOT_COMPLETED | 403 | Path not completed for certificate | No |

---

This completes the MCP Server specification for the AI Enablement Academy v2 platform, including the comprehensive v2.1 Skills, Resources, and Learning Paths systems.
