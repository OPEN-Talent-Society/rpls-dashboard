# Skills & Resources Library Flows - Pseudocode

## Skills & Competencies Flows

### 2.4.1 Track Skill Progress

```pseudocode
FUNCTION TrackSkillProgress(userId, courseId, competencyId, assessmentScore):
  // Validate course enrollment
  enrollment = FETCH enrollment(userId, courseId)
  IF NOT enrollment OR enrollment.paymentStatus != "completed":
    THROW AccessDeniedError("Not enrolled in course")

  // Get competency details
  competency = FETCH competency(competencyId)
  IF NOT competency:
    THROW NotFoundError("Competency not found")

  skill = FETCH skill(competency.skillId)
  IF NOT skill OR NOT skill.isActive:
    THROW NotFoundError("Skill not found or inactive")

  // Determine if assessment passed
  passed = assessmentScore >= competency.passingThreshold

  // Create competency evidence record
  evidence_id = MUTATION competencyEvidence.insert:
    userId: userId,
    competencyId: competencyId,
    enrollmentId: enrollment.id,
    evidenceType: "instructor_assessment", // or "quiz", "project", "peer_review"
    score: assessmentScore,
    passed: passed,
    evidenceUrl: null,
    notes: null,
    assessedBy: null, // Set if instructor assessment
    createdAt: now()

  // Update or create user skill progress
  existing_progress = QUERY userSkillProgress:
    WHERE userId == userId AND skillId == skill.id
    LIMIT 1

  IF existing_progress:
    // Increment evidence count
    MUTATION userSkillProgress.patch(existing_progress.id):
      evidenceCount: existing_progress.evidenceCount + 1,
      lastAssessedAt: now(),
      updatedAt: now()

    // Calculate new progress percentage
    all_competencies = QUERY competencies:
      WHERE skillId == skill.id AND isActive == true

    passed_evidence = QUERY competencyEvidence:
      WHERE userId == userId AND passed == true
      AND competencyId IN [all_competencies.map(c => c.id)]

    progress_percent = (passed_evidence.count / all_competencies.count) * 100

    // Update progress percentage
    MUTATION userSkillProgress.patch(existing_progress.id):
      progressPercent: progress_percent

    // Check for level advancement
    IF progress_percent >= 90 AND existing_progress.currentLevel == "foundational":
      MUTATION userSkillProgress.patch(existing_progress.id):
        currentLevel: "practitioner",
        progressPercent: 0 // Reset for next level

    ELSE IF progress_percent >= 90 AND existing_progress.currentLevel == "practitioner":
      MUTATION userSkillProgress.patch(existing_progress.id):
        currentLevel: "advanced",
        progressPercent: 0

  ELSE:
    // Create initial progress record
    MUTATION userSkillProgress.insert:
      userId: userId,
      skillId: skill.id,
      currentLevel: "foundational",
      progressPercent: 10, // First evidence
      evidenceCount: 1,
      lastAssessedAt: now(),
      verifiedByInstructor: false,
      createdAt: now(),
      updatedAt: now()

  // Check if user qualifies for skill badge
  IF passed AND existing_progress.progressPercent >= 90:
    TRIGGER IssueSkillBadge(userId, skill.id, existing_progress.currentLevel)

  RETURN {
    evidenceId: evidence_id,
    skillProgress: existing_progress or new_progress,
    passed: passed,
    levelAdvanced: progress_percent >= 90
  }
```

---

### 2.4.2 Award Competency Badge

