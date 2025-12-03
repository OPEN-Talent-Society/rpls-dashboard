# 2.3 System Flows & Infrastructure

## 2.3.1 Webhook Processing Flow with Retry & DLQ

```pseudocode
FLOW: WEBHOOK_PROCESSING

// Endpoint: /api/webhooks/[provider]
// Providers: stripe, cal, formbricks, custom

FUNCTION handleWebhook(provider, request):
  // Step 1: Receive and Verify
  TRY:
    rawBody = request.rawBody
    signature = request.headers['stripe-signature'] OR
                request.headers['cal-signature'] OR
                request.headers['x-webhook-signature']

    // Provider-specific signature verification
    SWITCH provider:
      CASE 'stripe':
        event = stripe.webhooks.constructEvent(rawBody, signature, STRIPE_WEBHOOK_SECRET)
      CASE 'cal':
        isValid = verifyCalSignature(rawBody, signature, CAL_WEBHOOK_SECRET)
        IF NOT isValid: THROW InvalidSignatureError
        event = JSON.parse(rawBody)
      CASE 'formbricks':
        isValid = verifyHMAC(rawBody, signature, FORMBRICKS_WEBHOOK_SECRET)
        IF NOT isValid: THROW InvalidSignatureError
        event = JSON.parse(rawBody)
      CASE 'custom':
        isValid = verifyHMAC(rawBody, signature, CUSTOM_WEBHOOK_SECRET)
        IF NOT isValid: THROW InvalidSignatureError
        event = JSON.parse(rawBody)

    // Step 2: Create delivery record
    deliveryId = db.webhookDeliveries.insert({
      provider: provider,
      eventType: event.type,
      payload: event,
      status: "processing",
      attempts: 1,
      createdAt: now(),
      updatedAt: now(),
      signature: signature,
      rawBody: rawBody
    })

    // Step 3: Process event
    result = processWebhookEvent(provider, event, deliveryId)

    // Step 4: Handle success
    db.webhookDeliveries.update(deliveryId, {
      status: "delivered",
      deliveredAt: now(),
      updatedAt: now(),
      response: result
    })

    RETURN { success: true, deliveryId: deliveryId }

  CATCH error:
    // Step 5: Handle failure with retry logic
    RETURN handleWebhookFailure(deliveryId, error)

// Webhook event router
FUNCTION processWebhookEvent(provider, event, deliveryId):
  SWITCH provider:
    CASE 'stripe':
      RETURN handleStripeEvent(event, deliveryId)
    CASE 'cal':
      RETURN handleCalEvent(event, deliveryId)
    CASE 'formbricks':
      RETURN handleFormbricksEvent(event, deliveryId)
    CASE 'custom':
      RETURN handleCustomEvent(event, deliveryId)

// Stripe webhook handler
FUNCTION handleStripeEvent(event, deliveryId):
  SWITCH event.type:
    CASE 'checkout.session.completed':
      session = event.data.object
      enrollmentId = session.metadata.enrollmentId

      // Update enrollment payment status
      db.enrollments.update(enrollmentId, {
        paymentStatus: "paid",
        paymentMethod: session.payment_method_types[0],
        paidAt: now()
      })

      // Send confirmation email
      sendEmail({
        to: session.customer_email,
        template: "enrollment-confirmed",
        data: { enrollmentId: enrollmentId }
      })

      // Create certificate if applicable
      enrollment = db.enrollments.get(enrollmentId)
      IF enrollment.status === "completed":
        issueCertificate(enrollmentId)

      RETURN { processed: true, action: "enrollment_payment_confirmed" }

    CASE 'payment_intent.payment_failed':
      paymentIntent = event.data.object
      enrollmentId = paymentIntent.metadata.enrollmentId

      // Mark payment as failed
      db.enrollments.update(enrollmentId, {
        paymentStatus: "failed",
        paymentError: paymentIntent.last_payment_error.message
      })

      // Send failure notification
      sendEmail({
        to: paymentIntent.receipt_email,
        template: "payment-failed",
        data: { enrollmentId: enrollmentId, error: paymentIntent.last_payment_error }
      })

      RETURN { processed: true, action: "payment_failed_notification_sent" }

    CASE 'customer.subscription.deleted':
      subscription = event.data.object
      orgId = subscription.metadata.orgId

      // Downgrade organization access
      db.organizations.update(orgId, {
        subscriptionStatus: "canceled",
        subscriptionEndDate: subscription.ended_at,
        tier: "free"
      })

      // Notify org admins
      admins = db.users.query({ organizationId: orgId, role: "admin" })
      FOR admin IN admins:
        sendEmail({
          to: admin.email,
          template: "subscription-canceled",
          data: { orgName: db.organizations.get(orgId).name }
        })

      RETURN { processed: true, action: "subscription_canceled" }

    DEFAULT:
      LOG.info("Unhandled Stripe event type: " + event.type)
      RETURN { processed: false, reason: "unhandled_event_type" }

// Cal.com webhook handler
FUNCTION handleCalEvent(event, deliveryId):
  SWITCH event.type:
    CASE 'BOOKING_CREATED':
      booking = event.data

      // Create booking record
      bookingId = db.bookings.insert({
        calBookingId: booking.id,
        userId: booking.metadata.userId,
        cohortId: booking.metadata.cohortId,
        startTime: booking.startTime,
        endTime: booking.endTime,
        status: "confirmed",
        createdAt: now()
      })

      // Send confirmation email
      user = db.users.get(booking.metadata.userId)
      sendEmail({
        to: user.email,
        template: "booking-confirmed",
        data: { booking: booking, calendarLink: booking.metadata.addToCalendarUrl }
      })

      RETURN { processed: true, action: "booking_created", bookingId: bookingId }

    CASE 'BOOKING_CANCELLED':
      booking = event.data

      // Update booking status
      db.bookings.update({ calBookingId: booking.id }, {
        status: "canceled",
        canceledAt: now(),
        cancellationReason: booking.cancellationReason
      })

      // Send cancellation notification
      user = db.users.get(booking.metadata.userId)
      sendEmail({
        to: user.email,
        template: "booking-canceled",
        data: { booking: booking }
      })

      RETURN { processed: true, action: "booking_canceled" }

    CASE 'BOOKING_RESCHEDULED':
      booking = event.data

      // Update booking times
      db.bookings.update({ calBookingId: booking.id }, {
        startTime: booking.startTime,
        endTime: booking.endTime,
        rescheduledAt: now()
      })

      // Send reschedule notification
      user = db.users.get(booking.metadata.userId)
      sendEmail({
        to: user.email,
        template: "booking-rescheduled",
        data: { booking: booking }
      })

      RETURN { processed: true, action: "booking_rescheduled" }

    DEFAULT:
      LOG.info("Unhandled Cal.com event type: " + event.type)
      RETURN { processed: false, reason: "unhandled_event_type" }

// Formbricks webhook handler
FUNCTION handleFormbricksEvent(event, deliveryId):
  SWITCH event.type:
    CASE 'response.created':
      response = event.data

      // Store survey response
      responseId = db.surveyResponses.insert({
        formbricksResponseId: response.id,
        surveyId: response.surveyId,
        userId: response.metadata.userId,
        cohortId: response.metadata.cohortId,
        responses: response.data,
        completedAt: response.finished ? now() : null,
        createdAt: now()
      })

      // Trigger post-survey automation if completed
      IF response.finished:
        surveyType = response.metadata.surveyType

        SWITCH surveyType:
          CASE 'post-cohort-feedback':
            // Mark enrollment as surveyed
            enrollment = db.enrollments.get(response.metadata.enrollmentId)
            db.enrollments.update(enrollment.id, {
              feedbackSubmitted: true,
              feedbackSubmittedAt: now()
            })

            // Trigger certificate issuance if all criteria met
            IF enrollment.status === "completed" AND enrollment.paymentStatus === "paid":
              issueCertificate(enrollment.id)

          CASE 'nps-survey':
            // Calculate NPS score
            npsScore = response.data.score

            // Store NPS response
            db.npsResponses.insert({
              userId: response.metadata.userId,
              score: npsScore,
              comment: response.data.comment,
              createdAt: now()
            })

            // Trigger follow-up for detractors (0-6)
            IF npsScore <= 6:
              sendEmail({
                to: db.users.get(response.metadata.userId).email,
                template: "nps-detractor-followup",
                data: { score: npsScore, comment: response.data.comment }
              })

      RETURN { processed: true, action: "survey_response_stored", responseId: responseId }

    DEFAULT:
      LOG.info("Unhandled Formbricks event type: " + event.type)
      RETURN { processed: false, reason: "unhandled_event_type" }

// Failure handling with exponential backoff
FUNCTION handleWebhookFailure(deliveryId, error):
  delivery = db.webhookDeliveries.get(deliveryId)
  attempts = delivery.attempts

  // Calculate next retry time (exponential backoff: 1s, 10s, 100s)
  backoffSeconds = Math.pow(10, attempts - 1)
  nextRetryAt = now() + (backoffSeconds * 1000)

  IF attempts < 3:
    // Queue for retry
    db.webhookDeliveries.update(deliveryId, {
      status: "pending",
      attempts: attempts + 1,
      nextRetryAt: nextRetryAt,
      lastError: error.message,
      updatedAt: now()
    })

    LOG.warn("Webhook delivery " + deliveryId + " failed, retry " + attempts + " scheduled for " + nextRetryAt)

    RETURN {
      success: false,
      retryScheduled: true,
      nextRetryAt: nextRetryAt,
      deliveryId: deliveryId
    }
  ELSE:
    // Max retries exceeded - move to DLQ
    db.webhookDeliveries.update(deliveryId, {
      status: "failed",
      failedAt: now(),
      updatedAt: now(),
      lastError: error.message
    })

    // Send admin notification
    sendEmail({
      to: ADMIN_EMAIL,
      template: "webhook-failed",
      data: {
        deliveryId: deliveryId,
        provider: delivery.provider,
        eventType: delivery.eventType,
        attempts: attempts,
        error: error.message,
        dashboardUrl: ADMIN_DASHBOARD_URL + "/webhooks/" + deliveryId
      }
    })

    LOG.error("Webhook delivery " + deliveryId + " failed permanently after " + attempts + " attempts")

    RETURN {
      success: false,
      permanentFailure: true,
      deliveryId: deliveryId,
      error: error.message
    }

// Signature verification helpers
FUNCTION verifyCalSignature(rawBody, signature, secret):
  expectedSignature = crypto.createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex')

  RETURN crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  )

FUNCTION verifyHMAC(rawBody, signature, secret):
  expectedSignature = crypto.createHmac('sha256', secret)
    .update(rawBody)
    .digest('base64')

  RETURN crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  )
```

