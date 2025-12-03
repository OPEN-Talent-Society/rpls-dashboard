# Section 5.5: London School TDD Strategy

## Overview

This document defines the Test-Driven Development strategy for the learning platform using London School principles. London School TDD focuses on **behavior verification** through mocking collaborators, rather than state verification. This approach ensures isolated, fast unit tests that verify how objects interact.

## 5.5.1 Mockable Service Boundaries

### Core Service Interfaces

All external dependencies and cross-service interactions must be defined through explicit interfaces that can be mocked during testing.

#### IEnrollmentService

```typescript
import { Id } from './_generated/dataModel';

export type EnrollmentId = Id<'enrollments'>;
export type UserId = Id<'users'>;
export type CohortId = Id<'cohorts'>;

export interface CreateEnrollmentArgs {
  userId: UserId;
  cohortId: CohortId;
  paymentIntentId: string;
  amount: number;
  currency: string;
  metadata?: Record<string, unknown>;
}

export interface IEnrollmentService {
  /**
   * Create a new enrollment after successful payment
   * @throws EnrollmentAlreadyExistsError if user already enrolled
   * @throws CohortFullError if cohort at capacity
   */
  create(args: CreateEnrollmentArgs): Promise<EnrollmentId>;

  /**
   * Retrieve all enrollments for a user
   */
  getByUserId(userId: UserId): Promise<Enrollment[]>;

  /**
   * Get enrollment by ID
   * @throws EnrollmentNotFoundError if not found
   */
  getById(enrollmentId: EnrollmentId): Promise<Enrollment>;

  /**
   * Process refund and mark enrollment as refunded
   * @throws RefundWindowExpiredError if > 7 days since enrollment
   */
  refund(enrollmentId: EnrollmentId, reason?: string): Promise<void>;

  /**
   * Check if user is enrolled in specific cohort
   */
  isEnrolled(userId: UserId, cohortId: CohortId): Promise<boolean>;

  /**
   * Get enrollment completion percentage
   */
  getProgress(enrollmentId: EnrollmentId): Promise<number>;
}

export interface Enrollment {
  _id: EnrollmentId;
  userId: UserId;
  cohortId: CohortId;
  status: 'active' | 'completed' | 'refunded' | 'suspended';
  paymentIntentId: string;
  enrolledAt: number;
  completedAt?: number;
  refundedAt?: number;
  progress: number; // 0-100
  metadata?: Record<string, unknown>;
}
```

#### IPaymentService (Stripe Integration)

```typescript
export interface CheckoutArgs {
  cohortId: CohortId;
  userId: UserId;
  priceId: string;
  successUrl: string;
  cancelUrl: string;
  metadata?: Record<string, unknown>;
}

export interface SessionUrl {
  url: string;
  sessionId: string;
}

export interface StripeEvent {
  id: string;
  type: string;
  data: {
    object: {
      id: string;
      amount: number;
      currency: string;
      metadata: Record<string, string>;
      payment_intent?: string;
    };
  };
}

export interface IPaymentService {
  /**
   * Create a Stripe Checkout session for enrollment
   */
  createCheckoutSession(args: CheckoutArgs): Promise<SessionUrl>;

  /**
   * Verify webhook signature to prevent spoofing
   * @throws InvalidSignatureError if signature invalid
   */
  verifyWebhookSignature(payload: string, signature: string): StripeEvent;

  /**
   * Process successful payment event
   */
  handlePaymentSuccess(event: StripeEvent): Promise<void>;

  /**
   * Process payment failure event
   */
  handlePaymentFailed(event: StripeEvent): Promise<void>;

  /**
   * Initiate refund through Stripe
   */
  createRefund(paymentIntentId: string, amount?: number): Promise<string>;

  /**
   * Get payment status
   */
  getPaymentStatus(paymentIntentId: string): Promise<'succeeded' | 'pending' | 'failed'>;
}
```

#### IEmailService (Brevo Integration)

```typescript
export type EmailTemplate =
  | 'ENROLLMENT_CONFIRMATION'
  | 'ENROLLMENT_REFUNDED'
  | 'COHORT_STARTING_SOON'
  | 'COHORT_STARTED'
  | 'CERTIFICATE_ISSUED'
  | 'WAITLIST_SPOT_AVAILABLE'
  | 'PASSWORD_RESET'
  | 'WELCOME';

export type MessageId = string;

export interface EmailParams {
  to: string;
  name?: string;
  cohortName?: string;
  cohortStartDate?: string;
  enrollmentId?: string;
  certificateUrl?: string;
  resetToken?: string;
  [key: string]: unknown;
}

export interface Email {
  template: EmailTemplate;
  params: EmailParams;
}

export interface IEmailService {
  /**
   * Send single transactional email
   * @throws EmailDeliveryError if send fails
   */
  send(template: EmailTemplate, params: EmailParams): Promise<MessageId>;

  /**
   * Queue batch of emails for processing
   * Uses Brevo batch API for efficiency
   */
  queueBatch(emails: Email[]): Promise<void>;

  /**
   * Track email delivery status
   */
  getDeliveryStatus(messageId: MessageId): Promise<'delivered' | 'bounced' | 'spam' | 'pending'>;

  /**
   * Update contact attributes in Brevo
   */
  updateContact(email: string, attributes: Record<string, unknown>): Promise<void>;

  /**
   * Add contact to list (e.g., "Active Students")
   */
  addToList(email: string, listId: number): Promise<void>;
}
```

#### IAnalyticsService (PostHog Integration)

```typescript
export interface AnalyticsEvent {
  event: string;
  userId?: UserId;
  properties?: Record<string, unknown>;
  timestamp?: number;
}

export interface IAnalyticsService {
  /**
   * Track user event (enrollment, completion, etc.)
   */
  track(event: AnalyticsEvent): Promise<void>;

  /**
   * Identify user with properties
   */
  identify(userId: UserId, properties: Record<string, unknown>): Promise<void>;

  /**
   * Track feature flag evaluation
   */
  isFeatureEnabled(userId: UserId, flag: string): Promise<boolean>;

  /**
   * Capture A/B test variant
   */
  getExperimentVariant(userId: UserId, experiment: string): Promise<string>;

  /**
   * Flush buffered events (for testing)
   */
  flush(): Promise<void>;
}
```

