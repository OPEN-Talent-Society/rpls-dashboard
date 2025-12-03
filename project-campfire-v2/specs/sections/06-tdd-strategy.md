# 6. Test-Driven Development Strategy

## 6.1 Testing Philosophy

### London School TDD Principles

The AI Enablement Academy v2 platform adopts **London School TDD** (mockist approach) as its core testing philosophy:

**Core Tenets:**
- **Behavior verification over state verification** - Test what services *do*, not what they *are*
- **Mock external dependencies at service boundaries** - Isolate units completely
- **Test behavior, not implementation** - Focus on contracts and interactions
- **Outside-in development** - Start with acceptance tests, drive down to unit tests

**Why London School?**
1. **Service-oriented architecture** - Our platform is built on discrete service boundaries (payment, email, analytics, etc.)
2. **External integrations** - Heavy reliance on third-party APIs (Stripe, Brevo, PostHog, Cal.com)
3. **Faster feedback loops** - Mocked dependencies run in milliseconds, not seconds
4. **Better design** - Forces explicit interface definitions and dependency injection
5. **Isolation** - Tests never fail due to external service issues

**Development Workflow:**
```
1. Write failing acceptance test (E2E)
2. Write failing integration test (API/Convex)
3. Write failing unit test (Service)
4. Implement minimum code to pass
5. Refactor with confidence
6. Repeat for next behavior
```

---

## 6.2 Mockable Service Interfaces

All external dependencies are abstracted behind mockable TypeScript interfaces. These interfaces define the **contract** each service must fulfill, enabling complete test isolation.

### Service Interface Definitions

```typescript
// services/interfaces.ts

/**
 * Enrollment Management
 * Handles course enrollment lifecycle from creation to refunds
 */
interface IEnrollmentService {
  /**
   * Create a new enrollment after successful payment
   * @throws EnrollmentExistsError if user already enrolled in cohort
   * @throws CohortFullError if cohort at capacity
   */
  createEnrollment(data: EnrollmentData): Promise<Enrollment>;

  /**
   * Get all enrollments for a specific user
   * @returns Enrollments sorted by creation date descending
   */
  getByUser(userId: string): Promise<Enrollment[]>;

  /**
   * Check if user has access to specific resource via enrollment
   * @param accessType - 'content' | 'community' | 'office_hours' | 'resources'
   */
  checkAccess(enrollmentId: string, accessType: AccessType): Promise<boolean>;

  /**
   * Process enrollment refund and update access
   * @throws RefundWindowExpiredError if beyond refund period
   */
  processRefund(enrollmentId: string): Promise<void>;
}

/**
 * Payment Processing (Stripe Integration)
 * Handles checkout sessions, webhooks, and refunds
 */
interface IPaymentService {
  /**
   * Create Stripe checkout session for cohort enrollment
   * @returns Checkout session URL for redirect
   */
  createCheckoutSession(data: CheckoutData): Promise<{ url: string }>;

  /**
   * Verify webhook signature from Stripe
   * @returns true if signature valid, false otherwise
   */
  verifyWebhookSignature(payload: string, signature: string): boolean;

  /**
   * Process refund through Stripe
   * @param reason - Displayed to customer in Stripe dashboard
   */
  processRefund(paymentIntentId: string, reason: string): Promise<void>;

  /**
   * Create manual invoice for enterprise/custom pricing
   * @returns Invoice object with payment URL
   */
  createManualInvoice(data: InvoiceData): Promise<Invoice>;
}

/**
 * Email Marketing & Transactional (Brevo Integration)
 * Template-based emails and contact list management
 */
interface IEmailService {
  /**
   * Send templated email via Brevo
   * @param templateId - Brevo template ID
   * @param params - Template variable substitutions
   */
  sendTemplate(templateId: number, to: Recipient[], params: object): Promise<void>;

  /**
   * Add contact to Brevo list (e.g., course-specific lists)
   */
  addToList(email: string, listId: number): Promise<void>;

  /**
   * Update contact attributes (e.g., cohort name, completion status)
   */
  updateContact(email: string, attributes: object): Promise<void>;
}

/**
 * Analytics & Product Telemetry (PostHog Integration)
 * Event tracking and user identification
 */
interface IAnalyticsService {
  /**
   * Track user event (e.g., 'Enrollment Created', 'Module Completed')
   */
  track(event: string, properties: object): void;

  /**
   * Identify user with traits (e.g., role, company, cohort)
   */
  identify(userId: string, traits: object): void;

  /**
   * Track page view with metadata
   */
  page(name: string, properties: object): void;
}

/**
 * User Feedback & Surveys (Formbricks Integration)
 * Trigger surveys and retrieve responses
 */
interface ISurveyService {
  /**
   * Trigger survey for user (e.g., post-workshop NPS)
   * @param surveyId - Formbricks survey ID
   */
  triggerSurvey(surveyId: string, userId: string): void;

  /**
   * Retrieve survey response data
   */
  getSurveyResponse(responseId: string): Promise<SurveyResponse>;
}

/**
 * Calendar & Scheduling (Cal.com Integration)
 * Office hours and 1:1 session booking
 */
interface ISchedulingService {
  /**
   * Get available time slots for event type (e.g., office hours)
   */
  getAvailability(eventTypeId: string): Promise<TimeSlot[]>;

  /**
   * Create booking for user
   * @throws NoAvailabilityError if slot already taken
   */
  createBooking(data: BookingData): Promise<Booking>;

  /**
   * Cancel existing booking and release slot
   */
  cancelBooking(bookingId: string): Promise<void>;
}

/**
 * AI Chat (Claude API Integration)
 * Streaming chat responses for learning assistant
 */
interface IChatService {
  /**
   * Send message and stream response chunks
   * @returns AsyncIterable for streaming responses
   */
  sendMessage(conversationId: string, message: string): AsyncIterable<string>;

  /**
   * Retrieve full conversation history
   */
  getConversation(conversationId: string): Promise<ChatMessage[]>;
}

/**
 * File Storage (Convex Storage)
 * Upload URLs and file retrieval
 */
interface IStorageService {
  /**
   * Generate pre-signed upload URL for client-side upload
   */
  generateUploadUrl(): Promise<string>;

  /**
   * Get public URL for stored file
   */
  getFileUrl(storageId: string): Promise<string>;

  /**
   * Delete file from storage
   */
  deleteFile(storageId: string): Promise<void>;
}

/**
 * Certificate Generation & Verification
 * PDF generation and blockchain verification
 */
interface ICertificateService {
  /**
   * Generate certificate PDF for completed enrollment
   * @throws EnrollmentIncompleteError if requirements not met
   */
  generate(enrollmentId: string): Promise<Certificate>;

  /**
   * Verify certificate authenticity via URL
   */
  verify(verificationUrl: string): Promise<CertificateVerification>;
}

/**
 * Webhook Delivery
 * Send platform events to external systems
 */
interface IWebhookService {
  /**
   * Send webhook to registered URL
   * @param event - Event type (e.g., 'enrollment.created')
   * @throws WebhookDeliveryError if delivery fails after retries
   */
  send(url: string, event: string, payload: object): Promise<void>;

  /**
   * Verify incoming webhook signature
   */
  verify(payload: string, signature: string, secret: string): boolean;
}

/**
 * Resource Library Management (v2.1)
 * Handles resources, glossary terms, prompts, and user interactions
 */
interface IResourceService {
  /**
   * Get resource by ID
   * @returns Resource object or null if not found
   */
  getResourceById(resourceId: Id<"resources">): Promise<Resource | null>;

  /**
   * Browse resources with filtering and pagination
   * @param filters - Type, category, tags, access level filters
   * @param pagination - Page number and page size
   * @returns Paginated resource list with total count
   */
  browseResources(filters: ResourceFilters, pagination: Pagination): Promise<PaginatedResources>;

  /**
   * Check if user has access to a specific resource
   * @param userId - User ID to check access for
   * @param resourceId - Resource ID to check access to
   * @returns true if user has access, false otherwise
   * @throws ResourceNotFoundError if resource doesn't exist
   */
  checkResourceAccess(userId: Id<"users">, resourceId: Id<"resources">): Promise<boolean>;

  /**
   * Search glossary terms by query string
   * @param query - Search query for term name or definition
   * @returns Array of matching glossary terms
   */
  searchGlossary(query: string): Promise<GlossaryTerm[]>;

  /**
   * Get glossary term by ID
   * @returns GlossaryTerm object or null if not found
   */
  getGlossaryTerm(termId: Id<"glossaryTerms">): Promise<GlossaryTerm | null>;

  /**
   * Get related glossary terms
   * @param termId - Glossary term ID to find relations for
   * @returns Array of related glossary terms
   */
  getRelatedTerms(termId: Id<"glossaryTerms">): Promise<GlossaryTerm[]>;

  /**
   * Get prompt by ID
   * @returns Prompt object with template and variables
   */
  getPromptById(promptId: Id<"prompts">): Promise<Prompt | null>;

  /**
   * Track prompt usage by user
   * @param userId - User who used the prompt
   * @param promptId - Prompt that was used
   * @throws PromptNotFoundError if prompt doesn't exist
   */
  usePrompt(userId: Id<"users">, promptId: Id<"prompts">): Promise<void>;

  /**
   * Get prompts by category
   * @param category - Prompt category (writing, analysis, coding, etc.)
   * @returns Array of prompts in the category
   */
  getPromptsByCategory(category: string): Promise<Prompt[]>;

  /**
   * Track resource interaction (view, download, etc.)
   * @param userId - User performing the interaction
   * @param resourceId - Resource being interacted with
   * @param type - Interaction type ('view' | 'download' | 'rate')
   */
  trackInteraction(userId: Id<"users">, resourceId: Id<"resources">, type: InteractionType): Promise<void>;

  /**
   * Bookmark a resource for later
   * @param userId - User creating the bookmark
   * @param resourceId - Resource to bookmark
   * @param notes - Optional user notes about the bookmark
   * @returns ID of created bookmark
   */
  bookmarkResource(userId: Id<"users">, resourceId: Id<"resources">, notes?: string): Promise<Id<"userBookmarks">>;

  /**
   * Get all bookmarks for a user
   * @param userId - User ID to get bookmarks for
   * @returns Array of user bookmarks with resource details
   */
  getUserBookmarks(userId: Id<"users">): Promise<UserBookmark[]>;
}

/**
 * Skills & Competencies Management (v2.1)
 * Handles skill definitions, user progress tracking, and competency-based assessments
 */
interface ISkillService {
  /**
   * Get skill definition by ID
   * @returns Skill object with full metadata (category, level, description)
   */
  getSkillById(skillId: Id<"skills">): Promise<Skill | null>;

  /**
   * Get all skills in a specific category
   * @param category - 'technical' | 'strategic' | 'leadership' | 'domain'
   * @returns Skills sorted by name ascending
   */
  getSkillsByCategory(category: SkillCategory): Promise<Skill[]>;

  /**
   * Search skills by name or description
   * @returns Matching skills with relevance ranking
   */
  searchSkills(query: string): Promise<Skill[]>;

  /**
   * Get user's progress for a specific skill
   * @returns Progress object with level, percent, and evidence count
   */
  getUserSkillProgress(userId: Id<"users">, skillId: Id<"skills">): Promise<UserSkillProgress | null>;

  /**
   * Update user's skill progress based on new evidence
   * @param evidence - Competency evidence record (type, score, assessment)
   * @throws SkillNotFoundError if skill doesn't exist
   */
  updateSkillProgress(userId: Id<"users">, skillId: Id<"skills">, evidence: CompetencyEvidence): Promise<void>;

  /**
   * Advance user to next proficiency level
   * @returns true if advancement successful, false if criteria not met
   * @throws InsufficientEvidenceError if not enough evidence collected
   */
  advanceSkillLevel(userId: Id<"users">, skillId: Id<"skills">): Promise<boolean>;

  /**
   * Get all competencies that make up a skill
   * @returns Competencies with assessment criteria and evidence types
   */
  getCompetenciesForSkill(skillId: Id<"skills">): Promise<Competency[]>;

  /**
   * Record evidence of competency achievement
   * @param evidence - Evidence details (type, score, artifact URL)
   * @throws CompetencyNotFoundError if competency doesn't exist
   */
  recordCompetencyEvidence(userId: Id<"users">, competencyId: Id<"competencies">, evidence: EvidenceInput): Promise<void>;

  /**
   * Award skill badge (micro-credential) to user
   * @returns Skill badge ID with Open Badges 3.0 metadata
   * @throws LevelNotAchievedError if user hasn't reached required level
   */
  awardSkillBadge(userId: Id<"users">, skillId: Id<"skills">, level: ProficiencyLevel): Promise<Id<"skillBadges">>;

  /**
   * Get all skill badges earned by user
   * @returns Badges sorted by earnedAt descending
   */
  getUserBadges(userId: Id<"users">): Promise<SkillBadge[]>;

  /**
   * Suggest next skill for user to develop (AI-powered)
   * @returns Skill suggestions with rationale and learning path recommendations
   */
  suggestNextSkill(userId: Id<"users">): Promise<SkillSuggestion[]>;
}
```

---

## 6.3 Behavior Verification Examples

### Example 1: Enrollment Service - Creating Enrollment

**Behavior Under Test:** When enrollment is created, welcome email is sent and analytics tracked

```typescript
// tests/unit/services/enrollment.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock, mockReset } from 'vitest-mock-extended';
import { EnrollmentService } from '@/services/enrollment';
import type { IPaymentService, IEmailService, IAnalyticsService } from '@/services/interfaces';
import { TEMPLATES } from '@/constants/email';

describe("EnrollmentService", () => {
  let mockPaymentService: MockProxy<IPaymentService>;
  let mockEmailService: MockProxy<IEmailService>;
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: EnrollmentService;

  beforeEach(() => {
    mockPaymentService = mock<IPaymentService>();
    mockEmailService = mock<IEmailService>();
    mockAnalyticsService = mock<IAnalyticsService>();

    service = new EnrollmentService(
      mockPaymentService,
      mockEmailService,
      mockAnalyticsService
    );
  });

  it("should send welcome email with cohort details on enrollment creation", async () => {
    // Arrange
    const enrollmentData = {
      userId: "user_123",
      cohortId: "cohort_456",
      paymentIntentId: "pi_789",
      userEmail: "learner@example.com",
      cohortName: "Advanced Prompting Q1 2025"
    };

    // Act
    await service.createEnrollment(enrollmentData);

    // Assert - verify behavior, not state
    expect(mockEmailService.sendTemplate).toHaveBeenCalledOnce();
    expect(mockEmailService.sendTemplate).toHaveBeenCalledWith(
      TEMPLATES.WELCOME,
      [{ email: "learner@example.com", name: expect.any(String) }],
      expect.objectContaining({
        cohortId: "cohort_456",
        cohortName: "Advanced Prompting Q1 2025",
        enrollmentId: expect.any(String)
      })
    );
  });

  it("should track enrollment creation event in analytics", async () => {
    // Arrange
    const enrollmentData = {
      userId: "user_123",
      cohortId: "cohort_456",
      paymentIntentId: "pi_789"
    };

    // Act
    await service.createEnrollment(enrollmentData);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Enrollment Created",
      expect.objectContaining({
        userId: "user_123",
        cohortId: "cohort_456",
        paymentIntentId: "pi_789"
      })
    );
  });

  it("should add user to course-specific email list", async () => {
    // Arrange
    const enrollmentData = {
      userId: "user_123",
      cohortId: "cohort_456",
      paymentIntentId: "pi_789",
      userEmail: "learner@example.com",
      courseListId: 42 // Brevo list ID
    };

    // Act
    await service.createEnrollment(enrollmentData);

    // Assert
    expect(mockEmailService.addToList).toHaveBeenCalledWith(
      "learner@example.com",
      42
    );
  });
});
```

### Example 2: Payment Service - Webhook Verification

**Behavior Under Test:** Webhook signature validation prevents unauthorized requests

```typescript
// tests/unit/services/payment.test.ts
import { describe, it, expect } from 'vitest';
import { PaymentService } from '@/services/payment';

describe("PaymentService - Webhook Verification", () => {
  const service = new PaymentService(process.env.STRIPE_SECRET_KEY!);

  it("should reject webhook with invalid signature", () => {
    // Arrange
    const payload = JSON.stringify({ type: "payment_intent.succeeded" });
    const invalidSignature = "whsec_invalid";

    // Act
    const result = service.verifyWebhookSignature(payload, invalidSignature);

    // Assert
    expect(result).toBe(false);
  });

  it("should accept webhook with valid signature", () => {
    // Arrange
    const payload = JSON.stringify({ type: "payment_intent.succeeded" });
    const validSignature = generateValidStripeSignature(payload); // Test helper

    // Act
    const result = service.verifyWebhookSignature(payload, validSignature);

    // Assert
    expect(result).toBe(true);
  });
});
```

### Example 3: Chat Service - Streaming Response

**Behavior Under Test:** Chat service streams response chunks asynchronously

```typescript
// tests/unit/services/chat.test.ts
import { describe, it, expect } from 'vitest';
import { mock } from 'vitest-mock-extended';
import { ChatService } from '@/services/chat';

describe("ChatService - Streaming", () => {
  it("should yield response chunks as they arrive", async () => {
    // Arrange
    const service = new ChatService(process.env.ANTHROPIC_API_KEY!);
    const chunks: string[] = [];

    // Act
    for await (const chunk of service.sendMessage("conv_123", "What is TDD?")) {
      chunks.push(chunk);
    }

    // Assert
    expect(chunks.length).toBeGreaterThan(0);
    expect(chunks.join("")).toContain("Test-Driven Development");
  });
});
```

### Example 4: Resource Service - Access Control

**Behavior Under Test:** Access control enforces resource visibility based on user enrollment status

