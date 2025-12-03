# Learner Experience Flows - Pseudocode

## 2.1.1 B2C Purchase Flow with FOMO

```pseudocode
FUNCTION BrowseAndPurchase(userId, courseId):
  // Display courses with live capacity indicators
  courses = FETCH courses with capacity metrics
  FOR EACH course IN courses:
    spots_left = capacity.max - registrations.count
    DISPLAY course.title, course.price, "X spots left" badge
    IF spots_left < 5:
      HIGHLIGHT red "Only X spots remaining!"

  // Cohort selection
  WHEN user.clicks(EnrollButton):
    cohort = SELECT cohort from available cohorts
    IF cohort.spots_left == 0:
      SHOW modal "This cohort is full, join waitlist?"
      IF user.confirms:
        ADD user to waitlist
        SEND confirmation email
      RETURN

    // Atomic capacity validation + checkout
    TRANSACTION atomicCheckout:
      TRY:
        LOCK cohort.capacity_semaphore(1 second timeout)
        IF cohort.spots_left <= 0:
          THROW CohortFullError

        // Create Stripe session
        stripe_session = CREATE stripe.checkout.session(
          line_items: [{ price: course.stripe_price_id, quantity: 1 }],
          metadata: { cohort_id, user_id, timestamp: now() }
        )
        DECREMENT cohort.spots_left (optimistic)
        RELEASE lock
        REDIRECT to stripe_session.url

      CATCH stripe.PaymentError:
        ROLLBACK cohort.spots_left
        SHOW "Payment failed, please try again"

      CATCH CohortFullError:
        // Race condition: another user grabbed last spot
        SHOW "Cohort filled while processing. Options:"
        OFFER: [
          "Join waitlist",
          "Choose different cohort",
          "Full refund (if paid)"
        ]
        IF user.chooses(Refund):
          STRIPE refund payment
          REMOVE registration

    // Stripe webhook: payment.success
    WHEN webhook.event == "checkout.session.completed":
      registration = CREATE registration(
        user_id, cohort_id, status: "ACTIVE"
      )
      SEND confirmation email with next steps
      TRIGGER intake survey (async)
      DISPLAY success page with intake link
      SHOW "Your cohort starts in X days"
```

---

## 2.1.2 Pre-Cohort Onboarding

```pseudocode
FUNCTION PreCohortOnboarding(userId, cohortId):
  cohort = FETCH cohort with start_date
  registration = FETCH registration(userId, cohortId)

  // T-7 days before cohort start
  SCHEDULED_TASK (cohort.start_date - 7 days):
    intake_survey = FETCH survey from Formbricks
    IF NOT registration.survey_completed:
      SEND email via Brevo:
        template: "cohort_welcome_7_days"
        variables: {
          user: registration.user,
          cohort: cohort,
          survey_url: intake_survey.link
        }
      SET registration.email_sent_t7 = true

  // Intake survey completion
  WHEN survey.completion_webhook (Formbricks):
    registration.survey_data = payload
    registration.survey_completed = true
    registration.cohort_profile = EXTRACT profile from survey_data

  // T-2 days before cohort start
  SCHEDULED_TASK (cohort.start_date - 2 days):
    SEND email via Brevo:
      template: "cohort_reminder_2_days"
      variables: { zoom_link: cohort.zoom_url }
    PUSH notification "Cohort starts in 2 days!"

  // T-1 day: final reminder
  SCHEDULED_TASK (cohort.start_date - 1 day):
    SEND email via Brevo:
      template: "cohort_reminder_1_day"
      variables: {
        start_time: cohort.start_date,
        zoom_link: cohort.zoom_url,
        timezone: user.timezone
      }

  // Portal countdown display
  FUNCTION ShowCohortCountdown(cohortId):
    days_remaining = cohort.start_date - now()
    IF days_remaining > 0:
      DISPLAY countdown timer on learner portal
      SHOW Zoom link (appears T-1 day)
      SHOW pre-cohort checklist
    ELSE IF days_remaining == 0:
      SHOW "Cohort starts in X hours"
      HIGHLIGHT Zoom link in bright color
    ELSE:
      SHOW "Cohort is LIVE"
      REDIRECT to Zoom link option
```

