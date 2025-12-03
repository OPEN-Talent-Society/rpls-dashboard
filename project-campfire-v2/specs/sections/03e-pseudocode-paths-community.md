# Learning Paths & Community Flows - Pseudocode

## 3.1 Learning Paths Flows

### 3.1.1 Enroll in Learning Path

```pseudocode
FUNCTION EnrollInLearningPath(userId, pathId, paymentType):
  // Validate path availability
  path = FETCH learningPath(pathId)
  IF path.isActive == false:
    THROW PathNotAvailableError("This learning path is not available")

  // Check existing enrollment
  existing = FETCH userPathEnrollments(userId, pathId)
  IF existing EXISTS:
    IF existing.status == "active":
      THROW AlreadyEnrolledError("Already enrolled in this path")
    ELSE IF existing.status == "paused":
      SHOW modal "Resume your existing enrollment?"
      IF user.confirms:
        UPDATE existing.status = "active"
        UPDATE existing.resumedAt = now()
        RETURN existing

  // Pricing logic
  IF paymentType == "b2c":
    price = path.priceB2C
    IF price > 0:
      // Stripe checkout
      TRANSACTION atomicPathPurchase:
        stripe_session = CREATE stripe.checkout.session(
          line_items: [{
            price: path.stripe_price_id,
            quantity: 1
          }],
          metadata: {
            path_id: pathId,
            user_id: userId,
            type: "learning_path"
          }
        )
        REDIRECT to stripe_session.url

      // Webhook: payment.success
      WHEN webhook.event == "checkout.session.completed":
        enrollment = CREATE userPathEnrollment(
          userId, pathId,
          status: "active",
          enrolledAt: now(),
          estimatedCompletion: now() + path.estimatedDuration,
          paymentIntentId: stripe_session.payment_intent
        )
    ELSE:
      // Free path
      enrollment = CREATE userPathEnrollment(
        userId, pathId,
        status: "active",
        enrolledAt: now(),
        estimatedCompletion: now() + path.estimatedDuration
      )

  ELSE IF paymentType == "b2b":
    // Organization seat allocation
    user = FETCH user(userId)
    org = FETCH organization(user.organizationId)

    IF org.seatsUsed >= org.seatsPurchased:
      THROW InsufficientSeatsError("Organization has no available seats")

    enrollment = CREATE userPathEnrollment(
      userId, pathId,
      status: "active",
      enrolledAt: now(),
      organizationId: org._id,
      estimatedCompletion: now() + path.estimatedDuration
    )
    INCREMENT org.seatsUsed

  // Initialize first step
  firstStep = FETCH learningPathSteps
    WHERE pathId == path._id
    AND stepNumber == 1

  UPDATE enrollment:
    currentStepId = firstStep._id
    stepsCompleted = 0

  // Send welcome email
  SEND email via Brevo:
    template: "learning_path_enrolled"
    variables: {
      path_title: path.title,
      estimated_duration: path.estimatedDuration,
      first_course: firstStep.courseId.title,
      dashboard_url: "/dashboard/paths/" + pathId
    }

  // Create progress tracker
  steps = FETCH all learningPathSteps WHERE pathId == path._id
  FOR EACH step IN steps:
    CREATE userPathProgress(
      enrollmentId: enrollment._id,
      stepId: step._id,
      status: step.stepNumber == 1 ? "unlocked" : "locked"
    )

  RETURN enrollment
```

---

### 3.1.2 Track Path Progress