```typescript
// tests/unit/services/resource.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock, mockReset } from 'vitest-mock-extended';
import { ResourceService } from '@/services/resource';
import type { IEnrollmentService, IAnalyticsService } from '@/services/interfaces';

describe("ResourceService - Access Control", () => {
  let mockEnrollmentService: MockProxy<IEnrollmentService>;
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ResourceService;

  beforeEach(() => {
    mockEnrollmentService = mock<IEnrollmentService>();
    mockAnalyticsService = mock<IAnalyticsService>();

    service = new ResourceService(
      mockEnrollmentService,
      mockAnalyticsService
    );
  });

  it("should grant access to public resources without authentication", async () => {
    // Arrange
    const resourceId = "resource_public_123" as Id<"resources">;
    const userId = "user_anonymous" as Id<"users">;

    // Act
    const hasAccess = await service.checkResourceAccess(userId, resourceId);

    // Assert
    expect(hasAccess).toBe(true);
    expect(mockEnrollmentService.checkAccess).not.toHaveBeenCalled();
  });

  it("should deny access to course-specific resources without enrollment", async () => {
    // Arrange
    const resourceId = "resource_course_456" as Id<"resources">;
    const userId = "user_123" as Id<"users">;

    // Mock no enrollment
    mockEnrollmentService.checkAccess.mockResolvedValue(false);

    // Act
    const hasAccess = await service.checkResourceAccess(userId, resourceId);

    // Assert
    expect(hasAccess).toBe(false);
  });

  it("should grant access to enrolled users and track analytics", async () => {
    // Arrange
    const resourceId = "resource_course_456" as Id<"resources">;
    const userId = "user_123" as Id<"users">;

    // Mock enrollment exists
    mockEnrollmentService.checkAccess.mockResolvedValue(true);

    // Act
    const hasAccess = await service.checkResourceAccess(userId, resourceId);

    // Assert
    expect(hasAccess).toBe(true);
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Resource Access Granted",
      expect.objectContaining({
        userId,
        resourceId
      })
    );
  });
});
```

### Example 5: Resource Service - Glossary Search

**Behavior Under Test:** Glossary search returns relevant terms and tracks analytics

```typescript
// tests/unit/services/resource.test.ts (continued)
describe("ResourceService - Glossary", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ResourceService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new ResourceService(mockAnalyticsService);
  });

  it("should search glossary terms by query and return related terms", async () => {
    // Arrange
    const query = "LLM";

    // Act
    const results = await service.searchGlossary(query);

    // Assert
    expect(results.length).toBeGreaterThan(0);
    expect(results[0].term).toBe("Large Language Model");
    expect(results[0].abbreviation).toBe("LLM");
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Glossary Search",
      expect.objectContaining({
        query,
        resultsCount: results.length
      })
    );
  });

  it("should retrieve related terms for a glossary term", async () => {
    // Arrange
    const termId = "term_1" as Id<"glossaryTerms">;

    // Act
    const relatedTerms = await service.getRelatedTerms(termId);

    // Assert
    expect(relatedTerms).toBeInstanceOf(Array);
    expect(relatedTerms.length).toBeGreaterThan(0);
  });
});
```

### Example 6: Resource Service - Prompt Usage Tracking

**Behavior Under Test:** Prompt usage increments usage count and tracks analytics

```typescript
// tests/unit/services/resource.test.ts (continued)
describe("ResourceService - Prompts", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ResourceService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new ResourceService(mockAnalyticsService);
  });

  it("should track prompt usage and increment usage count", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const promptId = "prompt_456" as Id<"prompts">;

    // Act
    await service.usePrompt(userId, promptId);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Prompt Used",
      expect.objectContaining({
        userId,
        promptId
      })
    );
  });

  it("should retrieve prompts by category", async () => {
    // Arrange
    const category = "writing";

    // Act
    const prompts = await service.getPromptsByCategory(category);

    // Assert
    expect(prompts).toBeInstanceOf(Array);
    expect(prompts.every(p => p.category === "writing")).toBe(true);
  });
});
```

### Example 7: Resource Service - Bookmarking

**Behavior Under Test:** Bookmarking creates user bookmark and tracks interaction

```typescript
// tests/unit/services/resource.test.ts (continued)
describe("ResourceService - Bookmarks", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ResourceService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new ResourceService(mockAnalyticsService);
  });

  it("should create bookmark with optional notes", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const resourceId = "resource_456" as Id<"resources">;
    const notes = "Great template for AI strategy planning";

    // Act
    const bookmarkId = await service.bookmarkResource(userId, resourceId, notes);

    // Assert
    expect(bookmarkId).toBeDefined();
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Resource Bookmarked",
      expect.objectContaining({
        userId,
        resourceId,
        hasNotes: true
      })
    );
  });

  it("should retrieve all user bookmarks with resource details", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;

    // Act
    const bookmarks = await service.getUserBookmarks(userId);

    // Assert
    expect(bookmarks).toBeInstanceOf(Array);
  });
});
```

### Example 8: Skill Service - Recording Competency Evidence

**Behavior Under Test:** When competency evidence is recorded, skill progress is updated and badge awarded if threshold reached

```typescript
// tests/unit/services/skill.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock, mockReset } from 'vitest-mock-extended';
import { SkillService } from '@/services/skill';
import type { IAnalyticsService, ICertificateService } from '@/services/interfaces';

describe("SkillService - Competency Evidence", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let mockCertificateService: MockProxy<ICertificateService>;
  let service: SkillService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    mockCertificateService = mock<ICertificateService>();

    service = new SkillService(
      mockAnalyticsService,
      mockCertificateService
    );
  });

  it("should record evidence and update skill progress", async () => {
    // Arrange
    const userId = "user_123";
    const competencyId = "comp_456";
    const evidence: EvidenceInput = {
      type: "project",
      score: 85,
      evidenceUrl: "https://example.com/project",
      notes: "Built complete authentication system"
    };

    // Act
    await service.recordCompetencyEvidence(userId, competencyId, evidence);

    // Assert - verify evidence stored
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Competency Evidence Recorded",
      expect.objectContaining({
        userId,
        competencyId,
        evidenceType: "project",
        score: 85
      })
    );
  });

  it("should advance skill level when evidence threshold reached", async () => {
    // Arrange
    const userId = "user_123";
    const skillId = "skill_789";
    const evidence: CompetencyEvidence = {
      type: "instructor_assessment",
      score: 90,
      passed: true,
      evidenceUrl: "https://example.com/assessment",
      assessedBy: "instructor_001"
    };

    // Stub getUserSkillProgress to return nearly complete foundational level
    const mockProgress: UserSkillProgress = {
      userId,
      skillId,
      currentLevel: "foundational",
      progressPercent: 95,
      evidenceCount: 4,
      verifiedByInstructor: false
    };

    // Act
    await service.updateSkillProgress(userId, skillId, evidence);

    // Assert - verify level advancement
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Skill Level Advanced",
      expect.objectContaining({
        userId,
        skillId,
        newLevel: "practitioner",
        previousLevel: "foundational"
      })
    );
  });

  it("should award skill badge when proficiency level achieved", async () => {
    // Arrange
    const userId = "user_123";
    const skillId = "skill_789";
    const level: ProficiencyLevel = "practitioner";

    // Act
    const badgeId = await service.awardSkillBadge(userId, skillId, level);

    // Assert - verify badge awarded
    expect(badgeId).toBeDefined();
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Skill Badge Awarded",
      expect.objectContaining({
        userId,
        skillId,
        level,
        badgeId: expect.any(String)
      })
    );
  });

  it("should throw InsufficientEvidenceError when advancing without meeting criteria", async () => {
    // Arrange
    const userId = "user_123";
    const skillId = "skill_789";

    // Stub getUserSkillProgress to return insufficient evidence
    const mockProgress: UserSkillProgress = {
      userId,
      skillId,
      currentLevel: "foundational",
      progressPercent: 40,
      evidenceCount: 1,
      verifiedByInstructor: false
    };

    // Act & Assert
    await expect(
      service.advanceSkillLevel(userId, skillId)
    ).rejects.toThrow("InsufficientEvidenceError");
  });
});
```

### Example 5: Skill Service - AI-Powered Skill Suggestions

**Behavior Under Test:** AI recommends next skills based on user's current progress and career goals

```typescript
// tests/unit/services/skill.test.ts (continued)
describe("SkillService - AI Recommendations", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: SkillService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new SkillService(mockAnalyticsService);
  });

  it("should suggest complementary skills based on completed skills", async () => {
    // Arrange
    const userId = "user_123";

    // Stub user has completed "Prompt Engineering" at practitioner level
    const mockCompletedSkills = [
      { skillId: "skill_001", name: "Prompt Engineering", level: "practitioner" }
    ];

    // Act
    const suggestions = await service.suggestNextSkill(userId);

    // Assert - verify suggestions include related skills
    expect(suggestions).toHaveLength(3);
    expect(suggestions[0]).toMatchObject({
      skillId: expect.any(String),
      name: "Advanced RAG Techniques",
      rationale: expect.stringContaining("complements your Prompt Engineering skills"),
      estimatedTimeToComplete: expect.any(Number),
      pathRecommendations: expect.arrayContaining([
        expect.objectContaining({
          pathId: expect.any(String),
          pathName: expect.any(String)
        })
      ])
    });
  });

  it("should prioritize skills aligned with user career goals", async () => {
    // Arrange
    const userId = "user_123";

    // Stub user profile with career goal
    const mockUserProfile = {
      userId,
      careerGoal: "AI Product Manager",
      currentRole: "Business Analyst"
    };

    // Act
    const suggestions = await service.suggestNextSkill(userId);

    // Assert - verify suggestions prioritize strategic/leadership skills
    expect(suggestions[0].category).toBe("strategic");
    expect(suggestions[1].category).toBeOneOf(["strategic", "leadership"]);

    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Skill Suggestions Generated",
      expect.objectContaining({
        userId,
        suggestionsCount: 3,
        alignedWithCareerGoal: true
      })
    );
  });

  it("should handle users with no completed skills (beginner recommendations)", async () => {
    // Arrange
    const userId = "user_new";

    // Stub user has no completed skills
    const mockCompletedSkills = [];

    // Act
    const suggestions = await service.suggestNextSkill(userId);

    // Assert - verify foundational skills recommended
    expect(suggestions).toHaveLength(3);
    expect(suggestions.every(s => s.level === "foundational")).toBe(true);
    expect(suggestions[0].name).toBe("Prompt Engineering Basics");
  });
});
```

### Example 6: Skill Service - Integration Test (Convex)

**Behavior Under Test:** Skill progress updates cascade correctly through database relationships

```typescript
// tests/integration/convex/skills.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { convexTest } from 'convex-test';
import { api } from '@/convex/_generated/api';

describe("Skills Integration - Progress Tracking", () => {
  let t: ConvexTestingHelper;

  beforeEach(async () => {
    t = convexTest();
    await t.run(async (ctx) => {
      // Seed test data
      await seedSkillsData(ctx);
    });
  });

  it("should update user progress when competency evidence recorded", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const userId = await createTestUser(ctx);
      const skillId = await createTestSkill(ctx, {
        name: "API Integration",
        category: "technical",
        level: "practitioner"
      });
      const competencyId = await createTestCompetency(ctx, {
        skillId,
        name: "RESTful API Design"
      });

      // Act - record evidence
      await ctx.mutation(api.skills.recordCompetencyEvidence, {
        userId,
        competencyId,
        evidence: {
          type: "project",
          score: 88,
          passed: true,
          evidenceUrl: "https://example.com/api-project"
        }
      });

      // Assert - verify progress updated
      const progress = await ctx.query(api.skills.getUserSkillProgress, {
        userId,
        skillId
      });

      expect(progress).toBeDefined();
      expect(progress.evidenceCount).toBe(1);
      expect(progress.progressPercent).toBeGreaterThan(0);
    });
  });

  it("should award badge when all competencies for level completed", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const userId = await createTestUser(ctx);
      const skillId = await createTestSkill(ctx, {
        name: "Data Analysis",
        category: "technical",
        level: "foundational"
      });

      // Create 3 competencies (all required for foundational level)
      const competencyIds = await Promise.all([
        createTestCompetency(ctx, { skillId, name: "Data Cleaning" }),
        createTestCompetency(ctx, { skillId, name: "Basic Statistics" }),
        createTestCompetency(ctx, { skillId, name: "Visualization" })
      ]);

      // Record passing evidence for all competencies
      for (const competencyId of competencyIds) {
        await ctx.mutation(api.skills.recordCompetencyEvidence, {
          userId,
          competencyId,
          evidence: { type: "quiz", score: 85, passed: true }
        });
      }

      // Act - advance skill level (should trigger badge award)
      const advanced = await ctx.mutation(api.skills.advanceSkillLevel, {
        userId,
        skillId
      });

      // Assert - verify badge awarded
      expect(advanced).toBe(true);

      const badges = await ctx.query(api.skills.getUserBadges, { userId });
      expect(badges).toHaveLength(1);
      expect(badges[0]).toMatchObject({
        skillId,
        level: "foundational",
        earnedAt: expect.any(Number)
      });

      // Verify Open Badges 3.0 metadata
      expect(badges[0].badgeData).toMatchObject({
        "@context": "https://www.w3.org/2018/credentials/v1",
        type: expect.arrayContaining(["VerifiableCredential", "OpenBadgeCredential"]),
        issuer: expect.objectContaining({
          id: expect.any(String),
          name: "AI Enablement Academy"
        })
      });
    });
  });
});
```

### Example 7: Resource Service - Integration Test (Convex)

**Behavior Under Test:** Resource library operations work correctly with Convex database

```typescript
// tests/integration/convex/resources.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { convexTest } from 'convex-test';
import { api } from '@/convex/_generated/api';
import schema from '@/convex/schema';

describe("Resource Library Integration", () => {
  let t: ConvexTestingHelper;

  beforeEach(() => {
    t = convexTest(schema);
  });

  it("should create resource with proper access control", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const resourceData = {
        title: "AI Strategy Canvas",
        slug: "ai-strategy-canvas",
        description: "Comprehensive AI adoption planning template",
        type: "template" as const,
        category: "Strategy",
        tags: ["planning", "framework", "beginner"],
        accessLevel: "enrolled" as const,
        courseIds: ["course_123" as Id<"courses">],
        isActive: true,
        isFeatured: true,
        downloadCount: 0,
        viewCount: 0,
        ratingCount: 0,
        sortOrder: 1
      };

      // Act
      const resourceId = await ctx.mutation(api.resources.create, resourceData);

      // Assert
      const resource = await ctx.query(api.resources.get, { resourceId });
      expect(resource).toBeDefined();
      expect(resource.title).toBe("AI Strategy Canvas");
      expect(resource.accessLevel).toBe("enrolled");
      expect(resource.downloadCount).toBe(0);
      expect(resource.viewCount).toBe(0);
    });
  });

  it("should enforce unique slugs across resources", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const resourceData = {
        title: "Template 1",
        slug: "duplicate-slug",
        type: "template" as const,
        description: "Test template",
        category: "Test",
        tags: [],
        accessLevel: "public" as const,
        isActive: true,
        isFeatured: false,
        downloadCount: 0,
        viewCount: 0,
        ratingCount: 0,
        sortOrder: 1
      };

      // Act & Assert
      await ctx.mutation(api.resources.create, resourceData);
      await expect(
        ctx.mutation(api.resources.create, { ...resourceData, title: "Template 2" })
      ).rejects.toThrow("Resource with slug already exists");
    });
  });

  it("should create glossary term with related terms", async () => {
    await t.run(async (ctx) => {
      // Arrange - create parent term
      const parentTermId = await ctx.mutation(api.glossaryTerms.create, {
        term: "Large Language Model",
        slug: "large-language-model",
        abbreviation: "LLM",
        definition: "AI model trained on text data",
        category: "AI Fundamentals",
        isActive: true
      });

      // Create related term
      const relatedTermData = {
        term: "GPT",
        slug: "gpt",
        abbreviation: "GPT",
        definition: "Generative Pre-trained Transformer",
        category: "AI Fundamentals",
        relatedTermIds: [parentTermId],
        isActive: true
      };

      // Act
      const termId = await ctx.mutation(api.glossaryTerms.create, relatedTermData);

      // Assert
      const term = await ctx.query(api.glossaryTerms.get, { termId });
      expect(term.relatedTermIds).toContain(parentTermId);

      const relatedTerms = await ctx.query(api.glossaryTerms.getRelated, { termId: parentTermId });
      expect(relatedTerms).toHaveLength(1);
      expect(relatedTerms[0].term).toBe("GPT");
    });
  });

  it("should track prompt usage and increment count", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const promptId = await ctx.mutation(api.prompts.create, {
        title: "Sales Email Generator",
        slug: "sales-email-generator",
        description: "Generate compelling sales emails",
        category: "writing" as const,
        subcategory: "Marketing",
        promptTemplate: "Write a sales email for {{product_name}}...",
        variables: [
          {
            name: "product_name",
            description: "Name of the product",
            type: "text" as const,
            required: true
          }
        ],
        recommendedModels: ["gpt-4", "claude-3"],
        usageCount: 0,
        isActive: true,
        isFeatured: false,
        sortOrder: 1
      });

      const userId = "user_123" as Id<"users">;

      // Act
      await ctx.mutation(api.prompts.trackUsage, { userId, promptId });
      await ctx.mutation(api.prompts.trackUsage, { userId, promptId });

      // Assert
      const prompt = await ctx.query(api.prompts.get, { promptId });
      expect(prompt.usageCount).toBe(2);
    });
  });

  it("should create bookmark and prevent duplicates", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const userId = "user_123" as Id<"users">;
      const resourceId = "resource_456";

      // Act
      const bookmarkId1 = await ctx.mutation(api.userBookmarks.create, {
        userId,
        resourceType: "resource" as const,
        resourceId,
        notes: "Great template"
      });

      // Assert
      expect(bookmarkId1).toBeDefined();

      // Try to create duplicate
      await expect(
        ctx.mutation(api.userBookmarks.create, {
          userId,
          resourceType: "resource" as const,
          resourceId,
          notes: "Another note"
        })
      ).rejects.toThrow("Bookmark already exists");
    });
  });

  it("should search resources by full-text search", async () => {
    await t.run(async (ctx) => {
      // Arrange
      await ctx.mutation(api.resources.create, {
        title: "Prompt Engineering Masterclass",
        slug: "prompt-engineering-masterclass",
        description: "Advanced prompt engineering techniques",
        type: "video" as const,
        category: "Prompt Engineering",
        tags: ["advanced", "prompting"],
        accessLevel: "public" as const,
        isActive: true,
        isFeatured: false,
        downloadCount: 0,
        viewCount: 0,
        ratingCount: 0,
        sortOrder: 1
      });

      await ctx.mutation(api.resources.create, {
        title: "Beginner Guide to AI",
        slug: "beginner-guide-ai",
        description: "Introduction to artificial intelligence",
        type: "article" as const,
        category: "AI Fundamentals",
        tags: ["beginner", "intro"],
        accessLevel: "public" as const,
        isActive: true,
        isFeatured: false,
        downloadCount: 0,
        viewCount: 0,
        ratingCount: 0,
        sortOrder: 2
      });

      // Act
      const results = await ctx.query(api.resources.search, {
        query: "prompt engineering",
        filters: { type: "video" }
      });

      // Assert
      expect(results).toHaveLength(1);
      expect(results[0].title).toBe("Prompt Engineering Masterclass");
    });
  });

  it("should track resource interactions and update counts", async () => {
    await t.run(async (ctx) => {
      // Arrange
      const resourceId = await ctx.mutation(api.resources.create, {
        title: "Test Resource",
        slug: "test-resource",
        description: "Test description",
        type: "template" as const,
        category: "Test",
        tags: [],
        accessLevel: "public" as const,
        isActive: true,
        isFeatured: false,
        downloadCount: 0,
        viewCount: 0,
        ratingCount: 0,
        sortOrder: 1
      });

      const userId = "user_123" as Id<"users">;

      // Act - track view
      await ctx.mutation(api.resourceInteractions.track, {
        userId,
        resourceId,
        type: "view"
      });

      // Track download
      await ctx.mutation(api.resourceInteractions.track, {
        userId,
        resourceId,
        type: "download"
      });

      // Assert
      const resource = await ctx.query(api.resources.get, { resourceId });
      expect(resource.viewCount).toBe(1);
      expect(resource.downloadCount).toBe(1);
    });
  });
});
```

