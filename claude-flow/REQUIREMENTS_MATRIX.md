# AI Enablement Academy: Requirements Matrix
## Real-Time vs Cache vs Polling - Feature Breakdown

**Last Updated:** December 2, 2025

---

## Executive Matrix

### Quick Reference: What Needs Real-Time

```
🔴 TRUE REAL-TIME (WebSocket) - CRITICAL FEATURES
├── Live Q&A during sessions (<500ms)
├── Real-time polling during sessions (<500ms)
├── Collaborative whiteboards (<500ms)
├── AI copilot streaming responses (<1s)
└── Live chat/community messaging (<1s)

🟡 NEAR-REAL-TIME (SSE) - ENGAGEMENT FEATURES
├── Progress dashboard updates (5-10s)
├── Cohort member activity (5-10s)
├── Quiz score notifications (10-15s)
├── Feedback notifications (10-30s)
├── Course announcements (10-30s)
├── Leaderboard updates (30s)
└── Grade updates (10-30s)

🟢 CACHED/BATCH - CONTENT FEATURES
├── Course lessons (cached 30 days)
├── Course metadata (cached 7 days)
├── Instructor bios (cached 30 days)
├── Course list/catalog (cached 1 day)
├── Video content (CDN-cached)
├── Learning materials (CDN-cached)
├── Student enrollment data (cached 1 hour)
├── B2B seat management (admin-only, cached)
└── Historical analytics (batch-computed)
```

---

## Detailed Feature Matrix

### LIVE SESSIONS (2-Day Workshop)

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Live Q&A** | WebSocket | Socket.IO | <500ms | Medium | $ |
| **Live Polling** | WebSocket | Socket.IO | <500ms | Medium | $ |
| **Attendance Tracking** | WebSocket | Socket.IO | <1s | Low | $ |
| **Instructor Broadcast** | WebSocket | Socket.IO | <500ms | Low | $ |
| **Screen Share Signals** | WebSocket | Socket.IO | <500ms | Medium | $$ |
| **Session Recording Status** | SSE + WebSocket | Mixed | <1s | Medium | $ |
| **Chat During Session** | WebSocket | Socket.IO | <1s | Medium | $$ |
| **Voting/Reactions** | WebSocket | Socket.IO | <500ms | Low | $ |

**Why WebSocket for Sessions:**
- Users expect instant interaction (typing a question and seeing it immediately)
- Bidirectional (instructor and students communicate)
- Reduces friction to engagement (no 5-10s delays)
- Cost justified: only active during live sessions (2-4 hours/day)

**Implementation Priority:** HIGH - Day 1 feature (Session weeks 3-4)

---

### PROGRESS TRACKING (Self-Paced Between Sessions)

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Lesson Completion Status** | SSE | SSE + polling fallback | 5-10s | Low | $ |
| **Progress Bar Update** | SSE | SSE | 5-10s | Low | $ |
| **Quiz Score Display** | SSE | SSE | 10-15s | Low | $ |
| **Certificate Progress** | SSE | SSE | 30s | Low | $ |
| **Time-on-Lesson Tracking** | Cache + Batch | Poll to DB every 30s | 30s | Low | $ |
| **Video Playback Position** | Cache | Local storage sync | Instant locally | Low | $ |
| **Bookmark Management** | HTTP | Standard POST request | 1s | Low | $ |

**Why SSE for Progress:**
- One-way communication (server → student)
- No bidirectional interaction needed
- 10s delay is acceptable (student just finished lesson)
- Lower cost than WebSocket (3-40x cheaper at scale)
- Works in corporate networks that block WebSocket

**Implementation Priority:** CRITICAL - Day 1 feature (Session weeks 1-2)

**Sample SSE Stream:**
```javascript
// Student sees progress update 5-10s after clicking "Complete"
event: progress.update
data: {"lessonId": "101", "completed": true, "percentage": 25, "timestamp": 1701547234}

event: quiz.graded
data: {"quizId": "201", "score": 92, "feedback": "Excellent work!", "timestamp": 1701547240}

event: certificate.progress
data: {"percentComplete": 25, "unlockedAt": null, "timestamp": 1701547245}
```

---

