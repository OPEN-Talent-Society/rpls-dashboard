# Phase 5: v2.1 ICP-Aligned Features

**Duration:** Week 14+
**Focus:** Skills, resources, paths, community, assessments, manager dashboard
**Key Deliverables:** Complete learning platform with B2B analytics

## Worktree Strategy

Phase 5 enables maximum parallelization with 6 independent epics:

```
develop
├── worktree/phase5-skills       (E5.1) - DB/Backend stream
├── worktree/phase5-resources    (E5.2) - Backend/Frontend stream
├── worktree/phase5-paths        (E5.3) - DB/Backend stream
├── worktree/phase5-community    (E5.4) - Full-stack stream
├── worktree/phase5-assessments  (E5.5) - AI/Backend stream
└── worktree/phase5-manager      (E5.6) - Frontend/Backend stream
```

**Branch Naming:** `phase5/<epic>/<area>-<feature>`
**Example:** `phase5/E5.1/db-skills-taxonomy`

---

## E5.1 - Skills & Competencies System

**Owner:** Backend Lead
**Duration:** 8 days
**Priority:** P1 - ICP Critical
**Branch:** `phase5/E5.1/backend-skills`

**User Story:**
> As a learner, I need to track my skill development with verified credentials so that I can demonstrate my competencies to employers.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.1-001 | Define skills table schema | `DB` | 2 | - | E0.3 | - |
| E5.1-002 | Define competencies table schema | `DB` | 2 | ✅ | E5.1-001 | - |
| E5.1-003 | Define courseSkills junction table | `DB` | 1 | ✅ | E5.1-001 | - |
| E5.1-004 | Define lessonCompetencies junction table | `DB` | 1 | ✅ | E5.1-002 | - |
| E5.1-005 | Define userSkillProgress table | `DB` | 1.5 | ✅ | E5.1-001 | - |
| E5.1-006 | Define competencyEvidence table | `DB` | 1.5 | ✅ | E5.1-002 | - |
| E5.1-007 | Define skillBadges table | `DB` | 1 | ✅ | E5.1-001 | - |
| E5.1-008 | Create skills CRUD mutations | `BACKEND` | 3 | - | E5.1-001 | - |
| E5.1-009 | Create competencies CRUD mutations | `BACKEND` | 2.5 | ✅ | E5.1-002 | - |
| E5.1-010 | Implement course-skill mapping | `BACKEND` | 2 | - | E5.1-003 | - |
| E5.1-011 | Implement skill progress calculation | `BACKEND` | 3 | - | E5.1-005 | - |
| E5.1-012 | Implement competency evidence collection | `BACKEND` | 2.5 | - | E5.1-006 | - |
| E5.1-013 | Generate skill badges (Open Badges 3.0) | `BACKEND` | 3 | - | E5.1-007, E2.4 | - |
| E5.1-014 | Query getUserSkillProfile | `BACKEND` | 2 | - | E5.1-011 | - |
| E5.1-015 | Query getCourseSkillOutcomes | `BACKEND` | 1.5 | ✅ | E5.1-010 | - |
| E5.1-016 | Query getSkillLeaderboard | `BACKEND` | 2 | ✅ | E5.1-011 | - |
| E5.1-017 | Query suggestNextSkill | `BACKEND` `AI/ML` | 2.5 | - | E5.1-014 | - |
| E5.1-018 | Build skills taxonomy admin UI | `FRONTEND` | 3 | - | E5.1-008 | - |
| E5.1-019 | Build course-skill mapping UI | `FRONTEND` | 2.5 | - | E5.1-010 | - |
| E5.1-020 | Build learner skill profile page | `FRONTEND` | 3 | - | E5.1-014 | - |
| E5.1-021 | Build skill progress visualization | `FRONTEND` | 2.5 | ✅ | E5.1-020 | - |
| E5.1-022 | Build skill badge display | `FRONTEND` | 2 | ✅ | E5.1-013 | - |
| E5.1-023 | Implement LinkedIn skill sharing | `FRONTEND` `API` | 2 | - | E5.1-022 | - |
| E5.1-024 | Skills system E2E tests | `TESTING` | 3 | - | E5.1-023 | - |

**Area Legend:**
- `DB` - Schema definitions
- `BACKEND` - Queries, mutations, calculations
- `FRONTEND` - Admin and learner UI
- `AI/ML` - Skill recommendations
- `API` - LinkedIn integration
- `TESTING` - E2E tests