```pseudocode
FUNCTION TrackPathProgress(userId, pathId):
  enrollment = FETCH userPathEnrollments(userId, pathId)
  IF NOT enrollment:
    THROW NotFoundError("Path enrollment not found")

  // Get all steps in path
  steps = FETCH learningPathSteps
    WHERE pathId == pathId
    ORDER BY stepNumber ASC

  // Get progress for each step
  progress = []
  FOR EACH step IN steps:
    stepProgress = FETCH userPathProgress
      WHERE enrollmentId == enrollment._id
      AND stepId == step._id

    course = FETCH course(step.courseId)

    // Check course completion
    courseEnrollment = FETCH enrollments
      WHERE userId == userId
      AND courseId == step.courseId

    isCompleted = false
    IF courseEnrollment EXISTS:
      cohort = FETCH cohort(courseEnrollment.cohortId)
      IF cohort.status == "completed":
        isCompleted = true

    // Check unlock status
    isUnlocked = CheckStepUnlockStatus(step, enrollment, stepProgress)

    progress.push({
      step: step,
      course: course,
      status: stepProgress.status,
      isCompleted: isCompleted,
      isUnlocked: isUnlocked,
      completedAt: courseEnrollment?.completedAt,
      nextAction: DetermineNextAction(step, isUnlocked, isCompleted)
    })

  // Calculate overall progress
  totalSteps = steps.length
  completedSteps = COUNT(progress WHERE isCompleted == true)
  progressPercentage = (completedSteps / totalSteps) * 100

  UPDATE enrollment:
    stepsCompleted = completedSteps,
    progressPercentage = progressPercentage

  // Display progress dashboard
  DISPLAY path_progress_dashboard:
    path: FETCH learningPath(pathId),
    enrollment: enrollment,
    steps: progress,
    overallProgress: progressPercentage,
    estimatedTimeRemaining: CalculateTimeRemaining(enrollment, progress),
    nextRecommendation: GetNextRecommendation(progress)

  RETURN progress
```

---

### 3.1.3 Unlock Next Course (Sequential/Time-Based)

```pseudocode
FUNCTION UnlockNextCourse(enrollmentId, completedStepId):
  enrollment = FETCH userPathEnrollment(enrollmentId)
  completedStep = FETCH learningPathStep(completedStepId)

  // Mark current step as completed
  stepProgress = FETCH userPathProgress
    WHERE enrollmentId == enrollmentId
    AND stepId == completedStepId

  UPDATE stepProgress:
    status = "completed",
    completedAt = now()

  INCREMENT enrollment.stepsCompleted

  // Find next step
  nextStep = FETCH learningPathStep
    WHERE pathId == completedStep.pathId
    AND stepNumber == completedStep.stepNumber + 1

  IF NOT nextStep:
    // This was the last step
    CompletePathAndIssueCertificate(enrollmentId)
    RETURN null

  nextStepProgress = FETCH userPathProgress
    WHERE enrollmentId == enrollmentId
    AND stepId == nextStep._id

  // Apply unlock rules
  IF nextStep.unlockRule == "immediate":
    UPDATE nextStepProgress.status = "unlocked"

  ELSE IF nextStep.unlockRule == "sequential":
    // Unlock if previous step is completed
    IF stepProgress.status == "completed":
      UPDATE nextStepProgress.status = "unlocked"
      SEND email via Brevo:
        template: "path_step_unlocked"
        variables: {
          step_number: nextStep.stepNumber,
          course_title: nextStep.courseId.title,
          unlock_url: "/dashboard/paths/" + enrollment.pathId
        }

  ELSE IF nextStep.unlockRule == "after_days":
    // Schedule unlock after delay
    unlockDate = enrollment.enrolledAt + (nextStep.unlockAfterDays * 86400)
    IF now() >= unlockDate:
      UPDATE nextStepProgress.status = "unlocked"
      SEND email via Brevo:
        template: "path_step_unlocked"
    ELSE:
      SCHEDULE unlock_task AT unlockDate:
        UPDATE nextStepProgress.status = "unlocked"
        SEND notification email

  ELSE IF nextStep.unlockRule == "after_completion":
    // Unlock after specific step completes
    requiredProgress = FETCH userPathProgress
      WHERE enrollmentId == enrollmentId
      AND stepId == nextStep.unlockAfterStepId

    IF requiredProgress.status == "completed":
      UPDATE nextStepProgress.status = "unlocked"
      SEND email via Brevo:
        template: "path_step_unlocked"

  // Update current step pointer
  IF nextStepProgress.status == "unlocked":
    UPDATE enrollment.currentStepId = nextStep._id

  RETURN nextStep
```

---

### 3.1.4 Complete Path & Issue Certificate