#### ISurveyService (Formbricks Integration)

```typescript
export interface SurveyResponse {
  surveyId: string;
  userId: UserId;
  responses: Record<string, unknown>;
  completedAt: number;
}

export interface ISurveyService {
  /**
   * Trigger survey for user at specific touchpoint
   */
  triggerSurvey(userId: UserId, surveyId: string): Promise<void>;

  /**
   * Record survey completion
   */
  recordResponse(response: SurveyResponse): Promise<void>;

  /**
   * Check if user has completed survey
   */
  hasCompleted(userId: UserId, surveyId: string): Promise<boolean>;

  /**
   * Get NPS score from survey responses
   */
  calculateNPS(surveyId: string): Promise<number>;
}
```

#### IBookingService (Cal.com Integration)

```typescript
export interface BookingSlot {
  startTime: string; // ISO 8601
  endTime: string;
  available: boolean;
}

export interface CreateBookingArgs {
  userId: UserId;
  eventTypeId: string;
  startTime: string;
  endTime: string;
  timeZone: string;
  metadata?: Record<string, unknown>;
}

export interface IBookingService {
  /**
   * Get available slots for coaching/office hours
   */
  getAvailableSlots(eventTypeId: string, startDate: string, endDate: string): Promise<BookingSlot[]>;

  /**
   * Create booking for user
   */
  createBooking(args: CreateBookingArgs): Promise<string>;

  /**
   * Cancel existing booking
   */
  cancelBooking(bookingId: string, reason?: string): Promise<void>;

  /**
   * Get user's upcoming bookings
   */
  getUserBookings(userId: UserId): Promise<Booking[]>;
}
```

#### IChatService (OpenRouter Integration)

```typescript
export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp?: number;
}

export interface ChatCompletionArgs {
  messages: ChatMessage[];
  model?: string;
  temperature?: number;
  maxTokens?: number;
  userId?: UserId;
}

export interface IChatService {
  /**
   * Get AI chat completion
   */
  complete(args: ChatCompletionArgs): Promise<string>;

  /**
   * Stream chat completion (for real-time UI)
   */
  streamComplete(args: ChatCompletionArgs): AsyncIterableIterator<string>;

  /**
   * Get available models
   */
  getModels(): Promise<string[]>;

  /**
   * Track token usage for billing
   */
  getUsage(userId: UserId, startDate: string, endDate: string): Promise<number>;
}
```

#### IFileService (Convex Storage)

```typescript
export type StorageId = Id<'_storage'>;

export interface UploadFileArgs {
  file: File | Buffer;
  contentType: string;
  metadata?: Record<string, unknown>;
}

export interface IFileService {
  /**
   * Upload file to Convex storage
   */
  upload(args: UploadFileArgs): Promise<StorageId>;

  /**
   * Get file URL (temporary signed URL)
   */
  getUrl(storageId: StorageId): Promise<string>;

  /**
   * Delete file from storage
   */
  delete(storageId: StorageId): Promise<void>;

  /**
   * Get file metadata
   */
  getMetadata(storageId: StorageId): Promise<Record<string, unknown>>;

  /**
   * List files with pagination
   */
  list(cursor?: string, limit?: number): Promise<{ files: StorageId[]; cursor?: string }>;
}
```

#### IWaitlistService

```typescript
export interface WaitlistEntry {
  _id: Id<'waitlist'>;
  email: string;
  cohortId: CohortId;
  position: number;
  joinedAt: number;
  notifiedAt?: number;
  convertedAt?: number;
}

export interface IWaitlistService {
  /**
   * Add user to waitlist for full cohort
   */
  join(email: string, cohortId: CohortId): Promise<WaitlistEntry>;

  /**
   * Get user's position in waitlist
   */
  getPosition(email: string, cohortId: CohortId): Promise<number>;

  /**
   * Notify next N users when spots open
   */
  notifyNext(cohortId: CohortId, count: number): Promise<void>;

  /**
   * Convert waitlist entry to enrollment
   */
  convert(waitlistId: Id<'waitlist'>, enrollmentId: EnrollmentId): Promise<void>;

  /**
   * Remove from waitlist
   */
  remove(waitlistId: Id<'waitlist'>): Promise<void>;
}
```

#### ICertificateService

```typescript
export interface GenerateCertificateArgs {
  enrollmentId: EnrollmentId;
  userId: UserId;
  cohortId: CohortId;
  completedAt: number;
}

export interface Certificate {
  _id: Id<'certificates'>;
  enrollmentId: EnrollmentId;
  userId: UserId;
  cohortId: CohortId;
  certificateNumber: string;
  issuedAt: number;
  pdfUrl: string;
  verificationUrl: string;
}

export interface ICertificateService {
  /**
   * Generate certificate PDF for completed enrollment
   */
  generate(args: GenerateCertificateArgs): Promise<Certificate>;

  /**
   * Get certificate by verification code
   */
  verify(certificateNumber: string): Promise<Certificate | null>;

  /**
   * Get all certificates for user
   */
  getUserCertificates(userId: UserId): Promise<Certificate[]>;

  /**
   * Regenerate certificate (if template updated)
   */
  regenerate(certificateId: Id<'certificates'>): Promise<Certificate>;
}
```

### Service Interface Summary