## 2.3.2 Webhook Retry Cron Job

```pseudocode
CRON: WEBHOOK_RETRY_PROCESSOR
SCHEDULE: Every 1 minute
EXECUTOR: Convex built-in scheduler

FUNCTION processWebhookRetries():
  // Query pending webhooks ready for retry
  pendingWebhooks = db.webhookDeliveries.query({
    status: "pending",
    nextRetryAt: { $lte: now() }
  }).limit(100)  // Process in batches to avoid timeout

  LOG.info("Processing " + pendingWebhooks.length + " pending webhook retries")

  FOR delivery IN pendingWebhooks:
    TRY:
      // Re-attempt processing
      event = delivery.payload
      result = processWebhookEvent(delivery.provider, event, delivery.id)

      // Mark as delivered on success
      db.webhookDeliveries.update(delivery.id, {
        status: "delivered",
        deliveredAt: now(),
        updatedAt: now(),
        response: result
      })

      LOG.info("Webhook delivery " + delivery.id + " succeeded on retry " + delivery.attempts)

    CATCH error:
      // Handle retry failure (will increment attempts or move to DLQ)
      handleWebhookFailure(delivery.id, error)

  RETURN { processed: pendingWebhooks.length }
```

## 2.3.3 Hybrid Cron Orchestration (Convex + n8n)

