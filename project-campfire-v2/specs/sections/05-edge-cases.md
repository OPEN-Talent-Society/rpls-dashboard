# 5. Edge Cases and Error Handling

## 5.1 Atomic Capacity Validation (Race Condition Fix)

### Problem
Multiple users simultaneously completing checkout for the last available seat creates a race condition where enrollment count can exceed capacity.

### Solution
Implement atomic capacity checking within the Stripe webhook handler using optimistic concurrency control.

```typescript
// convex/stripe/webhooks.ts
import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalMutation } from "../_generated/server";

export const handleCheckoutCompleted = internalMutation({
  args: {
    sessionId: v.string(),
    metadata: v.object({
      userId: v.id("users"),
      cohortId: v.id("cohorts"),
      paymentIntentId: v.string(),
      enrollmentType: v.string(),
    }),
  },
  handler: async (ctx, { sessionId, metadata }) => {
    // 1. Get cohort with fresh data (inside transaction)
    const cohort = await ctx.db.get(metadata.cohortId);

    if (!cohort) {
      throw new Error(`Cohort ${metadata.cohortId} not found`);
    }

    // 2. ATOMIC capacity check
    if (cohort.currentEnrollment >= cohort.maxCapacity) {
      console.warn(
        `Capacity exceeded for cohort ${metadata.cohortId}. ` +
        `Current: ${cohort.currentEnrollment}, Max: ${cohort.maxCapacity}`
      );

      // 3. Trigger refund asynchronously
      await ctx.scheduler.runAfter(0, internal.stripe.refundPayment, {
        paymentIntentId: metadata.paymentIntentId,
        reason: "capacity_exceeded",
        sessionId,
      });

      // 4. Add user to waitlist
      const waitlistPosition = await getNextWaitlistPosition(ctx, metadata.cohortId);

      await ctx.db.insert("waitlist", {
        userId: metadata.userId,
        cohortId: metadata.cohortId,
        position: waitlistPosition,
        status: "waiting",
        addedAt: Date.now(),
        notificationSent: false,
      });

      // 5. Send capacity exceeded notification
      await ctx.scheduler.runAfter(0, internal.emails.sendCapacityExceededEmail, {
        userId: metadata.userId,
        cohortId: metadata.cohortId,
        waitlistPosition,
      });

      return {
        success: false,
        reason: "capacity_exceeded",
        waitlistPosition,
      };
    }

    // 6. Check for duplicate enrollment (idempotency)
    const existingEnrollment = await ctx.db
      .query("enrollments")
      .withIndex("by_user_cohort", (q) =>
        q.eq("userId", metadata.userId).eq("cohortId", metadata.cohortId)
      )
      .first();

    if (existingEnrollment) {
      console.log(`Enrollment already exists for user ${metadata.userId} in cohort ${metadata.cohortId}`);
      return {
        success: true,
        reason: "already_enrolled",
        enrollmentId: existingEnrollment._id,
      };
    }

    // 7. Create enrollment atomically
    const now = Date.now();
    const enrollmentId = await ctx.db.insert("enrollments", {
      userId: metadata.userId,
      cohortId: metadata.cohortId,
      status: "active",
      enrollmentType: metadata.enrollmentType as "b2c" | "b2b",
      stripeCheckoutSessionId: sessionId,
      stripePaymentIntentId: metadata.paymentIntentId,
      enrolledAt: now,

      // Access periods (from cohort settings)
      workshopAccessUntil: cohort.workshopDate + (cohort.workshopAccessDays * 24 * 60 * 60 * 1000),
      chatbotAccessUntil: cohort.workshopDate + (cohort.chatbotAccessDays * 24 * 60 * 60 * 1000),
      officeHoursAccessUntil: cohort.workshopDate + (cohort.officeHoursAccessDays * 24 * 60 * 60 * 1000),

      // B2B fields (if applicable)
      organizationId: metadata.enrollmentType === "b2b" ? cohort.organizationId : undefined,
    });

    // 8. Increment enrollment count atomically
    await ctx.db.patch(metadata.cohortId, {
      currentEnrollment: cohort.currentEnrollment + 1,
    });

    // 9. Send confirmation email
    await ctx.scheduler.runAfter(0, internal.emails.sendEnrollmentConfirmation, {
      userId: metadata.userId,
      cohortId: metadata.cohortId,
      enrollmentId,
    });

    // 10. Track enrollment event
    await ctx.scheduler.runAfter(0, internal.analytics.trackEnrollment, {
      userId: metadata.userId,
      cohortId: metadata.cohortId,
      enrollmentType: metadata.enrollmentType,
    });

    return {
      success: true,
      enrollmentId,
    };
  },
});

// Helper function to get next waitlist position
async function getNextWaitlistPosition(
  ctx: { db: any },
  cohortId: string
): Promise<number> {
  const waitlist = await ctx.db
    .query("waitlist")
    .withIndex("by_cohort", (q) => q.eq("cohortId", cohortId))
    .collect();

  return waitlist.length + 1;
}
```

### Key Safeguards
1. **Transactional consistency**: All checks and updates happen in single mutation
2. **Idempotency**: Check for existing enrollment before creating new one
3. **Automatic recovery**: Refund + waitlist on capacity exceeded
4. **User notification**: Clear communication about status change
5. **Audit trail**: Log all capacity-related events

## 5.2 Webhook Retry Strategy

### Stripe Webhook Reliability
Implement exponential backoff with dead letter queue for failed webhook processing.

```typescript
// convex/stripe/webhookProcessor.ts
import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalMutation, internalAction } from "../_generated/server";

export const processWebhook = internalAction({
  args: {
    event: v.any(),
    attemptNumber: v.optional(v.number()),
  },
  handler: async (ctx, { event, attemptNumber = 1 }) => {
    const MAX_RETRIES = 3;
    const RETRY_DELAYS = [1000, 10000, 100000]; // 1s, 10s, 100s

    try {
      // Process webhook based on event type
      switch (event.type) {
        case "checkout.session.completed":
          await ctx.runMutation(internal.stripe.webhooks.handleCheckoutCompleted, {
            sessionId: event.data.object.id,
            metadata: event.data.object.metadata,
          });
          break;

        case "customer.subscription.updated":
          await ctx.runMutation(internal.stripe.webhooks.handleSubscriptionUpdated, {
            subscriptionId: event.data.object.id,
          });
          break;

        case "charge.refunded":
          await ctx.runMutation(internal.stripe.webhooks.handleRefund, {
            chargeId: event.data.object.id,
          });
          break;

        default:
          console.log(`Unhandled webhook event type: ${event.type}`);
      }

      // Log successful processing
      await ctx.runMutation(internal.webhooks.logWebhookSuccess, {
        eventId: event.id,
        eventType: event.type,
        attemptNumber,
      });

    } catch (error) {
      console.error(`Webhook processing failed (attempt ${attemptNumber}/${MAX_RETRIES}):`, error);

      // Log failure
      await ctx.runMutation(internal.webhooks.logWebhookFailure, {
        eventId: event.id,
        eventType: event.type,
        attemptNumber,
        error: error.message,
      });

      // Retry with exponential backoff
      if (attemptNumber < MAX_RETRIES) {
        const delay = RETRY_DELAYS[attemptNumber - 1];

        await ctx.scheduler.runAfter(
          delay,
          internal.stripe.webhookProcessor.processWebhook,
          {
            event,
            attemptNumber: attemptNumber + 1,
          }
        );

        console.log(`Scheduled retry ${attemptNumber + 1} after ${delay}ms`);
      } else {
        // Max retries exceeded - send to Dead Letter Queue
        await ctx.runMutation(internal.webhooks.sendToDeadLetterQueue, {
          eventId: event.id,
          eventType: event.type,
          event,
          error: error.message,
          attempts: MAX_RETRIES,
        });

        // Notify admin
        await ctx.runAction(internal.alerts.notifyWebhookFailure, {
          eventId: event.id,
          eventType: event.type,
          error: error.message,
        });
      }
    }
  },
});

// Dead Letter Queue management
export const sendToDeadLetterQueue = internalMutation({
  args: {
    eventId: v.string(),
    eventType: v.string(),
    event: v.any(),
    error: v.string(),
    attempts: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("webhookDeadLetterQueue", {
      eventId: args.eventId,
      eventType: args.eventType,
      eventData: args.event,
      error: args.error,
      attempts: args.attempts,
      addedAt: Date.now(),
      status: "pending_review",
      retryable: true,
    });
  },
});

// Manual retry interface for admins
export const retryFromDeadLetterQueue = internalAction({
  args: {
    dlqId: v.id("webhookDeadLetterQueue"),
  },
  handler: async (ctx, { dlqId }) => {
    const dlqEntry = await ctx.runQuery(internal.webhooks.getDLQEntry, { dlqId });

    if (!dlqEntry) {
      throw new Error(`DLQ entry ${dlqId} not found`);
    }

    // Attempt reprocessing
    await ctx.runAction(internal.stripe.webhookProcessor.processWebhook, {
      event: dlqEntry.eventData,
      attemptNumber: 1, // Reset attempt count for manual retry
    });

    // Update DLQ status
    await ctx.runMutation(internal.webhooks.updateDLQStatus, {
      dlqId,
      status: "manually_retried",
    });
  },
});
```

### Retry Configuration Summary
| Attempt | Delay | Total Time Elapsed |
|---------|-------|-------------------|
| 1 | Immediate | 0s |
| 2 | 1s | 1s |
| 3 | 10s | 11s |
| 4 (DLQ) | - | 111s |

### Admin Interface
- View all DLQ entries in dashboard
- Filter by event type, date, status
- Manual retry with one click
- View error details and event payload
- Bulk retry for common failures

## 5.3 Access Expiry Grace Period

### Graceful Degradation for In-Progress Content
Users completing workshop content near expiry should have a 24-hour grace period.

