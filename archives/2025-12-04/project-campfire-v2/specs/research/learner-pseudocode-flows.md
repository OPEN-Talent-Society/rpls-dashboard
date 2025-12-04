# Section 2.1: Learner Pseudocode Flows

## 2.1.1 B2C Purchase Flow (with FOMO & Capacity)

```
FLOW: COURSE_DISCOVERY_AND_PURCHASE
ENTRY: User arrives at marketing site or course catalog

1. COURSE_DISCOVERY
   - Display active courses with metadata:
     * Course title, description, learning outcomes
     * Duration (2 days intensive, X hours total)
     * Next cohort dates
     * Price (regular vs early bird)
     * Social proof (testimonials, completion rate)
   - Filter options: skill level, format, date range
   - Search by keyword or learning goal

2. COHORT_SELECTION
   - User clicks "Enroll Now" on course card
   - NAVIGATE to course detail page

   2.1. FETCH cohort availability:
        query = NocoDB.queryRecords({
          tableId: COHORTS_TABLE,
          where: "(courseId,eq,{selectedCourseId})~and(status,eq,Open)~and(startDate,gte,{today})",
          sort: "startDate",
          fields: ["Id", "startDate", "endDate", "capacity", "enrolled", "earlyBirdDeadline", "price", "earlyBirdPrice"]
        })

   2.2. FOR EACH cohort:
        spotsRemaining = cohort.capacity - cohort.enrolled
        percentFull = (cohort.enrolled / cohort.capacity) * 100

        IF percentFull >= 85:
          DISPLAY FOMO_TRIGGER:
            "⚠️ Only {spotsRemaining} spots left in this session!"
            BADGE: "Filling Fast" (red pulsing animation)

        IF percentFull >= 95:
          DISPLAY URGENCY_TRIGGER:
            "🔥 LAST {spotsRemaining} SPOTS - Book Now!"
            BADGE: "Almost Full" (urgent red)

        IF spotsRemaining == 0:
          DISPLAY:
            BUTTON: "Join Waitlist" (secondary style)
            TEXT: "Notify me when next session opens"
          SKIP to next cohort

        IF today <= cohort.earlyBirdDeadline:
          DISPLAY pricing:
            strikethrough: cohort.price
            highlighted: cohort.earlyBirdPrice
            BADGE: "Early Bird - Save ${cohort.price - cohort.earlyBirdPrice}!"
        ELSE:
          DISPLAY pricing: cohort.price

        BUTTON: "Reserve Your Spot" (primary CTA)

3. CAPACITY_CHECK_AND_RESERVE
   - User clicks "Reserve Your Spot" on cohort

   3.1. OPTIMISTIC_LOCK_CHECK:
        currentCohort = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: selectedCohortId,
          fields: ["enrolled", "capacity"]
        })

        IF currentCohort.enrolled >= currentCohort.capacity:
          DISPLAY modal:
            "😔 This session just filled up while you were viewing it!"
            OPTIONS:
              - "Join Waitlist" → GO TO waitlist_flow
              - "View Other Dates" → RETURN TO cohort_selection
              - "Get Notified of New Sessions" → email_capture
          ABORT checkout

   3.2. TEMPORARY_HOLD (5 minutes):
        // Create pending enrollment to reserve spot during checkout
        pendingEnrollment = NocoDB.createRecord({
          tableId: ENROLLMENTS_TABLE,
          fields: {
            cohortId: selectedCohortId,
            status: "pending_payment",
            holdExpiresAt: Date.now() + (5 * 60 * 1000), // 5 min
            reservedAt: Date.now()
          }
        })

        // Increment enrolled count temporarily
        NocoDB.updateRecord({
          tableId: COHORTS_TABLE,
          recordId: selectedCohortId,
          fields: {
            enrolled: currentCohort.enrolled + 1
          }
        })

        START background_timer(5 minutes):
          ON_EXPIRE:
            IF pendingEnrollment.status == "pending_payment":
              // Release hold if payment not completed
              NocoDB.updateRecord({
                tableId: ENROLLMENTS_TABLE,
                recordId: pendingEnrollment.id,
                fields: { status: "expired" }
              })
              NocoDB.updateRecord({
                tableId: COHORTS_TABLE,
                recordId: selectedCohortId,
                fields: { enrolled: currentCohort.enrolled }
              })

4. STRIPE_CHECKOUT_SESSION

   4.1. CALCULATE_FINAL_PRICE:
        cohortData = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: selectedCohortId,
          fields: ["price", "earlyBirdPrice", "earlyBirdDeadline"]
        })

        IF today <= cohortData.earlyBirdDeadline:
          finalPrice = cohortData.earlyBirdPrice
          priceType = "early_bird"
        ELSE:
          finalPrice = cohortData.price
          priceType = "regular"

   4.2. CREATE_CHECKOUT_SESSION:
        session = Stripe.checkout.sessions.create({
          mode: "payment",
          line_items: [{
            price_data: {
              currency: "usd",
              product_data: {
                name: cohortData.courseName,
                description: "2-Day AI Enablement Intensive",
                metadata: {
                  cohortId: selectedCohortId,
                  courseId: cohortData.courseId,
                  startDate: cohortData.startDate,
                  priceType: priceType
                }
              },
              unit_amount: finalPrice * 100 // Stripe uses cents
            },
            quantity: 1
          }],
          customer_email: userEmail, // Pre-fill if logged in
          metadata: {
            cohortId: selectedCohortId,
            courseId: cohortData.courseId,
            pendingEnrollmentId: pendingEnrollment.id,
            source: "b2c_purchase"
          },
          success_url: `${BASE_URL}/enrollment/success?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: `${BASE_URL}/courses/${courseId}?canceled=true`
        })

   4.3. REDIRECT to session.url

5. CHECKOUT_CANCELLATION_HANDLER
   - User returns to cancel_url

   5.1. RELEASE_HOLD:
        query = URLParams.get("canceled")
        IF query == "true":
          // Webhook will handle cleanup, but show message
          DISPLAY notification:
            "Your spot reservation has been released. The session is still available!"

          // Re-display cohort options
          GO TO cohort_selection

6. PAYMENT_SUCCESS_HANDLER (Webhook: checkout.session.completed)

   6.1. VALIDATE_WEBHOOK:
        signature = request.headers["stripe-signature"]
        event = Stripe.webhooks.constructEvent(
          request.body,
          signature,
          STRIPE_WEBHOOK_SECRET
        )

        IF event.type != "checkout.session.completed":
          RETURN 400

   6.2. EXTRACT_SESSION_DATA:
        session = event.data.object
        cohortId = session.metadata.cohortId
        pendingEnrollmentId = session.metadata.pendingEnrollmentId
        customerEmail = session.customer_details.email
        customerName = session.customer_details.name
        stripeCustomerId = session.customer
        paymentIntentId = session.payment_intent

   6.3. CONFIRM_ENROLLMENT:
        // Update pending enrollment to confirmed
        enrollment = NocoDB.updateRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: pendingEnrollmentId,
          fields: {
            status: "confirmed",
            learnerEmail: customerEmail,
            learnerName: customerName,
            stripeCustomerId: stripeCustomerId,
            paymentIntentId: paymentIntentId,
            paidAt: Date.now(),
            enrolledAt: Date.now(),
            source: "b2c_stripe"
          }
        })

   6.4. SET_ACCESS_WINDOWS:
        cohortData = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: cohortId,
          fields: ["startDate", "endDate"]
        })

        officeHoursEnd = cohortData.endDate + (90 * 24 * 60 * 60 * 1000) // +90 days
        chatbotAccessEnd = cohortData.endDate + (365 * 24 * 60 * 60 * 1000) // +1 year

        NocoDB.updateRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollment.id,
          fields: {
            officeHoursEligibleUntil: officeHoursEnd,
            chatbotAccessUntil: chatbotAccessEnd,
            materialsAccessUntil: chatbotAccessEnd
          }
        })

   6.5. CREATE_LEARNER_RECORD (if new):
        existingLearner = NocoDB.queryRecords({
          tableId: LEARNERS_TABLE,
          where: "(email,eq,{customerEmail})",
          fields: ["Id"]
        })

        IF existingLearner.length == 0:
          learner = NocoDB.createRecord({
            tableId: LEARNERS_TABLE,
            fields: {
              email: customerEmail,
              name: customerName,
              stripeCustomerId: stripeCustomerId,
              source: "b2c_purchase",
              firstEnrollmentDate: Date.now(),
              enrollmentCount: 1
            }
          })
        ELSE:
          // Increment enrollment count
          NocoDB.updateRecord({
            tableId: LEARNERS_TABLE,
            recordId: existingLearner[0].Id,
            fields: {
              enrollmentCount: existingLearner[0].enrollmentCount + 1
            }
          })

   6.6. SEND_CONFIRMATION_EMAIL:
        Brevo.sendTransactionalEmail({
          to: [{ email: customerEmail, name: customerName }],
          templateId: TEMPLATE_ENROLLMENT_CONFIRMATION,
          params: {
            learnerName: customerName,
            courseName: cohortData.courseName,
            cohortStartDate: formatDate(cohortData.startDate),
            cohortEndDate: formatDate(cohortData.endDate),
            receiptUrl: session.receipt_url,
            dashboardUrl: `${BASE_URL}/dashboard`
          },
          tags: ["enrollment", "confirmation", "b2c"]
        })

   6.7. TRACK_CONVERSION:
        PostHog.capture({
          distinctId: customerEmail,
          event: "enrollment_completed",
          properties: {
            cohortId: cohortId,
            courseId: session.metadata.courseId,
            priceType: session.metadata.priceType,
            revenue: session.amount_total / 100,
            source: "b2c_stripe"
          }
        })

   6.8. RETURN webhook_response(200, { received: true })