**Acceptance Criteria:**
- [ ] Skills taxonomy with 4 categories defined
- [ ] Competency evidence types (quiz, project, peer review, instructor)
- [ ] Skill progress calculated from completed courses
- [ ] Open Badges 3.0 skill badges generated
- [ ] LinkedIn sharing works
- [ ] Skill suggestions based on learning history

**Dependencies:** E2.4 (Certificates - Open Badges infrastructure)

---

## E5.2 - Resource Library System

**Owner:** Full-Stack Developer
**Duration:** 6 days
**Priority:** P1 - ICP Critical
**Branch:** `phase5/E5.2/fullstack-resources`

**User Story:**
> As a learner, I need access to templates, frameworks, prompts, and reference materials so that I can apply what I've learned.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.2-001 | Define resources table schema | `DB` | 2 | - | E0.3 | - |
| E5.2-002 | Define glossaryTerms table schema | `DB` | 1.5 | ✅ | E5.2-001 | - |
| E5.2-003 | Define prompts table schema | `DB` | 2 | ✅ | E5.2-001 | - |
| E5.2-004 | Define resourceInteractions table | `DB` | 1 | ✅ | E5.2-001 | - |
| E5.2-005 | Define userBookmarks table | `DB` | 1 | ✅ | E5.2-001 | - |
| E5.2-006 | Implement resource CRUD mutations | `BACKEND` | 3 | - | E5.2-001 | - |
| E5.2-007 | Implement tiered access control | `BACKEND` | 2.5 | - | E5.2-006 | - |
| E5.2-008 | Implement glossary CRUD | `BACKEND` | 2 | ✅ | E5.2-002 | - |
| E5.2-009 | Implement prompt library with variables | `BACKEND` | 3 | - | E5.2-003 | - |
| E5.2-010 | Implement prompt variable substitution | `BACKEND` | 2 | - | E5.2-009 | - |
| E5.2-011 | Track resource interactions | `BACKEND` | 1.5 | - | E5.2-004 | - |
| E5.2-012 | Implement bookmark CRUD | `BACKEND` | 1.5 | ✅ | E5.2-005 | - |
| E5.2-013 | Implement full-text search | `BACKEND` | 2.5 | - | E5.2-006 | - |
| E5.2-014 | Build resource library page | `FRONTEND` | 3 | - | E5.2-006 | - |
| E5.2-015 | Build resource type filters | `FRONTEND` | 1.5 | ✅ | E5.2-014 | - |
| E5.2-016 | Build glossary page with tooltips | `FRONTEND` | 2.5 | - | E5.2-008 | - |
| E5.2-017 | Build prompt library UI | `FRONTEND` | 3 | - | E5.2-009 | - |
| E5.2-018 | Build prompt variable input form | `FRONTEND` | 2 | - | E5.2-010 | - |
| E5.2-019 | Build bookmark functionality | `FRONTEND` | 1.5 | ✅ | E5.2-012 | - |
| E5.2-020 | Build admin resource management | `FRONTEND` | 3 | - | E5.2-006 | - |
| E5.2-021 | Resource library E2E tests | `TESTING` | 2.5 | - | E5.2-020 | - |

**Acceptance Criteria:**
- [ ] 10 resource types supported
- [ ] Tiered access (public → enrolled → course-specific → premium)
- [ ] Prompt library with {{variable}} substitution
- [ ] Glossary terms with tooltips
- [ ] User bookmarks and interaction tracking
- [ ] Full-text search across resources

---

## E5.3 - Learning Paths System

**Owner:** Backend Lead
**Duration:** 7 days
**Priority:** P1 - ICP Critical
**Branch:** `phase5/E5.3/backend-paths`