```typescript
// convex/access/validation.ts
import { query } from "../_generated/server";
import { v } from "convex/values";

const GRACE_PERIOD_MS = 24 * 60 * 60 * 1000; // 24 hours

export const checkAccess = query({
  args: {
    userId: v.id("users"),
    cohortId: v.id("cohorts"),
    accessType: v.union(
      v.literal("workshop"),
      v.literal("chatbot"),
      v.literal("officeHours")
    ),
  },
  handler: async (ctx, { userId, cohortId, accessType }) => {
    const enrollment = await ctx.db
      .query("enrollments")
      .withIndex("by_user_cohort", (q) =>
        q.eq("userId", userId).eq("cohortId", cohortId)
      )
      .first();

    if (!enrollment) {
      return {
        hasAccess: false,
        reason: "not_enrolled",
      };
    }

    // Map access type to expiry field
    const expiryFieldMap = {
      workshop: "workshopAccessUntil",
      chatbot: "chatbotAccessUntil",
      officeHours: "officeHoursAccessUntil",
    };

    const expiryField = expiryFieldMap[accessType];
    const expiryTimestamp = enrollment[expiryField];
    const now = Date.now();

    // Check if within normal access period
    if (now < expiryTimestamp) {
      return {
        hasAccess: true,
        reason: "active",
        expiresAt: expiryTimestamp,
        isGracePeriod: false,
      };
    }

    // Check if within grace period
    const gracePeriodEnd = expiryTimestamp + GRACE_PERIOD_MS;

    if (now < gracePeriodEnd) {
      return {
        hasAccess: true,
        reason: "grace_period",
        expiresAt: gracePeriodEnd,
        isGracePeriod: true,
        originalExpiry: expiryTimestamp,
        gracePeriodEndsIn: gracePeriodEnd - now,
      };
    }

    // Access expired (past grace period)
    return {
      hasAccess: false,
      reason: "expired",
      expiredAt: expiryTimestamp,
      gracePeriodEndedAt: gracePeriodEnd,
    };
  },
});

// UI component helper
export const getAccessStatus = query({
  args: {
    userId: v.id("users"),
    cohortId: v.id("cohorts"),
  },
  handler: async (ctx, { userId, cohortId }) => {
    const workshop = await ctx.db.query(internal.access.checkAccess, {
      userId,
      cohortId,
      accessType: "workshop",
    });

    const chatbot = await ctx.db.query(internal.access.checkAccess, {
      userId,
      cohortId,
      accessType: "chatbot",
    });

    const officeHours = await ctx.db.query(internal.access.checkAccess, {
      userId,
      cohortId,
      accessType: "officeHours",
    });

    return {
      workshop,
      chatbot,
      officeHours,
    };
  },
});
```

### Grace Period UI Indicators
```typescript
// app/components/AccessBanner.tsx
export function AccessBanner({ accessStatus }) {
  if (accessStatus.isGracePeriod) {
    const hoursRemaining = Math.floor(accessStatus.gracePeriodEndsIn / (60 * 60 * 1000));

    return (
      <div className="bg-amber-50 border-l-4 border-amber-400 p-4">
        <div className="flex">
          <div className="flex-shrink-0">
            <AlertTriangle className="h-5 w-5 text-amber-400" />
          </div>
          <div className="ml-3">
            <p className="text-sm text-amber-700">
              Your access has expired, but you have <strong>{hoursRemaining} hours</strong> remaining
              in your grace period to complete this content.
            </p>
            <p className="text-xs text-amber-600 mt-1">
              After the grace period ends, you'll need to re-enroll to continue.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return null;
}
```

## 5.4 B2B Account Merging

### Scenario: Existing B2C User Accepts B2B Invite
Handle the case where a user with existing individual enrollments accepts a B2B organization invite.

```typescript
// convex/organizations/invites.ts
import { v } from "convex/values";
import { mutation } from "../_generated/server";

export const acceptInvite = mutation({
  args: {
    inviteToken: v.string(),
  },
  handler: async (ctx, { inviteToken }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .first();

    if (!user) throw new Error("User not found");

    // 1. Get and validate invite
    const invite = await ctx.db
      .query("organizationInvites")
      .withIndex("by_token", (q) => q.eq("token", inviteToken))
      .first();

    if (!invite) {
      throw new Error("Invite not found");
    }

    if (invite.status !== "pending") {
      throw new Error("Invite already used or expired");
    }

    if (invite.expiresAt < Date.now()) {
      throw new Error("Invite expired");
    }

    // 2. Check for organization conflict
    if (user.organizationId && user.organizationId !== invite.organizationId) {
      throw new Error(
        "You are already a member of a different organization. " +
        "Please contact support to resolve this conflict."
      );
    }

    // 3. Get existing enrollments
    const existingEnrollments = await ctx.db
      .query("enrollments")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();

    // 4. Update user with organization
    await ctx.db.patch(user._id, {
      organizationId: invite.organizationId,
      organizationRole: "member",
      organizationJoinedAt: Date.now(),
    });

    // 5. Migrate existing B2C enrollments to B2B
    const migrationResults = [];

    for (const enrollment of existingEnrollments) {
      if (enrollment.enrollmentType === "b2c") {
        // Check if cohort belongs to same organization
        const cohort = await ctx.db.get(enrollment.cohortId);

        if (cohort?.organizationId === invite.organizationId) {
          // Migrate to B2B enrollment
          await ctx.db.patch(enrollment._id, {
            enrollmentType: "b2b",
            organizationId: invite.organizationId,
            migratedFromB2C: true,
            migrationDate: Date.now(),
          });

          migrationResults.push({
            enrollmentId: enrollment._id,
            cohortId: enrollment.cohortId,
            migrated: true,
          });
        } else {
          // Keep as B2C (different org or public cohort)
          migrationResults.push({
            enrollmentId: enrollment._id,
            cohortId: enrollment.cohortId,
            migrated: false,
            reason: "different_organization",
          });
        }
      }
    }

    // 6. Mark invite as accepted
    await ctx.db.patch(invite._id, {
      status: "accepted",
      acceptedAt: Date.now(),
      acceptedBy: user._id,
    });

    // 7. Create organization member record
    await ctx.db.insert("organizationMembers", {
      organizationId: invite.organizationId,
      userId: user._id,
      role: "member",
      joinedAt: Date.now(),
      inviteId: invite._id,
    });

    // 8. Send welcome email
    await ctx.scheduler.runAfter(0, internal.emails.sendB2BWelcome, {
      userId: user._id,
      organizationId: invite.organizationId,
    });

    return {
      success: true,
      organizationId: invite.organizationId,
      migratedEnrollments: migrationResults.filter((r) => r.migrated).length,
      totalEnrollments: existingEnrollments.length,
      migrationDetails: migrationResults,
    };
  },
});

// Handle organization conflict resolution
export const requestOrganizationTransfer = mutation({
  args: {
    targetOrganizationId: v.id("organizations"),
    reason: v.string(),
  },
  handler: async (ctx, { targetOrganizationId, reason }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .first();

    if (!user) throw new Error("User not found");

    if (!user.organizationId) {
      throw new Error("You are not currently in an organization");
    }

    // Create transfer request for admin review
    await ctx.db.insert("organizationTransferRequests", {
      userId: user._id,
      currentOrganizationId: user.organizationId,
      targetOrganizationId,
      reason,
      status: "pending",
      requestedAt: Date.now(),
    });

    // Notify admins of both organizations
    await ctx.scheduler.runAfter(0, internal.emails.notifyOrganizationTransferRequest, {
      userId: user._id,
      currentOrganizationId: user.organizationId,
      targetOrganizationId,
    });

    return {
      success: true,
      message: "Transfer request submitted. An admin will review your request.",
    };
  },
});
```

### Conflict Resolution Flow
1. **Automatic merge**: Same organization → migrate B2C to B2B
2. **Keep separate**: Different organization → keep B2C enrollments
3. **Admin intervention**: User wants to switch orgs → manual transfer request
4. **Notification**: User notified of migration results

## 5.5 Payment Edge Cases

### Comprehensive Payment Failure Handling

```typescript
// convex/payments/edgeCases.ts
import { v } from "convex/values";
import { internalMutation } from "../_generated/server";

export const PAYMENT_EDGE_CASES = {
  // Idempotency: Prevent duplicate enrollments
  DUPLICATE_WEBHOOK: {
    detection: "Check stripeCheckoutSessionId uniqueness",
    handling: "Return existing enrollment, don't create duplicate",
    example: async (ctx, sessionId) => {
      const existing = await ctx.db
        .query("enrollments")
        .withIndex("by_stripe_session", (q) => q.eq("stripeCheckoutSessionId", sessionId))
        .first();

      if (existing) {
        console.log(`Duplicate webhook detected for session ${sessionId}`);
        return { success: true, enrollmentId: existing._id, duplicate: true };
      }

      return null; // Proceed with enrollment creation
    },
  },

  // Stripe handles checkout timeout (default 24 hours)
  PAYMENT_TIMEOUT: {
    detection: "Stripe expires session automatically",
    handling: "Wait for webhook; no action needed",
    note: "User will see expired session error if they return to checkout URL",
  },

  // Partial refunds not supported
  PARTIAL_REFUND: {
    detection: "Refund amount < original amount",
    handling: "Reject partial refund requests",
    example: async (ctx, refundRequest) => {
      if (refundRequest.amount < refundRequest.originalAmount) {
        throw new Error(
          "REFUND_WINDOW_CLOSED: Full refunds only. " +
          "Partial refunds require manual processing by admin."
        );
      }
    },
  },

  // Card declined during checkout
  CARD_DECLINED: {
    detection: "Stripe redirects to failure URL",
    handling: "Show error message, allow retry",
    example: {
      successUrl: "https://academy.com/success?session_id={CHECKOUT_SESSION_ID}",
      cancelUrl: "https://academy.com/enroll?error=payment_failed&cohort_id={COHORT_ID}",
    },
  },

  // Cohort fills during checkout (see Section 5.1)
  COHORT_FULL_DURING_CHECKOUT: {
    detection: "Atomic capacity check in webhook handler",
    handling: "Refund + waitlist + notification",
    reference: "See Section 5.1 for implementation",
  },
} as const;

// Idempotency check implementation
export const handleCheckoutWithIdempotency = internalMutation({
  args: {
    sessionId: v.string(),
    metadata: v.any(),
  },
  handler: async (ctx, { sessionId, metadata }) => {
    // Check for duplicate webhook
    const existingEnrollment = await ctx.db
      .query("enrollments")
      .withIndex("by_stripe_session", (q) =>
        q.eq("stripeCheckoutSessionId", sessionId)
      )
      .first();

    if (existingEnrollment) {
      console.log(`Idempotency: Session ${sessionId} already processed`);

      return {
        success: true,
        enrollmentId: existingEnrollment._id,
        duplicate: true,
        message: "Enrollment already exists",
      };
    }

    // Proceed with enrollment creation
    // ... (rest of enrollment logic from Section 5.1)
  },
});

// Card decline error page handling
export const getCheckoutErrorMessage = (errorCode: string): string => {
  const errorMessages = {
    payment_failed: "Your payment could not be processed. Please check your card details and try again.",
    card_declined: "Your card was declined. Please use a different payment method.",
    insufficient_funds: "Your card has insufficient funds. Please use a different payment method.",
    expired_card: "Your card has expired. Please update your payment information.",
    incorrect_cvc: "The security code (CVC) is incorrect. Please check and try again.",
    processing_error: "An error occurred while processing your payment. Please try again.",
    capacity_exceeded: "This cohort has reached capacity. You've been added to the waitlist.",
  };

  return errorMessages[errorCode] || "An unexpected error occurred. Please contact support.";
};
```