7. SUCCESS_PAGE_POLLING
   - User redirected to success_url after payment

   7.1. EXTRACT_SESSION_ID:
        sessionId = URLParams.get("session_id")

   7.2. POLL_FOR_ENROLLMENT (max 30 seconds):
        attempts = 0
        maxAttempts = 15 // 15 attempts * 2 seconds = 30 seconds

        WHILE attempts < maxAttempts:
          session = Stripe.checkout.sessions.retrieve(sessionId)

          IF session.payment_status == "paid":
            enrollment = NocoDB.queryRecords({
              tableId: ENROLLMENTS_TABLE,
              where: "(paymentIntentId,eq,{session.payment_intent})",
              fields: ["Id", "status", "cohortId", "learnerName"]
            })

            IF enrollment.length > 0 AND enrollment[0].status == "confirmed":
              // Success! Enrollment confirmed
              DISPLAY success_state:
                "✅ Welcome to the AI Enablement Academy, {enrollment[0].learnerName}!"
                "Your spot is confirmed for {cohortData.courseName}"
                "Check your email for next steps"

                SHOW dashboard_link:
                  "Go to Your Dashboard →"

              BREAK polling_loop

          WAIT 2 seconds
          attempts++

        IF attempts >= maxAttempts:
          // Webhook might be delayed
          DISPLAY pending_state:
            "⏳ Processing your enrollment..."
            "You'll receive a confirmation email shortly at {session.customer_details.email}"
            "If you don't receive it in 5 minutes, contact support@aienablement.academy"

8. CROSS_SELL_WHEN_FULL
   - Triggered when user tries to enroll in full cohort

   8.1. FETCH_ALTERNATIVE_COHORTS:
        sameCourse = NocoDB.queryRecords({
          tableId: COHORTS_TABLE,
          where: "(courseId,eq,{selectedCourseId})~and(status,eq,Open)~and(startDate,gt,{selectedCohortStartDate})",
          sort: "startDate",
          limit: 3,
          fields: ["Id", "startDate", "endDate", "capacity", "enrolled", "price"]
        })

   8.2. DISPLAY_OPTIONS:
        MODAL: "This Session is Full"

        SECTION: "📅 Upcoming Sessions"
        FOR EACH cohort IN sameCourse:
          spotsLeft = cohort.capacity - cohort.enrolled
          DISPLAY cohort_card:
            "{formatDate(cohort.startDate)} - {formatDate(cohort.endDate)}"
            "{spotsLeft} spots available"
            BUTTON: "Enroll in This Session" → GO TO capacity_check_and_reserve(cohort.Id)

        SECTION: "🔔 Or Get Notified"
        DISPLAY waitlist_form:
          INPUT: email (pre-filled if available)
          CHECKBOX: "Also notify me about new course launches"
          BUTTON: "Join Waitlist" → GO TO waitlist_flow

9. WAITLIST_FLOW

   9.1. CAPTURE_WAITLIST_INFO:
        FORM:
          email: required
          name: optional
          preferredStartDate: date_picker (optional)
          notifyNewCourses: checkbox (default: true)

   9.2. CREATE_WAITLIST_RECORD:
        waitlist = NocoDB.createRecord({
          tableId: WAITLIST_TABLE,
          fields: {
            cohortId: fullCohortId,
            courseId: courseId,
            email: form.email,
            name: form.name,
            preferredStartDate: form.preferredStartDate,
            notifyNewCourses: form.notifyNewCourses,
            addedAt: Date.now(),
            status: "active"
          }
        })

   9.3. ADD_TO_BREVO_LIST:
        Brevo.createContact({
          email: form.email,
          attributes: {
            FIRSTNAME: form.name,
            WAITLIST_COURSE: courseName,
            WAITLIST_DATE: form.preferredStartDate,
            NOTIFY_NEW_COURSES: form.notifyNewCourses
          },
          listIds: [BREVO_LIST_WAITLIST]
        })

   9.4. SEND_CONFIRMATION:
        Brevo.sendTransactionalEmail({
          to: [{ email: form.email, name: form.name }],
          templateId: TEMPLATE_WAITLIST_CONFIRMATION,
          params: {
            courseName: courseName,
            preferredDate: form.preferredStartDate || "the next available session"
          },
          tags: ["waitlist", "confirmation"]
        })

   9.5. TRACK_WAITLIST:
        PostHog.capture({
          distinctId: form.email,
          event: "waitlist_joined",
          properties: {
            cohortId: fullCohortId,
            courseId: courseId,
            preferredStartDate: form.preferredStartDate
          }
        })

   9.6. DISPLAY success_message:
        "✅ You're on the waitlist!"
        "We'll email you when spots open up or when the next session is announced."

        IF form.notifyNewCourses:
          "+ You'll also hear about new course launches"

END FLOW
```

---

## 2.1.2 Pre-Cohort Onboarding

```
FLOW: PRE_COHORT_ONBOARDING_SEQUENCE
TRIGGER: Scheduled job runs daily at 9:00 AM UTC

1. IDENTIFY_UPCOMING_COHORTS

   1.1. FETCH_COHORTS_STARTING_SOON:
        sevenDaysFromNow = Date.now() + (7 * 24 * 60 * 60 * 1000)
        oneDayFromNow = Date.now() + (1 * 24 * 60 * 60 * 1000)

        cohortsT7 = NocoDB.queryRecords({
          tableId: COHORTS_TABLE,
          where: "(startDate,eq,{formatDate(sevenDaysFromNow)})~and(status,eq,Open)",
          fields: ["Id", "courseName", "startDate", "endDate", "zoomLink"]
        })

        cohortsT1 = NocoDB.queryRecords({
          tableId: COHORTS_TABLE,
          where: "(startDate,eq,{formatDate(oneDayFromNow)})~and(status,eq,Open)",
          fields: ["Id", "courseName", "startDate", "endDate", "zoomLink"]
        })

2. T_MINUS_7_DAYS_SEQUENCE

   FOR EACH cohort IN cohortsT7:

     2.1. FETCH_ENROLLMENTS:
          enrollments = NocoDB.queryRecords({
            tableId: ENROLLMENTS_TABLE,
            where: "(cohortId,eq,{cohort.Id})~and(status,eq,confirmed)",
            fields: ["Id", "learnerEmail", "learnerName", "onboardingSurveyCompleted"]
          })

     2.2. FOR EACH enrollment IN enrollments:

          IF enrollment.onboardingSurveyCompleted == true:
            SKIP // Already completed survey

          2.2.1. GENERATE_SURVEY_LINK:
                 surveyUrl = Formbricks.createSurveyResponse({
                   surveyId: SURVEY_PRE_COHORT_INTAKE,
                   prefill: {
                     enrollmentId: enrollment.Id,
                     cohortId: cohort.Id,
                     learnerEmail: enrollment.learnerEmail,
                     learnerName: enrollment.learnerName
                   }
                 })

          2.2.2. SEND_T7_EMAIL:
                 Brevo.sendTransactionalEmail({
                   to: [{
                     email: enrollment.learnerEmail,
                     name: enrollment.learnerName
                   }],
                   templateId: TEMPLATE_T7_ONBOARDING,
                   params: {
                     learnerName: enrollment.learnerName,
                     courseName: cohort.courseName,
                     startDate: formatDate(cohort.startDate),
                     endDate: formatDate(cohort.endDate),
                     daysUntilStart: 7,
                     surveyUrl: surveyUrl,
                     dashboardUrl: `${BASE_URL}/dashboard`,
                     preparationGuideUrl: `${BASE_URL}/prepare/${cohort.Id}`
                   },
                   tags: ["onboarding", "t-7", "pre-cohort"]
                 })

          2.2.3. TRACK_EMAIL_SENT:
                 PostHog.capture({
                   distinctId: enrollment.learnerEmail,
                   event: "onboarding_email_sent",
                   properties: {
                     stage: "t-7",
                     cohortId: cohort.Id,
                     enrollmentId: enrollment.Id
                   }
                 })

          2.2.4. UPDATE_ONBOARDING_STATUS:
                 NocoDB.updateRecord({
                   tableId: ENROLLMENTS_TABLE,
                   recordId: enrollment.Id,
                   fields: {
                     t7EmailSentAt: Date.now(),
                     onboardingStage: "t-7_sent"
                   }
                 })

