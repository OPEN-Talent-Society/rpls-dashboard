# 6.3 MCP Server Specification

## 6.3.1 Overview

The AI Enablement Academy exposes a Model Context Protocol (MCP) server that enables AI agents (Claude, GPT, custom agents, etc.) to interact with the learning platform programmatically. This MCP server provides a standardized interface for:

- **Learner Self-Service**: AI agents can help learners discover courses, check enrollment status, access materials, and retrieve certificates
- **Administrative Automation**: Platform administrators can automate cohort management, enrollment processing, and learner communications
- **B2B Integration**: Enterprise clients can integrate AI agents for bulk enrollment management and organizational reporting
- **Educational Enhancement**: Instructors can build AI-powered tools for personalized learning experiences

### Architecture

The MCP server is implemented as a Convex HTTP action layer that:
1. Authenticates requests via API keys with role-based scopes
2. Executes database queries and mutations through Convex queries/mutations
3. Returns responses in MCP-compliant JSON format
4. Supports both synchronous and streaming operations for long-running tasks

### Key Features

- **Role-Based Access Control**: Separate tool sets for learners, instructors, and administrators
- **Real-Time Data**: Direct integration with Convex ensures up-to-date enrollment and cohort information
- **Audit Trail**: All MCP operations are logged with timestamp, user, and action details
- **Rate Limiting**: 60 requests/minute per API key to prevent abuse
- **Streaming Support**: Long-running operations (bulk enrollments, certificate generation) support Server-Sent Events (SSE)

---

## 6.3.2 Available Tools

### Learner-Facing Tools

These tools are available to any authenticated learner and provide read-only access to their own data.

#### 6.3.2.1 `get_learner_enrollments`

Retrieves all enrollments for the authenticated learner, including past, current, and upcoming cohorts.

```typescript
interface GetLearnerEnrollmentsInput {
  // No parameters required - uses authenticated user context
}

interface Enrollment {
  id: string;
  cohortId: string;
  cohortName: string;
  courseTitle: string;
  courseSlug: string;
  status: "pending" | "active" | "completed" | "withdrawn";
  enrolledAt: number; // Unix timestamp
  completedAt?: number; // Unix timestamp
  certificateUrl?: string;
  progressPercentage: number;
  startDate: number;
  endDate: number;
  instructorName: string;
  modality: "online" | "in-person" | "hybrid";
}

interface GetLearnerEnrollmentsOutput {
  enrollments: Enrollment[];
  totalCount: number;
}
```

**Example Tool Call:**
```json
{
  "name": "get_learner_enrollments",
  "arguments": {}
}
```

**Example Response:**
```json
{
  "enrollments": [
    {
      "id": "enr_abc123",
      "cohortId": "coh_xyz789",
      "cohortName": "AI Fundamentals - January 2025",
      "courseTitle": "AI Fundamentals for Business Leaders",
      "courseSlug": "ai-fundamentals",
      "status": "active",
      "enrolledAt": 1704067200000,
      "progressPercentage": 65,
      "startDate": 1704153600000,
      "endDate": 1704758400000,
      "instructorName": "Dr. Sarah Chen",
      "modality": "online"
    },
    {
      "id": "enr_def456",
      "cohortId": "coh_uvw456",
      "cohortName": "Prompt Engineering - December 2024",
      "courseTitle": "Advanced Prompt Engineering",
      "courseSlug": "prompt-engineering",
      "status": "completed",
      "enrolledAt": 1701388800000,
      "completedAt": 1703980800000,
      "certificateUrl": "https://cdn.academy.ai/certificates/enr_def456.pdf",
      "progressPercentage": 100,
      "startDate": 1701561600000,
      "endDate": 1703980800000,
      "instructorName": "Marcus Johnson",
      "modality": "in-person"
    }
  ],
  "totalCount": 2
}
```

---

#### 6.3.2.2 `get_course_details`

Retrieves comprehensive information about a specific course, including curriculum, prerequisites, and upcoming cohorts.

```typescript
interface GetCourseDetailsInput {
  courseSlug: string; // URL-friendly course identifier
}

interface CourseDetails {
  id: string;
  title: string;
  slug: string;
  description: string;
  longDescription: string;
  duration: string; // e.g., "2 days intensive"
  level: "beginner" | "intermediate" | "advanced";
  prerequisites: string[];
  learningObjectives: string[];
  curriculum: {
    moduleNumber: number;
    title: string;
    topics: string[];
    duration: string;
  }[];
  pricing: {
    individual: number;
    corporate: number;
    currency: "USD";
  };
  upcomingCohorts: {
    cohortId: string;
    cohortName: string;
    startDate: number;
    endDate: number;
    modality: "online" | "in-person" | "hybrid";
    location?: string;
    availableSeats: number;
    totalSeats: number;
    instructorName: string;
  }[];
  enablementKitIncluded: boolean;
  certificateOffered: boolean;
}

interface GetCourseDetailsOutput {
  course: CourseDetails;
}
```