```pseudocode
FUNCTION IssueSkillBadge(userId, skillId, level):
  // Validate inputs
  skill = FETCH skill(skillId)
  user = FETCH user(userId)

  IF NOT skill OR NOT user:
    THROW NotFoundError("Skill or user not found")

  // Check badge eligibility
  user_progress = QUERY userSkillProgress:
    WHERE userId == userId AND skillId == skillId
    LIMIT 1

  IF NOT user_progress:
    THROW ValidationError("No progress record for this skill")

  IF user_progress.currentLevel != level:
    THROW ValidationError("User not at requested level")

  IF user_progress.progressPercent < 90:
    THROW ValidationError("Insufficient progress (minimum 90%)")

  // Check for existing badge (prevent duplicates)
  existing_badge = QUERY skillBadges:
    WHERE userId == userId
      AND skillId == skillId
      AND level == level
    LIMIT 1

  IF existing_badge:
    RETURN existing_badge.id // Already issued

  // Generate unique badge ID and public URL
  badge_uuid = GENERATE_UUID()
  public_url = "https://aienablement.academy/badges/" + badge_uuid

  // Create Open Badges 3.0 compliant badge data
  badge_data = {
    "@context": "https://www.w3.org/2018/credentials/v1",
    type: ["VerifiableCredential", "OpenBadgeCredential"],
    issuer: {
      id: "https://aienablement.academy",
      name: "AI Enablement Academy"
    },
    issuanceDate: ISO_DATE(now()),
    credentialSubject: {
      id: "mailto:" + user.email,
      achievement: {
        id: public_url,
        name: skill.name + " - " + CAPITALIZE(level),
        description: "Demonstrated " + level + " proficiency in " + skill.name,
        criteria: {
          narrative: skill.description
        }
      }
    }
  }

  // Insert skill badge
  now_timestamp = now()
  one_year_ms = 365 * 24 * 60 * 60 * 1000

  badge_id = MUTATION skillBadges.insert:
    userId: userId,
    skillId: skillId,
    level: level,
    earnedAt: now_timestamp,
    expiresAt: now_timestamp + one_year_ms, // 1 year expiration
    badgeData: badge_data,
    publicUrl: public_url,
    createdAt: now_timestamp

  // Update user progress to mark as verified
  MUTATION userSkillProgress.patch(user_progress.id):
    verifiedByInstructor: true,
    updatedAt: now_timestamp

  // Send badge notification email via Brevo
  SEND email via Brevo:
    template: "skill_badge_earned"
    to: [{ email: user.email, name: user.name }]
    variables: {
      badge_name: skill.name + " - " + CAPITALIZE(level),
      badge_url: public_url,
      share_linkedin: GENERATE_LINKEDIN_SHARE_URL(badge_data),
      share_twitter: GENERATE_TWITTER_SHARE_URL(badge_data),
      expiry_date: FORMAT_DATE(now_timestamp + one_year_ms)
    }

  RETURN badge_id
```

---

### 2.4.3 Generate Skill Profile

```pseudocode
FUNCTION GenerateUserSkillProfile(userId):
  // Fetch all user skill progress
  progress_records = QUERY userSkillProgress:
    WHERE userId == userId
    ORDER BY updatedAt DESC

  IF progress_records.count == 0:
    RETURN {
      total: 0,
      byCategory: {},
      allSkills: [],
      badges: [],
      recommendations: []
    }

  // Build detailed skill profile
  skills_with_progress = []

  FOR EACH progress IN progress_records:
    skill = FETCH skill(progress.skillId)
    IF NOT skill:
      CONTINUE

    // Get earned badges for this skill
    badges = QUERY skillBadges:
      WHERE userId == userId AND skillId == skill.id
      ORDER BY earnedAt DESC

    // Get competencies for this skill
    competencies = QUERY competencies:
      WHERE skillId == skill.id AND isActive == true

    // Get evidence for each competency
    competency_details = []
    FOR EACH comp IN competencies:
      evidence = QUERY competencyEvidence:
        WHERE userId == userId AND competencyId == comp.id

      passed_count = COUNT evidence WHERE passed == true

      competency_details.PUSH({
        competencyId: comp.id,
        competencyName: comp.name,
        evidenceCount: evidence.count,
        passedCount: passed_count,
        passingThreshold: comp.passingThreshold,
        completed: passed_count > 0
      })

    skills_with_progress.PUSH({
      skill: skill,
      progress: progress,
      badges: badges,
      competencies: competency_details,
      completionPercent: (competency_details.filter(c => c.completed).length / competency_details.length) * 100
    })

  // Group by category
  by_category = {}
  FOR EACH item IN skills_with_progress:
    category = item.skill.category
    IF NOT by_category[category]:
      by_category[category] = []
    by_category[category].PUSH(item)

  // Get all earned badges across all skills
  all_badges = QUERY skillBadges:
    WHERE userId == userId
    ORDER BY earnedAt DESC

  // Calculate category statistics
  category_stats = {}
  FOR category, skills IN by_category:
    total_skills = skills.length
    avg_completion = SUM(skills.map(s => s.completionPercent)) / total_skills
    total_badges = SUM(skills.map(s => s.badges.length))

    category_stats[category] = {
      total: total_skills,
      avgCompletion: avg_completion,
      badges: total_badges
    }

  RETURN {
    total: progress_records.count,
    byCategory: by_category,
    categoryStats: category_stats,
    allSkills: skills_with_progress,
    badges: all_badges,
    lastUpdated: MAX(progress_records.map(p => p.updatedAt))
  }
```