```pseudocode
// ========================================
// CONVEX BUILT-IN CRONS
// ========================================

CRON: SEND_COHORT_REMINDERS
SCHEDULE: Daily at 6:00 AM PT (14:00 UTC)
EXECUTOR: Convex built-in scheduler

FUNCTION sendCohortReminders():
  today = getToday()

  // Find cohorts starting in 7, 2, or 1 day(s)
  upcomingCohorts = db.cohorts.query({
    startDate: { $in: [
      today + 7.days,
      today + 2.days,
      today + 1.day
    ]},
    status: "published"
  })

  FOR cohort IN upcomingCohorts:
    daysUntilStart = (cohort.startDate - today).days

    // Get all enrolled learners
    enrollments = db.enrollments.query({
      cohortId: cohort.id,
      status: { $in: ["confirmed", "active"] }
    })

    FOR enrollment IN enrollments:
      user = db.users.get(enrollment.userId)

      // Send reminder email
      sendEmail({
        to: user.email,
        template: "cohort-reminder-t-" + daysUntilStart,
        data: {
          userName: user.firstName,
          cohortName: cohort.name,
          cohortStartDate: cohort.startDate,
          cohortStartTime: cohort.startTime,
          daysUntilStart: daysUntilStart,
          cohortUrl: PLATFORM_URL + "/cohorts/" + cohort.id,
          calendarUrl: cohort.calendarUrl,
          prepMaterials: cohort.prepMaterials
        }
      })

    LOG.info("Sent T-" + daysUntilStart + " reminders for cohort " + cohort.id + " to " + enrollments.length + " learners")

  RETURN { cohorts: upcomingCohorts.length, reminders: totalSent }

// ========================================

CRON: CHECK_ACCESS_EXPIRY
SCHEDULE: Daily at 7:00 AM PT (15:00 UTC)
EXECUTOR: Convex built-in scheduler

FUNCTION checkAccessExpiry():
  today = getToday()
  warningDate = today + 30.days

  // Find enrollments expiring in 30 days
  expiringEnrollments = db.enrollments.query({
    accessExpiryDate: warningDate,
    status: "active"
  })

  FOR enrollment IN expiringEnrollments:
    user = db.users.get(enrollment.userId)
    cohort = db.cohorts.get(enrollment.cohortId)

    // Send expiry warning
    sendEmail({
      to: user.email,
      template: "access-expiring-warning",
      data: {
        userName: user.firstName,
        cohortName: cohort.name,
        expiryDate: enrollment.accessExpiryDate,
        daysRemaining: 30,
        renewUrl: PLATFORM_URL + "/enrollments/" + enrollment.id + "/renew"
      }
    })

  // Find enrollments that expired today
  expiredEnrollments = db.enrollments.query({
    accessExpiryDate: today,
    status: "active"
  })

  FOR enrollment IN expiredEnrollments:
    // Mark as expired
    db.enrollments.update(enrollment.id, {
      status: "expired",
      expiredAt: now()
    })

    user = db.users.get(enrollment.userId)
    cohort = db.cohorts.get(enrollment.cohortId)

    // Send expiry notification
    sendEmail({
      to: user.email,
      template: "access-expired",
      data: {
        userName: user.firstName,
        cohortName: cohort.name,
        renewUrl: PLATFORM_URL + "/enrollments/" + enrollment.id + "/renew"
      }
    })

  RETURN {
    warnings: expiringEnrollments.length,
    expired: expiredEnrollments.length
  }

// ========================================

CRON: RUN_POST_COHORT_AUTOMATION
SCHEDULE: Daily at 8:00 AM PT (16:00 UTC)
EXECUTOR: Convex built-in scheduler

FUNCTION runPostCohortAutomation():
  today = getToday()
  yesterday = today - 1.day

  // Find cohorts that ended yesterday
  completedCohorts = db.cohorts.query({
    endDate: yesterday,
    status: "active"
  })

  FOR cohort IN completedCohorts:
    // Mark cohort as completed
    db.cohorts.update(cohort.id, {
      status: "completed",
      completedAt: now()
    })

    // Get all enrollments
    enrollments = db.enrollments.query({
      cohortId: cohort.id,
      status: "active"
    })

    FOR enrollment IN enrollments:
      user = db.users.get(enrollment.userId)

      // Mark enrollment as completed
      db.enrollments.update(enrollment.id, {
        status: "completed",
        completedAt: now()
      })

      // Send post-cohort survey
      surveyUrl = createFormbricksSurvey({
        surveyId: "post-cohort-feedback",
        userId: user.id,
        cohortId: cohort.id,
        enrollmentId: enrollment.id
      })

      sendEmail({
        to: user.email,
        template: "post-cohort-survey",
        data: {
          userName: user.firstName,
          cohortName: cohort.name,
          surveyUrl: surveyUrl
        }
      })

      // If payment confirmed, issue certificate
      IF enrollment.paymentStatus === "paid":
        issueCertificate(enrollment.id)

    LOG.info("Completed post-cohort automation for " + cohort.name + " (" + enrollments.length + " enrollments)")

  RETURN { cohorts: completedCohorts.length, enrollments: totalEnrollments }

// ========================================

CRON: PROCESS_WAITLIST_OFFER_EXPIRY
SCHEDULE: Every 1 minute
EXECUTOR: Convex built-in scheduler

FUNCTION processWaitlistOfferExpiry():
  now = getCurrentTime()

  // Find expired offers
  expiredOffers = db.waitlistOffers.query({
    status: "pending",
    expiresAt: { $lte: now }
  })

  FOR offer IN expiredOffers:
    // Mark offer as expired
    db.waitlistOffers.update(offer.id, {
      status: "expired",
      expiredAt: now
    })

    // Decrement enrollment count (seat becomes available)
    cohort = db.cohorts.get(offer.cohortId)
    db.cohorts.update(cohort.id, {
      enrolledCount: cohort.enrolledCount - 1
    })

    // Send next waitlist offer if available
    nextWaitlistEntry = db.waitlist.query({
      cohortId: offer.cohortId,
      status: "waiting"
    }).order("createdAt", "asc").first()

    IF nextWaitlistEntry:
      sendWaitlistOffer(nextWaitlistEntry.id)

  RETURN { expired: expiredOffers.length }

// ========================================
// n8n WORKFLOW INTEGRATIONS
// ========================================

CRON: TRIGGER_EXECUTIVE_REPORTS
SCHEDULE: Weekly Sunday at 10:00 PM PT (Monday 06:00 UTC)
EXECUTOR: Convex built-in scheduler

FUNCTION triggerExecutiveReports():
  // Get all B2B organizations
  organizations = db.organizations.query({
    type: "enterprise",
    subscriptionStatus: "active"
  })

  // Trigger n8n workflow
  response = httpAction({
    url: N8N_WEBHOOK_URL + "/executive-reports",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-N8N-API-KEY": N8N_API_KEY
    },
    body: {
      organizations: organizations.map(org => ({
        id: org.id,
        name: org.name,
        adminEmails: org.adminEmails
      })),
      reportPeriod: "weekly",
      generatedBy: "convex-cron",
      timestamp: now()
    }
  })

  LOG.info("Triggered executive report generation for " + organizations.length + " organizations")

  RETURN { organizations: organizations.length, n8nWorkflowId: response.workflowId }

// n8n workflow callback handler
ENDPOINT: /api/n8n/executive-reports/callback
METHOD: POST

FUNCTION handleExecutiveReportCallback(request):
  // Verify n8n signature
  signature = request.headers['x-n8n-signature']
  isValid = verifyHMAC(request.body, signature, N8N_WEBHOOK_SECRET)

  IF NOT isValid:
    THROW UnauthorizedError("Invalid n8n signature")

  data = request.body

  // Store executive report
  reportId = db.executiveReports.insert({
    organizationId: data.organizationId,
    reportPeriod: data.reportPeriod,
    pdfUrl: data.pdfUrl,
    metrics: data.metrics,
    generatedAt: data.generatedAt,
    createdAt: now()
  })

  // Send report email to org admins
  organization = db.organizations.get(data.organizationId)
  FOR adminEmail IN organization.adminEmails:
    sendEmail({
      to: adminEmail,
      template: "executive-report",
      data: {
        organizationName: organization.name,
        reportPeriod: data.reportPeriod,
        pdfUrl: data.pdfUrl,
        metrics: data.metrics,
        dashboardUrl: PLATFORM_URL + "/admin/reports/" + reportId
      }
    })

  RETURN { success: true, reportId: reportId }

// ========================================

MUTATION: TRIGGER_BULK_CERTIFICATE_GENERATION
EXECUTOR: Admin action (on-demand)

FUNCTION triggerBulkCertificateGeneration(cohortId):
  cohort = db.cohorts.get(cohortId)

  // Get all completed enrollments without certificates
  enrollments = db.enrollments.query({
    cohortId: cohortId,
    status: "completed",
    certificateIssued: false,
    paymentStatus: "paid"
  })

  // Trigger n8n workflow for bulk generation
  response = httpAction({
    url: N8N_WEBHOOK_URL + "/bulk-certificates",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-N8N-API-KEY": N8N_API_KEY
    },
    body: {
      cohortId: cohortId,
      cohortName: cohort.name,
      enrollments: enrollments.map(e => ({
        id: e.id,
        userId: e.userId,
        userName: db.users.get(e.userId).name,
        completedAt: e.completedAt
      })),
      template: "cohort-completion",
      triggeredBy: ctx.userId,
      timestamp: now()
    }
  })

  LOG.info("Triggered bulk certificate generation for " + enrollments.length + " enrollments")

  RETURN {
    enrollments: enrollments.length,
    n8nWorkflowId: response.workflowId
  }

// n8n callback for certificate generation
ENDPOINT: /api/n8n/certificates/callback
METHOD: POST

FUNCTION handleCertificateCallback(request):
  data = request.body

  FOR certificate IN data.certificates:
    // Update enrollment with certificate data
    db.enrollments.update(certificate.enrollmentId, {
      certificateIssued: true,
      certificateUrl: certificate.pdfUrl,
      certificateIssuedAt: now()
    })

    // Send certificate email
    user = db.users.get(certificate.userId)
    sendEmail({
      to: user.email,
      template: "certificate-issued",
      data: {
        userName: user.firstName,
        cohortName: certificate.cohortName,
        certificateUrl: certificate.pdfUrl,
        linkedInShareUrl: generateLinkedInShareUrl(certificate)
      }
    })

  RETURN { success: true, certificates: data.certificates.length }

// ========================================
// COORDINATION PATTERN
// ========================================

/*
CONVEX → n8n → CONVEX FLOW:

1. Convex cron triggers n8n webhook
   - Sends data payload
   - Includes callback URL
   - Signs request with shared secret

2. n8n executes complex workflow
   - Multi-step processing
   - External API calls
   - PDF generation
   - File uploads
   - Data transformations

3. n8n calls Convex HTTP action with results
   - POST to /api/n8n/[workflow]/callback
   - Includes signed payload
   - Returns processing results

4. Convex updates database
   - Stores results
   - Triggers follow-up actions
   - Sends notifications

BENEFITS:
- Complex workflows in n8n (visual, easy to modify)
- Simple triggers in Convex (database access)
- Reliable coordination via webhooks
- Signature verification for security
*/
```