---

## 6.4 Test Double Strategy

Different types of test doubles serve different purposes. Use the right tool for the job:

| Type | Use Case | When to Use | Example |
|------|----------|-------------|---------|
| **Mock** | Verify interactions with dependencies | Testing that service A calls service B with correct arguments | Verify email service sends welcome email on enrollment |
| **Stub** | Provide canned responses to queries | Need predictable return values for test setup | Stub payment service to return successful checkout URL |
| **Spy** | Record calls for later assertion | Need to verify interaction *and* use real implementation | Spy on analytics service to verify tracking calls |
| **Fake** | Simplified working implementation | Need realistic behavior without external dependencies | In-memory database for Convex queries |

### Implementation Examples

**Mock - Strict Interaction Verification:**
```typescript
// Mock email service to verify welcome email sent
const mockEmailService = mock<IEmailService>();
await enrollmentService.createEnrollment(data);
expect(mockEmailService.sendTemplate).toHaveBeenCalledOnce();
```

**Stub - Provide Canned Response:**
```typescript
// Stub payment service to return success
const stubPaymentService = mock<IPaymentService>();
stubPaymentService.createCheckoutSession.mockResolvedValue({ url: "https://checkout.stripe.com/test" });
const result = await checkoutHandler(stubPaymentService);
expect(result.url).toBe("https://checkout.stripe.com/test");
```

**Spy - Track Real Implementation:**
```typescript
// Spy on analytics to verify tracking without mocking behavior
const spyAnalytics = vi.spyOn(analyticsService, 'track');
await enrollmentService.createEnrollment(data);
expect(spyAnalytics).toHaveBeenCalledWith("Enrollment Created", expect.any(Object));
```

**Fake - Simplified Implementation:**
```typescript
// Fake in-memory database for Convex queries
class FakeConvexClient implements IConvexClient {
  private data = new Map();

  async query(name: string, args: any) {
    return this.data.get(name) || [];
  }

  async mutation(name: string, args: any) {
    this.data.set(name, args);
  }
}
```

---

## 6.5 Testing Stack

### Core Testing Dependencies

```json
{
  "devDependencies": {
    // Test Runner & Assertion
    "vitest": "^2.0.0",
    "vitest-mock-extended": "^2.0.0",
    "@vitest/ui": "^2.0.0",

    // React Component Testing
    "@testing-library/react": "^16.0.0",
    "@testing-library/user-event": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",

    // E2E Testing
    "playwright": "^1.48.0",
    "@playwright/test": "^1.48.0",

    // Convex Testing
    "convex-test": "^0.0.34",

    // API Mocking
    "msw": "^2.0.0",

    // Coverage
    "@vitest/coverage-v8": "^2.0.0"
  }
}
```

### Testing Configuration

**Vitest Config (`vitest.config.ts`):**
```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'tests/',
        '**/*.config.ts',
        '**/types.ts'
      ]
    },
    mockReset: true,
    restoreMocks: true
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  }
});
```

**Playwright Config (`playwright.config.ts`):**
```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

---

## 6.6 Test Organization

### Directory Structure

```
tests/
├── setup.ts                          # Global test configuration
├── helpers/                          # Shared test utilities
│   ├── mocks.ts                     # Mock factory functions
│   ├── fixtures.ts                  # Test data fixtures
│   └── assertions.ts                # Custom matchers
├── unit/                            # Unit tests (isolated, mocked dependencies)
│   ├── services/
│   │   ├── enrollment.test.ts       # Enrollment service behavior
│   │   ├── payment.test.ts          # Stripe integration logic
│   │   ├── email.test.ts            # Brevo email sending
│   │   ├── analytics.test.ts        # PostHog tracking
│   │   ├── survey.test.ts           # Formbricks survey triggers
│   │   ├── scheduling.test.ts       # Cal.com booking logic
│   │   ├── chat.test.ts             # Claude AI chat service
│   │   ├── storage.test.ts          # Convex storage operations
│   │   ├── certificate.test.ts      # Certificate generation
│   │   └── webhook.test.ts          # Webhook delivery
│   ├── components/
│   │   ├── EnrollmentCTA.test.tsx   # Enrollment button behavior
│   │   ├── CohortCard.test.tsx      # Cohort display card
│   │   ├── ProgressTracker.test.tsx # Module progress UI
│   │   ├── ChatInterface.test.tsx   # AI chat interface
│   │   └── CertificateDisplay.test.tsx # Certificate rendering
│   └── utils/
│       ├── validation.test.ts       # Input validation logic
│       ├── formatting.test.ts       # Date/currency formatting
│       └── permissions.test.ts      # Access control logic
├── integration/                     # Integration tests (real dependencies, test DB)
│   ├── convex/
│   │   ├── enrollments.test.ts      # Enrollment CRUD mutations
│   │   ├── cohorts.test.ts          # Cohort management mutations
│   │   ├── users.test.ts            # User profile mutations
│   │   ├── progress.test.ts         # Progress tracking mutations
│   │   ├── webhooks.test.ts         # Webhook event mutations
│   │   └── chat.test.ts             # Chat conversation mutations
│   └── api/
│       ├── checkout.test.ts         # Stripe checkout API route
│       ├── webhooks.test.ts         # Stripe webhook handler
│       ├── chat.test.ts             # Claude chat API route
│       ├── certificates.test.ts     # Certificate generation API
│       └── uploads.test.ts          # File upload API
└── e2e/                             # End-to-end tests (Playwright)
    ├── purchase-flow.spec.ts        # Complete purchase journey
    ├── office-hours.spec.ts         # Booking office hours
    ├── chat-interaction.spec.ts     # AI chat conversation
    ├── progress-tracking.spec.ts    # Module completion flow
    ├── certificate-claim.spec.ts    # Certificate generation
    └── admin-cohort.spec.ts         # Admin cohort management
```

### File Naming Conventions

- **Unit tests:** `[module-name].test.ts` or `[ComponentName].test.tsx`
- **Integration tests:** `[feature-name].test.ts`
- **E2E tests:** `[user-journey].spec.ts`

### Test Organization Principles

1. **Colocation:** Tests live near the code they test (unit tests) or in centralized test directories (integration/e2e)
2. **Descriptive names:** Test file names match the module/feature under test
3. **Logical grouping:** Related tests grouped in `describe` blocks
4. **Single responsibility:** Each test file tests one module/component/feature
5. **Shared utilities:** Common test helpers extracted to `tests/helpers/`

---

## 6.7 Coverage Requirements

### Target Coverage by Layer

| Category | Target Coverage | Rationale | Measured By |
|----------|----------------|-----------|-------------|
| **Service Layer** | **90%** | Business logic core - critical to get right | Line + branch coverage |
| **Convex Mutations** | **85%** | Data integrity and state transitions | Line + branch coverage |
| **API Routes** | **80%** | External contracts and webhook handling | Line + branch coverage |
| **React Components** | **70%** | UI behavior and user interactions | Line coverage |
| **E2E Critical Paths** | **100%** | User journeys must never break | Scenario coverage |

### Critical Path Definition

**100% E2E coverage required for:**
1. **Purchase Flow:** Homepage → Cohort page → Checkout → Confirmation → Email
2. **Office Hours Booking:** Dashboard → Available slots → Book → Confirmation
3. **Chat Interaction:** Chat page → Send message → Receive response → Thread history
4. **Progress Tracking:** Module list → Complete module → Update progress → Certificate eligibility
5. **Certificate Claim:** Complete all modules → Generate certificate → Download PDF → Verify
6. **Admin Cohort Management:** Create cohort → Set capacity → Manage enrollments → Close cohort

### Coverage Enforcement

**Pre-commit hook (`pre-commit`):**
```bash
#!/bin/bash
# Run tests with coverage
pnpm vitest run --coverage

# Check coverage thresholds
pnpm vitest run --coverage --coverage.thresholds.lines=80
```

**CI/CD Pipeline (`.github/workflows/test.yml`):**
```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install --frozen-lockfile
      - run: pnpm vitest run --coverage
      - run: pnpm playwright test
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage-final.json
```

### Coverage Exemptions

**Excluded from coverage requirements:**
- Auto-generated files (Convex schema, Prisma types)
- Configuration files (`*.config.ts`, `*.config.js`)
- Type definitions (`types.ts`, `*.d.ts`)
- Development-only utilities (`dev-server.ts`, `seed.ts`)
- Third-party integrations (covered by integration tests)

### Reporting

**Coverage reports generated:**
- **Text summary:** Console output after test run
- **HTML report:** `coverage/index.html` for detailed exploration
- **JSON report:** `coverage/coverage-final.json` for CI/CD pipelines
- **Codecov integration:** Uploaded to Codecov for trend tracking

---

## 6.8 Test Execution Commands

### Local Development

```bash
# Run all tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run tests with coverage
pnpm test:coverage

# Run unit tests only
pnpm test:unit

# Run integration tests only
pnpm test:integration

# Run E2E tests
pnpm test:e2e

# Run E2E tests in UI mode (debugging)
pnpm playwright test --ui

# Run specific test file
pnpm vitest tests/unit/services/enrollment.test.ts

# Run tests matching pattern
pnpm vitest --grep "enrollment"
```

### CI/CD Pipeline

```bash
# Pre-commit validation
pnpm test:unit && pnpm test:integration

# Pull request checks
pnpm test:coverage && pnpm test:e2e

# Pre-deployment smoke tests
pnpm test:e2e --project=chromium --grep "@smoke"
```

---

## 6.9 Best Practices Summary

### DO:
✅ **Write tests first** (red-green-refactor)
✅ **Mock external dependencies** at service boundaries
✅ **Test behavior, not implementation** (verify interactions, not internals)
✅ **Use descriptive test names** that explain expected behavior
✅ **Keep tests isolated** (no shared state between tests)
✅ **Use test doubles appropriately** (mocks for verification, stubs for queries)
✅ **Write integration tests** for critical Convex mutations
✅ **Cover all critical user journeys** with E2E tests
✅ **Fail fast** (don't continue test if precondition fails)
✅ **Clean up after tests** (reset mocks, clear database)

### DON'T:
❌ **Test implementation details** (private methods, internal state)
❌ **Use real external services** in unit/integration tests
❌ **Share test state** between test cases
❌ **Write overly complex tests** (if test is hard to write, code needs refactoring)
❌ **Ignore flaky tests** (fix root cause or disable test)
❌ **Skip E2E for critical paths** (always cover purchase flow, booking, etc.)
❌ **Mock what you own** (mock external services, not your own code)
❌ **Test framework code** (trust that React, Convex, etc. work)
❌ **Aim for 100% coverage** (diminishing returns after 85-90%)
❌ **Sacrifice test readability** for coverage metrics

---

## 6.10 TDD Workflow Example

### Feature: Enrollment Refund Processing

**Step 1: Write Failing Acceptance Test (E2E)**
```typescript
// tests/e2e/refund-flow.spec.ts
test("user can request refund within 14 days", async ({ page }) => {
  // Given: User enrolled 7 days ago
  await enrollUser({ daysAgo: 7 });
  await page.goto("/dashboard/enrollments");

  // When: User requests refund
  await page.click("button:has-text('Request Refund')");
  await page.click("button:has-text('Confirm')");

  // Then: Refund processed and access revoked
  await expect(page.locator("text=Refund processed")).toBeVisible();
  await expect(page.locator("text=Access: Revoked")).toBeVisible();
});
// ❌ FAILS: Refund button doesn't exist
```

**Step 2: Write Failing Integration Test (Convex)**
```typescript
// tests/integration/convex/enrollments.test.ts
test("processRefund mutation updates status and revokes access", async () => {
  // Given: Enrollment within refund window
  const enrollmentId = await createTestEnrollment({ daysAgo: 7 });

  // When: Refund processed
  await convex.mutation(api.enrollments.processRefund, { enrollmentId });

  // Then: Status updated and access revoked
  const enrollment = await convex.query(api.enrollments.get, { enrollmentId });
  expect(enrollment.status).toBe("refunded");
  expect(enrollment.accessLevel).toBe("none");
});
// ❌ FAILS: processRefund mutation doesn't exist
```

**Step 3: Write Failing Unit Test (Service)**
```typescript
// tests/unit/services/enrollment.test.ts
test("processRefund calls payment service and updates enrollment", async () => {
  // Given: Mocked dependencies
  const mockPaymentService = mock<IPaymentService>();
  const service = new EnrollmentService(mockPaymentService);

  // When: Refund processed
  await service.processRefund("enrollment_123");

  // Then: Payment service called
  expect(mockPaymentService.processRefund).toHaveBeenCalledWith(
    "pi_789",
    "Customer requested refund"
  );
});
// ❌ FAILS: processRefund method doesn't exist
```

**Step 4: Implement Minimum Code**
```typescript
// services/enrollment.ts
class EnrollmentService {
  async processRefund(enrollmentId: string): Promise<void> {
    const enrollment = await this.getEnrollment(enrollmentId);

    // Call payment service
    await this.paymentService.processRefund(
      enrollment.paymentIntentId,
      "Customer requested refund"
    );

    // Update enrollment status
    await this.updateEnrollment(enrollmentId, {
      status: "refunded",
      accessLevel: "none"
    });
  }
}
// ✅ Unit test PASSES
```

**Step 5: Implement Convex Mutation**
```typescript
// convex/enrollments.ts
export const processRefund = mutation({
  args: { enrollmentId: v.id("enrollments") },
  handler: async (ctx, { enrollmentId }) => {
    const enrollment = await ctx.db.get(enrollmentId);

    // Validate refund window (14 days)
    const daysSinceEnrollment = /* calculate */;
    if (daysSinceEnrollment > 14) {
      throw new Error("Refund window expired");
    }

    // Update status
    await ctx.db.patch(enrollmentId, {
      status: "refunded",
      accessLevel: "none",
      refundedAt: Date.now()
    });
  }
});
// ✅ Integration test PASSES
```

**Step 6: Implement UI Component**
```typescript
// components/RefundButton.tsx
export function RefundButton({ enrollmentId }: Props) {
  const processRefund = useMutation(api.enrollments.processRefund);

  return (
    <button onClick={() => processRefund({ enrollmentId })}>
      Request Refund
    </button>
  );
}
// ✅ E2E test PASSES
```

**Step 7: Refactor with Confidence**
```typescript
// All tests green → safe to refactor
// Extract validation logic
// Add error handling
// Improve naming
// Tests ensure behavior unchanged
```

---

## 6.11 Conclusion

The London School TDD approach, combined with comprehensive interface definitions and behavior verification, ensures:

1. **Isolation:** Tests never fail due to external service issues
2. **Speed:** Mocked tests run in milliseconds, not seconds
3. **Confidence:** Refactor freely without breaking behavior
4. **Design:** Forces explicit contracts and dependency injection
5. **Documentation:** Tests serve as living specification of expected behavior

By following these practices, the AI Enablement Academy v2 platform maintains high code quality, rapid development velocity, and confidence in every deployment.

---

## 6.12 Additional Service Interfaces

### IManagerDashboardService (v2.1)

**Purpose:** Interface for B2B manager analytics, team management, reporting, and privacy-aware learner oversight.

**Key Capabilities:**
- Multi-team management with role-based access control
- Organization and team-level analytics aggregation
- Skills heat map visualization for competency tracking
- Automated report generation with scheduled delivery
- Manager-initiated learning reminders and nudges
- GDPR-compliant privacy controls and access logging

```typescript
/**
 * Manager Dashboard Service
 * Provides analytics, reporting, and team management for B2B organizations
 */
interface IManagerDashboardService {
  // ==================== Team Management ====================