3. FORMBRICKS_INTAKE_SURVEY_PROCESSING
   TRIGGER: Webhook from Formbricks on survey completion

   3.1. VALIDATE_WEBHOOK:
        signature = request.headers["formbricks-signature"]
        event = Formbricks.validateWebhook(request.body, signature)

        IF event.surveyId != SURVEY_PRE_COHORT_INTAKE:
          RETURN 400

   3.2. EXTRACT_RESPONSES:
        enrollmentId = event.data.enrollmentId
        responses = event.data.responses

        // Example survey questions:
        // Q1: What's your current role?
        // Q2: What's your AI experience level? (None/Beginner/Intermediate/Advanced)
        // Q3: What are you hoping to achieve in this course?
        // Q4: Any specific challenges you're facing with AI adoption?
        // Q5: Dietary restrictions for catering? (if in-person)

        surveyData = {
          role: responses.find(q => q.id == "role")?.answer,
          aiExperience: responses.find(q => q.id == "ai_experience")?.answer,
          learningGoals: responses.find(q => q.id == "goals")?.answer,
          challenges: responses.find(q => q.id == "challenges")?.answer,
          dietaryRestrictions: responses.find(q => q.id == "dietary")?.answer
        }

   3.3. UPDATE_ENROLLMENT:
        NocoDB.updateRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: {
            onboardingSurveyCompleted: true,
            surveyCompletedAt: Date.now(),
            surveyResponses: JSON.stringify(surveyData),
            onboardingStage: "survey_completed"
          }
        })

   3.4. PERSONALIZE_EXPERIENCE:
        // Store responses for facilitator to review before cohort
        // Potentially adjust content delivery based on experience level

        IF surveyData.aiExperience == "None" OR surveyData.aiExperience == "Beginner":
          // Flag for facilitator to provide extra foundational support
          NocoDB.updateRecord({
            tableId: ENROLLMENTS_TABLE,
            recordId: enrollmentId,
            fields: {
              needsExtraSupport: true
            }
          })

   3.5. TRACK_COMPLETION:
        PostHog.capture({
          distinctId: event.data.learnerEmail,
          event: "onboarding_survey_completed",
          properties: {
            enrollmentId: enrollmentId,
            cohortId: event.data.cohortId,
            aiExperience: surveyData.aiExperience
          }
        })

   3.6. RETURN webhook_response(200, { received: true })

4. T_MINUS_1_DAY_REMINDER

   FOR EACH cohort IN cohortsT1:

     4.1. FETCH_ENROLLMENTS:
          enrollments = NocoDB.queryRecords({
            tableId: ENROLLMENTS_TABLE,
            where: "(cohortId,eq,{cohort.Id})~and(status,eq,confirmed)",
            fields: ["Id", "learnerEmail", "learnerName", "onboardingSurveyCompleted"]
          })

     4.2. FOR EACH enrollment IN enrollments:

          4.2.1. SEND_T1_REMINDER:
                 Brevo.sendTransactionalEmail({
                   to: [{
                     email: enrollment.learnerEmail,
                     name: enrollment.learnerName
                   }],
                   templateId: TEMPLATE_T1_REMINDER,
                   params: {
                     learnerName: enrollment.learnerName,
                     courseName: cohort.courseName,
                     startDate: formatDate(cohort.startDate),
                     startTime: formatTime(cohort.startDate),
                     zoomLink: cohort.zoomLink,
                     calendarIcsUrl: `${BASE_URL}/api/calendar/${enrollment.Id}.ics`,
                     techCheckUrl: `${BASE_URL}/tech-check`,
                     whatToBring: [
                       "Laptop with Chrome/Edge browser",
                       "Notebook for reflection exercises",
                       "Questions about AI in your work context"
                     ],
                     surveyCompleted: enrollment.onboardingSurveyCompleted
                   },
                   tags: ["onboarding", "t-1", "reminder"]
                 })

          4.2.2. IF NOT enrollment.onboardingSurveyCompleted:
                 // Send gentle nudge in separate email
                 surveyUrl = Formbricks.getSurveyUrl({
                   surveyId: SURVEY_PRE_COHORT_INTAKE,
                   enrollmentId: enrollment.Id
                 })

                 Brevo.sendTransactionalEmail({
                   to: [{
                     email: enrollment.learnerEmail,
                     name: enrollment.learnerName
                   }],
                   templateId: TEMPLATE_SURVEY_REMINDER,
                   params: {
                     learnerName: enrollment.learnerName,
                     surveyUrl: surveyUrl,
                     timeRemaining: "5 minutes"
                   },
                   tags: ["survey", "reminder"]
                 })

          4.2.3. TRACK_REMINDER_SENT:
                 PostHog.capture({
                   distinctId: enrollment.learnerEmail,
                   event: "onboarding_reminder_sent",
                   properties: {
                     stage: "t-1",
                     cohortId: cohort.Id,
                     enrollmentId: enrollment.Id,
                     surveyCompleted: enrollment.onboardingSurveyCompleted
                   }
                 })

          4.2.4. UPDATE_ONBOARDING_STATUS:
                 NocoDB.updateRecord({
                   tableId: ENROLLMENTS_TABLE,
                   recordId: enrollment.Id,
                   fields: {
                     t1EmailSentAt: Date.now(),
                     onboardingStage: "t-1_sent"
                   }
                 })

5. ZOOM_LINK_DELIVERY_VALIDATION

   5.1. VERIFY_ZOOM_LINK_EXISTS:
        FOR EACH cohort IN cohortsT1:
          IF NOT cohort.zoomLink OR cohort.zoomLink == "":
            // Alert admin that Zoom link is missing
            SEND_ALERT({
              to: "admin@aienablement.academy",
              subject: "URGENT: Missing Zoom link for cohort starting tomorrow",
              cohortId: cohort.Id,
              courseName: cohort.courseName,
              startDate: cohort.startDate
            })

            // Log error
            Logger.error("Missing Zoom link for cohort", {
              cohortId: cohort.Id,
              startDate: cohort.startDate
            })

6. CALENDAR_ICS_GENERATION
   ENDPOINT: /api/calendar/:enrollmentId.ics

   6.1. FETCH_ENROLLMENT_DATA:
        enrollment = NocoDB.getRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: ["cohortId", "learnerEmail", "learnerName"]
        })

        cohort = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: enrollment.cohortId,
          fields: ["courseName", "startDate", "endDate", "zoomLink", "timezone"]
        })

   6.2. GENERATE_ICS_FILE:
        icsContent = `
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//AI Enablement Academy//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:${cohort.courseName}
X-WR-TIMEZONE:${cohort.timezone}

BEGIN:VEVENT
UID:${enrollment.Id}@aienablement.academy
DTSTAMP:${formatICSDate(Date.now())}
DTSTART:${formatICSDate(cohort.startDate)}
DTEND:${formatICSDate(cohort.endDate)}
SUMMARY:${cohort.courseName} - Day 1
DESCRIPTION:AI Enablement Academy Intensive\\n\\nZoom Link: ${cohort.zoomLink}\\n\\nWhat to bring:\\n- Laptop with Chrome/Edge\\n- Notebook\\n- Questions about AI in your context
LOCATION:${cohort.zoomLink}
STATUS:CONFIRMED
SEQUENCE:0
END:VEVENT

BEGIN:VEVENT
UID:${enrollment.Id}-day2@aienablement.academy
DTSTAMP:${formatICSDate(Date.now())}
DTSTART:${formatICSDate(cohort.startDate + (1 * 24 * 60 * 60 * 1000))}
DTEND:${formatICSDate(cohort.endDate)}
SUMMARY:${cohort.courseName} - Day 2
DESCRIPTION:AI Enablement Academy Intensive - Day 2\\n\\nZoom Link: ${cohort.zoomLink}
LOCATION:${cohort.zoomLink}
STATUS:CONFIRMED
SEQUENCE:0
END:VEVENT

END:VCALENDAR
        `

   6.3. RETURN_ICS_FILE:
        response.setHeader("Content-Type", "text/calendar")
        response.setHeader("Content-Disposition", `attachment; filename="${cohort.courseName}.ics"`)
        response.send(icsContent)

7. TRACKING_ONBOARDING_FUNNEL

   7.1. DAILY_ONBOARDING_METRICS:
        // Track completion rates
        PostHog.capture({
          distinctId: "system",
          event: "onboarding_metrics_daily",
          properties: {
            t7_emails_sent: cohortsT7.reduce((sum, c) => sum + c.enrollments.length, 0),
            t1_emails_sent: cohortsT1.reduce((sum, c) => sum + c.enrollments.length, 0),
            surveys_completed_today: todaySurveyCount,
            surveys_pending: pendingSurveyCount
          }
        })

