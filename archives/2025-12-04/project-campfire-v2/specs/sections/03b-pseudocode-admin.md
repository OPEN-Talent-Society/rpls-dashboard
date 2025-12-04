# 2.2 Admin Flows

## 2.2.1 Cohort Management Flow (Multi-Session Types)

```
FLOW: COHORT_MANAGEMENT

CONSTANTS:
  SESSION_TYPES = ["cohort", "webinar", "hackathon"]
  STATUS_OPTIONS = ["scheduled", "open", "in_progress", "completed", "cancelled"]
  DEFAULT_CAPACITY = {
    "cohort": 20,
    "webinar": 100,
    "hackathon": 30
  }

1. ADMIN navigates to /admin/cohorts
   ├─ LOAD all cohorts with filters
   │  ├─ WHERE status IN (selected_statuses OR all)
   │  ├─ AND courseId IN (selected_courses OR all)
   │  ├─ AND sessionType IN (selected_types OR all)
   │  ├─ AND startDate BETWEEN (date_range OR all)
   │  └─ ORDER BY startDate DESC
   │
   ├─ DISPLAY data grid:
   │  ├─ Columns: course name, session type, dates, enrollment/capacity, status, actions
   │  ├─ Enrollment display:
   │  │  ├─ IF sessionType = "cohort": "12/20"
   │  │  ├─ IF sessionType = "webinar": "87/100"
   │  │  └─ IF sessionType = "hackathon": "25/30"
   │  ├─ Status badges:
   │  │  ├─ "scheduled" → gray
   │  │  ├─ "open" → green
   │  │  ├─ "in_progress" → blue
   │  │  ├─ "completed" → purple
   │  │  └─ "cancelled" → red
   │  └─ Quick actions: Edit, Clone, Cancel, View Roster
   │
   └─ SEARCH functionality:
      ├─ By instructor name
      ├─ By organization name (B2B)
      └─ By cohort ID

2. CREATE new cohort:
   ├─ CLICK "Create Cohort" button
   │
   ├─ FORM step 1: Basic Info
   │  ├─ SELECT course (required)
   │  │  └─ FETCH courses: WHERE status = "published"
   │  ├─ SELECT sessionType (required)
   │  │  ├─ Options: Cohort (2-day intensive), Webinar (single session), Hackathon (multi-day)
   │  │  └─ DISPLAY type description on selection
   │  └─ NEXT → step 2
   │
   ├─ FORM step 2: Schedule
   │  ├─ IF sessionType = "cohort":
   │  │  ├─ SELECT day1Date (required)
   │  │  │  └─ VALIDATE: must be future date
   │  │  ├─ SELECT day1StartTime, day1EndTime (required)
   │  │  │  └─ DEFAULT: 09:00-17:00
   │  │  ├─ SELECT day2Date (required)
   │  │  │  └─ VALIDATE: must be after day1Date
   │  │  └─ SELECT day2StartTime, day2EndTime (required)
   │  │     └─ DEFAULT: 09:00-17:00
   │  │
   │  ├─ ELSE IF sessionType = "webinar":
   │  │  ├─ SELECT startDate (required)
   │  │  ├─ SELECT startTime (required)
   │  │  └─ INPUT durationMinutes (required)
   │  │     └─ DEFAULT: 90
   │  │
   │  ├─ ELSE IF sessionType = "hackathon":
   │  │  ├─ SELECT startDate (required)
   │  │  ├─ SELECT endDate (required)
   │  │  │  └─ VALIDATE: endDate >= startDate
   │  │  └─ INPUT dailySchedule (optional)
   │  │     └─ Example: "Daily sessions: 10am-6pm"
   │  │
   │  ├─ INPUT timezone (required)
   │  │  └─ DEFAULT: admin's timezone
   │  └─ NEXT → step 3
   │
   ├─ FORM step 3: Capacity & Instructor
   │  ├─ INPUT maxCapacity (required)
   │  │  ├─ DEFAULT: based on sessionType
   │  │  ├─ VALIDATE: must be > 0
   │  │  └─ INFO: "Set to 0 for unlimited"
   │  │
   │  ├─ TOGGLE enableWaitlist
   │  │  └─ DEFAULT: true if maxCapacity > 0
   │  │
   │  ├─ SELECT instructorId (required)
   │  │  ├─ FETCH users: WHERE role IN ("admin", "instructor")
   │  │  └─ DISPLAY: name, email, past cohorts count
   │  │
   │  └─ NEXT → step 4
   │
   ├─ FORM step 4: Meeting & Organization
   │  ├─ INPUT meetingLink (required)
   │  │  ├─ VALIDATE: must be valid URL
   │  │  └─ PLACEHOLDER: "https://zoom.us/j/..."
   │  │
   │  ├─ INPUT meetingPassword (optional)
   │  │
   │  ├─ TOGGLE isB2B
   │  │  └─ IF true:
   │  │     ├─ SELECT organizationId (required)
   │  │     │  └─ FETCH organizations: WHERE status = "active"
   │  │     └─ INFO: "This cohort is private to the organization"
   │  │
   │  └─ NEXT → review
   │
   ├─ FORM step 5: Review & Create
   │  ├─ DISPLAY summary:
   │  │  ├─ Course details
   │  │  ├─ Session type and dates (formatted)
   │  │  ├─ Capacity and waitlist settings
   │  │  ├─ Instructor details
   │  │  ├─ Meeting information
   │  │  └─ B2B details (if applicable)
   │  │
   │  ├─ SUBMIT:
   │  │  ├─ VALIDATE all fields
   │  │  │  └─ IF errors: scroll to first error, highlight field
   │  │  │
   │  │  ├─ CREATE cohort record:
   │  │  │  ├─ INSERT INTO cohorts
   │  │  │  ├─ SET status = "scheduled"
   │  │  │  ├─ SET createdBy = admin.id
   │  │  │  ├─ GENERATE slug: course-slug-YYYY-MM-DD
   │  │  │  └─ RETURN cohortId
   │  │  │
   │  │  ├─ IF sessionType = "cohort":
   │  │  │  └─ CREATE 2 cohortSessions:
   │  │  │     ├─ Session 1: day1Date, day1StartTime, day1EndTime
   │  │  │     └─ Session 2: day2Date, day2StartTime, day2EndTime
   │  │  │
   │  │  ├─ ELSE IF sessionType = "webinar":
   │  │  │  └─ CREATE 1 cohortSession:
   │  │  │     └─ Single session with calculated endTime
   │  │  │
   │  │  ├─ ELSE IF sessionType = "hackathon":
   │  │  │  └─ CREATE cohortSessions for each day:
   │  │  │     ├─ FOR each date FROM startDate TO endDate
   │  │  │     └─ CREATE session with default times or custom schedule
   │  │  │
   │  │  ├─ TRACK PostHog: "cohort_created"
   │  │  │  └─ Properties: cohortId, sessionType, courseId, maxCapacity
   │  │  │
   │  │  └─ REDIRECT to /admin/cohorts/{cohortId}
   │  │
   │  └─ OR "Back" to edit
   │
   └─ EDGE CASES:
      ├─ Admin cancels mid-creation
      │  └─ Discard form data, confirm if partially filled
      ├─ Date conflicts with instructor's schedule
      │  └─ WARNING: "Instructor has another cohort on this date"
      └─ B2B organization has no available seats
         └─ ERROR: "Organization has used all purchased seats"

3. OPEN cohort for enrollment:
   ├─ NAVIGATE to /admin/cohorts/{cohortId}
   │
   ├─ VERIFY prerequisites:
   │  ├─ CHECK status = "scheduled"
   │  │  └─ ELSE: SHOW error "Cannot open cohort in {current_status} status"
   │  ├─ CHECK has meeting link
   │  │  └─ ELSE: PROMPT to add meeting link first
   │  ├─ CHECK has instructor assigned
   │  │  └─ ELSE: PROMPT to assign instructor first
   │  └─ CHECK course has published content
   │     └─ ELSE: WARN "Course content not ready"
   │
   ├─ CLICK "Open for Enrollment"
   │  ├─ CONFIRM modal:
   │  │  ├─ "Opening this cohort will make it visible in the public catalog."
   │  │  ├─ IF isB2B: "Only {organization.name} members can enroll."
   │  │  └─ Buttons: "Confirm", "Cancel"
   │  │
   │  ├─ ON confirm:
   │  │  ├─ UPDATE cohort:
   │  │  │  ├─ SET status = "open"
   │  │  │  └─ SET openedAt = NOW()
   │  │  │
   │  │  ├─ IF NOT isB2B:
   │  │  │  └─ Cohort appears in /courses/{courseSlug} catalog
   │  │  │
   │  │  ├─ IF isB2B:
   │  │  │  └─ Send Brevo email to organization members:
   │  │  │     ├─ Subject: "New {course.name} cohort available"
   │  │  │     ├─ CTA: Direct enrollment link
   │  │  │     └─ Track: "b2b_cohort_announcement_sent"
   │  │  │
   │  │  ├─ IF enableWaitlist AND maxCapacity > 0:
   │  │  │  └─ Waitlist functionality becomes active
   │  │  │
   │  │  ├─ TRACK PostHog: "cohort_opened"
   │  │  │
   │  │  └─ SHOW success: "Cohort is now open for enrollment"
   │  │
   │  └─ UPDATE UI:
   │     ├─ Status badge → green "open"
   │     └─ Action button → "Close Enrollment" or "Start Session"
   │
   └─ EDGE CASES:
      ├─ No one enrolls
      │  └─ Admin can cancel or postpone
      ├─ Fills to capacity quickly
      │  └─ Waitlist auto-activates
      └─ Admin needs to revert to "scheduled"
         ├─ ONLY if enrollmentCount = 0
         └─ ELSE: must transfer/refund first

4. DURING session (in_progress status):
   ├─ MANUAL status update:
   │  ├─ ADMIN navigates to /admin/cohorts/{cohortId}
   │  ├─ CLICK "Mark In Progress"
   │  │  ├─ UPDATE status: "open" → "in_progress"
   │  │  ├─ SET startedAt = NOW()
   │  │  └─ CLOSE enrollment (no new enrollments allowed)
   │  │
   │  └─ OR automatic trigger:
   │     ├─ CRON job runs hourly
   │     ├─ CHECK cohorts: WHERE status = "open" AND startDate <= NOW()
   │     └─ UPDATE matching cohorts to "in_progress"
   │
   ├─ VIEW live roster:
   │  ├─ NAVIGATE to "Roster" tab
   │  │
   │  ├─ DISPLAY enrolled users table:
   │  │  ├─ Columns: name, email, enrollment date, payment status, attendance
   │  │  ├─ FILTER by: payment status, attendance status
   │  │  ├─ SEARCH by: name, email
   │  │  └─ EXPORT to CSV
   │  │
   │  └─ SHOW stats:
   │     ├─ Total enrolled
   │     ├─ Paid vs. pending
   │     ├─ Attendance count (if tracked)
   │     └─ Completion rate
   │
   ├─ ACCESS intake survey responses:
   │  ├─ NAVIGATE to "Intake Surveys" tab
   │  │
   │  ├─ DISPLAY responses:
   │  │  ├─ GROUP by question
   │  │  ├─ SHOW individual responses
   │  │  ├─ EXPORT to CSV for analysis
   │  │  └─ VIEW aggregate stats (if applicable)
   │  │
   │  └─ USE CASE:
   │     └─ Instructor prepares personalized examples based on responses
   │
   ├─ MANUAL attendance tracking:
   │  ├─ NAVIGATE to "Attendance" tab
   │  │
   │  ├─ IF sessionType = "cohort":
   │  │  ├─ SHOW two checklists: Day 1, Day 2
   │  │  ├─ FOR each session:
   │  │  │  ├─ LIST all enrolled users
   │  │  │  ├─ CHECKBOX for each user (checked = attended)
   │  │  │  └─ SAVE button (auto-save on change)
   │  │  └─ CALCULATE completion:
   │  │     └─ User completed IF attended both days
   │  │
   │  ├─ ELSE IF sessionType = "webinar":
   │  │  ├─ SHOW single checklist
   │  │  └─ Mark attendance for single session
   │  │
   │  ├─ ELSE IF sessionType = "hackathon":
   │  │  ├─ SHOW checklist for each day
   │  │  └─ User completed IF attended minimum threshold (e.g., 80% of days)
   │  │
   │  ├─ ON attendance check:
   │  │  ├─ UPDATE cohortSessionAttendance:
   │  │  │  └─ UPSERT (userId, sessionId, attended = true)
   │  │  └─ TRACK PostHog: "attendance_marked"
   │  │
   │  └─ ALTERNATIVE:
   │     └─ Zoom integration auto-tracks attendance (future feature)
   │
   ├─ COMMUNICATIONS:
   │  ├─ Send announcements to enrolled users
   │  ├─ Share meeting link reminders
   │  └─ Post session materials
   │
   └─ EDGE CASES:
      ├─ User joins late
      │  └─ Admin can manually mark as attended
      ├─ Technical issues during session
      │  └─ Admin extends session or schedules makeup
      └─ User leaves mid-session
         └─ Admin marks partial attendance, offers refund/transfer

5. COMPLETE session:
   ├─ MANUAL completion:
   │  ├─ ADMIN navigates to /admin/cohorts/{cohortId}
   │  ├─ CLICK "Mark Complete"
   │  │  ├─ CONFIRM modal: "This will trigger post-session automation"
   │  │  │
   │  │  ├─ ON confirm:
   │  │  │  ├─ UPDATE cohort:
   │  │  │  │  ├─ SET status = "completed"
   │  │  │  │  └─ SET completedAt = NOW()
   │  │  │  │
   │  │  │  ├─ CALCULATE completion for each user:
   │  │  │  │  ├─ IF sessionType = "cohort":
   │  │  │  │  │  └─ completed = attended Day 1 AND Day 2
   │  │  │  │  ├─ IF sessionType = "webinar":
   │  │  │  │  │  └─ completed = attended session
   │  │  │  │  └─ IF sessionType = "hackathon":
   │  │  │  │     └─ completed = attended >= 80% of sessions
   │  │  │  │
   │  │  │  ├─ UPDATE enrollments:
   │  │  │  │  ├─ SET completed = calculated value
   │  │  │  │  └─ SET completedAt = NOW() (if completed)
   │  │  │  │
   │  │  │  ├─ TRIGGER post-session automation:
   │  │  │  │  ├─ Send feedback survey (Brevo email)
   │  │  │  │  │  ├─ Template: post_session_feedback
   │  │  │  │  │  ├─ TO: all enrolled users
   │  │  │  │  │  └─ Link to /feedback/{cohortId}/{userId}
   │  │  │  │  │
   │  │  │  │  ├─ Send certificate (if completed):
   │  │  │  │  │  ├─ GENERATE certificate PDF:
   │  │  │  │  │  │  ├─ Template with user name, course name, date
   │  │  │  │  │  │  └─ SAVE to S3: certificates/{userId}-{cohortId}.pdf
   │  │  │  │  │  ├─ CREATE certificateUrl
   │  │  │  │  │  ├─ UPDATE enrollment: SET certificateUrl
   │  │  │  │  │  └─ Send Brevo email with download link
   │  │  │  │  │
   │  │  │  │  └─ Send follow-up resources (Brevo email)
   │  │  │  │     ├─ Template: post_session_resources
   │  │  │  │     ├─ Include: recordings, slides, community links
   │  │  │  │     └─ Track: "post_session_email_sent"
   │  │  │  │
   │  │  │  ├─ TRACK PostHog: "cohort_completed"
   │  │  │  │  └─ Properties: cohortId, enrollmentCount, completionRate
   │  │  │  │
   │  │  │  └─ SHOW success: "Cohort marked complete, automation triggered"
   │  │  │
   │  │  └─ UPDATE UI:
   │  │     ├─ Status badge → purple "completed"
   │  │     └─ Show completion stats
   │  │
   │  └─ OR automatic trigger:
   │     ├─ CRON job runs daily
   │     ├─ CHECK cohorts: WHERE status = "in_progress" AND endDate < NOW() - 1 day
   │     └─ AUTO-complete after grace period
   │
   ├─ UPLOAD recordings:
   │  ├─ NAVIGATE to "Recordings" tab
   │  ├─ UPLOAD video files to S3:
   │  │  ├─ Path: recordings/{cohortId}/{filename}
   │  │  ├─ Generate signed URL (7-day expiry)
   │  │  └─ CREATE cohortRecording record
   │  │
   │  ├─ OR add external links (YouTube, Vimeo)
   │  │
   │  └─ MAKE AVAILABLE:
   │     ├─ Add to enablement kit
   │     └─ Notify enrolled users
   │
   ├─ GENERATE certificates:
   │  ├─ OPTION 1: Automatic (on completion)
   │  │  └─ Already triggered in post-session automation
   │  │
   │  ├─ OPTION 2: Manual regeneration
   │  │  ├─ NAVIGATE to "Certificates" tab
   │  │  ├─ CLICK "Regenerate All" or "Regenerate for {user}"
   │  │  └─ Re-run certificate generation process
   │  │
   │  └─ CERTIFICATE DATA:
   │     ├─ User name
   │     ├─ Course name
   │     ├─ Completion date
   │     ├─ Certificate ID (for verification)
   │     └─ Instructor signature (digital)
   │
   └─ EDGE CASES:
      ├─ User completed but didn't receive certificate
      │  └─ Admin can regenerate and resend
      ├─ Feedback survey not sent
      │  └─ Admin can manually trigger from "Communications" tab
      └─ Recording upload fails
         └─ Retry upload, check S3 permissions

6. CANCEL cohort:
   ├─ ADMIN navigates to /admin/cohorts/{cohortId}
   │
   ├─ CLICK "Cancel Cohort"
   │  ├─ CONFIRM modal:
   │  │  ├─ SHOW current state:
   │  │  │  ├─ Status: {current_status}
   │  │  │  ├─ Enrolled users: {enrollmentCount}
   │  │  │  ├─ Total paid: ${totalRevenue}
   │  │  │  └─ Days until start: {daysUntilStart}
   │  │  │
   │  │  ├─ WARNING:
   │  │  │  ├─ "This will refund all enrolled users"
   │  │  │  ├─ "Total refund amount: ${totalRevenue}"
   │  │  │  └─ "This action cannot be undone"
   │  │  │
   │  │  ├─ INPUT cancellationReason (required)
   │  │  │  ├─ Dropdown: "Low enrollment", "Instructor unavailable",
   │  │  │  │            "Technical issues", "Other"
   │  │  │  └─ Textarea: Additional details (optional)
   │  │  │
   │  │  └─ Buttons: "Confirm Cancellation", "Cancel"
   │  │
   │  ├─ ON confirm:
   │  │  ├─ UPDATE cohort:
   │  │  │  ├─ SET status = "cancelled"
   │  │  │  ├─ SET cancelledAt = NOW()
   │  │  │  ├─ SET cancelledBy = admin.id
   │  │  │  └─ SET cancellationReason
   │  │  │
   │  │  ├─ PROCESS refunds for all enrollees:
   │  │  │  ├─ QUERY enrollments: WHERE cohortId AND paymentStatus = "paid"
   │  │  │  │
   │  │  │  ├─ FOR each enrollment:
   │  │  │  │  ├─ IF has stripePaymentIntentId:
   │  │  │  │  │  ├─ CREATE Stripe refund:
   │  │  │  │  │  │  ├─ API: stripe.refunds.create({
   │  │  │  │  │  │  │      payment_intent: enrollment.stripePaymentIntentId,
   │  │  │  │  │  │  │      reason: "requested_by_customer",
   │  │  │  │  │  │  │      metadata: { cohortId, enrollmentId, reason: "cohort_cancelled" }
   │  │  │  │  │  │  │    })
   │  │  │  │  │  │  ├─ AWAIT refund confirmation
   │  │  │  │  │  │  └─ UPDATE enrollment:
   │  │  │  │  │  │     ├─ SET paymentStatus = "refunded"
   │  │  │  │  │  │     ├─ SET stripeRefundId = refund.id
   │  │  │  │  │  │     └─ SET refundedAt = NOW()
   │  │  │  │  │  │
   │  │  │  │  │  └─ TRACK PostHog: "payment_refunded"
   │  │  │  │  │     └─ Properties: enrollmentId, amount, reason: "cohort_cancelled"
   │  │  │  │  │
   │  │  │  │  ├─ ELSE IF isB2B:
   │  │  │  │  │  ├─ UPDATE organizationSeatsUsed:
   │  │  │  │  │  │  └─ DECREMENT org.seatsUsed
   │  │  │  │  │  └─ NO monetary refund (seat returned to pool)
   │  │  │  │  │
   │  │  │  │  └─ ELSE:
   │  │  │  │     └─ LOG warning: "Enrollment has no payment record"
   │  │  │  │
   │  │  │  └─ HANDLE refund failures:
   │  │  │     ├─ LOG error details
   │  │  │     ├─ SET enrollment.refundStatus = "failed"
   │  │  │     └─ ADMIN must manually process in Stripe
   │  │  │
   │  │  ├─ SEND cancellation emails (Brevo):
   │  │  │  ├─ QUERY all enrolled users
   │  │  │  │
   │  │  │  ├─ FOR each user:
   │  │  │  │  ├─ Template: cohort_cancelled
   │  │  │  │  ├─ Params:
   │  │  │  │  │  ├─ userName
   │  │  │  │  │  ├─ courseName
   │  │  │  │  │  ├─ cohortDates
   │  │  │  │  │  ├─ refundAmount (if applicable)
   │  │  │  │  │  └─ alternativeCohorts (suggestions)
   │  │  │  │  │
   │  │  │  │  ├─ SEND email
   │  │  │  │  └─ TRACK: "cancellation_email_sent"
   │  │  │  │
   │  │  │  └─ EMAIL CONTENT:
   │  │  │     ├─ Apology and explanation
   │  │  │     ├─ Refund confirmation (if paid)
   │  │  │     ├─ Alternative cohort suggestions
   │  │  │     └─ CTA: "View Alternative Dates"
   │  │  │
   │  │  ├─ OFFER transfer to alternative cohort:
   │  │  │  ├─ QUERY alternative cohorts:
   │  │  │  │  ├─ WHERE courseId = cancelled_cohort.courseId
   │  │  │  │  ├─ AND status = "open"
   │  │  │  │  ├─ AND startDate > NOW()
   │  │  │  │  └─ ORDER BY startDate ASC
   │  │  │  │  └─ LIMIT 3
   │  │  │  │
   │  │  │  ├─ DISPLAY in cancellation email:
   │  │  │  │  └─ "Transfer to these upcoming cohorts:"
   │  │  │  │     ├─ Cohort 1: {dates}, {enrollment/capacity}
   │  │  │  │     ├─ Cohort 2: {dates}, {enrollment/capacity}
   │  │  │  │     └─ Cohort 3: {dates}, {enrollment/capacity}
   │  │  │  │
   │  │  │  └─ USER clicks "Transfer to [cohort]":
   │  │  │     ├─ VALIDATE new cohort has capacity
   │  │  │     ├─ UPDATE enrollment:
   │  │  │     │  ├─ SET cohortId = new_cohort_id
   │  │  │     │  ├─ SET transferredFrom = old_cohort_id
   │  │  │     │  └─ KEEP original payment (no new charge)
   │  │  │     ├─ SEND confirmation email
   │  │  │     └─ TRACK: "cohort_transfer_accepted"
   │  │  │
   │  │  ├─ TRACK PostHog: "cohort_cancelled"
   │  │  │  └─ Properties: cohortId, enrollmentCount, totalRefunded, reason
   │  │  │
   │  │  └─ SHOW success:
   │  │     ├─ "Cohort cancelled successfully"
   │  │     ├─ "{refundCount} refunds processed"
   │  │     ├─ "{emailCount} cancellation emails sent"
   │  │     └─ Link to refund report
   │  │
   │  └─ UPDATE UI:
   │     ├─ Status badge → red "cancelled"
   │     ├─ Hide from public catalog
   │     └─ Show cancellation details in admin view
   │
   └─ EDGE CASES:
      ├─ Cancellation < 24h before start
      │  ├─ EXTRA WARNING: "This is very short notice"
      │  └─ Consider offering additional compensation
      │
      ├─ Partial refund failures
      │  ├─ LOG failed refunds
      │  ├─ SEND admin alert email
      │  └─ DISPLAY failed refunds in admin panel
      │
      ├─ User already started session
      │  ├─ ALLOW partial refund (pro-rated)
      │  └─ OR offer free access to next cohort
      │
      ├─ B2B cohort cancellation
      │  ├─ Return all seats to organization
      │  ├─ Notify organization admin
      │  └─ Offer to schedule replacement cohort
      │
      └─ User doesn't want transfer, wants refund only
         └─ Refund already processed, user can re-enroll later

VALIDATION RULES:
├─ Cannot cancel cohort with status "completed"
├─ Cannot open cohort without meeting link
├─ Cannot mark in_progress before startDate (unless manual override)
├─ Day 2 date must be after Day 1 date (cohort type)
├─ maxCapacity must be >= current enrollmentCount
└─ Cannot delete cohort with enrollments (must cancel first)

NOTIFICATIONS:
├─ Cohort opened → Organization admins (if B2B)
├─ Cohort starting soon → Enrolled users (24h before)
├─ Cohort completed → Feedback survey + certificate
├─ Cohort cancelled → Refund confirmation + alternatives
└─ Attendance marked → No user notification (internal only)

PERMISSIONS:
├─ CREATE cohort: admin only
├─ EDIT cohort: admin + assigned instructor
├─ CANCEL cohort: admin only
├─ MARK attendance: admin + assigned instructor
└─ VIEW roster: admin + assigned instructor
```