| Service | Purpose | External Dependency | Critical Operations |
|---------|---------|---------------------|---------------------|
| **IEnrollmentService** | Core enrollment logic | Convex DB | create, refund, getProgress |
| **IPaymentService** | Stripe integration | Stripe API | createCheckoutSession, verifyWebhook, createRefund |
| **IEmailService** | Transactional emails | Brevo API | send, queueBatch, updateContact |
| **IAnalyticsService** | Event tracking | PostHog API | track, identify, isFeatureEnabled |
| **ISurveyService** | User feedback | Formbricks API | triggerSurvey, recordResponse |
| **IBookingService** | Coaching sessions | Cal.com API | getAvailableSlots, createBooking |
| **IChatService** | AI assistance | OpenRouter API | complete, streamComplete |
| **IFileService** | File storage | Convex Storage | upload, getUrl, delete |
| **IWaitlistService** | Waitlist management | Convex DB | join, notifyNext, convert |
| **ICertificateService** | Certificate generation | Convex Storage | generate, verify |

## 5.5.2 Behavior Verification Specs

### Principle: Test What, Not How

London School TDD verifies **interactions** between objects, not internal state. We test:
- **Method calls**: Was the correct method called?
- **Arguments**: Were the correct arguments passed?
- **Order**: Were calls made in the correct sequence?
- **Consequences**: Did the method trigger expected side effects?

### Example: EnrollmentService

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mock, mockDeep } from 'vitest-mock-extended';
import { EnrollmentService } from './enrollmentService';
import type { IPaymentService } from './interfaces/IPaymentService';
import type { IEmailService } from './interfaces/IEmailService';
import type { IAnalyticsService } from './interfaces/IAnalyticsService';

