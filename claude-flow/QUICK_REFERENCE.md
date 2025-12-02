# EdTech Real-Time Architecture: Quick Reference Guide
## One-Page Decision Framework

---

## Decision Tree: Real-Time or Not?

```
Does the feature need bidirectional communication?
├── YES: Can instructor/system instantly respond to user?
│   └── YES → WebSocket (e.g., Q&A, polling, chat)
│   └── NO → SSE (e.g., feedback, grade notifications)
├── NO: Is it one-way server → client updates?
│   └── YES → SSE (e.g., progress dashboard, announcements)
│   └── NO → Cached/HTTP (e.g., course content, metadata)
├── NO: Is it infrequent updates (less than once per hour)?
│   └── YES → Cached/HTTP (e.g., course catalog, B2B seats)
│   └── NO → Batch job (e.g., nightly analytics, reports)
```

---

## Technology Quick Pick

### "Which transport should I use?"

```
For Progress Dashboard?
→ SSE (5-10s latency OK, one-way server updates)

For Live Q&A?
→ WebSocket (need <500ms, bidirectional)

For Quiz Scoring?
→ SSE (10-15s latency OK, notification use case)

For Course Content?
→ HTTP + CDN caching (not real-time needed)

For Instructor Notifications?
→ Event-based jobs + SSE delivery (scalable)

For Community Chat?
→ WebSocket (real-time messaging required)

For AI Copilot Responses?
→ WebSocket with streaming (streaming responses)
```

---

## Cost Estimates at Scale

### 100 Concurrent Users
| Architecture | Monthly Cost | Latency |
|-------------|-------------|---------|
| SSE-based | $30-50 | 5-10s |
| WebSocket-based | $50-100 | <500ms |
| Polling-based | $200-500 | 30s |

### 1,000 Concurrent Users
| Architecture | Monthly Cost | Latency |
|-------------|-------------|---------|
| SSE (90%) + WebSocket (10%) | $300-800 | Mixed |
| All WebSocket | $2,000-5,000 | <500ms |
| All Polling | $5,000-15,000 | 30s |

**Lesson:** Hybrid (SSE + WebSocket) saves 60-70% vs all real-time.

---

## Implementation Checklist

### MVP (Weeks 1-6)

**Week 1-2: Foundation**
- [ ] Express + Node.js server setup
- [ ] PostgreSQL database
- [ ] SSE endpoint for progress updates
- [ ] Student dashboard with SSE client
- [ ] Redis caching layer

**Week 3-4: Live Features**
- [ ] Socket.IO WebSocket server
- [ ] Q&A feature (ask, upvote, answer)
- [ ] Live polling feature
- [ ] Instructor broadcast capability
- [ ] Room management (separate cohorts)

**Week 5-6: Notifications & Polish**
- [ ] Bull job queue setup
- [ ] Event-based notification triggers
- [ ] Email notification delivery
- [ ] In-app notification via SSE
- [ ] Instructor dashboard with SSE
- [ ] Load testing & optimization

**Week 7-8: Production Ready**
- [ ] Monitoring setup (Datadog)
- [ ] Error tracking (Sentry)
- [ ] Graceful degradation testing
- [ ] Failover scenario testing
- [ ] Production deployment
- [ ] Documentation & runbooks

---

## Code Skeleton: Key Components

### SSE Progress Dashboard
```javascript
// Server
app.get('/api/stream/progress/:studentId', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');

  const handler = (progress) => {
    res.write(`data: ${JSON.stringify(progress)}\n\n`);
  };

  progressDb.on('change', handler);
  req.on('close', () => progressDb.off('change', handler));
});

// Client
const eventSource = new EventSource('/api/stream/progress/student123');
eventSource.onmessage = (event) => {
  const progress = JSON.parse(event.data);
  updateDashboard(progress);
};
```

### WebSocket Live Q&A
```javascript
// Server
io.on('connection', (socket) => {
  socket.on('qa:ask', (sessionId, question) => {
    const qa = { id: generateId(), question, upvotes: 0 };
    io.to(`session:${sessionId}`).emit('qa:new', qa);
  });

  socket.on('qa:upvote', (sessionId, qaId) => {
    const count = updateUpvotes(qaId);
    io.to(`session:${sessionId}`).emit('qa:upvoted', { qaId, count });
  });
});

// Client
socket.emit('qa:ask', sessionId, 'How do I...?');
socket.on('qa:new', (qa) => displayQuestion(qa));
```