```pseudocode
FUNCTION CompletePathAndIssueCertificate(enrollmentId):
  enrollment = FETCH userPathEnrollment(enrollmentId)
  path = FETCH learningPath(enrollment.pathId)
  user = FETCH user(enrollment.userId)

  // Validate completion criteria
  steps = FETCH learningPathSteps WHERE pathId == path._id
  progress = FETCH userPathProgress WHERE enrollmentId == enrollmentId

  totalRequired = COUNT(steps WHERE isRequired == true)
  completedRequired = COUNT(progress
    WHERE stepId IN (required steps)
    AND status == "completed"
  )

  IF completedRequired < totalRequired:
    THROW IncompletionError("Path requirements not met")

  // Update enrollment status
  UPDATE enrollment:
    status = "completed",
    completedAt = now(),
    progressPercentage = 100

  // Generate certificate number
  certificateNumber = GENERATE unique_id:
    format: "PATH-" + YEAR + "-" + PADDED_ID(6)

  // Aggregate skills achieved
  skillsAchieved = []
  FOR EACH step IN steps:
    IF step.isRequired OR progress[step._id].status == "completed":
      course = FETCH course(step.courseId)
      FOR EACH skill IN course.skills:
        IF NOT skillsAchieved.includes(skill):
          skillsAchieved.push({
            skillId: skill._id,
            achievedAt: progress[step._id].completedAt,
            courseId: course._id
          })

  // Generate Open Badge 3.0
  badge = GENERATE open_badge_3_0:
    "@context": "https://w3id.org/openbadges/v3",
    type: "Achievement",
    id: "https://aienablement.academy/badges/" + certificateNumber,
    name: path.title + " Learning Path",
    description: path.description,
    criteria: {
      narrative: "Completed all required courses in " + path.title
    },
    issuer: {
      id: "https://aienablement.academy",
      type: "Profile",
      name: "AI Enablement Academy"
    },
    recipient: {
      type: "email",
      identity: "sha256$" + HASH(user.email)
    },
    issuedOn: now()

  // Generate badge image
  badgeImage = GENERATE badge_png:
    template: "learning_path_badge.png",
    data: {
      path_title: path.title,
      recipient_name: user.name,
      issued_date: FORMAT_DATE(now()),
      certificate_number: certificateNumber
    }

  badgeImageId = UPLOAD to Convex storage: badgeImage

  // Generate certificate PDF
  certificatePdf = GENERATE certificate_pdf:
    template: "learning_path_certificate.pdf",
    data: {
      path_title: path.title,
      recipient_name: user.name,
      issued_date: FORMAT_DATE(now()),
      certificate_number: certificateNumber,
      skills_achieved: skillsAchieved.map(s => s.name),
      total_courses: steps.length,
      total_hours: SUM(steps.map(s => s.course.durationHours)),
      verification_url: badge.id,
      qr_code: GENERATE_QR(badge.id)
    }

  pdfId = UPLOAD to Convex storage: certificatePdf

  // Store certificate
  certificate = CREATE pathCertificate:
    userId: enrollment.userId,
    pathId: enrollment.pathId,
    enrollmentId: enrollmentId,
    certificateNumber: certificateNumber,
    issuedAt: now(),
    skillsAchieved: skillsAchieved,
    badgeData: badge,
    verificationUrl: badge.id,
    badgeImageId: badgeImageId,
    pdfId: pdfId,
    linkedInShareUrl: GenerateLinkedInShareUrl(badge),
    twitterShareUrl: GenerateTwitterShareUrl(badge)

  // Send certificate email
  SEND email via Brevo:
    template: "learning_path_certificate"
    variables: {
      path_title: path.title,
      certificate_url: badge.id,
      pdf_download_url: GeneratePdfDownloadToken(certificate._id),
      share_links: {
        linkedin: certificate.linkedInShareUrl,
        twitter: certificate.twitterShareUrl
      }
    }

  // Trigger celebration UI
  PUSH notification:
    type: "certificate_earned",
    title: "Congratulations!",
    body: "You've completed " + path.title,
    action_url: "/certificates/" + certificate._id

  RETURN certificate
```

---

### 3.1.5 Purchase Path Bundle