  /**
   * Get all teams managed by a specific manager
   * @returns Teams with member counts and learning goals
   */
  getManagerTeams(managerId: Id<"users">): Promise<Team[]>;

  /**
   * Get all members of a specific team
   * @returns Team members with roles and join dates
   */
  getTeamMembers(teamId: Id<"teams">): Promise<TeamMember[]>;

  /**
   * Add a user to a team
   * @throws TeamFullError if team at capacity
   * @throws UserAlreadyMemberError if user already in team
   */
  addTeamMember(
    teamId: Id<"teams">,
    userId: Id<"users">,
    role: "member" | "lead"
  ): Promise<void>;

  /**
   * Remove a user from a team
   * @throws LastTeamLeadError if removing last team lead
   */
  removeTeamMember(
    teamId: Id<"teams">,
    userId: Id<"users">
  ): Promise<void>;

  // ==================== Analytics ====================

  /**
   * Get organization-level analytics snapshot
   * @param periodType - daily, weekly, or monthly aggregation
   * @returns Enrollment, engagement, performance, and skills metrics
   */
  getOrganizationAnalytics(
    orgId: Id<"organizations">,
    periodType: "daily" | "weekly" | "monthly",
    dateRange: { start: number; end: number }
  ): Promise<OrganizationAnalytics>;

  /**
   * Get team-level analytics snapshot
   * @returns Team progress, performance, and top performers
   */
  getTeamAnalytics(
    teamId: Id<"teams">,
    periodType: "daily" | "weekly" | "monthly",
    dateRange: { start: number; end: number }
  ): Promise<TeamAnalytics>;

  /**
   * Get skills heat map for a team
   * @returns Matrix of learners × skills with proficiency levels
   */
  getSkillsHeatMap(
    teamId: Id<"teams">
  ): Promise<SkillsHeatMap>;

  // ==================== Reports ====================

  /**
   * Generate a report based on type and filters
   * @param reportType - progress_summary, individual_detail, skill_matrix, roi_analysis, engagement, compliance
   * @returns Report ID for download
   * @throws InsufficientPermissionsError if manager lacks view_scores permission for individual_detail
   */
  generateReport(
    managerId: Id<"users">,
    reportType: ReportType,
    filters: ReportFilters
  ): Promise<Id<"managerReports">>;

  /**
   * Retrieve a previously generated report
   * @returns Report metadata and download URL
   */
  getReport(
    reportId: Id<"managerReports">
  ): Promise<ManagerReport>;

  /**
   * Schedule a report for recurring generation
   * @param schedule - Frequency (daily, weekly, monthly) and recipients
   */
  scheduleReport(
    managerId: Id<"users">,
    schedule: ReportSchedule
  ): Promise<void>;

  /**
   * Export a report to specified format
   * @param format - pdf, csv, or xlsx
   * @returns Download URL for exported file
   */
  exportReport(
    reportId: Id<"managerReports">,
    format: "pdf" | "csv" | "xlsx"
  ): Promise<string>;

  // ==================== Reminders ====================

  /**
   * Send learning reminder to individuals or teams
   * @param reminderInput - Target (individual/team/behind_schedule/inactive), message, channel
   * @returns Reminder ID
   * @emits NotificationService.sendEmail if channel includes email
   * @emits AnalyticsService.track('reminder_sent')
   */
  sendLearningReminder(
    managerId: Id<"users">,
    reminderInput: ReminderInput
  ): Promise<Id<"learningReminders">>;

  /**
   * Get scheduled reminders created by a manager
   * @returns List of sent reminders with recipient counts
   */
  getScheduledReminders(
    managerId: Id<"users">
  ): Promise<LearningReminder[]>;

  // ==================== Privacy ====================

  /**
   * Check if manager has permission to access learner data
   * @returns true if manager has access via team membership and user privacy settings
   */
  checkDataAccess(
    managerId: Id<"users">,
    learnerId: Id<"users">
  ): Promise<boolean>;

  /**
   * Log manager access to learner data (GDPR compliance)
   * @param dataType - scores, activity, certificates, chat_history
   */
  logAccessEvent(
    managerId: Id<"users">,
    learnerId: Id<"users">,
    dataType: "scores" | "activity" | "certificates" | "chat_history"
  ): Promise<void>;
}

/**
 * Supporting Type Definitions
 */
interface Team {
  id: Id<"teams">;
  organizationId: Id<"organizations">;
  name: string;
  description?: string;
  managerId?: Id<"users">;
  memberCount: number;
  targetCourses?: Id<"courses">[];
  targetSkills?: Id<"skills">[];
  completionDeadline?: number;
  isActive: boolean;
}

interface TeamMember {
  userId: Id<"users">;
  teamId: Id<"teams">;
  role: "member" | "lead";
  joinedAt: number;
  userName: string;
  userEmail: string;
}

interface OrganizationAnalytics {
  organizationId: Id<"organizations">;
  periodType: "daily" | "weekly" | "monthly";
  periodStart: number;
  periodEnd: number;
  totalEnrollments: number;
  activeEnrollments: number;
  completedEnrollments: number;
  totalLearningHours: number;
  avgLearningHoursPerUser: number;
  lessonsCompleted: number;
  avgAssessmentScore?: number;
  avgLearningGain?: number;
  certificatesIssued: number;
  skillsAcquired: number;
  avgSkillProgress: number;
  enrollmentsChange: number; // vs previous period
  completionRateChange: number;
}

interface TeamAnalytics {
  teamId: Id<"teams">;
  organizationId: Id<"organizations">;
  periodType: "daily" | "weekly" | "monthly";
  periodStart: number;
  periodEnd: number;
  memberCount: number;
  activeMembers: number;
  avgProgressPercent: number;
  lessonsCompleted: number;
  totalLearningHours: number;
  avgAssessmentScore?: number;
  coursesCompleted: number;
  topPerformers: Array<{
    userId: Id<"users">;
    metric: string;
    value: number;
  }>;
}

interface SkillsHeatMap {
  teamId: Id<"teams">;
  skills: Array<{
    skillId: Id<"skills">;
    skillName: string;
  }>;
  learners: Array<{
    userId: Id<"users">;
    userName: string;
    skillProficiencies: Array<{
      skillId: Id<"skills">;
      level: number; // 0-100
      lastAssessed: number;
    }>;
  }>;
}

interface ReportFilters {
  teamIds?: Id<"teams">[];
  courseIds?: Id<"courses">[];
  dateRange: {
    start: number;
    end: number;
  };
}

type ReportType =
  | "progress_summary"     // Overall progress
  | "individual_detail"    // Per-learner breakdown
  | "skill_matrix"         // Skills heat map
  | "roi_analysis"         // Learning gains
  | "engagement"           // Activity metrics
  | "compliance";          // Deadline tracking

interface ManagerReport {
  id: Id<"managerReports">;
  organizationId: Id<"organizations">;
  createdBy: Id<"users">;
  name: string;
  reportType: ReportType;
  filters: ReportFilters;
  format: "pdf" | "csv" | "xlsx";
  fileUrl?: string;
  createdAt: number;
}

interface ReportSchedule {
  reportType: ReportType;
  filters: ReportFilters;
  frequency: "daily" | "weekly" | "monthly";
  recipients: string[]; // Email addresses
  format: "pdf" | "csv" | "xlsx";
}

interface ReminderInput {
  targetType: "individual" | "team" | "behind_schedule" | "inactive";
  targetUserIds?: Id<"users">[];
  targetTeamIds?: Id<"teams">[];
  inactivityDays?: number;
  subject: string;
  message: string;
  includeProgress: boolean;
  channel: "email" | "in_app" | "both";
}

interface LearningReminder {
  id: Id<"learningReminders">;
  organizationId: Id<"organizations">;
  sentBy: Id<"users">;
  targetType: "individual" | "team" | "behind_schedule" | "inactive";
  subject: string;
  message: string;
  channel: "email" | "in_app" | "both";
  sentAt: number;
  recipientCount: number;
}
```

---

### Behavior Verification: Manager Dashboard Service

#### Test 1: Privacy-Aware Data Access

**Behavior Under Test:** Manager can only access learner data if privacy settings allow

```typescript
// tests/unit/services/managerDashboard.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock } from 'vitest-mock-extended';
import { ManagerDashboardService } from '@/services/managerDashboard';
import type { IPrivacyService, IAnalyticsService } from '@/services/interfaces';

describe("ManagerDashboardService - Privacy Controls", () => {
  let mockPrivacyService: MockProxy<IPrivacyService>;
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ManagerDashboardService;

  beforeEach(() => {
    mockPrivacyService = mock<IPrivacyService>();
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new ManagerDashboardService(mockPrivacyService, mockAnalyticsService);
  });

  it("should deny access when learner privacy settings disallow", async () => {
    // Arrange
    const managerId = "mgr_123" as Id<"users">;
    const learnerId = "usr_456" as Id<"users">;
    mockPrivacyService.checkSettings.mockResolvedValue({
      allowManagerViewScores: false,
      allowManagerViewActivity: false
    });

    // Act
    const hasAccess = await service.checkDataAccess(managerId, learnerId);

    // Assert
    expect(hasAccess).toBe(false);
    expect(mockPrivacyService.checkSettings).toHaveBeenCalledWith(learnerId);
  });

  it("should log access event when manager views sensitive data", async () => {
    // Arrange
    const managerId = "mgr_123" as Id<"users">;
    const learnerId = "usr_456" as Id<"users">;

    // Act
    await service.logAccessEvent(managerId, learnerId, "scores");

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Manager Data Access",
      expect.objectContaining({
        managerId,
        learnerId,
        dataType: "scores",
        timestamp: expect.any(Number)
      })
    );
  });
});
```

#### Test 2: Report Generation with Permissions

**Behavior Under Test:** Individual detail reports require view_scores permission

```typescript
describe("ManagerDashboardService - Report Generation", () => {
  it("should throw error when generating individual_detail without permissions", async () => {
    // Arrange
    const mockPermissionService = mock<IPermissionService>();
    mockPermissionService.hasPermission.mockResolvedValue(false);
    const service = new ManagerDashboardService(mockPermissionService);

    const managerId = "mgr_123" as Id<"users">;
    const filters: ReportFilters = {
      teamIds: ["team_456" as Id<"teams">],
      dateRange: { start: 0, end: Date.now() }
    };

    // Act & Assert
    await expect(
      service.generateReport(managerId, "individual_detail", filters)
    ).rejects.toThrow("InsufficientPermissionsError");

    expect(mockPermissionService.hasPermission).toHaveBeenCalledWith(
      managerId,
      "view_scores"
    );
  });

  it("should generate progress_summary report without view_scores permission", async () => {
    // Arrange
    const mockPermissionService = mock<IPermissionService>();
    const mockReportGenerator = mock<IReportGenerator>();
    mockReportGenerator.generate.mockResolvedValue("report_789" as Id<"managerReports">);

    const service = new ManagerDashboardService(mockPermissionService, mockReportGenerator);

    const managerId = "mgr_123" as Id<"users">;
    const filters: ReportFilters = {
      teamIds: ["team_456" as Id<"teams">],
      dateRange: { start: 0, end: Date.now() }
    };

    // Act
    const reportId = await service.generateReport(managerId, "progress_summary", filters);

    // Assert
    expect(reportId).toBe("report_789");
    expect(mockReportGenerator.generate).toHaveBeenCalledWith(
      "progress_summary",
      filters
    );
  });
});
```

#### Test 3: Learning Reminder Delivery

**Behavior Under Test:** Manager sends reminder triggers email and in-app notification

```typescript
describe("ManagerDashboardService - Learning Reminders", () => {
  let mockEmailService: MockProxy<IEmailService>;
  let mockNotificationService: MockProxy<INotificationService>;
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: ManagerDashboardService;

  beforeEach(() => {
    mockEmailService = mock<IEmailService>();
    mockNotificationService = mock<INotificationService>();
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new ManagerDashboardService(
      mockEmailService,
      mockNotificationService,
      mockAnalyticsService
    );
  });

  it("should send both email and in-app notifications when channel is 'both'", async () => {
    // Arrange
    const managerId = "mgr_123" as Id<"users">;
    const reminderInput: ReminderInput = {
      targetType: "team",
      targetTeamIds: ["team_456" as Id<"teams">],
      subject: "Complete your AI training",
      message: "Your team deadline is approaching",
      includeProgress: true,
      channel: "both"
    };

    // Act
    await service.sendLearningReminder(managerId, reminderInput);

    // Assert - verify email sent
    expect(mockEmailService.sendTemplate).toHaveBeenCalledOnce();
    expect(mockEmailService.sendTemplate).toHaveBeenCalledWith(
      expect.any(Number), // Template ID
      expect.any(Array),  // Recipients
      expect.objectContaining({
        subject: "Complete your AI training",
        message: "Your team deadline is approaching"
      })
    );

    // Assert - verify in-app notification sent
    expect(mockNotificationService.sendBatch).toHaveBeenCalledOnce();
    expect(mockNotificationService.sendBatch).toHaveBeenCalledWith(
      expect.any(Array), // User IDs
      expect.objectContaining({
        type: "reminder",
        title: "Complete your AI training"
      })
    );

    // Assert - verify analytics tracked
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "reminder_sent",
      expect.objectContaining({
        managerId,
        targetType: "team",
        channel: "both",
        recipientCount: expect.any(Number)
      })
    );
  });

  it("should include progress stats when includeProgress is true", async () => {
    // Arrange
    const managerId = "mgr_123" as Id<"users">;
    const reminderInput: ReminderInput = {
      targetType: "individual",
      targetUserIds: ["usr_789" as Id<"users">],
      subject: "You're 50% done!",
      message: "Keep up the great work",
      includeProgress: true,
      channel: "email"
    };

    // Act
    await service.sendLearningReminder(managerId, reminderInput);

    // Assert
    expect(mockEmailService.sendTemplate).toHaveBeenCalledWith(
      expect.any(Number),
      expect.any(Array),
      expect.objectContaining({
        includeProgress: true,
        progressData: expect.any(Object)
      })
    );
  });
});
```

#### Test 4: Skills Heat Map Generation

**Behavior Under Test:** Heat map aggregates skill proficiencies across team members

```typescript
describe("ManagerDashboardService - Skills Heat Map", () => {
  it("should aggregate skill proficiencies for all team members", async () => {
    // Arrange
    const mockSkillsService = mock<ISkillsService>();
    mockSkillsService.getTeamSkills.mockResolvedValue([
      { userId: "usr_1", skillId: "skill_1", level: 80, lastAssessed: Date.now() },
      { userId: "usr_1", skillId: "skill_2", level: 60, lastAssessed: Date.now() },
      { userId: "usr_2", skillId: "skill_1", level: 90, lastAssessed: Date.now() },
      { userId: "usr_2", skillId: "skill_2", level: 40, lastAssessed: Date.now() },
    ]);

    const service = new ManagerDashboardService(mockSkillsService);
    const teamId = "team_456" as Id<"teams">;

    // Act
    const heatMap = await service.getSkillsHeatMap(teamId);

    // Assert
    expect(heatMap.teamId).toBe(teamId);
    expect(heatMap.skills).toHaveLength(2);
    expect(heatMap.learners).toHaveLength(2);
    expect(heatMap.learners[0].skillProficiencies).toHaveLength(2);
  });
});
```

---

### GDPR Compliance Patterns

#### Privacy-First Testing Approach

**Rule 1: Always Mock Privacy Checks**
```typescript
// Mock privacy service to verify privacy checks occur
const mockPrivacyService = mock<IPrivacyService>();
mockPrivacyService.checkSettings.mockResolvedValue({
  allowManagerViewScores: true
});

// Verify privacy check was performed
expect(mockPrivacyService.checkSettings).toHaveBeenCalledWith(learnerId);
```

**Rule 2: Log All Access Events**
```typescript
// Every sensitive data access must be logged
await service.logAccessEvent(managerId, learnerId, "scores");

// Verify logging occurred
expect(mockAnalyticsService.track).toHaveBeenCalledWith(
  "Manager Data Access",
  expect.objectContaining({ dataType: "scores" })
);
```

**Rule 3: Aggregate by Default**
```typescript
// Team analytics should NOT expose individual names by default
const analytics = await service.getTeamAnalytics(teamId);
expect(analytics.topPerformers[0]).toEqual({
  userId: expect.any(String),
  metric: "lessonsCompleted",
  value: 42
});
// No userName or userEmail in aggregate data
```

---

## 6.2.1 ILearningPathService (v2.1)

**Learning Path Management**
Handles learning path enrollment, progress tracking, step unlocking, and completion certificates.

```typescript
interface ILearningPathService {
  // =========================================================================
  // PATH MANAGEMENT
  // =========================================================================

  /**
   * Get learning path by ID
   * @returns Path details or null if not found
   */
  getPathById(pathId: Id<"learningPaths">): Promise<LearningPath | null>;

  /**
   * Get all steps for a learning path
   * @returns Steps sorted by stepNumber ascending
   */
  getPathSteps(pathId: Id<"learningPaths">): Promise<LearningPathStep[]>;

  /**
   * Get learning paths available to user based on role and audience
   * @returns Active paths filtered by targetAudience and user permissions
   */
  getAvailablePaths(userId: Id<"users">): Promise<LearningPath[]>;

  // =========================================================================
  // ENROLLMENT
  // =========================================================================

  /**
   * Enroll user in learning path after payment
   * @param paymentMethod - bundle | individual | subscription | organization
   * @returns Enrollment ID
   * @throws PathUnavailableError if path not active
   * @throws AlreadyEnrolledError if user already enrolled
   */
  enrollInPath(
    userId: Id<"users">,
    pathId: Id<"learningPaths">,
    paymentMethod: PaymentMethod
  ): Promise<Id<"userPathEnrollments">>;

  /**
   * Get user's enrollment in specific path
   * @returns Enrollment details or null if not enrolled
   */
  getPathEnrollment(
    userId: Id<"users">,
    pathId: Id<"learningPaths">
  ): Promise<UserPathEnrollment | null>;