---

### 2.4.4 Suggest Next Skill (AI-Driven)

```pseudocode
FUNCTION SuggestNextSkill(userId):
  // Get user's current skill progress
  user_progress = QUERY userSkillProgress:
    WHERE userId == userId

  user_skill_ids = SET(user_progress.map(p => p.skillId))
  user_skill_levels = MAP user_progress TO { skillId: currentLevel }

  // Get all active skills
  all_skills = QUERY skills:
    WHERE isActive == true
    ORDER BY sortOrder ASC

  suggestions = []

  FOR EACH skill IN all_skills:
    current_level = user_skill_levels[skill.id] OR "none"

    // Check if prerequisites are met
    prerequisites_met = true

    IF skill.prerequisites AND skill.prerequisites.length > 0:
      FOR prereq_id IN skill.prerequisites:
        prereq_level = user_skill_levels[prereq_id]

        IF NOT prereq_level OR prereq_level == "none":
          prerequisites_met = false
          BREAK

    IF NOT prerequisites_met:
      CONTINUE // Skip this skill

    // Determine if skill should be suggested
    should_suggest = false
    next_level = null

    IF current_level == "none":
      // User hasn't started - suggest if foundational
      IF skill.level == "foundational":
        should_suggest = true
        next_level = "foundational"

    ELSE IF current_level == "foundational" AND skill.level == "practitioner":
      // User can advance to practitioner
      should_suggest = true
      next_level = "practitioner"

    ELSE IF current_level == "practitioner" AND skill.level == "advanced":
      // User can advance to advanced
      should_suggest = true
      next_level = "advanced"

    ELSE IF current_level == "advanced" AND skill.level == "expert":
      // User can advance to expert
      should_suggest = true
      next_level = "expert"

    IF should_suggest:
      // Find courses that teach this skill
      course_skills = QUERY courseSkills:
        WHERE skillId == skill.id

      courses = []
      FOR course_skill IN course_skills:
        course = FETCH course(course_skill.courseId)
        IF course AND course.status == "published":
          courses.PUSH(course)

      // Calculate recommendation score
      score = 0

      // Higher score for skills user hasn't started
      IF current_level == "none":
        score += 100

      // Higher score for more available courses
      score += courses.length * 10

      // Higher score for foundational skills
      IF skill.level == "foundational":
        score += 50

      // Higher score for skills in user's strongest category
      user_category_counts = COUNT_BY_CATEGORY(user_progress)
      strongest_category = MAX_KEY(user_category_counts)
      IF skill.category == strongest_category:
        score += 30

      suggestions.PUSH({
        skill: skill,
        currentLevel: current_level,
        nextLevel: next_level,
        prerequisitesMet: prerequisites_met,
        availableCourses: courses,
        score: score
      })

  // Sort by recommendation score (highest first)
  suggestions.SORT((a, b) => b.score - a.score)

  // Get user enrollments to personalize recommendations
  user_enrollments = QUERY enrollments:
    WHERE userId == userId AND paymentStatus == "completed"

  completed_course_ids = SET(user_enrollments.map(e => e.courseId))

  // Filter out courses user is already enrolled in
  FOR suggestion IN suggestions:
    suggestion.availableCourses = suggestion.availableCourses.FILTER(
      course => NOT completed_course_ids.has(course.id)
    )

  RETURN {
    suggestions: suggestions.SLICE(0, 5), // Top 5 recommendations
    userSkillCount: user_progress.count,
    totalSkillsAvailable: all_skills.count
  }
```