describe('EnrollmentService', () => {
  let enrollmentService: EnrollmentService;
  let mockPayment: ReturnType<typeof mock<IPaymentService>>;
  let mockEmail: ReturnType<typeof mock<IEmailService>>;
  let mockAnalytics: ReturnType<typeof mock<IAnalyticsService>>;

  beforeEach(() => {
    mockPayment = mock<IPaymentService>();
    mockEmail = mock<IEmailService>();
    mockAnalytics = mock<IAnalyticsService>();

    enrollmentService = new EnrollmentService(
      mockPayment,
      mockEmail,
      mockAnalytics
    );
  });

  describe('createFromWebhook', () => {
    const webhookPayload = {
      body: '{"event": "checkout.session.completed"}',
      signature: 'whsec_test123'
    };

    const stripeEvent = {
      id: 'evt_123',
      type: 'checkout.session.completed',
      data: {
        object: {
          id: 'cs_test123',
          amount: 199700,
          currency: 'usd',
          metadata: {
            cohortId: 'cohort_456',
            userId: 'user_789'
          },
          payment_intent: 'pi_test123'
        }
      }
    };

    it('should verify webhook signature before processing', async () => {
      // Arrange
      mockPayment.verifyWebhookSignature.mockReturnValue(stripeEvent);

      // Act
      await enrollmentService.createFromWebhook(webhookPayload);

      // Assert - Behavior verification
      expect(mockPayment.verifyWebhookSignature).toHaveBeenCalledOnce();
      expect(mockPayment.verifyWebhookSignature).toHaveBeenCalledWith(
        webhookPayload.body,
        webhookPayload.signature
      );
    });

    it('should send confirmation email after creating enrollment', async () => {
      // Arrange
      mockPayment.verifyWebhookSignature.mockReturnValue(stripeEvent);

      // Act
      await enrollmentService.createFromWebhook(webhookPayload);

      // Assert - Verify email was sent with correct template and params
      expect(mockEmail.send).toHaveBeenCalledOnce();
      expect(mockEmail.send).toHaveBeenCalledWith(
        'ENROLLMENT_CONFIRMATION',
        expect.objectContaining({
          to: expect.any(String),
          enrollmentId: expect.any(String),
          cohortName: expect.any(String)
        })
      );
    });

    it('should track enrollment event in analytics', async () => {
      // Arrange
      mockPayment.verifyWebhookSignature.mockReturnValue(stripeEvent);

      // Act
      await enrollmentService.createFromWebhook(webhookPayload);

      // Assert - Verify analytics tracking
      expect(mockAnalytics.track).toHaveBeenCalledOnce();
      expect(mockAnalytics.track).toHaveBeenCalledWith(
        expect.objectContaining({
          event: 'enrollment_created',
          userId: stripeEvent.data.object.metadata.userId,
          properties: expect.objectContaining({
            cohortId: stripeEvent.data.object.metadata.cohortId,
            amount: stripeEvent.data.object.amount
          })
        })
      );
    });

    it('should call collaborators in correct order', async () => {
      // Arrange
      mockPayment.verifyWebhookSignature.mockReturnValue(stripeEvent);
      const callOrder: string[] = [];

      mockPayment.verifyWebhookSignature.mockImplementation(() => {
        callOrder.push('verifyWebhook');
        return stripeEvent;
      });

      mockEmail.send.mockImplementation(async () => {
        callOrder.push('sendEmail');
        return 'msg_123';
      });

      mockAnalytics.track.mockImplementation(async () => {
        callOrder.push('trackAnalytics');
      });

      // Act
      await enrollmentService.createFromWebhook(webhookPayload);

      // Assert - Verify correct sequence
      expect(callOrder).toEqual([
        'verifyWebhook',
        'sendEmail',
        'trackAnalytics'
      ]);
    });

    it('should not send email if webhook verification fails', async () => {
      // Arrange
      mockPayment.verifyWebhookSignature.mockImplementation(() => {
        throw new Error('Invalid signature');
      });

      // Act & Assert
      await expect(
        enrollmentService.createFromWebhook(webhookPayload)
      ).rejects.toThrow('Invalid signature');

      expect(mockEmail.send).not.toHaveBeenCalled();
      expect(mockAnalytics.track).not.toHaveBeenCalled();
    });
  });

  describe('refund', () => {
    const enrollmentId = 'enrollment_123' as EnrollmentId;

    it('should create refund through payment service', async () => {
      // Arrange
      const enrollment = {
        _id: enrollmentId,
        userId: 'user_789' as UserId,
        cohortId: 'cohort_456' as CohortId,
        status: 'active' as const,
        paymentIntentId: 'pi_test123',
        enrolledAt: Date.now(),
        progress: 0
      };

      mockPayment.createRefund.mockResolvedValue('re_test123');

      // Act
      await enrollmentService.refund(enrollmentId, 'Student request');

      // Assert
      expect(mockPayment.createRefund).toHaveBeenCalledWith(
        enrollment.paymentIntentId,
        undefined // Full refund
      );
    });

    it('should send refund confirmation email', async () => {
      // Arrange
      mockPayment.createRefund.mockResolvedValue('re_test123');

      // Act
      await enrollmentService.refund(enrollmentId);

      // Assert
      expect(mockEmail.send).toHaveBeenCalledWith(
        'ENROLLMENT_REFUNDED',
        expect.objectContaining({
          enrollmentId: enrollmentId,
          refundAmount: expect.any(Number)
        })
      );
    });

    it('should track refund event', async () => {
      // Arrange
      mockPayment.createRefund.mockResolvedValue('re_test123');

      // Act
      await enrollmentService.refund(enrollmentId, 'Quality issue');

      // Assert
      expect(mockAnalytics.track).toHaveBeenCalledWith(
        expect.objectContaining({
          event: 'enrollment_refunded',
          properties: expect.objectContaining({
            reason: 'Quality issue'
          })
        })
      );
    });
  });
});
```

### Example: PaymentService (Stripe)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mock } from 'vitest-mock-extended';
import { PaymentService } from './paymentService';
import Stripe from 'stripe';

// Mock the Stripe SDK
vi.mock('stripe', () => {
  return {
    default: vi.fn()
  };
});

describe('PaymentService', () => {
  let paymentService: PaymentService;
  let mockStripe: ReturnType<typeof mock<Stripe>>;

  beforeEach(() => {
    mockStripe = mock<Stripe>();
    (Stripe as any).mockImplementation(() => mockStripe);

    paymentService = new PaymentService({
      apiKey: 'sk_test_123',
      webhookSecret: 'whsec_test'
    });
  });

  describe('createCheckoutSession', () => {
    it('should create Stripe session with correct parameters', async () => {
      // Arrange
      const args = {
        cohortId: 'cohort_456' as CohortId,
        userId: 'user_789' as UserId,
        priceId: 'price_1234',
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
        metadata: { source: 'landing_page' }
      };

      mockStripe.checkout.sessions.create.mockResolvedValue({
        id: 'cs_test123',
        url: 'https://checkout.stripe.com/pay/cs_test123'
      } as any);

      // Act
      await paymentService.createCheckoutSession(args);

      // Assert - Verify Stripe API was called correctly
      expect(mockStripe.checkout.sessions.create).toHaveBeenCalledWith(
        expect.objectContaining({
          mode: 'payment',
          line_items: [{ price: args.priceId, quantity: 1 }],
          success_url: args.successUrl,
          cancel_url: args.cancelUrl,
          metadata: expect.objectContaining({
            cohortId: args.cohortId,
            userId: args.userId,
            source: 'landing_page'
          })
        })
      );
    });

    it('should return session URL and ID', async () => {
      // Arrange
      mockStripe.checkout.sessions.create.mockResolvedValue({
        id: 'cs_test123',
        url: 'https://checkout.stripe.com/pay/cs_test123'
      } as any);

      // Act
      const result = await paymentService.createCheckoutSession({
        cohortId: 'cohort_456' as CohortId,
        userId: 'user_789' as UserId,
        priceId: 'price_1234',
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel'
      });

      // Assert
      expect(result).toEqual({
        url: 'https://checkout.stripe.com/pay/cs_test123',
        sessionId: 'cs_test123'
      });
    });
  });

  describe('verifyWebhookSignature', () => {
    it('should call Stripe.webhooks.constructEvent', () => {
      // Arrange
      const payload = '{"event": "test"}';
      const signature = 'whsec_test123';
      const mockEvent = { id: 'evt_123', type: 'test' } as any;

      mockStripe.webhooks.constructEvent.mockReturnValue(mockEvent);

      // Act
      const result = paymentService.verifyWebhookSignature(payload, signature);

      // Assert
      expect(mockStripe.webhooks.constructEvent).toHaveBeenCalledWith(
        payload,
        signature,
        'whsec_test'
      );
      expect(result).toBe(mockEvent);
    });

    it('should throw InvalidSignatureError if verification fails', () => {
      // Arrange
      mockStripe.webhooks.constructEvent.mockImplementation(() => {
        throw new Error('Invalid signature');
      });

      // Act & Assert
      expect(() =>
        paymentService.verifyWebhookSignature('{}', 'bad_signature')
      ).toThrow('Invalid signature');
    });
  });
});
```

### Example: EmailService (Brevo)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mock } from 'vitest-mock-extended';
import { EmailService } from './emailService';
import type { TransactionalEmailsApi } from '@getbrevo/brevo';

vi.mock('@getbrevo/brevo');