  // =========================================================================
  // PROGRESS TRACKING
  // =========================================================================

  /**
   * Get current progress for user's path enrollment
   * @returns Progress summary with completed steps and percentage
   */
  getPathProgress(
    enrollmentId: Id<"userPathEnrollments">
  ): Promise<PathProgress>;

  /**
   * Check if specific step is unlocked for user
   * @returns Unlock status with reason if locked
   */
  checkStepUnlock(
    enrollmentId: Id<"userPathEnrollments">,
    stepId: Id<"learningPathSteps">
  ): Promise<UnlockStatus>;

  /**
   * Unlock next step after completing current step
   * @returns true if step unlocked, false if no next step or already unlocked
   * @throws StepNotCompletedError if current step not completed
   */
  unlockNextStep(
    enrollmentId: Id<"userPathEnrollments">
  ): Promise<boolean>;

  // =========================================================================
  // CERTIFICATES
  // =========================================================================

  /**
   * Check if user completed all required steps in path
   * @returns true if all required steps completed, false otherwise
   */
  isPathComplete(
    enrollmentId: Id<"userPathEnrollments">
  ): Promise<boolean>;

  /**
   * Generate completion certificate for path
   * @returns Certificate ID
   * @throws PathNotCompleteError if required steps not completed
   */
  generatePathCertificate(
    enrollmentId: Id<"userPathEnrollments">
  ): Promise<Id<"pathCertificates">>;

  /**
   * Get path certificate details
   * @returns Certificate with Open Badge data or null if not found
   */
  getPathCertificate(
    certificateId: Id<"pathCertificates">
  ): Promise<PathCertificate | null>;
}

// Supporting Types
type PaymentMethod = "bundle" | "individual" | "subscription" | "organization";

interface PathProgress {
  enrollmentId: Id<"userPathEnrollments">;
  pathId: Id<"learningPaths">;
  totalSteps: number;
  requiredSteps: number;
  completedSteps: number;
  progressPercent: number;
  currentStep: LearningPathStep | null;
  nextStep: LearningPathStep | null;
  isComplete: boolean;
}

interface UnlockStatus {
  isUnlocked: boolean;
  reason?: string; // "locked_sequential" | "locked_after_days" | "locked_after_completion"
  unlockDate?: number; // When step will unlock
  requiredStepId?: Id<"learningPathSteps">; // Step that must be completed first
}
```

---

## 6.3.1 Mock Patterns for Learning Path Service

### Mock Factory Function

```typescript
// tests/helpers/mocks.ts
import { mock, mockReset, type MockProxy } from 'vitest-mock-extended';
import type { ILearningPathService, PathProgress, UnlockStatus } from '@/services/interfaces';

export function createMockLearningPathService(): MockProxy<ILearningPathService> {
  const mockService = mock<ILearningPathService>();

  // Default successful behaviors
  mockService.getPathById.mockResolvedValue({
    _id: "path_123" as Id<"learningPaths">,
    title: "AI Leadership Track",
    slug: "ai-leadership",
    targetAudience: "individual",
    isActive: true,
    totalCourses: 5,
    estimatedDuration: "12 weeks",
  });

  mockService.getPathSteps.mockResolvedValue([
    {
      _id: "step_1" as Id<"learningPathSteps">,
      pathId: "path_123" as Id<"learningPaths">,
      courseId: "course_1" as Id<"courses">,
      stepNumber: 1,
      isRequired: true,
      unlockRule: "immediate",
    },
    {
      _id: "step_2" as Id<"learningPathSteps">,
      pathId: "path_123" as Id<"learningPaths">,
      courseId: "course_2" as Id<"courses">,
      stepNumber: 2,
      isRequired: true,
      unlockRule: "sequential",
    },
  ]);

  mockService.enrollInPath.mockResolvedValue("enrollment_123" as Id<"userPathEnrollments">);

  mockService.getPathProgress.mockResolvedValue({
    enrollmentId: "enrollment_123" as Id<"userPathEnrollments">,
    pathId: "path_123" as Id<"learningPaths">,
    totalSteps: 5,
    requiredSteps: 4,
    completedSteps: 2,
    progressPercent: 40,
    currentStep: null,
    nextStep: null,
    isComplete: false,
  });

  mockService.checkStepUnlock.mockResolvedValue({
    isUnlocked: true,
  });

  mockService.unlockNextStep.mockResolvedValue(true);
  mockService.isPathComplete.mockResolvedValue(false);
  mockService.generatePathCertificate.mockResolvedValue("cert_123" as Id<"pathCertificates">);

  return mockService;
}

// Fixture data
export const LEARNING_PATH_FIXTURES = {
  standardPath: {
    _id: "path_123" as Id<"learningPaths">,
    title: "AI Leadership Track",
    slug: "ai-leadership",
    description: "Comprehensive path for AI leaders",
    shortDescription: "Learn to lead AI initiatives",
    targetAudience: "individual" as const,
    estimatedDuration: "12 weeks",
    totalCourses: 5,
    totalHours: 40,
    skillsLearned: ["strategic_ai", "team_leadership", "ai_ethics"],
    isActive: true,
    isFeatured: true,
    sortOrder: 1,
    enrollmentCount: 150,
    completionCount: 45,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  },

  enterprisePath: {
    _id: "path_456" as Id<"learningPaths">,
    title: "Enterprise AI Transformation",
    slug: "enterprise-ai",
    targetAudience: "enterprise" as const,
    totalCourses: 8,
    estimatedDuration: "6 months",
    isActive: true,
  },

  stepImmediate: {
    _id: "step_1" as Id<"learningPathSteps">,
    pathId: "path_123" as Id<"learningPaths">,
    courseId: "course_1" as Id<"courses">,
    stepNumber: 1,
    isRequired: true,
    unlockRule: "immediate" as const,
    createdAt: Date.now(),
  },

  stepSequential: {
    _id: "step_2" as Id<"learningPathSteps">,
    pathId: "path_123" as Id<"learningPaths">,
    courseId: "course_2" as Id<"courses">,
    stepNumber: 2,
    isRequired: true,
    unlockRule: "sequential" as const,
    unlockAfterStepId: "step_1" as Id<"learningPathSteps">,
    createdAt: Date.now(),
  },

  enrollment: {
    _id: "enrollment_123" as Id<"userPathEnrollments">,
    userId: "user_123" as Id<"users">,
    pathId: "path_123" as Id<"learningPaths">,
    status: "active" as const,
    completedSteps: ["step_1"] as Id<"learningPathSteps">[],
    progressPercent: 20,
    paymentType: "bundle" as const,
    enrolledAt: Date.now(),
    createdAt: Date.now(),
    updatedAt: Date.now(),
  },
};
```

---

## 6.12 ICommunityService Interface (v2.1)

### Interface Definition

The Community Service manages discussion threads, replies, peer connections, and moderation for cohort-specific Q&A and networking features.

```typescript
// services/interfaces.ts

/**
 * Community Management (v2.1)
 * Handles discussions, peer connections, and community moderation
 */
interface ICommunityService {
  // ===== Thread Management =====

  /**
   * Create a new discussion thread
   * @param userId - Author ID
   * @param input - Thread creation data
   * @returns Thread ID
   * @throws InvalidScopeError if courseId/sessionId/lessonId mismatch scope
   */
  createThread(
    userId: Id<"users">,
    input: CreateThreadInput
  ): Promise<Id<"discussionThreads">>;

  /**
   * Get thread by ID with author and stats
   * @returns Thread with populated author data, null if not found
   */
  getThread(threadId: Id<"discussionThreads">): Promise<DiscussionThread | null>;

  /**
   * Get threads by scope (course, session, lesson, general)
   * @param scope - Filter by scope and associated IDs
   * @returns Threads sorted by lastActivityAt descending
   */
  getThreadsByScope(scope: ThreadScope): Promise<DiscussionThread[]>;

  // ===== Reply Management =====

  /**
   * Create a reply to a thread or another reply
   * @param parentReplyId - Optional parent reply for nested threads
   * @throws ThreadLockedError if thread is locked
   * @throws ThreadNotFoundError if threadId invalid
   */
  createReply(
    userId: Id<"users">,
    threadId: Id<"discussionThreads">,
    content: string,
    parentReplyId?: Id<"discussionReplies">
  ): Promise<Id<"discussionReplies">>;

  /**
   * Get all replies for a thread
   * @returns Replies sorted by createdAt ascending (chronological)
   */
  getReplies(threadId: Id<"discussionThreads">): Promise<DiscussionReply[]>;

  /**
   * Mark a reply as the best answer for Q&A threads
   * @throws NotThreadAuthorError if caller is not thread author
   * @throws AlreadyMarkedError if another reply already marked as best
   */
  markBestAnswer(
    threadId: Id<"discussionThreads">,
    replyId: Id<"discussionReplies">
  ): Promise<void>;

  // ===== Interaction Management =====

  /**
   * Like a thread (increment like count)
   * @throws AlreadyLikedError if user already liked this thread
   */
  likeThread(userId: Id<"users">, threadId: Id<"discussionThreads">): Promise<void>;

  /**
   * Like a reply (increment like count)
   * @throws AlreadyLikedError if user already liked this reply
   */
  likeReply(userId: Id<"users">, replyId: Id<"discussionReplies">): Promise<void>;

  // ===== Peer Connection Management =====

  /**
   * Request connection with another user
   * @returns Connection ID with status "pending"
   * @throws SelfConnectionError if userId === targetUserId
   * @throws ConnectionExistsError if connection already exists
   */
  requestConnection(
    userId: Id<"users">,
    targetUserId: Id<"users">
  ): Promise<Id<"peerConnections">>;

  /**
   * Respond to a connection request
   * @param accept - true to accept, false to decline
   * @throws NotConnectionRecipientError if caller is not the target user
   * @throws ConnectionNotPendingError if status is not "pending"
   */
  respondToConnection(
    connectionId: Id<"peerConnections">,
    accept: boolean
  ): Promise<void>;

  /**
   * Get all peer connections for a user
   * @returns Connections with status "accepted" sorted by acceptedAt descending
   */
  getPeerConnections(userId: Id<"users">): Promise<PeerConnection[]>;

  /**
   * Get AI-suggested peer connections
   * @param userId - User to generate suggestions for
   * @returns Suggested users based on cohort, skills, industry similarity
   */
  suggestConnections(userId: Id<"users">): Promise<ConnectionSuggestion[]>;

  // ===== Moderation =====

  /**
   * Moderate a thread (lock, hide, pin, etc.)
   * @param adminId - Must have moderator/admin role
   * @param action - Moderation action to perform
   * @throws UnauthorizedError if user is not admin/moderator
   */
  moderateThread(
    adminId: Id<"users">,
    threadId: Id<"discussionThreads">,
    action: ModerationAction
  ): Promise<void>;

  /**
   * Flag content for moderation review
   * @param contentType - "thread" or "reply"
   * @param contentId - ID of thread or reply
   * @param reason - User-provided reason for flagging
   */
  flagContent(
    userId: Id<"users">,
    contentType: "thread" | "reply",
    contentId: string,
    reason: string
  ): Promise<void>;
}

// Supporting Types

interface CreateThreadInput {
  title: string;
  content: string;
  scope: "course" | "session" | "lesson" | "general";
  courseId?: Id<"courses">;
  sessionId?: Id<"sessions">;
  lessonId?: Id<"lessons">;
  category?: "question" | "discussion" | "show-and-tell" | "resource";
  tags?: string[];
}

interface ThreadScope {
  scope: "course" | "session" | "lesson" | "general";
  courseId?: Id<"courses">;
  sessionId?: Id<"sessions">;
  lessonId?: Id<"lessons">;
}

interface DiscussionThread {
  _id: Id<"discussionThreads">;
  title: string;
  content: string;
  authorId: Id<"users">;
  authorName: string;
  scope: "course" | "session" | "lesson" | "general";
  isPinned: boolean;
  isLocked: boolean;
  replyCount: number;
  likeCount: number;
  viewCount: number;
  lastActivityAt: number;
  createdAt: number;
}

interface DiscussionReply {
  _id: Id<"discussionReplies">;
  threadId: Id<"discussionThreads">;
  authorId: Id<"users">;
  authorName: string;
  content: string;
  parentReplyId?: Id<"discussionReplies">;
  isInstructorReply: boolean;
  isBestAnswer: boolean;
  likeCount: number;
  createdAt: number;
}

interface PeerConnection {
  _id: Id<"peerConnections">;
  userId: Id<"users">;
  connectedUserId: Id<"users">;
  connectedUserName: string;
  connectedUserRole: string;
  connectionSource: "cohort" | "manual" | "suggested";
  status: "accepted";
  acceptedAt: number;
}

interface ConnectionSuggestion {
  userId: Id<"users">;
  userName: string;
  userRole: string;
  reason: string; // "Same cohort", "Similar skills", "Same industry"
  sharedCohorts: number;
  matchScore: number; // 0-1 similarity score
}

type ModerationAction =
  | { type: "lock" }
  | { type: "unlock" }
  | { type: "pin" }
  | { type: "unpin" }
  | { type: "hide"; reason: string }
  | { type: "unhide" }
  | { type: "mark_announcement" }
  | { type: "unmark_announcement" };
```

---

### Mock Patterns

```typescript
// tests/helpers/mocks.ts
import { mock } from 'vitest-mock-extended';
import type { ICommunityService } from '@/services/interfaces';

export function mockCommunityService(): MockProxy<ICommunityService> {
  const mockService = mock<ICommunityService>();

  // Default stub: Thread creation returns new ID
  mockService.createThread.mockResolvedValue("thread_abc123" as Id<"discussionThreads">);

  // Default stub: Get thread returns sample thread
  mockService.getThread.mockResolvedValue({
    _id: "thread_abc123" as Id<"discussionThreads">,
    title: "How do I implement prompt chaining?",
    content: "Looking for best practices...",
    authorId: "user_123" as Id<"users">,
    authorName: "Jane Learner",
    scope: "lesson",
    isPinned: false,
    isLocked: false,
    replyCount: 3,
    likeCount: 5,
    viewCount: 42,
    lastActivityAt: Date.now(),
    createdAt: Date.now() - 3600000
  });

  // Default stub: Get threads returns array
  mockService.getThreadsByScope.mockResolvedValue([]);

  // Default stub: Create reply returns new ID
  mockService.createReply.mockResolvedValue("reply_xyz789" as Id<"discussionReplies">);

  // Default stub: Get replies returns array
  mockService.getReplies.mockResolvedValue([]);

  // Default stub: Peer connection returns new ID
  mockService.requestConnection.mockResolvedValue("conn_def456" as Id<"peerConnections">);

  // Default stub: Get connections returns array
  mockService.getPeerConnections.mockResolvedValue([]);

  // Default stub: Suggest connections returns array
  mockService.suggestConnections.mockResolvedValue([]);

  return mockService;
}
```

---

### Test Scenarios

#### Scenario 1: Creating Discussion Thread

**Behavior Under Test:** When thread is created, it appears in scope-filtered queries and author is notified

```typescript
// tests/unit/services/community.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock } from 'vitest-mock-extended';
import { CommunityService } from '@/services/community';
import type { IAnalyticsService } from '@/services/interfaces';