## 2.3.4 Real-Time Subscriptions Flow

```pseudocode
FLOW: REAL_TIME_SUBSCRIPTIONS
TRANSPORT: WebSocket (Convex built-in)

// ========================================
// CLIENT-SIDE SUBSCRIPTION
// ========================================

// React component example
COMPONENT: CohortEnrollmentPage

FUNCTION render():
  // Subscribe to real-time query
  cohort = useQuery(api.cohorts.getCohortById, { cohortId: cohortId })
  enrollments = useQuery(api.enrollments.getCohortEnrollments, { cohortId: cohortId })

  // Automatically re-renders when data changes
  // No polling, no manual refresh needed

  RETURN (
    <div>
      <h1>{cohort.name}</h1>
      <p>Capacity: {enrollments.length} / {cohort.capacity}</p>
      <p>Spots remaining: {cohort.capacity - enrollments.length}</p>

      {cohort.capacity - enrollments.length === 0 && (
        <WaitlistButton cohortId={cohortId} />
      )}
    </div>
  )

// ========================================
// SERVER-SIDE QUERY DEFINITION
// ========================================

QUERY: getCohortById
ACCESS: Public (authenticated users)

FUNCTION getCohortById(cohortId):
  cohort = db.cohorts.get(cohortId)

  IF NOT cohort:
    THROW NotFoundError("Cohort not found")

  // Convex tracks this query subscription
  RETURN cohort

QUERY: getCohortEnrollments
ACCESS: Public (authenticated users)

FUNCTION getCohortEnrollments(cohortId):
  enrollments = db.enrollments.query({
    cohortId: cohortId,
    status: { $in: ["confirmed", "active"] }
  })

  // Convex tracks all subscribers to this query
  RETURN enrollments

// ========================================
// DATA MUTATION (TRIGGERS UPDATE)
// ========================================

MUTATION: enrollInCohort
ACCESS: Authenticated

FUNCTION enrollInCohort(cohortId, paymentMethod):
  userId = ctx.userId
  cohort = db.cohorts.get(cohortId)

  // Check capacity
  currentEnrollments = db.enrollments.count({
    cohortId: cohortId,
    status: { $in: ["confirmed", "active"] }
  })

  IF currentEnrollments >= cohort.capacity:
    // Add to waitlist instead
    RETURN addToWaitlist(cohortId, userId)

  // Create enrollment
  enrollmentId = db.enrollments.insert({
    userId: userId,
    cohortId: cohortId,
    status: "pending_payment",
    createdAt: now()
  })

  // Process payment
  paymentResult = processPayment(enrollmentId, paymentMethod)

  IF paymentResult.success:
    db.enrollments.update(enrollmentId, {
      status: "confirmed",
      paymentStatus: "paid",
      paidAt: now()
    })

    // ⚡ THIS TRIGGERS REAL-TIME UPDATE
    // Convex detects that enrollments data changed
    // Pushes update to ALL clients subscribed to:
    // - getCohortEnrollments({ cohortId })
    // - getCohortById({ cohortId }) (via computed capacity)

    RETURN { success: true, enrollmentId: enrollmentId }
  ELSE:
    THROW PaymentError("Payment failed")

// ========================================
// CONVEX REACTIVITY ENGINE
// ========================================

INTERNAL: Convex Reactivity System

WHEN mutation modifies database:
  1. Identify affected table (e.g., enrollments)

  2. Find all active queries that read from this table
     - getCohortEnrollments
     - getUserEnrollments
     - getAdminDashboardStats

  3. For each affected query:
     - Re-run query with current parameters
     - Compare new result to cached result
     - IF different:
       - Push update to subscribed clients via WebSocket

  4. Client receives update:
     - React component re-renders automatically
     - UI updates instantly (< 50ms typical latency)

// ========================================
// USE CASES
// ========================================

USE_CASE_1: Real-time cohort capacity updates
  SCENARIO: User viewing cohort enrollment page

  1. User A opens cohort page at 10:00:00
     - Sees "5 spots remaining"
     - WebSocket subscription active

  2. User B enrolls at 10:00:15
     - Mutation updates enrollments table
     - Convex detects change

  3. User A's page updates at 10:00:15.043
     - Now shows "4 spots remaining"
     - No page refresh needed
     - No polling interval

  TECHNICAL FLOW:
    Client A: useQuery(getCohortEnrollments) → WebSocket subscription
    Client B: useMutation(enrollInCohort) → Database write
    Convex: Detect change → Re-run getCohortEnrollments → Push to Client A
    Client A: Receive update → React re-render → UI update

// ========================================

USE_CASE_2: Admin dashboard real-time metrics
  SCENARIO: Admin monitoring platform activity

  QUERY: getAdminDashboardStats

  FUNCTION getAdminDashboardStats():
    RETURN {
      activeEnrollments: db.enrollments.count({ status: "active" }),
      pendingPayments: db.enrollments.count({ paymentStatus: "pending" }),
      upcomingCohorts: db.cohorts.count({
        startDate: { $gte: today(), $lte: today() + 30.days },
        status: "published"
      }),
      revenueToday: db.enrollments.sum("amount", {
        paidAt: { $gte: startOfDay(today()) }
      }),
      activeUsers: db.users.count({ lastActiveAt: { $gte: now() - 5.minutes } })
    }

  UPDATES IN REAL-TIME WHEN:
  - New enrollment created → activeEnrollments updates
  - Payment completed → pendingPayments decreases, revenueToday increases
  - Cohort published → upcomingCohorts updates
  - User activity → activeUsers updates

// ========================================

USE_CASE_3: Live chat/messaging
  SCENARIO: Cohort discussion forum

  QUERY: getCohortMessages

  FUNCTION getCohortMessages(cohortId):
    RETURN db.messages.query({
      cohortId: cohortId
    }).order("createdAt", "desc").limit(100)

  MUTATION: sendMessage

  FUNCTION sendMessage(cohortId, content):
    messageId = db.messages.insert({
      cohortId: cohortId,
      userId: ctx.userId,
      content: content,
      createdAt: now()
    })

    // ⚡ All users viewing this cohort's chat receive update instantly

    RETURN { messageId: messageId }

  RESULT:
  - User types message and sends
  - All other users see it appear < 100ms
  - No polling, no manual refresh
  - WhatsApp-like experience

// ========================================

USE_CASE_4: Booking confirmations
  SCENARIO: User books office hours via Cal.com

  MUTATION: confirmBooking (called by Cal.com webhook)

  FUNCTION confirmBooking(calBookingId, userId):
    bookingId = db.bookings.insert({
      calBookingId: calBookingId,
      userId: userId,
      status: "confirmed",
      createdAt: now()
    })

    // ⚡ If user has booking page open, it updates instantly

    RETURN { bookingId: bookingId }

  QUERY: getUserBookings

  FUNCTION getUserBookings(userId):
    RETURN db.bookings.query({ userId: userId })
      .order("createdAt", "desc")

  USER EXPERIENCE:
  1. User completes Cal.com booking flow
  2. Webhook fires → confirmBooking mutation
  3. User's "My Bookings" page updates instantly
  4. No need to refresh or navigate away

// ========================================
// PERFORMANCE CHARACTERISTICS
// ========================================

WEBSOCKET CONNECTION:
- Persistent, bidirectional
- Automatic reconnection with exponential backoff
- Client-side connection pooling
- Typical latency: 20-50ms from mutation to client update

SUBSCRIPTION OVERHEAD:
- Zero polling overhead (vs REST: 1 req/sec = 86,400 req/day)
- Minimal bandwidth (only deltas sent, not full data)
- Smart deduplication (same query parameters share subscription)

SCALABILITY:
- Convex handles subscriptions at scale
- Automatic query result caching
- Incremental view maintenance (only recompute changed results)

RELIABILITY:
- Offline support (queued mutations)
- Optimistic UI updates
- Automatic retry on connection loss
- Guaranteed eventual consistency
```