### Event-Based Notification
```javascript
// Trigger notification
async function notifyGradeReady(studentId, quizId, score) {
  await notificationQueue.add({
    studentId,
    type: 'grade-ready',
    message: `Your quiz scored ${score}%`,
  });
}

// Process in background
notificationQueue.process(async (job) => {
  const { studentId, type, message } = job.data;

  // Send via SSE
  await sendSSENotification(studentId, message);

  // Send via email
  await sendEmail(studentId, `New ${type}`, message);

  // Save to database
  await Notification.create({ studentId, type, message });
});
```

---

## Common Pitfalls & How to Avoid

| Pitfall | Symptom | Solution |
|---------|---------|----------|
| Using WebSocket for everything | Server costs 10x higher | Use SSE for 90% of features |
| No graceful degradation | Features break in corporate networks | Implement WebSocket → SSE → polling fallbacks |
| Polling every 10s for updates | Server overloaded, users frustrated | Switch to SSE or event-based |
| Not caching content | Database hammered with same requests | Cache lessons 30 days, metadata 7 days |
| Real-time without monitoring | Silent failures, poor UX | Monitor connections, latency, errors |
| Bidirectional when unidirectional works | Unnecessary complexity | Use SSE for server → client, HTTP for client → server |
| No load testing before launch | Crashes at 2x peak usage | Test at 2-3x expected concurrent users |
| Hardcoded URLs/config | Redeploy for each environment | Use env variables, feature flags |

---

## Feature-to-Technology Mapping

```
✅ PROGRESS DASHBOARD        → SSE
✅ LESSON COMPLETION STATUS  → SSE
✅ QUIZ RESULTS             → SSE
✅ GRADE NOTIFICATIONS      → Event-based + SSE/Email
✅ COURSE ANNOUNCEMENTS     → Event-based + SSE/Email
✅ INSTRUCTOR DASHBOARD     → SSE
✅ COHORT ACTIVITY          → SSE (or WebSocket if interactive)
✅ LEADERBOARD              → SSE (refresh every 30-60s)

✅ LIVE Q&A                 → WebSocket
✅ LIVE POLLING             → WebSocket
✅ SESSION ATTENDANCE       → WebSocket
✅ INSTRUCTOR BROADCAST     → WebSocket
✅ LIVE CHAT                → WebSocket
✅ AI COPILOT STREAMING     → WebSocket

✅ COURSE CONTENT           → HTTP + CDN Caching
✅ COURSE METADATA          → HTTP + Caching
✅ B2B SEAT MANAGEMENT      → HTTP (admin-only)
✅ ENROLLMENT DATA          → HTTP + Cache
✅ ANALYTICS REPORTS        → Batch job + HTTP
```

---

## Performance Targets

| Metric | Target | How to Monitor |
|--------|--------|---|
| SSE latency (p95) | <10s | Time from event to client receive |
| WebSocket latency (p95) | <500ms | Time from send to confirmation |
| Connection success rate | >99.5% | Failed connections / total attempts |
| Error recovery time | <30s | Time from disconnection to reconnection |
| Message delivery rate | >99.9% | Confirmed deliveries / sent |
| Server memory per 1K SSE | <50 MB | Memory usage / active connections |
| Server memory per 1K WS | <500 MB | Memory usage / active connections |

---

## Deployment Checklist

Before going live:

- [ ] Load test at 2x peak concurrent users
- [ ] Failover testing (simulate server down)
- [ ] Network interruption recovery testing
- [ ] Database failover testing
- [ ] Cache invalidation working correctly
- [ ] Monitoring & alerts configured
- [ ] Error logging capturing all issues
- [ ] Graceful degradation working
- [ ] Documentation complete
- [ ] Team trained on incident response
- [ ] Rollback procedure documented
- [ ] Feature flags for quick disable

---

## Weekly Monitoring