**Example Tool Call:**
```json
{
  "name": "get_course_details",
  "arguments": {
    "courseSlug": "ai-fundamentals"
  }
}
```

**Example Response:**
```json
{
  "course": {
    "id": "crs_ai_fund_001",
    "title": "AI Fundamentals for Business Leaders",
    "slug": "ai-fundamentals",
    "description": "2-day intensive workshop for executives and managers to understand AI capabilities and strategic applications",
    "longDescription": "This comprehensive program equips business leaders with the knowledge to evaluate AI opportunities, understand technical constraints, and lead AI transformation initiatives within their organizations.",
    "duration": "2 days (16 hours total)",
    "level": "beginner",
    "prerequisites": [
      "Basic understanding of business strategy",
      "No technical background required"
    ],
    "learningObjectives": [
      "Understand core AI/ML concepts and terminology",
      "Evaluate AI use cases for business value",
      "Identify technical and organizational constraints",
      "Develop AI transformation roadmaps"
    ],
    "curriculum": [
      {
        "moduleNumber": 1,
        "title": "AI Landscape & Capabilities",
        "topics": [
          "Machine Learning fundamentals",
          "Large Language Models (LLMs)",
          "Computer Vision & NLP",
          "AI vs. traditional software"
        ],
        "duration": "4 hours"
      },
      {
        "moduleNumber": 2,
        "title": "Strategic AI Applications",
        "topics": [
          "Use case identification",
          "ROI evaluation frameworks",
          "Build vs. buy decisions",
          "Vendor evaluation"
        ],
        "duration": "4 hours"
      },
      {
        "moduleNumber": 3,
        "title": "AI Implementation & Governance",
        "topics": [
          "Data readiness assessment",
          "Team structure & skills",
          "Ethics & bias mitigation",
          "Compliance & risk management"
        ],
        "duration": "4 hours"
      },
      {
        "moduleNumber": 4,
        "title": "AI Transformation Roadmap",
        "topics": [
          "Phased rollout strategies",
          "Change management",
          "Measuring success",
          "Workshop: Build your roadmap"
        ],
        "duration": "4 hours"
      }
    ],
    "pricing": {
      "individual": 2500,
      "corporate": 2000,
      "currency": "USD"
    },
    "upcomingCohorts": [
      {
        "cohortId": "coh_xyz789",
        "cohortName": "AI Fundamentals - January 2025",
        "startDate": 1704153600000,
        "endDate": 1704758400000,
        "modality": "online",
        "availableSeats": 8,
        "totalSeats": 25,
        "instructorName": "Dr. Sarah Chen"
      },
      {
        "cohortId": "coh_abc123",
        "cohortName": "AI Fundamentals - February 2025 (NYC)",
        "startDate": 1706745600000,
        "endDate": 1707350400000,
        "modality": "in-person",
        "location": "New York, NY",
        "availableSeats": 15,
        "totalSeats": 20,
        "instructorName": "Marcus Johnson"
      }
    ],
    "enablementKitIncluded": true,
    "certificateOffered": true
  }
}
```

---

#### 6.3.2.3 `get_upcoming_cohorts`

Lists all upcoming cohorts across all courses, optionally filtered by course.

```typescript
interface GetUpcomingCohortsInput {
  courseId?: string; // Optional filter by specific course
  modality?: "online" | "in-person" | "hybrid"; // Optional modality filter
  startDateAfter?: number; // Optional: only cohorts starting after this timestamp
  limit?: number; // Default: 20, Max: 100
}

interface CohortListing {
  cohortId: string;
  cohortName: string;
  courseId: string;
  courseTitle: string;
  courseSlug: string;
  startDate: number;
  endDate: number;
  modality: "online" | "in-person" | "hybrid";
  location?: string;
  availableSeats: number;
  totalSeats: number;
  instructorName: string;
  instructorBio: string;
  pricing: {
    individual: number;
    corporate: number;
    currency: "USD";
  };
  registrationDeadline: number;
  status: "scheduled" | "open" | "waitlist" | "full";
}

interface GetUpcomingCohortsOutput {
  cohorts: CohortListing[];
  totalCount: number;
  hasMore: boolean;
}
```

**Example Tool Call:**
```json
{
  "name": "get_upcoming_cohorts",
  "arguments": {
    "modality": "online",
    "startDateAfter": 1704067200000,
    "limit": 10
  }
}
```

**Example Response:**
```json
{
  "cohorts": [
    {
      "cohortId": "coh_xyz789",
      "cohortName": "AI Fundamentals - January 2025",
      "courseId": "crs_ai_fund_001",
      "courseTitle": "AI Fundamentals for Business Leaders",
      "courseSlug": "ai-fundamentals",
      "startDate": 1704153600000,
      "endDate": 1704758400000,
      "modality": "online",
      "availableSeats": 8,
      "totalSeats": 25,
      "instructorName": "Dr. Sarah Chen",
      "instructorBio": "15+ years in AI research, former Google Brain researcher",
      "pricing": {
        "individual": 2500,
        "corporate": 2000,
        "currency": "USD"
      },
      "registrationDeadline": 1703980800000,
      "status": "open"
    }
  ],
  "totalCount": 1,
  "hasMore": false
}
```