END FLOW
```

---

## 2.1.3 Post-Cohort Experience

```
FLOW: POST_COHORT_COMPLETION_SEQUENCE
TRIGGER: Manual trigger by facilitator OR scheduled job on cohort.endDate + 1 hour

1. IDENTIFY_COMPLETED_COHORT

   1.1. FETCH_RECENTLY_ENDED_COHORTS:
        yesterday = Date.now() - (24 * 60 * 60 * 1000)

        completedCohorts = NocoDB.queryRecords({
          tableId: COHORTS_TABLE,
          where: "(endDate,gte,{formatDate(yesterday)})~and(status,eq,Open)~and(certificatesIssued,eq,false)",
          fields: ["Id", "courseName", "courseId", "startDate", "endDate"]
        })

   1.2. FOR EACH cohort IN completedCohorts:
        EXECUTE post_cohort_processing(cohort)

2. POST_COHORT_PROCESSING (per cohort)

   2.1. FETCH_COMPLETED_ENROLLMENTS:
        enrollments = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(cohortId,eq,{cohort.Id})~and(status,eq,confirmed)~and(attendanceDay1,eq,true)~and(attendanceDay2,eq,true)",
          fields: ["Id", "learnerEmail", "learnerName", "certificateIssued", "badgeIssued"]
        })

        // Only learners who attended both days get certificates

   2.2. BATCH_CERTIFICATE_GENERATION:
        FOR EACH enrollment IN enrollments:

          IF enrollment.certificateIssued == true:
            SKIP // Already issued

          2.2.1. GENERATE_CERTIFICATE_PDF:
                 certificateData = {
                   learnerName: enrollment.learnerName,
                   courseName: cohort.courseName,
                   completionDate: cohort.endDate,
                   certificateId: generateUUID(),
                   issueDate: Date.now(),
                   credentialUrl: `${BASE_URL}/credentials/${certificateId}`
                 }

                 // Use PDF generation library (e.g., Puppeteer, PDFKit)
                 pdfBuffer = generateCertificatePDF(certificateData)

                 // Upload to cloud storage (e.g., Supabase Storage, AWS S3)
                 certificateUrl = Storage.upload({
                   bucket: "certificates",
                   path: `${cohort.Id}/${enrollment.Id}.pdf`,
                   file: pdfBuffer,
                   contentType: "application/pdf",
                   metadata: {
                     enrollmentId: enrollment.Id,
                     cohortId: cohort.Id,
                     learnerEmail: enrollment.learnerEmail
                   }
                 })

          2.2.2. GENERATE_OPEN_BADGE_JSON_LD:
                 badgeData = {
                   "@context": "https://w3id.org/openbadges/v2",
                   "type": "Assertion",
                   "id": `${BASE_URL}/badges/${certificateData.certificateId}`,
                   "badge": {
                     "type": "BadgeClass",
                     "id": `${BASE_URL}/badges/ai-enablement-intensive`,
                     "name": cohort.courseName,
                     "description": "Completed 2-day AI Enablement Academy intensive, demonstrating proficiency in AI fundamentals, prompt engineering, and real-world AI application.",
                     "image": `${BASE_URL}/badges/ai-enablement-intensive.png`,
                     "criteria": {
                       "narrative": "Attended both days of intensive training, completed hands-on exercises, and demonstrated understanding of AI enablement principles."
                     },
                     "issuer": {
                       "type": "Profile",
                       "id": `${BASE_URL}/issuer`,
                       "name": "AI Enablement Academy",
                       "url": "https://aienablement.academy",
                       "email": "credentials@aienablement.academy"
                     },
                     "tags": ["AI", "Enablement", "Professional Development", "Claude"]
                   },
                   "recipient": {
                     "type": "email",
                     "hashed": false,
                     "identity": enrollment.learnerEmail
                   },
                   "issuedOn": new Date(Date.now()).toISOString(),
                   "verification": {
                     "type": "hosted",
                     "verificationUrl": `${BASE_URL}/badges/${certificateData.certificateId}`
                   }
                 }

                 // Store badge JSON-LD
                 badgeUrl = Storage.upload({
                   bucket: "badges",
                   path: `${certificateData.certificateId}.json`,
                   file: JSON.stringify(badgeData),
                   contentType: "application/ld+json"
                 })

          2.2.3. UPDATE_ENROLLMENT_RECORD:
                 NocoDB.updateRecord({
                   tableId: ENROLLMENTS_TABLE,
                   recordId: enrollment.Id,
                   fields: {
                     certificateIssued: true,
                     certificateIssuedAt: Date.now(),
                     certificateUrl: certificateUrl,
                     certificateId: certificateData.certificateId,
                     badgeIssued: true,
                     badgeUrl: badgeUrl,
                     badgeJsonUrl: badgeUrl,
                     completionStage: "certificates_issued"
                   }
                 })

          2.2.4. SEND_CERTIFICATE_EMAIL:
                 Brevo.sendTransactionalEmail({
                   to: [{
                     email: enrollment.learnerEmail,
                     name: enrollment.learnerName
                   }],
                   templateId: TEMPLATE_CERTIFICATE_DELIVERY,
                   params: {
                     learnerName: enrollment.learnerName,
                     courseName: cohort.courseName,
                     certificateUrl: certificateUrl,
                     badgeUrl: `${BASE_URL}/credentials/${certificateData.certificateId}`,
                     linkedinShareUrl: generateLinkedInShareUrl(certificateData),
                     enablementKitUrl: `${BASE_URL}/enablement-kit/${enrollment.Id}`,
                     dashboardUrl: `${BASE_URL}/dashboard`,
                     officeHoursUrl: `${BASE_URL}/office-hours`,
                     chatbotUrl: `${BASE_URL}/chatbot`
                   },
                   attachments: [
                     {
                       name: `${cohort.courseName} Certificate.pdf`,
                       content: pdfBuffer.toString("base64")
                     }
                   ],
                   tags: ["post-cohort", "certificate", "completion"]
                 })

          2.2.5. TRACK_CERTIFICATE_ISSUED:
                 PostHog.capture({
                   distinctId: enrollment.learnerEmail,
                   event: "certificate_issued",
                   properties: {
                     enrollmentId: enrollment.Id,
                     cohortId: cohort.Id,
                     certificateId: certificateData.certificateId,
                     hasOpenBadge: true
                   }
                 })

   2.3. MARK_COHORT_CERTIFICATES_ISSUED:
        NocoDB.updateRecord({
          tableId: COHORTS_TABLE,
          recordId: cohort.Id,
          fields: {
            certificatesIssued: true,
            certificatesIssuedAt: Date.now(),
            certificateCount: enrollments.length
          }
        })

3. LINKEDIN_SHARE_FLOW
   ENDPOINT: /api/linkedin/share/:certificateId

   3.1. GENERATE_SHARE_URL:
        // LinkedIn share URL format
        shareUrl = `https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME&name=${encodeURIComponent(cohort.courseName)}&organizationId=AI%20Enablement%20Academy&issueYear=${new Date(cohort.endDate).getFullYear()}&issueMonth=${new Date(cohort.endDate).getMonth() + 1}&certUrl=${encodeURIComponent(`${BASE_URL}/credentials/${certificateId}`)}&certId=${certificateId}`

   3.2. TRACK_SHARE_INTENT:
        PostHog.capture({
          distinctId: enrollment.learnerEmail,
          event: "linkedin_share_clicked",
          properties: {
            certificateId: certificateId,
            cohortId: cohort.Id
          }
        })

   3.3. REDIRECT to shareUrl

4. ENABLEMENT_KIT_ACCESS
   ENDPOINT: /enablement-kit/:enrollmentId

   4.1. VERIFY_ENROLLMENT:
        enrollment = NocoDB.getRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: ["Id", "status", "certificateIssued", "materialsAccessUntil", "cohortId", "learnerName"]
        })

        IF enrollment.status != "confirmed":
          RETURN 403: "Enrollment not confirmed"

        IF Date.now() > enrollment.materialsAccessUntil:
          RETURN 403: "Materials access expired"

   4.2. FETCH_ENABLEMENT_KIT_CONTENTS:
        cohort = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: enrollment.cohortId,
          fields: ["courseId", "courseName"]
        })

        course = NocoDB.getRecord({
          tableId: COURSES_TABLE,
          recordId: cohort.courseId,
          fields: ["enablementKitUrl", "slidesUrl", "handbookUrl", "resourcesUrl"]
        })

   4.3. DISPLAY_ENABLEMENT_KIT_PAGE:
        RENDER page:
          HEADER: "Your AI Enablement Kit - {cohort.courseName}"
          SUBTITLE: "Access expires: {formatDate(enrollment.materialsAccessUntil)}"

          SECTION: "📚 Course Materials"
          - Download: "Complete Slide Deck (PDF)" → course.slidesUrl
          - Download: "AI Enablement Handbook (PDF)" → course.handbookUrl
          - Download: "Resource Library (ZIP)" → course.resourcesUrl

          SECTION: "🤖 Tools & Templates"
          - Claude.ai account setup guide
          - Prompt engineering cheat sheet
          - AI use case templates
          - ROI calculator spreadsheet

          SECTION: "📹 Session Recordings (if available)"
          - Day 1 Recording (MP4)
          - Day 2 Recording (MP4)

          SECTION: "🎓 Your Credentials"
          - Download Certificate (PDF)
          - View Open Badge (JSON-LD)
          - Share on LinkedIn

          SECTION: "💬 Ongoing Support"
          - Book Office Hours (next 90 days) → /office-hours
          - Ask the Knowledge Chatbot (next 12 months) → /chatbot

          SECTION: "🚀 Continue Learning"
          - View upcoming advanced courses
          - Join alumni community (Slack/Discord)
          - Subscribe to AI Enablement newsletter

   4.4. TRACK_KIT_ACCESS:
        PostHog.capture({
          distinctId: enrollment.learnerEmail,
          event: "enablement_kit_accessed",
          properties: {
            enrollmentId: enrollmentId,
            cohortId: cohort.Id
          }
        })