---

## Resource Library Flows

### 2.4.5 Browse Resource Library

```pseudocode
FUNCTION BrowseResourceLibrary(userId, filters):
  // Validate access
  user = FETCH user(userId)
  IF NOT user:
    access_level = "public" // Anonymous user
  ELSE:
    // Determine user's access level
    has_enrollment = QUERY enrollments:
      WHERE userId == userId AND paymentStatus == "completed"
      LIMIT 1

    IF has_enrollment:
      access_level = "enrolled"
    ELSE:
      access_level = "registered"

  // Build query with filters
  query = QUERY resources:
    WHERE isActive == true

  // Apply access control filter
  IF access_level == "public":
    query = query.WHERE accessLevel == "public"
  ELSE IF access_level == "registered":
    query = query.WHERE accessLevel IN ["public", "registered"]
  ELSE IF access_level == "enrolled":
    query = query.WHERE accessLevel IN ["public", "registered", "enrolled"]
    // Also include course-specific resources for user's courses
    user_course_ids = GET_USER_COURSE_IDS(userId)
    query = query.OR(
      accessLevel == "course_specific" AND courseIds CONTAINS_ANY user_course_ids
    )

  // Apply type filter
  IF filters.type:
    query = query.WHERE type == filters.type

  // Apply category filter
  IF filters.category:
    query = query.WHERE category == filters.category

  // Apply search query
  IF filters.search:
    query = query.SEARCH("search_resources", filters.search)

  // Apply sorting
  IF filters.sortBy == "popular":
    query = query.ORDER BY downloadCount DESC
  ELSE IF filters.sortBy == "recent":
    query = query.ORDER BY createdAt DESC
  ELSE IF filters.sortBy == "rating":
    query = query.ORDER BY rating DESC
  ELSE:
    query = query.ORDER BY sortOrder ASC, createdAt DESC

  // Pagination
  page = filters.page OR 1
  page_size = filters.pageSize OR 20
  offset = (page - 1) * page_size

  resources = query.LIMIT(page_size).OFFSET(offset).collect()
  total_count = query.count()

  // Fetch user bookmarks
  user_bookmarks = []
  IF userId:
    user_bookmarks = QUERY userBookmarks:
      WHERE userId == userId AND resourceType == "resource"

  bookmarked_ids = SET(user_bookmarks.map(b => b.resourceId))

  // Enrich resources with user context
  enriched_resources = []
  FOR resource IN resources:
    enriched_resources.PUSH({
      ...resource,
      isBookmarked: bookmarked_ids.has(resource.id),
      canAccess: true // Already filtered by access level
    })

  // Get category counts for filter UI
  category_counts = AGGREGATE resources GROUP BY category:
    COUNT(*)

  RETURN {
    resources: enriched_resources,
    totalCount: total_count,
    page: page,
    pageSize: page_size,
    totalPages: CEIL(total_count / page_size),
    categoryCounts: category_counts,
    userAccessLevel: access_level
  }
```

---

### 2.4.6 Search Glossary Terms