describe("CommunityService - Thread Creation", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let service: CommunityService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    service = new CommunityService(mockAnalyticsService);
  });

  it("should track thread creation event in analytics", async () => {
    // Arrange
    const input: CreateThreadInput = {
      title: "Best practices for system prompts?",
      content: "I'm struggling with...",
      scope: "lesson",
      lessonId: "lesson_123" as Id<"lessons">,
      category: "question",
      tags: ["prompting", "best-practices"]
    };

    // Act
    await service.createThread("user_456" as Id<"users">, input);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Discussion Thread Created",
      expect.objectContaining({
        scope: "lesson",
        category: "question",
        tags: ["prompting", "best-practices"]
      })
    );
  });

  it("should throw InvalidScopeError if lessonId missing for lesson scope", async () => {
    // Arrange
    const input: CreateThreadInput = {
      title: "Thread without lesson ID",
      content: "Invalid scope",
      scope: "lesson", // Requires lessonId!
      category: "question"
    };

    // Act & Assert
    await expect(
      service.createThread("user_456" as Id<"users">, input)
    ).rejects.toThrow("InvalidScopeError");
  });
});
```

#### Scenario 2: Marking Best Answer

**Behavior Under Test:** Thread author can mark a reply as best answer, updating reply status and notifying reply author

```typescript
// tests/unit/services/community.test.ts
describe("CommunityService - Best Answer", () => {
  it("should mark reply as best answer and notify reply author", async () => {
    // Arrange
    const mockNotificationService = mock<INotificationService>();
    const service = new CommunityService(
      mockAnalyticsService,
      mockNotificationService
    );

    // Act
    await service.markBestAnswer(
      "thread_abc123" as Id<"discussionThreads">,
      "reply_xyz789" as Id<"discussionReplies">
    );

    // Assert - Verify notification sent
    expect(mockNotificationService.send).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "best_answer_marked",
        recipientId: expect.any(String),
        threadId: "thread_abc123",
        replyId: "reply_xyz789"
      })
    );
  });

  it("should throw AlreadyMarkedError if another reply is already best answer", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);

    // Mock: Another reply is already marked as best
    // (Implementation would query existing replies)

    // Act & Assert
    await expect(
      service.markBestAnswer(
        "thread_abc123" as Id<"discussionThreads">,
        "reply_new" as Id<"discussionReplies">
      )
    ).rejects.toThrow("AlreadyMarkedError");
  });
});
```

#### Scenario 3: Peer Connection Suggestions

**Behavior Under Test:** AI suggests connections based on shared cohorts, skills, and industry

```typescript
// tests/unit/services/community.test.ts
describe("CommunityService - Connection Suggestions", () => {
  it("should return users from same cohort sorted by match score", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);
    const userId = "user_123" as Id<"users">;

    // Act
    const suggestions = await service.suggestConnections(userId);

    // Assert
    expect(suggestions).toBeDefined();
    expect(suggestions.length).toBeGreaterThan(0);
    expect(suggestions[0].matchScore).toBeGreaterThanOrEqual(
      suggestions[suggestions.length - 1].matchScore
    ); // Sorted descending
    expect(suggestions[0].reason).toContain("Same cohort");
  });

  it("should exclude users already connected", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);
    const userId = "user_123" as Id<"users">;

    // Mock: User already connected to "user_456"
    const existingConnections = await service.getPeerConnections(userId);
    const existingIds = existingConnections.map(c => c.connectedUserId);

    // Act
    const suggestions = await service.suggestConnections(userId);

    // Assert
    suggestions.forEach(suggestion => {
      expect(existingIds).not.toContain(suggestion.userId);
    });
  });
});
```

#### Scenario 4: Moderation Actions

**Behavior Under Test:** Admins can lock/hide threads, and actions are logged for audit trail

```typescript
// tests/unit/services/community.test.ts
describe("CommunityService - Moderation", () => {
  it("should lock thread and prevent new replies", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);
    const adminId = "admin_001" as Id<"users">;
    const threadId = "thread_abc123" as Id<"discussionThreads">;

    // Act
    await service.moderateThread(adminId, threadId, { type: "lock" });

    // Verify thread is locked (would query thread status)
    const thread = await service.getThread(threadId);
    expect(thread?.isLocked).toBe(true);

    // Assert - New replies should fail
    await expect(
      service.createReply(
        "user_456" as Id<"users">,
        threadId,
        "This should fail"
      )
    ).rejects.toThrow("ThreadLockedError");
  });

  it("should throw UnauthorizedError if non-admin attempts moderation", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);
    const regularUserId = "user_789" as Id<"users">;
    const threadId = "thread_abc123" as Id<"discussionThreads">;

    // Act & Assert
    await expect(
      service.moderateThread(regularUserId, threadId, { type: "lock" })
    ).rejects.toThrow("UnauthorizedError");
  });

  it("should track moderation action in analytics", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);
    const adminId = "admin_001" as Id<"users">;
    const threadId = "thread_abc123" as Id<"discussionThreads">;

    // Act
    await service.moderateThread(adminId, threadId, {
      type: "hide",
      reason: "Spam content"
    });

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Thread Moderated",
      expect.objectContaining({
        moderatorId: adminId,
        threadId: threadId,
        action: "hide",
        reason: "Spam content"
      })
    );
  });
});
```

#### Scenario 5: Flagging Content

**Behavior Under Test:** Users can flag threads/replies for moderation review

```typescript
// tests/unit/services/community.test.ts
describe("CommunityService - Content Flagging", () => {
  it("should flag thread and notify moderators", async () => {
    // Arrange
    const mockNotificationService = mock<INotificationService>();
    const service = new CommunityService(
      mockAnalyticsService,
      mockNotificationService
    );

    // Act
    await service.flagContent(
      "user_123" as Id<"users">,
      "thread",
      "thread_abc123",
      "Inappropriate language"
    );

    // Assert - Moderators notified
    expect(mockNotificationService.send).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "content_flagged",
        recipientRole: "moderator",
        contentType: "thread",
        contentId: "thread_abc123",
        reason: "Inappropriate language"
      })
    );
  });

  it("should update thread status to 'flagged'", async () => {
    // Arrange
    const service = new CommunityService(mockAnalyticsService);

    // Act
    await service.flagContent(
      "user_123" as Id<"users">,
      "thread",
      "thread_abc123",
      "Spam"
    );

    // Assert - Thread status updated
    const thread = await service.getThread("thread_abc123" as Id<"discussionThreads">);
    expect(thread?.status).toBe("flagged");
  });
});
```

---

### Integration Tests

#### Convex Mutation Tests

```typescript
// tests/integration/convex/community.test.ts
import { convexTest } from "convex-test";
import { describe, it, expect, beforeEach } from "vitest";
import schema from "@/convex/schema";
import { api } from "@/convex/_generated/api";

describe("Community Convex Mutations", () => {
  let t: ConvexTestingHelper;

  beforeEach(async () => {
    t = convexTest(schema);
  });

  it("should create thread and increment reply count on reply", async () => {
    // Arrange: Create thread
    const threadId = await t.mutation(api.community.createThread, {
      title: "Test Thread",
      content: "Test content",
      scope: "general"
    });

    // Act: Add reply
    await t.mutation(api.community.createReply, {
      threadId,
      content: "First reply!"
    });

    // Assert: Reply count incremented
    const thread = await t.query(api.community.getThread, { threadId });
    expect(thread.replyCount).toBe(1);
  });

  it("should prevent duplicate likes on same thread", async () => {
    // Arrange: Create thread
    const threadId = await t.mutation(api.community.createThread, {
      title: "Test Thread",
      content: "Test content",
      scope: "general"
    });

    // Act: Like thread twice
    await t.mutation(api.community.likeThread, { threadId });

    // Assert: Second like throws error
    await expect(
      t.mutation(api.community.likeThread, { threadId })
    ).rejects.toThrow("AlreadyLikedError");
  });

  it("should filter threads by scope and status", async () => {
    // Arrange: Create threads in different scopes
    const lessonThreadId = await t.mutation(api.community.createThread, {
      title: "Lesson Thread",
      content: "Lesson content",
      scope: "lesson",
      lessonId: "lesson_123"
    });

    const generalThreadId = await t.mutation(api.community.createThread, {
      title: "General Thread",
      content: "General content",
      scope: "general"
    });

    // Act: Query lesson threads only
    const lessonThreads = await t.query(api.community.getThreadsByScope, {
      scope: "lesson",
      lessonId: "lesson_123"
    });

    // Assert: Only lesson thread returned
    expect(lessonThreads).toHaveLength(1);
    expect(lessonThreads[0]._id).toBe(lessonThreadId);
  });

  it("should update lastActivityAt on new reply", async () => {
    // Arrange: Create thread
    const threadId = await t.mutation(api.community.createThread, {
      title: "Test Thread",
      content: "Test content",
      scope: "general"
    });

    const threadBefore = await t.query(api.community.getThread, { threadId });

    // Wait 100ms
    await new Promise(resolve => setTimeout(resolve, 100));

    // Act: Add reply
    await t.mutation(api.community.createReply, {
      threadId,
      content: "New reply"
    });

    // Assert: lastActivityAt updated
    const threadAfter = await t.query(api.community.getThread, { threadId });
    expect(threadAfter.lastActivityAt).toBeGreaterThan(threadBefore.lastActivityAt);
  });
});
```

---

### E2E Test Scenarios

```typescript
// tests/e2e/community-discussion.spec.ts
import { test, expect } from '@playwright/test';

test.describe("Community Discussion Flow", () => {
  test("learner creates question thread and receives instructor reply", async ({ page }) => {
    // Given: Learner is enrolled in course
    await page.goto("/courses/advanced-prompting/discussions");

    // When: Learner creates question
    await page.click("button:has-text('New Question')");
    await page.fill("input[name='title']", "What is chain-of-thought prompting?");
    await page.fill("textarea[name='content']", "I'm confused about when to use it...");
    await page.selectOption("select[name='category']", "question");
    await page.click("button:has-text('Post Question')");

    // Then: Thread appears in list
    await expect(page.locator("text=What is chain-of-thought prompting?")).toBeVisible();

    // When: Instructor replies
    await page.click("text=What is chain-of-thought prompting?");
    await page.fill("textarea[name='reply']", "Great question! Chain-of-thought...");
    await page.click("button:has-text('Reply')");

    // Then: Reply visible with instructor badge
    await expect(page.locator("text=Great question!")).toBeVisible();
    await expect(page.locator(".instructor-badge")).toBeVisible();

    // When: Learner marks as best answer
    await page.click("button[aria-label='Mark as best answer']");

    // Then: Best answer badge appears
    await expect(page.locator(".best-answer-badge")).toBeVisible();
  });

  test("learner receives peer connection suggestion and accepts", async ({ page }) => {
    // Given: Learner views peer connections
    await page.goto("/dashboard/connections");

    // When: Learner views suggested connections
    await page.click("tab:has-text('Suggestions')");

    // Then: Suggestions displayed with match reasons
    await expect(page.locator(".connection-suggestion")).toHaveCount(5);
    await expect(page.locator("text=Same cohort")).toBeVisible();

    // When: Learner sends connection request
    await page.click("button:has-text('Connect'):first");

    // Then: Request sent confirmation
    await expect(page.locator("text=Connection request sent")).toBeVisible();
  });

  test("moderator locks flagged thread", async ({ page }) => {
    // Given: Moderator views flagged content
    await page.goto("/admin/moderation");

    // When: Moderator views flagged thread
    await page.click("text=Flagged: Spam content");

    // Then: Thread details and flag reason visible
    await expect(page.locator("text=Reason: Spam")).toBeVisible();

    // When: Moderator locks thread
    await page.click("button:has-text('Lock Thread')");
    await page.fill("textarea[name='reason']", "Confirmed spam");
    await page.click("button:has-text('Confirm Lock')");

    // Then: Thread locked badge appears
    await expect(page.locator(".thread-locked-badge")).toBeVisible();
  });
});
```

---

### Coverage Notes

**Key Behaviors to Test:**
- Thread creation with different scopes (course, session, lesson, general)
- Reply threading (flat and nested)
- Best answer marking (only thread author can mark)
- Like interactions (prevent duplicates)
- Peer connection workflow (request → accept/decline)
- Connection suggestions (AI-based matching)
- Moderation actions (lock, hide, pin)
- Content flagging workflow
- Notification triggers (new reply, best answer, connection request)
- Access control (instructor-only actions, admin-only moderation)

**Edge Cases:**
- Creating thread with mismatched scope and IDs
- Replying to locked threads
- Marking best answer on non-question threads
- Self-connection requests
- Non-admin moderation attempts
- Duplicate likes/flags

**Integration Points:**
- Notification service (reply notifications, connection requests)
- Analytics service (track thread creation, moderation actions)
- User service (validate user roles for moderation)
- Course service (validate courseId/sessionId/lessonId)

---

## 6.12 Assessment Service Interface (v2.1)

### IAssessmentService

Interface for pre/post assessments, grading, and learning gain calculation. Enables comprehensive measurement of learning outcomes using evidence-based methodologies (Hake's normalized gain) with AI-assisted grading for scale.

```typescript
/**
 * Assessment Management & Learning Measurement
 * Pre/post assessments, grading, and ROI measurement
 */
interface IAssessmentService {
  // =============================================================================
  // ASSESSMENT MANAGEMENT
  // =============================================================================

  /**
   * Get assessment by ID
   * @returns Assessment configuration or null if not found
   */
  getAssessmentById(assessmentId: Id<"assessments">): Promise<Assessment | null>;

  /**
   * Get all assessments for a specific course
   * @returns Assessments sorted by type (pre_course, knowledge_check, post_course)
   */
  getAssessmentsForCourse(courseId: Id<"courses">): Promise<Assessment[]>;

  /**
   * Get all questions for an assessment
   * @returns Questions sorted by sortOrder
   */
  getAssessmentQuestions(assessmentId: Id<"assessments">): Promise<AssessmentQuestion[]>;

  /**
   * Create new assessment
   * @throws DuplicateAssessmentError if pre/post already exists for course
   */
  createAssessment(data: CreateAssessmentData): Promise<Id<"assessments">>;

  /**
   * Add question to assessment
   * @throws InvalidQuestionTypeError if question type doesn't match assessment requirements
   */
  addQuestion(data: CreateQuestionData): Promise<Id<"assessmentQuestions">>;

  // =============================================================================
  // TAKING ASSESSMENTS
  // =============================================================================

  /**
   * Start a new assessment attempt
   * @throws MaxAttemptsExceededError if user has exhausted retries
   * @throws AssessmentNotActiveError if assessment is disabled
   * @returns Attempt ID for tracking responses
   */
  startAssessment(
    userId: Id<"users">,
    assessmentId: Id<"assessments">,
    enrollmentId?: Id<"enrollments">
  ): Promise<Id<"assessmentAttempts">>;

  /**
   * Submit response to a single question
   * @throws AttemptExpiredError if time limit exceeded
   * @throws InvalidResponseError if response format doesn't match question type
   */
  submitResponse(
    attemptId: Id<"assessmentAttempts">,
    questionId: Id<"assessmentQuestions">,
    response: QuestionResponse
  ): Promise<void>;

  /**
   * Complete assessment and trigger grading
   * @returns Assessment result with score and pass/fail status
   * @throws IncompleteAttemptError if not all required questions answered
   */
  completeAssessment(attemptId: Id<"assessmentAttempts">): Promise<AssessmentResult>;

  /**
   * Resume in-progress assessment
   * @returns Attempt with already-submitted responses
   * @throws NoActiveAttemptError if no in-progress attempt found
   */
  resumeAttempt(userId: Id<"users">, assessmentId: Id<"assessments">): Promise<AttemptSession>;

  // =============================================================================
  // GRADING
  // =============================================================================

  /**
   * Auto-grade multiple choice, multiple select, true/false questions
   * @returns Score as percentage (0-100)
   */
  gradeMultipleChoice(attemptId: Id<"assessmentAttempts">): Promise<number>;

  /**
   * Use AI (Claude) to grade open-ended response
   * @returns AI score, confidence level, and explanation
   * @throws AIServiceError if Claude API fails
   */
  gradeOpenEndedWithAI(
    responseId: Id<"questionResponses">,
    questionText: string,
    sampleAnswer: string,
    userResponse: string
  ): Promise<AIGradingResult>;

  /**
   * Submit manual grade for open-ended or short answer
   * @param grade - Score (0-100)
   * @param feedback - Written feedback for learner
   * @throws InvalidGradeError if grade outside 0-100 range
   */
  submitManualGrade(
    responseId: Id<"questionResponses">,
    grade: number,
    feedback: string,
    gradedBy: Id<"users">
  ): Promise<void>;

  /**
   * Override AI grading with manual review
   * @param manualScore - Instructor's corrected score
   */
  overrideAIGrade(
    responseId: Id<"questionResponses">,
    manualScore: number,
    reason: string,
    gradedBy: Id<"users">
  ): Promise<void>;

  // =============================================================================
  // LEARNING GAIN CALCULATION
  // =============================================================================

  /**
   * Calculate learning gain using Hake's normalized gain formula
   * Formula: (post_score - pre_score) / (100 - pre_score)
   *
   * Interpretation:
   * - g ≥ 0.7: High gain (exceptional learning)
   * - 0.3 ≤ g < 0.7: Medium gain (good learning)
   * - g < 0.3: Low gain (ineffective instruction)
   *
   * @throws MissingAssessmentError if pre or post assessment not completed
   */
  calculateLearningGain(
    userId: Id<"users">,
    courseId: Id<"courses">
  ): Promise<LearningGainResult>;

  /**
   * Get aggregated learning gain analytics for entire course
   * @returns Average normalized gain, score distributions, skill-level gains
   */
  getLearningGainAnalytics(courseId: Id<"courses">): Promise<LearningGainAnalytics>;

  /**
   * Get skill-specific learning gains
   * @returns Per-skill pre/post scores and normalized gains
   */
  getSkillLevelGains(
    userId: Id<"users">,
    courseId: Id<"courses">
  ): Promise<SkillGain[]>;

  // =============================================================================
  // REPORTING
  // =============================================================================

  /**
   * Generate comprehensive assessment report for user
   * @returns All attempts, scores, learning gains, skill breakdown
   */
  generateAssessmentReport(
    userId: Id<"users">,
    courseId: Id<"courses">
  ): Promise<AssessmentReport>;

  /**
   * Generate organizational ROI report (B2B)
   * @returns Aggregated learning gains, completion rates, skill improvements
   */
  generateOrganizationReport(organizationId: string): Promise<OrganizationReport>;

  /**
   * Export assessment data for analysis
   * @returns CSV-formatted data with all attempts and responses
   */
  exportAssessmentData(
    courseId: Id<"courses">,
    format: "csv" | "json"
  ): Promise<string>;
}

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

type QuestionResponse =
  | { type: "multiple_choice"; answerId: string }
  | { type: "multiple_select"; answerIds: string[] }
  | { type: "true_false"; answerId: string }
  | { type: "short_answer"; text: string }
  | { type: "open_ended"; text: string }
  | { type: "rating_scale"; value: number };

interface AssessmentResult {
  attemptId: Id<"assessmentAttempts">;
  score: number; // 0-100
  pointsEarned: number;
  pointsPossible: number;
  passed: boolean;
  timeSpent: number; // seconds
  correctAnswers: number;
  totalQuestions: number;
  feedback: string;
}

interface AIGradingResult {
  score: number; // 0-100
  confidence: number; // 0-1
  explanation: string;
  keyPointsCovered: string[];
  areasForImprovement: string[];
}

interface LearningGainResult {
  userId: Id<"users">;
  courseId: Id<"courses">;
  preScore: number;
  postScore: number;
  scoreImprovement: number; // post - pre
  percentageGain: number; // ((post-pre)/pre) * 100
  normalizedGain: number; // (post-pre)/(100-pre) - Hake's g-factor
  interpretation: "high" | "medium" | "low";
  skillGains: SkillGain[];
}

interface SkillGain {
  skillId: Id<"skills">;
  skillName: string;
  preScore: number;
  postScore: number;
  improvement: number;
  normalizedGain: number;
}

interface LearningGainAnalytics {
  courseId: Id<"courses">;
  totalStudents: number;
  averageNormalizedGain: number;
  highGainStudents: number; // g >= 0.7
  mediumGainStudents: number; // 0.3 <= g < 0.7
  lowGainStudents: number; // g < 0.3
  averagePreScore: number;
  averagePostScore: number;
  skillBreakdown: SkillAnalytics[];
}