5. ACCESS_WINDOW_MANAGEMENT
   SCHEDULED_JOB: Daily at 2:00 AM UTC

   5.1. CHECK_EXPIRING_OFFICE_HOURS_ACCESS:
        threeDaysFromNow = Date.now() + (3 * 24 * 60 * 60 * 1000)

        expiringOfficeHours = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(officeHoursEligibleUntil,eq,{formatDate(threeDaysFromNow)})~and(status,eq,confirmed)",
          fields: ["Id", "learnerEmail", "learnerName", "cohortId"]
        })

        FOR EACH enrollment IN expiringOfficeHours:
          // Send reminder to book office hours before expiration
          Brevo.sendTransactionalEmail({
            to: [{
              email: enrollment.learnerEmail,
              name: enrollment.learnerName
            }],
            templateId: TEMPLATE_OFFICE_HOURS_EXPIRING,
            params: {
              learnerName: enrollment.learnerName,
              daysRemaining: 3,
              officeHoursUrl: `${BASE_URL}/office-hours`,
              expirationDate: formatDate(enrollment.officeHoursEligibleUntil)
            },
            tags: ["office-hours", "expiring", "reminder"]
          })

   5.2. CHECK_EXPIRED_MATERIAL_ACCESS:
        expiredAccess = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(materialsAccessUntil,lt,{formatDate(Date.now())})~and(status,eq,confirmed)~and(accessExpiredNotified,eq,false)",
          fields: ["Id", "learnerEmail", "learnerName", "cohortId"]
        })

        FOR EACH enrollment IN expiredAccess:
          // Notify of access expiration and offer renewal/upgrade
          Brevo.sendTransactionalEmail({
            to: [{
              email: enrollment.learnerEmail,
              name: enrollment.learnerName
            }],
            templateId: TEMPLATE_ACCESS_EXPIRED,
            params: {
              learnerName: enrollment.learnerName,
              renewalUrl: `${BASE_URL}/renew/${enrollment.Id}`,
              upgradeUrl: `${BASE_URL}/courses/advanced`
            },
            tags: ["access", "expired", "upsell"]
          })

          // Mark as notified
          NocoDB.updateRecord({
            tableId: ENROLLMENTS_TABLE,
            recordId: enrollment.Id,
            fields: {
              accessExpiredNotified: true,
              accessExpiredNotifiedAt: Date.now()
            }
          })

6. POST_COHORT_SURVEY (Optional Enhancement)
   TRIGGER: 7 days after cohort end

   6.1. SEND_FEEDBACK_SURVEY:
        Formbricks.createSurvey({
          surveyId: SURVEY_POST_COHORT_FEEDBACK,
          to: enrollment.learnerEmail,
          prefill: {
            enrollmentId: enrollment.Id,
            cohortId: cohort.Id
          },
          questions: [
            "How likely are you to recommend this course? (NPS 0-10)",
            "What was the most valuable part of the course?",
            "What could be improved?",
            "Have you applied any learnings at work yet? If yes, describe.",
            "Would you be interested in advanced courses?"
          ]
        })

END FLOW
```

---

## 2.1.4 Office Hours Booking

```
FLOW: OFFICE_HOURS_BOOKING
ENTRY: User navigates to /office-hours

1. AUTHENTICATION_CHECK

   1.1. VERIFY_USER_SESSION:
        IF NOT authenticated:
          REDIRECT to /login?redirect=/office-hours

   1.2. FETCH_USER_EMAIL:
        userEmail = session.user.email

2. ELIGIBILITY_VERIFICATION

   2.1. QUERY_ACTIVE_ENROLLMENTS:
        enrollments = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(learnerEmail,eq,{userEmail})~and(status,eq,confirmed)~and(officeHoursEligibleUntil,gte,{formatDate(Date.now())})",
          sort: "-officeHoursEligibleUntil",
          fields: ["Id", "cohortId", "courseName", "officeHoursEligibleUntil", "officeHoursBooked", "officeHoursCompleted"]
        })

   2.2. CHECK_ELIGIBILITY:
        IF enrollments.length == 0:
          DISPLAY ineligible_state:
            "❌ No Active Office Hours Access"

            "Office hours are available for 90 days after completing a course."

            OPTIONS:
              - "View Past Courses" → /dashboard
              - "Enroll in New Course" → /courses
              - "Contact Support" → mailto:support@aienablement.academy

          ABORT flow

   2.3. SELECT_ENROLLMENT (if multiple):
        IF enrollments.length > 1:
          DISPLAY enrollment_selector:
            "You have office hours access from multiple courses. Which would you like to use?"

            FOR EACH enrollment IN enrollments:
              RADIO_BUTTON:
                label: "{enrollment.courseName} (expires {formatDate(enrollment.officeHoursEligibleUntil)})"
                value: enrollment.Id

            BUTTON: "Continue" → selectedEnrollment = selected value
        ELSE:
          selectedEnrollment = enrollments[0]

3. DISPLAY_BOOKING_INTERFACE

   3.1. SHOW_ELIGIBILITY_INFO:
        DISPLAY info_banner:
          "✅ Office Hours Access Active"
          "Valid until: {formatDate(selectedEnrollment.officeHoursEligibleUntil)}"
          "Sessions booked: {selectedEnrollment.officeHoursBooked || 0}"
          "Sessions completed: {selectedEnrollment.officeHoursCompleted || 0}"

   3.2. EMBED_CAL_COM_WIDGET:
        // Cal.com embed script
        calComConfig = {
          calLink: "aienablement/office-hours-30min",
          embedType: "inline",
          theme: "light",
          prefill: {
            name: selectedEnrollment.learnerName,
            email: userEmail,
            customAnswers: {
              enrollmentId: selectedEnrollment.Id,
              cohortId: selectedEnrollment.cohortId,
              courseName: selectedEnrollment.courseName
            }
          },
          metadata: {
            enrollmentId: selectedEnrollment.Id,
            source: "office_hours_portal"
          }
        }

        RENDER cal_embed:
          <div id="cal-booking-widget"></div>
          <script>
            Cal("init", calComConfig);
            Cal("inline", {
              elementOrSelector: "#cal-booking-widget",
              calLink: calComConfig.calLink
            });
          </script>

   3.3. DISPLAY_GUIDELINES:
        SECTION: "📋 Office Hours Guidelines"
        - Duration: 30 minutes per session
        - Topics: AI implementation questions, strategy guidance, technical troubleshooting
        - Preparation: Come with specific questions or challenges
        - Cancellation: Please cancel at least 24 hours in advance
        - Rescheduling: You can reschedule up to 2 hours before the session