```pseudocode
FUNCTION SearchGlossaryTerms(searchQuery, filters):
  // Build base query
  IF searchQuery AND searchQuery.length > 0:
    // Full-text search
    query = SEARCH glossaryTerms.search_glossary(searchQuery)
  ELSE:
    // Browse all terms
    query = QUERY glossaryTerms:
      WHERE isActive == true

  // Apply category filter
  IF filters.category:
    query = query.WHERE category == filters.category

  // Sort alphabetically by default
  query = query.ORDER BY term ASC

  terms = query.collect()

  // Get related terms for each result
  enriched_terms = []
  FOR term IN terms:
    // Fetch related terms
    related_terms = []
    IF term.relatedTermIds AND term.relatedTermIds.length > 0:
      FOR related_id IN term.relatedTermIds:
        related = FETCH glossaryTerm(related_id)
        IF related AND related.isActive:
          related_terms.PUSH({
            id: related.id,
            term: related.term,
            slug: related.slug,
            abbreviation: related.abbreviation
          })

    // Fetch related skills
    related_skills = []
    IF term.skillIds AND term.skillIds.length > 0:
      FOR skill_id IN term.skillIds:
        skill = FETCH skill(skill_id)
        IF skill AND skill.isActive:
          related_skills.PUSH({
            id: skill.id,
            name: skill.name,
            slug: skill.slug,
            category: skill.category
          })

    enriched_terms.PUSH({
      ...term,
      relatedTerms: related_terms,
      relatedSkills: related_skills
    })

  // Get category list for filters
  categories = AGGREGATE glossaryTerms WHERE isActive == true:
    DISTINCT category
    ORDER BY category ASC

  RETURN {
    terms: enriched_terms,
    totalCount: terms.count,
    categories: categories
  }
```

---

### 2.4.7 Use Prompt Template

```pseudocode
FUNCTION UsePromptTemplate(userId, templateId):
  // Fetch template
  template = FETCH promptTemplate(templateId)
  IF NOT template OR NOT template.isActive:
    THROW NotFoundError("Prompt template not found")

  // Check access permissions
  user = FETCH user(userId)

  IF template.accessLevel == "public":
    can_access = true
  ELSE IF template.accessLevel == "registered":
    can_access = user != null
  ELSE IF template.accessLevel == "enrolled":
    // Check if user has any course enrollment
    enrollment = QUERY enrollments:
      WHERE userId == userId AND paymentStatus == "completed"
      LIMIT 1
    can_access = enrollment != null
  ELSE IF template.accessLevel == "course_specific":
    // Check if user enrolled in specific courses
    IF NOT template.courseIds OR template.courseIds.length == 0:
      can_access = false
    ELSE:
      user_enrollments = QUERY enrollments:
        WHERE userId == userId
          AND paymentStatus == "completed"
          AND courseId IN template.courseIds
      can_access = user_enrollments.count > 0
  ELSE:
    can_access = false

  IF NOT can_access:
    THROW AccessDeniedError("Insufficient permissions to access this template")

  // Increment use count
  MUTATION promptTemplates.patch(templateId):
    useCount: template.useCount + 1

  // Track interaction
  IF userId:
    MUTATION resourceInteractions.insert:
      userId: userId,
      resourceId: templateId,
      interactionType: "view",
      createdAt: now()

  // Fetch variables for template customization
  variables = []
  IF template.variables AND template.variables.length > 0:
    variables = template.variables

  // Return template with metadata
  RETURN {
    id: template.id,
    title: template.title,
    category: template.category,
    subcategory: template.subcategory,
    prompt: template.prompt,
    variables: variables,
    systemPrompt: template.systemPrompt,
    userPrompt: template.userPrompt,
    examples: template.examples,
    tags: template.tags,
    recommendedModels: template.recommendedModels,
    modelSettings: template.modelSettings,
    useCount: template.useCount + 1,
    rating: template.rating,
    isFeatured: template.isFeatured
  }
```

---

### 2.4.8 Bookmark Resource