### INSTRUCTOR COHORT DASHBOARD

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Cohort Progress Overview** | SSE | SSE | 30s | Low | $ |
| **Individual Student Progress** | SSE | SSE | 30s | Low | $ |
| **Quiz Performance Stats** | SSE | SSE | 30s | Low | $ |
| **Engagement Metrics** | SSE | SSE | 10-30s | Medium | $ |
| **Who's Online Now** | WebSocket | Socket.IO | <2s | Medium | $$ |
| **Real-Time Sentiment** | WebSocket | Socket.IO + AI | <5s | High | $$$ |
| **Student Struggling Alerts** | SSE | SSE + AI analysis | 30-60s | High | $$ |

**Why SSE Primary, WebSocket Secondary:**
- Instructor reviews dashboard every 5-30 minutes (not constantly watching)
- 30s delay for progress is fine
- WebSocket only for "who's online now" (lower volume of data)
- Real-time sentiment/alerts are expensive (require ML analysis)

**Implementation Priority:** MEDIUM - Session weeks 3-4 (after student dashboard)

**Admin-Only Visibility:**
- All metrics require authentication
- Filter by cohort, section, individual
- Export to CSV/PDF for reporting

---

### NOTIFICATIONS & ALERTS

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Grade Ready Notification** | Event-based | SSE + email | 10-30s | Low | $ |
| **Feedback Posted Alert** | Event-based | SSE + email | 10-30s | Low | $ |
| **Cohort Announcement** | Event-based | SSE + email | 5-10s | Low | $ |
| **Session Reminder** | Scheduled job | Email + in-app | 1 min before | Low | $ |
| **Progress Milestone** | Event-based | SSE + gamification | 30-60s | Low | $ |
| **Instructor Feedback Tagged** | Event-based | SSE + email | 10-20s | Low | $ |
| **Comment on Submission** | Event-based | SSE + email | 10-20s | Low | $ |

**Why Event-Based + SSE:**
- Don't poll for notifications (expensive)
- Trigger on actual events (quiz submitted, grade computed, feedback posted)
- Deliver via SSE (instant in-app) + email (persistent notification)
- All delivered within 30 seconds

**Implementation Priority:** HIGH - Session weeks 5-6 (background jobs)

**Cost Analysis:**
- Event-based: 100K users, 10 notifications/day = 1M events/day = ~$10-50/mo
- Polling every 30s: 100K users, constant polling = 100K servers/sec = $500-2000/mo
- **Savings: 50-100x** by using event-based

---