---

#### 6.3.2.4 `check_enrollment_status`

Checks if the authenticated user is enrolled in a specific cohort and returns enrollment details.

```typescript
interface CheckEnrollmentStatusInput {
  cohortId: string;
}

interface EnrollmentStatus {
  isEnrolled: boolean;
  enrollmentId?: string;
  status?: "pending" | "active" | "completed" | "withdrawn";
  enrolledAt?: number;
  progressPercentage?: number;
  canEnroll: boolean; // True if user can enroll (seats available, not enrolled, meets prerequisites)
  enrollmentBlockers?: string[]; // Reasons why enrollment is blocked
}

interface CheckEnrollmentStatusOutput {
  enrollment: EnrollmentStatus;
}
```

**Example Tool Call (Enrolled User):**
```json
{
  "name": "check_enrollment_status",
  "arguments": {
    "cohortId": "coh_xyz789"
  }
}
```

**Example Response (Enrolled):**
```json
{
  "enrollment": {
    "isEnrolled": true,
    "enrollmentId": "enr_abc123",
    "status": "active",
    "enrolledAt": 1704067200000,
    "progressPercentage": 65,
    "canEnroll": false,
    "enrollmentBlockers": ["Already enrolled in this cohort"]
  }
}
```

**Example Response (Not Enrolled, Can Enroll):**
```json
{
  "enrollment": {
    "isEnrolled": false,
    "canEnroll": true,
    "enrollmentBlockers": []
  }
}
```

**Example Response (Not Enrolled, Cohort Full):**
```json
{
  "enrollment": {
    "isEnrolled": false,
    "canEnroll": false,
    "enrollmentBlockers": [
      "Cohort is at full capacity (25/25 seats)",
      "Registration deadline has passed"
    ]
  }
}
```

---

#### 6.3.2.5 `get_enablement_kit`

Retrieves the Enablement Kit materials for a specific enrollment, including downloadable resources.

```typescript
interface GetEnablementKitInput {
  enrollmentId: string;
}

interface EnablementKitMaterial {
  id: string;
  title: string;
  type: "pdf" | "video" | "interactive" | "template" | "tool";
  description: string;
  downloadUrl: string;
  fileSize?: number; // bytes
  duration?: string; // For videos
  updatedAt: number;
}

interface EnablementKit {
  enrollmentId: string;
  cohortName: string;
  courseTitle: string;
  generatedAt: number;
  materials: EnablementKitMaterial[];
  customResources: {
    organizationName?: string; // For B2B enrollments
    customTemplates?: EnablementKitMaterial[];
  };
}

interface GetEnablementKitOutput {
  kit: EnablementKit;
}
```

**Example Tool Call:**
```json
{
  "name": "get_enablement_kit",
  "arguments": {
    "enrollmentId": "enr_abc123"
  }
}
```

**Example Response:**
```json
{
  "kit": {
    "enrollmentId": "enr_abc123",
    "cohortName": "AI Fundamentals - January 2025",
    "courseTitle": "AI Fundamentals for Business Leaders",
    "generatedAt": 1704153600000,
    "materials": [
      {
        "id": "mat_001",
        "title": "AI Strategy Playbook",
        "type": "pdf",
        "description": "Comprehensive guide to developing AI strategy",
        "downloadUrl": "https://cdn.academy.ai/kits/enr_abc123/playbook.pdf",
        "fileSize": 2457600,
        "updatedAt": 1704067200000
      },
      {
        "id": "mat_002",
        "title": "ROI Calculator Template",
        "type": "template",
        "description": "Excel template for AI project ROI calculation",
        "downloadUrl": "https://cdn.academy.ai/kits/enr_abc123/roi-calculator.xlsx",
        "fileSize": 512000,
        "updatedAt": 1704067200000
      },
      {
        "id": "mat_003",
        "title": "Case Study: Retail AI Transformation",
        "type": "video",
        "description": "20-minute case study walkthrough",
        "downloadUrl": "https://cdn.academy.ai/kits/enr_abc123/case-study-retail.mp4",
        "duration": "20:35",
        "updatedAt": 1704067200000
      },
      {
        "id": "mat_004",
        "title": "AI Vendor Evaluation Checklist",
        "type": "interactive",
        "description": "Interactive scoring tool for vendor assessment",
        "downloadUrl": "https://academy.ai/tools/vendor-eval?kit=enr_abc123",
        "updatedAt": 1704067200000
      }
    ],
    "customResources": {
      "organizationName": "Acme Corp",
      "customTemplates": [
        {
          "id": "mat_custom_001",
          "title": "Acme Corp AI Governance Framework",
          "type": "pdf",
          "description": "Organization-specific governance template",
          "downloadUrl": "https://cdn.academy.ai/kits/enr_abc123/acme-governance.pdf",
          "fileSize": 1024000,
          "updatedAt": 1704067200000
        }
      ]
    }
  }
}
```