```pseudocode
FUNCTION PurchasePathBundle(userId, pathId):
  path = FETCH learningPath(pathId)
  user = FETCH user(userId)

  // Calculate bundle pricing
  steps = FETCH learningPathSteps WHERE pathId == pathId
  courses = FETCH courses WHERE _id IN steps.map(s => s.courseId)

  individualTotal = SUM(courses.map(c => c.priceB2C))
  bundlePrice = path.priceB2C // Discounted bundle price
  savingsAmount = individualTotal - bundlePrice
  savingsPercentage = (savingsAmount / individualTotal) * 100

  // Display bundle offer
  DISPLAY bundle_purchase_modal:
    path: path,
    bundlePrice: bundlePrice,
    individualTotal: individualTotal,
    savings: savingsAmount,
    savingsPercentage: savingsPercentage,
    coursesIncluded: courses,
    estimatedDuration: path.estimatedDuration

  // Bundle checkout
  WHEN user.clicks(PurchaseBundle):
    TRANSACTION atomicBundlePurchase:
      TRY:
        // Create Stripe checkout
        stripe_session = CREATE stripe.checkout.session(
          line_items: [{
            price: path.stripe_price_id,
            quantity: 1
          }],
          metadata: {
            path_id: pathId,
            user_id: userId,
            bundle_type: "learning_path",
            courses_included: JSON.stringify(courses.map(c => c._id))
          },
          discounts: path.discountCode ? [{ coupon: path.discountCode }] : []
        )

        REDIRECT to stripe_session.url

      CATCH stripe.PaymentError:
        SHOW "Payment failed, please try again"
        LOG error for support
        RETURN

    // Webhook: payment.success
    WHEN webhook.event == "checkout.session.completed":
      // Create path enrollment
      enrollment = CREATE userPathEnrollment:
        userId: userId,
        pathId: pathId,
        status: "active",
        enrolledAt: now(),
        paymentIntentId: stripe_session.payment_intent,
        estimatedCompletion: now() + path.estimatedDuration,
        stepsCompleted: 0,
        progressPercentage: 0

      // Initialize progress for all steps
      FOR EACH step IN steps:
        CREATE userPathProgress:
          enrollmentId: enrollment._id,
          stepId: step._id,
          status: step.unlockRule == "immediate" ? "unlocked" : "locked"

      // Set current step
      firstStep = steps[0]
      UPDATE enrollment.currentStepId = firstStep._id

      // Send confirmation email
      SEND email via Brevo:
        template: "path_bundle_purchased"
        variables: {
          path_title: path.title,
          amount_paid: bundlePrice / 100,
          amount_saved: savingsAmount / 100,
          courses_count: courses.length,
          dashboard_url: "/dashboard/paths/" + pathId,
          first_course: courses[0].title
        }

      // Show success page
      DISPLAY success_page:
        message: "Welcome to " + path.title + "!",
        savings: "You saved $" + (savingsAmount / 100),
        next_steps: [
          "Start with: " + courses[0].title,
          "Track your progress in the dashboard",
          "Unlock courses as you complete each step"
        ]

      RETURN enrollment
```

---

## 3.2 Community Flows

### 3.2.1 Create Discussion Thread

```pseudocode
FUNCTION CreateDiscussionThread(userId, threadData):
  user = FETCH user(userId)

  // Validate access
  IF threadData.scope == "course":
    courseEnrollment = FETCH enrollments
      WHERE userId == userId
      AND courseId == threadData.courseId
    IF NOT courseEnrollment:
      THROW AccessDeniedError("Must be enrolled to post in course discussions")

  ELSE IF threadData.scope == "session":
    sessionEnrollment = FETCH enrollments
      WHERE userId == userId
      AND cohortId.sessionId == threadData.sessionId
    IF NOT sessionEnrollment:
      THROW AccessDeniedError("Must be enrolled in this cohort to post")

  // Spam prevention
  recentThreads = FETCH discussionThreads
    WHERE authorId == userId
    AND createdAt > now() - 300 // Last 5 minutes

  IF recentThreads.length >= 3:
    THROW RateLimitError("Please wait before creating another thread")

  // Content moderation (basic)
  FUNCTION ContainsSpam(content) -> Boolean:
    spamKeywords = ["buy now", "click here", "limited offer", "http://bit.ly"]
    FOR EACH keyword IN spamKeywords:
      IF content.toLowerCase().includes(keyword):
        RETURN true
    RETURN false

  IF ContainsSpam(threadData.title) OR ContainsSpam(threadData.content):
    THROW ModerationError("Content flagged for review")

  // Create thread
  thread = CREATE discussionThread:
    title: threadData.title,
    content: threadData.content,
    authorId: userId,
    scope: threadData.scope,
    courseId: threadData.courseId,
    sessionId: threadData.sessionId,
    lessonId: threadData.lessonId,
    isPinned: false,
    isAnnouncement: false,
    isLocked: false,
    category: threadData.category, // "question", "discussion", "show-and-tell"
    tags: threadData.tags || [],
    replyCount: 0,
    likeCount: 0,
    viewCount: 0,
    lastActivityAt: now(),
    status: "active",
    createdAt: now(),
    updatedAt: now()

  // Subscribe author to notifications
  CREATE threadSubscription:
    userId: userId,
    threadId: thread._id,
    subscribedAt: now()

  // Notify instructors (if course/session thread)
  IF threadData.scope IN ["course", "session"]:
    instructors = FETCH users
      WHERE role == "instructor"
      AND (assignedCourses INCLUDES threadData.courseId)

    FOR EACH instructor IN instructors:
      SEND notification:
        userId: instructor._id,
        type: "new_thread",
        title: "New " + threadData.category + " in " + threadData.courseId.title,
        body: threadData.title,
        action_url: "/community/threads/" + thread._id

  RETURN thread
```