**User Story:**
> As a learner, I need curated course sequences so that I can follow a structured journey to mastery.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.3-001 | Define learningPaths table schema | `DB` | 2 | - | E0.3 | - |
| E5.3-002 | Define learningPathSteps table | `DB` | 1.5 | ✅ | E5.3-001 | - |
| E5.3-003 | Define userPathEnrollments table | `DB` | 1.5 | ✅ | E5.3-001 | - |
| E5.3-004 | Define pathCertificates table | `DB` | 1 | ✅ | E5.3-001 | - |
| E5.3-005 | Implement path CRUD mutations | `BACKEND` | 3 | - | E5.3-001 | - |
| E5.3-006 | Implement step sequencing with unlock rules | `BACKEND` | 3 | - | E5.3-002 | - |
| E5.3-007 | Implement unlock types (immediate, sequential, time-based, completion-based) | `BACKEND` | 3 | - | E5.3-006 | - |
| E5.3-008 | Implement path enrollment | `BACKEND` | 2 | - | E5.3-003 | - |
| E5.3-009 | Implement bundled pricing | `BACKEND` `API` | 3 | - | E5.3-005, E1.2 | - |
| E5.3-010 | Calculate path progress percentage | `BACKEND` | 2 | - | E5.3-008 | - |
| E5.3-011 | Generate path completion certificate | `BACKEND` | 2.5 | - | E5.3-004, E2.4 | - |
| E5.3-012 | Build path catalog page | `FRONTEND` | 3 | - | E5.3-005 | - |
| E5.3-013 | Build path detail page | `FRONTEND` | 3 | - | E5.3-006 | - |
| E5.3-014 | Build path progress visualization | `FRONTEND` | 2.5 | ✅ | E5.3-010 | - |
| E5.3-015 | Build step unlock status UI | `FRONTEND` | 2 | ✅ | E5.3-007 | - |
| E5.3-016 | Build path enrollment flow | `FRONTEND` | 2.5 | - | E5.3-008 | - |
| E5.3-017 | Build admin path management | `FRONTEND` | 3 | - | E5.3-005 | - |
| E5.3-018 | Learning paths E2E tests | `TESTING` | 3 | - | E5.3-017 | - |

**Acceptance Criteria:**
- [ ] Sequential course unlocking works
- [ ] 4 unlock types implemented
- [ ] Bundled pricing with discounts
- [ ] Progress tracking across multiple courses
- [ ] Path completion certificates generated

---

## E5.4 - Community System

**Owner:** Full-Stack Developer
**Duration:** 6 days
**Priority:** P1 - High Value
**Branch:** `phase5/E5.4/fullstack-community`

**User Story:**
> As a learner, I need cohort-specific discussion threads and peer connections so that I can engage with my learning community.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.4-001 | Define discussionThreads table | `DB` | 2 | - | E0.3 | - |
| E5.4-002 | Define discussionReplies table | `DB` | 1.5 | ✅ | E5.4-001 | - |
| E5.4-003 | Define threadInteractions table | `DB` | 1 | ✅ | E5.4-001 | - |
| E5.4-004 | Define peerConnections table | `DB` | 1.5 | ✅ | E5.4-001 | - |
| E5.4-005 | Define externalCommunityLinks table | `DB` | 1 | ✅ | E5.4-001 | - |
| E5.4-006 | Implement thread CRUD | `BACKEND` | 2.5 | - | E5.4-001 | - |
| E5.4-007 | Implement reply CRUD with nesting | `BACKEND` | 3 | - | E5.4-002 | - |
| E5.4-008 | Implement best answer marking | `BACKEND` | 1.5 | ✅ | E5.4-007 | - |
| E5.4-009 | Implement thread scoping (course/session/lesson) | `BACKEND` | 2 | - | E5.4-006 | - |
| E5.4-010 | Implement real-time subscriptions | `BACKEND` | 2.5 | - | E5.4-007 | - |
| E5.4-011 | Implement moderation workflows | `BACKEND` | 2 | - | E5.4-006 | - |
| E5.4-012 | Implement peer connection system | `BACKEND` | 2.5 | - | E5.4-004 | - |
| E5.4-013 | Implement AI peer recommendations | `BACKEND` `AI/ML` | 3 | - | E5.4-012 | - |
| E5.4-014 | Build discussion thread list | `FRONTEND` | 2.5 | - | E5.4-006 | - |
| E5.4-015 | Build thread detail with replies | `FRONTEND` | 3 | - | E5.4-007 | - |
| E5.4-016 | Build real-time reply updates | `FRONTEND` | 2 | - | E5.4-010 | - |
| E5.4-017 | Build instructor reply highlighting | `FRONTEND` | 1 | ✅ | E5.4-015 | - |
| E5.4-018 | Build peer connections page | `FRONTEND` | 2.5 | - | E5.4-012 | - |
| E5.4-019 | Build moderation admin UI | `FRONTEND` | 2 | - | E5.4-011 | - |
| E5.4-020 | Integrate external community SSO | `BACKEND` `API` | 3 | - | E5.4-005 | - |
| E5.4-021 | Community E2E tests | `TESTING` | 2.5 | - | E5.4-020 | - |

**Acceptance Criteria:**
- [ ] Threads scoped to course/session/lesson
- [ ] Nested replies with real-time updates
- [ ] Instructor replies highlighted
- [ ] Best answer marking works
- [ ] Peer connection recommendations surface
- [ ] External community SSO integration