interface SkillAnalytics {
  skillId: Id<"skills">;
  skillName: string;
  averagePreScore: number;
  averagePostScore: number;
  averageGain: number;
  studentsImproved: number;
}

interface AssessmentReport {
  userId: Id<"users">;
  courseId: Id<"courses">;
  attempts: AttemptSummary[];
  learningGain: LearningGainResult | null;
  skillMastery: SkillMasteryLevel[];
  certificateEligible: boolean;
}

interface AttemptSummary {
  attemptId: Id<"assessmentAttempts">;
  assessmentTitle: string;
  assessmentType: string;
  attemptNumber: number;
  score: number;
  passed: boolean;
  completedAt: number;
}

interface SkillMasteryLevel {
  skillId: Id<"skills">;
  skillName: string;
  currentScore: number;
  masteryLevel: "novice" | "intermediate" | "advanced" | "expert";
}

interface OrganizationReport {
  organizationId: string;
  reportPeriod: { start: number; end: number };
  totalEnrollments: number;
  completionRate: number;
  averageLearningGain: number;
  courseBreakdown: CourseROI[];
  skillImprovements: SkillAnalytics[];
  topPerformers: UserSummary[];
}

interface CourseROI {
  courseId: Id<"courses">;
  courseName: string;
  enrollments: number;
  completions: number;
  averagePreScore: number;
  averagePostScore: number;
  averageNormalizedGain: number;
}

interface UserSummary {
  userId: Id<"users">;
  userName: string;
  coursesCompleted: number;
  averageScore: number;
  averageLearningGain: number;
}

interface AttemptSession {
  attemptId: Id<"assessmentAttempts">;
  assessmentId: Id<"assessments">;
  questions: AssessmentQuestion[];
  responses: Map<Id<"assessmentQuestions">, QuestionResponse>;
  timeRemaining: number | null; // seconds, null if no time limit
  startedAt: number;
}

interface CreateAssessmentData {
  title: string;
  description?: string;
  type: "pre_course" | "post_course" | "knowledge_check" | "skill_assessment" | "certification" | "self_assessment";
  courseId?: Id<"courses">;
  lessonId?: Id<"lessons">;
  skillIds?: Id<"skills">[];
  timeLimit?: number;
  passingScore: number;
  allowRetake: boolean;
  maxAttempts?: number;
  showCorrectAnswers: "never" | "after_submit" | "after_passing" | "after_all_attempts";
  randomizeQuestions: boolean;
  randomizeAnswers: boolean;
  questionsPerAttempt?: number;
}

interface CreateQuestionData {
  assessmentId: Id<"assessments">;
  questionType: "multiple_choice" | "multiple_select" | "true_false" | "short_answer" | "rating_scale" | "open_ended";
  questionText: string;
  questionImageId?: Id<"_storage">;
  explanation?: string;
  answers?: Answer[];
  scaleMin?: number;
  scaleMax?: number;
  scaleLabels?: { min: string; max: string };
  sampleAnswer?: string;
  aiGradingEnabled?: boolean;
  points: number;
  difficulty: "easy" | "medium" | "hard";
  skillIds?: Id<"skills">[];
  tags?: string[];
  sortOrder: number;
}

interface Answer {
  id: string; // UUID
  text: string;
  isCorrect: boolean;
  feedback?: string;
}
```

---

## 6.13 Assessment Service Test Scenarios

### Unit Tests - Hake's Normalized Gain Implementation

**Behavior Under Test:** Learning gain calculation follows Hake's formula correctly

```typescript
// tests/unit/services/assessment.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { AssessmentService } from '@/services/assessment';

describe("AssessmentService - Learning Gain Calculation", () => {
  let service: AssessmentService;

  beforeEach(() => {
    service = new AssessmentService();
  });

  it("should calculate high normalized gain (g >= 0.7) correctly", () => {
    // Arrange
    const preScore = 40;
    const postScore = 85;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBeCloseTo(0.75, 2); // (85-40)/(100-40) = 45/60 = 0.75
    expect(service.interpretGain(gain)).toBe("high");
  });

  it("should calculate medium normalized gain (0.3 <= g < 0.7) correctly", () => {
    // Arrange
    const preScore = 75;
    const postScore = 90;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBeCloseTo(0.60, 2); // (90-75)/(100-75) = 15/25 = 0.60
    expect(service.interpretGain(gain)).toBe("medium");
  });

  it("should calculate low normalized gain (g < 0.3) correctly", () => {
    // Arrange
    const preScore = 60;
    const postScore = 68;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBeCloseTo(0.20, 2); // (68-60)/(100-60) = 8/40 = 0.20
    expect(service.interpretGain(gain)).toBe("low");
  });

  it("should handle ceiling effect (pre-score = 95%)", () => {
    // Arrange
    const preScore = 95;
    const postScore = 98;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBeCloseTo(0.60, 2); // (98-95)/(100-95) = 3/5 = 0.60
    expect(service.interpretGain(gain)).toBe("medium");
  });

  it("should return 0 when no improvement", () => {
    // Arrange
    const preScore = 70;
    const postScore = 70;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBe(0);
    expect(service.interpretGain(gain)).toBe("low");
  });

  it("should handle negative gain (score decreased)", () => {
    // Arrange
    const preScore = 80;
    const postScore = 70;

    // Act
    const gain = service.calculateNormalizedGain(preScore, postScore);

    // Assert
    expect(gain).toBeCloseTo(-0.50, 2); // (70-80)/(100-80) = -10/20 = -0.50
    expect(service.interpretGain(gain)).toBe("low");
  });
});
```

### Unit Tests - AI Grading with Mocks

**Behavior Under Test:** AI grading service correctly evaluates open-ended responses

```typescript
// tests/unit/services/assessment-ai-grading.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock, mockReset } from 'vitest-mock-extended';
import { AssessmentService } from '@/services/assessment';
import type { IChatService } from '@/services/interfaces';

describe("AssessmentService - AI Grading", () => {
  let mockChatService: MockProxy<IChatService>;
  let service: AssessmentService;

  beforeEach(() => {
    mockChatService = mock<IChatService>();
    service = new AssessmentService(mockChatService);
  });

  it("should grade response with high confidence (>= 0.9)", async () => {
    // Arrange
    const questionText = "Describe a business process for AI automation";
    const sampleAnswer = "Marketing team categorizing support tickets...";
    const userResponse = "Our sales team manually qualifies leads...";

    mockChatService.sendMessage.mockResolvedValue({
      score: 85,
      confidence: 0.95,
      explanation: "Response demonstrates clear understanding of AI automation principles",
      keyPointsCovered: ["specific process", "automation tasks", "expected outcomes"],
      areasForImprovement: []
    });

    // Act
    const result = await service.gradeOpenEndedWithAI(
      "response_123",
      questionText,
      sampleAnswer,
      userResponse
    );

    // Assert
    expect(result.score).toBe(85);
    expect(result.confidence).toBeGreaterThanOrEqual(0.9);
    expect(mockChatService.sendMessage).toHaveBeenCalledWith(
      expect.any(String),
      expect.stringContaining(questionText)
    );
  });

  it("should flag low confidence responses for manual review", async () => {
    // Arrange
    const questionText = "Explain prompt engineering best practices";
    const sampleAnswer = "Clear context, step-by-step, examples...";
    const userResponse = "You should make prompts good";

    mockChatService.sendMessage.mockResolvedValue({
      score: 40,
      confidence: 0.65, // Low confidence
      explanation: "Response lacks specificity and depth",
      keyPointsCovered: [],
      areasForImprovement: ["needs specific techniques", "lacks examples"]
    });

    // Act
    const result = await service.gradeOpenEndedWithAI(
      "response_456",
      questionText,
      sampleAnswer,
      userResponse
    );

    // Assert
    expect(result.confidence).toBeLessThan(0.7);
    expect(result.areasForImprovement.length).toBeGreaterThan(0);
  });

  it("should handle AI service errors gracefully", async () => {
    // Arrange
    mockChatService.sendMessage.mockRejectedValue(
      new Error("Claude API rate limit exceeded")
    );

    // Act & Assert
    await expect(
      service.gradeOpenEndedWithAI(
        "response_789",
        "Question text",
        "Sample answer",
        "User response"
      )
    ).rejects.toThrow("AIServiceError");
  });
});
```

### Integration Tests - Complete Assessment Flow

**Behavior Under Test:** End-to-end assessment workflow from start to grading

```typescript
// tests/integration/convex/assessments.test.ts
import { convexTest } from "convex-test";
import { describe, it, expect, beforeEach } from "vitest";
import { api } from "@/convex/_generated/api";

describe("Assessment Flow - Integration", () => {
  let convex: ConvexTestClient;

  beforeEach(async () => {
    convex = convexTest(schema);
    // Seed test data
    await seedAssessments(convex);
  });

  it("should complete full pre/post assessment workflow", async () => {
    // Given: User and course with pre/post assessments
    const userId = await convex.mutation(api.users.create, { email: "learner@test.com" });
    const courseId = "course_ai_fundamentals";
    const preAssessmentId = "assessment_pre";
    const postAssessmentId = "assessment_post";

    // When: User takes pre-assessment
    const preAttemptId = await convex.mutation(api.assessments.startAssessment, {
      userId,
      assessmentId: preAssessmentId
    });

    // Submit answers (mix of correct/incorrect)
    await convex.mutation(api.assessments.submitResponse, {
      attemptId: preAttemptId,
      questionId: "q1",
      response: { type: "multiple_choice", answerId: "correct_answer_1" }
    });

    await convex.mutation(api.assessments.submitResponse, {
      attemptId: preAttemptId,
      questionId: "q2",
      response: { type: "multiple_choice", answerId: "wrong_answer_2" }
    });

    const preResult = await convex.mutation(api.assessments.completeAssessment, {
      attemptId: preAttemptId
    });

    // Then: Pre-assessment graded
    expect(preResult.score).toBe(50); // 1/2 correct

    // When: User takes post-assessment (after course)
    const postAttemptId = await convex.mutation(api.assessments.startAssessment, {
      userId,
      assessmentId: postAssessmentId
    });

    // Submit same questions, now all correct
    await convex.mutation(api.assessments.submitResponse, {
      attemptId: postAttemptId,
      questionId: "q1",
      response: { type: "multiple_choice", answerId: "correct_answer_1" }
    });

    await convex.mutation(api.assessments.submitResponse, {
      attemptId: postAttemptId,
      questionId: "q2",
      response: { type: "multiple_choice", answerId: "correct_answer_2" }
    });

    const postResult = await convex.mutation(api.assessments.completeAssessment, {
      attemptId: postAttemptId
    });

    // Then: Post-assessment graded
    expect(postResult.score).toBe(100);

    // When: Calculate learning gain
    const learningGain = await convex.query(api.assessments.calculateLearningGain, {
      userId,
      courseId
    });

    // Then: Normalized gain calculated correctly
    // (100 - 50) / (100 - 50) = 50 / 50 = 1.0 (perfect gain)
    expect(learningGain.normalizedGain).toBeCloseTo(1.0, 2);
    expect(learningGain.interpretation).toBe("high");
  });

  it("should enforce max attempts limit", async () => {
    // Given: Assessment with maxAttempts = 2
    const userId = await convex.mutation(api.users.create, { email: "learner@test.com" });
    const assessmentId = "assessment_limited";

    // When: Attempt 1
    const attempt1 = await convex.mutation(api.assessments.startAssessment, {
      userId,
      assessmentId
    });
    await completeAttempt(convex, attempt1); // Fails

    // When: Attempt 2
    const attempt2 = await convex.mutation(api.assessments.startAssessment, {
      userId,
      assessmentId
    });
    await completeAttempt(convex, attempt2); // Fails

    // Then: Attempt 3 blocked
    await expect(
      convex.mutation(api.assessments.startAssessment, { userId, assessmentId })
    ).rejects.toThrow("MaxAttemptsExceededError");
  });

  it("should expire assessment after time limit", async () => {
    // Given: Assessment with 5-minute time limit
    const userId = await convex.mutation(api.users.create, { email: "learner@test.com" });
    const assessmentId = "assessment_timed";

    // When: Start assessment
    const attemptId = await convex.mutation(api.assessments.startAssessment, {
      userId,
      assessmentId
    });

    // Simulate time passing (mock system time)
    await advanceTime(6 * 60 * 1000); // 6 minutes

    // Then: Cannot submit responses
    await expect(
      convex.mutation(api.assessments.submitResponse, {
        attemptId,
        questionId: "q1",
        response: { type: "multiple_choice", answerId: "a1" }
      })
    ).rejects.toThrow("AttemptExpiredError");

    // And: Attempt marked as expired
    const attempt = await convex.query(api.assessments.getAttempt, { attemptId });
    expect(attempt.status).toBe("expired");
  });
});
```

### E2E Tests - User Assessment Journey

**Behavior Under Test:** Learner can complete assessment from start to results

```typescript
// tests/e2e/assessment-flow.spec.ts
import { test, expect } from '@playwright/test';

test("learner completes pre-assessment and views results", async ({ page }) => {
  // Given: Enrolled learner viewing course dashboard
  await page.goto("/courses/ai-fundamentals");
  await page.click("button:has-text('Start Pre-Assessment')");

  // When: Taking assessment
  await expect(page.locator("h1")).toContainText("AI Fundamentals - Pre-Assessment");
  await expect(page.locator("text=Question 1 of 20")).toBeVisible();

  // Answer multiple choice question
  await page.click("label:has-text('Machine learning models learn patterns')");
  await page.click("button:has-text('Next')");

  // Answer multiple select question
  await page.click("label:has-text('Providing clear context')");
  await page.click("label:has-text('Breaking complex tasks')");
  await page.click("label:has-text('Including examples')");
  await page.click("button:has-text('Next')");

  // Answer open-ended question
  await page.fill("textarea", "Our marketing team spends 10 hours weekly...");
  await page.click("button:has-text('Next')");

  // ... answer remaining questions ...

  // Submit assessment
  await page.click("button:has-text('Submit Assessment')");
  await page.click("button:has-text('Confirm Submit')");

  // Then: Results displayed
  await expect(page.locator("text=Assessment Complete")).toBeVisible();
  await expect(page.locator("text=Your Score:")).toBeVisible();

  const scoreElement = page.locator("[data-testid='assessment-score']");
  const score = await scoreElement.textContent();
  expect(parseInt(score!)).toBeGreaterThanOrEqual(0);
  expect(parseInt(score!)).toBeLessThanOrEqual(100);

  // And: Baseline recorded message shown
  await expect(page.locator("text=This is your baseline score")).toBeVisible();
  await expect(page.locator("text=Take the post-assessment after course completion")).toBeVisible();
});

test("learner sees learning gain after post-assessment", async ({ page }) => {
  // Given: Learner completed course and pre-assessment (score: 50%)
  await completeCourse(page, { preScore: 50 });

  // When: Taking post-assessment
  await page.goto("/courses/ai-fundamentals");
  await page.click("button:has-text('Take Post-Assessment')");

  // Complete assessment with higher score
  await completeAssessment(page, { targetScore: 85 });

  // Then: Learning gain displayed
  await expect(page.locator("h2")).toContainText("Learning Gain Report");

  await expect(page.locator("text=Pre-Assessment: 50%")).toBeVisible();
  await expect(page.locator("text=Post-Assessment: 85%")).toBeVisible();
  await expect(page.locator("text=Improvement: +35%")).toBeVisible();

  // Normalized gain: (85-50)/(100-50) = 35/50 = 0.70
  await expect(page.locator("text=Normalized Gain: 0.70")).toBeVisible();
  await expect(page.locator("text=High Gain")).toBeVisible();

  // And: Certificate unlocked
  await expect(page.locator("text=Certificate Unlocked!")).toBeVisible();
  await expect(page.locator("button:has-text('Download Certificate')")).toBeEnabled();
});
```

---

## 6.14 Assessment Service Best Practices

### DO:
✅ **Use Hake's normalized gain** for standardized learning measurement
✅ **Flag low-confidence AI grades** for instructor review (confidence < 0.7)
✅ **Randomize question order** to prevent cheating
✅ **Test same questions pre/post** for valid comparison
✅ **Map questions to skills** for granular analytics
✅ **Set reasonable time limits** (1.5 minutes per question)
✅ **Provide immediate feedback** for knowledge checks
✅ **Delay feedback** for pre-assessments (until post-assessment)
✅ **Track attempt timestamps** for academic integrity
✅ **Encrypt sensitive data** (scores, responses) at rest

### DON'T:
❌ **Don't show correct answers** before post-assessment
❌ **Don't use different questions** for pre/post comparison
❌ **Don't auto-grade open-ended** without confidence threshold
❌ **Don't allow unlimited retakes** for high-stakes assessments
❌ **Don't skip normalization** when comparing across cohorts
❌ **Don't ignore ceiling effects** (high pre-scores)
❌ **Don't share individual scores** in organizational reports
❌ **Don't grade without sample answers** for open-ended questions
❌ **Don't trust AI grading 100%** (always allow manual override)
❌ **Don't forget time zone handling** for scheduled assessments

---

## 6.3.2 Test Scenarios for Learning Path Service

### Scenario 1: Enrolling in Learning Path

**Behavior Under Test:** When user enrolls in path, analytics tracked and welcome email sent

```typescript
// tests/unit/services/learningPath.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mock, mockReset } from 'vitest-mock-extended';
import { LearningPathService } from '@/services/learningPath';
import type { IAnalyticsService, IEmailService } from '@/services/interfaces';
import { TEMPLATES } from '@/constants/email';