---

## 2.1.3 Post-Cohort Experience

```pseudocode
FUNCTION PostCohortExperience(userId, cohortId):
  registration = FETCH registration(userId, cohortId)
  cohort = FETCH cohort

  // T+0 days: immediately after cohort ends
  SCHEDULED_TASK (cohort.end_date + 1 day):
    // NPS Feedback Survey
    nps_survey = CREATE survey in Formbricks:
      questions: [
        "How likely to recommend? (0-10)",
        "What was most valuable?",
        "What could improve?"
      ]
    SEND email via Brevo:
      template: "cohort_feedback_survey"
      variables: { survey_url: nps_survey.link }
    registration.survey_sent_nps = true

  // Process NPS response
  WHEN nps_survey.completion:
    registration.nps_score = payload.question_1
    registration.feedback = payload
    IF registration.nps_score >= 9:
      ADD user to promoters list
      SEND referral incentive email

  // T+2 days: office hours invitation
  SCHEDULED_TASK (cohort.end_date + 2 days):
    SEND email via Brevo:
      template: "office_hours_invitation"
      variables: { office_hours_calendar_link }

  // T+3 days: recording availability
  IF cohort.recording_enabled:
    SCHEDULED_TASK (cohort.end_date + 3 days):
      SEND email via Brevo:
        template: "cohort_recording_available"
        variables: {
          recording_url: cohort.recording_url,
          expiry_date: cohort.recording_expiry
        }
      registration.recording_access_granted = true

  // Certificate generation (Open Badges 3.0)
  WHEN registration.attendance >= cohort.min_attendance_pct:
    badge = GENERATE open_badge_3_0:
      criteria:
        - attendance >= min_attendance_pct
        - survey_completed
        - cohort_status == "COMPLETED"
      fields:
        - issuer: "Project Campfire"
        - recipient: user.email
        - issued_date: now()
        - expires: null (non-expiring)
    registration.badge_id = badge.id
    registration.badge_url = badge.public_url
    SEND email via Brevo:
      template: "certificate_earned"
      variables: {
        badge_url: badge.public_url,
        share_links: GenerateShareLinks(badge.id)
      }

  // Access expiry warnings
  SCHEDULED_TASK (cohort.recording_expiry - 7 days):
    SEND email via Brevo:
      template: "recording_expires_soon"
      variables: {
        days_remaining: 7,
        download_instructions: true
      }

  // Final access expiry
  SCHEDULED_TASK (cohort.recording_expiry):
    registration.recording_access_revoked = true
    SEND email via Brevo:
      template: "recording_access_ended"
```

---

## 2.1.4 Office Hours Booking

```pseudocode
FUNCTION OfficeHoursBooking(userId, cohortId):
  registration = FETCH registration(userId, cohortId)
  cohort = FETCH cohort

  // Eligibility check
  FUNCTION CheckEligibility(userId, cohortId) -> Boolean:
    registration = FETCH registration(userId, cohortId)
    IF registration.status != "COMPLETED":
      RETURN false // Not completed cohort
    IF registration.attendance < cohort.min_attendance_pct:
      RETURN false // Below attendance threshold
    IF registration.office_hours_used >= cohort.office_hours_limit:
      RETURN false // Already used allocation
    RETURN true

  // Display office hours calendar
  WHEN user.navigates(OfficeHoursPage):
    IF NOT CheckEligibility(userId, cohortId):
      SHOW "You are not eligible for office hours"
      SHOW eligibility requirements
      RETURN

    // Embed Cal.com calendar
    DISPLAY calendar embed:
      source: "cal.com/[coach]/office-hours"
      metadata: {
        cohort_id: cohortId,
        user_id: userId
      }

    SHOW "You have X bookings remaining"

  // Cal.com webhook: booking confirmed
  WHEN webhook.event == "booking.created":
    booking_data = webhook.payload
    office_hours_slot = CREATE office_hours_slot:
      user_id: booking_data.user_id,
      cohort_id: cohortId,
      scheduled_at: booking_data.start_time,
      coach_id: booking_data.coach_id,
      status: "CONFIRMED"

    DECREMENT registration.office_hours_used
    SEND confirmation email via Brevo:
      template: "office_hours_confirmed"
      variables: {
        coach_name: booking_data.coach,
        scheduled_time: booking_data.start_time,
        zoom_link: booking_data.location (if Zoom)
      }

  // Cancellation flow
  WHEN user.clicks(CancelBooking) or booking.cancellation_webhook:
    office_hours_slot.status = "CANCELLED"
    INCREMENT registration.office_hours_used // Return booking
    SEND confirmation email
    IF booking.cancellation_reason:
      LOG cancellation_reason for feedback
```