4. CAL_COM_BOOKING_WEBHOOK
   TRIGGER: Webhook from Cal.com on booking.created
   ENDPOINT: /api/webhooks/cal-com/booking

   4.1. VALIDATE_WEBHOOK:
        signature = request.headers["x-cal-signature"]
        event = CalCom.validateWebhook(request.body, signature)

        IF NOT valid:
          RETURN 401: "Invalid signature"

   4.2. EXTRACT_BOOKING_DATA:
        booking = event.data
        enrollmentId = booking.responses.enrollmentId
        cohortId = booking.responses.cohortId
        attendeeEmail = booking.attendees[0].email
        attendeeName = booking.attendees[0].name
        bookingId = booking.id
        bookingUid = booking.uid
        scheduledTime = booking.startTime
        endTime = booking.endTime
        meetingUrl = booking.metadata.videoCallUrl

   4.3. VERIFY_ELIGIBILITY_AGAIN:
        // Double-check eligibility at booking time
        enrollment = NocoDB.getRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: ["officeHoursEligibleUntil", "status"]
        })

        IF enrollment.status != "confirmed":
          RETURN 403: "Enrollment not confirmed"

        IF Date.now() > enrollment.officeHoursEligibleUntil:
          // Cancel the booking
          CalCom.cancelBooking({ bookingId: bookingId })
          RETURN 403: "Office hours access expired"

   4.4. CREATE_BOOKING_RECORD:
        bookingRecord = NocoDB.createRecord({
          tableId: OFFICE_HOURS_TABLE,
          fields: {
            enrollmentId: enrollmentId,
            cohortId: cohortId,
            learnerEmail: attendeeEmail,
            learnerName: attendeeName,
            calComBookingId: bookingId,
            calComUid: bookingUid,
            scheduledAt: scheduledTime,
            duration: 30,
            meetingUrl: meetingUrl,
            status: "scheduled",
            bookedAt: Date.now()
          }
        })

   4.5. INCREMENT_BOOKING_COUNT:
        currentCount = enrollment.officeHoursBooked || 0
        NocoDB.updateRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: {
            officeHoursBooked: currentCount + 1,
            lastOfficeHoursBookedAt: Date.now()
          }
        })

   4.6. SEND_CONFIRMATION_EMAIL:
        Brevo.sendTransactionalEmail({
          to: [{ email: attendeeEmail, name: attendeeName }],
          templateId: TEMPLATE_OFFICE_HOURS_CONFIRMATION,
          params: {
            learnerName: attendeeName,
            scheduledDate: formatDate(scheduledTime),
            scheduledTime: formatTime(scheduledTime),
            duration: "30 minutes",
            meetingUrl: meetingUrl,
            calendarIcsUrl: `${BASE_URL}/api/calendar/office-hours/${bookingRecord.Id}.ics`,
            preparationTips: [
              "Review any questions or challenges you want to discuss",
              "Have relevant project context or examples ready",
              "Test your video/audio 5 minutes before the call"
            ],
            rescheduleUrl: `https://cal.com/reschedule/${bookingUid}`,
            cancelUrl: `https://cal.com/cancel/${bookingUid}`
          },
          tags: ["office-hours", "confirmation", "booking"]
        })

   4.7. TRACK_BOOKING:
        PostHog.capture({
          distinctId: attendeeEmail,
          event: "office_hours_booked",
          properties: {
            enrollmentId: enrollmentId,
            cohortId: cohortId,
            scheduledAt: scheduledTime,
            bookingId: bookingId
          }
        })

   4.8. RETURN webhook_response(200, { received: true })

5. BOOKING_CANCELLATION_WEBHOOK
   TRIGGER: Webhook from Cal.com on booking.cancelled

   5.1. EXTRACT_CANCELLATION_DATA:
        booking = event.data
        bookingUid = booking.uid

   5.2. UPDATE_BOOKING_RECORD:
        bookingRecord = NocoDB.queryRecords({
          tableId: OFFICE_HOURS_TABLE,
          where: "(calComUid,eq,{bookingUid})",
          fields: ["Id", "enrollmentId", "learnerEmail"]
        })

        IF bookingRecord.length > 0:
          NocoDB.updateRecord({
            tableId: OFFICE_HOURS_TABLE,
            recordId: bookingRecord[0].Id,
            fields: {
              status: "cancelled",
              cancelledAt: Date.now()
            }
          })

          // Decrement booking count
          enrollment = NocoDB.getRecord({
            tableId: ENROLLMENTS_TABLE,
            recordId: bookingRecord[0].enrollmentId,
            fields: ["officeHoursBooked"]
          })

          NocoDB.updateRecord({
            tableId: ENROLLMENTS_TABLE,
            recordId: bookingRecord[0].enrollmentId,
            fields: {
              officeHoursBooked: Math.max(0, enrollment.officeHoursBooked - 1)
            }
          })

          // Track cancellation
          PostHog.capture({
            distinctId: bookingRecord[0].learnerEmail,
            event: "office_hours_cancelled",
            properties: {
              bookingId: bookingRecord[0].Id,
              enrollmentId: bookingRecord[0].enrollmentId
            }
          })

6. POST_SESSION_COMPLETION
   TRIGGER: Manual trigger by facilitator OR automated 1 hour after session end

   6.1. MARK_SESSION_COMPLETE:
        NocoDB.updateRecord({
          tableId: OFFICE_HOURS_TABLE,
          recordId: bookingId,
          fields: {
            status: "completed",
            completedAt: Date.now()
          }
        })

   6.2. INCREMENT_COMPLETED_COUNT:
        enrollment = NocoDB.getRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: ["officeHoursCompleted"]
        })

        NocoDB.updateRecord({
          tableId: ENROLLMENTS_TABLE,
          recordId: enrollmentId,
          fields: {
            officeHoursCompleted: (enrollment.officeHoursCompleted || 0) + 1
          }
        })

   6.3. SEND_FOLLOW_UP_EMAIL (optional):
        Brevo.sendTransactionalEmail({
          to: [{ email: learnerEmail, name: learnerName }],
          templateId: TEMPLATE_OFFICE_HOURS_FOLLOWUP,
          params: {
            learnerName: learnerName,
            sessionDate: formatDate(sessionTime),
            feedbackUrl: `${BASE_URL}/feedback/office-hours/${bookingId}`,
            bookAgainUrl: `${BASE_URL}/office-hours`
          },
          tags: ["office-hours", "follow-up"]
        })

END FLOW
```

---

## 2.1.5 Knowledge Chatbot Interaction

```
FLOW: KNOWLEDGE_CHATBOT_INTERACTION
ENTRY: User navigates to /chatbot

1. AUTHENTICATION_CHECK

   1.1. VERIFY_USER_SESSION:
        IF NOT authenticated:
          REDIRECT to /login?redirect=/chatbot

   1.2. FETCH_USER_EMAIL:
        userEmail = session.user.email

2. ACCESS_VALIDATION

   2.1. QUERY_CHATBOT_ACCESS:
        enrollments = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(learnerEmail,eq,{userEmail})~and(status,eq,confirmed)~and(chatbotAccessUntil,gte,{formatDate(Date.now())})",
          sort: "-chatbotAccessUntil",
          fields: ["Id", "cohortId", "courseName", "chatbotAccessUntil", "courseId"]
        })

   2.2. CHECK_ACCESS:
        IF enrollments.length == 0:
          DISPLAY no_access_state:
            "❌ No Active Chatbot Access"

            "The AI knowledge chatbot is available for 12 months after completing a course."

            INFO:
              "This chatbot has access to all course materials, recordings, and AI enablement best practices."

            OPTIONS:
              - "View Past Courses" → /dashboard
              - "Enroll in New Course" → /courses
              - "Contact Support" → mailto:support@aienablement.academy

          ABORT flow

   2.3. SELECT_COURSE_CONTEXT (if multiple):
        IF enrollments.length > 1:
          DISPLAY context_selector:
            "Which course context would you like to chat about?"

            FOR EACH enrollment IN enrollments:
              CARD:
                title: enrollment.courseName
                subtitle: "Access until {formatDate(enrollment.chatbotAccessUntil)}"
                BUTTON: "Chat about this course" → selectedEnrollment = enrollment
        ELSE:
          selectedEnrollment = enrollments[0]

3. INITIALIZE_CHATBOT_INTERFACE

   3.1. DISPLAY_CHATBOT_UI:
        RENDER chat_interface:
          HEADER:
            title: "AI Knowledge Assistant - {selectedEnrollment.courseName}"
            subtitle: "Ask anything about the course materials, AI concepts, or implementation guidance"
            access_badge: "Active until {formatDate(selectedEnrollment.chatbotAccessUntil)}"

          CHAT_CONTAINER:
            id: "chat-messages"
            initialMessages: []

          INPUT_AREA:
            textarea: id="user-input" placeholder="Ask a question about AI enablement..."
            BUTTON: "Send" onclick="sendMessage()"

          SUGGESTED_PROMPTS:
            - "What were the key takeaways about prompt engineering?"
            - "How do I calculate ROI for AI implementation?"
            - "What are the best practices for AI governance?"
            - "Can you summarize the session on change management?"

   3.2. LOAD_CONVERSATION_HISTORY (if exists):
        history = NocoDB.queryRecords({
          tableId: CHATBOT_CONVERSATIONS_TABLE,
          where: "(enrollmentId,eq,{selectedEnrollment.Id})",
          sort: "-createdAt",
          limit: 1,
          fields: ["Id", "messages"]
        })

        IF history.length > 0:
          conversationId = history[0].Id
          messages = JSON.parse(history[0].messages)

          RENDER previous_messages:
            FOR EACH message IN messages:
              DISPLAY message_bubble(message.role, message.content)
        ELSE:
          conversationId = null
          messages = []