### Payment Edge Case Summary Table

| Scenario | Detection | Handling | User Impact |
|----------|-----------|----------|-------------|
| **Double webhook** | Check `stripeCheckoutSessionId` | Return existing enrollment | None (transparent) |
| **Payment timeout** | Stripe handles (24h expiry) | Wait for webhook | Expired checkout error |
| **Partial refund** | Amount validation | Reject, require admin | Contact support |
| **Card declined** | Stripe redirect to cancelUrl | Show error, allow retry | Try different card |
| **Cohort full during checkout** | Atomic capacity check | Refund + waitlist + notify | Refunded, waitlisted |

## 5.6 Integration Failure Handling

### Graceful Degradation for External Services

```typescript
// convex/integrations/failureHandling.ts
import { v } from "convex/values";
import { internalAction, internalMutation } from "../_generated/server";

// Brevo email rate limiting
export const sendEmailWithRetry = internalAction({
  args: {
    to: v.string(),
    templateId: v.number(),
    params: v.any(),
    attemptNumber: v.optional(v.number()),
  },
  handler: async (ctx, { to, templateId, params, attemptNumber = 1 }) => {
    const MAX_RETRIES = 5;
    const BASE_DELAY = 1000; // 1 second

    try {
      await ctx.runAction(internal.brevo.sendTransactionalEmail, {
        to,
        templateId,
        params,
      });

      console.log(`Email sent successfully to ${to}`);

    } catch (error) {
      // Check if rate limit error
      if (error.message.includes("rate limit") || error.status === 429) {
        if (attemptNumber < MAX_RETRIES) {
          // Exponential backoff: 1s, 2s, 4s, 8s, 16s
          const delay = BASE_DELAY * Math.pow(2, attemptNumber - 1);

          console.log(
            `Brevo rate limit hit. Retrying in ${delay}ms (attempt ${attemptNumber + 1}/${MAX_RETRIES})`
          );

          await ctx.scheduler.runAfter(
            delay,
            internal.integrations.failureHandling.sendEmailWithRetry,
            {
              to,
              templateId,
              params,
              attemptNumber: attemptNumber + 1,
            }
          );
        } else {
          // Queue for later delivery
          await ctx.runMutation(internal.emails.queueFailedEmail, {
            to,
            templateId,
            params,
            error: "Rate limit exceeded after max retries",
          });

          console.error(`Brevo rate limit: Email queued for manual review`);
        }
      } else {
        // Other email errors
        console.error(`Email send error:`, error);

        await ctx.runMutation(internal.emails.queueFailedEmail, {
          to,
          templateId,
          params,
          error: error.message,
        });
      }
    }
  },
});

// PostHog graceful degradation
export const trackEventSafely = internalAction({
  args: {
    userId: v.string(),
    event: v.string(),
    properties: v.any(),
  },
  handler: async (ctx, { userId, event, properties }) => {
    try {
      // Attempt to track event
      await ctx.runAction(internal.analytics.trackEvent, {
        userId,
        event,
        properties,
      });
    } catch (error) {
      // Silent fail - analytics should never block core functionality
      console.warn(`PostHog tracking failed (non-blocking):`, error.message);

      // Log failure for debugging but don't throw
      await ctx.runMutation(internal.analytics.logTrackingFailure, {
        userId,
        event,
        error: error.message,
        timestamp: Date.now(),
      });
    }
  },
});

// OpenRouter fallback model
export const generateChatResponseWithFallback = internalAction({
  args: {
    messages: v.array(v.any()),
    preferredModel: v.optional(v.string()),
  },
  handler: async (ctx, { messages, preferredModel = "anthropic/claude-3.5-sonnet" }) => {
    const FALLBACK_MODEL = "anthropic/claude-3-haiku";

    try {
      // Try preferred model
      const response = await ctx.runAction(internal.ai.generateResponse, {
        messages,
        model: preferredModel,
      });

      return {
        response,
        modelUsed: preferredModel,
        fellback: false,
      };

    } catch (error) {
      console.warn(`Primary model ${preferredModel} failed. Falling back to ${FALLBACK_MODEL}`);

      try {
        // Fallback to cheaper, more reliable model
        const response = await ctx.runAction(internal.ai.generateResponse, {
          messages,
          model: FALLBACK_MODEL,
        });

        return {
          response,
          modelUsed: FALLBACK_MODEL,
          fellback: true,
          originalError: error.message,
        };

      } catch (fallbackError) {
        // Both models failed
        throw new Error(
          `AI generation failed: ${error.message}. Fallback also failed: ${fallbackError.message}`
        );
      }
    }
  },
});

// Cal.com booking conflict handling
export const handleCalComConflict = internalMutation({
  args: {
    userId: v.id("users"),
    eventTypeId: v.string(),
    requestedTime: v.number(),
  },
  handler: async (ctx, { userId, eventTypeId, requestedTime }) => {
    // Cal.com handles availability checking automatically
    // This is just for logging/tracking on our side

    await ctx.db.insert("bookingConflicts", {
      userId,
      eventTypeId,
      requestedTime,
      detectedAt: Date.now(),
      resolution: "user_rescheduled_via_calcom",
    });

    // Cal.com will show available slots to user
    return {
      message: "Please select an available time slot from Cal.com",
      handledBy: "calcom",
    };
  },
});

// Formbricks survey timeout handling
export const submitSurveyWithTimeout = internalAction({
  args: {
    userId: v.id("users"),
    surveyId: v.string(),
    responses: v.any(),
  },
  handler: async (ctx, { userId, surveyId, responses }) => {
    const TIMEOUT_MS = 5000; // 5 second timeout

    try {
      // Race between Formbricks submission and timeout
      const result = await Promise.race([
        ctx.runAction(internal.formbricks.submitResponse, {
          surveyId,
          responses,
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error("Formbricks timeout")), TIMEOUT_MS)
        ),
      ]);

      return {
        success: true,
        submittedToFormbricks: true,
      };

    } catch (error) {
      // Timeout or Formbricks error
      console.warn(`Formbricks submission failed:`, error.message);

      // Save responses locally for manual completion
      await ctx.runMutation(internal.surveys.saveResponsesLocally, {
        userId,
        surveyId,
        responses,
        submittedToFormbricks: false,
        error: error.message,
      });

      return {
        success: true,
        submittedToFormbricks: false,
        message: "Your responses have been saved locally",
      };
    }
  },
});
```

### Integration Failure Handling Summary

| Integration | Failure Scenario | Handling Strategy | User Impact |
|-------------|------------------|-------------------|-------------|
| **Brevo** | Rate limit (429) | Exponential backoff (1s → 16s), then queue | Delayed email (< 1 min) |
| **Brevo** | Service down | Queue for retry, admin notification | Email sent when service recovers |
| **PostHog** | Tracking fails | Silent fail, log error | None (analytics only) |
| **PostHog** | Service timeout | Silent fail | None (analytics only) |
| **OpenRouter** | Primary model unavailable | Auto-fallback to claude-3-haiku | Slightly lower quality response |
| **OpenRouter** | Both models fail | Throw error, user retries | Error message shown |
| **Cal.com** | Booking conflict | Cal.com shows available slots | User selects different time |
| **Cal.com** | Service down | Show error, allow retry | Temporary booking unavailable |
| **Formbricks** | Submission timeout (>5s) | Save locally, allow manual completion | Survey saved, submitted later |
| **Formbricks** | Service down | Save locally | Survey submitted when service recovers |

### Monitoring and Alerting

```typescript
// convex/monitoring/integrationHealth.ts
export const checkIntegrationHealth = internalAction({
  handler: async (ctx) => {
    const checks = [
      { name: "Brevo", check: () => ctx.runAction(internal.brevo.healthCheck) },
      { name: "PostHog", check: () => ctx.runAction(internal.analytics.healthCheck) },
      { name: "OpenRouter", check: () => ctx.runAction(internal.ai.healthCheck) },
      { name: "Cal.com", check: () => ctx.runAction(internal.calendar.healthCheck) },
      { name: "Formbricks", check: () => ctx.runAction(internal.surveys.healthCheck) },
    ];

    const results = await Promise.allSettled(
      checks.map(async ({ name, check }) => {
        const start = Date.now();
        await check();
        return { name, latency: Date.now() - start, status: "healthy" };
      })
    );

    const healthStatus = results.map((result, i) => {
      if (result.status === "fulfilled") {
        return result.value;
      } else {
        return {
          name: checks[i].name,
          status: "unhealthy",
          error: result.reason.message,
        };
      }
    });

    // Alert if any integration is unhealthy
    const unhealthy = healthStatus.filter((h) => h.status === "unhealthy");

    if (unhealthy.length > 0) {
      await ctx.runAction(internal.alerts.notifyIntegrationFailure, {
        unhealthyIntegrations: unhealthy,
      });
    }

    return healthStatus;
  },
});
```

## 5.7 Error Codes and Messages

### Comprehensive Error Code System