---

## 2.1.5 Knowledge Chatbot

```pseudocode
FUNCTION KnowledgeChat(userId, cohortId, messageText):
  registration = FETCH registration(userId, cohortId)

  // Access validation
  FUNCTION ValidateChatAccess(userId, cohortId) -> Boolean:
    registration = FETCH registration(userId, cohortId)
    IF registration.status != "ACTIVE" AND registration.status != "COMPLETED":
      RETURN false
    IF registration.chat_access_revoked:
      RETURN false
    cohort = FETCH cohort
    IF cohort.chat_available == false:
      RETURN false
    RETURN true

  IF NOT ValidateChatAccess(userId, cohortId):
    THROW AccessDeniedError("Chat access not available")

  // Conversation persistence
  conversation = FETCH or CREATE conversation:
    user_id: userId,
    cohort_id: cohortId

  // Add user message
  message_record = CREATE message:
    conversation_id: conversation.id,
    role: "user",
    content: messageText,
    created_at: now()

  // Prepare context for LLM
  context = BUILD system_prompt:
    role: "You are a helpful learning assistant for Project Campfire cohorts"
    knowledge: cohort.knowledge_base
    user_context: registration.cohort_profile
    constraints: [
      "Stay within course scope",
      "Cite course materials when possible",
      "Refer complex questions to instructors"
    ]

  conversation_history = FETCH recent messages from conversation
    LIMIT 20 (sliding window)

  // Stream response from OpenRouter with fallback
  TRY:
    STREAM response = CALL openrouter.api.completions(
      model: "meta-llama/llama-3.1-70b-instruct",
      messages: [context, ...conversation_history, messageText],
      stream: true,
      temperature: 0.7,
      max_tokens: 1024
    )

    full_response = ""
    WHILE chunk IN response:
      full_response += chunk
      YIELD chunk (stream to client)

  CATCH openrouter.RateLimitError:
    FALLBACK to secondary_model: "meta-llama/llama-3.1-8b-instruct"
    RETRY with secondary model

  CATCH openrouter.TimeoutError:
    SEND "Response taking longer than expected. Please try again."
    RETURN

  // Persist assistant response
  assistant_message = CREATE message:
    conversation_id: conversation.id,
    role: "assistant",
    content: full_response,
    model_used: response.model,
    tokens_used: response.usage.total_tokens,
    created_at: now()

  // Track chat usage
  UPDATE conversation:
    total_messages += 2,
    last_message_at: now(),
    tokens_used += response.usage.total_tokens
```

---

## 2.1.6 Certificate Sharing