---

## E5.5 - Assessment System (Pre/Post ROI)

**Owner:** Backend Lead + AI/ML
**Duration:** 7 days
**Priority:** P1 - B2B Critical
**Branch:** `phase5/E5.5/backend-assessments`

**User Story:**
> As an L&D manager, I need pre/post assessments with learning gain metrics so that I can measure ROI.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.5-001 | Define assessments table | `DB` | 2 | - | E0.3 | - |
| E5.5-002 | Define assessmentQuestions table | `DB` | 2 | ✅ | E5.5-001 | - |
| E5.5-003 | Define assessmentAttempts table | `DB` | 1.5 | ✅ | E5.5-001 | - |
| E5.5-004 | Define questionResponses table | `DB` | 1.5 | ✅ | E5.5-002 | - |
| E5.5-005 | Define learningGainAnalytics table | `DB` | 1.5 | ✅ | E5.5-001 | - |
| E5.5-006 | Implement assessment CRUD | `BACKEND` | 3 | - | E5.5-001 | - |
| E5.5-007 | Implement all question types | `BACKEND` | 4 | - | E5.5-002 | - |
| E5.5-008 | Implement auto-grading (MC, T/F, rating) | `BACKEND` | 3 | - | E5.5-007 | - |
| E5.5-009 | Implement AI-assisted grading (open-ended) | `BACKEND` `AI/ML` | 4 | - | E5.5-007 | - |
| E5.5-010 | Calculate Hake's normalized gain | `BACKEND` | 2.5 | - | E5.5-003 | - |
| E5.5-011 | Trigger pre-assessment T-2 days | `BACKEND` | 2 | - | E5.5-006, E1.3 | - |
| E5.5-012 | Trigger post-assessment T+7 days | `BACKEND` | 2 | ✅ | E5.5-011 | - |
| E5.5-013 | Build assessment creation UI | `FRONTEND` | 3.5 | - | E5.5-006 | - |
| E5.5-014 | Build question type editors | `FRONTEND` | 4 | - | E5.5-007 | - |
| E5.5-015 | Build learner assessment interface | `FRONTEND` | 3.5 | - | E5.5-006 | - |
| E5.5-016 | Build results display with feedback | `FRONTEND` | 2.5 | - | E5.5-008 | - |
| E5.5-017 | Build instructor grading interface | `FRONTEND` | 3 | - | E5.5-009 | - |
| E5.5-018 | Build learning gain reports | `FRONTEND` | 3 | - | E5.5-010 | - |
| E5.5-019 | Assessments E2E tests | `TESTING` | 3 | - | E5.5-018 | - |

**Acceptance Criteria:**
- [ ] All question types supported (MC, multi-select, T/F, short answer, rating, open-ended)
- [ ] Pre-assessments sent automatically T-2 days
- [ ] Post-assessments sent T+7 days
- [ ] AI grading with confidence scores
- [ ] Hake's normalized gain calculated
- [ ] Learning gain reports for managers

---

## E5.6 - Manager Dashboard System (B2B)

**Owner:** Frontend Lead
**Duration:** 8 days
**Priority:** P1 - Revenue Critical
**Branch:** `phase5/E5.6/frontend-manager`