```pseudocode
FUNCTION BookmarkResource(userId, resourceType, resourceId, notes):
  // Validate user
  user = FETCH user(userId)
  IF NOT user:
    THROW AuthenticationError("User not authenticated")

  // Validate resource type
  IF resourceType NOT IN ["resource", "glossary", "prompt"]:
    THROW ValidationError("Invalid resource type")

  // Validate resource exists
  resource = null
  IF resourceType == "resource":
    resource = FETCH resource(resourceId)
  ELSE IF resourceType == "glossary":
    resource = FETCH glossaryTerm(resourceId)
  ELSE IF resourceType == "prompt":
    resource = FETCH promptTemplate(resourceId)

  IF NOT resource:
    THROW NotFoundError("Resource not found")

  // Check if already bookmarked
  existing_bookmark = QUERY userBookmarks:
    WHERE userId == userId
      AND resourceType == resourceType
      AND resourceId == resourceId
    LIMIT 1

  IF existing_bookmark:
    // Update notes if provided
    IF notes:
      MUTATION userBookmarks.patch(existing_bookmark.id):
        notes: notes,
        updatedAt: now()

    RETURN {
      bookmarkId: existing_bookmark.id,
      action: "updated"
    }

  // Create new bookmark
  bookmark_id = MUTATION userBookmarks.insert:
    userId: userId,
    resourceType: resourceType,
    resourceId: resourceId,
    notes: notes OR null,
    createdAt: now()

  // Track bookmark interaction
  IF resourceType == "resource":
    MUTATION resourceInteractions.insert:
      userId: userId,
      resourceId: resourceId,
      interactionType: "bookmark",
      createdAt: now()

  RETURN {
    bookmarkId: bookmark_id,
    action: "created"
  }
```

---

### 2.4.9 Track Resource Interaction

```pseudocode
FUNCTION TrackResourceInteraction(userId, resourceId, interactionType, rating):
  // Validate interaction type
  IF interactionType NOT IN ["view", "download", "bookmark", "rate", "share"]:
    THROW ValidationError("Invalid interaction type")

  // Validate resource exists
  resource = FETCH resource(resourceId)
  IF NOT resource:
    THROW NotFoundError("Resource not found")

  // Create interaction record
  interaction_id = MUTATION resourceInteractions.insert:
    userId: userId OR null, // Allow anonymous tracking
    resourceId: resourceId,
    interactionType: interactionType,
    rating: rating OR null, // Only for "rate" interactions
    createdAt: now()

  // Update resource aggregate metrics
  IF interactionType == "view":
    MUTATION resources.patch(resourceId):
      viewCount: resource.viewCount + 1

  ELSE IF interactionType == "download":
    MUTATION resources.patch(resourceId):
      downloadCount: resource.downloadCount + 1

  ELSE IF interactionType == "rate":
    // Validate rating
    IF NOT rating OR rating < 1 OR rating > 5:
      THROW ValidationError("Rating must be between 1 and 5")

    // Calculate new average rating
    existing_ratings = QUERY resourceInteractions:
      WHERE resourceId == resourceId AND interactionType == "rate"

    total_ratings = existing_ratings.count
    sum_ratings = SUM(existing_ratings.map(r => r.rating))
    new_avg_rating = sum_ratings / total_ratings

    MUTATION resources.patch(resourceId):
      rating: new_avg_rating,
      ratingCount: total_ratings

  RETURN {
    interactionId: interaction_id,
    interactionType: interactionType,
    timestamp: now()
  }
```

---

## Summary

| Flow | Key Components | Convex Operations |
|------|---|---|
| **Track Skill Progress** | Competency evidence, progress calculation, level advancement | `competencyEvidence.insert`, `userSkillProgress.patch/insert` |
| **Award Competency Badge** | Open Badges 3.0, verification, Brevo email | `skillBadges.insert`, `userSkillProgress.patch` |
| **Generate Skill Profile** | Category grouping, badge aggregation, completion stats | `userSkillProgress.query`, `skillBadges.query` |
| **Suggest Next Skill** | Prerequisite checking, scoring algorithm, course mapping | `skills.query`, `courseSkills.query`, `enrollments.query` |
| **Browse Resource Library** | Access control, filtering, pagination, bookmarks | `resources.query`, `userBookmarks.query` |
| **Search Glossary Terms** | Full-text search, related terms/skills enrichment | `glossaryTerms.search`, `glossaryTerms.query` |
| **Use Prompt Template** | Access validation, use count tracking, variable extraction | `promptTemplates.query`, `resourceInteractions.insert` |
| **Bookmark Resource** | Duplicate detection, multi-type support (resource/glossary/prompt) | `userBookmarks.insert/patch` |
| **Track Resource Interaction** | View/download/rate/share tracking, aggregate metrics | `resourceInteractions.insert`, `resources.patch` |