describe('EmailService', () => {
  let emailService: EmailService;
  let mockBrevo: ReturnType<typeof mock<TransactionalEmailsApi>>;

  beforeEach(() => {
    mockBrevo = mock<TransactionalEmailsApi>();
    emailService = new EmailService(mockBrevo);
  });

  describe('send', () => {
    it('should send email with correct template ID', async () => {
      // Arrange
      mockBrevo.sendTransacEmail.mockResolvedValue({
        messageId: 'msg_123'
      } as any);

      // Act
      await emailService.send('ENROLLMENT_CONFIRMATION', {
        to: 'student@example.com',
        name: 'John Doe',
        cohortName: 'AI Bootcamp Q1 2025'
      });

      // Assert
      expect(mockBrevo.sendTransacEmail).toHaveBeenCalledWith(
        expect.objectContaining({
          to: [{ email: 'student@example.com', name: 'John Doe' }],
          templateId: expect.any(Number),
          params: expect.objectContaining({
            cohortName: 'AI Bootcamp Q1 2025'
          })
        })
      );
    });

    it('should return message ID', async () => {
      // Arrange
      mockBrevo.sendTransacEmail.mockResolvedValue({
        messageId: 'msg_123'
      } as any);

      // Act
      const messageId = await emailService.send('WELCOME', {
        to: 'test@example.com'
      });

      // Assert
      expect(messageId).toBe('msg_123');
    });

    it('should throw EmailDeliveryError on failure', async () => {
      // Arrange
      mockBrevo.sendTransacEmail.mockRejectedValue(
        new Error('API rate limit exceeded')
      );

      // Act & Assert
      await expect(
        emailService.send('WELCOME', { to: 'test@example.com' })
      ).rejects.toThrow('API rate limit exceeded');
    });
  });

  describe('queueBatch', () => {
    it('should batch multiple emails in single API call', async () => {
      // Arrange
      const emails = [
        {
          template: 'COHORT_STARTING_SOON' as const,
          params: { to: 'student1@example.com', cohortName: 'Q1 2025' }
        },
        {
          template: 'COHORT_STARTING_SOON' as const,
          params: { to: 'student2@example.com', cohortName: 'Q1 2025' }
        }
      ];

      // Act
      await emailService.queueBatch(emails);

      // Assert - Should use batch API
      expect(mockBrevo.sendTransacEmail).toHaveBeenCalledTimes(1);
      expect(mockBrevo.sendTransacEmail).toHaveBeenCalledWith(
        expect.objectContaining({
          messageVersions: expect.arrayContaining([
            expect.objectContaining({ to: [{ email: 'student1@example.com' }] }),
            expect.objectContaining({ to: [{ email: 'student2@example.com' }] })
          ])
        })
      );
    });
  });
});
```

### Behavior Verification Patterns

| Pattern | When to Use | Example |
|---------|-------------|---------|
| **Method Call Verification** | Ensure collaborator was invoked | `expect(mock.method).toHaveBeenCalled()` |
| **Argument Verification** | Verify correct data passed | `expect(mock.method).toHaveBeenCalledWith(expected)` |
| **Call Count Verification** | Ensure method called exactly N times | `expect(mock.method).toHaveBeenCalledTimes(2)` |
| **Sequence Verification** | Verify order of operations | Track calls in array, verify sequence |
| **Negative Verification** | Ensure method NOT called in error cases | `expect(mock.method).not.toHaveBeenCalled()` |
| **Partial Matching** | Verify subset of arguments | `expect.objectContaining({ key: value })` |

## 5.5.3 Test Double Strategy

### Test Double Types

#### 1. Mocks (Primary Strategy)

**Definition**: Objects pre-programmed with expectations about method calls.

**When to Use**:
- Verifying interactions with external services
- Testing side effects (emails sent, events tracked)
- Ensuring correct call order/sequence

**Example**:
```typescript
// Mock for behavior verification
const mockEmail = mock<IEmailService>();
mockEmail.send.mockResolvedValue('msg_123');

// Act
await service.enrollUser(args);

// Verify the behavior
expect(mockEmail.send).toHaveBeenCalledWith('ENROLLMENT_CONFIRMATION', ...);
```

#### 2. Stubs (Supporting Strategy)

**Definition**: Objects that return predefined values, no verification.

**When to Use**:
- Providing data to the system under test
- Simulating different states (error, success)
- Testing conditional logic branches

**Example**:
```typescript
// Stub for returning values
const stubPayment = {
  verifyWebhookSignature: () => ({
    id: 'evt_123',
    type: 'checkout.session.completed',
    data: { /* ... */ }
  })
} as IPaymentService;

// Act - no verification needed, just return value
await service.processWebhook(payload);
```

#### 3. Spies (Advanced Strategy)

**Definition**: Real objects wrapped with call tracking.

**When to Use**:
- Testing real implementations with verification
- Tracking calls without changing behavior
- Integration-style tests

**Example**:
```typescript
import { vi } from 'vitest';

// Spy on real implementation
const realService = new RealEmailService();
const sendSpy = vi.spyOn(realService, 'send');

// Act with real implementation
await service.sendWelcomeEmail(user);

// Verify the spy
expect(sendSpy).toHaveBeenCalledWith('WELCOME', { to: user.email });
```

#### 4. Fakes (Integration Testing)

**Definition**: Working implementations with simplified logic.

**When to Use**:
- Integration tests with real-like behavior
- Testing against in-memory databases
- E2E-style tests without real external services

**Example**:
```typescript
// Fake in-memory email service
class FakeEmailService implements IEmailService {
  private sentEmails: Email[] = [];

  async send(template: EmailTemplate, params: EmailParams): Promise<MessageId> {
    this.sentEmails.push({ template, params });
    return `msg_${this.sentEmails.length}`;
  }

  getSentEmails(): Email[] {
    return this.sentEmails;
  }

  async queueBatch(emails: Email[]): Promise<void> {
    this.sentEmails.push(...emails);
  }

  // ... other methods
}

// Use in tests
const fakeEmail = new FakeEmailService();
const service = new EnrollmentService(payment, fakeEmail, analytics);

await service.enrollUser(args);

// Assert on fake state
expect(fakeEmail.getSentEmails()).toHaveLength(1);
expect(fakeEmail.getSentEmails()[0].template).toBe('ENROLLMENT_CONFIRMATION');
```

### Test Double Selection Matrix

| Scenario | Recommended Double | Rationale |
|----------|-------------------|-----------|
| Verify email sent after enrollment | **Mock** | Need to verify `send()` was called with correct params |
| Return payment webhook data | **Stub** | Just need return value, no verification needed |
| Test real Convex mutation with tracking | **Spy** | Real implementation but track calls |
| Integration test with in-memory DB | **Fake** | Need working implementation without real DB |
| Verify Stripe API call order | **Mock** | Must verify sequence: verify → charge → email |
| Simulate Stripe API error | **Stub** | Return error response for error handling test |
| Test analytics event batching | **Fake** | In-memory queue to verify batch logic |
| Verify refund only called once | **Mock** | Ensure no duplicate refunds |

### Convex-Specific Testing Strategy

Convex mutations/queries require special handling:

```typescript
import { convexTest } from 'convex-test';
import { vi } from 'vitest';
import schema from './schema';
import { api } from './_generated/api';

