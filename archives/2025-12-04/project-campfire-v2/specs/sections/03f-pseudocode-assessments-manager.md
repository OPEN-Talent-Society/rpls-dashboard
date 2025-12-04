# Assessment & Manager Dashboard Flows - Pseudocode (v2.1)

## Overview

This document provides detailed pseudocode for:
- **Assessment System**: Pre/post assessments, learning gains (Hake's formula), AI-assisted grading
- **Manager Dashboard**: Team progress tracking, skills heat maps, compliance reporting, learning reminders

---

## Assessment Flows

### 2.6.1 Take Pre-Course Assessment

```pseudocode
FUNCTION TakePreCourseAssessment(userId, courseId, enrollmentId):
  // Eligibility check
  enrollment = FETCH enrollment(enrollmentId)
  IF enrollment.status != "ACTIVE":
    THROW AccessDeniedError("Enrollment not active")

  // Find pre-course assessment
  assessment = QUERY assessments:
    WHERE courseId = courseId
    AND type = "pre_course"
    AND isActive = true
  IF NOT assessment:
    THROW NotFoundError("Pre-course assessment not available")

  // Check if already taken
  existing_attempt = QUERY assessmentAttempts:
    WHERE userId = userId
    AND assessmentId = assessment.id
    AND status IN ["in_progress", "submitted", "graded"]
  IF existing_attempt:
    IF assessment.allowRetake == false:
      THROW ConflictError("Assessment already completed")
    IF assessment.maxAttempts:
      attempt_count = COUNT attempts(userId, assessment.id)
      IF attempt_count >= assessment.maxAttempts:
        THROW ConflictError("Maximum attempts reached")

  // Create assessment attempt
  attempt_number = COUNT attempts(userId, assessment.id) + 1
  attempt = CREATE assessmentAttempts:
    userId: userId,
    assessmentId: assessment.id,
    enrollmentId: enrollmentId,
    attemptNumber: attempt_number,
    status: "in_progress",
    startedAt: now(),
    createdAt: now()

  // Load questions
  all_questions = QUERY assessmentQuestions:
    WHERE assessmentId = assessment.id
    AND isActive = true
    ORDER BY sortOrder ASC

  // Randomize if configured
  IF assessment.randomizeQuestions:
    questions = SHUFFLE(all_questions)
  ELSE:
    questions = all_questions

  // Limit questions if configured
  IF assessment.questionsPerAttempt:
    questions = questions[0...assessment.questionsPerAttempt]

  // Randomize answer choices if configured
  IF assessment.randomizeAnswers:
    FOR EACH question IN questions:
      IF question.questionType IN ["multiple_choice", "multiple_select"]:
        question.answers = SHUFFLE(question.answers)

  // Display assessment interface
  DISPLAY assessment_page:
    title: assessment.title,
    description: assessment.description,
    time_limit: assessment.timeLimit ? (assessment.timeLimit + " minutes") : "Unlimited",
    questions: questions,
    current_attempt: attempt

  // If time limit exists, start countdown
  IF assessment.timeLimit:
    START timer(assessment.timeLimit * 60 seconds)
    LISTEN timer.expired:
      TRIGGER SubmitAssessment(attemptId, "expired")

  // Save responses as user answers
  WHEN user.answers(questionId, response):
    response_record = UPSERT questionResponses:
      attemptId: attempt.id,
      questionId: questionId,
      selectedAnswerIds: response.selectedAnswerIds,
      textResponse: response.textResponse,
      ratingValue: response.ratingValue,
      createdAt: now()
    AUTO_SAVE "Progress saved"

  // Submit assessment
  WHEN user.clicks(SubmitButton) OR timer.expired:
    TRIGGER SubmitAssessment(attempt.id, timer.expired ? "expired" : "submitted")
```

---

### 2.6.2 Take Post-Course Assessment

```pseudocode
FUNCTION TakePostCourseAssessment(userId, courseId, enrollmentId):
  // Eligibility check
  enrollment = FETCH enrollment(enrollmentId)
  cohort = FETCH cohort(enrollment.cohortId)
  IF cohort.status != "completed":
    THROW AccessDeniedError("Course not yet completed")

  // Check if pre-course assessment was taken
  pre_assessment = QUERY assessments:
    WHERE courseId = courseId
    AND type = "pre_course"
  pre_attempt = QUERY assessmentAttempts:
    WHERE userId = userId
    AND assessmentId = pre_assessment.id
    AND status = "graded"
  IF NOT pre_attempt:
    SHOW modal:
      message: "You must complete the pre-course assessment first"
      action: REDIRECT to PreCourseAssessment

  // Find post-course assessment
  assessment = QUERY assessments:
    WHERE courseId = courseId
    AND type = "post_course"
    AND isActive = true
  IF NOT assessment:
    THROW NotFoundError("Post-course assessment not available")

  // Check attempt limits
  attempt_count = COUNT attempts(userId, assessment.id)
  IF attempt_count >= assessment.maxAttempts AND assessment.maxAttempts:
    THROW ConflictError("Maximum attempts reached")

  // Create assessment attempt
  attempt_number = attempt_count + 1
  attempt = CREATE assessmentAttempts:
    userId: userId,
    assessmentId: assessment.id,
    enrollmentId: enrollmentId,
    attemptNumber: attempt_number,
    status: "in_progress",
    startedAt: now(),
    createdAt: now()

  // IMPORTANT: Use SAME questions as pre-course for valid comparison
  pre_questions = QUERY questionResponses:
    WHERE attemptId = pre_attempt.id
    ORDER BY questionId
  questions = MAP pre_questions -> question(response.questionId)

  // Randomize answers if configured (but keep same questions)
  IF assessment.randomizeAnswers:
    FOR EACH question IN questions:
      IF question.questionType IN ["multiple_choice", "multiple_select"]:
        question.answers = SHUFFLE(question.answers)

  // Display assessment interface (same as pre-course)
  DISPLAY assessment_page:
    title: assessment.title,
    description: assessment.description,
    time_limit: assessment.timeLimit ? (assessment.timeLimit + " minutes") : "Unlimited",
    questions: questions,
    current_attempt: attempt,
    show_note: "This is the same assessment you took before the course"

  // Time limit and submission logic (same as pre-course)
  IF assessment.timeLimit:
    START timer(assessment.timeLimit * 60 seconds)
    LISTEN timer.expired:
      TRIGGER SubmitAssessment(attemptId, "expired")

  WHEN user.answers(questionId, response):
    response_record = UPSERT questionResponses:
      attemptId: attempt.id,
      questionId: questionId,
      selectedAnswerIds: response.selectedAnswerIds,
      textResponse: response.textResponse,
      ratingValue: response.ratingValue,
      createdAt: now()
    AUTO_SAVE "Progress saved"

  WHEN user.clicks(SubmitButton) OR timer.expired:
    TRIGGER SubmitAssessment(attempt.id, timer.expired ? "expired" : "submitted")
    TRIGGER CalculateLearningGain(userId, courseId, enrollmentId)
```

---

### 2.6.3 Submit & Grade Assessment

```pseudocode
FUNCTION SubmitAssessment(attemptId, submissionType):
  // submissionType: "submitted" (user submit) or "expired" (timeout)
  attempt = FETCH assessmentAttempts(attemptId)
  assessment = FETCH assessments(attempt.assessmentId)

  // Update attempt status
  UPDATE attempt:
    status: submissionType,
    submittedAt: now(),
    timeSpent: now() - attempt.startedAt

  // Grade all responses
  responses = QUERY questionResponses:
    WHERE attemptId = attemptId

  total_points_earned = 0
  total_points_possible = 0

  FOR EACH response IN responses:
    question = FETCH assessmentQuestions(response.questionId)
    total_points_possible += question.points

    // Grade based on question type
    SWITCH question.questionType:
      CASE "multiple_choice":
        TRIGGER GradeMultipleChoice(response, question)
      CASE "multiple_select":
        TRIGGER GradeMultipleSelect(response, question)
      CASE "true_false":
        TRIGGER GradeTrueFalse(response, question)
      CASE "short_answer":
        IF question.aiGradingEnabled:
          TRIGGER GradeShortAnswerWithAI(response, question)
        ELSE:
          // Flag for manual grading
          UPDATE response:
            isCorrect: null,
            pointsEarned: 0,
            feedback: "Awaiting manual grading"
      CASE "rating_scale":
        // Rating scales are not graded (informational only)
        UPDATE response:
          pointsEarned: 0
      CASE "open_ended":
        IF question.aiGradingEnabled:
          TRIGGER GradeOpenEndedWithAI(response, question)
        ELSE:
          // Flag for manual grading
          UPDATE response:
            isCorrect: null,
            pointsEarned: 0,
            feedback: "Awaiting manual grading"

    total_points_earned += response.pointsEarned

  // Calculate final score
  score = (total_points_earned / total_points_possible) * 100
  passed = score >= assessment.passingScore

  // Update attempt with results
  UPDATE attempt:
    status: "graded",
    score: score,
    pointsEarned: total_points_earned,
    pointsPossible: total_points_possible,
    passed: passed,
    overallFeedback: GenerateFeedback(score, passed, assessment.passingScore)

  // Show results based on configuration
  SHOW results_page:
    score: score,
    passed: passed,
    points: total_points_earned + "/" + total_points_possible,
    time_spent: FormatDuration(attempt.timeSpent)

  IF assessment.showCorrectAnswers == "after_submit" OR
     (assessment.showCorrectAnswers == "after_passing" AND passed):
    DISPLAY detailed_review:
      questions: questions with correct answers,
      user_responses: responses,
      feedback: per-question feedback

  // Send completion notification
  IF passed:
    SEND email via Brevo:
      template: "assessment_passed"
      variables: {
        user: attempt.user,
        assessment: assessment,
        score: score
      }
  ELSE:
    IF attempt.attemptNumber < assessment.maxAttempts:
      SEND email via Brevo:
        template: "assessment_retake_available"
        variables: {
          attempts_remaining: assessment.maxAttempts - attempt.attemptNumber
        }

  RETURN attempt
```

---

### 2.6.4 AI-Assisted Grading (Open-Ended)

```pseudocode
FUNCTION GradeOpenEndedWithAI(response, question):
  // Prepare grading context
  grading_prompt = BUILD prompt:
    role: "You are an expert assessment grader for AI enablement courses"
    task: "Grade the student's open-ended response"
    question: question.questionText,
    sample_answer: question.sampleAnswer,
    student_response: response.textResponse,
    points_possible: question.points,
    instructions: [
      "Evaluate accuracy, completeness, and depth",
      "Consider practical application and understanding",
      "Provide constructive feedback",
      "Return score (0-{points_possible}), confidence (0-1), and explanation"
    ]

  // Call OpenRouter LLM
  TRY:
    llm_response = CALL openrouter.api.completions:
      model: "meta-llama/llama-3.1-70b-instruct",
      messages: [grading_prompt, response.textResponse],
      temperature: 0.3, // Lower temp for consistent grading
      max_tokens: 512,
      response_format: { type: "json_object" }

    // Parse AI grading result
    grading_result = JSON.parse(llm_response.content)
    ai_score = grading_result.score
    ai_confidence = grading_result.confidence
    ai_explanation = grading_result.explanation

    // Apply confidence thresholds
    IF ai_confidence >= 0.9:
      // High confidence: auto-grade
      UPDATE response:
        pointsEarned: ai_score,
        aiScore: ai_score,
        aiConfidence: ai_confidence,
        aiExplanation: ai_explanation,
        feedback: ai_explanation,
        isCorrect: ai_score >= (question.points * 0.7) // 70% threshold

    ELSE IF ai_confidence >= 0.7 AND ai_confidence < 0.9:
      // Medium confidence: flag for review
      UPDATE response:
        pointsEarned: ai_score,
        aiScore: ai_score,
        aiConfidence: ai_confidence,
        aiExplanation: ai_explanation,
        feedback: "Awaiting instructor review (AI confidence: " + ai_confidence + ")",
        isCorrect: null
      // Create review task for instructor
      CREATE grading_review_task:
        questionResponseId: response.id,
        reason: "Medium AI confidence",
        suggestedScore: ai_score

    ELSE:
      // Low confidence: require manual grading
      UPDATE response:
        pointsEarned: 0,
        aiScore: ai_score,
        aiConfidence: ai_confidence,
        aiExplanation: ai_explanation,
        feedback: "Awaiting manual grading (AI confidence too low)",
        isCorrect: null
      CREATE grading_review_task:
        questionResponseId: response.id,
        reason: "Low AI confidence",
        suggestedScore: ai_score

  CATCH openrouter.RateLimitError:
    // Fallback: queue for manual grading
    UPDATE response:
      pointsEarned: 0,
      feedback: "AI grading unavailable, awaiting manual review"
    LOG error "OpenRouter rate limit exceeded for grading"

  CATCH openrouter.TimeoutError:
    // Retry once, then fallback to manual
    RETRY CALL openrouter (max 1 retry)
    IF retry fails:
      UPDATE response:
        pointsEarned: 0,
        feedback: "AI grading failed, awaiting manual review"

  RETURN response
```

---

### 2.6.5 Calculate Learning Gain (Hake's Formula)

```pseudocode
FUNCTION CalculateLearningGain(userId, courseId, enrollmentId):
  // Fetch pre-assessment attempt
  pre_assessment = QUERY assessments:
    WHERE courseId = courseId
    AND type = "pre_course"
  pre_attempt = QUERY assessmentAttempts:
    WHERE userId = userId
    AND assessmentId = pre_assessment.id
    AND status = "graded"
    ORDER BY submittedAt DESC
    LIMIT 1

  IF NOT pre_attempt:
    LOG warning "No pre-assessment found for learning gain calculation"
    RETURN null

  // Fetch post-assessment attempt
  post_assessment = QUERY assessments:
    WHERE courseId = courseId
    AND type = "post_course"
  post_attempt = QUERY assessmentAttempts:
    WHERE userId = userId
    AND assessmentId = post_assessment.id
    AND status = "graded"
    ORDER BY submittedAt DESC
    LIMIT 1

  IF NOT post_attempt:
    LOG warning "No post-assessment found for learning gain calculation"
    RETURN null

  // Extract scores
  pre_score = pre_attempt.score
  post_score = post_attempt.score

  // Calculate learning gains
  score_improvement = post_score - pre_score
  percentage_gain = ((post_score - pre_score) / pre_score) * 100

  // Hake's normalized gain formula
  IF pre_score >= 100:
    // Edge case: perfect pre-score, no room for improvement
    normalized_gain = 0
  ELSE:
    normalized_gain = (post_score - pre_score) / (100 - pre_score)

  // Calculate skill-level gains
  skill_gains = []
  skills = FETCH skills from assessment.skillIds

  FOR EACH skill IN skills:
    // Get pre-score for skill
    pre_skill_responses = QUERY questionResponses:
      WHERE attemptId = pre_attempt.id
      AND questionId IN (SELECT id FROM assessmentQuestions WHERE skillIds CONTAINS skill.id)
    pre_skill_points = SUM(pre_skill_responses -> pointsEarned)
    pre_skill_possible = SUM(pre_skill_responses -> question.points)
    pre_skill_score = (pre_skill_points / pre_skill_possible) * 100

    // Get post-score for skill
    post_skill_responses = QUERY questionResponses:
      WHERE attemptId = post_attempt.id
      AND questionId IN (SELECT id FROM assessmentQuestions WHERE skillIds CONTAINS skill.id)
    post_skill_points = SUM(post_skill_responses -> pointsEarned)
    post_skill_possible = SUM(post_skill_responses -> question.points)
    post_skill_score = (post_skill_points / post_skill_possible) * 100

    skill_improvement = post_skill_score - pre_skill_score

    APPEND skill_gains:
      skillId: skill.id,
      preScore: pre_skill_score,
      postScore: post_skill_score,
      improvement: skill_improvement

  // Store learning gain analytics
  learning_gain = CREATE learningGainAnalytics:
    userId: userId,
    courseId: courseId,
    enrollmentId: enrollmentId,
    preAssessmentId: pre_assessment.id,
    preAttemptId: pre_attempt.id,
    preScore: pre_score,
    postAssessmentId: post_assessment.id,
    postAttemptId: post_attempt.id,
    postScore: post_score,
    scoreImprovement: score_improvement,
    percentageGain: percentage_gain,
    normalizedGain: normalized_gain,
    skillGains: skill_gains,
    calculatedAt: now()

  // Interpret normalized gain
  FUNCTION InterpretGain(g) -> String:
    IF g >= 0.7:
      RETURN "High gain (exceptional learning)"
    ELSE IF g >= 0.3:
      RETURN "Medium gain (good learning)"
    ELSE:
      RETURN "Low gain (needs improvement)"

  // Display results to user
  DISPLAY learning_gain_report:
    title: "Your Learning Progress",
    pre_score: pre_score + "%",
    post_score: post_score + "%",
    improvement: score_improvement + " points",
    normalized_gain: ROUND(normalized_gain, 2),
    interpretation: InterpretGain(normalized_gain),
    skill_breakdown: skill_gains,
    message: "You've made " + InterpretGain(normalized_gain) + " in this course!"

  // Send report email
  SEND email via Brevo:
    template: "learning_gain_report"
    variables: {
      user: enrollment.user,
      course: course,
      pre_score: pre_score,
      post_score: post_score,
      normalized_gain: normalized_gain,
      interpretation: InterpretGain(normalized_gain)
    }

  RETURN learning_gain
```

---

### 2.6.6 Generate Assessment Report (Manager View)

```pseudocode
FUNCTION GenerateAssessmentReport(organizationId, courseId, reportType):
  // Verify manager permissions
  manager = AUTHENTICATE current_user
  org_manager = QUERY organizationManagers:
    WHERE userId = manager.id
    AND organizationId = organizationId
    AND permissions CONTAINS "view_analytics"
  IF NOT org_manager:
    THROW PermissionDeniedError("Insufficient permissions")

  // Fetch all enrollments for organization
  enrollments = QUERY enrollments:
    WHERE courseId = courseId
    AND userId IN (SELECT id FROM users WHERE organizationId = organizationId)

  // Fetch learning gains for enrollments
  learning_gains = QUERY learningGainAnalytics:
    WHERE courseId = courseId
    AND enrollmentId IN (enrollments -> id)

  // Calculate aggregate metrics
  total_learners = COUNT(enrollments)
  completed_pre = COUNT(learning_gains WHERE preScore IS NOT NULL)
  completed_post = COUNT(learning_gains WHERE postScore IS NOT NULL)
  completed_both = COUNT(learning_gains WHERE preScore AND postScore)

  avg_pre_score = AVG(learning_gains -> preScore)
  avg_post_score = AVG(learning_gains -> postScore)
  avg_improvement = AVG(learning_gains -> scoreImprovement)
  avg_normalized_gain = AVG(learning_gains -> normalizedGain)

  // Categorize learners by gain
  high_gain = COUNT(learning_gains WHERE normalizedGain >= 0.7)
  medium_gain = COUNT(learning_gains WHERE normalizedGain >= 0.3 AND normalizedGain < 0.7)
  low_gain = COUNT(learning_gains WHERE normalizedGain < 0.3)

  // Calculate skill-level aggregate gains
  all_skills = UNIQUE(learning_gains -> skillGains -> skillId)
  skill_aggregates = []

  FOR EACH skill IN all_skills:
    skill_data = FILTER learning_gains -> skillGains WHERE skillId = skill
    avg_skill_improvement = AVG(skill_data -> improvement)

    APPEND skill_aggregates:
      skillId: skill,
      skillName: FETCH skill(skill).name,
      avgImprovement: avg_skill_improvement,
      learnersAssessed: COUNT(skill_data)

  // Build report data structure
  report_data = {
    organization: FETCH organization(organizationId),
    course: FETCH course(courseId),
    generated_at: now(),
    summary: {
      total_learners: total_learners,
      completed_pre: completed_pre,
      completed_post: completed_post,
      completed_both: completed_both,
      completion_rate: (completed_both / total_learners) * 100
    },
    scores: {
      avg_pre_score: ROUND(avg_pre_score, 1),
      avg_post_score: ROUND(avg_post_score, 1),
      avg_improvement: ROUND(avg_improvement, 1),
      avg_normalized_gain: ROUND(avg_normalized_gain, 2)
    },
    distribution: {
      high_gain: high_gain,
      medium_gain: medium_gain,
      low_gain: low_gain
    },
    skill_breakdown: skill_aggregates
  }

  // Generate report based on type
  SWITCH reportType:
    CASE "pdf":
      pdf = GENERATE PDF:
        template: "assessment_report_template.pdf",
        data: report_data
      file_id = UPLOAD pdf TO convex_storage
      RETURN { format: "pdf", file_id: file_id, url: GENERATE_URL(file_id) }

    CASE "csv":
      csv = GENERATE CSV:
        headers: ["Learner", "Pre-Score", "Post-Score", "Improvement", "Normalized Gain"],
        rows: MAP learning_gains -> [
          learner.name,
          preScore,
          postScore,
          scoreImprovement,
          normalizedGain
        ]
      file_id = UPLOAD csv TO convex_storage
      RETURN { format: "csv", file_id: file_id, url: GENERATE_URL(file_id) }

    CASE "json":
      RETURN { format: "json", data: report_data }

  // Log report generation
  CREATE managerAccessLogs:
    managerId: manager.id,
    organizationId: organizationId,
    accessType: "export_report",
    timestamp: now()
```

---

## Manager Dashboard Flows (B2B)

### 2.7.1 View Team Progress Dashboard

```pseudocode
FUNCTION ViewTeamProgressDashboard(managerId, teamId):
  // Verify manager permissions
  org_manager = QUERY organizationManagers:
    WHERE userId = managerId
    AND permissions CONTAINS "view_progress"
    AND (teamIds CONTAINS teamId OR teamIds IS NULL) // Null = access to all teams
  IF NOT org_manager:
    THROW PermissionDeniedError("Cannot access this team")

  team = FETCH teams(teamId)
  organization = FETCH organizations(team.organizationId)

  // Fetch team members
  team_members = QUERY teamMembers:
    WHERE teamId = teamId
  user_ids = team_members -> userId

  // Fetch enrollments for team members
  enrollments = QUERY enrollments:
    WHERE userId IN user_ids
    AND paymentStatus = "completed"

  // Calculate progress for each member
  member_progress = []

  FOR EACH member IN team_members:
    user = FETCH users(member.userId)
    user_enrollments = FILTER enrollments WHERE userId = user.id

    // Check privacy settings
    privacy = FETCH userPrivacySettings(user.id)
    allow_view_scores = privacy?.allowManagerViewScores ?? true // Default true for B2B
    allow_view_activity = privacy?.allowManagerViewActivity ?? true

    FOR EACH enrollment IN user_enrollments:
      course = FETCH courses(enrollment.courseId)
      cohort = FETCH cohorts(enrollment.cohortId)

      // Calculate progress percentage
      total_lessons = COUNT lessons WHERE courseId = course.id
      completed_lessons = COUNT lessonProgress:
        WHERE enrollmentId = enrollment.id
        AND status = "completed"
      progress_pct = (completed_lessons / total_lessons) * 100

      // Get assessment scores (if allowed)
      assessment_score = null
      IF allow_view_scores:
        post_assessment = QUERY assessments:
          WHERE courseId = course.id
          AND type = "post_course"
        post_attempt = QUERY assessmentAttempts:
          WHERE userId = user.id
          AND assessmentId = post_assessment?.id
          AND status = "graded"
          ORDER BY submittedAt DESC
          LIMIT 1
        assessment_score = post_attempt?.score

      // Get last activity (if allowed)
      last_active = null
      IF allow_view_activity:
        last_progress = QUERY lessonProgress:
          WHERE enrollmentId = enrollment.id
          ORDER BY updatedAt DESC
          LIMIT 1
        last_active = last_progress?.updatedAt

      // Calculate status
      status = "on_track"
      IF progress_pct < 25 AND DaysSince(enrollment.createdAt) > 7:
        status = "behind_schedule"
      ELSE IF last_active AND DaysSince(last_active) > 7:
        status = "inactive"
      ELSE IF progress_pct >= 100:
        status = "completed"

      APPEND member_progress:
        user_id: user.id,
        user_name: user.name,
        course_name: course.title,
        cohort_name: cohort.name,
        progress_pct: ROUND(progress_pct, 1),
        completed_lessons: completed_lessons,
        total_lessons: total_lessons,
        assessment_score: assessment_score,
        last_active: last_active,
        days_since_active: last_active ? DaysSince(last_active) : null,
        status: status,
        certificate_earned: enrollment.certificateId ? true : false

  // Calculate team aggregate metrics
  total_members = COUNT(team_members)
  active_members = COUNT(member_progress WHERE status != "inactive")
  avg_progress = AVG(member_progress -> progress_pct)
  on_track = COUNT(member_progress WHERE status = "on_track")
  behind = COUNT(member_progress WHERE status = "behind_schedule")
  inactive = COUNT(member_progress WHERE status = "inactive")
  completed = COUNT(member_progress WHERE status = "completed")

  // Display dashboard
  DISPLAY team_dashboard:
    team: {
      name: team.name,
      organization: organization.name,
      member_count: total_members,
      manager: team.managerId ? FETCH user(team.managerId).name : "None"
    },
    summary: {
      total_members: total_members,
      active_members: active_members,
      avg_progress: ROUND(avg_progress, 1) + "%",
      on_track: on_track,
      behind_schedule: behind,
      inactive: inactive,
      completed: completed
    },
    members: member_progress,
    filters: [
      "All Members",
      "On Track",
      "Behind Schedule",
      "Inactive",
      "Completed"
    ]

  // Visual elements
  RENDER progress_chart:
    type: "bar_chart",
    x_axis: member_progress -> user_name,
    y_axis: member_progress -> progress_pct,
    color: member_progress -> status_color

  RENDER status_pie_chart:
    segments: [
      { label: "On Track", value: on_track, color: "green" },
      { label: "Behind", value: behind, color: "yellow" },
      { label: "Inactive", value: inactive, color: "red" },
      { label: "Completed", value: completed, color: "blue" }
    ]

  // Log dashboard access
  CREATE managerAccessLogs:
    managerId: managerId,
    organizationId: team.organizationId,
    accessType: "view_dashboard",
    timestamp: now()
```

---

### 2.7.2 Generate Manager Report

```pseudocode
FUNCTION GenerateManagerReport(managerId, organizationId, reportConfig):
  // Verify manager permissions
  org_manager = QUERY organizationManagers:
    WHERE userId = managerId
    AND organizationId = organizationId
    AND permissions CONTAINS "export_reports"
  IF NOT org_manager:
    THROW PermissionDeniedError("Cannot export reports")

  // Extract report configuration
  report_type = reportConfig.reportType
  team_ids = reportConfig.teamIds
  course_ids = reportConfig.courseIds
  date_range = reportConfig.dateRange
  format = reportConfig.format

  // Fetch relevant data based on report type
  SWITCH report_type:
    CASE "progress_summary":
      data = GENERATE_PROGRESS_SUMMARY(organizationId, team_ids, date_range)
    CASE "individual_detail":
      data = GENERATE_INDIVIDUAL_DETAIL(organizationId, team_ids, course_ids, date_range)
    CASE "skill_matrix":
      data = GENERATE_SKILL_MATRIX(organizationId, team_ids)
    CASE "roi_analysis":
      data = GENERATE_ROI_ANALYSIS(organizationId, course_ids, date_range)
    CASE "engagement":
      data = GENERATE_ENGAGEMENT_REPORT(organizationId, team_ids, date_range)
    CASE "compliance":
      data = GENERATE_COMPLIANCE_REPORT(organizationId, team_ids, date_range)

  // Generate file based on format
  SWITCH format:
    CASE "pdf":
      file = GENERATE_PDF(data, report_type)
    CASE "csv":
      file = GENERATE_CSV(data, report_type)
    CASE "xlsx":
      file = GENERATE_XLSX(data, report_type)

  // Upload to storage
  file_id = UPLOAD file TO convex_storage
  download_url = GENERATE_URL(file_id)

  // Save report record
  report = CREATE managerReports:
    organizationId: organizationId,
    createdBy: managerId,
    name: reportConfig.name,
    description: reportConfig.description,
    reportType: report_type,
    teamIds: team_ids,
    courseIds: course_ids,
    dateRange: date_range,
    format: format,
    lastGeneratedFileId: file_id,
    isScheduled: false,
    isActive: true,
    createdAt: now(),
    updatedAt: now()

  // Send report via email
  SEND email via Brevo:
    template: "manager_report_ready"
    to: [{ email: manager.email, name: manager.name }]
    variables: {
      report_name: reportConfig.name,
      report_type: report_type,
      download_url: download_url,
      generated_at: now()
    }

  // Log report generation
  CREATE managerAccessLogs:
    managerId: managerId,
    organizationId: organizationId,
    accessType: "export_report",
    timestamp: now()

  RETURN {
    report_id: report.id,
    file_id: file_id,
    download_url: download_url
  }

// Helper function for individual detail report
FUNCTION GENERATE_INDIVIDUAL_DETAIL(organizationId, teamIds, courseIds, dateRange):
  // Fetch team members
  IF teamIds:
    members = QUERY teamMembers WHERE teamId IN teamIds
  ELSE:
    members = QUERY teamMembers WHERE teamId IN (SELECT id FROM teams WHERE organizationId = organizationId)

  user_ids = members -> userId

  // Fetch enrollments
  enrollments = QUERY enrollments:
    WHERE userId IN user_ids
    AND paymentStatus = "completed"
    AND (courseIds ? courseId IN courseIds : true)
    AND createdAt BETWEEN dateRange.start AND dateRange.end

  // Build detailed rows
  rows = []

  FOR EACH enrollment IN enrollments:
    user = FETCH users(enrollment.userId)
    team = QUERY teamMembers WHERE userId = user.id -> team
    course = FETCH courses(enrollment.courseId)

    // Check privacy
    privacy = FETCH userPrivacySettings(user.id)
    allow_scores = privacy?.allowManagerViewScores ?? true
    allow_activity = privacy?.allowManagerViewActivity ?? true

    // Calculate progress
    total_lessons = COUNT lessons WHERE courseId = course.id
    completed_lessons = COUNT lessonProgress:
      WHERE enrollmentId = enrollment.id
      AND status = "completed"
    progress_pct = (completed_lessons / total_lessons) * 100

    // Get assessment score
    assessment_score = null
    IF allow_scores:
      post_attempt = QUERY assessmentAttempts:
        WHERE userId = user.id
        AND assessmentId IN (SELECT id FROM assessments WHERE courseId = course.id AND type = "post_course")
        AND status = "graded"
        ORDER BY submittedAt DESC
        LIMIT 1
      assessment_score = post_attempt?.score

    // Get last activity
    last_active = null
    IF allow_activity:
      last_progress = QUERY lessonProgress:
        WHERE enrollmentId = enrollment.id
        ORDER BY updatedAt DESC
        LIMIT 1
      last_active = last_progress?.updatedAt

    // Get certificate
    certificate = enrollment.certificateId ? FETCH certificates(enrollment.certificateId) : null

    // Get skills acquired
    skills_acquired = QUERY skillProgress:
      WHERE userId = user.id
      AND skillId IN (SELECT skillId FROM courseSkills WHERE courseId = course.id)
      AND proficiencyLevel IN ["intermediate", "advanced", "expert"]

    APPEND rows:
      learner_name: user.name,
      team_name: team?.name ?? "No Team",
      course_name: course.title,
      progress_pct: ROUND(progress_pct, 1),
      lessons_completed: completed_lessons + "/" + total_lessons,
      assessment_score: assessment_score ? ROUND(assessment_score, 1) + "%" : "N/A",
      last_active: last_active ? FormatDate(last_active) : "Never",
      days_since_login: last_active ? DaysSince(last_active) : "N/A",
      certificate_status: certificate ? "Earned" : "Not Earned",
      skills_acquired: COUNT(skills_acquired)

  RETURN {
    columns: ["Learner Name", "Team", "Course", "Progress %", "Lessons Completed",
              "Assessment Score", "Last Active", "Days Since Last Login",
              "Certificate Status", "Skills Acquired"],
    rows: rows
  }
```

---

### 2.7.3 Send Learning Reminder

```pseudocode
FUNCTION SendLearningReminder(managerId, organizationId, reminderConfig):
  // Verify manager permissions
  org_manager = QUERY organizationManagers:
    WHERE userId = managerId
    AND organizationId = organizationId
    AND permissions CONTAINS "send_reminders"
  IF NOT org_manager:
    THROW PermissionDeniedError("Cannot send reminders")

  // Extract configuration
  target_type = reminderConfig.targetType
  target_user_ids = reminderConfig.targetUserIds
  target_team_ids = reminderConfig.targetTeamIds
  inactivity_days = reminderConfig.inactivityDays
  subject = reminderConfig.subject
  message = reminderConfig.message
  include_progress = reminderConfig.includeProgress
  channel = reminderConfig.channel

  // Determine recipient list based on target type
  recipients = []

  SWITCH target_type:
    CASE "individual":
      // Specific users
      recipients = target_user_ids

    CASE "team":
      // All members of specified teams
      team_members = QUERY teamMembers WHERE teamId IN target_team_ids
      recipients = team_members -> userId

    CASE "behind_schedule":
      // Auto-target learners falling behind
      all_enrollments = QUERY enrollments:
        WHERE userId IN (SELECT id FROM users WHERE organizationId = organizationId)
        AND paymentStatus = "completed"
        AND status = "ACTIVE"

      FOR EACH enrollment IN all_enrollments:
        total_lessons = COUNT lessons WHERE courseId = enrollment.courseId
        completed_lessons = COUNT lessonProgress:
          WHERE enrollmentId = enrollment.id
          AND status = "completed"
        progress_pct = (completed_lessons / total_lessons) * 100

        days_enrolled = DaysSince(enrollment.createdAt)
        expected_progress = (days_enrolled / 60) * 100 // Assume 60-day course

        IF progress_pct < (expected_progress - 20): // 20% behind expected
          APPEND recipients: enrollment.userId

    CASE "inactive":
      // No activity in X days
      all_enrollments = QUERY enrollments:
        WHERE userId IN (SELECT id FROM users WHERE organizationId = organizationId)
        AND paymentStatus = "completed"
        AND status = "ACTIVE"

      FOR EACH enrollment IN all_enrollments:
        last_activity = QUERY lessonProgress:
          WHERE enrollmentId = enrollment.id
          ORDER BY updatedAt DESC
          LIMIT 1

        IF last_activity AND DaysSince(last_activity.updatedAt) >= inactivity_days:
          APPEND recipients: enrollment.userId

  // Deduplicate recipients
  recipients = UNIQUE(recipients)

  // Send reminders
  sent_count = 0

  FOR EACH user_id IN recipients:
    user = FETCH users(user_id)

    // Get user's progress data if include_progress = true
    progress_data = null
    IF include_progress:
      enrollments = QUERY enrollments WHERE userId = user_id
      progress_summary = []
      FOR EACH enrollment IN enrollments:
        total_lessons = COUNT lessons WHERE courseId = enrollment.courseId
        completed_lessons = COUNT lessonProgress:
          WHERE enrollmentId = enrollment.id
          AND status = "completed"
        progress_pct = (completed_lessons / total_lessons) * 100

        APPEND progress_summary:
          course_name: FETCH course(enrollment.courseId).title,
          progress_pct: ROUND(progress_pct, 1)

      progress_data = progress_summary

    // Send via email
    IF channel IN ["email", "both"]:
      SEND email via Brevo:
        template: "manager_learning_reminder"
        to: [{ email: user.email, name: user.name }]
        variables: {
          subject: subject,
          message: message,
          progress_data: progress_data,
          manager_name: FETCH user(managerId).name
        }

    // Send in-app notification
    IF channel IN ["in_app", "both"]:
      CREATE notification:
        userId: user_id,
        type: "learning_reminder",
        title: subject,
        content: message,
        actionUrl: "/dashboard",
        createdAt: now()

    sent_count += 1

  // Log reminder
  reminder_record = CREATE learningReminders:
    organizationId: organizationId,
    sentBy: managerId,
    targetType: target_type,
    targetUserIds: target_user_ids,
    targetTeamIds: target_team_ids,
    inactivityDays: inactivity_days,
    subject: subject,
    message: message,
    includeProgress: include_progress,
    channel: channel,
    sentAt: now(),
    recipientCount: sent_count,
    createdAt: now()

  // Log access
  CREATE managerAccessLogs:
    managerId: managerId,
    organizationId: organizationId,
    accessType: "send_reminder",
    timestamp: now()

  RETURN {
    reminder_id: reminder_record.id,
    recipients_count: sent_count
  }
```

---

### 2.7.4 View Skills Heat Map

```pseudocode
FUNCTION ViewSkillsHeatMap(managerId, organizationId, teamId):
  // Verify manager permissions
  org_manager = QUERY organizationManagers:
    WHERE userId = managerId
    AND organizationId = organizationId
    AND permissions CONTAINS "view_analytics"
  IF NOT org_manager:
    THROW PermissionDeniedError("Cannot view analytics")

  // Fetch team members
  IF teamId:
    team_members = QUERY teamMembers WHERE teamId = teamId
  ELSE:
    // All teams in organization
    all_teams = QUERY teams WHERE organizationId = organizationId
    team_members = QUERY teamMembers WHERE teamId IN (all_teams -> id)

  user_ids = team_members -> userId

  // Fetch all skills from courses taken by team
  enrollments = QUERY enrollments WHERE userId IN user_ids
  course_ids = enrollments -> courseId
  course_skills = QUERY courseSkills WHERE courseId IN course_ids
  all_skills = UNIQUE(course_skills -> skillId)

  // Build skills matrix
  skills_matrix = []

  FOR EACH skill_id IN all_skills:
    skill = FETCH skills(skill_id)

    // Get proficiency data for each user
    user_proficiencies = []

    FOR EACH user_id IN user_ids:
      user = FETCH users(user_id)

      // Check privacy
      privacy = FETCH userPrivacySettings(user_id)
      allow_view = privacy?.allowManagerViewActivity ?? true

      IF NOT allow_view:
        proficiency = "hidden"
      ELSE:
        skill_progress = QUERY skillProgress:
          WHERE userId = user_id
          AND skillId = skill_id

        IF NOT skill_progress:
          proficiency = "none" // Skill not started
        ELSE:
          proficiency = skill_progress.proficiencyLevel // novice/intermediate/advanced/expert

      APPEND user_proficiencies:
        user_id: user_id,
        user_name: user.name,
        proficiency: proficiency

    // Calculate team aggregate for this skill
    proficiency_counts = COUNT_BY(user_proficiencies -> proficiency)
    avg_proficiency = CalculateAverageProficiency(user_proficiencies)

    APPEND skills_matrix:
      skill_id: skill_id,
      skill_name: skill.name,
      skill_category: skill.category,
      user_proficiencies: user_proficiencies,
      team_aggregate: {
        none: proficiency_counts["none"] ?? 0,
        novice: proficiency_counts["novice"] ?? 0,
        intermediate: proficiency_counts["intermediate"] ?? 0,
        advanced: proficiency_counts["advanced"] ?? 0,
        expert: proficiency_counts["expert"] ?? 0,
        avg_proficiency: avg_proficiency
      }

  // Display heat map
  DISPLAY skills_heatmap:
    title: teamId ? FETCH team(teamId).name + " Skills Matrix" : "Organization Skills Matrix",
    x_axis: user_proficiencies -> user_name,
    y_axis: skills_matrix -> skill_name,
    cells: [
      FOR skill IN skills_matrix:
        FOR user_prof IN skill.user_proficiencies:
          {
            skill: skill.skill_name,
            user: user_prof.user_name,
            proficiency: user_prof.proficiency,
            color: MapProficiencyToColor(user_prof.proficiency)
          }
    ],
    legend: {
      "none": "gray",
      "novice": "light blue",
      "intermediate": "blue",
      "advanced": "dark blue",
      "expert": "purple",
      "hidden": "striped"
    }

  // Display skill gaps
  skill_gaps = FILTER skills_matrix WHERE team_aggregate.avg_proficiency < 2 // Below intermediate
  DISPLAY skill_gaps_section:
    title: "Skill Gaps (Below Intermediate)",
    skills: skill_gaps -> skill_name,
    recommendation: "Consider additional training in these areas"

  // Log access
  CREATE managerAccessLogs:
    managerId: managerId,
    organizationId: organizationId,
    accessType: "view_dashboard",
    timestamp: now()

// Helper function
FUNCTION CalculateAverageProficiency(user_proficiencies) -> Number:
  proficiency_values = {
    "none": 0,
    "novice": 1,
    "intermediate": 2,
    "advanced": 3,
    "expert": 4,
    "hidden": null
  }

  values = []
  FOR EACH user_prof IN user_proficiencies:
    value = proficiency_values[user_prof.proficiency]
    IF value IS NOT NULL:
      APPEND values: value

  IF values.length == 0:
    RETURN 0
  ELSE:
    RETURN AVG(values)

FUNCTION MapProficiencyToColor(proficiency) -> String:
  SWITCH proficiency:
    CASE "none": RETURN "#E0E0E0" // Gray
    CASE "novice": RETURN "#BBDEFB" // Light blue
    CASE "intermediate": RETURN "#42A5F5" // Blue
    CASE "advanced": RETURN "#1565C0" // Dark blue
    CASE "expert": RETURN "#7E57C2" // Purple
    CASE "hidden": RETURN "url(#stripe-pattern)" // Striped pattern
    DEFAULT: RETURN "#FFFFFF"
```

---

### 2.7.5 Export Compliance Report

```pseudocode
FUNCTION ExportComplianceReport(managerId, organizationId, dateRange):
  // Verify manager permissions
  org_manager = QUERY organizationManagers:
    WHERE userId = managerId
    AND organizationId = organizationId
    AND permissions CONTAINS "export_reports"
  IF NOT org_manager:
    THROW PermissionDeniedError("Cannot export reports")

  organization = FETCH organizations(organizationId)

  // Fetch all team members
  all_teams = QUERY teams WHERE organizationId = organizationId
  all_members = QUERY teamMembers WHERE teamId IN (all_teams -> id)
  user_ids = all_members -> userId

  // Fetch enrollments
  enrollments = QUERY enrollments:
    WHERE userId IN user_ids
    AND createdAt BETWEEN dateRange.start AND dateRange.end

  // Section 1: Deadline Tracking
  deadline_tracking = []

  FOR EACH enrollment IN enrollments:
    course = FETCH courses(enrollment.courseId)
    cohort = FETCH cohorts(enrollment.cohortId)
    user = FETCH users(enrollment.userId)
    team = QUERY teamMembers WHERE userId = user.id -> team

    // Check if course has deadline
    IF team?.completionDeadline:
      deadline = team.completionDeadline

      // Calculate progress
      total_lessons = COUNT lessons WHERE courseId = course.id
      completed_lessons = COUNT lessonProgress:
        WHERE enrollmentId = enrollment.id
        AND status = "completed"
      progress_pct = (completed_lessons / total_lessons) * 100

      // Determine status
      status = "on_time"
      IF now() > deadline AND progress_pct < 100:
        status = "overdue"
      ELSE IF now() > (deadline - 7 days) AND progress_pct < 80:
        status = "at_risk"

      APPEND deadline_tracking:
        user_name: user.name,
        team_name: team.name,
        course_name: course.title,
        progress_pct: ROUND(progress_pct, 1),
        deadline: FormatDate(deadline),
        days_until_deadline: DaysUntil(deadline),
        status: status

  // Section 2: Mandatory Training
  mandatory_courses = QUERY courses WHERE isMandatory = true // Assumes field exists
  mandatory_completion = []

  FOR EACH course IN mandatory_courses:
    FOR EACH user_id IN user_ids:
      user = FETCH users(user_id)
      team = QUERY teamMembers WHERE userId = user_id -> team

      enrollment = QUERY enrollments:
        WHERE userId = user_id
        AND courseId = course.id

      IF enrollment:
        total_lessons = COUNT lessons WHERE courseId = course.id
        completed_lessons = COUNT lessonProgress:
          WHERE enrollmentId = enrollment.id
          AND status = "completed"
        progress_pct = (completed_lessons / total_lessons) * 100
        compliant = progress_pct >= 100
      ELSE:
        progress_pct = 0
        compliant = false

      APPEND mandatory_completion:
        user_name: user.name,
        team_name: team?.name ?? "No Team",
        course_name: course.title,
        progress_pct: ROUND(progress_pct, 1),
        compliant: compliant

  // Section 3: Certification Status
  certification_status = []

  FOR EACH user_id IN user_ids:
    user = FETCH users(user_id)
    team = QUERY teamMembers WHERE userId = user_id -> team

    certificates = QUERY certificates WHERE userId = user_id
    FOR EACH cert IN certificates:
      course = FETCH courses(cert.courseId)

      // Check if certificate has expiry (if implemented)
      expiring = false
      IF cert.expiresAt AND cert.expiresAt < (now() + 30 days):
        expiring = true

      APPEND certification_status:
        user_name: user.name,
        team_name: team?.name ?? "No Team",
        course_name: course.title,
        certificate_id: cert.id,
        issued_at: FormatDate(cert.issuedAt),
        expires_at: cert.expiresAt ? FormatDate(cert.expiresAt) : "Never",
        expiring_soon: expiring

  // Generate compliance report
  report_data = {
    organization: organization.name,
    report_period: {
      start: FormatDate(dateRange.start),
      end: FormatDate(dateRange.end)
    },
    generated_at: now(),
    deadline_tracking: {
      on_time: COUNT(deadline_tracking WHERE status = "on_time"),
      at_risk: COUNT(deadline_tracking WHERE status = "at_risk"),
      overdue: COUNT(deadline_tracking WHERE status = "overdue"),
      details: deadline_tracking
    },
    mandatory_training: {
      total_required: COUNT(mandatory_completion),
      compliant: COUNT(mandatory_completion WHERE compliant = true),
      non_compliant: COUNT(mandatory_completion WHERE compliant = false),
      compliance_rate: (COUNT(mandatory_completion WHERE compliant = true) / COUNT(mandatory_completion)) * 100,
      details: mandatory_completion
    },
    certification_status: {
      total_certificates: COUNT(certification_status),
      expiring_soon: COUNT(certification_status WHERE expiring_soon = true),
      details: certification_status
    }
  }

  // Generate XLSX file
  xlsx = GENERATE_XLSX:
    sheets: [
      {
        name: "Summary",
        data: [
          ["Organization", organization.name],
          ["Report Period", FormatDate(dateRange.start) + " to " + FormatDate(dateRange.end)],
          ["Generated", FormatDate(now())],
          [],
          ["Deadline Tracking"],
          ["On Time", report_data.deadline_tracking.on_time],
          ["At Risk", report_data.deadline_tracking.at_risk],
          ["Overdue", report_data.deadline_tracking.overdue],
          [],
          ["Mandatory Training"],
          ["Compliance Rate", ROUND(report_data.mandatory_training.compliance_rate, 1) + "%"],
          ["Compliant", report_data.mandatory_training.compliant],
          ["Non-Compliant", report_data.mandatory_training.non_compliant],
          [],
          ["Certifications"],
          ["Total Issued", report_data.certification_status.total_certificates],
          ["Expiring Soon", report_data.certification_status.expiring_soon]
        ]
      },
      {
        name: "Deadline Tracking",
        headers: ["Learner", "Team", "Course", "Progress %", "Deadline", "Days Until Deadline", "Status"],
        rows: report_data.deadline_tracking.details
      },
      {
        name: "Mandatory Training",
        headers: ["Learner", "Team", "Course", "Progress %", "Compliant"],
        rows: report_data.mandatory_training.details
      },
      {
        name: "Certifications",
        headers: ["Learner", "Team", "Course", "Certificate ID", "Issued At", "Expires At", "Expiring Soon"],
        rows: report_data.certification_status.details
      }
    ]

  // Upload to storage
  file_id = UPLOAD xlsx TO convex_storage
  download_url = GENERATE_URL(file_id)

  // Save report record
  report = CREATE managerReports:
    organizationId: organizationId,
    createdBy: managerId,
    name: "Compliance Report - " + FormatDate(now()),
    description: "Compliance tracking for " + FormatDate(dateRange.start) + " to " + FormatDate(dateRange.end),
    reportType: "compliance",
    dateRange: dateRange,
    format: "xlsx",
    lastGeneratedFileId: file_id,
    isScheduled: false,
    isActive: true,
    createdAt: now(),
    updatedAt: now()

  // Send report via email
  manager = FETCH users(managerId)
  SEND email via Brevo:
    template: "compliance_report_ready"
    to: [{ email: manager.email, name: manager.name }]
    variables: {
      organization_name: organization.name,
      report_period: FormatDate(dateRange.start) + " to " + FormatDate(dateRange.end),
      download_url: download_url,
      compliance_rate: ROUND(report_data.mandatory_training.compliance_rate, 1),
      overdue_count: report_data.deadline_tracking.overdue
    }

  // Log report generation
  CREATE managerAccessLogs:
    managerId: managerId,
    organizationId: organizationId,
    accessType: "export_report",
    timestamp: now()

  RETURN {
    report_id: report.id,
    file_id: file_id,
    download_url: download_url
  }
```

---

### 2.7.6 Manage Privacy Settings (Learner Control)

```pseudocode
FUNCTION ManagePrivacySettings(userId):
  // Fetch current privacy settings
  privacy = FETCH userPrivacySettings(userId)
  IF NOT privacy:
    // Create default settings (B2B defaults to visible)
    user = FETCH users(userId)
    is_b2b = user.organizationId ? true : false

    privacy = CREATE userPrivacySettings:
      userId: userId,
      allowManagerViewScores: is_b2b ? true : false,
      allowManagerViewActivity: is_b2b ? true : false,
      allowManagerViewCertificates: is_b2b ? true : false,
      allowLeaderboardDisplay: false,
      updatedAt: now()

  // Display privacy settings page
  DISPLAY privacy_settings_page:
    title: "Privacy Settings",
    description: "Control what your manager and organization can see about your learning progress",
    settings: [
      {
        name: "Allow Manager View Scores",
        current: privacy.allowManagerViewScores,
        description: "Your manager can see your assessment scores and grades",
        recommended: user.organizationId ? true : false
      },
      {
        name: "Allow Manager View Activity",
        current: privacy.allowManagerViewActivity,
        description: "Your manager can see when you last logged in and completed lessons",
        recommended: user.organizationId ? true : false
      },
      {
        name: "Allow Manager View Certificates",
        current: privacy.allowManagerViewCertificates,
        description: "Your manager can see which certificates you've earned",
        recommended: user.organizationId ? true : false
      },
      {
        name: "Allow Leaderboard Display",
        current: privacy.allowLeaderboardDisplay,
        description: "Your name appears on team leaderboards and rankings",
        recommended: false
      }
    ]

  // Update settings when user changes
  WHEN user.updates(setting_name, new_value):
    VALIDATE new_value IS Boolean

    SWITCH setting_name:
      CASE "allowManagerViewScores":
        UPDATE privacy.allowManagerViewScores = new_value
      CASE "allowManagerViewActivity":
        UPDATE privacy.allowManagerViewActivity = new_value
      CASE "allowManagerViewCertificates":
        UPDATE privacy.allowManagerViewCertificates = new_value
      CASE "allowLeaderboardDisplay":
        UPDATE privacy.allowLeaderboardDisplay = new_value

    UPDATE privacy.updatedAt = now()

    SHOW notification "Privacy settings updated"

  // Export data (GDPR Right to Access)
  WHEN user.clicks(ExportMyData):
    TRIGGER ExportUserData(userId)

  // Delete data (GDPR Right to Erasure)
  WHEN user.clicks(DeleteMyData):
    SHOW confirmation_modal:
      title: "Delete All Data?"
      message: "This will permanently delete your learning records. This action cannot be undone."
      warning: "If you are enrolled through your organization, you may need approval."

    IF user.confirms:
      IF user.organizationId:
        // Request approval from organization admin
        CREATE data_deletion_request:
          userId: userId,
          organizationId: user.organizationId,
          requestedAt: now(),
          status: "pending_approval"
        SEND email to org_admin
        SHOW "Your deletion request has been submitted for approval"
      ELSE:
        // Individual user: immediate deletion
        TRIGGER DeleteUserData(userId)
        SIGN_OUT user
        SHOW "Your data has been deleted"

// Helper function: Export user data
FUNCTION ExportUserData(userId):
  user = FETCH users(userId)

  data_export = {
    user_profile: user,
    enrollments: QUERY enrollments WHERE userId = userId,
    lesson_progress: QUERY lessonProgress WHERE enrollmentId IN (enrollments -> id),
    assessments: QUERY assessmentAttempts WHERE userId = userId,
    certificates: QUERY certificates WHERE userId = userId,
    skill_progress: QUERY skillProgress WHERE userId = userId,
    chat_conversations: QUERY chatConversations WHERE userId = userId,
    office_hours_bookings: QUERY officeHoursBookings WHERE userId = userId,
    privacy_settings: FETCH userPrivacySettings(userId)
  }

  // Generate JSON export
  json_file = JSON.stringify(data_export, indent: 2)
  file_id = UPLOAD json_file TO convex_storage
  download_url = GENERATE_URL(file_id, expiry: 24 hours)

  SEND email via Brevo:
    template: "data_export_ready"
    to: [{ email: user.email, name: user.name }]
    variables: {
      download_url: download_url,
      expiry: "24 hours"
    }

  RETURN download_url
```

---

## Summary

| Flow | Key Components | Edge Cases |
|------|---|---|
| **Pre-Course Assessment** | Eligibility check, question randomization, time limits, auto-save | Attempt limits, timer expiry, duplicate attempts |
| **Post-Course Assessment** | Same questions as pre-course, cohort completion check | No pre-assessment taken, maximum attempts reached |
| **AI-Assisted Grading** | OpenRouter LLM, confidence thresholds, manual review queue | Rate limits, low confidence, timeout errors |
| **Learning Gain Calculation** | Hake's normalized gain formula, skill-level breakdown | Perfect pre-score (ceiling effect), missing assessments |
| **Assessment Report** | Manager permissions, aggregate metrics, PDF/CSV/JSON export | Privacy settings, incomplete data, large datasets |
| **Team Progress Dashboard** | Member-level tracking, privacy controls, status calculation | Privacy opt-outs, inactive learners, stale data |
| **Manager Report Generation** | Report types, scheduled delivery, multiple formats | Permission checks, large exports, email delivery |
| **Learning Reminders** | Target types (individual/team/inactive), multi-channel delivery | Unsubscribe handling, duplicate recipients, privacy |
| **Skills Heat Map** | Team-by-skill matrix, proficiency levels, gap identification | Hidden profiles, skill not started, color coding |
| **Compliance Report** | Deadline tracking, mandatory training, certificate expiry | Missing deadlines, non-compliant users, XLSX generation |
| **Privacy Settings** | GDPR controls, data export, deletion requests | Organizational approval, immediate deletion, export expiry |

---

## Key Design Patterns

### 1. Privacy-First Manager Views
- All manager views check `userPrivacySettings` before displaying sensitive data
- Default B2B visibility: true, B2C visibility: false
- Aggregate metrics shown when individual data is hidden

### 2. Hake's Normalized Gain
- Formula: `(post_score - pre_score) / (100 - pre_score)`
- Interpretation: g ≥ 0.7 (High), 0.3 ≤ g < 0.7 (Medium), g < 0.3 (Low)
- Accounts for ceiling effects and provides standardized ROI metric

### 3. AI-Assisted Grading with Confidence Thresholds
- **High confidence (≥0.9)**: Auto-grade
- **Medium confidence (0.7-0.9)**: Flag for review
- **Low confidence (<0.7)**: Require manual grading
- Fallback to manual grading on API errors

### 4. Scheduled Report Generation
- Reports can be scheduled (daily/weekly/monthly)
- File generated and stored in Convex storage
- Email delivery via Brevo with download link
- Access logs for audit trail

### 5. Multi-Channel Reminders
- Email (via Brevo) + In-app notifications
- Target types: individual, team, behind_schedule, inactive
- Include progress data option for context

### 6. Compliance Tracking
- Deadline tracking with on_time/at_risk/overdue statuses
- Mandatory training completion rates
- Certificate expiry warnings (30 days)
- Multi-sheet XLSX export with summary + details

---

This pseudocode provides a complete reference for implementing the Assessment System and Manager Dashboard features in Project Campfire v2.1.