## 2.3.5 Outbound Webhook Flow (Platform API)

```pseudocode
FLOW: OUTBOUND_WEBHOOKS
PURPOSE: Allow external systems to subscribe to platform events

// ========================================
// ADMIN WEBHOOK CONFIGURATION
// ========================================

MUTATION: createWebhookEndpoint
ACCESS: Admin only

FUNCTION createWebhookEndpoint(url, secret, events):
  // Validate URL
  IF NOT isValidHttpsUrl(url):
    THROW ValidationError("URL must be HTTPS")

  // Generate webhook endpoint ID
  endpointId = db.webhookEndpoints.insert({
    organizationId: ctx.organizationId,
    url: url,
    secret: secret,  // Used for HMAC signing
    events: events,  // e.g., ["enrollment.created", "payment.received"]
    status: "active",
    createdBy: ctx.userId,
    createdAt: now()
  })

  RETURN { endpointId: endpointId }

// Example webhook endpoint creation
EXAMPLE:
  createWebhookEndpoint({
    url: "https://customer-crm.com/webhooks/academy",
    secret: generateRandomSecret(32),  // e.g., "whsec_abc123..."
    events: [
      "enrollment.created",
      "enrollment.completed",
      "certificate.issued",
      "payment.received"
    ]
  })

// ========================================
// EVENT DEFINITIONS
// ========================================

ENUM: WebhookEventType
VALUES:
  - "enrollment.created"      // User enrolls in cohort
  - "enrollment.completed"    // User completes cohort
  - "enrollment.canceled"     // User cancels enrollment
  - "cohort.started"          // Cohort begins
  - "cohort.completed"        // Cohort ends
  - "certificate.issued"      // Certificate generated and sent
  - "waitlist.offered"        // Waitlist spot offered
  - "waitlist.accepted"       // User accepts waitlist offer
  - "payment.received"        // Payment successful
  - "payment.refunded"        // Refund processed
  - "booking.created"         // Cal.com booking confirmed
  - "booking.canceled"        // Booking canceled
  - "survey.completed"        // Formbricks survey submitted
  - "user.created"            // New user registered
  - "organization.created"    // New B2B organization

// ========================================
// WEBHOOK DELIVERY SYSTEM
// ========================================

FUNCTION triggerWebhookEvent(eventType, eventData):
  // Find all webhook endpoints subscribed to this event
  endpoints = db.webhookEndpoints.query({
    events: { $contains: eventType },
    status: "active"
  })

  IF endpoints.length === 0:
    RETURN  // No subscribers, skip

  // Build webhook payload
  payload = {
    id: generateEventId(),  // e.g., "evt_abc123"
    type: eventType,
    created: Math.floor(now() / 1000),  // Unix timestamp
    data: eventData,
    livemode: IS_PRODUCTION
  }

  // Deliver to all subscribed endpoints
  FOR endpoint IN endpoints:
    deliverWebhook(endpoint, payload)

  RETURN { endpoints: endpoints.length }

// ========================================

FUNCTION deliverWebhook(endpoint, payload):
  // Generate HMAC-SHA256 signature
  timestamp = payload.created
  signedPayload = timestamp + "." + JSON.stringify(payload)
  signature = crypto.createHmac('sha256', endpoint.secret)
    .update(signedPayload)
    .digest('hex')

  // Create delivery record
  deliveryId = db.webhookDeliveries.insert({
    endpointId: endpoint.id,
    eventType: payload.type,
    payload: payload,
    signature: signature,
    status: "pending",
    attempts: 0,
    createdAt: now()
  })

  // Attempt delivery
  TRY:
    response = httpAction({
      url: endpoint.url,
      method: "POST",
      timeout: 30000,  // 30 second timeout
      headers: {
        "Content-Type": "application/json",
        "X-Webhook-Signature": signature,
        "X-Webhook-Event": payload.type,
        "X-Webhook-Timestamp": timestamp.toString(),
        "X-Webhook-ID": payload.id,
        "User-Agent": "AcademyWebhooks/1.0"
      },
      body: payload
    })

    // Check response status
    IF response.status >= 200 AND response.status < 300:
      // Success (2xx status code)
      db.webhookDeliveries.update(deliveryId, {
        status: "delivered",
        deliveredAt: now(),
        responseStatus: response.status,
        responseBody: response.body
      })

      LOG.info("Webhook delivered successfully: " + deliveryId)

    ELSE:
      // Non-2xx status code = failure
      THROW WebhookDeliveryError("HTTP " + response.status)

  CATCH error:
    // Handle delivery failure
    handleOutboundWebhookFailure(deliveryId, error)

// ========================================

FUNCTION handleOutboundWebhookFailure(deliveryId, error):
  delivery = db.webhookDeliveries.get(deliveryId)
  attempts = delivery.attempts + 1

  // Exponential backoff: 1s, 10s, 100s, 1000s, 10000s
  backoffSeconds = Math.pow(10, attempts - 1)
  nextRetryAt = now() + (backoffSeconds * 1000)

  IF attempts < 5:  // Max 5 attempts for outbound webhooks
    // Queue for retry
    db.webhookDeliveries.update(deliveryId, {
      status: "pending",
      attempts: attempts,
      nextRetryAt: nextRetryAt,
      lastError: error.message,
      updatedAt: now()
    })

    LOG.warn("Outbound webhook delivery " + deliveryId + " failed, retry " + attempts + " scheduled")

  ELSE:
    // Max retries exceeded
    db.webhookDeliveries.update(deliveryId, {
      status: "failed",
      attempts: attempts,
      failedAt: now(),
      lastError: error.message
    })

    // Mark endpoint as unhealthy if multiple failures
    checkEndpointHealth(delivery.endpointId)

    LOG.error("Outbound webhook delivery " + deliveryId + " failed permanently")

// ========================================

FUNCTION checkEndpointHealth(endpointId):
  // Count recent failures (last 24 hours)
  recentFailures = db.webhookDeliveries.count({
    endpointId: endpointId,
    status: "failed",
    createdAt: { $gte: now() - 24.hours }
  })

  // If > 10 failures in 24h, mark endpoint as unhealthy
  IF recentFailures > 10:
    db.webhookEndpoints.update(endpointId, {
      status: "unhealthy",
      lastFailureCount: recentFailures,
      markedUnhealthyAt: now()
    })

    // Notify organization admins
    endpoint = db.webhookEndpoints.get(endpointId)
    organization = db.organizations.get(endpoint.organizationId)

    FOR adminEmail IN organization.adminEmails:
      sendEmail({
        to: adminEmail,
        template: "webhook-endpoint-unhealthy",
        data: {
          endpointUrl: endpoint.url,
          failureCount: recentFailures,
          dashboardUrl: PLATFORM_URL + "/admin/webhooks/" + endpointId
        }
      })

// ========================================
// RECIPIENT VERIFICATION
// ========================================

// How recipients should verify webhook signatures
PSEUDOCODE: Recipient Verification (Customer Implementation)

FUNCTION verifyWebhookSignature(request, endpointSecret):
  // Extract headers
  signature = request.headers['x-webhook-signature']
  timestamp = request.headers['x-webhook-timestamp']
  eventType = request.headers['x-webhook-event']

  // Verify timestamp (replay protection)
  currentTime = Math.floor(Date.now() / 1000)
  IF Math.abs(currentTime - parseInt(timestamp)) > 300:  // 5 minutes
    THROW ReplayAttackError("Webhook timestamp too old")

  // Compute expected signature
  signedPayload = timestamp + "." + request.rawBody
  expectedSignature = crypto.createHmac('sha256', endpointSecret)
    .update(signedPayload)
    .digest('hex')

  // Timing-safe comparison
  isValid = crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  )

  IF NOT isValid:
    THROW InvalidSignatureError("Webhook signature verification failed")

  // Parse event data
  event = JSON.parse(request.rawBody)

  RETURN event

// Example implementation (Node.js/Express)
EXAMPLE:
  app.post('/webhooks/academy', express.raw({ type: 'application/json' }), (req, res) => {
    try {
      const event = verifyWebhookSignature(req, ENDPOINT_SECRET);

      // Process event
      switch (event.type) {
        case 'enrollment.created':
          handleEnrollmentCreated(event.data);
          break;
        case 'certificate.issued':
          handleCertificateIssued(event.data);
          break;
        // ... other event types
      }

      res.status(200).json({ received: true });
    } catch (error) {
      console.error('Webhook verification failed:', error);
      res.status(400).send('Webhook verification failed');
    }
  });

// ========================================
// EVENT PAYLOAD EXAMPLES
// ========================================

EXAMPLE: enrollment.created event
{
  "id": "evt_1a2b3c4d5e",
  "type": "enrollment.created",
  "created": 1735776000,
  "data": {
    "enrollment": {
      "id": "enr_abc123",
      "userId": "usr_xyz789",
      "cohortId": "coh_def456",
      "status": "confirmed",
      "paymentStatus": "paid",
      "amount": 2997,
      "currency": "USD",
      "createdAt": 1735776000
    },
    "user": {
      "id": "usr_xyz789",
      "email": "learner@example.com",
      "name": "Jane Doe",
      "organizationId": "org_corp123"
    },
    "cohort": {
      "id": "coh_def456",
      "name": "AI for Product Managers - Jan 2025",
      "startDate": "2025-01-15",
      "endDate": "2025-01-16"
    }
  },
  "livemode": true
}

// ========================================

EXAMPLE: certificate.issued event
{
  "id": "evt_9z8y7x6w5v",
  "type": "certificate.issued",
  "created": 1736035200,
  "data": {
    "certificate": {
      "id": "cert_ghi789",
      "enrollmentId": "enr_abc123",
      "userId": "usr_xyz789",
      "cohortId": "coh_def456",
      "pdfUrl": "https://storage.academy.com/certs/cert_ghi789.pdf",
      "issuedAt": 1736035200
    },
    "user": {
      "id": "usr_xyz789",
      "email": "learner@example.com",
      "name": "Jane Doe"
    },
    "cohort": {
      "id": "coh_def456",
      "name": "AI for Product Managers - Jan 2025"
    }
  },
  "livemode": true
}

// ========================================

EXAMPLE: payment.received event
{
  "id": "evt_5t4r3e2w1q",
  "type": "payment.received",
  "created": 1735776000,
  "data": {
    "payment": {
      "id": "pay_jkl012",
      "enrollmentId": "enr_abc123",
      "amount": 2997,
      "currency": "USD",
      "paymentMethod": "card",
      "last4": "4242",
      "status": "succeeded",
      "stripePaymentIntentId": "pi_stripe123",
      "createdAt": 1735776000
    },
    "enrollment": {
      "id": "enr_abc123",
      "userId": "usr_xyz789",
      "cohortId": "coh_def456"
    }
  },
  "livemode": true
}

// ========================================
// RETRY CRON (OUTBOUND)
// ========================================

CRON: PROCESS_OUTBOUND_WEBHOOK_RETRIES
SCHEDULE: Every 1 minute
EXECUTOR: Convex built-in scheduler

FUNCTION processOutboundWebhookRetries():
  // Query pending outbound webhooks ready for retry
  pendingDeliveries = db.webhookDeliveries.query({
    status: "pending",
    nextRetryAt: { $lte: now() }
  }).limit(100)

  FOR delivery IN pendingDeliveries:
    endpoint = db.webhookEndpoints.get(delivery.endpointId)

    // Skip if endpoint is disabled
    IF endpoint.status !== "active":
      CONTINUE

    // Retry delivery
    TRY:
      response = httpAction({
        url: endpoint.url,
        method: "POST",
        timeout: 30000,
        headers: {
          "Content-Type": "application/json",
          "X-Webhook-Signature": delivery.signature,
          "X-Webhook-Event": delivery.eventType,
          "X-Webhook-Timestamp": delivery.payload.created.toString(),
          "X-Webhook-ID": delivery.payload.id
        },
        body: delivery.payload
      })

      IF response.status >= 200 AND response.status < 300:
        db.webhookDeliveries.update(delivery.id, {
          status: "delivered",
          deliveredAt: now(),
          responseStatus: response.status
        })
        LOG.info("Outbound webhook retry succeeded: " + delivery.id)
      ELSE:
        THROW WebhookDeliveryError("HTTP " + response.status)

    CATCH error:
      handleOutboundWebhookFailure(delivery.id, error)

  RETURN { processed: pendingDeliveries.length }

// ========================================
// ADMIN MONITORING
// ========================================

QUERY: getWebhookEndpointStats
ACCESS: Admin only

FUNCTION getWebhookEndpointStats(endpointId):
  endpoint = db.webhookEndpoints.get(endpointId)

  // Calculate delivery stats
  totalDeliveries = db.webhookDeliveries.count({ endpointId: endpointId })
  successfulDeliveries = db.webhookDeliveries.count({
    endpointId: endpointId,
    status: "delivered"
  })
  failedDeliveries = db.webhookDeliveries.count({
    endpointId: endpointId,
    status: "failed"
  })
  pendingDeliveries = db.webhookDeliveries.count({
    endpointId: endpointId,
    status: "pending"
  })

  // Calculate success rate
  successRate = totalDeliveries > 0 ?
    (successfulDeliveries / totalDeliveries) * 100 : 0

  // Get recent deliveries
  recentDeliveries = db.webhookDeliveries.query({ endpointId: endpointId })
    .order("createdAt", "desc")
    .limit(10)

  RETURN {
    endpoint: endpoint,
    stats: {
      total: totalDeliveries,
      successful: successfulDeliveries,
      failed: failedDeliveries,
      pending: pendingDeliveries,
      successRate: successRate
    },
    recentDeliveries: recentDeliveries
  }
```