---

## 2.2.2 Enablement Kit Management Flow

```
FLOW: ENABLEMENT_KIT_MANAGEMENT

CONTEXT:
  Enablement kits are course-specific bundles of files and links
  that become available to users upon enrollment.
  Files are stored in S3, links are external URLs.

1. ADMIN navigates to /admin/courses/{courseId}/enablement-kit
   ├─ DISPLAY current kit contents:
   │  ├─ Grouped by type:
   │  │  ├─ 📄 Files (slides, worksheets, templates, prompts)
   │  │  └─ 🔗 Links (chatbot URLs, external resources)
   │  │
   │  ├─ FOR each item:
   │  │  ├─ Display: icon, title, type, size (files), order
   │  │  ├─ Actions: Edit, Delete, Move Up/Down
   │  │  └─ Preview (files only)
   │  │
   │  └─ SHOW stats:
   │     ├─ Total items: {count}
   │     ├─ Total storage: {size} MB
   │     └─ Last updated: {timestamp}
   │
   └─ BUTTONS:
      ├─ "Upload Files"
      ├─ "Add Link"
      └─ "Reorder Items"

2. UPLOAD files:
   ├─ CLICK "Upload Files"
   │
   ├─ FILE PICKER modal:
   │  ├─ DRAG-DROP zone
   │  │  └─ "Drag files here or click to browse"
   │  │
   │  ├─ SUPPORTED formats:
   │  │  ├─ Documents: PDF, DOCX, PPTX, TXT, MD
   │  │  ├─ Spreadsheets: XLSX, CSV
   │  │  ├─ Images: PNG, JPG, SVG
   │  │  └─ Archives: ZIP
   │  │
   │  ├─ SIZE LIMIT: 50MB per file
   │  │
   │  └─ MULTI-SELECT: enabled
   │
   ├─ ON file selection:
   │  ├─ FOR each file:
   │  │  ├─ VALIDATE:
   │  │  │  ├─ CHECK file type (extension + MIME)
   │  │  │  │  └─ IF invalid: SHOW error "Unsupported file type"
   │  │  │  ├─ CHECK file size <= 50MB
   │  │  │  │  └─ IF too large: SHOW error "File exceeds 50MB limit"
   │  │  │  └─ CHECK virus scan (if available)
   │  │  │
   │  │  ├─ PREVIEW upload:
   │  │  │  ├─ Show: filename, size, type
   │  │  │  ├─ INPUT title (default: filename without extension)
   │  │  │  ├─ INPUT description (optional)
   │  │  │  ├─ SELECT category (optional):
   │  │  │  │  └─ Options: Slides, Worksheets, Templates, Prompts, Reference, Other
   │  │  │  └─ CHECKBOX: "Make immediately available to enrolled users"
   │  │  │
   │  │  └─ SHOW upload progress bar
   │  │
   │  └─ BUTTONS: "Upload All", "Cancel"
   │
   ├─ ON "Upload All":
   │  ├─ FOR each file:
   │  │  ├─ GENERATE unique filename:
   │  │  │  └─ Pattern: {courseId}/{timestamp}-{sanitized-original-name}
   │  │  │
   │  │  ├─ UPLOAD to S3:
   │  │  │  ├─ Bucket: enablement-kits
   │  │  │  ├─ Path: {courseId}/{filename}
   │  │  │  ├─ ACL: private (presigned URLs for access)
   │  │  │  ├─ Metadata:
   │  │  │  │  ├─ courseId
   │  │  │  │  ├─ uploadedBy (admin.id)
   │  │  │  │  ├─ originalFilename
   │  │  │  │  └─ uploadedAt
   │  │  │  └─ RETURN S3 URL
   │  │  │
   │  │  ├─ CREATE enablementKitItem record:
   │  │  │  ├─ INSERT INTO enablementKitItems
   │  │  │  ├─ SET:
   │  │  │  │  ├─ courseId
   │  │  │  │  ├─ type = "file"
   │  │  │  │  ├─ title (from input)
   │  │  │  │  ├─ description (from input)
   │  │  │  │  ├─ category (from input)
   │  │  │  │  ├─ fileUrl = S3 URL
   │  │  │  │  ├─ fileName = original filename
   │  │  │  │  ├─ fileSize = size in bytes
   │  │  │  │  ├─ mimeType
   │  │  │  │  ├─ order = MAX(order) + 1 (append to end)
   │  │  │  │  └─ isActive = true
   │  │  │  └─ RETURN itemId
   │  │  │
   │  │  ├─ TRACK PostHog: "enablement_kit_file_uploaded"
   │  │  │  └─ Properties: courseId, fileType, fileSize, category
   │  │  │
   │  │  └─ UPDATE progress: "{n}/{total} uploaded"
   │  │
   │  ├─ IF "Make immediately available" checked:
   │  │  └─ Send notification to enrolled users (optional feature)
   │  │
   │  ├─ SHOW success: "{count} files uploaded successfully"
   │  │
   │  └─ REFRESH kit contents list
   │
   └─ EDGE CASES:
      ├─ Upload fails mid-batch
      │  ├─ SHOW partial success: "X/Y files uploaded"
      │  ├─ LIST failed files with reasons
      │  └─ BUTTON: "Retry Failed"
      │
      ├─ Duplicate filename
      │  ├─ Auto-append counter: filename-2.pdf
      │  └─ OR prompt: "Replace existing?"
      │
      ├─ S3 quota exceeded
      │  └─ ERROR: "Storage limit reached, contact support"
      │
      └─ Network interruption
         ├─ RETRY upload automatically (3 attempts)
         └─ IF fails: SHOW error, KEEP in queue for manual retry

3. ADD external link:
   ├─ CLICK "Add Link"
   │
   ├─ LINK FORM modal:
   │  ├─ INPUT title (required)
   │  │  └─ PLACEHOLDER: "Chatbot for Module 3"
   │  │
   │  ├─ INPUT url (required)
   │  │  ├─ PLACEHOLDER: "https://..."
   │  │  └─ VALIDATE:
   │  │     ├─ Must be valid URL format
   │  │     └─ Must start with http:// or https://
   │  │
   │  ├─ INPUT description (optional)
   │  │  └─ PLACEHOLDER: "Access the AI assistant for this module"
   │  │
   │  ├─ SELECT category (optional)
   │  │  └─ Options: Chatbot, Tool, Resource, Community, Other
   │  │
   │  ├─ SELECT linkType:
   │  │  ├─ "External" (opens in new tab) - default
   │  │  └─ "Embedded" (iFrame within platform)
   │  │
   │  ├─ CHECKBOX: "Open in new tab"
   │  │  └─ DEFAULT: true
   │  │
   │  └─ BUTTONS: "Add Link", "Cancel"
   │
   ├─ ON "Add Link":
   │  ├─ VALIDATE all fields
   │  │  └─ IF errors: highlight fields, prevent submit
   │  │
   │  ├─ CREATE enablementKitItem record:
   │  │  ├─ INSERT INTO enablementKitItems
   │  │  ├─ SET:
   │  │  │  ├─ courseId
   │  │  │  ├─ type = "link"
   │  │  │  ├─ title
   │  │  │  ├─ description
   │  │  │  ├─ category
   │  │  │  ├─ externalUrl = url
   │  │  │  ├─ linkType
   │  │  │  ├─ openInNewTab
   │  │  │  ├─ order = MAX(order) + 1
   │  │  │  └─ isActive = true
   │  │  └─ RETURN itemId
   │  │
   │  ├─ TRACK PostHog: "enablement_kit_link_added"
   │  │  └─ Properties: courseId, linkType, category
   │  │
   │  ├─ SHOW success: "Link added successfully"
   │  │
   │  └─ REFRESH kit contents list
   │
   └─ EDGE CASES:
      ├─ Invalid URL
      │  └─ ERROR: "Please enter a valid URL"
      ├─ URL is not accessible (404, SSL error)
      │  └─ WARNING: "URL may not be accessible, add anyway?"
      └─ Duplicate URL
         └─ WARNING: "This URL already exists in the kit"

4. DRAG-DROP reordering:
   ├─ CLICK "Reorder Items"
   │  └─ ENABLE drag handles on all items
   │
   ├─ DRAG item to new position:
   │  ├─ VISUAL feedback:
   │  │  ├─ Show placeholder where item will drop
   │  │  ├─ Dim other items
   │  │  └─ Update order numbers in real-time
   │  │
   │  ├─ ON drop:
   │  │  ├─ CALCULATE new order values:
   │  │  │  ├─ Dropped item gets target position order
   │  │  │  └─ Other items shift accordingly
   │  │  │
   │  │  ├─ UPDATE database (batch):
   │  │  │  └─ FOR each affected item:
   │  │  │     └─ UPDATE enablementKitItems SET order = new_order WHERE id = itemId
   │  │  │
   │  │  ├─ AUTO-SAVE (no explicit save button)
   │  │  │  └─ SHOW toast: "Order updated"
   │  │  │
   │  │  └─ TRACK PostHog: "enablement_kit_reordered"
   │  │
   │  └─ ALTERNATIVE: Up/Down arrow buttons
   │     ├─ CLICK ↑ to move up one position
   │     └─ CLICK ↓ to move down one position
   │
   └─ EDGE CASES:
      ├─ Concurrent edits by multiple admins
      │  ├─ OPTIMISTIC update (instant UI)
      │  ├─ IF conflict: REFRESH from server
      │  └─ SHOW warning: "Order updated by another admin"
      └─ Browser crash during reorder
         └─ Changes auto-save, no data loss

5. DELETE item:
   ├─ CLICK "Delete" on item
   │
   ├─ CONFIRM modal:
   │  ├─ "Delete {item.title}?"
   │  ├─ IF type = "file":
   │  │  └─ WARNING: "This will permanently delete the file from storage"
   │  ├─ IF type = "link":
   │  │  └─ "This will remove the link (external resource remains)"
   │  │
   │  └─ BUTTONS: "Delete", "Cancel"
   │
   ├─ ON confirm:
   │  ├─ IF type = "file":
   │  │  ├─ DELETE from S3:
   │  │  │  ├─ API: s3.deleteObject({
   │  │  │  │      Bucket: "enablement-kits",
   │  │  │  │      Key: item.fileUrl
   │  │  │  │    })
   │  │  │  └─ HANDLE errors:
   │  │  │     ├─ IF file not found: LOG warning, proceed
   │  │  │     └─ IF permission error: SHOW error, abort
   │  │  │
   │  │  └─ UPDATE storage stats
   │  │
   │  ├─ DELETE database record:
   │  │  └─ DELETE FROM enablementKitItems WHERE id = itemId
   │  │
   │  ├─ REORDER remaining items:
   │  │  └─ UPDATE order values to remove gaps
   │  │     └─ UPDATE enablementKitItems SET order = order - 1 WHERE order > deleted_item_order
   │  │
   │  ├─ TRACK PostHog: "enablement_kit_item_deleted"
   │  │  └─ Properties: courseId, itemType, category
   │  │
   │  ├─ SHOW success: "Item deleted successfully"
   │  │
   │  └─ REFRESH kit contents list
   │
   └─ EDGE CASES:
      ├─ S3 deletion fails but DB record deleted
      │  ├─ LOG error for manual cleanup
      │  └─ Schedule orphaned file cleanup job
      │
      ├─ Item in use by enrolled users
      │  └─ ALLOW deletion (users lose access)
      │
      └─ Undo deletion request
         └─ NOT SUPPORTED (permanent deletion)
         └─ ALTERNATIVE: Mark as inactive instead of delete

6. IMMEDIATE availability to enrolled users:
   ├─ ALL items are IMMEDIATELY visible after upload/creation
   │  └─ No separate "publish" step required
   │
   ├─ USER ACCESS:
   │  ├─ NAVIGATE to /courses/{courseSlug}/enablement-kit
   │  │  └─ OR from course dashboard after enrollment
   │  │
   │  ├─ VERIFY user is enrolled:
   │  │  └─ QUERY enrollments: WHERE userId AND courseId
   │  │     ├─ IF not found: REDIRECT to course page "Enroll to access"
   │  │     └─ IF found: proceed
   │  │
   │  ├─ FETCH enablement kit items:
   │  │  ├─ QUERY: WHERE courseId AND isActive = true ORDER BY order ASC
   │  │  └─ FOR each item:
   │  │     ├─ IF type = "file":
   │  │     │  ├─ GENERATE presigned S3 URL:
   │  │     │  │  ├─ Expiry: 1 hour
   │  │     │  │  ├─ Permissions: read-only
   │  │     │  │  └─ RETURN temporary download URL
   │  │     │  └─ DISPLAY: Download button with file icon
   │  │     │
   │  │     └─ IF type = "link":
   │  │        ├─ DISPLAY: External link with open icon
   │  │        └─ OPEN in new tab (if configured)
   │  │
   │  ├─ TRACK usage (optional):
   │  │  └─ PostHog: "enablement_kit_item_accessed"
   │  │     └─ Properties: itemId, itemType, userId
   │  │
   │  └─ DOWNLOAD file:
   │     ├─ CLICK download button
   │     ├─ FETCH from presigned URL
   │     ├─ BROWSER handles download
   │     └─ TRACK: "enablement_kit_file_downloaded"
   │
   └─ REVOKE access:
      ├─ IF user refunds enrollment:
      │  └─ No longer sees enablement kit (enrollment check fails)
      └─ IF admin sets isActive = false on item:
         └─ Item hidden from all users immediately

VALIDATION RULES:
├─ File uploads:
│  ├─ Size <= 50MB per file
│  ├─ Allowed file types only
│  └─ Virus scan passes (if enabled)
│
├─ Links:
│  ├─ Valid URL format (http/https)
│  └─ Title required
│
└─ Reordering:
   ├─ Order values must be unique
   └─ No gaps in order sequence

STORAGE MANAGEMENT:
├─ S3 bucket: enablement-kits
├─ Folder structure: {courseId}/{timestamp}-{filename}
├─ ACL: private (presigned URLs for access)
├─ Lifecycle: No auto-deletion (manual cleanup)
└─ Quota: Monitor per-course storage, alert at threshold

PERMISSIONS:
├─ UPLOAD files: admin only
├─ ADD links: admin only
├─ REORDER items: admin only
├─ DELETE items: admin only
└─ VIEW/DOWNLOAD: enrolled users only

NOTIFICATIONS:
├─ New file uploaded → Enrolled users (optional email)
├─ Storage quota 80% → Admin alert
└─ Failed upload → Admin error notification
```