```
Monday Morning Checklist:
□ Connection success rate >99.5%?
□ Latency p95 within SLA?
□ Error rate <0.1%?
□ Database query time <100ms p99?
□ Cache hit rate >90%?
□ Memory usage stable?
□ No memory leaks overnight?
□ All alerts acknowledged?

Weekly Review:
□ Top 5 errors & fixes
□ Peak concurrent users reached?
□ Latency trends (getting worse?)
□ Cost trends (expected?)
□ User feedback on real-time features
□ Capacity planning for next quarter
```

---

## Troubleshooting Decision Tree

```
"Real-time features are slow"
├── Is latency consistently >SLA?
│   └── YES: Check server CPU/memory, database latency
│   └── NO: Could be client-side (browser, network)
├── Is it only during peak hours?
│   └── YES: Need to scale horizontally (add servers)
│   └── NO: Check for memory leaks or inefficient queries
└── Is it affecting all users or specific cohort?
    └── SPECIFIC: Check if that cohort has unusual load

"Users not receiving updates"
├── Are they using older browser?
│   └── YES: Fallback not working, needs debug
│   └── NO: Check connection status
├── Are they behind corporate proxy?
│   └── YES: WebSocket blocked, should fallback to SSE
│   └── NO: Check server logs for connection drops
└── Are updates in database?
    └── NO: Business logic bug (not real-time issue)
    └── YES: Event not triggering, check event logic

"Server memory constantly growing"
├── Memory leak in Node.js?
│   └── Check for unremoved event listeners
│   └── Check for circular references
├── Too many concurrent connections?
│   └── Calculate: 500KB per SSE + 500KB per WS
│   └── If exceeded, need to scale or optimize
└── Redis filling up?
    └── Check cache eviction policy
    └── Check for expired keys not being cleaned
```

---

## Cost Optimization Tips

1. **Use SSE instead of WebSocket** - 3-40x cheaper
2. **Cache aggressively** - Content 30 days, metadata 7 days
3. **Batch notifications** - Don't send individually, group them
4. **Event-driven, not polling** - Saves 90% of DB queries
5. **Use CDN for content** - Offload from origin server
6. **Compress messages** - Gzip can reduce by 60-80%
7. **Monitor for leaks** - Fix memory leaks, save $$$
8. **Right-size servers** - Not too big (expensive), not too small (slower)
9. **Use managed services** - AWS managed Redis, RDS easier than self-hosted
10. **Feature flags for expensive features** - Enable only for paying customers

---

## Quick Deployment Steps

```bash
# 1. Prepare
git checkout -b real-time/mvp
npm install
npm run test

# 2. Deploy to staging
npm run deploy:staging
npm run test:smoke-staging

# 3. Load test
npm run load-test:staging

# 4. Monitor
# Watch metrics for 1 hour, check for memory leaks, errors

# 5. Deploy to production (gradual)
npm run deploy:prod:canary    # 5% of traffic
npm run monitor:prod:1hour    # Monitor for 1 hour
npm run deploy:prod:shadow    # 50% of traffic
npm run monitor:prod:2hours   # Monitor for 2 hours
npm run deploy:prod:full      # 100% of traffic

# 6. Post-deployment
# Monitor for 24 hours, check for issues
npm run rollback:prod         # If needed

# 7. Success
# Document what worked, add to runbooks
```

---

## References & Resources

**Key Decisions:**
- Use SSE for 90% of real-time features
- Use WebSocket only for interactive/bidirectional
- Cache course content (30 days)
- Event-driven notifications (not polling)
- Test at 2x peak load before launch

**Tools:**
- Socket.IO (WebSocket + fallbacks)
- Node.js + Express (backend)
- PostgreSQL (database)
- Redis (caching + message broker)
- Bull (job queue)
- Datadog (monitoring)

**Implementation Order:**
1. Progress dashboard (SSE)
2. Live sessions (WebSocket)
3. Notifications (Event-based)
4. Instructor dashboard (SSE)
5. Advanced features (ChatGPT, analytics)

**Support:** Reference full analysis at `/Users/adamkovacs/Documents/codebuild/claude-flow/EDTECH_REALTIME_ANALYSIS.md`