```typescript
// convex/errors/codes.ts
export const ERROR_CODES = {
  // Authentication & Authorization
  UNAUTHORIZED: "UNAUTHORIZED",
  FORBIDDEN: "FORBIDDEN",
  INVALID_TOKEN: "INVALID_TOKEN",
  SESSION_EXPIRED: "SESSION_EXPIRED",

  // Enrollment
  COHORT_FULL: "COHORT_FULL",
  ALREADY_ENROLLED: "ALREADY_ENROLLED",
  NOT_ENROLLED: "NOT_ENROLLED",
  ACCESS_EXPIRED: "ACCESS_EXPIRED",
  ACCESS_GRACE_PERIOD: "ACCESS_GRACE_PERIOD",
  ENROLLMENT_NOT_FOUND: "ENROLLMENT_NOT_FOUND",

  // Payment
  PAYMENT_FAILED: "PAYMENT_FAILED",
  PAYMENT_TIMEOUT: "PAYMENT_TIMEOUT",
  REFUND_WINDOW_CLOSED: "REFUND_WINDOW_CLOSED",
  REFUND_ALREADY_PROCESSED: "REFUND_ALREADY_PROCESSED",
  INVALID_PAYMENT_INTENT: "INVALID_PAYMENT_INTENT",
  STRIPE_WEBHOOK_VERIFICATION_FAILED: "STRIPE_WEBHOOK_VERIFICATION_FAILED",

  // Booking
  OFFICE_HOURS_INELIGIBLE: "OFFICE_HOURS_INELIGIBLE",
  BOOKING_CONFLICT: "BOOKING_CONFLICT",
  BOOKING_NOT_FOUND: "BOOKING_NOT_FOUND",
  INVALID_BOOKING_TIME: "INVALID_BOOKING_TIME",

  // Chat
  CHATBOT_ACCESS_EXPIRED: "CHATBOT_ACCESS_EXPIRED",
  CHAT_RATE_LIMITED: "CHAT_RATE_LIMITED",
  CHAT_SESSION_NOT_FOUND: "CHAT_SESSION_NOT_FOUND",
  INVALID_CHAT_MESSAGE: "INVALID_CHAT_MESSAGE",
  AI_GENERATION_FAILED: "AI_GENERATION_FAILED",

  // B2B / Organizations
  INVITE_EXPIRED: "INVITE_EXPIRED",
  INVITE_ALREADY_USED: "INVITE_ALREADY_USED",
  INVITE_NOT_FOUND: "INVITE_NOT_FOUND",
  ORG_SEATS_EXHAUSTED: "ORG_SEATS_EXHAUSTED",
  ORG_NOT_FOUND: "ORG_NOT_FOUND",
  ORG_CONFLICT: "ORG_CONFLICT",
  ALREADY_ORG_MEMBER: "ALREADY_ORG_MEMBER",

  // Waitlist
  ALREADY_ON_WAITLIST: "ALREADY_ON_WAITLIST",
  WAITLIST_NOT_FOUND: "WAITLIST_NOT_FOUND",
  WAITLIST_EXPIRED: "WAITLIST_EXPIRED",

  // Validation
  INVALID_INPUT: "INVALID_INPUT",
  MISSING_REQUIRED_FIELD: "MISSING_REQUIRED_FIELD",
  INVALID_DATE_RANGE: "INVALID_DATE_RANGE",

  // System
  INTERNAL_ERROR: "INTERNAL_ERROR",
  SERVICE_UNAVAILABLE: "SERVICE_UNAVAILABLE",
  RATE_LIMITED: "RATE_LIMITED",
  MAINTENANCE_MODE: "MAINTENANCE_MODE",
} as const;

export type ErrorCode = typeof ERROR_CODES[keyof typeof ERROR_CODES];

// User-friendly error messages
export const ERROR_MESSAGES: Record<ErrorCode, string> = {
  // Auth
  UNAUTHORIZED: "You must be logged in to access this resource.",
  FORBIDDEN: "You don't have permission to perform this action.",
  INVALID_TOKEN: "Your session token is invalid. Please log in again.",
  SESSION_EXPIRED: "Your session has expired. Please log in again.",

  // Enrollment
  COHORT_FULL: "This cohort has reached capacity. You've been added to the waitlist and will be notified if a spot opens up.",
  ALREADY_ENROLLED: "You're already enrolled in this cohort.",
  NOT_ENROLLED: "You must enroll in this cohort to access this content.",
  ACCESS_EXPIRED: "Your access to this content has expired. Contact support to extend your access.",
  ACCESS_GRACE_PERIOD: "Your access has expired, but you have 24 hours to complete in-progress content.",
  ENROLLMENT_NOT_FOUND: "Enrollment not found. Please contact support.",

  // Payment
  PAYMENT_FAILED: "Payment failed. Please check your card details and try again.",
  PAYMENT_TIMEOUT: "Your checkout session has expired. Please start over.",
  REFUND_WINDOW_CLOSED: "The refund window for this enrollment has closed. Please contact support for assistance.",
  REFUND_ALREADY_PROCESSED: "A refund has already been processed for this enrollment.",
  INVALID_PAYMENT_INTENT: "Invalid payment information. Please contact support.",
  STRIPE_WEBHOOK_VERIFICATION_FAILED: "Payment webhook verification failed. Our team has been notified.",

  // Booking
  OFFICE_HOURS_INELIGIBLE: "You don't have access to office hours. Enroll in a cohort to book sessions.",
  BOOKING_CONFLICT: "This time slot is no longer available. Please select a different time.",
  BOOKING_NOT_FOUND: "Booking not found.",
  INVALID_BOOKING_TIME: "The selected time is not available. Please choose a different slot.",

  // Chat
  CHATBOT_ACCESS_EXPIRED: "Your chatbot access has expired. Re-enroll to continue chatting.",
  CHAT_RATE_LIMITED: "You're sending messages too quickly. Please wait a moment.",
  CHAT_SESSION_NOT_FOUND: "Chat session not found. Please start a new conversation.",
  INVALID_CHAT_MESSAGE: "Invalid message format. Please try again.",
  AI_GENERATION_FAILED: "Failed to generate AI response. Please try again.",

  // B2B
  INVITE_EXPIRED: "This invitation has expired. Please request a new one from your organization admin.",
  INVITE_ALREADY_USED: "This invitation has already been used.",
  INVITE_NOT_FOUND: "Invitation not found. Please check the link and try again.",
  ORG_SEATS_EXHAUSTED: "Your organization has reached its seat limit. Contact your admin to add more seats.",
  ORG_NOT_FOUND: "Organization not found.",
  ORG_CONFLICT: "You're already a member of a different organization. Contact support to resolve this.",
  ALREADY_ORG_MEMBER: "You're already a member of this organization.",

  // Waitlist
  ALREADY_ON_WAITLIST: "You're already on the waitlist for this cohort.",
  WAITLIST_NOT_FOUND: "Waitlist entry not found.",
  WAITLIST_EXPIRED: "Your waitlist spot has expired.",

  // Validation
  INVALID_INPUT: "Invalid input. Please check your data and try again.",
  MISSING_REQUIRED_FIELD: "Required field is missing.",
  INVALID_DATE_RANGE: "Invalid date range.",

  // System
  INTERNAL_ERROR: "An unexpected error occurred. Our team has been notified.",
  SERVICE_UNAVAILABLE: "Service temporarily unavailable. Please try again later.",
  RATE_LIMITED: "Too many requests. Please slow down.",
  MAINTENANCE_MODE: "The platform is undergoing maintenance. Please check back soon.",
};

// Error class with code and message
export class ApplicationError extends Error {
  constructor(
    public code: ErrorCode,
    public userMessage?: string,
    public metadata?: Record<string, any>
  ) {
    super(userMessage || ERROR_MESSAGES[code]);
    this.name = "ApplicationError";
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.userMessage || ERROR_MESSAGES[this.code],
        metadata: this.metadata,
      },
    };
  }
}

// Helper function to throw errors
export function throwError(
  code: ErrorCode,
  customMessage?: string,
  metadata?: Record<string, any>
): never {
  throw new ApplicationError(code, customMessage, metadata);
}

// Usage examples
export const exampleUsage = {
  // In a mutation
  checkEnrollment: async (ctx, cohortId) => {
    const enrollment = await ctx.db.query("enrollments").first();

    if (!enrollment) {
      throwError("NOT_ENROLLED", undefined, { cohortId });
    }

    if (enrollment.workshopAccessUntil < Date.now()) {
      throwError("ACCESS_EXPIRED", "Workshop access expired on " + new Date(enrollment.workshopAccessUntil).toLocaleDateString());
    }
  },

  // In error handler
  handleError: (error: unknown) => {
    if (error instanceof ApplicationError) {
      return {
        success: false,
        error: error.toJSON(),
      };
    }

    // Unknown error
    return {
      success: false,
      error: {
        code: ERROR_CODES.INTERNAL_ERROR,
        message: ERROR_MESSAGES.INTERNAL_ERROR,
      },
    };
  },
};
```

### Error Response Format

```typescript
// Standardized error response structure
interface ErrorResponse {
  success: false;
  error: {
    code: ErrorCode;
    message: string;
    metadata?: Record<string, any>;
  };
}

// Success response structure
interface SuccessResponse<T = any> {
  success: true;
  data: T;
}

// Example API responses
const examples = {
  // Enrollment error
  cohortFull: {
    success: false,
    error: {
      code: "COHORT_FULL",
      message: "This cohort has reached capacity. You've been added to the waitlist and will be notified if a spot opens up.",
      metadata: {
        cohortId: "j123456789",
        waitlistPosition: 5,
      },
    },
  },

  // Payment error
  paymentFailed: {
    success: false,
    error: {
      code: "PAYMENT_FAILED",
      message: "Payment failed. Please check your card details and try again.",
      metadata: {
        stripeError: "card_declined",
        declineCode: "insufficient_funds",
      },
    },
  },

  // Access error with grace period
  gracePeriod: {
    success: false,
    error: {
      code: "ACCESS_GRACE_PERIOD",
      message: "Your access has expired, but you have 24 hours to complete in-progress content.",
      metadata: {
        originalExpiry: 1704067200000,
        gracePeriodEndsAt: 1704153600000,
        hoursRemaining: 18,
      },
    },
  },

  // Success response
  enrollmentSuccess: {
    success: true,
    data: {
      enrollmentId: "k987654321",
      cohortId: "j123456789",
      workshopDate: 1704153600000,
      accessPeriods: {
        workshop: { until: 1704844800000 },
        chatbot: { until: 1707523200000 },
        officeHours: { until: 1707523200000 },
      },
    },
  },
};
```

### Frontend Error Display

```typescript
// app/components/ErrorDisplay.tsx
import { AlertCircle, Info, AlertTriangle } from "lucide-react";

interface ErrorDisplayProps {
  error: {
    code: string;
    message: string;
    metadata?: Record<string, any>;
  };
}

export function ErrorDisplay({ error }: ErrorDisplayProps) {
  // Determine severity
  const severity = getSeverity(error.code);

  const config = {
    error: {
      icon: AlertCircle,
      className: "bg-red-50 border-red-400 text-red-800",
    },
    warning: {
      icon: AlertTriangle,
      className: "bg-amber-50 border-amber-400 text-amber-800",
    },
    info: {
      icon: Info,
      className: "bg-blue-50 border-blue-400 text-blue-800",
    },
  };

  const { icon: Icon, className } = config[severity];

  return (
    <div className={`border-l-4 p-4 ${className}`}>
      <div className="flex">
        <Icon className="h-5 w-5 mr-3" />
        <div>
          <p className="font-medium">{error.message}</p>
          {error.metadata && (
            <p className="text-sm mt-1 opacity-80">
              {formatMetadata(error.metadata)}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

function getSeverity(code: string): "error" | "warning" | "info" {
  const errorCodes = ["PAYMENT_FAILED", "UNAUTHORIZED", "FORBIDDEN", "INTERNAL_ERROR"];
  const warningCodes = ["ACCESS_GRACE_PERIOD", "COHORT_FULL", "REFUND_WINDOW_CLOSED"];

  if (errorCodes.includes(code)) return "error";
  if (warningCodes.includes(code)) return "warning";
  return "info";
}

function formatMetadata(metadata: Record<string, any>): string {
  if (metadata.waitlistPosition) {
    return `Waitlist position: ${metadata.waitlistPosition}`;
  }
  if (metadata.hoursRemaining) {
    return `${metadata.hoursRemaining} hours remaining in grace period`;
  }
  return "";
}
```