---

### 3.2.2 Reply to Thread

```pseudocode
FUNCTION ReplyToThread(userId, threadId, replyData):
  thread = FETCH discussionThread(threadId)
  user = FETCH user(userId)

  // Check thread status
  IF thread.status == "hidden":
    THROW NotFoundError("Thread not found")
  IF thread.isLocked:
    THROW LockedError("This thread is locked")

  // Validate access (same as CreateThread)
  IF thread.scope == "course":
    enrollment = FETCH enrollments
      WHERE userId == userId AND courseId == thread.courseId
    IF NOT enrollment:
      THROW AccessDeniedError("Must be enrolled to reply")

  // Check if user is instructor
  isInstructor = false
  IF user.role == "instructor":
    course = FETCH course(thread.courseId)
    IF course.instructorId == userId:
      isInstructor = true

  // Rate limiting
  recentReplies = FETCH discussionReplies
    WHERE authorId == userId
    AND createdAt > now() - 60 // Last 1 minute

  IF recentReplies.length >= 5:
    THROW RateLimitError("Slow down! Wait before replying again")

  // Create reply
  reply = CREATE discussionReply:
    threadId: threadId,
    authorId: userId,
    content: replyData.content,
    parentReplyId: replyData.parentReplyId, // null for top-level reply
    isInstructorReply: isInstructor,
    isBestAnswer: false,
    likeCount: 0,
    status: "active",
    createdAt: now(),
    updatedAt: now()

  // Update thread stats
  INCREMENT thread.replyCount
  UPDATE thread.lastActivityAt = now()

  // Notify thread subscribers
  subscriptions = FETCH threadSubscriptions
    WHERE threadId == threadId
    AND userId != userId // Don't notify the replier

  FOR EACH sub IN subscriptions:
    subscriber = FETCH user(sub.userId)
    IF subscriber.notificationPreferences.community.threadReplies:
      SEND notification:
        userId: sub.userId,
        type: "thread_reply",
        title: user.name + " replied to: " + thread.title,
        body: TRUNCATE(replyData.content, 100),
        action_url: "/community/threads/" + threadId + "#reply-" + reply._id

      // Email notification (if enabled)
      IF subscriber.notificationPreferences.emailNotifications:
        SEND email via Brevo:
          template: "thread_reply_notification"
          to: subscriber.email
          variables: {
            thread_title: thread.title,
            replier_name: user.name,
            reply_preview: TRUNCATE(replyData.content, 200),
            thread_url: "/community/threads/" + threadId
          }

  // Special notification for instructor replies
  IF isInstructor:
    subscribers = FETCH users IN subscriptions
    FOR EACH subscriber IN subscribers:
      IF subscriber.notificationPreferences.community.instructorReplies:
        SEND notification:
          type: "instructor_reply",
          priority: "high",
          title: "Instructor replied to: " + thread.title

  // Notify parent reply author (if nested)
  IF replyData.parentReplyId:
    parentReply = FETCH discussionReply(replyData.parentReplyId)
    IF parentReply.authorId != userId:
      SEND notification:
        userId: parentReply.authorId,
        type: "reply_mention",
        title: user.name + " replied to your comment",
        body: TRUNCATE(replyData.content, 100),
        action_url: "/community/threads/" + threadId + "#reply-" + reply._id

  RETURN reply
```

---

### 3.2.3 Request Peer Connection