describe('Enrollment Mutations', () => {
  it('should create enrollment in database', async () => {
    // Use convex-test for real database simulation
    const t = convexTest(schema);

    // Mock external services
    const mockStripe = mock<IPaymentService>();
    const mockEmail = mock<IEmailService>();

    // Inject mocks into Convex context
    await t.run(async (ctx) => {
      // Create enrollment using real Convex mutation
      const enrollmentId = await ctx.run(api.enrollments.create, {
        userId: 'user_123',
        cohortId: 'cohort_456',
        paymentIntentId: 'pi_test'
      });

      // Verify database state (state verification for persistence)
      const enrollment = await ctx.run(api.enrollments.getById, {
        enrollmentId
      });
      expect(enrollment).toBeDefined();
      expect(enrollment.status).toBe('active');

      // Verify external service interactions (behavior verification)
      expect(mockEmail.send).toHaveBeenCalledWith(
        'ENROLLMENT_CONFIRMATION',
        expect.any(Object)
      );
    });
  });
});
```

## 5.5.4 Testing Stack

### Framework: Vitest

**Why Vitest**:
- Fast, Vite-native test runner
- Jest-compatible API (easy migration)
- Native ESM support
- Built-in TypeScript support
- Watch mode with HMR

**Configuration**:

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'convex/_generated/',
        '**/*.test.ts',
        '**/*.spec.ts'
      ]
    },
    mockReset: true,
    restoreMocks: true,
    clearMocks: true
  }
});
```

### Mocking: Vitest + vitest-mock-extended

**Installation**:
```bash
pnpm add -D vitest vitest-mock-extended @vitest/coverage-v8
```

**Mock Creation**:

```typescript
import { mock, mockDeep, mockReset } from 'vitest-mock-extended';

// Simple mock
const mockService = mock<IEmailService>();

// Deep mock (mocks nested properties)
const mockStripe = mockDeep<Stripe>();
mockStripe.checkout.sessions.create.mockResolvedValue({ id: 'cs_test' });

// Reset between tests
beforeEach(() => {
  mockReset(mockService);
});
```

### Component Testing: @testing-library/react

**For React/Next.js components**:

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { EnrollmentButton } from './EnrollmentButton';

describe('EnrollmentButton', () => {
  it('should call onEnroll when clicked', async () => {
    const onEnroll = vi.fn();
    render(<EnrollmentButton cohortId="cohort_123" onEnroll={onEnroll} />);

    const button = screen.getByRole('button', { name: /enroll now/i });
    await userEvent.click(button);

    expect(onEnroll).toHaveBeenCalledWith('cohort_123');
  });

  it('should disable button while loading', async () => {
    render(<EnrollmentButton cohortId="cohort_123" isLoading />);

    const button = screen.getByRole('button');
    expect(button).toBeDisabled();
  });
});
```

### E2E Testing: Playwright

**For critical user journeys**:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Enrollment Flow', () => {
  test('should complete full enrollment journey', async ({ page }) => {
    // Navigate to cohort page
    await page.goto('/cohorts/ai-bootcamp-q1-2025');

    // Click enroll button
    await page.getByRole('button', { name: /enroll now/i }).click();

    // Fill Stripe checkout (using test mode)
    await page.waitForURL(/checkout.stripe.com/);
    await page.fill('[name="cardNumber"]', '4242424242424242');
    await page.fill('[name="cardExpiry"]', '12/25');
    await page.fill('[name="cardCvc"]', '123');
    await page.fill('[name="billingName"]', 'Test User');

    // Submit payment
    await page.getByRole('button', { name: /pay/i }).click();

    // Verify success page
    await page.waitForURL(/\/enrollment\/success/);
    await expect(page.getByText(/enrollment confirmed/i)).toBeVisible();

    // Verify confirmation email sent (check test inbox)
    // Note: In real tests, would check email test service
  });
});
```

### Convex Testing: convex-test

**For Convex mutations/queries with mocked externals**:

```typescript
import { convexTest } from 'convex-test';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import schema from '../convex/schema';
import { api } from '../convex/_generated/api';

// Mock external services
vi.mock('../convex/lib/stripe', () => ({
  stripeClient: {
    checkout: {
      sessions: {
        create: vi.fn().mockResolvedValue({ url: 'https://checkout.stripe.com/test' })
      }
    }
  }
}));

describe('Enrollment Mutations', () => {
  const t = convexTest(schema);

  beforeEach(async () => {
    // Clear database between tests
    await t.run(async (ctx) => {
      // Use Convex testing utilities to reset state
    });
  });

  it('should create enrollment with valid payment', async () => {
    await t.run(async (ctx) => {
      // Create test user
      const userId = await ctx.run(api.users.create, {
        email: 'test@example.com',
        name: 'Test User'
      });

      // Create enrollment
      const enrollmentId = await ctx.run(api.enrollments.createFromWebhook, {
        userId,
        cohortId: 'cohort_123',
        paymentIntentId: 'pi_test123',
        amount: 199700,
        currency: 'usd'
      });

      // Verify enrollment created
      const enrollment = await ctx.run(api.enrollments.getById, { enrollmentId });
      expect(enrollment.status).toBe('active');
      expect(enrollment.userId).toBe(userId);
    });
  });

  it('should reject duplicate enrollments', async () => {
    await t.run(async (ctx) => {
      const userId = await ctx.run(api.users.create, {
        email: 'test@example.com',
        name: 'Test User'
      });

      // First enrollment should succeed
      await ctx.run(api.enrollments.create, {
        userId,
        cohortId: 'cohort_123',
        paymentIntentId: 'pi_test123'
      });

      // Second enrollment should fail
      await expect(
        ctx.run(api.enrollments.create, {
          userId,
          cohortId: 'cohort_123',
          paymentIntentId: 'pi_test456'
        })
      ).rejects.toThrow('User already enrolled');
    });
  });
});
```