---

## 5.8 Assessment Edge Cases

### EC-AS-001: Assessment Timeout Mid-Question
**Scenario:** Time expires while user typing answer

**Prevention:**
- Auto-save draft response every 30 seconds
- Store in local storage as backup
- Warning at 5 minutes remaining

**Recovery:**
- Submit partial response automatically
- Mark assessment as "incomplete"
- Allow instructor review for time extension
- Store timestamp of timeout for audit

**Implementation:**
```typescript
// convex/assessments/timeout.ts
export const handleAssessmentTimeout = internalMutation({
  args: {
    assessmentSessionId: v.id("assessmentSessions"),
    lastDraftResponse: v.optional(v.string()),
  },
  handler: async (ctx, { assessmentSessionId, lastDraftResponse }) => {
    const session = await ctx.db.get(assessmentSessionId);
    if (!session) throw new Error("Session not found");

    // Submit partial response
    await ctx.db.patch(assessmentSessionId, {
      status: "incomplete",
      completedAt: Date.now(),
      timeoutOccurred: true,
      lastDraftResponse,
    });

    // Notify instructor for review
    await ctx.scheduler.runAfter(0, internal.emails.notifyInstructorTimeout, {
      userId: session.userId,
      assessmentSessionId,
    });
  },
});
```

### EC-AS-002: AI Grading Service Unavailable
**Scenario:** OpenRouter API down during grading

**Prevention:**
- Health check before batch grading
- Queue-based grading system
- Mark responses as "pending" rather than failing

**Recovery:**
- Retry with exponential backoff (1s, 10s, 60s)
- Fall back to manual review queue after 3 attempts
- Notify instructor of grading delays
- Store original response for later re-grading

**Implementation:**
```typescript
// convex/assessments/grading.ts
export const gradeWithFallback = internalAction({
  args: {
    responseId: v.id("assessmentResponses"),
    attemptNumber: v.optional(v.number()),
  },
  handler: async (ctx, { responseId, attemptNumber = 1 }) => {
    const MAX_RETRIES = 3;
    const RETRY_DELAYS = [1000, 10000, 60000]; // 1s, 10s, 60s

    try {
      // Attempt AI grading
      const grade = await ctx.runAction(internal.ai.gradeResponse, {
        responseId,
      });

      await ctx.runMutation(internal.assessments.saveGrade, {
        responseId,
        grade,
        gradedBy: "ai",
      });

    } catch (error) {
      if (attemptNumber < MAX_RETRIES) {
        // Retry with backoff
        const delay = RETRY_DELAYS[attemptNumber - 1];
        await ctx.scheduler.runAfter(delay, internal.assessments.gradeWithFallback, {
          responseId,
          attemptNumber: attemptNumber + 1,
        });
      } else {
        // Queue for manual review
        await ctx.runMutation(internal.assessments.queueManualReview, {
          responseId,
          reason: "ai_grading_failed",
        });
      }
    }
  },
});
```

### EC-AS-003: Negative Learning Gain
**Scenario:** Post-score lower than pre-score

**Prevention:**
- This is valid data - don't hide it
- Track as legitimate outcome
- May indicate: rushing, fatigue, misunderstanding, or regression

**Recovery:**
- Display honestly with context
- Flag for instructor follow-up
- Offer optional retake with different questions
- Track for program effectiveness analysis

**Implementation:**
```typescript
// convex/assessments/learningGain.ts
export const calculateLearningGain = (preScore: number, postScore: number, maxScore: number) => {
  const possibleGain = maxScore - preScore;
  const actualGain = postScore - preScore;

  if (possibleGain === 0) {
    // Ceiling effect - pre-score was perfect
    return {
      gain: 0,
      normalized: null,
      status: "ceiling_reached",
      message: "Perfect pre-assessment score - no room for improvement",
    };
  }

  const normalized = (actualGain / possibleGain) * 100;

  if (normalized < 0) {
    // Negative learning gain
    return {
      gain: actualGain,
      normalized,
      status: "negative_gain",
      message: "Post-score lower than pre-score - flagged for review",
      flagForReview: true,
    };
  }

  return {
    gain: actualGain,
    normalized,
    status: "positive_gain",
    message: `${normalized.toFixed(1)}% learning gain`,
  };
};
```

### EC-AS-004: Pre-Assessment Retake Attempt
**Scenario:** User tries to retake pre-assessment

**Prevention:**
- Disable retake button after submission
- Check for existing submission before allowing access
- Clear error message explaining one-attempt policy

**Recovery:**
- Block retake with error message
- Show existing pre-assessment score
- Link to support if legitimate issue (technical failure, etc.)

**Implementation:**
```typescript
// convex/assessments/retake.ts
export const checkRetakeEligibility = query({
  args: {
    userId: v.id("users"),
    assessmentId: v.id("assessments"),
  },
  handler: async (ctx, { userId, assessmentId }) => {
    const assessment = await ctx.db.get(assessmentId);
    if (!assessment) throw new Error("Assessment not found");

    const existingAttempt = await ctx.db
      .query("assessmentSessions")
      .withIndex("by_user_assessment", (q) =>
        q.eq("userId", userId).eq("assessmentId", assessmentId)
      )
      .first();

    if (assessment.type === "pre" && existingAttempt) {
      return {
        eligible: false,
        reason: "PRE_ASSESSMENT_ALREADY_TAKEN",
        message: "Pre-assessments can only be taken once to establish baseline knowledge.",
        existingScore: existingAttempt.score,
      };
    }

    return {
      eligible: true,
    };
  },
});
```

### EC-AS-005: Question Bank Exhausted
**Scenario:** Randomization needs more questions than exist

**Prevention:**
- Validate assessment config against question bank size
- Warn admin when creating assessment with insufficient questions
- Set minimum question pool size (e.g., 2x requested count)

**Recovery:**
- Use all available questions
- Log warning to admin dashboard
- Display notice to user: "All available questions included"
- Consider allowing duplicate questions with note

**Implementation:**
```typescript
// convex/assessments/questionPool.ts
export const validateQuestionPool = query({
  args: {
    courseId: v.id("courses"),
    requestedCount: v.number(),
  },
  handler: async (ctx, { courseId, requestedCount }) => {
    const availableQuestions = await ctx.db
      .query("assessmentQuestions")
      .withIndex("by_course", (q) => q.eq("courseId", courseId))
      .collect();

    if (availableQuestions.length < requestedCount) {
      return {
        valid: false,
        reason: "QUESTION_POOL_EXHAUSTED",
        message: `Only ${availableQuestions.length} questions available, but ${requestedCount} requested`,
        recommendation: "Add more questions or reduce assessment length",
        willUseAllAvailable: true,
      };
    }

    return {
      valid: true,
      availableCount: availableQuestions.length,
    };
  },
});
```

### EC-AS-006: Grading Rubric Mismatch
**Scenario:** AI grades with outdated rubric

**Prevention:**
- Version rubric with assessment (immutable)
- Store rubric snapshot in assessment record
- Track rubric version in grading metadata

**Recovery:**
- Detect version mismatch in audit
- Re-grade affected responses with correct rubric
- Notify affected users of score changes
- Log all re-grading events for transparency

**Implementation:**
```typescript
// convex/assessments/rubricVersion.ts
export const detectRubricMismatch = internalMutation({
  args: {
    assessmentId: v.id("assessments"),
  },
  handler: async (ctx, { assessmentId }) => {
    const assessment = await ctx.db.get(assessmentId);
    if (!assessment) throw new Error("Assessment not found");

    const responses = await ctx.db
      .query("assessmentResponses")
      .withIndex("by_assessment", (q) => q.eq("assessmentId", assessmentId))
      .collect();

    const mismatches = responses.filter(
      (r) => r.rubricVersion !== assessment.currentRubricVersion
    );

    if (mismatches.length > 0) {
      // Queue for re-grading
      await ctx.db.insert("regradingQueue", {
        assessmentId,
        affectedResponses: mismatches.map((r) => r._id),
        reason: "rubric_version_mismatch",
        createdAt: Date.now(),
      });

      // Notify admin
      await ctx.scheduler.runAfter(0, internal.emails.notifyRubricMismatch, {
        assessmentId,
        affectedCount: mismatches.length,
      });
    }

    return {
      mismatchesFound: mismatches.length,
      requiresRegrading: mismatches.length > 0,
    };
  },
});
```

### EC-AS-007: Concurrent Assessment Sessions
**Scenario:** User opens assessment in two tabs

**Prevention:**
- Lock to single active session per user
- Detect multiple tabs via session token
- Show warning: "Assessment already in progress"

**Recovery:**
- Close older session automatically
- Preserve progress from most recent session
- Merge draft responses if both have data (use latest timestamp)

**Implementation:**
```typescript
// convex/assessments/session.ts
export const initializeSession = mutation({
  args: {
    assessmentId: v.id("assessments"),
    sessionToken: v.string(),
  },
  handler: async (ctx, { assessmentId, sessionToken }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const userId = identity.subject;

    // Check for existing active session
    const activeSession = await ctx.db
      .query("assessmentSessions")
      .withIndex("by_user_assessment", (q) =>
        q.eq("userId", userId).eq("assessmentId", assessmentId)
      )
      .filter((q) => q.eq(q.field("status"), "in_progress"))
      .first();

    if (activeSession && activeSession.sessionToken !== sessionToken) {
      // Close older session
      await ctx.db.patch(activeSession._id, {
        status: "closed_duplicate",
        closedAt: Date.now(),
      });
    }

    // Create new session
    const sessionId = await ctx.db.insert("assessmentSessions", {
      userId,
      assessmentId,
      sessionToken,
      status: "in_progress",
      startedAt: Date.now(),
    });

    return {
      sessionId,
      warning: activeSession ? "Previous session closed" : null,
    };
  },
});
```

### EC-AS-008: Learning Gain Calculation Division Error
**Scenario:** Pre-score is 100% (ceiling effect)

**Prevention:**
- Handle mathematically: possible gain = 0
- Display as "N/A" or "Ceiling reached"
- Track separately for analytics

**Recovery:**
- Show "Perfect pre-assessment" message
- Don't calculate percentage gain (divide by zero)
- Consider alternative metrics (time improvement, depth of answers)

**Implementation:** (See EC-AS-003 implementation above)

---

## 5.9 Manager Dashboard Edge Cases