```pseudocode
FUNCTION RequestPeerConnection(userId, targetUserId, connectionData):
  // Prevent self-connection
  IF userId == targetUserId:
    THROW ValidationError("Cannot connect with yourself")

  // Check existing connection
  existingConnection = FETCH peerConnection
    WHERE (userId == userId AND connectedUserId == targetUserId)
    OR (userId == targetUserId AND connectedUserId == userId)

  IF existingConnection EXISTS:
    IF existingConnection.status == "accepted":
      THROW AlreadyConnectedError("Already connected")
    ELSE IF existingConnection.status == "pending":
      THROW PendingRequestError("Connection request already sent")
    ELSE IF existingConnection.status == "blocked":
      THROW BlockedError("Cannot connect with this user")

  // Find shared cohort/session
  userEnrollments = FETCH enrollments WHERE userId == userId
  targetEnrollments = FETCH enrollments WHERE userId == targetUserId

  sharedCohorts = INTERSECT(
    userEnrollments.map(e => e.cohortId),
    targetEnrollments.map(e => e.cohortId)
  )

  IF sharedCohorts.length == 0 AND connectionData.source == "cohort":
    THROW ValidationError("No shared cohorts with this user")

  // Create connection request
  connection = CREATE peerConnection:
    userId: userId,
    connectedUserId: targetUserId,
    connectionSource: connectionData.source, // "cohort", "manual", "suggested"
    sessionId: sharedCohorts[0] || null,
    message: connectionData.message,
    status: "pending",
    createdAt: now(),
    updatedAt: now()

  // Notify target user
  sender = FETCH user(userId)
  targetUser = FETCH user(targetUserId)

  IF targetUser.notificationPreferences.community.peerConnections:
    SEND notification:
      userId: targetUserId,
      type: "connection_request",
      title: sender.name + " wants to connect",
      body: connectionData.message || "From " + sharedCohorts[0]?.name,
      action_url: "/community/connections/requests"

    // Email notification
    IF targetUser.notificationPreferences.emailNotifications:
      SEND email via Brevo:
        template: "connection_request"
        to: targetUser.email
        variables: {
          sender_name: sender.name,
          sender_title: sender.title || "Learner",
          sender_company: sender.company,
          message: connectionData.message,
          shared_cohort: sharedCohorts[0]?.name,
          accept_url: "/community/connections/requests/" + connection._id + "/accept",
          decline_url: "/community/connections/requests/" + connection._id + "/decline"
        }

  RETURN connection
```

---

### 3.2.4 Accept/Decline Connection

```pseudocode
FUNCTION RespondToConnectionRequest(userId, connectionId, action):
  connection = FETCH peerConnection(connectionId)

  // Validate recipient
  IF connection.connectedUserId != userId:
    THROW UnauthorizedError("Not the recipient of this request")

  IF connection.status != "pending":
    THROW InvalidStateError("Request already " + connection.status)

  IF action == "accept":
    // Accept connection
    UPDATE connection:
      status = "accepted",
      acceptedAt = now(),
      updatedAt = now()

    // Create reciprocal connection
    CREATE peerConnection:
      userId: connection.connectedUserId,
      connectedUserId: connection.userId,
      connectionSource: connection.connectionSource,
      sessionId: connection.sessionId,
      status: "accepted",
      acceptedAt: now(),
      createdAt: now(),
      updatedAt: now()

    // Notify requester
    requester = FETCH user(connection.userId)
    accepter = FETCH user(connection.connectedUserId)

    SEND notification:
      userId: connection.userId,
      type: "connection_accepted",
      title: accepter.name + " accepted your connection",
      body: "You can now see each other's activity",
      action_url: "/community/connections"

    // Suggest next steps
    SEND notification:
      userId: connection.userId,
      type: "connection_suggestion",
      title: "Stay connected with " + accepter.name,
      body: "Send a message or schedule a virtual coffee",
      action_url: "/community/connections/" + connection.connectedUserId

    RETURN { status: "accepted", connection: connection }

  ELSE IF action == "decline":
    // Decline connection
    UPDATE connection:
      status = "declined",
      declinedAt: now(),
      updatedAt: now()

    // Optionally notify requester (subtle)
    requester = FETCH user(connection.userId)
    SEND notification:
      userId: connection.userId,
      type: "connection_response",
      title: "Connection status updated",
      body: "", // No details to avoid awkwardness
      priority: "low"

    RETURN { status: "declined" }

  ELSE:
    THROW ValidationError("Invalid action: " + action)
```

---