---

#### 6.3.2.6 `get_certificate`

Retrieves certificate details and download URL for a completed enrollment.

```typescript
interface GetCertificateInput {
  enrollmentId: string;
}

interface Certificate {
  id: string;
  enrollmentId: string;
  learnerName: string;
  courseTitle: string;
  cohortName: string;
  completedAt: number;
  issuedAt: number;
  certificateUrl: string; // PDF download URL
  verificationUrl: string; // Public verification page
  verificationCode: string; // Unique verification code
  credentialId: string; // Blockchain credential ID (if enabled)
  skills: string[]; // Skills earned
  instructorSignature: string; // Instructor name
  organizationName?: string; // For B2B enrollments
}

interface GetCertificateOutput {
  certificate: Certificate;
}
```

**Example Tool Call:**
```json
{
  "name": "get_certificate",
  "arguments": {
    "enrollmentId": "enr_def456"
  }
}
```

**Example Response:**
```json
{
  "certificate": {
    "id": "cert_xyz123",
    "enrollmentId": "enr_def456",
    "learnerName": "Jane Smith",
    "courseTitle": "Advanced Prompt Engineering",
    "cohortName": "Prompt Engineering - December 2024",
    "completedAt": 1703980800000,
    "issuedAt": 1703980800000,
    "certificateUrl": "https://cdn.academy.ai/certificates/cert_xyz123.pdf",
    "verificationUrl": "https://academy.ai/verify/cert_xyz123",
    "verificationCode": "AEA-2024-XYZ123",
    "credentialId": "0x1a2b3c4d5e6f7g8h9i0j",
    "skills": [
      "Prompt Engineering",
      "LLM Architecture Understanding",
      "AI Safety & Alignment",
      "Production Prompt Optimization"
    ],
    "instructorSignature": "Marcus Johnson, Lead AI Engineer",
    "organizationName": "Acme Corp"
  }
}
```

**Error Response (Certificate Not Available):**
```json
{
  "error": {
    "code": "CERTIFICATE_NOT_AVAILABLE",
    "message": "Certificate is only available for completed enrollments",
    "details": {
      "enrollmentStatus": "active",
      "progressPercentage": 65,
      "requiredPercentage": 100
    }
  }
}
```

---

### Admin-Only Tools

These tools require administrative privileges and are used for platform management and B2B operations.

#### 6.3.2.7 `create_enrollment`

Creates a manual enrollment for a learner, typically used for B2B bulk enrollments or complimentary access.

```typescript
interface CreateEnrollmentInput {
  userId: string; // Target learner's user ID
  cohortId: string; // Cohort to enroll in
  organizationId?: string; // Required for B2B enrollments
  enrollmentType: "standard" | "complimentary" | "corporate" | "trial";
  paymentStatus?: "pending" | "paid" | "waived";
  notes?: string; // Admin notes for audit trail
  sendWelcomeEmail?: boolean; // Default: true
}

interface CreateEnrollmentOutput {
  enrollmentId: string;
  userId: string;
  cohortId: string;
  status: "pending" | "active";
  enrolledAt: number;
  welcomeEmailSent: boolean;
}
```

**Example Tool Call:**
```json
{
  "name": "create_enrollment",
  "arguments": {
    "userId": "usr_john_doe_123",
    "cohortId": "coh_xyz789",
    "organizationId": "org_acme_corp",
    "enrollmentType": "corporate",
    "paymentStatus": "paid",
    "notes": "Part of Acme Corp Q1 2025 training initiative",
    "sendWelcomeEmail": true
  }
}
```

**Example Response:**
```json
{
  "enrollmentId": "enr_new_123",
  "userId": "usr_john_doe_123",
  "cohortId": "coh_xyz789",
  "status": "active",
  "enrolledAt": 1704240000000,
  "welcomeEmailSent": true
}
```

**Error Response (Cohort Full):**
```json
{
  "error": {
    "code": "COHORT_FULL",
    "message": "Cannot enroll: cohort is at full capacity",
    "details": {
      "cohortId": "coh_xyz789",
      "totalSeats": 25,
      "enrolledCount": 25,
      "availableSeats": 0
    }
  }
}
```

---

#### 6.3.2.8 `get_cohort_roster`

Retrieves the complete roster for a cohort, including learner details and enrollment status.