```pseudocode
FUNCTION CertificateSharing(userId, cohortId):
  registration = FETCH registration(userId, cohortId)

  // Validate badge exists
  IF NOT registration.badge_id:
    THROW NotFoundError("Certificate not earned")

  badge = FETCH badge(registration.badge_id)

  // Function: Generate share links
  FUNCTION GenerateShareLinks(badgeId, userId) -> ShareLinks:
    badge = FETCH badge(badgeId)
    user = FETCH user(userId)

    // LinkedIn share URL
    linkedin_share_url = ENCODE url:
      "https://www.linkedin.com/feed/?content=share&"
      "&url=" + badge.public_url +
      "&summary=" + URLENCODE(badge.title + " from Project Campfire") +
      "&image=" + URLENCODE(badge.image_url)

    // Twitter share URL
    twitter_share_url = ENCODE url:
      "https://twitter.com/intent/tweet?" +
      "text=" + URLENCODE("I earned the " + badge.title + " certificate!") +
      "&url=" + badge.public_url +
      "&hashtags=learning,ProjectCampfire"

    // PDF download token (one-time use)
    pdf_download_token = GENERATE secure_token:
      user_id: userId,
      badge_id: badgeId,
      expires: now() + 24 hours,
      one_time: true

    RETURN {
      linkedin_url: linkedin_share_url,
      twitter_url: twitter_share_url,
      pdf_download_token: pdf_download_token,
      badge_public_url: badge.public_url,
      email_share_template: "I earned a certificate from Project Campfire!"
    }

  // Display certificate sharing page
  WHEN user.navigates(CertificatePage):
    share_links = GenerateShareLinks(badge.id, userId)

    DISPLAY certificate card:
      badge_image: badge.image_url
      badge_title: badge.title
      issued_date: badge.issued_date
      issuer: "Project Campfire"

    DISPLAY share buttons:
      - "Share on LinkedIn" -> OPEN share_links.linkedin_url
      - "Share on Twitter" -> OPEN share_links.twitter_url
      - "Email Certificate" -> OPEN email_client with template
      - "Download PDF" -> TRIGGER pdf_download_token

  // Verify badge authenticity endpoint
  GET /badges/{badgeId}/verify -> JSON:
    FUNCTION VerifyBadge(badgeId):
      badge = FETCH badge(badgeId)
      IF NOT badge:
        RETURN 404

      RETURN {
        valid: true,
        recipient: HASH(badge.recipient_email),
        issuer: badge.issuer,
        issued_date: badge.issued_date,
        criteria: badge.criteria,
        public_url: badge.public_url
      }

  // PDF generation on download
  WHEN user.clicks(DownloadPDF):
    token = query_param.token

    // Validate one-time token
    VALIDATE token:
      IF token.used:
        THROW "Token already used"
      IF token.expired:
        THROW "Token expired"
      IF token.user_id != current_user_id:
        THROW "Unauthorized"

    // Generate PDF
    pdf = GENERATE certificate_pdf:
      template: "open_badge_3_0_certificate.pdf",
      data: {
        badge_title: badge.title,
        recipient_name: user.name,
        issued_date: badge.issued_date,
        issuer: badge.issuer,
        verification_url: badge.verification_url,
        qr_code: GENERATE_QR(badge.public_url)
      }

    // Mark token as used
    UPDATE token.used = true

    // Send file
    RETURN pdf with headers:
      Content-Type: application/pdf
      Content-Disposition: attachment; filename="certificate.pdf"
```

---

## Summary

| Flow | Key Components | Edge Cases |
|------|---|---|
| **B2C Purchase** | Stripe, capacity semaphore, race condition handling | Cohort fills during checkout, refund + waitlist |
| **Pre-Cohort** | Formbricks surveys, Brevo email scheduling, countdown | Missing survey completion, timezone handling |
| **Post-Cohort** | NPS feedback, office hours, recordings, Open Badges 3.0 | Attendance validation, recording expiry, access revocation |
| **Office Hours** | Cal.com embed, eligibility check, booking webhooks | Exceeded allocation, cancellation refunds |
| **Knowledge Chatbot** | OpenRouter streaming, conversation history, model fallback | Rate limits, timeouts, access validation |
| **Certificate Sharing** | Open Badge URLs, LinkedIn/Twitter share, PDF generation | One-time token validation, badge verification |