---

## 2.2.3 B2B Manual Enrollment Flow

```
FLOW: B2B_MANUAL_ENROLLMENT

CONTEXT:
  B2B customers purchase bulk seats for their team.
  Payments are handled manually via Stripe invoices.
  Admins manage the entire process from invoice to enrollment.

1. RECEIVE B2B request (offline):
   ├─ CUSTOMER contacts via:
   │  ├─ Email: sales@aienablement.academy
   │  ├─ Contact form on website
   │  └─ Direct outreach
   │
   ├─ GATHER requirements:
   │  ├─ Organization name
   │  ├─ Contact person (name, email, role)
   │  ├─ Number of seats needed
   │  ├─ Desired course(s)
   │  ├─ Preferred cohort dates (if known)
   │  └─ Special requirements (custom content, private cohort, etc.)
   │
   └─ CALCULATE pricing:
      ├─ Base price per seat (from course.price)
      ├─ Apply volume discount:
      │  ├─ 5-9 seats: 10% off
      │  ├─ 10-19 seats: 15% off
      │  ├─ 20-49 seats: 20% off
      │  └─ 50+ seats: 25% off (custom pricing)
      ├─ Add-ons (if requested):
      │  ├─ Private cohort: +$2000
      │  ├─ Custom content: +$5000
      │  └─ Extended support: +$500/month
      └─ QUOTE total amount

2. ADMIN creates Organization record:
   ├─ NAVIGATE to /admin/organizations
   │
   ├─ CLICK "Create Organization"
   │
   ├─ FORM:
   │  ├─ INPUT name (required)
   │  │  └─ EXAMPLE: "Acme Corporation"
   │  │
   │  ├─ INPUT domain (optional)
   │  │  ├─ EXAMPLE: "acme.com"
   │  │  └─ USE CASE: Auto-verify team members by email domain
   │  │
   │  ├─ INPUT contactName (required)
   │  │  └─ Primary contact person
   │  │
   │  ├─ INPUT contactEmail (required)
   │  │  ├─ VALIDATE: valid email format
   │  │  └─ USE CASE: Invoice recipient, main point of contact
   │  │
   │  ├─ INPUT contactPhone (optional)
   │  │
   │  ├─ INPUT seatsPurchased (required)
   │  │  ├─ DEFAULT: 0 (will update after payment)
   │  │  └─ VALIDATE: must be > 0
   │  │
   │  ├─ SELECT status:
   │  │  ├─ Options: "pending_payment", "active", "suspended", "expired"
   │  │  └─ DEFAULT: "pending_payment"
   │  │
   │  ├─ INPUT notes (optional)
   │  │  └─ Admin-only notes about the account
   │  │
   │  └─ BUTTONS: "Create", "Cancel"
   │
   ├─ ON submit:
   │  ├─ VALIDATE all required fields
   │  │
   │  ├─ CREATE organization record:
   │  │  ├─ INSERT INTO organizations
   │  │  ├─ SET:
   │  │  │  ├─ name, domain, contactName, contactEmail, contactPhone
   │  │  │  ├─ status = "pending_payment"
   │  │  │  ├─ seatsPurchased (initial value)
   │  │  │  ├─ seatsUsed = 0
   │  │  │  ├─ createdBy = admin.id
   │  │  │  └─ createdAt = NOW()
   │  │  └─ RETURN organizationId
   │  │
   │  ├─ TRACK PostHog: "organization_created"
   │  │  └─ Properties: organizationId, seatsPurchased, status
   │  │
   │  ├─ SHOW success: "Organization created successfully"
   │  │
   │  └─ REDIRECT to /admin/organizations/{organizationId}
   │
   └─ EDGE CASE:
      └─ Duplicate organization name
         └─ WARNING: "An organization with this name already exists"

3. ADMIN creates Stripe manual invoice:
   ├─ NAVIGATE to Stripe Dashboard (external)
   │  └─ URL: https://dashboard.stripe.com/invoices/create
   │
   ├─ CREATE invoice:
   │  ├─ SELECT or CREATE customer:
   │  │  ├─ Name: {organization.name}
   │  │  ├─ Email: {organization.contactEmail}
   │  │  └─ Metadata: { organizationId: {id} }
   │  │
   │  ├─ ADD line items:
   │  │  ├─ FOR each course/cohort:
   │  │  │  ├─ Description: "{course.name} - {seatCount} seats"
   │  │  │  ├─ Quantity: {seatCount}
   │  │  │  ├─ Unit price: {pricePerSeat} (after discount)
   │  │  │  └─ Total: {quantity * unit_price}
   │  │  │
   │  │  └─ ADD add-ons (if applicable):
   │  │     ├─ Private cohort fee
   │  │     ├─ Custom content fee
   │  │     └─ Extended support
   │  │
   │  ├─ SET metadata (CRITICAL):
   │  │  ├─ organizationId: {organizationId}
   │  │  ├─ courseId: {courseId}
   │  │  ├─ seatsPurchased: {count}
   │  │  └─ createdBy: {admin.email}
   │  │
   │  ├─ SET payment terms:
   │  │  ├─ Due date: Net 30 (or custom)
   │  │  └─ Payment methods: Bank transfer, Credit card
   │  │
   │  ├─ ADD memo (optional):
   │  │  └─ "Thank you for your purchase. Team invites will be sent upon payment."
   │  │
   │  └─ SEND invoice to customer
   │     └─ Stripe sends email to {organization.contactEmail}
   │
   ├─ COPY invoice details back to platform:
   │  ├─ NAVIGATE to /admin/organizations/{organizationId}
   │  ├─ CLICK "Add Invoice"
   │  ├─ INPUT:
   │  │  ├─ stripeInvoiceId (from Stripe)
   │  │  ├─ amount
   │  │  ├─ status: "pending"
   │  │  └─ dueDate
   │  └─ SAVE (links invoice to organization)
   │
   └─ EDGE CASES:
      ├─ Customer requests changes to invoice
      │  ├─ EDIT invoice in Stripe
      │  └─ UPDATE local record if needed
      │
      └─ Invoice creation fails
         └─ CHECK Stripe API keys, retry

4. TRACK payment (manual check):
   ├─ OPTION 1: Stripe webhook (automated):
   │  ├─ STRIPE sends webhook: invoice.paid
   │  │
   │  ├─ WEBHOOK handler receives event:
   │  │  ├─ VERIFY webhook signature
   │  │  ├─ EXTRACT:
   │  │  │  ├─ invoiceId
   │  │  │  ├─ organizationId (from metadata)
   │  │  │  ├─ amount paid
   │  │  │  └─ payment date
   │  │  │
   │  │  ├─ UPDATE organization:
   │  │  │  ├─ SET status = "active"
   │  │  │  ├─ SET seatsPurchased = metadata.seatsPurchased
   │  │  │  └─ SET paidAt = NOW()
   │  │  │
   │  │  ├─ UPDATE local invoice record:
   │  │  │  └─ SET status = "paid"
   │  │  │
   │  │  ├─ TRACK PostHog: "b2b_payment_received"
   │  │  │  └─ Properties: organizationId, amount, seatsPurchased
   │  │  │
   │  │  └─ TRIGGER next step: send invites (can be manual or auto)
   │  │
   │  └─ EDGE CASE: Webhook fails
   │     └─ FALLBACK to manual check (Option 2)
   │
   └─ OPTION 2: Manual verification (fallback):
      ├─ ADMIN checks Stripe Dashboard periodically
      ├─ WHEN invoice shows "Paid":
      │  ├─ NAVIGATE to /admin/organizations/{organizationId}
      │  ├─ CLICK "Mark Invoice as Paid"
      │  ├─ CONFIRM:
      │  │  ├─ Verify payment in Stripe
      │  │  └─ Update local record
      │  └─ PROCEED to send invites
      │
      └─ EDGE CASE: Partial payment
         ├─ UPDATE seatsPurchased proportionally
         └─ SEND partial invites

5. ADMIN sends invite emails:
   ├─ NAVIGATE to /admin/organizations/{organizationId}/invites
   │
   ├─ VERIFY organization status = "active"
   │  └─ IF not: SHOW error "Payment pending, cannot send invites"
   │
   ├─ CLICK "Send Invites"
   │
   ├─ INVITE FORM:
   │  ├─ INPUT method:
   │  │  ├─ OPTION 1: Bulk upload (CSV)
   │  │  │  ├─ DOWNLOAD CSV template:
   │  │  │  │  └─ Columns: email, firstName, lastName, role (optional)
   │  │  │  ├─ UPLOAD filled CSV
   │  │  │  └─ PARSE and validate
   │  │  │
   │  │  └─ OPTION 2: Manual entry (one by one)
   │  │     ├─ INPUT email (required)
   │  │     ├─ INPUT firstName, lastName (optional)
   │  │     └─ BUTTON: "Add Another"
   │  │
   │  ├─ VALIDATE entries:
   │  │  ├─ CHECK email format
   │  │  ├─ CHECK not already invited
   │  │  ├─ CHECK not already enrolled
   │  │  └─ CHECK seats available:
   │  │     └─ IF (inviteCount + seatsUsed) > seatsPurchased:
   │  │        └─ ERROR: "Not enough seats available"
   │  │
   │  ├─ PREVIEW invite list:
   │  │  ├─ SHOW: email, name, status
   │  │  ├─ REMOVE option for each
   │  │  └─ SHOW: "{count} invites ready, {remaining} seats left"
   │  │
   │  └─ BUTTONS: "Send Invites", "Cancel"
   │
   ├─ ON "Send Invites":
   │  ├─ FOR each team member:
   │  │  ├─ GENERATE unique inviteToken:
   │  │  │  └─ crypto.randomUUID() or similar
   │  │  │
   │  │  ├─ CREATE organizationInvite record:
   │  │  │  ├─ INSERT INTO organizationInvites
   │  │  │  ├─ SET:
   │  │  │  │  ├─ organizationId
   │  │  │  │  ├─ email
   │  │  │  │  ├─ firstName, lastName (if provided)
   │  │  │  │  ├─ inviteToken (unique)
   │  │  │  │  ├─ status = "pending"
   │  │  │  │  ├─ invitedBy = admin.id
   │  │  │  │  ├─ invitedAt = NOW()
   │  │  │  │  └─ expiresAt = NOW() + 30 days
   │  │  │  └─ RETURN inviteId
   │  │  │
   │  │  ├─ GENERATE invite link:
   │  │  │  └─ URL: https://app.aienablement.academy/invite/{inviteToken}
   │  │  │
   │  │  ├─ SEND Brevo email:
   │  │  │  ├─ Template: organization_invite
   │  │  │  ├─ TO: {email}
   │  │  │  ├─ Params:
   │  │  │  │  ├─ firstName (or "Team Member")
   │  │  │  │  ├─ organizationName
   │  │  │  │  ├─ inviteLink
   │  │  │  │  ├─ courseName (if specific cohort)
   │  │  │  │  └─ expiryDate
   │  │  │  │
   │  │  │  └─ CONTENT:
   │  │  │     ├─ "Your organization has purchased access to {course}"
   │  │  │     ├─ "Click to accept your invite and create your account"
   │  │  │     ├─ CTA button: "Accept Invite"
   │  │  │     └─ "This invite expires on {expiryDate}"
   │  │  │
   │  │  └─ TRACK PostHog: "organization_invite_sent"
   │  │     └─ Properties: inviteId, organizationId, email
   │  │
   │  ├─ UPDATE organization:
   │  │  └─ SET seatsUsed += inviteCount (reserve seats)
   │  │
   │  ├─ SHOW success: "{count} invites sent successfully"
   │  │
   │  └─ DISPLAY invite status table
   │
   └─ EDGE CASES:
      ├─ Email delivery fails (bounce)
      │  ├─ TRACK bounce in Brevo webhook
      │  ├─ MARK invite status = "bounced"
      │  └─ ADMIN can resend to corrected email
      │
      ├─ User already has account
      │  └─ Invite links account to organization, skips signup
      │
      └─ Invite expires before acceptance
         └─ ADMIN can extend expiry or resend

6. TEAM MEMBER accepts invite:
   ├─ USER clicks invite link in email
   │  └─ URL: /invite/{inviteToken}
   │
   ├─ VALIDATE inviteToken:
   │  ├─ QUERY organizationInvites: WHERE inviteToken
   │  │
   │  ├─ IF not found:
   │  │  └─ SHOW error: "Invalid invite link"
   │  │
   │  ├─ IF status != "pending":
   │  │  └─ SHOW error: "This invite has already been {status}"
   │  │
   │  ├─ IF expiresAt < NOW():
   │  │  └─ SHOW error: "This invite has expired. Contact {organization.contactEmail}"
   │  │
   │  └─ IF valid: proceed
   │
   ├─ DISPLAY invite acceptance page:
   │  ├─ SHOW:
   │  │  ├─ Organization name
   │  │  ├─ Course/cohort details (if specific)
   │  │  └─ "You've been invited to join"
   │  │
   │  └─ AUTH flow:
   │     ├─ OPTION 1: Google Sign-In
   │     │  ├─ CLICK "Sign in with Google"
   │     │  ├─ OAuth redirect
   │     │  ├─ RETURN with Google profile
   │     │  └─ VERIFY email matches invite email
   │     │
   │     └─ OPTION 2: Magic Link
   │        ├─ INPUT email (pre-filled from invite)
   │        ├─ SEND magic link email (Brevo)
   │        ├─ USER clicks magic link
   │        └─ VERIFY token, create session
   │
   ├─ ON successful auth:
   │  ├─ CHECK if user already exists:
   │  │  ├─ QUERY users: WHERE email = invite.email
   │  │  │
   │  │  ├─ IF exists:
   │  │  │  ├─ LINK to organization:
   │  │  │  │  ├─ UPDATE users SET organizationId = invite.organizationId
   │  │  │  │  └─ SHOW: "Your existing account has been linked to {org.name}"
   │  │  │  └─ SKIP profile creation
   │  │  │
   │  │  └─ ELSE (new user):
   │  │     ├─ CREATE user record:
   │  │     │  ├─ INSERT INTO users
   │  │     │  ├─ SET:
   │  │     │  │  ├─ email
   │  │     │  │  ├─ firstName, lastName (from invite or auth provider)
   │  │     │  │  ├─ authProvider ("google" or "magic_link")
   │  │     │  │  ├─ organizationId = invite.organizationId
   │  │     │  │  ├─ role = "user"
   │  │     │  │  └─ createdAt = NOW()
   │  │     │  └─ RETURN userId
   │  │     │
   │  │     └─ SHOW: "Welcome! Your account has been created"
   │  │
   │  ├─ UPDATE organizationInvite:
   │  │  ├─ SET status = "accepted"
   │  │  ├─ SET acceptedAt = NOW()
   │  │  └─ SET acceptedBy = userId
   │  │
   │  ├─ TRACK PostHog: "organization_invite_accepted"
   │  │  └─ Properties: inviteId, userId, organizationId
   │  │
   │  └─ REDIRECT to:
   │     ├─ IF invite has specific cohortId:
   │     │  └─ /courses/{courseSlug}/enroll (auto-enroll flow)
   │     └─ ELSE:
   │        └─ /dashboard (user can browse and enroll)
   │
   └─ EDGE CASES:
      ├─ Email mismatch (Google email != invite email)
      │  └─ ERROR: "Please sign in with {invite.email}"
      │
      ├─ User already linked to different organization
      │  └─ ERROR: "Your account is already linked to another organization"
      │
      └─ Invite accepted twice (concurrent clicks)
         └─ IDEMPOTENT: second accept shows "Already accepted"

7. ADMIN creates bulk enrollments:
   ├─ NAVIGATE to /admin/organizations/{organizationId}/enrollments
   │
   ├─ CLICK "Bulk Enroll"
   │
   ├─ ENROLLMENT FORM:
   │  ├─ SELECT cohort (required):
   │  │  ├─ FETCH cohorts:
   │  │  │  ├─ WHERE status IN ("open", "scheduled")
   │  │  │  └─ ORDER BY startDate ASC
   │  │  ├─ DISPLAY:
   │  │  │  ├─ Course name
   │  │  │  ├─ Cohort dates
   │  │  │  ├─ Enrollment count / capacity
   │  │  │  └─ Session type
   │  │  └─ VALIDATE: cohort has available capacity
   │  │
   │  ├─ SELECT team members (required):
   │  │  ├─ FETCH organization users:
   │  │  │  ├─ WHERE organizationId AND NOT already enrolled in selected cohort
   │  │  │  └─ ORDER BY lastName ASC
   │  │  │
   │  │  ├─ DISPLAY checklist:
   │  │  │  ├─ CHECKBOX for each user
   │  │  │  ├─ SHOW: name, email, invite status
   │  │  │  └─ FILTER: by accepted invites only (optional)
   │  │  │
   │  │  ├─ SELECT ALL / DESELECT ALL buttons
   │  │  │
   │  │  └─ VALIDATE:
   │  │     └─ selectedCount <= (org.seatsPurchased - org.seatsUsed)
   │  │
   │  ├─ PREVIEW:
   │  │  ├─ "Enrolling {count} users in {cohort.name}"
   │  │  ├─ "Seats remaining after: {seatsPurchased - seatsUsed - count}"
   │  │  └─ "No payment required (B2B)"
   │  │
   │  └─ BUTTONS: "Enroll All", "Cancel"
   │
   ├─ ON "Enroll All":
   │  ├─ FOR each selected user:
   │  │  ├─ CREATE enrollment record:
   │  │  │  ├─ INSERT INTO enrollments
   │  │  │  ├─ SET:
   │  │  │  │  ├─ userId
   │  │  │  │  ├─ cohortId
   │  │  │  │  ├─ organizationId
   │  │  │  │  ├─ paymentStatus = "b2b_paid" (no Stripe charge)
   │  │  │  │  ├─ enrolledAt = NOW()
   │  │  │  │  ├─ source = "b2b_bulk_admin"
   │  │  │  │  └─ completed = false
   │  │  │  └─ RETURN enrollmentId
   │  │  │
   │  │  ├─ SEND confirmation email (Brevo):
   │  │  │  ├─ Template: b2b_enrollment_confirmation
   │  │  │  ├─ TO: user.email
   │  │  │  ├─ Params:
   │  │  │  │  ├─ userName
   │  │  │  │  ├─ courseName
   │  │  │  │  ├─ cohortDates
   │  │  │  │  ├─ meetingLink (if available)
   │  │  │  │  └─ dashboardLink
   │  │  │  └─ CONTENT:
   │  │  │     ├─ "You've been enrolled in {course.name}"
   │  │  │     ├─ "Session details: {dates}"
   │  │  │     ├─ CTA: "View Course Dashboard"
   │  │  │     └─ "Access your enablement kit and prepare for the session"
   │  │  │
   │  │  └─ TRACK PostHog: "b2b_enrollment_created"
   │  │     └─ Properties: enrollmentId, userId, cohortId, organizationId
   │  │
   │  ├─ UPDATE organization:
   │  │  ├─ INCREMENT seatsUsed by enrollmentCount
   │  │  └─ VALIDATE: seatsUsed <= seatsPurchased
   │  │
   │  ├─ UPDATE cohort:
   │  │  └─ enrollmentCount (calculated field, refresh)
   │  │
   │  ├─ SHOW success: "{count} users enrolled successfully"
   │  │
   │  └─ DISPLAY updated enrollment list
   │
   └─ EDGE CASES:
      ├─ Cohort reaches capacity mid-enrollment
      │  ├─ PARTIAL enrollment
      │  ├─ SHOW: "Enrolled X users, Y failed (capacity)"
      │  └─ OFFER: Add to waitlist or select different cohort
      │
      ├─ User already enrolled (duplicate)
      │  └─ SKIP silently, LOG warning
      │
      └─ Seats exceed purchased amount
         └─ ERROR: "Not enough seats. Purchase more or reduce selection."

8. ADMIN manages B2B roster:
   ├─ NAVIGATE to /admin/organizations/{organizationId}
   │
   ├─ TABS:
   │  ├─ Overview
   │  ├─ Invites
   │  ├─ Enrollments
   │  └─ Billing
   │
   ├─ OVERVIEW tab:
   │  ├─ DISPLAY metrics:
   │  │  ├─ Seats purchased: {seatsPurchased}
   │  │  ├─ Seats used: {seatsUsed}
   │  │  ├─ Seats available: {seatsPurchased - seatsUsed}
   │  │  ├─ Invites sent: {inviteCount}
   │  │  ├─ Invites accepted: {acceptedInviteCount}
   │  │  └─ Enrollments: {enrollmentCount}
   │  │
   │  └─ QUICK ACTIONS:
   │     ├─ Send Invites
   │     ├─ Bulk Enroll
   │     └─ Purchase More Seats
   │
   ├─ INVITES tab:
   │  ├─ LIST all invites:
   │  │  ├─ Columns: email, name, status, sent date, expires date, actions
   │  │  ├─ FILTER by: status (pending, accepted, expired, bounced, revoked)
   │  │  └─ SEARCH by: email, name
   │  │
   │  └─ ACTIONS per invite:
   │     ├─ RESEND invite:
   │     │  ├─ REGENERATE inviteToken (optional)
   │     │  ├─ EXTEND expiresAt (+30 days)
   │     │  ├─ SEND new email
   │     │  └─ UPDATE status: "expired" → "pending"
   │     │
   │     └─ REVOKE invite:
   │        ├─ CONFIRM: "Revoke invite for {email}?"
   │        ├─ UPDATE status: → "revoked"
   │        ├─ DECREMENT seatsUsed (free up seat)
   │        └─ TRACK: "organization_invite_revoked"
   │
   ├─ ENROLLMENTS tab:
   │  ├─ LIST all enrollments:
   │  │  ├─ Columns: user, course, cohort, enrolled date, completed, actions
   │  │  ├─ FILTER by: course, cohort, completion status
   │  │  └─ SEARCH by: user name, email
   │  │
   │  └─ ACTIONS per enrollment:
   │     ├─ TRANSFER to different cohort:
   │     │  ├─ SELECT new cohort (same course)
   │     │  ├─ VALIDATE: new cohort has capacity
   │     │  ├─ UPDATE enrollment.cohortId
   │     │  ├─ SEND notification to user
   │     │  └─ TRACK: "enrollment_transferred"
   │     │
   │     └─ UNENROLL (refund seat):
   │        ├─ CONFIRM: "Remove {user.name} from {cohort.name}?"
   │        ├─ DELETE enrollment
   │        ├─ DECREMENT org.seatsUsed
   │        ├─ SEND notification to user
   │        └─ TRACK: "b2b_enrollment_removed"
   │
   └─ BILLING tab:
      ├─ LIST all invoices:
      │  ├─ Columns: invoice ID, amount, status, due date, paid date, actions
      │  └─ LINK to Stripe invoice
      │
      └─ ADD MORE SEATS:
         ├─ CLICK "Purchase More Seats"
         ├─ INPUT: additional seat count
         ├─ CALCULATE: new total and amount
         ├─ CREATE new Stripe invoice (repeat step 3)
         └─ UPDATE seatsPurchased after payment

EDGE CASES:

1. Team member already has B2C account:
   ├─ SCENARIO: User has personal account, now joining org
   │
   ├─ ON invite acceptance:
   │  ├─ DETECT existing user by email
   │  ├─ LINK existing account to organization:
   │  │  └─ UPDATE users SET organizationId = invite.organizationId
   │  │
   │  ├─ MERGE data:
   │  │  ├─ KEEP existing enrollments (personal)
   │  │  ├─ ADD organization enrollments
   │  │  └─ KEEP original createdAt (don't overwrite)
   │  │
   │  └─ NOTIFY user:
   │     └─ "Your account has been linked to {org.name}. Your previous enrollments are still available."
   │
   └─ BILLING:
      └─ NO refund for existing B2C enrollments (user keeps access)

2. Adding more seats (expansion):
   ├─ SCENARIO: Organization needs more seats mid-contract
   │
   ├─ PROCESS:
   │  ├─ CREATE new Stripe invoice (additional seats only)
   │  ├─ PAYMENT received → INCREMENT seatsPurchased
   │  ├─ SEND additional invites
   │  └─ TRACK: "organization_seats_added"
   │
   └─ PRICING:
      └─ Apply same discount tier as original purchase (or renegotiate)

3. Team member leaves organization:
   ├─ SCENARIO: Employee departs, seat should be freed
   │
   ├─ OPTION 1: Soft removal (recommended)
   │  ├─ UPDATE user:
   │  │  └─ SET organizationId = NULL (unlink)
   │  ├─ KEEP enrollments (already completed)
   │  ├─ FREE seat for new team member
   │  └─ User retains access to completed courses
   │
   └─ OPTION 2: Hard removal (rare)
      ├─ DELETE user account entirely
      ├─ DELETE all enrollments
      ├─ FREE seat
      └─ TRACK: "organization_user_removed"

4. Cohort rescheduling:
   ├─ SCENARIO: Cohort dates change after B2B enrollment
   │
   ├─ PROCESS:
   │  ├─ ADMIN updates cohort dates
   │  ├─ SEND notification to all enrolled users (Brevo mass email)
   │  │  └─ Template: cohort_rescheduled
   │  ├─ OFFER transfer to alternative cohort
   │  └─ TRACK: "cohort_rescheduled"
   │
   └─ IF users cannot attend new dates:
      └─ Transfer to different cohort (no additional charge)

5. Organization wants private cohort:
   ├─ SCENARIO: Org wants exclusive session, no other enrollees
   │
   ├─ SETUP:
   │  ├─ CREATE cohort with isB2B = true
   │  ├─ SET organizationId on cohort (exclusive)
   │  ├─ HIDE from public catalog
   │  └─ ONLY allow org members to enroll
   │
   └─ PRICING:
      └─ ADD private cohort fee ($2000) to invoice

6. Invoice not paid after 30 days:
   ├─ SCENARIO: Organization hasn't paid, invites sent
   │
   ├─ ACTIONS:
   │  ├─ AUTOMATED reminder emails (Stripe handles)
   │  ├─ ADMIN follow-up (manual)
   │  ├─ IF still unpaid after 60 days:
   │  │  ├─ UPDATE org.status → "suspended"
   │  │  ├─ REVOKE all pending invites
   │  │  └─ BLOCK new enrollments
   │  │
   │  └─ IF paid later:
   │     ├─ UPDATE status → "active"
   │     └─ RESEND invites
   │
   └─ EXISTING ENROLLMENTS:
      └─ ALLOW completion (don't disrupt active learners)

VALIDATION RULES:
├─ Cannot send invites if org.status != "active"
├─ Cannot enroll if seatsUsed >= seatsPurchased
├─ Cannot revoke invite after it's accepted (must unenroll instead)
├─ Cannot delete organization with active enrollments
└─ Invite email must be unique per organization

NOTIFICATIONS:
├─ Invoice created → Contact email (via Stripe)
├─ Payment received → Admin alert (webhook)
├─ Invite sent → Team member email
├─ Invite accepted → Admin notification (optional)
├─ Enrollment created → User confirmation email
└─ Seat limit approaching → Admin warning (at 80%)

PERMISSIONS:
├─ CREATE organization: admin only
├─ SEND invites: admin only
├─ BULK enroll: admin only
├─ VIEW organization roster: admin only
└─ ACCEPT invite: invited user only (via token)
```