### Testing Stack Summary

| Layer | Tool | Purpose | Test Type |
|-------|------|---------|-----------|
| **Unit Tests** | Vitest + vitest-mock-extended | Service logic with mocks | Fast, isolated |
| **Integration Tests** | Vitest + convex-test | Services + Convex DB | Medium speed |
| **Component Tests** | @testing-library/react | React components | Fast, isolated |
| **E2E Tests** | Playwright | Full user journeys | Slow, comprehensive |
| **API Tests** | Vitest + MSW | HTTP API mocking | Fast, network isolated |

## 5.5.5 Test Categories

### Unit Tests: Service Logic with Mocked Collaborators

**Scope**: Single service class, all dependencies mocked.

**Speed**: Very fast (< 10ms per test)

**Example Structure**:
```
src/
  services/
    enrollmentService.ts
    enrollmentService.test.ts      ← Unit tests
    paymentService.ts
    paymentService.test.ts         ← Unit tests
    emailService.ts
    emailService.test.ts           ← Unit tests
```

**Characteristics**:
- All external dependencies mocked (Stripe, Brevo, PostHog, etc.)
- No database calls (Convex mocked)
- No network requests
- Focus on business logic and interaction patterns
- 100% code coverage goal

**Example Test**:
```typescript
// enrollmentService.test.ts
describe('EnrollmentService (Unit)', () => {
  let service: EnrollmentService;
  let mockPayment: IPaymentService;
  let mockEmail: IEmailService;
  let mockConvex: ConvexClient;

  beforeEach(() => {
    mockPayment = mock<IPaymentService>();
    mockEmail = mock<IEmailService>();
    mockConvex = mock<ConvexClient>();

    service = new EnrollmentService(mockPayment, mockEmail, mockConvex);
  });

  it('should create enrollment after payment verification', async () => {
    // Arrange
    mockPayment.verifyWebhookSignature.mockReturnValue(validEvent);
    mockConvex.mutation.mockResolvedValue('enrollment_123');

    // Act
    const result = await service.createFromWebhook(webhookPayload);

    // Assert
    expect(mockPayment.verifyWebhookSignature).toHaveBeenCalled();
    expect(mockConvex.mutation).toHaveBeenCalledWith(
      api.enrollments.create,
      expect.any(Object)
    );
    expect(mockEmail.send).toHaveBeenCalled();
  });
});
```

### Integration Tests: Service + Convex (Real Mutations)

**Scope**: Service layer + Convex database, external APIs mocked.

**Speed**: Medium (50-200ms per test)

**Example Structure**:
```
test/
  integration/
    enrollment-flow.test.ts        ← Integration tests
    payment-webhook.test.ts        ← Integration tests
    waitlist-conversion.test.ts    ← Integration tests
```

**Characteristics**:
- Real Convex mutations/queries (using convex-test)
- External APIs still mocked (Stripe, Brevo, etc.)
- Database state verified
- Tests realistic data flows
- Fewer tests than unit tests (critical paths only)

**Example Test**:
```typescript
// test/integration/enrollment-flow.test.ts
import { convexTest } from 'convex-test';
import schema from '../../convex/schema';

describe('Enrollment Flow (Integration)', () => {
  const t = convexTest(schema);

  it('should complete enrollment from webhook to confirmation', async () => {
    await t.run(async (ctx) => {
      // Step 1: Create user
      const userId = await ctx.run(api.users.create, {
        email: 'student@example.com',
        name: 'Test Student'
      });

      // Step 2: Create cohort
      const cohortId = await ctx.run(api.cohorts.create, {
        name: 'AI Bootcamp Q1 2025',
        startDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
        capacity: 20
      });

      // Step 3: Simulate Stripe webhook
      const enrollmentId = await ctx.run(api.enrollments.createFromWebhook, {
        userId,
        cohortId,
        paymentIntentId: 'pi_integration_test',
        amount: 199700,
        currency: 'usd'
      });

      // Verify: Enrollment created
      const enrollment = await ctx.run(api.enrollments.getById, { enrollmentId });
      expect(enrollment.status).toBe('active');

      // Verify: User's enrollments updated
      const userEnrollments = await ctx.run(api.enrollments.getByUserId, { userId });
      expect(userEnrollments).toHaveLength(1);

      // Verify: Cohort capacity decremented
      const cohort = await ctx.run(api.cohorts.getById, { cohortId });
      expect(cohort.enrolledCount).toBe(1);
    });
  });

  it('should handle concurrent enrollments for same cohort', async () => {
    await t.run(async (ctx) => {
      // Create cohort with capacity 2
      const cohortId = await ctx.run(api.cohorts.create, {
        name: 'Limited Cohort',
        capacity: 2
      });

      // Create 3 users trying to enroll simultaneously
      const enrollmentPromises = [
        ctx.run(api.enrollments.create, {
          userId: 'user_1',
          cohortId,
          paymentIntentId: 'pi_1'
        }),
        ctx.run(api.enrollments.create, {
          userId: 'user_2',
          cohortId,
          paymentIntentId: 'pi_2'
        }),
        ctx.run(api.enrollments.create, {
          userId: 'user_3',
          cohortId,
          paymentIntentId: 'pi_3'
        })
      ];

      // One should fail due to capacity
      const results = await Promise.allSettled(enrollmentPromises);
      const successful = results.filter(r => r.status === 'fulfilled');
      const failed = results.filter(r => r.status === 'rejected');

      expect(successful).toHaveLength(2);
      expect(failed).toHaveLength(1);
      expect(failed[0].reason.message).toContain('Cohort full');
    });
  });
});
```