describe("LearningPathService - Enrollment", () => {
  let mockAnalyticsService: MockProxy<IAnalyticsService>;
  let mockEmailService: MockProxy<IEmailService>;
  let service: LearningPathService;

  beforeEach(() => {
    mockAnalyticsService = mock<IAnalyticsService>();
    mockEmailService = mock<IEmailService>();

    service = new LearningPathService(
      mockAnalyticsService,
      mockEmailService
    );
  });

  it("should track enrollment event with payment method", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const pathId = "path_123" as Id<"learningPaths">;
    const paymentMethod = "bundle";

    // Act
    await service.enrollInPath(userId, pathId, paymentMethod);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Learning Path Enrollment Created",
      expect.objectContaining({
        userId,
        pathId,
        paymentMethod: "bundle",
      })
    );
  });

  it("should send welcome email with path details", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const pathId = "path_123" as Id<"learningPaths">;

    // Act
    await service.enrollInPath(userId, pathId, "bundle");

    // Assert
    expect(mockEmailService.sendTemplate).toHaveBeenCalledWith(
      TEMPLATES.PATH_WELCOME,
      [{ email: expect.any(String), name: expect.any(String) }],
      expect.objectContaining({
        pathId,
        pathTitle: expect.any(String),
        totalCourses: expect.any(Number),
      })
    );
  });

  it("should throw AlreadyEnrolledError if user already enrolled", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const pathId = "path_123" as Id<"learningPaths">;

    // Create existing enrollment
    await service.enrollInPath(userId, pathId, "bundle");

    // Act & Assert
    await expect(
      service.enrollInPath(userId, pathId, "bundle")
    ).rejects.toThrow("User already enrolled in path");
  });

  it("should throw PathUnavailableError if path not active", async () => {
    // Arrange
    const userId = "user_123" as Id<"users">;
    const inactivePathId = "path_inactive" as Id<"learningPaths">;

    // Act & Assert
    await expect(
      service.enrollInPath(userId, inactivePathId, "bundle")
    ).rejects.toThrow("Learning path not available");
  });
});
```

### Scenario 2: Step Unlocking Logic

**Behavior Under Test:** Steps unlock based on unlock rules (immediate, sequential, after_days)

```typescript
// tests/unit/services/learningPath.test.ts
describe("LearningPathService - Step Unlocking", () => {
  it("should unlock immediate steps on enrollment", async () => {
    // Arrange
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;
    const immediateStepId = "step_1" as Id<"learningPathSteps">;

    // Act
    const status = await service.checkStepUnlock(enrollmentId, immediateStepId);

    // Assert
    expect(status.isUnlocked).toBe(true);
    expect(status.reason).toBeUndefined();
  });

  it("should lock sequential step if previous not completed", async () => {
    // Arrange
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;
    const sequentialStepId = "step_2" as Id<"learningPathSteps">;

    // Act
    const status = await service.checkStepUnlock(enrollmentId, sequentialStepId);

    // Assert
    expect(status.isUnlocked).toBe(false);
    expect(status.reason).toBe("locked_sequential");
    expect(status.requiredStepId).toBe("step_1");
  });

  it("should unlock sequential step after previous completed", async () => {
    // Arrange
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;
    const sequentialStepId = "step_2" as Id<"learningPathSteps">;

    // Complete previous step
    await service.unlockNextStep(enrollmentId);

    // Act
    const status = await service.checkStepUnlock(enrollmentId, sequentialStepId);

    // Assert
    expect(status.isUnlocked).toBe(true);
  });

  it("should lock after_days step until days elapsed", async () => {
    // Arrange
    const enrollmentId = "enrollment_new" as Id<"userPathEnrollments">;
    const timedStepId = "step_timed" as Id<"learningPathSteps">;
    // Step unlocks after 7 days

    // Act
    const status = await service.checkStepUnlock(enrollmentId, timedStepId);

    // Assert
    expect(status.isUnlocked).toBe(false);
    expect(status.reason).toBe("locked_after_days");
    expect(status.unlockDate).toBeGreaterThan(Date.now());
  });

  it("should track step unlock event in analytics", async () => {
    // Arrange
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;

    // Act
    await service.unlockNextStep(enrollmentId);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Learning Path Step Unlocked",
      expect.objectContaining({
        enrollmentId,
        stepNumber: expect.any(Number),
      })
    );
  });
});
```

### Scenario 3: Progress Calculation

**Behavior Under Test:** Progress percentage calculated based on required steps only

```typescript
// tests/unit/services/learningPath.test.ts
describe("LearningPathService - Progress Tracking", () => {
  it("should calculate progress based on required steps only", async () => {
    // Arrange
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;
    // Path has 5 total steps, 4 required, 2 completed

    // Act
    const progress = await service.getPathProgress(enrollmentId);

    // Assert
    expect(progress.totalSteps).toBe(5);
    expect(progress.requiredSteps).toBe(4);
    expect(progress.completedSteps).toBe(2);
    expect(progress.progressPercent).toBe(50); // 2/4 = 50%
  });

  it("should mark path complete when all required steps done", async () => {
    // Arrange
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;
    // All 4 required steps completed

    // Act
    const progress = await service.getPathProgress(enrollmentId);

    // Assert
    expect(progress.progressPercent).toBe(100);
    expect(progress.isComplete).toBe(true);
  });

  it("should not mark complete if optional steps incomplete", async () => {
    // Arrange
    const enrollmentId = "enrollment_partial" as Id<"userPathEnrollments">;
    // 4 required complete, 1 optional incomplete

    // Act
    const progress = await service.getPathProgress(enrollmentId);

    // Assert
    expect(progress.progressPercent).toBe(100);
    expect(progress.isComplete).toBe(true); // Optional doesn't block
  });
});
```

### Scenario 4: Certificate Generation

**Behavior Under Test:** Certificate only generated when all required steps complete

```typescript
// tests/unit/services/learningPath.test.ts
describe("LearningPathService - Certificates", () => {
  let mockCertificateService: MockProxy<ICertificateService>;

  beforeEach(() => {
    mockCertificateService = mock<ICertificateService>();
    service = new LearningPathService(
      mockAnalyticsService,
      mockEmailService,
      mockCertificateService
    );
  });

  it("should generate certificate when path complete", async () => {
    // Arrange
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;
    // All required steps complete

    // Act
    const certificateId = await service.generatePathCertificate(enrollmentId);

    // Assert
    expect(certificateId).toBeDefined();
    expect(mockCertificateService.generate).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "path",
        enrollmentId,
      })
    );
  });

  it("should throw PathNotCompleteError if required steps incomplete", async () => {
    // Arrange
    const enrollmentId = "enrollment_partial" as Id<"userPathEnrollments">;
    // Only 2/4 required steps complete

    // Act & Assert
    await expect(
      service.generatePathCertificate(enrollmentId)
    ).rejects.toThrow("Learning path not complete");
  });

  it("should include skills achieved in certificate", async () => {
    // Arrange
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;

    // Act
    await service.generatePathCertificate(enrollmentId);

    // Assert
    expect(mockCertificateService.generate).toHaveBeenCalledWith(
      expect.objectContaining({
        skillsAchieved: expect.arrayContaining([
          { skillId: expect.any(String), level: expect.any(String) }
        ]),
      })
    );
  });

  it("should send certificate email after generation", async () => {
    // Arrange
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;

    // Act
    await service.generatePathCertificate(enrollmentId);

    // Assert
    expect(mockEmailService.sendTemplate).toHaveBeenCalledWith(
      TEMPLATES.PATH_CERTIFICATE,
      expect.any(Array),
      expect.objectContaining({
        certificateId: expect.any(String),
        pathTitle: expect.any(String),
      })
    );
  });

  it("should track certificate generation event", async () => {
    // Arrange
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;

    // Act
    await service.generatePathCertificate(enrollmentId);

    // Assert
    expect(mockAnalyticsService.track).toHaveBeenCalledWith(
      "Learning Path Certificate Generated",
      expect.objectContaining({
        enrollmentId,
        pathId: expect.any(String),
      })
    );
  });
});
```

---

## 6.3.3 Integration Tests for Learning Paths

### Convex Mutation Tests

```typescript
// tests/integration/convex/learningPaths.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import schema from "@/convex/schema";
import { api } from "@/convex/_generated/api";

describe("Learning Path Enrollments", () => {
  test("should create enrollment with immediate step unlocked", async () => {
    // Setup
    const t = convexTest(schema);

    const userId = await t.run(async (ctx) => {
      return await ctx.db.insert("users", {
        name: "Test User",
        email: "test@example.com",
      });
    });

    const pathId = await t.run(async (ctx) => {
      return await ctx.db.insert("learningPaths", {
        title: "Test Path",
        slug: "test-path",
        isActive: true,
        totalCourses: 3,
      });
    });

    const stepId = await t.run(async (ctx) => {
      return await ctx.db.insert("learningPathSteps", {
        pathId,
        courseId: "course_1" as Id<"courses">,
        stepNumber: 1,
        isRequired: true,
        unlockRule: "immediate",
        createdAt: Date.now(),
      });
    });

    // Execute
    const enrollmentId = await t.mutation(api.learningPaths.enrollInPath, {
      userId,
      pathId,
      paymentMethod: "bundle",
    });

    // Assert
    const enrollment = await t.run(async (ctx) => {
      return await ctx.db.get(enrollmentId);
    });

    expect(enrollment).toBeDefined();
    expect(enrollment.userId).toBe(userId);
    expect(enrollment.pathId).toBe(pathId);
    expect(enrollment.status).toBe("active");
    expect(enrollment.progressPercent).toBe(0);
    expect(enrollment.completedSteps).toHaveLength(0);
  });

  test("should prevent duplicate enrollment", async () => {
    // Setup
    const t = convexTest(schema);

    const userId = "user_123" as Id<"users">;
    const pathId = "path_123" as Id<"learningPaths">;

    // First enrollment
    await t.mutation(api.learningPaths.enrollInPath, {
      userId,
      pathId,
      paymentMethod: "bundle",
    });

    // Execute & Assert
    await expect(
      t.mutation(api.learningPaths.enrollInPath, {
        userId,
        pathId,
        paymentMethod: "bundle",
      })
    ).rejects.toThrow("already enrolled");
  });

  test("should update progress when step completed", async () => {
    // Setup
    const t = convexTest(schema);
    const enrollmentId = "enrollment_123" as Id<"userPathEnrollments">;
    const stepId = "step_1" as Id<"learningPathSteps">;

    // Execute
    await t.mutation(api.learningPaths.completeStep, {
      enrollmentId,
      stepId,
    });

    // Assert
    const enrollment = await t.run(async (ctx) => {
      return await ctx.db.get(enrollmentId);
    });

    expect(enrollment.completedSteps).toContain(stepId);
    expect(enrollment.progressPercent).toBeGreaterThan(0);
  });

  test("should generate certificate when all required steps complete", async () => {
    // Setup
    const t = convexTest(schema);
    const enrollmentId = "enrollment_complete" as Id<"userPathEnrollments">;
    // Assume all required steps complete

    // Execute
    const certificateId = await t.mutation(api.learningPaths.generateCertificate, {
      enrollmentId,
    });

    // Assert
    const certificate = await t.run(async (ctx) => {
      return await ctx.db.get(certificateId);
    });

    expect(certificate).toBeDefined();
    expect(certificate.enrollmentId).toBe(enrollmentId);
    expect(certificate.certificateNumber).toMatch(/^PATH-\d{4}-\d{6}$/);
    expect(certificate.issuedAt).toBeLessThanOrEqual(Date.now());
  });
});
```

### API Route Tests

```typescript
// tests/integration/api/learningPaths.test.ts
import { describe, it, expect, beforeAll } from 'vitest';
import { createMocks } from 'node-mocks-http';
import enrollPathHandler from '@/pages/api/learning-paths/enroll';

describe("POST /api/learning-paths/enroll", () => {
  it("should create enrollment and return 201", async () => {
    // Arrange
    const { req, res } = createMocks({
      method: 'POST',
      body: {
        userId: "user_123",
        pathId: "path_123",
        paymentMethod: "bundle",
      },
    });

    // Act
    await enrollPathHandler(req, res);

    // Assert
    expect(res._getStatusCode()).toBe(201);
    const data = JSON.parse(res._getData());
    expect(data.enrollmentId).toBeDefined();
    expect(data.progressPercent).toBe(0);
  });

  it("should return 409 if already enrolled", async () => {
    // Arrange - first enrollment
    const { req: req1, res: res1 } = createMocks({
      method: 'POST',
      body: {
        userId: "user_123",
        pathId: "path_123",
        paymentMethod: "bundle",
      },
    });
    await enrollPathHandler(req1, res1);

    // Arrange - duplicate enrollment
    const { req: req2, res: res2 } = createMocks({
      method: 'POST',
      body: {
        userId: "user_123",
        pathId: "path_123",
        paymentMethod: "bundle",
      },
    });

    // Act
    await enrollPathHandler(req2, res2);

    // Assert
    expect(res2._getStatusCode()).toBe(409);
    const data = JSON.parse(res2._getData());
    expect(data.error).toContain("already enrolled");
  });

  it("should return 400 for invalid payment method", async () => {
    // Arrange
    const { req, res } = createMocks({
      method: 'POST',
      body: {
        userId: "user_123",
        pathId: "path_123",
        paymentMethod: "invalid",
      },
    });

    // Act
    await enrollPathHandler(req, res);

    // Assert
    expect(res._getStatusCode()).toBe(400);
  });
});
```

---

## 6.3.4 E2E Tests for Learning Paths

```typescript
// tests/e2e/learning-path-journey.spec.ts
import { test, expect } from '@playwright/test';

test.describe("Learning Path User Journey", () => {
  test("user can enroll, progress, and earn certificate", async ({ page }) => {
    // Given: User logged in and viewing path
    await page.goto("/learning-paths/ai-leadership");
    await expect(page.locator("h1")).toContainText("AI Leadership Track");

    // When: User clicks enroll
    await page.click("button:has-text('Enroll in Path')");

    // Then: Redirected to checkout
    await expect(page).toHaveURL(/\/checkout/);

    // When: Complete payment (using Stripe test mode)
    await page.fill('input[name="card-number"]', '4242424242424242');
    await page.fill('input[name="expiry"]', '12/34');
    await page.fill('input[name="cvc"]', '123');
    await page.click("button:has-text('Pay')");

    // Then: Redirected to dashboard with enrollment
    await expect(page).toHaveURL(/\/dashboard\/learning-paths/);
    await expect(page.locator("text=AI Leadership Track")).toBeVisible();
    await expect(page.locator("text=Progress: 0%")).toBeVisible();

    // When: Click to start first step
    await page.click("button:has-text('Start Step 1')");

    // Then: First course page loads
    await expect(page).toHaveURL(/\/courses\//);

    // When: Complete first step (mock course completion)
    await page.evaluate(() => {
      window.localStorage.setItem("course_1_complete", "true");
    });
    await page.goto("/dashboard/learning-paths/ai-leadership");

    // Then: Progress updated, next step unlocked
    await expect(page.locator("text=Progress: 20%")).toBeVisible();
    await expect(page.locator("button:has-text('Start Step 2')")).toBeEnabled();

    // When: Complete all required steps (mock)
    await page.evaluate(() => {
      window.localStorage.setItem("path_ai-leadership_complete", "true");
    });
    await page.reload();

    // Then: Certificate available
    await expect(page.locator("text=Progress: 100%")).toBeVisible();
    await expect(page.locator("button:has-text('Claim Certificate')")).toBeVisible();

    // When: Generate certificate
    await page.click("button:has-text('Claim Certificate')");

    // Then: Certificate displays
    await expect(page.locator("h2:has-text('Certificate of Completion')")).toBeVisible();
    await expect(page.locator("text=AI Leadership Track")).toBeVisible();

    // When: Download certificate
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.click("button:has-text('Download PDF')"),
    ]);

    // Then: PDF downloaded
    expect(download.suggestedFilename()).toMatch(/certificate.*\.pdf$/);
  });

  test("sequential steps locked until previous completed", async ({ page }) => {
    // Given: User enrolled in path
    await page.goto("/dashboard/learning-paths/ai-leadership");

    // Then: Step 2 locked
    await expect(page.locator("button:has-text('Start Step 2')")).toBeDisabled();
    await expect(page.locator("text=Complete Step 1 to unlock")).toBeVisible();

    // When: Complete step 1
    await page.click("button:has-text('Start Step 1')");
    // ... complete course
    await page.goto("/dashboard/learning-paths/ai-leadership");

    // Then: Step 2 unlocked
    await expect(page.locator("button:has-text('Start Step 2')")).toBeEnabled();
  });

  test("time-locked steps show unlock date", async ({ page }) => {
    // Given: User just enrolled
    await page.goto("/dashboard/learning-paths/enterprise-ai");

    // Then: Time-locked step shows countdown
    await expect(page.locator("text=Unlocks in 7 days")).toBeVisible();
    await expect(page.locator("button:has-text('Start Step 3')")).toBeDisabled();
  });
});
```

---

## 6.4 Accessibility Testing Strategy

### 6.4.1 Automated Testing (CI Pipeline)

```typescript
// jest.setup.ts - axe-core integration
import { toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

// Example component test
import { axe } from 'jest-axe';
import { render } from '@testing-library/react';

describe('Button accessibility', () => {
  it('should have no accessibility violations', async () => {
    const { container } = render(<Button>Click me</Button>);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('should be keyboard accessible', () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Click me</Button>);
    const button = screen.getByRole('button');
    button.focus();
    fireEvent.keyDown(button, { key: 'Enter' });
    expect(onClick).toHaveBeenCalled();
  });
});
```

### 6.4.2 Testing Checklist Per Component

- [ ] axe-core passes with no violations
- [ ] Keyboard navigation works (Tab, Enter, Escape, Arrow keys)
- [ ] Focus indicator visible
- [ ] ARIA attributes correct
- [ ] Screen reader announcement makes sense

### 6.4.3 E2E Accessibility Tests (Playwright)

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage should pass accessibility audit', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag22aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

### 6.4.4 Manual Testing Protocol

1. **Keyboard-only**: Navigate entire flow without mouse
2. **Screen reader**: Test with NVDA (Windows), VoiceOver (Mac)
3. **Zoom**: Test at 200% and 400% zoom
4. **High contrast**: Test with Windows High Contrast mode
5. **Reduced motion**: Test with prefers-reduced-motion enabled