---

## 2.2.4 Waitlist Management Flow

```
FLOW: WAITLIST_MANAGEMENT

CONTEXT:
  Waitlists activate when cohorts reach maxCapacity.
  Users join a queue and receive offers when spots open.
  Offers expire after 48 hours, moving to next in line.

1. USER joins waitlist:
   ├─ CONTEXT: User attempts to enroll in full cohort
   │  └─ Cohort: status = "open", enrollmentCount >= maxCapacity
   │
   ├─ NAVIGATE to /courses/{courseSlug}
   │
   ├─ DISPLAY cohort card:
   │  ├─ IF enrollmentCount < maxCapacity:
   │  │  └─ SHOW "Enroll Now" button (normal flow)
   │  │
   │  └─ ELSE (cohort full):
   │     ├─ HIDE "Enroll Now"
   │     ├─ SHOW "Cohort Full"
   │     └─ IF cohort.enableWaitlist = true:
   │        └─ SHOW "Join Waitlist" button
   │
   ├─ USER clicks "Join Waitlist"
   │
   ├─ VERIFY user authentication:
   │  ├─ IF not logged in:
   │  │  ├─ REDIRECT to /auth/signin
   │  │  └─ RETURN to cohort page after signin
   │  │
   │  └─ IF logged in: proceed
   │
   ├─ CHECK existing waitlist entry:
   │  ├─ QUERY waitlistEntries: WHERE userId AND cohortId
   │  │
   │  ├─ IF found:
   │  │  └─ SHOW: "You're already on the waitlist at position {position}"
   │  │
   │  └─ ELSE: proceed to add
   │
   ├─ CALCULATE position:
   │  ├─ QUERY: SELECT MAX(position) FROM waitlistEntries WHERE cohortId
   │  └─ newPosition = maxPosition + 1
   │
   ├─ CREATE waitlistEntry record:
   │  ├─ INSERT INTO waitlistEntries
   │  ├─ SET:
   │  │  ├─ userId
   │  │  ├─ cohortId
   │  │  ├─ position = newPosition
   │  │  ├─ status = "waiting"
   │  │  ├─ joinedAt = NOW()
   │  │  └─ offerExpiresAt = NULL
   │  └─ RETURN entryId
   │
   ├─ SEND confirmation email (Brevo):
   │  ├─ Template: waitlist_joined
   │  ├─ TO: user.email
   │  ├─ Params:
   │  │  ├─ userName
   │  │  ├─ courseName
   │  │  ├─ cohortDates
   │  │  ├─ position
   │  │  └─ totalWaiting (count of all "waiting")
   │  │
   │  └─ CONTENT:
   │     ├─ "You're on the waitlist for {course.name}"
   │     ├─ "Your position: #{position}"
   │     ├─ "We'll email you if a spot opens"
   │     └─ "You can cancel anytime from your dashboard"
   │
   ├─ TRACK PostHog: "waitlist_joined"
   │  └─ Properties: entryId, cohortId, userId, position
   │
   └─ SHOW confirmation:
      ├─ "You've been added to the waitlist!"
      ├─ "Position: #{position}"
      └─ "We'll notify you if a spot becomes available"

2. SPOT opens (trigger scenarios):
   ├─ SCENARIO 1: User refunds enrollment
   │  ├─ ENROLLMENT deleted or paymentStatus → "refunded"
   │  ├─ DECREMENT cohort.enrollmentCount
   │  └─ IF enrollmentCount < maxCapacity: TRIGGER next in waitlist
   │
   ├─ SCENARIO 2: User transfers to different cohort
   │  ├─ ENROLLMENT.cohortId updated
   │  ├─ DECREMENT old cohort.enrollmentCount
   │  └─ IF enrollmentCount < maxCapacity: TRIGGER next in waitlist
   │
   └─ SCENARIO 3: Admin increases capacity
      ├─ COHORT.maxCapacity increased
      ├─ CALCULATE available spots: maxCapacity - enrollmentCount
      └─ IF availableSpots > 0: TRIGGER next in waitlist
   │
   ├─ QUERY next in line:
   │  ├─ SELECT * FROM waitlistEntries
   │  ├─ WHERE cohortId = {cohortId}
   │  ├─ AND status = "waiting"
   │  ├─ ORDER BY position ASC
   │  ├─ LIMIT 1
   │  └─ RETURN waitlistEntry (or NULL if none)
   │
   └─ IF waitlistEntry found:
      └─ PROCEED to step 3 (send offer)

3. SYSTEM sends offer:
   ├─ UPDATE waitlistEntry:
   │  ├─ SET status = "offered"
   │  ├─ SET offeredAt = NOW()
   │  └─ SET offerExpiresAt = NOW() + 48 hours
   │
   ├─ GENERATE checkout link:
   │  ├─ CREATE temporary checkoutSession:
   │  │  ├─ userId
   │  │  ├─ cohortId
   │  │  ├─ source = "waitlist"
   │  │  ├─ expiresAt = offerExpiresAt
   │  │  └─ token = crypto.randomUUID()
   │  │
   │  └─ URL: /checkout/{token}
   │     └─ Pre-filled with cohort details, skips cohort selection
   │
   ├─ SEND offer email (Brevo):
   │  ├─ Template: waitlist_offer
   │  ├─ TO: user.email
   │  ├─ Params:
   │  │  ├─ userName
   │  │  ├─ courseName
   │  │  ├─ cohortDates
   │  │  ├─ price
   │  │  ├─ checkoutLink
   │  │  └─ expiryTime (formatted: "48 hours from now")
   │  │
   │  └─ CONTENT:
   │     ├─ "Great news! A spot opened in {course.name}"
   │     ├─ "You have 48 hours to claim your spot"
   │     ├─ CTA: "Claim Your Spot" (checkout link)
   │     └─ "If you don't complete payment by {expiryTime}, the spot will go to the next person"
   │
   ├─ SEND reminder email (24h before expiry):
   │  ├─ SCHEDULE job: offerExpiresAt - 24 hours
   │  ├─ ONLY IF status still "offered"
   │  └─ Content: "Your spot reservation expires in 24 hours!"
   │
   ├─ TRACK PostHog: "waitlist_offer_sent"
   │  └─ Properties: entryId, cohortId, userId, expiresAt
   │
   └─ EDGE CASES:
      ├─ User doesn't receive email
      │  └─ SHOW offer in dashboard: /dashboard/waitlist-offers
      │
      └─ Multiple spots open simultaneously
         ├─ SEND offers to top N users in queue
         └─ UPDATE all to "offered" with same expiry

4. USER accepts offer (within 48h):
   ├─ USER clicks checkout link in email
   │  └─ URL: /checkout/{token}
   │
   ├─ VALIDATE checkoutSession token:
   │  ├─ QUERY checkoutSessions: WHERE token
   │  │
   │  ├─ IF not found:
   │  │  └─ ERROR: "Invalid checkout link"
   │  │
   │  ├─ IF expiresAt < NOW():
   │  │  └─ ERROR: "This offer has expired"
   │  │
   │  └─ IF valid: proceed
   │
   ├─ DISPLAY checkout page:
   │  ├─ SHOW cohort details (pre-filled, read-only)
   │  ├─ SHOW price
   │  ├─ SHOW countdown timer: "Time remaining: {hours}:{minutes}"
   │  └─ PAYMENT FORM (Stripe Checkout)
   │
   ├─ USER completes payment:
   │  ├─ STRIPE processes payment
   │  ├─ RETURN paymentIntentId
   │  └─ WEBHOOK: payment_intent.succeeded
   │
   ├─ WEBHOOK handler:
   │  ├─ EXTRACT:
   │  │  ├─ paymentIntentId
   │  │  ├─ userId (from metadata)
   │  │  ├─ cohortId (from metadata)
   │  │  └─ amount paid
   │  │
   │  ├─ CREATE enrollment:
   │  │  ├─ INSERT INTO enrollments
   │  │  ├─ SET:
   │  │  │  ├─ userId
   │  │  │  ├─ cohortId
   │  │  │  ├─ paymentStatus = "paid"
   │  │  │  ├─ stripePaymentIntentId
   │  │  │  ├─ amount
   │  │  │  ├─ source = "waitlist"
   │  │  │  ├─ enrolledAt = NOW()
   │  │  │  └─ completed = false
   │  │  └─ RETURN enrollmentId
   │  │
   │  ├─ UPDATE waitlistEntry:
   │  │  ├─ SET status = "enrolled"
   │  │  └─ SET enrolledAt = NOW()
   │  │
   │  ├─ INCREMENT cohort.enrollmentCount
   │  │
   │  ├─ SEND enrollment confirmation (Brevo):
   │  │  └─ Template: enrollment_confirmation (same as normal enrollment)
   │  │
   │  ├─ TRACK PostHog: "waitlist_offer_accepted"
   │  │  └─ Properties: entryId, enrollmentId, cohortId, userId, timeToAccept
   │  │
   │  └─ DELETE checkoutSession (no longer needed)
   │
   └─ EDGE CASES:
      ├─ Payment fails
      │  ├─ KEEP offer active (don't expire immediately)
      │  ├─ ALLOW retry
      │  └─ IF still fails after 48h: expire as normal
      │
      └─ Cohort fills before payment completes
         ├─ RARE (race condition)
         ├─ REFUND payment
         └─ RETURN to waitlist at original position

5. OFFER expires (no action taken):
   ├─ CRON job runs every 15 minutes:
   │  └─ CHECK waitlistEntries:
   │     ├─ WHERE status = "offered"
   │     └─ AND offerExpiresAt < NOW()
   │
   ├─ FOR each expired offer:
   │  ├─ UPDATE waitlistEntry:
   │  │  ├─ SET status = "expired"
   │  │  └─ SET expiredAt = NOW()
   │  │
   │  ├─ SEND expiry notification (Brevo):
   │  │  ├─ Template: waitlist_offer_expired
   │  │  ├─ TO: user.email
   │  │  └─ CONTENT:
   │  │     ├─ "Your spot reservation has expired"
   │  │     ├─ "You're back on the waitlist at position {position}"
   │  │     └─ "We'll notify you if another spot opens"
   │  │
   │  ├─ TRACK PostHog: "waitlist_offer_expired"
   │  │  └─ Properties: entryId, cohortId, userId
   │  │
   │  └─ TRIGGER next in queue:
   │     └─ RETURN to step 2 (find next waiting)
   │
   └─ EDGE CASES:
      ├─ User claims spot 1 minute before expiry
      │  └─ CANCEL expiry job if payment processing
      │
      └─ All waitlist users expire
         └─ Spot remains open for normal enrollment

6. USER cancels waitlist:
   ├─ NAVIGATE to /dashboard
   │
   ├─ VIEW waitlist section:
   │  ├─ LIST all active waitlist entries
   │  ├─ SHOW: course, cohort, position, status
   │  └─ BUTTON: "Leave Waitlist" per entry
   │
   ├─ USER clicks "Leave Waitlist"
   │
   ├─ CONFIRM modal:
   │  ├─ "Are you sure you want to leave the waitlist for {course.name}?"
   │  └─ Buttons: "Yes, Leave", "Cancel"
   │
   ├─ ON confirm:
   │  ├─ UPDATE waitlistEntry:
   │  │  ├─ SET status = "cancelled"
   │  │  └─ SET cancelledAt = NOW()
   │  │
   │  ├─ RECALCULATE positions for remaining:
   │  │  ├─ GET all entries WHERE cohortId AND status = "waiting"
   │  │  ├─ ORDER BY position ASC
   │  │  └─ FOR each (index i):
   │  │     └─ UPDATE position = i + 1
   │  │
   │  ├─ SEND cancellation confirmation (Brevo):
   │  │  └─ Template: waitlist_cancelled
   │  │
   │  ├─ TRACK PostHog: "waitlist_cancelled"
   │  │  └─ Properties: entryId, cohortId, userId, previousPosition
   │  │
   │  └─ SHOW success: "You've been removed from the waitlist"
   │
   └─ EDGE CASES:
      ├─ User cancels while offer is active
      │  ├─ ALLOW cancellation
      │  ├─ INVALIDATE checkout session
      │  └─ MOVE to next in queue
      │
      └─ User rejoins after cancelling
         └─ CREATE new entry at end of queue (no position preservation)

ADDITIONAL FLOWS:

7. ADMIN manually moves user up in queue:
   ├─ NAVIGATE to /admin/cohorts/{cohortId}/waitlist
   │
   ├─ VIEW waitlist table:
   │  ├─ Columns: user, position, status, joined date, actions
   │  └─ SORT by position ASC
   │
   ├─ CLICK "Move Up" on user row
   │
   ├─ SWAP positions:
   │  ├─ currentPosition = user.position
   │  ├─ newPosition = currentPosition - 1
   │  │
   │  ├─ FIND user at newPosition
   │  ├─ SWAP their positions
   │  │  ├─ UPDATE waitlistEntries SET position = currentPosition WHERE position = newPosition
   │  │  └─ UPDATE waitlistEntries SET position = newPosition WHERE userId = selectedUserId
   │  │
   │  └─ TRACK: "waitlist_position_adjusted"
   │
   └─ ALTERNATIVE: "Move to Top" button
      ├─ SET user.position = 1
      └─ INCREMENT all other positions

8. BULK waitlist offers (admin override):
   ├─ SCENARIO: Admin increases capacity by 10 spots
   │
   ├─ NAVIGATE to /admin/cohorts/{cohortId}
   │
   ├─ UPDATE maxCapacity:
   │  ├─ INPUT new capacity (old + 10)
   │  └─ SAVE
   │
   ├─ TRIGGER automatic offers:
   │  ├─ CALCULATE available: maxCapacity - enrollmentCount = 10
   │  ├─ QUERY top 10 from waitlist
   │  └─ FOR each:
   │     └─ SEND offer (step 3)
   │
   └─ SHOW admin notification:
      └─ "10 waitlist offers sent"

9. WAITLIST notifications (position updates):
   ├─ OPTIONAL FEATURE (nice-to-have)
   │
   ├─ WHEN user moves up in queue:
   │  ├─ SEND email: "You've moved to position #{newPosition}"
   │  └─ ONLY if moved up by >= 5 positions
   │
   └─ WHEN user is close to top:
      ├─ SEND email: "You're #{position} in line!"
      └─ ONLY if position <= 3

VALIDATION RULES:
├─ Cannot join waitlist if already enrolled in cohort
├─ Cannot join waitlist if cohort status = "cancelled" or "completed"
├─ Cannot join waitlist if cohort.enableWaitlist = false
├─ Cannot send offer if cohort is full (enrollmentCount >= maxCapacity)
├─ Position must be unique per cohort
└─ Offer expiry must be in the future

CRON JOBS:
├─ Every 15 minutes: Check for expired offers
├─ Daily: Send reminder emails (24h before expiry)
└─ Hourly: Recalculate positions (fix gaps from cancellations)

NOTIFICATIONS:
├─ Join waitlist → Confirmation email
├─ Offer sent → Urgent email with CTA
├─ Offer expires in 24h → Reminder email
├─ Offer expired → Notification email
├─ Enrolled from waitlist → Confirmation email
├─ Cancelled waitlist → Confirmation email
└─ Position update → Optional notification (if enabled)

PERMISSIONS:
├─ JOIN waitlist: authenticated users only
├─ LEAVE waitlist: user (their own entry)
├─ VIEW waitlist: admin only (full list)
├─ SEND offers: automated system (or admin manual trigger)
└─ ADJUST positions: admin only

ANALYTICS & TRACKING:
├─ Waitlist join rate per cohort
├─ Offer acceptance rate (enrolled / offered)
├─ Average time to accept offer
├─ Expiry rate (expired / offered)
├─ Waitlist dropout rate (cancelled / joined)
└─ Conversion rate (waitlist → enrollment)
```

---

## Summary

These four admin flows cover:
1. **Cohort Management** - Complete lifecycle from creation to completion, supporting multiple session types (cohort, webinar, hackathon)
2. **Enablement Kit Management** - File uploads, external links, drag-drop reordering, and immediate user availability
3. **B2B Manual Enrollment** - Offline sales, manual invoicing, team invites, bulk enrollments, and roster management
4. **Waitlist Management** - Queue management, automated offers, expiry handling, and position tracking

Each flow includes:
- Detailed step-by-step pseudocode
- Edge case handling
- Validation rules
- Notifications
- PostHog tracking
- Permission requirements