**User Story:**
> As an L&D manager, I need a dashboard to track team learning progress, measure ROI, and demonstrate value to leadership.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E5.6-001 | Define organizationManagers table | `DB` | 1.5 | - | E3.1 | - |
| E5.6-002 | Define teams table | `DB` | 1.5 | ✅ | E5.6-001 | - |
| E5.6-003 | Define teamMembers table | `DB` | 1 | ✅ | E5.6-002 | - |
| E5.6-004 | Define organizationAnalytics table | `DB` | 1.5 | ✅ | E5.6-001 | - |
| E5.6-005 | Define teamAnalytics table | `DB` | 1.5 | ✅ | E5.6-002 | - |
| E5.6-006 | Define managerReports table | `DB` | 1.5 | ✅ | E5.6-001 | - |
| E5.6-007 | Define learningReminders table | `DB` | 1 | ✅ | E5.6-001 | - |
| E5.6-008 | Define userPrivacySettings table | `DB` | 1 | ✅ | E5.6-001 | - |
| E5.6-009 | Define managerAccessLogs table | `DB` | 1 | ✅ | E5.6-001 | - |
| E5.6-010 | Implement manager permissions | `BACKEND` | 2.5 | - | E5.6-001 | - |
| E5.6-011 | Implement team CRUD | `BACKEND` | 2.5 | - | E5.6-002 | - |
| E5.6-012 | Implement analytics calculation (daily/weekly/monthly) | `BACKEND` | 4 | - | E5.6-004 | - |
| E5.6-013 | Implement at-risk learner detection | `BACKEND` | 3 | - | E5.6-012 | - |
| E5.6-014 | Implement report generation | `BACKEND` | 3.5 | - | E5.6-006 | - |
| E5.6-015 | Implement scheduled reports | `BACKEND` | 2.5 | - | E5.6-014 | - |
| E5.6-016 | Implement learning reminders | `BACKEND` | 2 | - | E5.6-007 | - |
| E5.6-017 | Implement privacy controls (GDPR) | `BACKEND` | 2 | - | E5.6-008 | - |
| E5.6-018 | Implement access logging | `BACKEND` | 1.5 | - | E5.6-009 | - |
| E5.6-019 | Build manager dashboard layout | `FRONTEND` | 3 | - | E5.6-010 | - |
| E5.6-020 | Build executive summary view | `FRONTEND` | 3 | - | E5.6-012 | - |
| E5.6-021 | Build team comparison view | `FRONTEND` | 2.5 | ✅ | E5.6-020 | - |
| E5.6-022 | Build individual learner view | `FRONTEND` | 2.5 | ✅ | E5.6-020 | - |
| E5.6-023 | Build skills heat map visualization | `FRONTEND` | 3 | - | E5.1-014 | - |
| E5.6-024 | Build at-risk learner alerts | `FRONTEND` | 2 | - | E5.6-013 | - |
| E5.6-025 | Build report builder UI | `FRONTEND` | 3.5 | - | E5.6-014 | - |
| E5.6-026 | Implement PDF/CSV/XLSX export | `FRONTEND` `BACKEND` | 3 | - | E5.6-025 | - |
| E5.6-027 | Build scheduled reports UI | `FRONTEND` | 2 | - | E5.6-015 | - |
| E5.6-028 | Build team management UI | `FRONTEND` | 2.5 | - | E5.6-011 | - |
| E5.6-029 | Build reminder targeting UI | `FRONTEND` | 2 | - | E5.6-016 | - |
| E5.6-030 | Manager dashboard E2E tests | `TESTING` | 4 | - | E5.6-029 | - |

**Acceptance Criteria:**
- [ ] Only authorized managers can access
- [ ] Executive summary with real-time metrics
- [ ] Team comparison and individual views
- [ ] Skills heat map visualization
- [ ] At-risk learners auto-flagged
- [ ] Reports export to PDF/CSV/XLSX
- [ ] Scheduled reports work
- [ ] GDPR-compliant privacy controls

---

## Phase 5 Summary

**Total Duration:** ~42 days (8.4 weeks) sequential, ~14-18 days with 6 parallel streams
**Total Tasks:** ~140 tasks

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `FRONTEND` | ~55 | ~85h |
| `BACKEND` | ~60 | ~95h |
| `DB` | ~35 | ~50h |
| `AI/ML` | ~8 | ~14h |
| `API` | ~5 | ~8h |
| `TESTING` | ~12 | ~20h |
| **Total** | **~140 tasks** | **~272h** |

### Parallel Execution Plan

With 6 engineers (one per epic), Phase 5 compresses to **~14-18 days**:

| Week | E5.1 (Skills) | E5.2 (Resources) | E5.3 (Paths) | E5.4 (Community) | E5.5 (Assessments) | E5.6 (Manager) |
|------|--------------|------------------|--------------|------------------|-------------------|----------------|
| 1 | DB + CRUD | DB + CRUD | DB + CRUD | DB + CRUD | DB + Types | DB + Perms |
| 2 | Progress calc | Access + Search | Unlock rules | Replies + RT | Grading | Analytics |
| 3 | Badges + UI | Prompts + UI | Bundled $ | Peer + Mod | AI grading | Reports |
| 4 | Testing | Testing | Testing | Testing | Testing | Testing |

### Deliverables:
- ✅ Skills & competencies system with Open Badges 3.0
- ✅ Resource library with 10 content types
- ✅ Learning paths with bundled pricing
- ✅ Community system with discussions and peer connections
- ✅ Assessment system with pre/post ROI measurement
- ✅ Manager dashboard with team analytics and reporting

**ICP Value Delivered:**
- **L&D Leaders:** Skills tracking, ROI measurement, manager dashboards
- **Enablement Teams:** Resource library, prompt templates, frameworks
- **Change Managers:** Learning paths, compliance tracking, progress monitoring