### EC-MD-001: Privacy Opt-Out After Data Viewed
**Scenario:** User opts out after manager viewed data

**Prevention:**
- Immediate effect on future views
- Historical views remain in audit log (compliance)
- Clear opt-out message: "Future data will be hidden"

**Recovery:**
- Remove user from future aggregations
- Historical reports remain (immutable audit trail)
- Show placeholder in dashboard: "User opted out"
- Notify manager of team member opt-out

**Implementation:**
```typescript
// convex/privacy/optOut.ts
export const handlePrivacyOptOut = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, { userId }) => {
    // Update user privacy preference
    await ctx.db.patch(userId, {
      managerViewOptOut: true,
      optOutTimestamp: Date.now(),
    });

    // Notify manager(s)
    const user = await ctx.db.get(userId);
    if (user?.organizationId) {
      const managers = await ctx.db
        .query("users")
        .withIndex("by_organization", (q) => q.eq("organizationId", user.organizationId))
        .filter((q) => q.eq(q.field("role"), "org_admin"))
        .collect();

      for (const manager of managers) {
        await ctx.scheduler.runAfter(0, internal.emails.notifyManagerOptOut, {
          managerId: manager._id,
          userId,
        });
      }
    }

    return {
      success: true,
      message: "Your learning data is now private. Managers will see anonymized metrics only.",
    };
  },
});
```

### EC-MD-002: Team Member Leaves Organization
**Scenario:** User departs mid-learning-path