4. CONTEXT_LOADING

   4.1. FETCH_COURSE_MATERIALS:
        course = NocoDB.getRecord({
          tableId: COURSES_TABLE,
          recordId: selectedEnrollment.courseId,
          fields: ["courseName", "description", "learningOutcomes", "syllabus", "handbookUrl", "slidesUrl"]
        })

        cohort = NocoDB.getRecord({
          tableId: COHORTS_TABLE,
          recordId: selectedEnrollment.cohortId,
          fields: ["sessionNotesUrl", "transcriptDay1Url", "transcriptDay2Url"]
        })

   4.2. BUILD_CONTEXT_DOCUMENTS:
        contextDocs = []

        // Course metadata
        contextDocs.push({
          type: "course_overview",
          content: `
Course: ${course.courseName}
Description: ${course.description}
Learning Outcomes: ${course.learningOutcomes}
Syllabus: ${course.syllabus}
          `
        })

        // Fetch handbook content (if PDF, extract text)
        IF course.handbookUrl:
          handbookText = extractTextFromPDF(course.handbookUrl)
          contextDocs.push({
            type: "handbook",
            content: handbookText
          })

        // Fetch session transcripts (if available)
        IF cohort.transcriptDay1Url:
          transcript1 = fetchText(cohort.transcriptDay1Url)
          contextDocs.push({
            type: "transcript_day1",
            content: transcript1
          })

        IF cohort.transcriptDay2Url:
          transcript2 = fetchText(cohort.transcriptDay2Url)
          contextDocs.push({
            type: "transcript_day2",
            content: transcript2
          })

   4.3. STORE_CONTEXT_IN_MEMORY:
        // Keep context in server memory for session duration
        session.chatbotContext = {
          enrollmentId: selectedEnrollment.Id,
          courseName: course.courseName,
          documents: contextDocs
        }

5. MESSAGE_PROCESSING
   TRIGGER: User clicks "Send" button

   5.1. CAPTURE_USER_MESSAGE:
        userMessage = document.getElementById("user-input").value

        IF userMessage.trim() == "":
          RETURN // Do nothing

        // Append to UI immediately
        APPEND_TO_CHAT:
          role: "user"
          content: userMessage
          timestamp: Date.now()

        // Clear input
        document.getElementById("user-input").value = ""

   5.2. UPDATE_CONVERSATION_HISTORY:
        messages.push({
          role: "user",
          content: userMessage,
          timestamp: Date.now()
        })

   5.3. BUILD_CONTEXT_PROMPT:
        systemPrompt = `
You are an AI assistant specializing in AI enablement education. You have access to the following course materials for "${course.courseName}":

${contextDocs.map(doc => `--- ${doc.type.toUpperCase()} ---\n${doc.content}`).join('\n\n')}

Your role:
- Answer questions about the course content, AI concepts, and implementation guidance
- Reference specific sections from the handbook or transcripts when relevant
- Provide actionable advice for applying AI in the learner's work context
- If a question is outside the course scope, politely redirect to the course materials or suggest booking office hours

Learner context:
- Completed: ${course.courseName}
- Enrollment: ${selectedEnrollment.Id}

Be helpful, accurate, and cite sources from the course materials when possible.
        `

   5.4. CALL_OPENROUTER_API:
        DISPLAY typing_indicator: "AI is thinking..."

        TRY:
          response = OpenRouter.chat.completions.create({
            model: "anthropic/claude-3.5-sonnet", // Or configurable model
            messages: [
              { role: "system", content: systemPrompt },
              ...messages.slice(-10) // Last 10 messages for context window management
            ],
            stream: true, // Enable streaming for real-time response
            max_tokens: 2000,
            temperature: 0.7
          })

        CATCH error:
          GO TO error_handling(error)

   5.5. STREAM_RESPONSE:
        assistantMessage = ""

        FOR EACH chunk IN response:
          delta = chunk.choices[0].delta.content

          IF delta:
            assistantMessage += delta

            // Update UI in real-time
            UPDATE_CHAT_BUBBLE:
              role: "assistant"
              content: assistantMessage
              isStreaming: true

        // Finalize message
        UPDATE_CHAT_BUBBLE:
          isStreaming: false

   5.6. UPDATE_CONVERSATION_HISTORY:
        messages.push({
          role: "assistant",
          content: assistantMessage,
          timestamp: Date.now()
        })

6. CONVERSATION_PERSISTENCE

   6.1. SAVE_OR_UPDATE_CONVERSATION:
        IF conversationId:
          // Update existing conversation
          NocoDB.updateRecord({
            tableId: CHATBOT_CONVERSATIONS_TABLE,
            recordId: conversationId,
            fields: {
              messages: JSON.stringify(messages),
              messageCount: messages.length,
              lastMessageAt: Date.now()
            }
          })
        ELSE:
          // Create new conversation
          conversation = NocoDB.createRecord({
            tableId: CHATBOT_CONVERSATIONS_TABLE,
            fields: {
              enrollmentId: selectedEnrollment.Id,
              cohortId: selectedEnrollment.cohortId,
              learnerEmail: userEmail,
              messages: JSON.stringify(messages),
              messageCount: messages.length,
              startedAt: Date.now(),
              lastMessageAt: Date.now()
            }
          })
          conversationId = conversation.Id

   6.2. TRACK_INTERACTION:
        PostHog.capture({
          distinctId: userEmail,
          event: "chatbot_message_sent",
          properties: {
            enrollmentId: selectedEnrollment.Id,
            conversationId: conversationId,
            messageLength: userMessage.length,
            responseLength: assistantMessage.length
          }
        })

7. ERROR_HANDLING

   7.1. OPENROUTER_API_FAILURE:
        IF error.status == 429: // Rate limit
          DISPLAY error_message:
            "⏳ The AI assistant is currently at capacity. Please try again in a few moments."

          ENABLE retry_button:
            onclick: "Retry" → GO TO message_processing

        ELSE IF error.status == 500: // Server error
          DISPLAY error_message:
            "❌ The AI assistant encountered an error. Please try again or contact support if the issue persists."

          ENABLE retry_button

        ELSE: // Other errors
          DISPLAY error_message:
            "⚠️ Something went wrong. Your message wasn't sent. Please try again."

          ENABLE retry_button

   7.2. GRACEFUL_DEGRADATION:
        // If OpenRouter is down, offer alternatives
        DISPLAY fallback_options:
          "While the AI assistant is unavailable, you can:"
          - "Download course materials" → /enablement-kit/{enrollmentId}
          - "Book office hours for personalized help" → /office-hours
          - "Search our knowledge base" → /resources

   7.3. LOG_ERROR:
        Logger.error("Chatbot API failure", {
          enrollmentId: selectedEnrollment.Id,
          error: error.message,
          status: error.status
        })

8. CONVERSATION_MANAGEMENT

   8.1. NEW_CONVERSATION_BUTTON:
        BUTTON: "Start New Conversation"
        onclick:
          CONFIRM: "This will clear the current chat. Continue?"
          IF confirmed:
            messages = []
            conversationId = null
            CLEAR_CHAT_UI()
            DISPLAY welcome_message:
              "👋 Hi! I'm your AI knowledge assistant. Ask me anything about {course.courseName}!"

   8.2. EXPORT_CONVERSATION:
        BUTTON: "Export Chat"
        onclick:
          conversationText = messages.map(m => `${m.role.toUpperCase()}: ${m.content}`).join('\n\n')

          DOWNLOAD_FILE:
            filename: `ai-chat-${Date.now()}.txt`
            content: conversationText

9. USAGE_LIMITS (Optional Enhancement)

   9.1. TRACK_DAILY_USAGE:
        today = formatDate(Date.now())

        usage = NocoDB.queryRecords({
          tableId: CHATBOT_USAGE_TABLE,
          where: "(enrollmentId,eq,{selectedEnrollment.Id})~and(date,eq,{today})",
          fields: ["messageCount"]
        })

        IF usage.length > 0 AND usage[0].messageCount >= DAILY_LIMIT:
          DISPLAY limit_reached:
            "⚠️ You've reached your daily message limit ({DAILY_LIMIT} messages)."
            "Limits reset daily at midnight UTC."

            "Need more help? Book office hours for unlimited 1:1 support."

          DISABLE input_area
          ABORT flow

END FLOW
```

---

## 2.1.6 Certificate & Badge Claiming

```
FLOW: CERTIFICATE_AND_BADGE_CLAIMING
ENTRY: User navigates to /credentials/:certificateId

1. VERIFY_CERTIFICATE_EXISTS

   1.1. FETCH_CERTIFICATE_DATA:
        enrollment = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(certificateId,eq,{certificateId})",
          fields: ["Id", "learnerEmail", "learnerName", "cohortId", "certificateUrl", "badgeJsonUrl", "certificateIssued", "courseName"]
        })

        IF enrollment.length == 0:
          DISPLAY error_page:
            "❌ Certificate Not Found"
            "The certificate ID you're looking for doesn't exist."

            LINK: "View Your Dashboard" → /dashboard

          ABORT flow

        certificateData = enrollment[0]