### E2E Tests: Full User Journeys (Playwright)

**Scope**: Complete flows from UI → Backend → External APIs → Database.

**Speed**: Slow (1-10 seconds per test)

**Example Structure**:
```
e2e/
  enrollment.spec.ts               ← E2E enrollment flow
  refund.spec.ts                   ← E2E refund flow
  waitlist.spec.ts                 ← E2E waitlist flow
```

**Characteristics**:
- Real browser interactions (Playwright)
- Real Stripe checkout (test mode)
- Real email delivery (test inbox)
- Real database state changes
- Minimal tests (smoke tests only)
- Run in CI/CD before deployment

**Example Test**:
```typescript
// e2e/enrollment.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Enrollment E2E', () => {
  test('complete enrollment from landing page to dashboard', async ({ page }) => {
    // Step 1: Browse cohorts
    await page.goto('/cohorts');
    await expect(page.getByText('AI Bootcamp Q1 2025')).toBeVisible();

    // Step 2: View cohort details
    await page.getByText('AI Bootcamp Q1 2025').click();
    await expect(page.getByRole('heading', { name: /ai bootcamp/i })).toBeVisible();

    // Step 3: Click enroll button
    await page.getByRole('button', { name: /enroll now/i }).click();

    // Step 4: Redirected to Stripe Checkout
    await page.waitForURL(/checkout.stripe.com/);
    await expect(page.getByText(/payment details/i)).toBeVisible();

    // Step 5: Fill payment details (Stripe test card)
    await page.fill('[name="cardNumber"]', '4242424242424242');
    await page.fill('[name="cardExpiry"]', '12/30');
    await page.fill('[name="cardCvc"]', '123');
    await page.fill('[name="billingName"]', 'E2E Test User');
    await page.fill('[name="email"]', 'e2e-test@example.com');

    // Step 6: Submit payment
    await page.getByRole('button', { name: /pay/i }).click();

    // Step 7: Redirected to success page
    await page.waitForURL(/\/dashboard\/enrollments/);
    await expect(page.getByText(/enrollment confirmed/i)).toBeVisible();

    // Step 8: Verify enrollment appears in dashboard
    await expect(page.getByText('AI Bootcamp Q1 2025')).toBeVisible();
    await expect(page.getByText(/enrolled/i)).toBeVisible();

    // Step 9: Verify email sent (would check test inbox in real scenario)
    // For demo, we trust the email service mock was configured correctly
  });

  test('handle enrollment failure gracefully', async ({ page }) => {
    await page.goto('/cohorts/ai-bootcamp-q1-2025');
    await page.getByRole('button', { name: /enroll now/i }).click();

    // Use Stripe test card that fails
    await page.waitForURL(/checkout.stripe.com/);
    await page.fill('[name="cardNumber"]', '4000000000000002'); // Declined card
    await page.fill('[name="cardExpiry"]', '12/30');
    await page.fill('[name="cardCvc"]', '123');
    await page.fill('[name="billingName"]', 'Failed Payment Test');

    await page.getByRole('button', { name: /pay/i }).click();

    // Should show error message
    await expect(page.getByText(/payment failed/i)).toBeVisible();
    await expect(page.getByText(/card was declined/i)).toBeVisible();
  });
});
```

### Test Category Decision Matrix

| Question | Unit | Integration | E2E |
|----------|------|-------------|-----|
| Testing a single service method? | ✅ | ❌ | ❌ |
| Testing interaction between service and database? | ❌ | ✅ | ❌ |
| Testing multi-step user flow? | ❌ | ❌ | ✅ |
| Need to verify external API calls? | ✅ (mock) | ✅ (mock) | ✅ (real/test mode) |
| Testing UI components? | ❌ | ❌ | ✅ |
| Testing race conditions? | ❌ | ✅ | ❌ |
| Need fast feedback (< 1s)? | ✅ | ⚠️ | ❌ |
| Testing browser behavior? | ❌ | ❌ | ✅ |

### Test Pyramid (Recommended Distribution)

```
        /\
       /  \  E2E Tests
      /____\  (~10 tests - critical paths only)
     /      \
    / Integ  \ Integration Tests
   /   Tests  \ (~50 tests - key flows)
  /____________\
 /              \
/   Unit Tests   \ Unit Tests
/________________\ (~500+ tests - comprehensive coverage)
```

**Ratios**:
- **Unit Tests**: 70% of tests (fast, comprehensive)
- **Integration Tests**: 20% of tests (realistic flows)
- **E2E Tests**: 10% of tests (smoke tests)

### Test Naming Convention

```typescript
// Unit tests
describe('EnrollmentService', () => {
  describe('create', () => {
    it('should verify payment before creating enrollment', ...)
    it('should send confirmation email after enrollment', ...)
    it('should track enrollment event in analytics', ...)
    it('should throw CohortFullError if capacity reached', ...)
  });
});

// Integration tests
describe('Enrollment Flow [Integration]', () => {
  it('should create enrollment and update cohort capacity', ...)
  it('should handle concurrent enrollments correctly', ...)
});

// E2E tests
describe('Enrollment Journey [E2E]', () => {
  test('complete enrollment from landing to dashboard', ...)
  test('handle payment failure gracefully', ...)
});
```

## Conclusion

This London School TDD strategy ensures:

1. **Fast Tests**: Unit tests with mocked dependencies run in milliseconds
2. **Reliable Tests**: Behavior verification catches integration issues
3. **Maintainable Tests**: Clear service boundaries make refactoring safe
4. **Comprehensive Coverage**: Test pyramid provides confidence at all levels
5. **Production Ready**: E2E tests verify critical user journeys

All services follow explicit interfaces (`IEnrollmentService`, `IPaymentService`, etc.) that can be mocked, enabling true isolated unit testing while integration and E2E tests verify real-world behavior.