**Prevention:**
- Soft delete (don't remove data)
- Mark as "inactive" in team roster
- Maintain data for historical reporting

**Recovery:**
- Archive in reports with "Former member" label
- Remove from active team views
- Preserve completion records for organization metrics
- Transfer ongoing work to replacement if applicable

**Implementation:**
```typescript
// convex/organizations/offboarding.ts
export const offboardTeamMember = mutation({
  args: {
    userId: v.id("users"),
    departureDatee: v.number(),
  },
  handler: async (ctx, { userId, departureDate }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("User not found");

    // Update user status
    await ctx.db.patch(userId, {
      organizationStatus: "inactive",
      organizationDepartureDate: departureDate,
      organizationId: undefined, // Remove org link
    });

    // Archive enrollments (don't delete)
    const enrollments = await ctx.db
      .query("enrollments")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const enrollment of enrollments) {
      await ctx.db.patch(enrollment._id, {
        archived: true,
        archivedReason: "user_departed",
        archivedAt: Date.now(),
      });
    }

    return {
      success: true,
      enrollmentsArchived: enrollments.length,
    };
  },
});
```

### EC-MD-003: Report Generation Timeout
**Scenario:** Large org report exceeds processing time

**Prevention:**
- Async generation with progress tracking
- Show loading state with estimated time
- Set reasonable timeout (e.g., 5 minutes)

**Recovery:**
- Generate report in background
- Email manager when ready
- Offer partial results option (e.g., "Top 50 learners only")
- Cache frequently requested reports

**Implementation:**
```typescript
// convex/reports/generation.ts
export const generateLargeReport = internalAction({
  args: {
    organizationId: v.id("organizations"),
    reportType: v.string(),
    managerId: v.id("users"),
  },
  handler: async (ctx, { organizationId, reportType, managerId }) => {
    try {
      // Generate report asynchronously
      const reportData = await ctx.runAction(internal.reports.buildReport, {
        organizationId,
        reportType,
      });

      // Store report
      const reportId = await ctx.runMutation(internal.reports.saveReport, {
        organizationId,
        reportType,
        data: reportData,
        generatedAt: Date.now(),
      });

      // Email manager
      await ctx.scheduler.runAfter(0, internal.emails.sendReportReady, {
        managerId,
        reportId,
      });

    } catch (error) {
      // Timeout or error
      await ctx.runMutation(internal.reports.logReportFailure, {
        organizationId,
        reportType,
        error: error.message,
      });

      // Notify manager of failure
      await ctx.scheduler.runAfter(0, internal.emails.sendReportFailed, {
        managerId,
        error: error.message,
      });
    }
  },
});
```

### EC-MD-004: Skills Heat Map Empty Cells
**Scenario:** No team members have certain skill

**Prevention:**
- Show gap indicator clearly
- Differentiate between "no data" and "skill gap"
- Color code: gray = no data, red = gap identified

**Recovery:**
- Display as "Training opportunity"
- Suggest relevant courses for skill gap
- Track skill gaps for org needs analysis
- Allow manager to mark as "Not applicable"

**Implementation:**
```typescript
// convex/analytics/skillsHeatmap.ts
export const generateSkillsHeatmap = query({
  args: {
    organizationId: v.id("organizations"),
  },
  handler: async (ctx, { organizationId }) => {
    // Get all skills from course taxonomy
    const allSkills = await ctx.db
      .query("skills")
      .collect();

    // Get team member skill levels
    const teamMembers = await ctx.db
      .query("users")
      .withIndex("by_organization", (q) => q.eq("organizationId", organizationId))
      .collect();

    const heatmap = allSkills.map((skill) => {
      const members = teamMembers.map((member) => {
        const skillLevel = getSkillLevel(member, skill._id);

        return {
          memberId: member._id,
          memberName: member.name,
          level: skillLevel,
          isEmpty: skillLevel === null,
        };
      });

      const emptyCount = members.filter((m) => m.isEmpty).length;

      return {
        skillId: skill._id,
        skillName: skill.name,
        members,
        isGap: emptyCount === teamMembers.length,
        gapPercentage: (emptyCount / teamMembers.length) * 100,
      };
    });

    return heatmap;
  },
});
```

### EC-MD-005: Manager Role Revoked Mid-Session
**Scenario:** Admin removes manager role while viewing

**Prevention:**
- Check permission on each data request
- Real-time permission sync via Convex subscriptions
- Clear session on role change

**Recovery:**
- Graceful redirect to learner view
- Show message: "Manager access revoked"
- Log access attempt for audit
- Don't show error - maintain positive UX

**Implementation:**
```typescript
// convex/auth/permissions.ts
export const checkManagerAccess = query({
  args: {
    organizationId: v.id("organizations"),
  },
  handler: async (ctx, { organizationId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    const hasAccess =
      user.role === "org_admin" &&
      user.organizationId === organizationId;

    if (!hasAccess) {
      // Log unauthorized attempt
      await ctx.db.insert("accessLogs", {
        userId: user._id,
        attemptedResource: "manager_dashboard",
        reason: "insufficient_permissions",
        timestamp: Date.now(),
      });

      return {
        hasAccess: false,
        redirectTo: "/learner/dashboard",
        message: "Manager access has been revoked. Redirecting to learner dashboard.",
      };
    }

    return {
      hasAccess: true,
    };
  },
});
```

### EC-MD-006: GDPR Data Export Timeout
**Scenario:** User's data export request times out

**Prevention:**
- Async job with chunked export
- Progress tracking UI
- Reasonable timeout (e.g., 10 minutes for large datasets)

**Recovery:**
- Retry queue with exponential backoff
- Notification when ready (email + dashboard alert)
- Partial export option if full export fails
- Admin manual intervention for large exports

**Implementation:**
```typescript
// convex/gdpr/dataExport.ts
export const requestDataExport = internalAction({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, { userId }) => {
    try {
      // Export user data in chunks
      const userData = await ctx.runAction(internal.gdpr.collectUserData, { userId });
      const enrollmentData = await ctx.runAction(internal.gdpr.collectEnrollmentData, { userId });
      const progressData = await ctx.runAction(internal.gdpr.collectProgressData, { userId });

      // Combine and format
      const exportData = {
        user: userData,
        enrollments: enrollmentData,
        progress: progressData,
        exportedAt: new Date().toISOString(),
      };

      // Store export file
      const exportId = await ctx.runMutation(internal.gdpr.saveExport, {
        userId,
        data: exportData,
      });

      // Notify user
      await ctx.scheduler.runAfter(0, internal.emails.sendExportReady, {
        userId,
        exportId,
      });

    } catch (error) {
      if (error.message.includes("timeout")) {
        // Retry later
        await ctx.scheduler.runAfter(300000, internal.gdpr.requestDataExport, { userId });
      } else {
        // Log failure, notify admin
        await ctx.runMutation(internal.gdpr.logExportFailure, {
          userId,
          error: error.message,
        });
      }
    }
  },
});
```

### EC-MD-007: Reminder to Inactive User
**Scenario:** Manager sends reminder to user who left

**Prevention:**
- Check user status before sending
- Filter out inactive/departed users
- Show warning: "User no longer active"

**Recovery:**
- Skip inactive users automatically
- Report skipped users to manager
- Suggest removing from team roster
- Log attempted sends for audit

**Implementation:**
```typescript
// convex/notifications/reminders.ts
export const sendTeamReminders = mutation({
  args: {
    userIds: v.array(v.id("users")),
    message: v.string(),
  },
  handler: async (ctx, { userIds, message }) => {
    const results = {
      sent: [],
      skipped: [],
    };

    for (const userId of userIds) {
      const user = await ctx.db.get(userId);

      if (!user || user.organizationStatus === "inactive") {
        results.skipped.push({
          userId,
          reason: user ? "User inactive" : "User not found",
        });
        continue;
      }

      // Send reminder
      await ctx.scheduler.runAfter(0, internal.emails.sendReminder, {
        userId,
        message,
      });

      results.sent.push(userId);
    }

    return results;
  },
});
```

### EC-MD-008: Analytics Aggregation Mismatch
**Scenario:** Team total doesn't match sum of individuals

**Prevention:**
- Recalculate on every read (don't cache stale data)
- Use database aggregation functions
- Validate sums before display

**Recovery:**
- Async reconciliation job (nightly)
- Flag mismatches in admin dashboard
- Re-aggregate affected data
- Log discrepancies for investigation

**Implementation:**
```typescript
// convex/analytics/reconciliation.ts
export const reconcileTeamMetrics = internalMutation({
  args: {
    organizationId: v.id("organizations"),
  },
  handler: async (ctx, { organizationId }) => {
    // Get team members
    const members = await ctx.db
      .query("users")
      .withIndex("by_organization", (q) => q.eq("organizationId", organizationId))
      .collect();

    // Calculate individual sums
    let totalEnrollments = 0;
    let totalCompletions = 0;

    for (const member of members) {
      const enrollments = await ctx.db
        .query("enrollments")
        .withIndex("by_user", (q) => q.eq("userId", member._id))
        .collect();

      totalEnrollments += enrollments.length;
      totalCompletions += enrollments.filter((e) => e.status === "completed").length;
    }

    // Get cached team totals
    const cachedMetrics = await ctx.db
      .query("organizationMetrics")
      .withIndex("by_organization", (q) => q.eq("organizationId", organizationId))
      .first();

    // Check for mismatch
    if (cachedMetrics) {
      const enrollmentMismatch = cachedMetrics.totalEnrollments !== totalEnrollments;
      const completionMismatch = cachedMetrics.totalCompletions !== totalCompletions;

      if (enrollmentMismatch || completionMismatch) {
        // Log discrepancy
        await ctx.db.insert("reconciliationLogs", {
          organizationId,
          type: "metrics_mismatch",
          cachedEnrollments: cachedMetrics.totalEnrollments,
          actualEnrollments: totalEnrollments,
          cachedCompletions: cachedMetrics.totalCompletions,
          actualCompletions: totalCompletions,
          detectedAt: Date.now(),
        });

        // Update cached metrics
        await ctx.db.patch(cachedMetrics._id, {
          totalEnrollments,
          totalCompletions,
          lastReconciledAt: Date.now(),
        });

        return {
          mismatchFound: true,
          corrected: true,
        };
      }
    }

    return {
      mismatchFound: false,
    };
  },
});
```

---

## 5.10 Learning Paths Edge Cases (v2.1)

### EC-LP-001: Path Course Removed
**Scenario**: Course in path is unpublished/deleted while users are enrolled

**Prevention**:
- Soft delete courses instead of hard delete
- Maintain enrollments even when course is inactive
- Block new enrollments but preserve existing ones

**Recovery**:
- Skip archived step in progress calculation
- Adjust progress percentage dynamically
- Notify affected users about change
- Continue path without removed course

---

### EC-LP-002: Sequential Unlock Race Condition
**Scenario**: User completes course while another unlock check runs simultaneously

**Prevention**:
- Optimistic locking on step completion status
- Atomic step unlock mutations
- Version field on userPathEnrollments

**Recovery**:
- Check if already completed (idempotency)
- Atomic update with version increment
- Recheck and correct state if conflict
- Trigger next step unlocks after completion

---

### EC-LP-003: Bundle Price Change Mid-Purchase
**Scenario**: Bundle price updates while user is in Stripe checkout

**Prevention**:
- Lock price in Stripe checkout session metadata
- Store original price in session
- Honor original price even if bundle updated

**Recovery**:
- Use locked price from metadata, not current path price
- Log price discrepancies for audit
- Apply original discount shown at checkout
- User pays price they saw when starting checkout

---

### EC-LP-004: Certificate Generation Failure
**Scenario**: PDF generation service unavailable when user completes path

**Prevention**:
- Retry queue with exponential backoff (5s, 30s, 5m, 30m, 2h)
- Status tracking (pending, generating, completed, failed)
- Async generation with user notification

**Recovery**:
- Show "Certificate generating..." state in UI
- Email certificate when generation completes
- Queue failed attempts for admin review
- Manual regeneration option for admins

---

### EC-LP-005: Time-Based Unlock Timezone Issues
**Scenario**: User in different timezone than scheduled unlock time

**Prevention**:
- Store all timestamps in UTC
- Display in user's local timezone
- Use consistent timezone for all unlock calculations

**Recovery**:
- Calculate unlock time from enrollment date + days (UTC)
- Frontend converts UTC to user's timezone for display
- Email notifications respect user's timezone setting
- Unlock checks run on UTC timestamps

---

### EC-LP-006: Duplicate Path Enrollment
**Scenario**: User tries to enroll in path they already have

**Prevention**:
- Unique constraint on userId + pathId
- Check for existing enrollment before checkout
- Return existing enrollment if found

**Recovery**:
- Redirect to existing enrollment dashboard
- Show current progress and status
- No duplicate charge or enrollment creation
- Clear message: "You're already enrolled"

---

## 5.11 Community Edge Cases (v2.1)

### EC-CM-001: Thread Spam Flood
**Scenario**: User creates many threads rapidly (spam attack)

**Prevention**:
- Rate limit: 5 threads per hour per user
- Track creation timestamps
- Auto-flag if threshold exceeded

**Recovery**:
- Soft block user from creating threads
- Add to admin review queue
- Show clear rate limit error message
- Temporary 1-hour cooldown period

---

### EC-CM-002: Reply to Locked Thread
**Scenario**: User submits reply as thread gets locked simultaneously

**Prevention**:
- Recheck lock status in mutation (atomic check)
- Get fresh thread data inside transaction
- Validate thread status before reply creation

**Recovery**:
- Reject with "THREAD_LOCKED" error
- Clear message about lock status
- Don't lose user's typed content (handle gracefully in UI)
- Allow copy of reply text before closing error

---

### EC-CM-003: Self-Connection Request
**Scenario**: User accidentally requests connection with themselves

**Prevention**:
- Validation: reject if userId === connectedUserId
- Client-side validation to hide self from suggestions
- Clear error message

**Recovery**:
- Immediate rejection with clear error
- Message: "You cannot connect with yourself"
- No connection record created
- Hide own profile from connection suggestions

---

### EC-CM-004: Connection Request Spam
**Scenario**: User mass-sends connection requests (spam behavior)

**Prevention**:
- Rate limit: 20 requests per day
- Track daily request count
- Temporary block from sending after threshold

**Recovery**:
- Block for 24 hours after 20 requests
- Show hours remaining in block message
- Add to spam monitoring dashboard
- Admin can review and adjust block

---

### EC-CM-005: Moderator Action Conflict
**Scenario**: Two moderators act on same thread simultaneously (lock, pin, etc.)

**Prevention**:
- Optimistic locking with version field
- Log all moderator actions (full audit trail)
- Last write wins strategy

**Recovery**:
- Both actions logged with timestamps
- Most recent action takes effect
- View moderation history shows all actions
- Detect conflicts (actions within 5 seconds)
- No data loss, complete audit trail maintained

---

### EC-CM-006: External Community Sync Failure
**Scenario**: Circle/Discord webhook fails, members out of sync

**Prevention**:
- Retry queue with exponential backoff (5s, 30s, 5m)
- Local state is source of truth (platform access independent)
- Track sync status per membership

**Recovery**:
- Continue local access regardless of sync status
- Show sync status indicator in UI (success/failed/pending)
- Queue failed syncs for manual review
- Manual sync trigger for admins
- Notify admins after max retries exceeded

---

## 5.12 Skills & Competencies Edge Cases (v2.1)

### EC-SK-001: Duplicate Evidence Submission
**Scenario**: User submits same competency evidence twice

**Prevention**: Idempotency key on evidence content hash

**Recovery**: Return existing evidence record

---

### EC-SK-002: Skill Level Race Condition
**Scenario**: Concurrent evidence submissions trigger multiple level advances

**Prevention**: Atomic level check + update in single mutation

**Recovery**: Latest level wins, dedup badges

---

### EC-SK-003: Badge Verification Failure
**Scenario**: Open Badges 3.0 verification endpoint unavailable

**Prevention**: Local verification + async external

**Recovery**: Retry with exponential backoff

---

### EC-SK-004: Circular Skill Prerequisites
**Scenario**: Admin creates circular prerequisite chain

**Prevention**: DAG validation on save

**Recovery**: Reject with clear error

---

### EC-SK-005: Orphaned Competency Progress
**Scenario**: Skill deleted while user has progress

**Prevention**: Soft delete with cascade check

**Recovery**: Archive progress, maintain badges

---

### EC-SK-006: AI Suggestion Cold Start
**Scenario**: New user with no skill data

**Prevention**: Default recommendations from ICP

**Recovery**: Use course enrollment as proxy

---

## 5.13 Resource Library Edge Cases (v2.1)

### EC-RS-001: Access Tier Downgrade
**Scenario**: User loses premium access, has premium bookmarks

**Prevention**: Graceful degradation

**Recovery**: Show locked state, offer upgrade

---

### EC-RS-002: Prompt Variable Missing
**Scenario**: Prompt template has {{variable}} user doesn't provide

**Prevention**: Required variable validation

**Recovery**: Highlight missing, show placeholder

---

### EC-RS-003: Glossary Circular References
**Scenario**: Term A relates to Term B relates to Term A

**Prevention**: Allow but cap depth

**Recovery**: Show max 2 levels of related terms

---

### EC-RS-004: Resource File Corruption
**Scenario**: Uploaded resource file corrupted

**Prevention**: Checksum validation on upload

**Recovery**: Notification to admin, show error state

---

### EC-RS-005: Bookmark Limit Exceeded
**Scenario**: User exceeds bookmark quota

**Prevention**: Soft limit with warning

**Recovery**: Oldest auto-archive or upgrade prompt

---

### EC-RS-006: Search Index Stale
**Scenario**: New resource not appearing in search

**Prevention**: Real-time index with Convex

**Recovery**: Manual reindex trigger for admin

---

## Summary

This edge cases documentation covers:

1. **Atomic Capacity Validation** - Race condition prevention with refund + waitlist
2. **Webhook Retry Strategy** - Exponential backoff with Dead Letter Queue
3. **Access Grace Period** - 24-hour extension for in-progress content
4. **B2B Account Merging** - Seamless migration from B2C to B2B with conflict resolution
5. **Payment Edge Cases** - Comprehensive handling of payment failures and edge cases
6. **Integration Failures** - Graceful degradation for all external services
7. **Error Codes** - Standardized error system with user-friendly messages
8. **Assessment Edge Cases** - Timeout handling, AI grading fallbacks, learning gain calculation, rubric versioning, and concurrent sessions
9. **Manager Dashboard Edge Cases** - Privacy opt-out, team member offboarding, report generation, skills gaps, permission changes, GDPR exports, and analytics reconciliation
10. **Learning Paths Edge Cases (v2.1)** - Course removal, sequential unlocks, bundle pricing, certificates, timezones, duplicate enrollments
11. **Community Edge Cases (v2.1)** - Thread spam, locked threads, self-connections, connection spam, moderator conflicts, external sync failures
12. **Skills & Competencies Edge Cases (v2.1)** - Duplicate evidence, race conditions, badge verification, circular prerequisites, orphaned progress, cold start recommendations
13. **Resource Library Edge Cases (v2.1)** - Access tier downgrades, prompt variable validation, glossary circular references, file corruption, bookmark limits, search indexing
14. **Accessibility Edge Cases (v2.1)** - Screen reader focus traps, dynamic content announcements, keyboard navigation, form validation, video captions, color-blind support, touch targets, motion sickness prevention

All implementations follow production-ready patterns with proper error handling, monitoring, and user communication, including WCAG 2.1 AAA accessibility standards.

---

## 5.14 Accessibility Edge Cases (v2.1)

### EC-A11Y-001: Screen Reader Focus Trap in Modal
**Scenario**: User with screen reader gets stuck in modal, cannot navigate away or close

**Prevention**:
- Implement focus trap with `aria-modal="true"` and `role="dialog"`
- Provide escape key handler (ESC to close)
- Maintain focus order within modal only
- Set initial focus on modal title or first interactive element

**Recovery**:
- Visible close button with clear label ("Close dialog")
- Keyboard shortcut announced via `aria-describedby`
- Return focus to trigger element on close
- Announce modal state changes with `aria-live="polite"`

**Implementation**:
```typescript
// app/components/AccessibleModal.tsx
export function AccessibleModal({ isOpen, onClose, title, children }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocusRef.current = document.activeElement as HTMLElement;
      modalRef.current?.focus();
    } else {
      previousFocusRef.current?.focus();
    }
  }, [isOpen]);

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    }
  };

  return (
    <div
      ref={modalRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      aria-describedby="modal-description"
      tabIndex={-1}
      onKeyDown={handleKeyDown}
      className="modal"
    >
      <h2 id="modal-title">{title}</h2>
      <p id="modal-description" className="sr-only">
        Press Escape to close this dialog
      </p>
      <button onClick={onClose} aria-label="Close dialog">
        <X aria-hidden="true" />
      </button>
      {children}
    </div>
  );
}
```

---

### EC-A11Y-002: Dynamic Content Not Announced
**Scenario**: Live content updates (new messages, notifications, progress) not read by screen reader

**Prevention**:
- Use `aria-live` regions appropriately
- `aria-live="polite"` for most updates (wait for pause)
- `aria-live="assertive"` only for critical alerts
- `aria-atomic="true"` to announce entire region

**Recovery**:
- Provide manual refresh option (button)
- Visual indicators alongside live regions (status icons)
- Option to view update history

**Implementation**:
```typescript
// app/components/LiveRegion.tsx
export function LiveRegion({ message, priority = "polite" }) {
  return (
    <div
      role="status"
      aria-live={priority}
      aria-atomic="true"
      className="sr-only"
    >
      {message}
    </div>
  );
}

// Usage: New message in chat
<LiveRegion message={`New message from ${user.name}: ${message.content}`} />

// Usage: Progress update
<LiveRegion message={`Course progress updated: ${progress}% complete`} />
```

---

### EC-A11Y-003: Keyboard Navigation Broken After SPA Navigation
**Scenario**: Focus lost after client-side route change in Next.js app

**Prevention**:
- Programmatically focus main content after navigation
- Use Next.js router events to detect route change
- Skip link always returns to predictable location

**Recovery**:
- Focus on page title or main heading after navigation
- Announce page change to screen readers
- Skip link at top of every page

**Implementation**:
```typescript
// app/components/SkipLink.tsx
export function SkipLink() {
  return (
    <a
      href="#main-content"
      className="skip-link sr-only focus:not-sr-only"
    >
      Skip to main content
    </a>
  );
}

// app/hooks/useFocusManagement.ts
export function useFocusManagement() {
  const router = useRouter();

  useEffect(() => {
    const handleRouteChange = () => {
      const mainContent = document.getElementById('main-content');
      if (mainContent) {
        mainContent.focus();
        mainContent.scrollIntoView();
      }
    };

    router.events.on('routeChangeComplete', handleRouteChange);
    return () => router.events.off('routeChangeComplete', handleRouteChange);
  }, [router]);
}

// app/layout.tsx
<main id="main-content" tabIndex={-1}>
  {children}
</main>
```

---

### EC-A11Y-004: Form Validation Errors Not Accessible
**Scenario**: Error messages displayed but not associated with inputs, screen reader cannot find them

**Prevention**:
- Use `aria-describedby` linking errors to fields
- Add `aria-invalid="true"` to invalid inputs
- Provide clear error text, not just color/icon

**Recovery**:
- Error summary at top of form with links to invalid fields
- Focus on first invalid field on submit
- Each error has unique ID linked via `aria-describedby`

**Implementation**:
```typescript
// app/components/AccessibleForm.tsx
export function AccessibleFormField({ id, label, error, ...inputProps }) {
  const errorId = `${id}-error`;

  return (
    <div className="form-field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        aria-describedby={error ? errorId : undefined}
        aria-invalid={error ? "true" : undefined}
        {...inputProps}
      />
      {error && (
        <p id={errorId} role="alert" className="error-message">
          {error}
        </p>
      )}
    </div>
  );
}

// Error summary component
export function FormErrorSummary({ errors }) {
  return (
    <div role="alert" aria-labelledby="error-summary-title">
      <h2 id="error-summary-title">There are {errors.length} errors in this form</h2>
      <ul>
        {errors.map((error) => (
          <li key={error.fieldId}>
            <a href={`#${error.fieldId}`}>{error.message}</a>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

### EC-A11Y-005: Video Without Captions
**Scenario**: Deaf user cannot access video content (workshop recordings, demos)

**Prevention**:
- Require captions for all video uploads (validation rule)
- Auto-generate captions with Whisper AI if none provided
- Support .vtt and .srt caption file formats

**Recovery**:
- Show transcript alternative below video
- Allow manual caption upload after initial publish
- Provide audio description track for blind users

**Implementation**:
```typescript
// app/components/AccessibleVideo.tsx
export function AccessibleVideo({ videoUrl, captionUrl, transcriptUrl }) {
  return (
    <div className="video-container">
      <video controls aria-describedby="video-transcript">
        <source src={videoUrl} type="video/mp4" />
        {captionUrl && (
          <track
            kind="captions"
            src={captionUrl}
            srcLang="en"
            label="English captions"
            default
          />
        )}
        Your browser does not support the video tag.
      </video>
      {transcriptUrl && (
        <details>
          <summary>View video transcript</summary>
          <div id="video-transcript">
            <iframe src={transcriptUrl} title="Video transcript" />
          </div>
        </details>
      )}
    </div>
  );
}

// convex/videos/validation.ts
export const validateVideoUpload = mutation({
  args: {
    videoUrl: v.string(),
    captionUrl: v.optional(v.string()),
  },
  handler: async (ctx, { videoUrl, captionUrl }) => {
    if (!captionUrl) {
      // Queue for auto-caption generation
      await ctx.scheduler.runAfter(0, internal.ai.generateCaptions, {
        videoUrl,
      });

      return {
        status: "pending_captions",
        message: "Captions are being generated automatically",
      };
    }

    return { status: "ready" };
  },
});
```

---

### EC-A11Y-006: Color-Only Status Indicators
**Scenario**: Color-blind user cannot distinguish status (red/yellow/green progress)

**Prevention**:
- Use icons + text + color for all statuses
- Never rely on color alone for information
- Sufficient color contrast (WCAG AAA: 7:1)

**Recovery**:
- Provide text tooltip on hover/focus
- Use patterns/textures in addition to color
- Allow user to customize status colors

**Implementation**:
```typescript
// app/components/AccessibleStatus.tsx
const STATUS_CONFIG = {
  completed: {
    color: 'text-green-700',
    icon: CheckCircle,
    label: 'Completed',
  },
  in_progress: {
    color: 'text-yellow-700',
    icon: Clock,
    label: 'In Progress',
  },
  not_started: {
    color: 'text-gray-700',
    icon: Circle,
    label: 'Not Started',
  },
  blocked: {
    color: 'text-red-700',
    icon: AlertCircle,
    label: 'Blocked',
  },
};

export function AccessibleStatus({ status }) {
  const config = STATUS_CONFIG[status];
  const Icon = config.icon;

  return (
    <span className={`status ${config.color}`}>
      <Icon aria-hidden="true" />
      <span>{config.label}</span>
    </span>
  );
}
```

---

### EC-A11Y-007: Touch Target Too Small on Mobile
**Scenario**: User with motor impairment cannot tap buttons accurately

**Prevention**:
- Enforce minimum 44x44px touch targets (WCAG 2.1 AAA)
- Add padding to increase hit area without changing visual size
- Adequate spacing between interactive elements (8px minimum)

**Recovery**:
- Provide alternative larger controls option
- Allow "fat finger" forgiveness (larger invisible hit area)
- Undo/confirm for critical actions

**Implementation**:
```css
/* app/styles/accessibility.css */
.btn {
  min-width: 44px;
  min-height: 44px;
  padding: 12px 24px;
  position: relative;
}

/* Increase hit area without changing visual size */
.btn::before {
  content: '';
  position: absolute;
  top: -8px;
  right: -8px;
  bottom: -8px;
  left: -8px;
}

/* Spacing between touch targets */
.btn + .btn {
  margin-left: 8px;
}

@media (max-width: 768px) {
  .btn {
    min-height: 48px; /* Larger on mobile */
  }
}
```

---

### EC-A11Y-008: Animation Causes Motion Sickness
**Scenario**: User with vestibular disorder gets nauseous from animations (parallax, page transitions)

**Prevention**:
- Respect `prefers-reduced-motion` media query
- Disable animations when preference detected
- Reduce motion globally, not just for decorative animations

**Recovery**:
- Provide global toggle to disable animations
- Store preference in user settings
- Apply to all transitions, scrolling, carousels

**Implementation**:
```typescript
// app/hooks/useReducedMotion.ts
export function useReducedMotion() {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReducedMotion(mediaQuery.matches);

    const handleChange = () => setPrefersReducedMotion(mediaQuery.matches);
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  return prefersReducedMotion;
}

// app/components/AnimatedComponent.tsx
export function AnimatedComponent({ children }) {
  const prefersReducedMotion = useReducedMotion();

  return (
    <motion.div
      animate={{ opacity: 1, y: 0 }}
      initial={{ opacity: 0, y: prefersReducedMotion ? 0 : 20 }}
      transition={{
        duration: prefersReducedMotion ? 0 : 0.3,
      }}
    >
      {children}
    </motion.div>
  );
}

// app/styles/animations.css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

// User settings override
.reduce-motion *,
.reduce-motion *::before,
.reduce-motion *::after {
  animation: none !important;
  transition: none !important;
}
```

---

### Accessibility Testing Checklist

**Automated Testing**:
- Lighthouse accessibility audit (score > 95)
- axe-core automated scans
- WAVE browser extension checks

**Manual Testing**:
- Keyboard-only navigation (Tab, Shift+Tab, Enter, Space, Arrow keys)
- Screen reader testing (NVDA on Windows, VoiceOver on macOS, TalkBack on Android)
- Color contrast validation (WCAG AAA: 7:1)
- Zoom testing (up to 200% browser zoom)
- Mobile touch target testing

**User Testing**:
- Test with actual users with disabilities
- Diverse assistive technology (screen readers, magnifiers, switch controls)
- Feedback loop for continuous improvement