2. DISPLAY_CERTIFICATE_PAGE

   2.1. RENDER_CERTIFICATE_VIEW:
        HEADER:
          title: "Digital Certificate of Completion"
          subtitle: certificateData.courseName

        CERTIFICATE_PREVIEW:
          // Embed PDF preview or custom HTML certificate
          IF certificateData.certificateUrl:
            EMBED_PDF:
              src: certificateData.certificateUrl
              width: "100%"
              height: "800px"

          // Certificate details
          DETAILS:
            "Awarded to: {certificateData.learnerName}"
            "Course: {certificateData.courseName}"
            "Completion Date: {formatDate(certificateData.completionDate)}"
            "Certificate ID: {certificateId}"

        ACTIONS_SECTION:
          BUTTON: "Download Certificate (PDF)" → GO TO download_certificate
          BUTTON: "Download Badge (JSON-LD)" → GO TO download_badge
          BUTTON: "Share on LinkedIn" → GO TO linkedin_share
          BUTTON: "Verify Certificate" → GO TO verification_page

3. DOWNLOAD_CERTIFICATE
   TRIGGER: User clicks "Download Certificate"

   3.1. TRACK_DOWNLOAD:
        PostHog.capture({
          distinctId: certificateData.learnerEmail,
          event: "certificate_downloaded",
          properties: {
            certificateId: certificateId,
            enrollmentId: certificateData.Id
          }
        })

   3.2. SERVE_PDF_DOWNLOAD:
        response.setHeader("Content-Type", "application/pdf")
        response.setHeader("Content-Disposition", `attachment; filename="${certificateData.courseName} - Certificate.pdf"`)

        // Redirect to certificate URL (cloud storage)
        REDIRECT to certificateData.certificateUrl

4. DOWNLOAD_BADGE_JSON_LD
   TRIGGER: User clicks "Download Badge"

   4.1. FETCH_BADGE_DATA:
        badgeJson = fetch(certificateData.badgeJsonUrl)

   4.2. TRACK_BADGE_DOWNLOAD:
        PostHog.capture({
          distinctId: certificateData.learnerEmail,
          event: "badge_downloaded",
          properties: {
            certificateId: certificateId,
            enrollmentId: certificateData.Id,
            format: "json-ld"
          }
        })

   4.3. SERVE_JSON_DOWNLOAD:
        response.setHeader("Content-Type", "application/ld+json")
        response.setHeader("Content-Disposition", `attachment; filename="${certificateId}-badge.json"`)
        response.send(badgeJson)

5. LINKEDIN_SHARE_INTEGRATION
   TRIGGER: User clicks "Share on LinkedIn"

   5.1. GENERATE_LINKEDIN_SHARE_URL:
        // LinkedIn certification share URL
        linkedinUrl = `https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME&name=${encodeURIComponent(certificateData.courseName)}&organizationId=${encodeURIComponent("AI Enablement Academy")}&issueYear=${new Date(certificateData.completionDate).getFullYear()}&issueMonth=${new Date(certificateData.completionDate).getMonth() + 1}&certUrl=${encodeURIComponent(`${BASE_URL}/credentials/${certificateId}`)}&certId=${certificateId}`

   5.2. TRACK_SHARE_INTENT:
        PostHog.capture({
          distinctId: certificateData.learnerEmail,
          event: "linkedin_share_clicked",
          properties: {
            certificateId: certificateId,
            enrollmentId: certificateData.Id,
            platform: "linkedin"
          }
        })

   5.3. OPEN_LINKEDIN_SHARE:
        // Open LinkedIn in new window
        window.open(linkedinUrl, "_blank", "width=600,height=800")

        // Show confirmation modal
        DISPLAY modal:
          "✅ LinkedIn Share Opened"

          "Follow the prompts in the LinkedIn window to add this certification to your profile."

          INSTRUCTIONS:
            1. "Confirm the certification details"
            2. "LinkedIn will add it to your 'Licenses & Certifications' section"
            3. "Your network will be notified of your achievement!"

          BUTTON: "Close"

6. VERIFICATION_PAGE
   TRIGGER: User clicks "Verify Certificate"
   ENDPOINT: /credentials/verify/:certificateId

   6.1. DISPLAY_VERIFICATION_INTERFACE:
        HEADER: "Certificate Verification"

        VERIFIED_BADGE:
          "✅ Verified Certificate"

        DETAILS:
          "This certificate was issued by AI Enablement Academy and is authentic."

          TABLE:
            | Field | Value |
            |-------|-------|
            | Recipient | {certificateData.learnerName} |
            | Course | {certificateData.courseName} |
            | Issued On | {formatDate(certificateData.completionDate)} |
            | Certificate ID | {certificateId} |
            | Verification URL | {BASE_URL}/credentials/{certificateId} |
            | Badge URL | {certificateData.badgeJsonUrl} |

        SECTION: "Verification Methods"
        TABS:
          TAB: "Online Verification"
            "This page serves as official verification. Share this URL with employers or institutions."

          TAB: "Open Badges"
            "Download the JSON-LD badge file and upload to platforms like Badgr, Credly, or LinkedIn."
            BUTTON: "Download Badge" → GO TO download_badge

          TAB: "QR Code"
            DISPLAY qr_code:
              data: `${BASE_URL}/credentials/${certificateId}`
              size: 256
            "Scan this QR code to verify the certificate instantly."

7. OPEN_BADGES_METADATA_ENDPOINT
   ENDPOINT: /badges/:certificateId

   7.1. SERVE_BADGE_JSON_LD:
        badgeData = {
          "@context": "https://w3id.org/openbadges/v2",
          "type": "Assertion",
          "id": `${BASE_URL}/badges/${certificateId}`,
          "badge": {
            "type": "BadgeClass",
            "id": `${BASE_URL}/badges/ai-enablement-intensive`,
            "name": certificateData.courseName,
            "description": "Completed 2-day AI Enablement Academy intensive, demonstrating proficiency in AI fundamentals, prompt engineering, and real-world AI application.",
            "image": `${BASE_URL}/badges/ai-enablement-intensive.png`,
            "criteria": {
              "narrative": "Attended both days of intensive training, completed hands-on exercises, and demonstrated understanding of AI enablement principles."
            },
            "issuer": {
              "type": "Profile",
              "id": `${BASE_URL}/issuer`,
              "name": "AI Enablement Academy",
              "url": "https://aienablement.academy",
              "email": "credentials@aienablement.academy",
              "image": `${BASE_URL}/issuer-logo.png`
            },
            "tags": ["AI", "Enablement", "Professional Development", "Claude", "Anthropic"]
          },
          "recipient": {
            "type": "email",
            "hashed": false,
            "identity": certificateData.learnerEmail
          },
          "issuedOn": new Date(certificateData.completionDate).toISOString(),
          "verification": {
            "type": "hosted",
            "verificationUrl": `${BASE_URL}/badges/${certificateId}`
          },
          "evidence": [
            {
              "id": `${BASE_URL}/credentials/${certificateId}`,
              "name": "Certificate of Completion",
              "description": "Official certificate PDF",
              "genre": "Certificate"
            }
          ]
        }

        response.setHeader("Content-Type", "application/ld+json")
        response.send(badgeData)

8. PUBLIC_VERIFICATION_API
   ENDPOINT: /api/verify/:certificateId

   8.1. QUERY_CERTIFICATE:
        enrollment = NocoDB.queryRecords({
          tableId: ENROLLMENTS_TABLE,
          where: "(certificateId,eq,{certificateId})",
          fields: ["learnerName", "courseName", "certificateIssued", "completionDate"]
        })

        IF enrollment.length == 0:
          RETURN JSON:
            {
              "valid": false,
              "message": "Certificate not found"
            }

        ELSE:
          RETURN JSON:
            {
              "valid": true,
              "recipient": enrollment[0].learnerName,
              "course": enrollment[0].courseName,
              "issuedOn": enrollment[0].completionDate,
              "certificateId": certificateId,
              "verificationUrl": `${BASE_URL}/credentials/${certificateId}`
            }

9. SOCIAL_SHARING_ENHANCEMENTS

   9.1. OPEN_GRAPH_META_TAGS:
        // Add to <head> of /credentials/:certificateId page
        <meta property="og:title" content="${certificateData.learnerName} - ${certificateData.courseName}" />
        <meta property="og:description" content="Earned a certificate from AI Enablement Academy for completing ${certificateData.courseName}" />
        <meta property="og:image" content="${BASE_URL}/og-images/${certificateId}.png" />
        <meta property="og:url" content="${BASE_URL}/credentials/${certificateId}" />
        <meta property="og:type" content="article" />

        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="${certificateData.learnerName} - ${certificateData.courseName}" />
        <meta name="twitter:description" content="Earned a certificate from AI Enablement Academy" />
        <meta name="twitter:image" content="${BASE_URL}/og-images/${certificateId}.png" />

   9.2. GENERATE_SOCIAL_SHARE_IMAGE:
        // Dynamic OG image generation (using Puppeteer, Canvas, or image generation API)
        socialImage = generateCertificateSocialImage({
          learnerName: certificateData.learnerName,
          courseName: certificateData.courseName,
          completionDate: certificateData.completionDate,
          certificateId: certificateId
        })

        Storage.upload({
          bucket: "og-images",
          path: `${certificateId}.png`,
          file: socialImage,
          contentType: "image/png"
        })

END FLOW
```

---

**END OF SECTION 2.1: LEARNER PSEUDOCODE FLOWS**