### COMMUNITY & SOCIAL FEATURES (Future)

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Forum Posts List** | Cached | HTTP + CDN | 1-5s | Low | $ |
| **New Post Notification** | SSE | SSE | 10-30s | Low | $ |
| **Post Comments** | Cached + SSE | HTTP for fetch, SSE for new | 10-30s | Low | $ |
| **Live Discussion During Session** | WebSocket | Socket.IO | <1s | Medium | $$ |
| **Community Chat** | WebSocket | Socket.IO | <1s | High | $$$ |
| **User Presence (who's typing)** | WebSocket | Socket.IO | <500ms | Low | $ |
| **Peer Reviews** | Cached + SSE | HTTP + SSE | 30-60s | Medium | $ |
| **Leaderboard** | Cached | Redis cache | 30-60s | Low | $ |

**Why Mostly Cached/SSE:**
- Forum posts don't need instant updates (users check periodically)
- Live chat only when students actively discussing (not always)
- Peer reviews are asynchronous (not time-sensitive)
- SSE for notifications when others engage with your content

**Implementation Priority:** FUTURE - Post-MVP (post week 8)

**Note:** Community features scale to WebSocket as adoption grows (more active chat).

---

### AI COPILOT / INTELLIGENT ASSISTANT (Future)

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Question Answering** | WebSocket (streaming) | Stream text chunks | <2s first chunk | High | $$$ |
| **Code Review** | WebSocket (streaming) | Stream analysis | <2s first chunk | High | $$$ |
| **Learning Recommendations** | SSE | Server-sent suggestions | 5-10s | Medium | $$ |
| **Writing Feedback** | WebSocket (streaming) | Stream edits/suggestions | <2s first chunk | High | $$$ |
| **Concept Explanations** | WebSocket (streaming) | Stream explanation | <2s first chunk | High | $$$ |
| **Progress Predictions** | Batch | ML model batch job | 1-2 hours | High | $$ |

**Why WebSocket for AI Streaming:**
- Users expect streaming text (like ChatGPT)
- 2-3 second delay is noticeable and frustrating
- Streaming reduces perceived latency (first chunk arrives instantly)
- Bidirectional (student can interrupt, refine questions)

**Why Event-Based for Recommendations:**
- Can be batched/scheduled (compute during off-hours)
- 5-10s delay acceptable (user isn't actively waiting)
- Saves significant compute cost

**Implementation Priority:** FUTURE - Post-MVP with paid AI tier

**Cost Warning:**
- Streaming AI with OpenAI = $0.10-1.00 per response (expensive!)
- May require usage limits or paid tier for students
- Alternative: Cache common questions, reuse responses

---

### B2B SEAT MANAGEMENT & ADMINISTRATION

| Feature | Requirement | Tech | Latency | Complexity | Cost |
|---------|-------------|------|---------|-----------|------|
| **Bulk Enrollment** | Batch | CSV import, background job | 5-10 min | Low | $ |
| **Seat Usage Dashboard** | Cached | Daily refresh | 1 day | Low | $ |
| **Billing Integration** | Cached | Nightly sync | 1 day | Low | $ |
| **License Management** | Cached | HTTP, on-demand update | 1s | Low | $ |
| **User Provisioning** | HTTP + Event | Real-time but admin function | 1-5s | Low | $ |
| **SSO Integration** | HTTP | Real-time, cached per user | Instant | Medium | $ |
| **Usage Analytics** | Batch | Daily/weekly reports | 1 day | Low | $ |

**Why Mostly Cached/Batch:**
- B2B seat management is admin-level function (not hundreds of concurrent users)
- Bulk enrollment happens on schedule (not constantly)
- Billing reconciliation can be nightly
- No user-facing real-time requirement

**Implementation Priority:** MEDIUM - Initial launch with discount from MVP

---

## Cost-Benefit Analysis Table

### Implementation Cost vs User Experience Gain

| Feature | Tech Complexity | Monthly Cost (100 users) | Monthly Cost (1000 users) | UX Improvement | ROI |
|---------|-----------------|------------------------|--------------------------|---|---|
| Progress Dashboard (SSE) | Low | $10-20 | $100-200 | 7/10 | EXCELLENT |
| Live Sessions (WebSocket) | Medium | $20-40 | $400-800 | 9/10 | EXCELLENT |
| Quiz Results (SSE) | Low | $5-10 | $50-100 | 6/10 | EXCELLENT |
| Notifications (Event-based) | Low | $10-20 | $100-200 | 8/10 | EXCELLENT |
| **Cohort Activity (WebSocket)** | Medium | $20-40 | $400-800 | 5/10 | GOOD |
| **Real-time Chat (WebSocket)** | High | $50-100 | $2,000-5,000 | 8/10 | GOOD (future) |
| **AI Copilot Streaming** | High | $100-500 | $2,000-10,000 | 9/10 | DEPENDS ON PRICING |
| **Sentiment Analysis** | High | $50-200 | $1,000-5,000 | 6/10 | MEDIUM |
| **Personalized Recommendations** | High | $50-200 | $1,000-5,000 | 7/10 | MEDIUM |

**Conclusion:**
- **MVP Focus:** Green/Excellent ROI features (progress, sessions, notifications)
- **Future Phases:** Yellow/Medium ROI (chat, copilot, sentiment)
- **Avoid:** Features with poor ROI unless strategically important

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-4) - $200-400/mo
✅ Progress Dashboard (SSE)
✅ Basic Quiz Tracking (SSE)
✅ Lesson Completion (HTTP)
✅ Live Sessions (WebSocket basic)
✅ Session Attendance (WebSocket)

**Not Included:**
- Community features
- AI copilot
- Sentiment analysis
- Advanced analytics

---

### Phase 2: Engagement (Weeks 5-8) - $300-600/mo
✅ Notifications (Event-based)
✅ Q&A During Sessions (WebSocket)
✅ Live Polling (WebSocket)
✅ Instructor Dashboard (SSE)
✅ Grade/Feedback Notifications (Event-based)

**New Complexity:**
- Background job queue (Bull)
- Redis caching layer
- Monitoring & alerting

---

### Phase 3: Intelligence (Months 3-6) - $800-2000/mo
✅ AI Feedback Streaming (WebSocket)
✅ Real-time Engagement Metrics (SSE + AI)
✅ Learning Recommendations (Batch)
✅ Community Forums (Cached)
✅ Discord Integration (Webhooks)

**New Complexity:**
- LLM integration (OpenAI/Claude)
- ML model deployment
- Event streaming (Kafka or similar)

---

### Phase 4: Scale (Months 6-12) - $3000-8000/mo
✅ Multi-Region Deployment
✅ Community Chat (WebSocket)
✅ Collaborative Tools (WebSocket)
✅ Advanced Analytics (Batch)
✅ Personalization Engine

**New Complexity:**
- Database replication
- Global content delivery
- API rate limiting
- Usage-based billing

---

## Technology Stack Recommendations

### MVP Stack (Phase 1-2)

```
Frontend:
- React 18+ (TypeScript)
- SWR or TanStack Query (data fetching)
- Socket.IO client (WebSocket)
- Recharts (dashboards)

Backend:
- Node.js + Express
- Socket.IO (WebSocket server)
- Bull (job queue)
- PostgreSQL (database)
- Redis (cache + queue backend)
- Zod (validation)

Infrastructure:
- AWS EC2 (t3.medium) or Vercel
- AWS RDS (PostgreSQL)
- AWS ElastiCache (Redis)
- CloudFlare (CDN)

Monitoring:
- Datadog (logging, metrics, APM)
- Sentry (error tracking)
- Custom dashboards (Recharts)

Deployment:
- GitHub Actions (CI/CD)
- Docker (containerization)
- Vercel or AWS for hosting
```

---

### Scale Stack (Phase 3-4)

```
Frontend:
- Same as MVP
- Additional: @tanstack/solid-router (better types)

Backend:
- Node.js + Express (frontend/API)
- Python + FastAPI (AI/ML services)
- Go (high-performance services, optional)
- Socket.IO with Redis adapter (clustering)
- Apache Kafka (event streaming)
- PostgreSQL (primary) + read replicas
- Redis cluster (distributed caching)
- Elasticsearch (analytics, search)

Infrastructure:
- Kubernetes (container orchestration)
- AWS RDS (multi-region)
- AWS AppSync OR managed WebSocket service
- CloudFlare (global edge)
- AWS Lambda (serverless functions)

Monitoring:
- Datadog (comprehensive observability)
- PagerDuty (incident response)
- Custom ML dashboards (anomaly detection)
```

---

## Database Schema (PostgreSQL)

```sql
-- Core tables
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  name VARCHAR,
  role ENUM ('student', 'instructor', 'admin'),
  cohort_id UUID REFERENCES cohorts(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE cohorts (
  id UUID PRIMARY KEY,
  name VARCHAR NOT NULL,
  start_date DATE,
  end_date DATE,
  instructor_id UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE lessons (
  id UUID PRIMARY KEY,
  cohort_id UUID REFERENCES cohorts(id),
  title VARCHAR,
  content TEXT,
  video_url VARCHAR,
  order_index INT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Progress tracking
CREATE TABLE student_progress (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES users(id),
  lesson_id UUID REFERENCES lessons(id),
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMP,
  time_spent_seconds INT,
  last_accessed TIMESTAMP,
  UNIQUE(student_id, lesson_id)
);

CREATE TABLE quiz_submissions (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES users(id),
  quiz_id UUID REFERENCES quizzes(id),
  answers JSONB,
  score DECIMAL(5,2),
  submitted_at TIMESTAMP,
  graded_at TIMESTAMP,
  feedback TEXT
);

-- Real-time event log
CREATE TABLE events (
  id UUID PRIMARY KEY,
  event_type VARCHAR NOT NULL,
  user_id UUID REFERENCES users(id),
  cohort_id UUID REFERENCES cohorts(id),
  data JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX (event_type, created_at),
  INDEX (user_id, created_at)
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  recipient_id UUID REFERENCES users(id),
  title VARCHAR,
  message TEXT,
  type VARCHAR, -- 'grade', 'feedback', 'announcement'
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Session tracking
CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  cohort_id UUID REFERENCES cohorts(id),
  instructor_id UUID REFERENCES users(id),
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  recording_url VARCHAR
);

CREATE TABLE session_participants (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES sessions(id),
  student_id UUID REFERENCES users(id),
  joined_at TIMESTAMP,
  left_at TIMESTAMP,
  active BOOLEAN DEFAULT TRUE
);
```

---

## Real-Time Event Schema (Redis/Kafka)

```javascript
// Progress events
{
  type: 'progress.lesson_completed',
  studentId: 'uuid',
  lessonId: 'uuid',
  cohortId: 'uuid',
  completedAt: '2025-12-02T10:30:00Z',
  timeSent: 5400 // seconds
}

// Quiz events
{
  type: 'quiz.submitted',
  studentId: 'uuid',
  quizId: 'uuid',
  cohortId: 'uuid',
  submittedAt: '2025-12-02T10:35:00Z'
}

{
  type: 'quiz.graded',
  studentId: 'uuid',
  quizId: 'uuid',
  cohortId: 'uuid',
  score: 92,
  feedback: 'Great work!',
  gradedAt: '2025-12-02T10:36:00Z'
}

// Session events
{
  type: 'session.qa_submitted',
  sessionId: 'uuid',
  studentId: 'uuid',
  cohortId: 'uuid',
  question: 'How do I...?',
  submittedAt: '2025-12-02T10:40:00Z'
}

{
  type: 'session.poll_voted',
  sessionId: 'uuid',
  studentId: 'uuid',
  pollId: 'uuid',
  choice: 'A',
  votedAt: '2025-12-02T10:41:00Z'
}

// Notification events
{
  type: 'notification.send',
  recipientId: 'uuid',
  title: 'Your quiz is graded!',
  message: 'You scored 92/100',
  notificationType: 'grade',
  sentAt: '2025-12-02T10:36:00Z'
}
```

---

## Success Metrics & SLAs

### Real-Time Feature SLAs

| Feature | Latency SLA | Availability SLA | Error Rate SLA |
|---------|-----------|-----------------|---|
| Progress Dashboard (SSE) | <10s | 99.5% | <0.1% |
| Live Q&A (WebSocket) | <500ms | 99.9% | <0.01% |
| Live Polling (WebSocket) | <500ms | 99.9% | <0.01% |
| Quiz Scoring (SSE) | <15s | 99.5% | <0.1% |
| Notifications (SSE) | <30s | 99% | <0.5% |
| Instructor Dashboard (SSE) | <30s | 99.5% | <0.1% |

### Monitoring Metrics

```
Real-Time Health:
- WebSocket connection success rate (target: >99.5%)
- SSE reconnection rate (target: <1% daily)
- Message delivery latency p95 (target: <500ms for WebSocket, <10s for SSE)
- Peak concurrent connections (capacity planning)
- Message throughput (msgs/sec)

User Experience:
- Page load time (target: <2s)
- Dashboard update latency (target: <10s)
- Error recovery time (target: <30s)
- User satisfaction (NPS tracking)

Infrastructure:
- Server CPU utilization (target: <70%)
- Memory utilization (target: <80%)
- Database query latency p99 (target: <100ms)
- Cache hit rate (target: >90%)
- Network bandwidth usage (trending)
```

---

## Conclusion & Recommendations

### MVP Implementation Priority (12 Weeks)

1. **Week 1-2:** Progress Dashboard with SSE (foundation)
2. **Week 3-4:** Live Sessions with WebSocket (engagement)
3. **Week 5-6:** Notifications with Event-Based Jobs (retention)
4. **Week 7-8:** Instructor Dashboard with SSE (enablement)
5. **Week 9-10:** Testing, Optimization, Monitoring (quality)
6. **Week 11-12:** Production Hardening & Documentation (readiness)

### Go/No-Go Criteria for Production
- All critical path features have <2s response time
- Real-time features have >99.5% availability
- Graceful degradation working for all fallback scenarios
- Load testing shows no issues at 2x expected peak capacity
- Monitoring and alerting configured and tested
- Incident runbooks documented
- Support team trained on troubleshooting

### Post-MVP Roadmap
- **Month 3:** Community forums + Discord integration
- **Month 4:** AI copilot with streaming feedback
- **Month 5:** Real-time engagement analytics
- **Month 6:** Multi-region deployment
- **Month 7:** Advanced personalization engine