### 3.2.5 Moderate Thread (Admin)

```pseudocode
FUNCTION ModerateThread(adminId, threadId, moderationAction):
  admin = FETCH user(adminId)

  // Validate admin permissions
  IF admin.role NOT IN ["platform_admin", "instructor"]:
    THROW UnauthorizedError("Insufficient permissions")

  thread = FETCH discussionThread(threadId)
  threadAuthor = FETCH user(thread.authorId)

  IF moderationAction.action == "pin":
    UPDATE thread:
      isPinned = true,
      pinnedAt = now(),
      pinnedBy = adminId

    LOG moderation_event:
      type: "thread_pinned",
      threadId: threadId,
      moderatorId: adminId,
      timestamp: now()

  ELSE IF moderationAction.action == "unpin":
    UPDATE thread:
      isPinned = false,
      pinnedAt = null,
      pinnedBy = null

  ELSE IF moderationAction.action == "lock":
    UPDATE thread:
      isLocked = true,
      lockedAt = now(),
      lockedBy = adminId,
      lockReason: moderationAction.reason

    LOG moderation_event:
      type: "thread_locked",
      threadId: threadId,
      moderatorId: adminId,
      reason: moderationAction.reason,
      timestamp: now()

    // Notify thread author
    SEND notification:
      userId: thread.authorId,
      type: "thread_moderated",
      title: "Your thread has been locked",
      body: "Reason: " + moderationAction.reason,
      action_url: "/community/threads/" + threadId

  ELSE IF moderationAction.action == "unlock":
    UPDATE thread:
      isLocked = false,
      lockedAt = null,
      lockedBy = null,
      lockReason: null

  ELSE IF moderationAction.action == "hide":
    UPDATE thread:
      status = "hidden",
      hiddenAt = now(),
      hiddenBy = adminId,
      hideReason: moderationAction.reason

    LOG moderation_event:
      type: "thread_hidden",
      threadId: threadId,
      moderatorId: adminId,
      reason: moderationAction.reason,
      timestamp: now()

    // Notify author
    SEND email via Brevo:
      template: "content_moderated"
      to: threadAuthor.email
      variables: {
        content_type: "thread",
        title: thread.title,
        reason: moderationAction.reason,
        appeal_url: "/support/appeals?thread=" + threadId
      }

  ELSE IF moderationAction.action == "restore":
    UPDATE thread:
      status = "active",
      hiddenAt = null,
      hiddenBy = null,
      hideReason: null

    // Notify author
    SEND notification:
      userId: thread.authorId,
      type: "content_restored",
      title: "Your thread has been restored",
      action_url: "/community/threads/" + threadId

  ELSE IF moderationAction.action == "flag":
    UPDATE thread:
      status = "flagged",
      flaggedAt: now(),
      flaggedBy = adminId,
      flagReason: moderationAction.reason

    // Notify moderation team
    moderators = FETCH users WHERE role == "platform_admin"
    FOR EACH mod IN moderators:
      SEND notification:
        userId: mod._id,
        type: "moderation_queue",
        title: "Thread flagged for review",
        body: thread.title,
        action_url: "/admin/moderation/threads/" + threadId

  ELSE IF moderationAction.action == "mark_best_answer":
    // Mark a reply as best answer (for Q&A threads)
    reply = FETCH discussionReply(moderationAction.replyId)

    // Remove previous best answer (if any)
    previousBest = FETCH discussionReply
      WHERE threadId == threadId
      AND isBestAnswer == true

    IF previousBest:
      UPDATE previousBest.isBestAnswer = false

    UPDATE reply:
      isBestAnswer = true,
      markedBestAt = now(),
      markedBestBy = adminId

    // Notify reply author
    SEND notification:
      userId: reply.authorId,
      type: "best_answer",
      title: "Your answer was marked as best!",
      body: "In: " + thread.title,
      action_url: "/community/threads/" + threadId + "#reply-" + reply._id

  ELSE:
    THROW ValidationError("Invalid moderation action")

  RETURN { success: true, thread: thread }
```

---

### 3.2.6 Link External Community

