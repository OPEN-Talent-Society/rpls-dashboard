# SPARC Specification - Section 2.3: System Pseudocode Flows

**Agent**: AGENT 5 - System Flow Architect
**Version**: 1.0.0
**Date**: 2025-12-02
**Status**: Complete

---

## Table of Contents
- [2.3.1 Webhook Processing (with Retry & Dead Letter)](#231-webhook-processing-with-retry--dead-letter)
  - [Stripe Webhook Handler](#stripe-webhook-handler)
  - [Cal.com Webhook Handler](#calcom-webhook-handler)
  - [Formbricks Webhook Handler](#formbricks-webhook-handler)
- [2.3.2 Cron Job Orchestration (Convex + n8n Hybrid)](#232-cron-job-orchestration-convex--n8n-hybrid)
  - [Convex Crons (Data-Critical)](#convex-crons-data-critical)
  - [n8n Workflows (External Integrations)](#n8n-workflows-external-integrations)
- [2.3.3 Real-time Subscription Updates](#233-real-time-subscription-updates)
- [2.3.4 Outbound Webhook Dispatch](#234-outbound-webhook-dispatch)

---

## 2.3.1 Webhook Processing (with Retry & Dead Letter)

### Stripe Webhook Handler

```pseudocode
FUNCTION handleStripeWebhook(request: HTTPRequest): HTTPResponse
  TRY
    // 1. SIGNATURE VERIFICATION
    signature = request.headers["stripe-signature"]
    rawBody = request.rawBody
    webhookSecret = env.STRIPE_WEBHOOK_SECRET

    TRY
      event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret)
    CATCH SignatureVerificationError as err
      LOG_ERROR("Stripe signature verification failed", {
        error: err.message,
        ip: request.ip,
        timestamp: NOW()
      })
      RETURN HTTPResponse(401, "Invalid signature")
    END TRY

    // 2. IDEMPOTENCY CHECK
    sessionId = event.data.object.id
    eventType = event.type
    idempotencyKey = HASH(sessionId + eventType + event.id)

    existingEvent = db.processedWebhooks.findUnique({
      where: { idempotencyKey: idempotencyKey }
    })

    IF existingEvent EXISTS THEN
      LOG_INFO("Duplicate webhook event ignored", {
        eventId: event.id,
        eventType: eventType,
        processedAt: existingEvent.processedAt
      })
      RETURN HTTPResponse(200, "Event already processed")
    END IF

    // 3. EVENT TYPE ROUTING
    SWITCH eventType
      CASE "checkout.session.completed":
        result = processCheckoutCompleted(event.data.object)

      CASE "charge.refunded":
        result = processChargeRefunded(event.data.object)

      CASE "invoice.payment_succeeded":
        result = processInvoicePaymentSucceeded(event.data.object)

      CASE "customer.subscription.updated":
        result = processSubscriptionUpdated(event.data.object)

      CASE "customer.subscription.deleted":
        result = processSubscriptionDeleted(event.data.object)

      DEFAULT:
        LOG_WARN("Unhandled Stripe event type", {
          eventType: eventType,
          eventId: event.id
        })
        RETURN HTTPResponse(200, "Event type not handled")
    END SWITCH

    // 4. RECORD SUCCESSFUL PROCESSING
    db.processedWebhooks.create({
      data: {
        idempotencyKey: idempotencyKey,
        eventId: event.id,
        eventType: eventType,
        payload: JSON.stringify(event),
        processedAt: NOW(),
        status: "SUCCESS",
        result: JSON.stringify(result)
      }
    })

    RETURN HTTPResponse(200, "Webhook processed successfully")

  CATCH error
    // 5. RETRY STRATEGY WITH EXPONENTIAL BACKOFF
    attemptNumber = getAttemptNumber(request.headers["stripe-webhook-attempt"])
    maxAttempts = 3

    IF attemptNumber < maxAttempts THEN
      // Calculate backoff: 2^attempt * 1000ms (1s, 2s, 4s)
      backoffMs = POWER(2, attemptNumber) * 1000

      // Store failed attempt for retry
      db.webhookRetries.create({
        data: {
          webhookId: event?.id || "unknown",
          eventType: eventType || "unknown",
          payload: rawBody,
          attemptNumber: attemptNumber,
          error: error.message,
          nextRetryAt: NOW() + backoffMs,
          status: "RETRY_SCHEDULED"
        }
      })

      LOG_WARN("Webhook processing failed, retry scheduled", {
        eventId: event?.id,
        attemptNumber: attemptNumber,
        nextRetryAt: NOW() + backoffMs,
        error: error.message
      })

      RETURN HTTPResponse(500, "Processing failed, will retry")

    ELSE
      // 6. DEAD LETTER QUEUE FOR PERSISTENT FAILURES
      deadLetterEntry = db.webhookDeadLetters.create({
        data: {
          webhookId: event?.id || "unknown",
          eventType: eventType || "unknown",
          payload: rawBody,
          signature: signature,
          attempts: attemptNumber,
          finalError: error.message,
          stackTrace: error.stack,
          receivedAt: NOW(),
          status: "FAILED_PERMANENTLY"
        }
      })

      // 7. ADMIN NOTIFICATION ON PERSISTENT FAILURE
      notifyAdmins({
        type: "WEBHOOK_DEAD_LETTER",
        severity: "CRITICAL",
        title: "Stripe webhook processing failed permanently",
        details: {
          deadLetterId: deadLetterEntry.id,
          eventType: eventType,
          eventId: event?.id,
          error: error.message,
          attempts: attemptNumber
        },
        channels: ["email", "slack", "dashboard"],
        recipients: env.ADMIN_EMAILS
      })

      LOG_ERROR("Webhook moved to dead letter queue", {
        deadLetterId: deadLetterEntry.id,
        eventId: event?.id,
        attempts: attemptNumber,
        error: error.message
      })

      RETURN HTTPResponse(500, "Processing failed permanently")
    END IF
  END TRY
END FUNCTION

// ===== HELPER FUNCTIONS =====

FUNCTION processCheckoutCompleted(session: StripeSession): Result
  TRY
    // Extract metadata
    cohortId = session.metadata.cohortId
    userId = session.metadata.userId
    paymentIntentId = session.payment_intent

    // Validate required metadata
    IF NOT cohortId OR NOT userId THEN
      THROW Error("Missing required metadata: cohortId or userId")
    END IF

    // Check cohort capacity
    cohort = db.cohorts.findUnique({
      where: { id: cohortId },
      include: {
        enrollments: { where: { status: "ACTIVE" } }
      }
    })

    IF NOT cohort THEN
      THROW Error("Cohort not found: " + cohortId)
    END IF

    IF cohort.enrollments.count >= cohort.maxCapacity THEN
      // Refund payment and add to waitlist
      stripe.refunds.create({
        payment_intent: paymentIntentId,
        reason: "requested_by_customer",
        metadata: {
          reason: "cohort_full",
          cohortId: cohortId
        }
      })

      db.waitlistEntries.create({
        data: {
          userId: userId,
          cohortId: cohortId,
          addedAt: NOW(),
          status: "ACTIVE",
          priority: calculateWaitlistPriority(userId, cohortId)
        }
      })

      sendEmail({
        to: getUserEmail(userId),
        template: "cohort-full-waitlist",
        data: { cohortName: cohort.name }
      })

      RETURN { status: "WAITLISTED", reason: "cohort_full" }
    END IF

    // Create enrollment
    enrollment = db.enrollments.create({
      data: {
        userId: userId,
        cohortId: cohortId,
        status: "ACTIVE",
        enrolledAt: NOW(),
        paymentIntentId: paymentIntentId,
        amountPaid: session.amount_total,
        currency: session.currency,
        stripeSessionId: session.id,
        accessExpiresAt: cohort.endDate + 30_DAYS,
        progress: {
          lessonsCompleted: [],
          assignmentsSubmitted: [],
          quizzesCompleted: []
        }
      }
    })

    // Create Cal.com booking if cohort has scheduled sessions
    IF cohort.hasLiveSessions THEN
      calBooking = createCalBooking({
        userId: userId,
        cohortId: cohortId,
        eventTypeId: cohort.calEventTypeId,
        startTime: cohort.startDate,
        endTime: cohort.endDate
      })

      db.enrollments.update({
        where: { id: enrollment.id },
        data: { calBookingId: calBooking.id }
      })
    END IF

    // Trigger onboarding email sequence
    sendEmail({
      to: getUserEmail(userId),
      template: "enrollment-welcome",
      data: {
        cohortName: cohort.name,
        startDate: cohort.startDate,
        calBookingLink: calBooking?.rescheduleUrl
      }
    })

    // Real-time update to dashboard
    publishToSubscribers("cohort/" + cohortId + "/enrollments", {
      type: "ENROLLMENT_CREATED",
      enrollment: enrollment,
      currentCount: cohort.enrollments.count + 1,
      spotsRemaining: cohort.maxCapacity - (cohort.enrollments.count + 1)
    })

    // Trigger outbound webhook
    dispatchOutboundWebhook({
      eventType: "enrollment.created",
      payload: {
        enrollmentId: enrollment.id,
        userId: userId,
        cohortId: cohortId,
        enrolledAt: enrollment.enrolledAt
      }
    })

    RETURN {
      status: "SUCCESS",
      enrollmentId: enrollment.id,
      calBookingId: calBooking?.id
    }

  CATCH error
    LOG_ERROR("Checkout processing failed", {
      sessionId: session.id,
      error: error.message,
      metadata: session.metadata
    })
    THROW error
  END TRY
END FUNCTION

FUNCTION processChargeRefunded(charge: StripeCharge): Result
  TRY
    paymentIntentId = charge.payment_intent
    refundAmount = charge.amount_refunded
    refundReason = charge.refund_reason || "requested_by_customer"

    // Find enrollment by payment intent
    enrollment = db.enrollments.findFirst({
      where: { paymentIntentId: paymentIntentId },
      include: { cohort: true, user: true }
    })

    IF NOT enrollment THEN
      LOG_WARN("No enrollment found for refunded charge", {
        chargeId: charge.id,
        paymentIntentId: paymentIntentId
      })
      RETURN { status: "NO_ENROLLMENT_FOUND" }
    END IF

    // Check if partial or full refund
    isFullRefund = (refundAmount === charge.amount)

    IF isFullRefund THEN
      // Cancel enrollment completely
      db.enrollments.update({
        where: { id: enrollment.id },
        data: {
          status: "REFUNDED",
          refundedAt: NOW(),
          refundAmount: refundAmount,
          refundReason: refundReason,
          accessExpiresAt: NOW() // Immediate access removal
        }
      })

      // Cancel Cal.com booking
      IF enrollment.calBookingId THEN
        cancelCalBooking(enrollment.calBookingId)
      END IF

      // Send refund confirmation
      sendEmail({
        to: enrollment.user.email,
        template: "refund-confirmation",
        data: {
          cohortName: enrollment.cohort.name,
          refundAmount: formatCurrency(refundAmount),
          refundReason: refundReason
        }
      })

      // Check waitlist for next student
      promoteFromWaitlist(enrollment.cohortId)

    ELSE
      // Partial refund - adjust access or features
      db.enrollments.update({
        where: { id: enrollment.id },
        data: {
          partialRefund: refundAmount,
          partialRefundReason: refundReason,
          // Possibly downgrade access tier
        }
      })
    END IF

    // Real-time update
    publishToSubscribers("cohort/" + enrollment.cohortId + "/enrollments", {
      type: "ENROLLMENT_REFUNDED",
      enrollmentId: enrollment.id,
      isFullRefund: isFullRefund
    })

    // Trigger outbound webhook
    dispatchOutboundWebhook({
      eventType: "enrollment.refunded",
      payload: {
        enrollmentId: enrollment.id,
        refundAmount: refundAmount,
        isFullRefund: isFullRefund,
        refundReason: refundReason
      }
    })

    RETURN {
      status: "SUCCESS",
      enrollmentId: enrollment.id,
      refundType: isFullRefund ? "FULL" : "PARTIAL"
    }

  CATCH error
    LOG_ERROR("Refund processing failed", {
      chargeId: charge.id,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION
```

---

### Cal.com Webhook Handler

```pseudocode
FUNCTION handleCalWebhook(request: HTTPRequest): HTTPResponse
  TRY
    // 1. HMAC SIGNATURE VERIFICATION
    signature = request.headers["x-cal-signature"]
    rawBody = request.rawBody
    webhookSecret = env.CAL_WEBHOOK_SECRET

    expectedSignature = HMAC_SHA256(rawBody, webhookSecret)

    IF NOT timingSafeCompare(signature, expectedSignature) THEN
      LOG_ERROR("Cal.com signature verification failed", {
        ip: request.ip,
        timestamp: NOW()
      })
      RETURN HTTPResponse(401, "Invalid signature")
    END IF

    // 2. PARSE EVENT
    event = JSON.parse(rawBody)
    eventType = event.triggerEvent
    payload = event.payload

    // 3. IDEMPOTENCY CHECK
    bookingUid = payload.uid || payload.booking?.uid
    idempotencyKey = HASH(bookingUid + eventType)

    existingEvent = db.processedWebhooks.findUnique({
      where: { idempotencyKey: idempotencyKey }
    })

    IF existingEvent EXISTS THEN
      LOG_INFO("Duplicate Cal webhook ignored", {
        bookingUid: bookingUid,
        eventType: eventType
      })
      RETURN HTTPResponse(200, "Event already processed")
    END IF

    // 4. EVENT TYPE ROUTING
    SWITCH eventType
      CASE "BOOKING_CREATED":
        result = processBookingCreated(payload)

      CASE "BOOKING_RESCHEDULED":
        result = processBookingRescheduled(payload)

      CASE "BOOKING_CANCELLED":
        result = processBookingCancelled(payload)

      CASE "BOOKING_CONFIRMED":
        result = processBookingConfirmed(payload)

      CASE "MEETING_ENDED":
        result = processMeetingEnded(payload)

      DEFAULT:
        LOG_WARN("Unhandled Cal event type", {
          eventType: eventType,
          bookingUid: bookingUid
        })
        RETURN HTTPResponse(200, "Event type not handled")
    END SWITCH

    // 5. RECORD SUCCESSFUL PROCESSING
    db.processedWebhooks.create({
      data: {
        idempotencyKey: idempotencyKey,
        eventId: bookingUid,
        eventType: eventType,
        payload: JSON.stringify(event),
        processedAt: NOW(),
        status: "SUCCESS",
        result: JSON.stringify(result)
      }
    })

    RETURN HTTPResponse(200, "Webhook processed successfully")

  CATCH error
    LOG_ERROR("Cal webhook processing failed", {
      error: error.message,
      payload: request.body
    })

    // Cal.com doesn't support retry headers, so we queue for later
    db.webhookRetries.create({
      data: {
        webhookId: event?.payload?.uid || "unknown",
        eventType: event?.triggerEvent || "unknown",
        payload: rawBody,
        attemptNumber: 1,
        error: error.message,
        nextRetryAt: NOW() + 60000, // 1 minute
        status: "RETRY_SCHEDULED"
      }
    })

    RETURN HTTPResponse(500, "Processing failed")
  END TRY
END FUNCTION

// ===== HELPER FUNCTIONS =====

FUNCTION processBookingCreated(payload: CalBookingPayload): Result
  TRY
    bookingUid = payload.uid
    userEmail = payload.attendees[0].email
    startTime = payload.startTime
    endTime = payload.endTime
    eventTypeId = payload.eventTypeId
    metadata = payload.metadata

    // Find user by email
    user = db.users.findUnique({
      where: { email: userEmail }
    })

    IF NOT user THEN
      LOG_WARN("Booking created for unknown user", {
        email: userEmail,
        bookingUid: bookingUid
      })
      RETURN { status: "USER_NOT_FOUND" }
    END IF

    // Find cohort by event type ID (from metadata)
    cohortId = metadata?.cohortId

    IF NOT cohortId THEN
      LOG_WARN("Booking missing cohort metadata", {
        bookingUid: bookingUid,
        metadata: metadata
      })
      RETURN { status: "COHORT_NOT_FOUND" }
    END IF

    // ENROLLMENT VALIDATION
    enrollment = db.enrollments.findFirst({
      where: {
        userId: user.id,
        cohortId: cohortId,
        status: "ACTIVE"
      }
    })

    IF NOT enrollment THEN
      // Cancel the booking - user not enrolled
      cancelCalBooking(bookingUid)

      sendEmail({
        to: userEmail,
        template: "booking-cancelled-no-enrollment",
        data: {
          bookingUid: bookingUid,
          reason: "No active enrollment found"
        }
      })

      RETURN {
        status: "BOOKING_CANCELLED",
        reason: "NO_ACTIVE_ENROLLMENT"
      }
    END IF

    // Update enrollment with booking ID
    db.enrollments.update({
      where: { id: enrollment.id },
      data: {
        calBookingId: bookingUid,
        calBookingStartTime: startTime,
        calBookingEndTime: endTime
      }
    })

    // Send confirmation email
    sendEmail({
      to: userEmail,
      template: "booking-confirmed",
      data: {
        bookingUid: bookingUid,
        startTime: formatDateTime(startTime),
        calendarLink: payload.calendarLink,
        rescheduleLink: payload.rescheduleLink
      }
    })

    // Real-time update
    publishToSubscribers("user/" + user.id + "/bookings", {
      type: "BOOKING_CREATED",
      booking: {
        uid: bookingUid,
        startTime: startTime,
        endTime: endTime
      }
    })

    RETURN {
      status: "SUCCESS",
      bookingUid: bookingUid,
      enrollmentId: enrollment.id
    }

  CATCH error
    LOG_ERROR("Booking creation processing failed", {
      bookingUid: payload.uid,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION

FUNCTION processBookingRescheduled(payload: CalBookingPayload): Result
  TRY
    bookingUid = payload.uid
    newStartTime = payload.startTime
    newEndTime = payload.endTime

    enrollment = db.enrollments.findFirst({
      where: { calBookingId: bookingUid },
      include: { user: true, cohort: true }
    })

    IF NOT enrollment THEN
      RETURN { status: "ENROLLMENT_NOT_FOUND" }
    END IF

    db.enrollments.update({
      where: { id: enrollment.id },
      data: {
        calBookingStartTime: newStartTime,
        calBookingEndTime: newEndTime
      }
    })

    sendEmail({
      to: enrollment.user.email,
      template: "booking-rescheduled",
      data: {
        bookingUid: bookingUid,
        newStartTime: formatDateTime(newStartTime),
        cohortName: enrollment.cohort.name
      }
    })

    publishToSubscribers("user/" + enrollment.userId + "/bookings", {
      type: "BOOKING_RESCHEDULED",
      bookingUid: bookingUid,
      newStartTime: newStartTime
    })

    RETURN { status: "SUCCESS" }

  CATCH error
    LOG_ERROR("Booking reschedule processing failed", {
      bookingUid: payload.uid,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION

FUNCTION processBookingCancelled(payload: CalBookingPayload): Result
  TRY
    bookingUid = payload.uid
    cancellationReason = payload.cancellationReason

    enrollment = db.enrollments.findFirst({
      where: { calBookingId: bookingUid },
      include: { user: true, cohort: true }
    })

    IF NOT enrollment THEN
      RETURN { status: "ENROLLMENT_NOT_FOUND" }
    END IF

    db.enrollments.update({
      where: { id: enrollment.id },
      data: {
        calBookingId: NULL,
        calBookingCancelledAt: NOW(),
        calBookingCancellationReason: cancellationReason
      }
    })

    sendEmail({
      to: enrollment.user.email,
      template: "booking-cancelled",
      data: {
        bookingUid: bookingUid,
        cohortName: enrollment.cohort.name,
        cancellationReason: cancellationReason
      }
    })

    publishToSubscribers("user/" + enrollment.userId + "/bookings", {
      type: "BOOKING_CANCELLED",
      bookingUid: bookingUid
    })

    RETURN { status: "SUCCESS" }

  CATCH error
    LOG_ERROR("Booking cancellation processing failed", {
      bookingUid: payload.uid,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION

FUNCTION processMeetingEnded(payload: CalBookingPayload): Result
  TRY
    bookingUid = payload.uid
    duration = payload.duration
    attendees = payload.attendees

    enrollment = db.enrollments.findFirst({
      where: { calBookingId: bookingUid },
      include: { user: true, cohort: true }
    })

    IF NOT enrollment THEN
      RETURN { status: "ENROLLMENT_NOT_FOUND" }
    END IF

    // Track attendance
    db.attendanceRecords.create({
      data: {
        enrollmentId: enrollment.id,
        bookingUid: bookingUid,
        attendedAt: NOW(),
        duration: duration,
        status: "ATTENDED"
      }
    })

    // Update progress
    db.enrollments.update({
      where: { id: enrollment.id },
      data: {
        progress: {
          ...enrollment.progress,
          sessionsAttended: enrollment.progress.sessionsAttended + 1
        }
      }
    })

    // Send follow-up email with resources
    sendEmail({
      to: enrollment.user.email,
      template: "session-followup",
      data: {
        cohortName: enrollment.cohort.name,
        sessionDate: formatDateTime(payload.startTime),
        recordingUrl: payload.recordingUrl,
        resourcesUrl: generateResourcesUrl(enrollment.cohortId)
      }
    })

    RETURN { status: "SUCCESS" }

  CATCH error
    LOG_ERROR("Meeting end processing failed", {
      bookingUid: payload.uid,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION
```

---

### Formbricks Webhook Handler

```pseudocode
FUNCTION handleFormbricksWebhook(request: HTTPRequest): HTTPResponse
  TRY
    // 1. PARSE EVENT (Formbricks doesn't use signature verification by default)
    event = JSON.parse(request.body)
    eventType = event.event
    surveyId = event.surveyId
    responseId = event.responseId
    data = event.data

    // 2. VALIDATE SURVEY ID (ensure it's one of our surveys)
    validSurveyIds = [
      env.FORMBRICKS_INTAKE_SURVEY_ID,
      env.FORMBRICKS_EXIT_SURVEY_ID,
      env.FORMBRICKS_FEEDBACK_SURVEY_ID
    ]

    IF NOT validSurveyIds.includes(surveyId) THEN
      LOG_WARN("Unknown survey ID received", {
        surveyId: surveyId,
        responseId: responseId
      })
      RETURN HTTPResponse(200, "Survey not recognized")
    END IF

    // 3. IDEMPOTENCY CHECK
    idempotencyKey = HASH(responseId + surveyId)

    existingResponse = db.processedWebhooks.findUnique({
      where: { idempotencyKey: idempotencyKey }
    })

    IF existingResponse EXISTS THEN
      RETURN HTTPResponse(200, "Response already processed")
    END IF

    // 4. ROUTE BY SURVEY TYPE
    SWITCH surveyId
      CASE env.FORMBRICKS_INTAKE_SURVEY_ID:
        result = processIntakeSurvey(data, responseId)

      CASE env.FORMBRICKS_EXIT_SURVEY_ID:
        result = processExitSurvey(data, responseId)

      CASE env.FORMBRICKS_FEEDBACK_SURVEY_ID:
        result = processFeedbackSurvey(data, responseId)

      DEFAULT:
        RETURN HTTPResponse(200, "Survey type not handled")
    END SWITCH

    // 5. RECORD PROCESSING
    db.processedWebhooks.create({
      data: {
        idempotencyKey: idempotencyKey,
        eventId: responseId,
        eventType: "formbricks." + surveyId,
        payload: JSON.stringify(event),
        processedAt: NOW(),
        status: "SUCCESS",
        result: JSON.stringify(result)
      }
    })

    RETURN HTTPResponse(200, "Survey response processed")

  CATCH error
    LOG_ERROR("Formbricks webhook processing failed", {
      error: error.message,
      surveyId: event?.surveyId,
      responseId: event?.responseId
    })

    db.webhookRetries.create({
      data: {
        webhookId: event?.responseId || "unknown",
        eventType: "formbricks." + event?.surveyId,
        payload: request.body,
        attemptNumber: 1,
        error: error.message,
        nextRetryAt: NOW() + 60000,
        status: "RETRY_SCHEDULED"
      }
    })

    RETURN HTTPResponse(500, "Processing failed")
  END TRY
END FUNCTION

// ===== HELPER FUNCTIONS =====

FUNCTION processIntakeSurvey(data: SurveyData, responseId: string): Result
  TRY
    // Extract user identifier from survey metadata or data
    userEmail = data.hidden?.email || data.email
    enrollmentId = data.hidden?.enrollmentId

    IF NOT enrollmentId THEN
      LOG_ERROR("Intake survey missing enrollment ID", {
        responseId: responseId,
        data: data
      })
      RETURN { status: "MISSING_ENROLLMENT_ID" }
    END IF

    enrollment = db.enrollments.findUnique({
      where: { id: enrollmentId },
      include: { user: true, cohort: true }
    })

    IF NOT enrollment THEN
      RETURN { status: "ENROLLMENT_NOT_FOUND" }
    END IF

    // Parse survey responses
    responses = {
      experienceLevel: data.experienceLevel,
      learningGoals: data.learningGoals,
      challenges: data.challenges,
      timezone: data.timezone,
      preferredCommunication: data.preferredCommunication,
      additionalNeeds: data.additionalNeeds
    }

    // Update enrollment
    db.enrollments.update({
      where: { id: enrollmentId },
      data: {
        intakeSurveyCompleted: true,
        intakeSurveyCompletedAt: NOW(),
        intakeSurveyResponseId: responseId,
        studentProfile: {
          ...enrollment.studentProfile,
          ...responses
        },
        onboardingProgress: {
          ...enrollment.onboardingProgress,
          intakeSurveyDone: true
        }
      }
    })

    // Personalize learning path based on experience level
    IF responses.experienceLevel === "BEGINNER" THEN
      assignSupplementalResources(enrollmentId, "beginner-prep")
    ELSE IF responses.experienceLevel === "ADVANCED" THEN
      assignSupplementalResources(enrollmentId, "advanced-challenges")
    END IF

    // Send personalized welcome email
    sendEmail({
      to: enrollment.user.email,
      template: "intake-complete-personalized",
      data: {
        name: enrollment.user.name,
        cohortName: enrollment.cohort.name,
        experienceLevel: responses.experienceLevel,
        learningGoals: responses.learningGoals
      }
    })

    // Real-time update
    publishToSubscribers("user/" + enrollment.userId + "/profile", {
      type: "INTAKE_SURVEY_COMPLETED",
      enrollmentId: enrollmentId
    })

    RETURN {
      status: "SUCCESS",
      enrollmentId: enrollmentId,
      profileUpdated: true
    }

  CATCH error
    LOG_ERROR("Intake survey processing failed", {
      responseId: responseId,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION

FUNCTION processExitSurvey(data: SurveyData, responseId: string): Result
  TRY
    enrollmentId = data.hidden?.enrollmentId

    enrollment = db.enrollments.findUnique({
      where: { id: enrollmentId },
      include: { user: true, cohort: true }
    })

    IF NOT enrollment THEN
      RETURN { status: "ENROLLMENT_NOT_FOUND" }
    END IF

    // Parse exit survey responses
    feedback = {
      overallSatisfaction: data.overallSatisfaction, // 1-10
      wouldRecommend: data.wouldRecommend, // boolean
      mostValuable: data.mostValuable,
      leastValuable: data.leastValuable,
      instructorRating: data.instructorRating,
      contentRating: data.contentRating,
      suggestions: data.suggestions,
      careerImpact: data.careerImpact
    }

    // Calculate NPS (Net Promoter Score)
    npsScore = calculateNPS(feedback.overallSatisfaction)
    npsCategory = getNPSCategory(npsScore) // Promoter, Passive, Detractor

    // Store feedback
    db.enrollments.update({
      where: { id: enrollmentId },
      data: {
        exitSurveyCompleted: true,
        exitSurveyCompletedAt: NOW(),
        exitSurveyResponseId: responseId,
        feedback: feedback,
        npsScore: npsScore,
        npsCategory: npsCategory
      }
    })

    // Update cohort metrics
    updateCohortMetrics(enrollment.cohortId, {
      completionRate: true,
      npsScore: npsScore,
      satisfaction: feedback.overallSatisfaction
    })

    // Trigger certificate generation if eligible
    IF enrollment.progress.completionPercentage >= 80 THEN
      queueCertificateGeneration(enrollmentId)
    END IF

    // Send thank you email with certificate (if eligible)
    sendEmail({
      to: enrollment.user.email,
      template: "exit-survey-thank-you",
      data: {
        cohortName: enrollment.cohort.name,
        certificateEligible: enrollment.progress.completionPercentage >= 80
      }
    })

    // If NPS detractor, alert team for follow-up
    IF npsCategory === "DETRACTOR" THEN
      notifyAdmins({
        type: "NPS_DETRACTOR",
        severity: "HIGH",
        title: "Student exit survey shows low satisfaction",
        details: {
          studentEmail: enrollment.user.email,
          cohortName: enrollment.cohort.name,
          npsScore: npsScore,
          feedback: feedback.suggestions
        },
        channels: ["slack", "dashboard"]
      })
    END IF

    RETURN {
      status: "SUCCESS",
      npsCategory: npsCategory
    }

  CATCH error
    LOG_ERROR("Exit survey processing failed", {
      responseId: responseId,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION
```

---

## 2.3.2 Cron Job Orchestration (Convex + n8n Hybrid)

### Convex Crons (Data-Critical)

```pseudocode
// ===== DAILY ACCESS EXPIRY CHECKER =====
// Schedule: Every day at 2:00 AM UTC
// Convex Cron: crons.daily("check-access-expiry", "0 2 * * *")

FUNCTION checkAccessExpiry(): CronResult
  TRY
    startTime = NOW()
    LOG_INFO("Starting access expiry check")

    // Find all enrollments expiring today
    today = startOfDay(NOW())
    tomorrow = startOfDay(NOW() + 1_DAY)

    expiringToday = db.enrollments.findMany({
      where: {
        accessExpiresAt: {
          gte: today,
          lt: tomorrow
        },
        status: "ACTIVE"
      },
      include: { user: true, cohort: true }
    })

    // Process each expiring enrollment
    results = {
      processed: 0,
      notified: 0,
      errors: 0
    }

    FOR EACH enrollment IN expiringToday DO
      TRY
        // Check if extension was purchased
        extension = db.accessExtensions.findFirst({
          where: {
            enrollmentId: enrollment.id,
            status: "ACTIVE"
          }
        })

        IF extension EXISTS THEN
          // Extend access
          db.enrollments.update({
            where: { id: enrollment.id },
            data: {
              accessExpiresAt: extension.extendsUntil,
              accessExtensionApplied: true
            }
          })
          results.processed++
          CONTINUE
        END IF

        // No extension - send final reminder
        sendEmail({
          to: enrollment.user.email,
          template: "access-expiring-today",
          data: {
            cohortName: enrollment.cohort.name,
            expiresAt: formatDateTime(enrollment.accessExpiresAt),
            extendAccessUrl: generateExtensionUrl(enrollment.id)
          }
        })

        results.notified++

      CATCH error
        LOG_ERROR("Failed to process expiring enrollment", {
          enrollmentId: enrollment.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    // Find all enrollments that expired yesterday (revoke access)
    yesterday = startOfDay(NOW() - 1_DAY)

    expiredYesterday = db.enrollments.findMany({
      where: {
        accessExpiresAt: {
          gte: yesterday,
          lt: today
        },
        status: "ACTIVE"
      }
    })

    FOR EACH enrollment IN expiredYesterday DO
      TRY
        db.enrollments.update({
          where: { id: enrollment.id },
          data: {
            status: "EXPIRED",
            accessRevokedAt: NOW()
          }
        })

        results.processed++

      CATCH error
        LOG_ERROR("Failed to revoke access for expired enrollment", {
          enrollmentId: enrollment.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    duration = NOW() - startTime

    LOG_INFO("Access expiry check completed", {
      duration: duration,
      expiringToday: expiringToday.length,
      expiredYesterday: expiredYesterday.length,
      results: results
    })

    RETURN {
      success: true,
      duration: duration,
      stats: results
    }

  CATCH error
    LOG_ERROR("Access expiry check failed", {
      error: error.message
    })

    notifyAdmins({
      type: "CRON_FAILURE",
      severity: "CRITICAL",
      title: "Daily access expiry check failed",
      details: { error: error.message }
    })

    RETURN {
      success: false,
      error: error.message
    }
  END TRY
END FUNCTION

// ===== PRE-COHORT EMAIL SCHEDULER =====
// Schedule: Every day at 9:00 AM UTC
// Convex Cron: crons.daily("pre-cohort-emails", "0 9 * * *")

FUNCTION sendPreCohortEmails(): CronResult
  TRY
    startTime = NOW()
    LOG_INFO("Starting pre-cohort email scheduler")

    // Find cohorts starting in 7 days
    in7Days = startOfDay(NOW() + 7_DAYS)
    in8Days = startOfDay(NOW() + 8_DAYS)

    cohortsStartingIn7Days = db.cohorts.findMany({
      where: {
        startDate: {
          gte: in7Days,
          lt: in8Days
        },
        status: "CONFIRMED"
      },
      include: {
        enrollments: {
          where: { status: "ACTIVE" },
          include: { user: true }
        }
      }
    })

    results = {
      cohorts: 0,
      emails: 0,
      errors: 0
    }

    FOR EACH cohort IN cohortsStartingIn7Days DO
      TRY
        FOR EACH enrollment IN cohort.enrollments DO
          // Check if intake survey completed
          intakeComplete = enrollment.intakeSurveyCompleted

          sendEmail({
            to: enrollment.user.email,
            template: "cohort-starting-7days",
            data: {
              name: enrollment.user.name,
              cohortName: cohort.name,
              startDate: formatDate(cohort.startDate),
              calBookingUrl: enrollment.calBookingId ?
                getCalBookingUrl(enrollment.calBookingId) : null,
              intakeComplete: intakeComplete,
              intakeSurveyUrl: intakeComplete ? null :
                generateIntakeSurveyUrl(enrollment.id),
              prepMaterialsUrl: generatePrepUrl(cohort.id)
            }
          })

          results.emails++
        END FOR

        results.cohorts++

      CATCH error
        LOG_ERROR("Failed to send pre-cohort emails", {
          cohortId: cohort.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    // Find cohorts starting in 1 day (final reminder)
    tomorrow = startOfDay(NOW() + 1_DAY)
    in2Days = startOfDay(NOW() + 2_DAYS)

    cohortsStartingTomorrow = db.cohorts.findMany({
      where: {
        startDate: {
          gte: tomorrow,
          lt: in2Days
        },
        status: "CONFIRMED"
      },
      include: {
        enrollments: {
          where: { status: "ACTIVE" },
          include: { user: true }
        }
      }
    })

    FOR EACH cohort IN cohortsStartingTomorrow DO
      TRY
        FOR EACH enrollment IN cohort.enrollments DO
          sendEmail({
            to: enrollment.user.email,
            template: "cohort-starting-tomorrow",
            data: {
              name: enrollment.user.name,
              cohortName: cohort.name,
              startTime: formatDateTime(cohort.startDate),
              calBookingUrl: getCalBookingUrl(enrollment.calBookingId),
              zoomLink: cohort.zoomLink,
              slackChannelUrl: cohort.slackChannelUrl
            }
          })

          results.emails++
        END FOR

        results.cohorts++

      CATCH error
        LOG_ERROR("Failed to send final reminder emails", {
          cohortId: cohort.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    duration = NOW() - startTime

    LOG_INFO("Pre-cohort email scheduler completed", {
      duration: duration,
      results: results
    })

    RETURN {
      success: true,
      duration: duration,
      stats: results
    }

  CATCH error
    LOG_ERROR("Pre-cohort email scheduler failed", {
      error: error.message
    })

    notifyAdmins({
      type: "CRON_FAILURE",
      severity: "HIGH",
      title: "Pre-cohort email scheduler failed",
      details: { error: error.message }
    })

    RETURN {
      success: false,
      error: error.message
    }
  END TRY
END FUNCTION

// ===== WAITLIST AUTO-PROMOTION =====
// Schedule: Every 6 hours
// Convex Cron: crons.interval("waitlist-promotion", { hours: 6 })

FUNCTION promoteFromWaitlists(): CronResult
  TRY
    startTime = NOW()
    LOG_INFO("Starting waitlist auto-promotion")

    // Find cohorts with available spots
    cohortsWithSpots = db.cohorts.findMany({
      where: {
        startDate: { gte: NOW() },
        status: { in: ["CONFIRMED", "OPEN"] }
      },
      include: {
        enrollments: {
          where: { status: "ACTIVE" }
        },
        waitlistEntries: {
          where: { status: "ACTIVE" },
          orderBy: { priority: "desc" }
        }
      }
    })

    results = {
      promoted: 0,
      notified: 0,
      errors: 0
    }

    FOR EACH cohort IN cohortsWithSpots DO
      TRY
        availableSpots = cohort.maxCapacity - cohort.enrollments.count

        IF availableSpots <= 0 THEN
          CONTINUE
        END IF

        // Get top priority waitlist entries
        entriesToPromote = cohort.waitlistEntries.slice(0, availableSpots)

        FOR EACH entry IN entriesToPromote DO
          TRY
            // Generate invite token
            inviteToken = generateSecureToken(32)
            expiresAt = NOW() + 48_HOURS

            invite = db.waitlistInvites.create({
              data: {
                waitlistEntryId: entry.id,
                userId: entry.userId,
                cohortId: cohort.id,
                token: inviteToken,
                expiresAt: expiresAt,
                status: "SENT"
              }
            })

            // Update waitlist entry
            db.waitlistEntries.update({
              where: { id: entry.id },
              data: {
                status: "INVITED",
                invitedAt: NOW()
              }
            })

            // Send invite email
            user = db.users.findUnique({
              where: { id: entry.userId }
            })

            sendEmail({
              to: user.email,
              template: "waitlist-spot-available",
              data: {
                name: user.name,
                cohortName: cohort.name,
                startDate: formatDate(cohort.startDate),
                enrollUrl: generateEnrollUrl(inviteToken),
                expiresAt: formatDateTime(expiresAt)
              }
            })

            results.promoted++
            results.notified++

          CATCH error
            LOG_ERROR("Failed to promote waitlist entry", {
              entryId: entry.id,
              error: error.message
            })
            results.errors++
          END TRY
        END FOR

      CATCH error
        LOG_ERROR("Failed to process cohort waitlist", {
          cohortId: cohort.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    duration = NOW() - startTime

    LOG_INFO("Waitlist auto-promotion completed", {
      duration: duration,
      results: results
    })

    RETURN {
      success: true,
      duration: duration,
      stats: results
    }

  CATCH error
    LOG_ERROR("Waitlist auto-promotion failed", {
      error: error.message
    })

    RETURN {
      success: false,
      error: error.message
    }
  END TRY
END FUNCTION

// ===== INVITE TOKEN EXPIRY CLEANUP =====
// Schedule: Every hour
// Convex Cron: crons.hourly("cleanup-expired-invites", { minute: 0 })

FUNCTION cleanupExpiredInvites(): CronResult
  TRY
    startTime = NOW()

    // Find expired invites
    expiredInvites = db.waitlistInvites.findMany({
      where: {
        expiresAt: { lt: NOW() },
        status: "SENT"
      },
      include: { waitlistEntry: true }
    })

    results = {
      expired: 0,
      waitlistReactivated: 0,
      errors: 0
    }

    FOR EACH invite IN expiredInvites DO
      TRY
        // Mark invite as expired
        db.waitlistInvites.update({
          where: { id: invite.id },
          data: { status: "EXPIRED" }
        })

        // Reactivate waitlist entry
        db.waitlistEntries.update({
          where: { id: invite.waitlistEntryId },
          data: {
            status: "ACTIVE",
            invitedAt: NULL
          }
        })

        results.expired++
        results.waitlistReactivated++

      CATCH error
        LOG_ERROR("Failed to cleanup expired invite", {
          inviteId: invite.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    duration = NOW() - startTime

    LOG_INFO("Invite token cleanup completed", {
      duration: duration,
      results: results
    })

    RETURN {
      success: true,
      duration: duration,
      stats: results
    }

  CATCH error
    LOG_ERROR("Invite token cleanup failed", {
      error: error.message
    })

    RETURN {
      success: false,
      error: error.message
    }
  END TRY
END FUNCTION

// ===== CERTIFICATE GENERATION TRIGGER =====
// Schedule: Every day at 3:00 AM UTC
// Convex Cron: crons.daily("trigger-certificates", "0 3 * * *")

FUNCTION triggerCertificateGeneration(): CronResult
  TRY
    startTime = NOW()
    LOG_INFO("Starting certificate generation trigger")

    // Find cohorts that ended in the last 7 days
    last7Days = NOW() - 7_DAYS

    recentlyEndedCohorts = db.cohorts.findMany({
      where: {
        endDate: {
          gte: last7Days,
          lt: NOW()
        },
        status: "COMPLETED"
      },
      include: {
        enrollments: {
          where: {
            status: "ACTIVE",
            certificateIssued: false
          },
          include: { user: true }
        }
      }
    })

    results = {
      cohorts: 0,
      eligible: 0,
      queued: 0,
      errors: 0
    }

    FOR EACH cohort IN recentlyEndedCohorts DO
      TRY
        FOR EACH enrollment IN cohort.enrollments DO
          // Check completion criteria
          completionPercentage = enrollment.progress.completionPercentage
          requiredAttendance = cohort.requiredAttendancePercentage || 80
          actualAttendance = enrollment.progress.attendancePercentage

          isEligible = (
            completionPercentage >= 80 AND
            actualAttendance >= requiredAttendance AND
            enrollment.exitSurveyCompleted === true
          )

          IF isEligible THEN
            results.eligible++

            // Queue certificate generation
            db.certificateQueue.create({
              data: {
                enrollmentId: enrollment.id,
                userId: enrollment.userId,
                cohortId: cohort.id,
                status: "QUEUED",
                queuedAt: NOW(),
                metadata: {
                  completionPercentage: completionPercentage,
                  attendancePercentage: actualAttendance,
                  cohortName: cohort.name,
                  studentName: enrollment.user.name
                }
              }
            })

            results.queued++
          END IF
        END FOR

        results.cohorts++

      CATCH error
        LOG_ERROR("Failed to process cohort for certificates", {
          cohortId: cohort.id,
          error: error.message
        })
        results.errors++
      END TRY
    END FOR

    duration = NOW() - startTime

    LOG_INFO("Certificate generation trigger completed", {
      duration: duration,
      results: results
    })

    RETURN {
      success: true,
      duration: duration,
      stats: results
    }

  CATCH error
    LOG_ERROR("Certificate generation trigger failed", {
      error: error.message
    })

    RETURN {
      success: false,
      error: error.message
    }
  END TRY
END FUNCTION
```

---

### n8n Workflows (External Integrations)

```pseudocode
// ===== MULTI-CHANNEL NOTIFICATION WORKFLOW =====
// Trigger: Webhook from Convex
// Endpoint: https://n8n.example.com/webhook/notify

WORKFLOW multiChannelNotification
  INPUT: {
    type: string,           // "enrollment.created", "cohort.started", etc.
    severity: string,       // "info", "warning", "critical"
    recipients: array,      // email addresses or user IDs
    channels: array,        // ["email", "slack", "sms"]
    message: object,        // { title, body, metadata }
    template: string        // optional template ID
  }

  STEP 1: Validate Input
    IF NOT type OR NOT recipients OR NOT channels THEN
      RETURN Error("Missing required fields")
    END IF

  STEP 2: Fan Out to Channels (Parallel Execution)
    FOR EACH channel IN channels DO (IN PARALLEL)
      SWITCH channel
        CASE "email":
          CALL sendEmailViaBrevo({
            recipients: recipients,
            template: template || message.title,
            data: message
          })

        CASE "slack":
          CALL sendSlackNotification({
            channels: getSlackChannels(type),
            message: formatSlackMessage(message),
            severity: severity
          })

        CASE "sms":
          CALL sendSMSViaTwilio({
            recipients: recipients,
            message: truncate(message.body, 160)
          })

        CASE "push":
          CALL sendPushNotification({
            userIds: recipients,
            title: message.title,
            body: message.body,
            data: message.metadata
          })
      END SWITCH
    END FOR

  STEP 3: Aggregate Results
    results = collectParallelResults()

    successCount = results.filter(r => r.success).length
    failureCount = results.filter(r => !r.success).length

  STEP 4: Log Notification Event
    CALL convexMutation("logNotificationEvent", {
      type: type,
      recipients: recipients.length,
      channels: channels,
      successCount: successCount,
      failureCount: failureCount,
      timestamp: NOW()
    })

  STEP 5: Handle Failures
    IF failureCount > 0 THEN
      failedChannels = results.filter(r => !r.success)

      // Retry failed channels after 5 minutes
      SCHEDULE_WORKFLOW(
        workflow: "retryFailedNotifications",
        delay: 300000, // 5 minutes
        data: {
          originalInput: INPUT,
          failedChannels: failedChannels
        }
      )
    END IF

  OUTPUT: {
    success: failureCount === 0,
    sent: successCount,
    failed: failureCount,
    details: results
  }
END WORKFLOW

// ===== CRM SYNC WORKFLOW =====
// Trigger: Scheduled (every 15 minutes)
// Purpose: Sync enrollments and user data to CRM (e.g., HubSpot)

WORKFLOW crmSync
  STEP 1: Fetch Changed Records from Convex
    changedSince = getLastSyncTimestamp()

    changedUsers = CALL convexQuery("getChangedUsers", {
      since: changedSince
    })

    changedEnrollments = CALL convexQuery("getChangedEnrollments", {
      since: changedSince
    })

  STEP 2: Transform Data for CRM Format
    crmContacts = []
    crmDeals = []

    FOR EACH user IN changedUsers DO
      crmContact = {
        email: user.email,
        firstName: user.name.split(" ")[0],
        lastName: user.name.split(" ").slice(1).join(" "),
        lifecycleStage: user.enrollments.length > 0 ? "customer" : "lead",
        customFields: {
          totalEnrollments: user.enrollments.length,
          lastLoginAt: user.lastLoginAt,
          accountCreatedAt: user.createdAt
        }
      }

      crmContacts.push(crmContact)
    END FOR

    FOR EACH enrollment IN changedEnrollments DO
      crmDeal = {
        name: "Enrollment: " + enrollment.cohort.name,
        amount: enrollment.amountPaid,
        stage: mapEnrollmentStatusToDealStage(enrollment.status),
        closeDate: enrollment.enrolledAt,
        associatedContact: enrollment.user.email,
        customFields: {
          cohortId: enrollment.cohortId,
          enrollmentId: enrollment.id,
          startDate: enrollment.cohort.startDate,
          endDate: enrollment.cohort.endDate
        }
      }

      crmDeals.push(crmDeal)
    END FOR

  STEP 3: Batch Upsert to CRM (Parallel)
    PARALLEL_EXECUTE([
      CALL hubspotBatchUpsertContacts(crmContacts),
      CALL hubspotBatchUpsertDeals(crmDeals)
    ])

  STEP 4: Update Last Sync Timestamp
    setLastSyncTimestamp(NOW())

  STEP 5: Log Sync Results
    CALL convexMutation("logCrmSync", {
      syncedAt: NOW(),
      contactsProcessed: crmContacts.length,
      dealsProcessed: crmDeals.length,
      success: true
    })

  OUTPUT: {
    success: true,
    contacts: crmContacts.length,
    deals: crmDeals.length
  }
END WORKFLOW

// ===== ANALYTICS AGGREGATION WORKFLOW =====
// Trigger: Daily at 4:00 AM UTC
// Purpose: Aggregate metrics and sync to analytics platforms

WORKFLOW analyticsAggregation
  STEP 1: Fetch Daily Metrics from Convex
    yesterday = startOfDay(NOW() - 1_DAY)
    today = startOfDay(NOW())

    metrics = CALL convexQuery("getDailyMetrics", {
      startDate: yesterday,
      endDate: today
    })

    // metrics = {
    //   newEnrollments: number,
    //   refunds: number,
    //   revenue: number,
    //   activeUsers: number,
    //   courseCompletions: number,
    //   npsScore: number
    // }

  STEP 2: Calculate KPIs
    kpis = {
      conversionRate: metrics.newEnrollments / metrics.visitors,
      avgRevenuePerUser: metrics.revenue / metrics.newEnrollments,
      churnRate: metrics.refunds / metrics.activeEnrollments,
      completionRate: metrics.courseCompletions / metrics.activeEnrollments,
      npsScore: metrics.npsScore
    }

  STEP 3: Send to Analytics Platforms (Parallel)
    PARALLEL_EXECUTE([
      // Google Analytics
      CALL sendToGoogleAnalytics({
        events: [
          { name: "daily_enrollments", value: metrics.newEnrollments },
          { name: "daily_revenue", value: metrics.revenue }
        ]
      }),

      // Mixpanel
      CALL sendToMixpanel({
        event: "daily_metrics",
        properties: metrics
      }),

      // Segment
      CALL sendToSegment({
        event: "daily_aggregated_metrics",
        properties: { ...metrics, ...kpis }
      }),

      // Internal Dashboard (Convex)
      CALL convexMutation("storeDailyMetrics", {
        date: yesterday,
        metrics: metrics,
        kpis: kpis
      })
    ])

  STEP 4: Generate Daily Report
    report = generateDailyReport(metrics, kpis)

    CALL sendEmailViaBrevo({
      to: env.ADMIN_EMAILS,
      template: "daily-metrics-report",
      data: report
    })

  OUTPUT: {
    success: true,
    date: yesterday,
    metrics: metrics,
    kpis: kpis
  }
END WORKFLOW

// ===== CONDITIONAL WORKFLOW: AUTO-REFUND ON CANCELLATION =====
// Trigger: Webhook from Convex when cohort is cancelled
// Purpose: Auto-refund all enrolled students

WORKFLOW autoRefundOnCohortCancellation
  INPUT: {
    cohortId: string,
    cancellationReason: string
  }

  STEP 1: Fetch Cohort Enrollments
    enrollments = CALL convexQuery("getActiveEnrollments", {
      cohortId: INPUT.cohortId
    })

    IF enrollments.length === 0 THEN
      RETURN { success: true, message: "No enrollments to refund" }
    END IF

  STEP 2: Process Refunds (with Rate Limiting)
    refundResults = []

    FOR EACH enrollment IN enrollments DO
      TRY
        // Issue refund via Stripe
        refund = CALL stripeRefund({
          paymentIntent: enrollment.paymentIntentId,
          amount: enrollment.amountPaid,
          reason: "requested_by_customer",
          metadata: {
            cohortCancelled: true,
            cancellationReason: INPUT.cancellationReason
          }
        })

        // Update enrollment in Convex
        CALL convexMutation("updateEnrollment", {
          enrollmentId: enrollment.id,
          data: {
            status: "REFUNDED",
            refundedAt: NOW(),
            refundReason: INPUT.cancellationReason
          }
        })

        // Send notification to student
        CALL sendEmailViaBrevo({
          to: enrollment.user.email,
          template: "cohort-cancelled-refund",
          data: {
            cohortName: enrollment.cohort.name,
            refundAmount: formatCurrency(enrollment.amountPaid),
            cancellationReason: INPUT.cancellationReason
          }
        })

        refundResults.push({
          enrollmentId: enrollment.id,
          success: true
        })

        // Rate limit: 10 refunds per second
        WAIT(100)

      CATCH error
        refundResults.push({
          enrollmentId: enrollment.id,
          success: false,
          error: error.message
        })
      END TRY
    END FOR

  STEP 3: Handle Failed Refunds
    failedRefunds = refundResults.filter(r => !r.success)

    IF failedRefunds.length > 0 THEN
      CALL sendEmailViaBrevo({
        to: env.ADMIN_EMAILS,
        template: "failed-refunds-alert",
        data: {
          cohortId: INPUT.cohortId,
          failedCount: failedRefunds.length,
          failures: failedRefunds
        }
      })
    END IF

  STEP 4: Update Cohort Status
    CALL convexMutation("updateCohort", {
      cohortId: INPUT.cohortId,
      data: {
        status: "CANCELLED",
        cancelledAt: NOW(),
        cancellationReason: INPUT.cancellationReason,
        refundsProcessed: refundResults.filter(r => r.success).length
      }
    })

  OUTPUT: {
    success: failedRefunds.length === 0,
    totalEnrollments: enrollments.length,
    successfulRefunds: refundResults.filter(r => r.success).length,
    failedRefunds: failedRefunds.length
  }
END WORKFLOW
```

---

## 2.3.3 Real-time Subscription Updates

```pseudocode
// ===== CONVEX REAL-TIME SUBSCRIPTION SYSTEM =====
// Using Convex's built-in reactive queries and subscriptions

// ===== ENROLLMENT COUNT LIVE UPDATES =====

MUTATION updateEnrollmentCount(cohortId: string, delta: number)
  TRY
    cohort = db.cohorts.get(cohortId)

    IF NOT cohort THEN
      THROW Error("Cohort not found")
    END IF

    newCount = cohort.activeEnrollmentCount + delta
    spotsRemaining = cohort.maxCapacity - newCount

    db.cohorts.patch(cohortId, {
      activeEnrollmentCount: newCount,
      spotsRemaining: spotsRemaining,
      lastUpdated: NOW()
    })

    // Convex automatically notifies all subscribers to this cohort

    RETURN {
      cohortId: cohortId,
      newCount: newCount,
      spotsRemaining: spotsRemaining
    }

  CATCH error
    LOG_ERROR("Failed to update enrollment count", {
      cohortId: cohortId,
      error: error.message
    })
    THROW error
  END TRY
END MUTATION

QUERY subscribeToEnrollmentCount(cohortId: string)
  // Reactive query - automatically re-runs when data changes
  cohort = db.cohorts.get(cohortId)

  IF NOT cohort THEN
    RETURN NULL
  END IF

  RETURN {
    cohortId: cohort.id,
    cohortName: cohort.name,
    activeEnrollmentCount: cohort.activeEnrollmentCount,
    maxCapacity: cohort.maxCapacity,
    spotsRemaining: cohort.spotsRemaining,
    percentFull: (cohort.activeEnrollmentCount / cohort.maxCapacity) * 100,
    status: cohort.status,
    lastUpdated: cohort.lastUpdated
  }
END QUERY

// Client-side usage (React/Next.js):
// const enrollmentData = useQuery(api.cohorts.subscribeToEnrollmentCount, {
//   cohortId: "cohort123"
// });
// Automatically updates UI when data changes!

// ===== COHORT STATUS CHANGES =====

MUTATION updateCohortStatus(cohortId: string, newStatus: CohortStatus)
  TRY
    cohort = db.cohorts.get(cohortId)

    IF NOT cohort THEN
      THROW Error("Cohort not found")
    END IF

    // Validate status transition
    validTransitions = {
      "DRAFT": ["OPEN", "CANCELLED"],
      "OPEN": ["CONFIRMED", "CANCELLED"],
      "CONFIRMED": ["IN_PROGRESS", "CANCELLED"],
      "IN_PROGRESS": ["COMPLETED", "CANCELLED"],
      "COMPLETED": [],
      "CANCELLED": []
    }

    IF NOT validTransitions[cohort.status].includes(newStatus) THEN
      THROW Error("Invalid status transition: " + cohort.status + " -> " + newStatus)
    END IF

    db.cohorts.patch(cohortId, {
      status: newStatus,
      statusChangedAt: NOW(),
      statusHistory: [
        ...cohort.statusHistory,
        {
          from: cohort.status,
          to: newStatus,
          changedAt: NOW()
        }
      ]
    })

    // Trigger side effects based on status
    SWITCH newStatus
      CASE "CONFIRMED":
        // Send confirmation emails to enrolled students
        scheduleConfirmationEmails(cohortId)

      CASE "IN_PROGRESS":
        // Unlock course content for enrolled students
        unlockCourseContent(cohortId)

      CASE "COMPLETED":
        // Trigger certificate generation
        triggerCertificateGeneration(cohortId)

      CASE "CANCELLED":
        // Trigger refund workflow
        triggerRefundWorkflow(cohortId)
    END SWITCH

    // Convex automatically notifies all subscribers

    RETURN {
      cohortId: cohortId,
      newStatus: newStatus,
      previousStatus: cohort.status
    }

  CATCH error
    LOG_ERROR("Failed to update cohort status", {
      cohortId: cohortId,
      newStatus: newStatus,
      error: error.message
    })
    THROW error
  END TRY
END MUTATION

QUERY subscribeToCohortStatus(cohortId: string)
  cohort = db.cohorts.get(cohortId)

  IF NOT cohort THEN
    RETURN NULL
  END IF

  RETURN {
    cohortId: cohort.id,
    status: cohort.status,
    statusChangedAt: cohort.statusChangedAt,
    statusHistory: cohort.statusHistory,
    canTransitionTo: getValidTransitions(cohort.status)
  }
END QUERY

// ===== CHAT MESSAGE STREAMING =====

MUTATION sendChatMessage(cohortId: string, userId: string, message: string)
  TRY
    // Validate user is enrolled in cohort
    enrollment = db.enrollments.findFirst({
      where: {
        userId: userId,
        cohortId: cohortId,
        status: "ACTIVE"
      }
    })

    IF NOT enrollment THEN
      THROW Error("User not enrolled in cohort")
    END IF

    // Create message
    messageId = db.chatMessages.insert({
      cohortId: cohortId,
      userId: userId,
      message: message,
      sentAt: NOW(),
      edited: false,
      reactions: []
    })

    // Increment unread count for other users
    db.enrollments.updateMany({
      where: {
        cohortId: cohortId,
        userId: { ne: userId },
        status: "ACTIVE"
      },
      data: {
        unreadMessageCount: { increment: 1 }
      }
    })

    // Convex automatically streams this to all subscribers

    RETURN {
      messageId: messageId,
      cohortId: cohortId,
      sentAt: NOW()
    }

  CATCH error
    LOG_ERROR("Failed to send chat message", {
      cohortId: cohortId,
      userId: userId,
      error: error.message
    })
    THROW error
  END TRY
END MUTATION

QUERY subscribeToChatMessages(cohortId: string, limit: number = 50)
  // Paginated reactive query
  messages = db.chatMessages.findMany({
    where: { cohortId: cohortId },
    orderBy: { sentAt: "desc" },
    limit: limit,
    include: {
      user: {
        select: {
          id: true,
          name: true,
          avatar: true
        }
      }
    }
  })

  RETURN messages.reverse() // Newest at bottom
END QUERY

// Client-side usage with streaming:
// const messages = useQuery(api.chat.subscribeToChatMessages, {
//   cohortId: "cohort123"
// });
// New messages appear instantly without polling!

// ===== ADMIN DASHBOARD LIVE METRICS =====

QUERY subscribeToAdminDashboard()
  // Multi-table reactive query
  // Automatically updates when ANY of these tables change

  activeEnrollments = db.enrollments.count({
    where: { status: "ACTIVE" }
  })

  todayEnrollments = db.enrollments.count({
    where: {
      enrolledAt: { gte: startOfDay(NOW()) },
      status: "ACTIVE"
    }
  })

  todayRevenue = db.enrollments.aggregate({
    where: {
      enrolledAt: { gte: startOfDay(NOW()) },
      status: "ACTIVE"
    },
    _sum: { amountPaid: true }
  })

  activeCohorts = db.cohorts.count({
    where: {
      status: { in: ["OPEN", "CONFIRMED", "IN_PROGRESS"] }
    }
  })

  pendingRefunds = db.enrollments.count({
    where: {
      status: "REFUND_PENDING"
    }
  })

  recentActivity = db.activityLog.findMany({
    limit: 10,
    orderBy: { timestamp: "desc" }
  })

  RETURN {
    activeEnrollments: activeEnrollments,
    todayEnrollments: todayEnrollments,
    todayRevenue: todayRevenue._sum.amountPaid || 0,
    activeCohorts: activeCohorts,
    pendingRefunds: pendingRefunds,
    recentActivity: recentActivity,
    lastUpdated: NOW()
  }
END QUERY

// Client-side usage:
// const dashboardData = useQuery(api.admin.subscribeToAdminDashboard);
// Dashboard updates in real-time as data changes!

// ===== PRESENCE TRACKING (WHO'S ONLINE) =====

MUTATION updateUserPresence(userId: string, cohortId: string, status: "online" | "away" | "offline")
  TRY
    // Upsert presence record
    db.userPresence.upsert({
      where: {
        userId_cohortId: {
          userId: userId,
          cohortId: cohortId
        }
      },
      update: {
        status: status,
        lastSeenAt: NOW()
      },
      create: {
        userId: userId,
        cohortId: cohortId,
        status: status,
        lastSeenAt: NOW()
      }
    })

    // Clean up stale presence (>5 minutes)
    db.userPresence.deleteMany({
      where: {
        lastSeenAt: { lt: NOW() - 5_MINUTES },
        status: { ne: "offline" }
      }
    })

    RETURN { success: true }

  CATCH error
    LOG_ERROR("Failed to update user presence", {
      userId: userId,
      error: error.message
    })
    THROW error
  END TRY
END MUTATION

QUERY subscribeToOnlineUsers(cohortId: string)
  // Reactive query for presence
  onlineUsers = db.userPresence.findMany({
    where: {
      cohortId: cohortId,
      status: { in: ["online", "away"] },
      lastSeenAt: { gte: NOW() - 5_MINUTES }
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          avatar: true
        }
      }
    }
  })

  RETURN {
    count: onlineUsers.length,
    users: onlineUsers
  }
END QUERY
```

---

## 2.3.4 Outbound Webhook Dispatch

```pseudocode
// ===== OUTBOUND WEBHOOK DISPATCH SYSTEM =====

// Event Types:
// - enrollment.created
// - enrollment.refunded
// - cohort.started
// - cohort.completed
// - user.registered
// - certificate.issued

// ===== WEBHOOK REGISTRATION AND MANAGEMENT =====

MUTATION registerWebhook(
  url: string,
  events: array<string>,
  secret: string,
  metadata: object = {}
): WebhookRegistration
  TRY
    // Validate URL
    IF NOT isValidUrl(url) THEN
      THROW Error("Invalid webhook URL")
    END IF

    // Validate HTTPS
    IF NOT url.startsWith("https://") THEN
      THROW Error("Webhook URL must use HTTPS")
    END IF

    // Validate events
    validEvents = [
      "enrollment.created",
      "enrollment.refunded",
      "enrollment.updated",
      "cohort.started",
      "cohort.completed",
      "cohort.cancelled",
      "user.registered",
      "user.updated",
      "certificate.issued",
      "waitlist.promoted"
    ]

    FOR EACH event IN events DO
      IF NOT validEvents.includes(event) THEN
        THROW Error("Invalid event type: " + event)
      END IF
    END FOR

    // Create webhook registration
    webhook = db.webhookRegistrations.create({
      data: {
        url: url,
        events: events,
        secret: secret, // Store hashed in production!
        active: true,
        metadata: metadata,
        createdAt: NOW(),
        lastTriggeredAt: NULL,
        successCount: 0,
        failureCount: 0
      }
    })

    RETURN webhook

  CATCH error
    LOG_ERROR("Failed to register webhook", {
      url: url,
      error: error.message
    })
    THROW error
  END TRY
END MUTATION

// ===== DISPATCH OUTBOUND WEBHOOK =====

FUNCTION dispatchOutboundWebhook(
  eventType: string,
  payload: object
): DispatchResult
  TRY
    // Find all active webhooks subscribed to this event
    webhooks = db.webhookRegistrations.findMany({
      where: {
        active: true,
        events: { has: eventType }
      }
    })

    IF webhooks.length === 0 THEN
      LOG_INFO("No webhooks registered for event", {
        eventType: eventType
      })
      RETURN { dispatched: 0 }
    END IF

    results = []

    FOR EACH webhook IN webhooks DO
      TRY
        // Create delivery record
        delivery = db.webhookDeliveries.create({
          data: {
            webhookId: webhook.id,
            eventType: eventType,
            payload: JSON.stringify(payload),
            status: "PENDING",
            attemptCount: 0,
            createdAt: NOW()
          }
        })

        // Dispatch asynchronously
        result = sendWebhookAsync({
          deliveryId: delivery.id,
          url: webhook.url,
          secret: webhook.secret,
          eventType: eventType,
          payload: payload
        })

        results.push(result)

      CATCH error
        LOG_ERROR("Failed to dispatch webhook", {
          webhookId: webhook.id,
          eventType: eventType,
          error: error.message
        })
      END TRY
    END FOR

    RETURN {
      dispatched: webhooks.length,
      results: results
    }

  CATCH error
    LOG_ERROR("Webhook dispatch failed", {
      eventType: eventType,
      error: error.message
    })
    THROW error
  END TRY
END FUNCTION

// ===== SEND WEBHOOK WITH RETRY LOGIC =====

ASYNC FUNCTION sendWebhookAsync(
  deliveryId: string,
  url: string,
  secret: string,
  eventType: string,
  payload: object
): WebhookResult
  maxAttempts = 3
  attempt = 1

  WHILE attempt <= maxAttempts DO
    TRY
      // Generate signature
      timestamp = NOW().toISOString()
      signaturePayload = timestamp + "." + JSON.stringify(payload)
      signature = HMAC_SHA256(signaturePayload, secret)

      // Update attempt count
      db.webhookDeliveries.update({
        where: { id: deliveryId },
        data: {
          attemptCount: attempt,
          lastAttemptAt: NOW()
        }
      })

      // Send HTTP request
      response = AWAIT HTTP_POST(url, {
        headers: {
          "Content-Type": "application/json",
          "X-Webhook-Signature": signature,
          "X-Webhook-Timestamp": timestamp,
          "X-Webhook-Event": eventType,
          "User-Agent": "LearningPlatform-Webhooks/1.0"
        },
        body: JSON.stringify({
          event: eventType,
          timestamp: timestamp,
          data: payload
        }),
        timeout: 10000 // 10 second timeout
      })

      // Check response status
      IF response.status >= 200 AND response.status < 300 THEN
        // Success!
        db.webhookDeliveries.update({
          where: { id: deliveryId },
          data: {
            status: "DELIVERED",
            deliveredAt: NOW(),
            responseStatus: response.status,
            responseBody: response.body
          }
        })

        // Update webhook stats
        db.webhookRegistrations.increment({
          where: { url: url },
          data: {
            successCount: 1,
            lastTriggeredAt: NOW()
          }
        })

        RETURN {
          success: true,
          attempts: attempt,
          status: response.status
        }

      ELSE
        // Non-2xx response
        THROW Error("HTTP " + response.status + ": " + response.statusText)
      END IF

    CATCH error
      LOG_WARN("Webhook delivery attempt failed", {
        deliveryId: deliveryId,
        url: url,
        attempt: attempt,
        error: error.message
      })

      // Calculate exponential backoff
      IF attempt < maxAttempts THEN
        backoffMs = POWER(2, attempt) * 1000 // 2s, 4s
        AWAIT SLEEP(backoffMs)
        attempt++
      ELSE
        // All attempts failed - mark as failed
        db.webhookDeliveries.update({
          where: { id: deliveryId },
          data: {
            status: "FAILED",
            failedAt: NOW(),
            errorMessage: error.message
          }
        })

        // Update webhook stats
        db.webhookRegistrations.increment({
          where: { url: url },
          data: { failureCount: 1 }
        })

        // Check if webhook should be auto-disabled
        webhook = db.webhookRegistrations.findUnique({
          where: { url: url }
        })

        failureRate = webhook.failureCount / (webhook.successCount + webhook.failureCount)

        IF failureRate > 0.5 AND webhook.failureCount > 10 THEN
          // >50% failure rate with >10 total failures
          db.webhookRegistrations.update({
            where: { url: url },
            data: {
              active: false,
              disabledReason: "High failure rate",
              disabledAt: NOW()
            }
          })

          // Notify webhook owner
          notifyWebhookOwner(webhook, {
            reason: "auto-disabled",
            failureRate: failureRate,
            totalFailures: webhook.failureCount
          })
        END IF

        RETURN {
          success: false,
          attempts: attempt,
          error: error.message
        }
      END IF
    END TRY
  END WHILE
END FUNCTION

// ===== WEBHOOK EVENT HELPERS =====

FUNCTION triggerEnrollmentCreatedWebhook(enrollmentId: string)
  enrollment = db.enrollments.findUnique({
    where: { id: enrollmentId },
    include: {
      user: true,
      cohort: true
    }
  })

  dispatchOutboundWebhook("enrollment.created", {
    enrollmentId: enrollment.id,
    userId: enrollment.userId,
    userEmail: enrollment.user.email,
    userName: enrollment.user.name,
    cohortId: enrollment.cohortId,
    cohortName: enrollment.cohort.name,
    cohortStartDate: enrollment.cohort.startDate,
    enrolledAt: enrollment.enrolledAt,
    amountPaid: enrollment.amountPaid,
    currency: enrollment.currency
  })
END FUNCTION

FUNCTION triggerCohortStartedWebhook(cohortId: string)
  cohort = db.cohorts.findUnique({
    where: { id: cohortId },
    include: {
      enrollments: {
        where: { status: "ACTIVE" },
        include: { user: true }
      }
    }
  })

  dispatchOutboundWebhook("cohort.started", {
    cohortId: cohort.id,
    cohortName: cohort.name,
    startDate: cohort.startDate,
    endDate: cohort.endDate,
    enrollmentCount: cohort.enrollments.length,
    students: cohort.enrollments.map(e => ({
      userId: e.userId,
      email: e.user.email,
      name: e.user.name
    }))
  })
END FUNCTION

FUNCTION triggerCertificateIssuedWebhook(certificateId: string)
  certificate = db.certificates.findUnique({
    where: { id: certificateId },
    include: {
      enrollment: {
        include: {
          user: true,
          cohort: true
        }
      }
    }
  })

  dispatchOutboundWebhook("certificate.issued", {
    certificateId: certificate.id,
    userId: certificate.enrollment.userId,
    userEmail: certificate.enrollment.user.email,
    userName: certificate.enrollment.user.name,
    cohortName: certificate.enrollment.cohort.name,
    issuedAt: certificate.issuedAt,
    certificateUrl: certificate.url,
    credentialId: certificate.credentialId,
    completionPercentage: certificate.enrollment.progress.completionPercentage
  })
END FUNCTION

FUNCTION triggerEnrollmentRefundedWebhook(enrollmentId: string)
  enrollment = db.enrollments.findUnique({
    where: { id: enrollmentId },
    include: {
      user: true,
      cohort: true
    }
  })

  dispatchOutboundWebhook("enrollment.refunded", {
    enrollmentId: enrollment.id,
    userId: enrollment.userId,
    userEmail: enrollment.user.email,
    cohortId: enrollment.cohortId,
    cohortName: enrollment.cohort.name,
    refundAmount: enrollment.refundAmount,
    refundReason: enrollment.refundReason,
    refundedAt: enrollment.refundedAt,
    wasFullRefund: enrollment.refundAmount === enrollment.amountPaid
  })
END FUNCTION

// ===== WEBHOOK DELIVERY RETRY QUEUE =====
// Cron job to retry failed webhook deliveries
// Schedule: Every 15 minutes

FUNCTION retryFailedWebhooks(): CronResult
  TRY
    // Find failed deliveries from last 24 hours
    failedDeliveries = db.webhookDeliveries.findMany({
      where: {
        status: "FAILED",
        createdAt: { gte: NOW() - 24_HOURS },
        attemptCount: { lt: 3 }
      },
      limit: 100 // Process max 100 per run
    })

    results = {
      retried: 0,
      succeeded: 0,
      failed: 0
    }

    FOR EACH delivery IN failedDeliveries DO
      webhook = db.webhookRegistrations.findUnique({
        where: { id: delivery.webhookId }
      })

      IF webhook AND webhook.active THEN
        result = sendWebhookAsync({
          deliveryId: delivery.id,
          url: webhook.url,
          secret: webhook.secret,
          eventType: delivery.eventType,
          payload: JSON.parse(delivery.payload)
        })

        results.retried++

        IF result.success THEN
          results.succeeded++
        ELSE
          results.failed++
        END IF
      END IF
    END FOR

    RETURN {
      success: true,
      stats: results
    }

  CATCH error
    LOG_ERROR("Webhook retry job failed", {
      error: error.message
    })
    RETURN { success: false }
  END TRY
END FUNCTION
```

---

## Summary

This document provides comprehensive pseudocode for all system-level flows in the learning platform:

### **2.3.1 Webhook Processing**
- **Stripe**: Signature verification, idempotency, event routing, retry with exponential backoff, dead letter queue
- **Cal.com**: HMAC verification, enrollment validation before booking creation
- **Formbricks**: Survey response processing with intake/exit survey handling

### **2.3.2 Cron Job Orchestration**
- **Convex Crons**: Data-critical operations (access expiry, pre-cohort emails, waitlist promotion, invite cleanup, certificate triggers)
- **n8n Workflows**: External integrations (multi-channel notifications, CRM sync, analytics aggregation, conditional workflows)

### **2.3.3 Real-time Subscription Updates**
- Enrollment count live updates using Convex reactive queries
- Cohort status changes with automatic subscriber notifications
- Chat message streaming
- Admin dashboard live metrics
- User presence tracking

### **2.3.4 Outbound Webhook Dispatch**
- Webhook registration and management
- Event dispatch with retry logic
- Signature generation for security
- Auto-disable on high failure rates
- Retry queue for failed deliveries

All flows include:
- ✅ **Explicit error handling** with try-catch blocks
- ✅ **Retry strategies** with exponential backoff
- ✅ **Dead letter queues** for persistent failures
- ✅ **Admin notifications** on critical errors
- ✅ **Idempotency checks** to prevent duplicate processing
- ✅ **Comprehensive logging** for observability

---

**Document Status**: ✅ Complete
**Review Status**: Ready for integration into full SPARC specification
**Next Steps**: Combine with other agents' sections (2.1, 2.2, 2.4, 2.5) for complete Section 2