```typescript
interface GetCohortRosterInput {
  cohortId: string;
  includeWithdrawn?: boolean; // Default: false
}

interface RosterEntry {
  enrollmentId: string;
  userId: string;
  learnerName: string;
  learnerEmail: string;
  organizationName?: string; // For B2B enrollments
  enrollmentType: "standard" | "complimentary" | "corporate" | "trial";
  status: "pending" | "active" | "completed" | "withdrawn";
  enrolledAt: number;
  completedAt?: number;
  progressPercentage: number;
  lastActivityAt: number;
  certificateIssued: boolean;
}

interface GetCohortRosterOutput {
  cohortId: string;
  cohortName: string;
  courseTitle: string;
  startDate: number;
  endDate: number;
  totalSeats: number;
  enrolledCount: number;
  activeCount: number;
  completedCount: number;
  roster: RosterEntry[];
}
```

**Example Tool Call:**
```json
{
  "name": "get_cohort_roster",
  "arguments": {
    "cohortId": "coh_xyz789",
    "includeWithdrawn": false
  }
}
```

**Example Response:**
```json
{
  "cohortId": "coh_xyz789",
  "cohortName": "AI Fundamentals - January 2025",
  "courseTitle": "AI Fundamentals for Business Leaders",
  "startDate": 1704153600000,
  "endDate": 1704758400000,
  "totalSeats": 25,
  "enrolledCount": 17,
  "activeCount": 15,
  "completedCount": 2,
  "roster": [
    {
      "enrollmentId": "enr_abc123",
      "userId": "usr_jane_smith",
      "learnerName": "Jane Smith",
      "learnerEmail": "jane.smith@example.com",
      "organizationName": "Acme Corp",
      "enrollmentType": "corporate",
      "status": "active",
      "enrolledAt": 1704067200000,
      "progressPercentage": 65,
      "lastActivityAt": 1704326400000,
      "certificateIssued": false
    },
    {
      "enrollmentId": "enr_def456",
      "userId": "usr_john_doe",
      "learnerName": "John Doe",
      "learnerEmail": "john.doe@example.com",
      "enrollmentType": "standard",
      "status": "completed",
      "enrolledAt": 1704067200000,
      "completedAt": 1704672000000,
      "progressPercentage": 100,
      "lastActivityAt": 1704672000000,
      "certificateIssued": true
    }
  ]
}
```

---

#### 6.3.2.9 `update_cohort_status`

Updates the status of a cohort (e.g., from "scheduled" to "in_progress").

```typescript
interface UpdateCohortStatusInput {
  cohortId: string;
  status: "scheduled" | "open" | "in_progress" | "completed" | "cancelled";
  reason?: string; // Required for "cancelled" status
  notifyEnrollees?: boolean; // Send notification email to all enrollees
}

interface UpdateCohortStatusOutput {
  cohortId: string;
  previousStatus: string;
  newStatus: string;
  updatedAt: number;
  notificationsSent: number; // Number of enrollees notified
}
```

**Example Tool Call:**
```json
{
  "name": "update_cohort_status",
  "arguments": {
    "cohortId": "coh_xyz789",
    "status": "in_progress",
    "notifyEnrollees": true
  }
}
```

**Example Response:**
```json
{
  "cohortId": "coh_xyz789",
  "previousStatus": "open",
  "newStatus": "in_progress",
  "updatedAt": 1704153600000,
  "notificationsSent": 17
}
```

---

#### 6.3.2.10 `send_cohort_notification`

Sends a custom notification to all enrollees in a cohort.

```typescript
interface SendCohortNotificationInput {
  cohortId: string;
  subject: string;
  message: string; // Supports markdown
  priority: "low" | "normal" | "high" | "urgent";
  includeInstructorContact?: boolean; // Add instructor email to message
  targetStatuses?: ("pending" | "active" | "completed" | "withdrawn")[]; // Default: ["pending", "active"]
}

interface SendCohortNotificationOutput {
  cohortId: string;
  notificationId: string;
  recipientCount: number;
  sentAt: number;
  deliveryStatus: {
    sent: number;
    failed: number;
    pending: number;
  };
}
```

**Example Tool Call:**
```json
{
  "name": "send_cohort_notification",
  "arguments": {
    "cohortId": "coh_xyz789",
    "subject": "Week 2 Materials Now Available",
    "message": "# Week 2: Strategic AI Applications\n\nHello learners!\n\nWeek 2 materials are now available in your dashboard. This week covers:\n\n- Use case identification\n- ROI evaluation frameworks\n- Build vs. buy decisions\n\nPlease review the pre-reading materials before our Monday session.\n\nBest regards,\nDr. Sarah Chen",
    "priority": "normal",
    "includeInstructorContact": true,
    "targetStatuses": ["active"]
  }
}
```

**Example Response:**
```json
{
  "cohortId": "coh_xyz789",
  "notificationId": "notif_abc123",
  "recipientCount": 15,
  "sentAt": 1704412800000,
  "deliveryStatus": {
    "sent": 15,
    "failed": 0,
    "pending": 0
  }
}
```

---

## 6.3.3 Resources

MCP resources provide read-only access to platform data in a structured format. Resources are identified by URIs following the `academy://` scheme.

### 6.3.3.1 `academy://courses`

Lists all available courses with metadata.