```pseudocode
FUNCTION LinkExternalCommunity(organizationId, platformData):
  org = FETCH organization(organizationId)

  // Validate external platform
  supportedPlatforms = ["circle", "skool", "discord", "slack"]
  IF NOT supportedPlatforms.includes(platformData.platform):
    THROW UnsupportedPlatformError("Platform not supported")

  // Create integration
  integration = CREATE externalCommunityIntegration:
    organizationId: organizationId,
    platform: platformData.platform,
    communityUrl: platformData.communityUrl,
    apiKey: ENCRYPT(platformData.apiKey),
    webhookUrl: platformData.webhookUrl,
    ssoEnabled: platformData.ssoEnabled || false,
    autoSyncMembers: platformData.autoSyncMembers || false,
    status: "active",
    createdAt: now(),
    updatedAt: now()

  // Configure SSO (if enabled)
  IF platformData.ssoEnabled:
    ssoConfig = CREATE ssoConfiguration:
      integrationId: integration._id,
      provider: platformData.platform,
      clientId: platformData.sso.clientId,
      clientSecret: ENCRYPT(platformData.sso.clientSecret),
      redirectUrl: "https://aienablement.academy/auth/callback/" + platformData.platform,
      scopes: platformData.sso.scopes || ["read:user", "write:user"]

    UPDATE integration.ssoConfigId = ssoConfig._id

  // Sync existing members (if enabled)
  IF platformData.autoSyncMembers:
    SCHEDULE member_sync_task:
      FUNCTION SyncExternalMembers():
        members = FETCH organization_members WHERE organizationId == org._id

        FOR EACH member IN members:
          TRY:
            // Platform-specific API call
            IF platformData.platform == "circle":
              API_CALL circle.create_member(
                community_id: platformData.communityId,
                email: member.email,
                name: member.name,
                skip_invitation: true
              )

            ELSE IF platformData.platform == "slack":
              API_CALL slack.admin.users.invite(
                channel: platformData.channelId,
                email: member.email,
                real_name: member.name
              )

            LOG sync_success:
              userId: member._id,
              platform: platformData.platform,
              synced_at: now()

          CATCH APIError as e:
            LOG sync_failure:
              userId: member._id,
              platform: platformData.platform,
              error: e.message,
              failed_at: now()

  // Register webhook listener
  WEBHOOK_HANDLER "/webhooks/community/" + platformData.platform:
    FUNCTION HandleExternalEvent(event):
      IF event.type == "member.joined":
        // Find or create user
        user = FETCH user WHERE email == event.member.email
        IF NOT user:
          user = CREATE user:
            email: event.member.email,
            name: event.member.name,
            organizationId: organizationId,
            role: "org_member"

        LOG external_activity:
          userId: user._id,
          platform: platformData.platform,
          event_type: "member_joined",
          timestamp: now()

      ELSE IF event.type == "post.created":
        // Optionally sync discussions
        IF integration.syncDiscussions:
          CREATE discussionThread:
            title: event.post.title,
            content: event.post.content,
            authorId: MATCH_USER(event.post.author),
            scope: "general",
            externalId: event.post.id,
            externalPlatform: platformData.platform

  RETURN integration
```

---

## Summary

| Flow | Key Components | Edge Cases |
|------|---|---|
| **Enroll in Path** | Stripe bundle checkout, B2B seat allocation, progress initialization | Existing enrollment, insufficient seats, free vs paid |
| **Track Progress** | Step-by-step progress, unlock status, percentage calculation | Locked steps, time-based unlocks, completion validation |
| **Unlock Next Course** | Sequential/time-based/conditional unlocks, notifications | Last step completion, unlock rule variations |
| **Complete Path** | Certificate generation, Open Badges 3.0, skills aggregation | Required vs optional steps, certificate PDF generation |
| **Purchase Bundle** | Bundle pricing, savings calculation, course pre-allocation | Individual vs bundle comparison, discount codes |
| **Create Thread** | Access validation, spam prevention, scope-based permissions | Rate limiting, spam detection, moderation flags |
| **Reply to Thread** | Nested replies, instructor highlighting, subscriber notifications | Thread locked, rate limiting, best answer marking |
| **Request Connection** | Shared cohort validation, connection status checks | Self-connection, duplicate requests, blocked users |
| **Accept/Decline** | Reciprocal connection creation, notification handling | Already responded, invalid state transitions |
| **Moderate Thread** | Admin actions (pin/lock/hide), moderation logs, author notifications | Permission validation, restore actions, best answer marking |
| **Link External** | SSO configuration, member sync, webhook integration | Platform-specific APIs, sync failures, event handling |