```typescript
interface CoursesResource {
  uri: "academy://courses";
  mimeType: "application/json";
  data: {
    courses: {
      id: string;
      title: string;
      slug: string;
      description: string;
      level: "beginner" | "intermediate" | "advanced";
      duration: string;
      pricing: {
        individual: number;
        corporate: number;
        currency: "USD";
      };
      upcomingCohortCount: number;
      totalEnrollments: number;
      averageRating?: number;
    }[];
    totalCount: number;
    lastUpdated: number;
  };
}
```

**Example Resource Read:**
```json
{
  "uri": "academy://courses",
  "mimeType": "application/json",
  "data": {
    "courses": [
      {
        "id": "crs_ai_fund_001",
        "title": "AI Fundamentals for Business Leaders",
        "slug": "ai-fundamentals",
        "description": "2-day intensive workshop for executives",
        "level": "beginner",
        "duration": "2 days (16 hours)",
        "pricing": {
          "individual": 2500,
          "corporate": 2000,
          "currency": "USD"
        },
        "upcomingCohortCount": 4,
        "totalEnrollments": 342,
        "averageRating": 4.8
      }
    ],
    "totalCount": 1,
    "lastUpdated": 1704412800000
  }
}
```

---

### 6.3.3.2 `academy://cohorts`

Lists all upcoming cohorts across all courses.

```typescript
interface CohortsResource {
  uri: "academy://cohorts";
  mimeType: "application/json";
  data: {
    cohorts: {
      cohortId: string;
      cohortName: string;
      courseTitle: string;
      startDate: number;
      endDate: number;
      modality: "online" | "in-person" | "hybrid";
      location?: string;
      availableSeats: number;
      totalSeats: number;
      status: "scheduled" | "open" | "waitlist" | "full";
    }[];
    totalCount: number;
    lastUpdated: number;
  };
}
```

---

### 6.3.3.3 `academy://enrollments/{userId}`

Retrieves all enrollments for a specific user.

```typescript
interface EnrollmentsResource {
  uri: "academy://enrollments/{userId}";
  mimeType: "application/json";
  data: {
    userId: string;
    enrollments: Enrollment[]; // Same schema as get_learner_enrollments
    totalCount: number;
    lastUpdated: number;
  };
}
```

**Example Resource Read:**
```json
{
  "uri": "academy://enrollments/usr_jane_smith",
  "mimeType": "application/json",
  "data": {
    "userId": "usr_jane_smith",
    "enrollments": [
      {
        "id": "enr_abc123",
        "cohortId": "coh_xyz789",
        "cohortName": "AI Fundamentals - January 2025",
        "courseTitle": "AI Fundamentals for Business Leaders",
        "courseSlug": "ai-fundamentals",
        "status": "active",
        "enrolledAt": 1704067200000,
        "progressPercentage": 65,
        "startDate": 1704153600000,
        "endDate": 1704758400000,
        "instructorName": "Dr. Sarah Chen",
        "modality": "online"
      }
    ],
    "totalCount": 1,
    "lastUpdated": 1704412800000
  }
}
```

---

### 6.3.3.4 `academy://certificates/{enrollmentId}`

Retrieves certificate details for a specific enrollment.

```typescript
interface CertificateResource {
  uri: "academy://certificates/{enrollmentId}";
  mimeType: "application/json";
  data: Certificate; // Same schema as get_certificate
}
```

---

### 6.3.3.5 `academy://organizations/{organizationId}`

Retrieves organization details and aggregate enrollment statistics (admin-only).

```typescript
interface OrganizationResource {
  uri: "academy://organizations/{organizationId}";
  mimeType: "application/json";
  data: {
    organizationId: string;
    name: string;
    contactEmail: string;
    contractType: "champion_network" | "retainer" | "project_based";
    activeSince: number;
    totalEnrollments: number;
    activeEnrollments: number;
    completedEnrollments: number;
    totalSpent: number;
    currency: "USD";
    allocatedSeats: number;
    usedSeats: number;
    upcomingCohorts: {
      cohortId: string;
      cohortName: string;
      enrolledCount: number;
    }[];
    lastUpdated: number;
  };
}
```

---

## 6.3.4 Authentication

The MCP server uses API key authentication with role-based scopes.

### 6.3.4.1 API Key Format

API keys follow the format: `aea_<scope>_<random_32_chars>`

Examples:
- Learner key: `aea_learner_7a8b9c0d1e2f3g4h5i6j7k8l9m0n1o2p`
- Admin key: `aea_admin_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p`

### 6.3.4.2 Scopes

| Scope | Access Level | Available Tools |
|-------|--------------|-----------------|
| `learner` | Authenticated learner | All learner-facing tools (6.3.2.1 - 6.3.2.6) |
| `instructor` | Course instructor | Learner tools + cohort roster, send notifications |
| `admin` | Platform administrator | All tools including admin-only tools |

### 6.3.4.3 Authentication Header

Include the API key in the `Authorization` header:

```http
Authorization: Bearer aea_learner_7a8b9c0d1e2f3g4h5i6j7k8l9m0n1o2p
```

### 6.3.4.4 Key Generation

API keys are generated via the admin dashboard:

1. Navigate to **Settings → API Keys**
2. Click **Generate New Key**
3. Select scope: learner, instructor, or admin
4. Optional: Set expiration date
5. Optional: Restrict to specific IP addresses
6. Click **Create Key**
7. Copy the key immediately (it won't be shown again)

### 6.3.4.5 Key Rotation

For security, API keys should be rotated regularly:
- Learner keys: Every 12 months
- Instructor keys: Every 6 months
- Admin keys: Every 3 months

Keys can be revoked immediately via the admin dashboard.

### 6.3.4.6 Error Responses

**Missing API Key:**
```json
{
  "error": {
    "code": "MISSING_API_KEY",
    "message": "API key is required. Include 'Authorization: Bearer <key>' header."
  }
}
```

**Invalid API Key:**
```json
{
  "error": {
    "code": "INVALID_API_KEY",
    "message": "The provided API key is invalid or has been revoked."
  }
}
```

**Insufficient Permissions:**
```json
{
  "error": {
    "code": "INSUFFICIENT_PERMISSIONS",
    "message": "This operation requires 'admin' scope. Your key has 'learner' scope.",
    "details": {
      "requiredScope": "admin",
      "currentScope": "learner"
    }
  }
}
```

---

## 6.3.5 Implementation Notes

### 6.3.5.1 Technology Stack

The MCP server is built on **Convex HTTP actions**, providing:
- Real-time database queries via Convex queries
- Secure mutations via Convex mutations
- Built-in authentication and authorization
- Automatic request/response validation
- TypeScript type safety

### 6.3.5.2 Rate Limiting

To prevent abuse and ensure fair resource allocation:

- **Rate Limit**: 60 requests/minute per API key
- **Burst Allowance**: Up to 10 requests in a 1-second burst
- **Quota Reset**: Rolling 60-second window

**Rate Limit Response:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 42 seconds.",
    "details": {
      "limit": 60,
      "window": "60s",
      "retryAfter": 42
    }
  }
}
```

Headers included in rate-limited responses:
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1704412842
Retry-After: 42
```

### 6.3.5.3 Streaming Support

Long-running operations support **Server-Sent Events (SSE)** for real-time progress updates.

**Supported Operations:**
- Bulk enrollment creation (`create_enrollment` with `stream: true`)
- Certificate generation for large cohorts
- Cohort roster exports

**Example Streaming Request:**
```http
POST /mcp/tools/create_enrollment
Authorization: Bearer aea_admin_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
Accept: text/event-stream

{
  "enrollments": [
    {"userId": "usr_1", "cohortId": "coh_xyz789"},
    {"userId": "usr_2", "cohortId": "coh_xyz789"}
  ],
  "stream": true
}
```

**Example SSE Response:**
```
event: progress
data: {"completed": 1, "total": 2, "currentUser": "usr_1", "status": "success"}

event: progress
data: {"completed": 2, "total": 2, "currentUser": "usr_2", "status": "success"}

event: complete
data: {"totalEnrolled": 2, "totalFailed": 0, "duration": 3421}
```

### 6.3.5.4 Error Handling

All errors follow a consistent format:

```typescript
interface MCPError {
  error: {
    code: string; // Machine-readable error code
    message: string; // Human-readable error message
    details?: Record<string, any>; // Additional context
    timestamp: number; // Unix timestamp
    requestId: string; // Unique request identifier for support
  };
}
```

**Common Error Codes:**
- `MISSING_API_KEY` - No API key provided
- `INVALID_API_KEY` - Invalid or revoked API key
- `INSUFFICIENT_PERMISSIONS` - Scope mismatch
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `RESOURCE_NOT_FOUND` - Requested resource doesn't exist
- `VALIDATION_ERROR` - Input validation failed
- `COHORT_FULL` - No available seats
- `ENROLLMENT_EXISTS` - User already enrolled
- `CERTIFICATE_NOT_AVAILABLE` - Course not completed
- `INTERNAL_ERROR` - Server-side error

### 6.3.5.5 Logging and Audit Trail

All MCP operations are logged with:
- Timestamp
- API key ID (not the full key)
- User ID (if authenticated)
- Tool called
- Input parameters (sanitized, no PII in logs)
- Response status
- Execution duration
- IP address

Logs are retained for 90 days and available via the admin dashboard.

### 6.3.5.6 Webhook Integration

Admins can configure webhooks to receive notifications for platform events:

**Supported Events:**
- `enrollment.created` - New enrollment
- `enrollment.completed` - Learner completed course
- `certificate.issued` - Certificate generated
- `cohort.status_changed` - Cohort status updated
- `payment.received` - Payment processed

**Webhook Payload Example:**
```json
{
  "event": "enrollment.completed",
  "timestamp": 1704672000000,
  "data": {
    "enrollmentId": "enr_def456",
    "userId": "usr_john_doe",
    "cohortId": "coh_xyz789",
    "courseTitle": "Advanced Prompt Engineering",
    "completedAt": 1704672000000,
    "certificateUrl": "https://cdn.academy.ai/certificates/cert_xyz123.pdf"
  }
}
```

### 6.3.5.7 Versioning

The MCP server uses semantic versioning in the URL path:

- Current: `/mcp/v1/tools/<tool_name>`
- Future: `/mcp/v2/tools/<tool_name>`

Breaking changes will be introduced in new major versions, with a **6-month deprecation period** for old versions.

### 6.3.5.8 Testing

A **sandbox environment** is available for testing:
- Base URL: `https://sandbox-api.academy.ai/mcp/v1/`
- Test API keys available in admin dashboard
- Sandbox data is reset daily at 00:00 UTC
- No real enrollments or payments are processed

### 6.3.5.9 Performance Characteristics

Typical response times:
- Learner tools: 50-150ms (p50), 200-400ms (p95)
- Admin tools (roster, bulk operations): 200-500ms (p50), 1-2s (p95)
- Streaming operations: First event within 500ms, subsequent events every 100-300ms

Database queries are optimized with:
- Convex indexes on frequently queried fields (userId, cohortId, courseId)
- Pagination for large result sets
- Denormalized data for fast reads
- Caching for static resources (course catalogs, instructor bios)

---

## 6.3.6 Example Integration: Claude AI Agent

Here's an example of how a Claude AI agent would interact with the MCP server:

### User Prompt:
"I want to learn about AI for my business. What courses are available?"

### Agent Tool Calls:

**Step 1: Discover Courses**
```typescript
// Tool call: get_course_details
{
  "name": "get_course_details",
  "arguments": {
    "courseSlug": "ai-fundamentals"
  }
}

// Response: Full course details (see 6.3.2.2 example)
```

**Step 2: Check Availability**
```typescript
// Tool call: get_upcoming_cohorts
{
  "name": "get_upcoming_cohorts",
  "arguments": {
    "courseId": "crs_ai_fund_001",
    "startDateAfter": 1704067200000,
    "limit": 5
  }
}

// Response: List of upcoming cohorts (see 6.3.2.3 example)
```

**Step 3: Check Enrollment Status**
```typescript
// Tool call: check_enrollment_status
{
  "name": "check_enrollment_status",
  "arguments": {
    "cohortId": "coh_xyz789"
  }
}

// Response: Enrollment status (see 6.3.2.4 example)
```

### Agent Response:
"Great question! I found the **AI Fundamentals for Business Leaders** course, which sounds perfect for you. It's a 2-day intensive workshop ($2,500) designed for executives and managers with no technical background required.

**Upcoming cohorts:**
- **January 2025** (Online) - Starts Jan 2, 2025 - 8 seats left - Instructor: Dr. Sarah Chen
- **February 2025** (In-person, NYC) - Starts Feb 1, 2025 - 15 seats left - Instructor: Marcus Johnson

You're not currently enrolled. Would you like me to help you register for one of these cohorts?"

---

## 6.3.7 Security Best Practices

### For Learners:
1. **Never share API keys** - Keys are personal and should not be shared
2. **Regenerate compromised keys immediately** via the dashboard
3. **Use HTTPS only** - Never send API keys over unencrypted connections
4. **Monitor usage** - Check API usage logs for suspicious activity

### For Admins:
1. **Rotate admin keys every 3 months**
2. **Use IP restrictions** for admin keys when possible
3. **Enable webhook signatures** to verify webhook authenticity
4. **Monitor rate limit patterns** - Unusual spikes may indicate abuse
5. **Review audit logs regularly** - Check for unauthorized access attempts
6. **Separate keys for different integrations** - Don't reuse keys across systems

### For Developers:
1. **Store keys in environment variables**, never in code
2. **Use scoped keys** - Request minimum necessary permissions
3. **Implement exponential backoff** for rate limit handling
4. **Validate webhook signatures** before processing events
5. **Handle errors gracefully** - Don't expose error details to end users
6. **Test in sandbox** before production deployment

---

## 6.3.8 Changelog

### v1.0.0 (2025-01-01)
- Initial release
- Learner-facing tools (6 tools)
- Admin tools (4 tools)
- Resources (5 URIs)
- API key authentication
- Rate limiting (60 req/min)
- Streaming support for bulk operations

### Future Roadmap:
- **v1.1.0**: Instructor-specific tools (cohort analytics, grade management)
- **v1.2.0**: Webhook integration for real-time event notifications
- **v1.3.0**: GraphQL endpoint for advanced queries
- **v2.0.0**: Breaking changes for improved performance and new data models

---

This MCP server specification provides a comprehensive, production-ready interface for AI agents to interact with the AI Enablement Academy platform, supporting both individual learner self-service and enterprise B2B automation.
