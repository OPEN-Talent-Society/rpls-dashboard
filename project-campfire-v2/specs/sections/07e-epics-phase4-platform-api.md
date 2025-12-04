# Phase 4: Platform API

**Duration:** Week 12+
**Focus:** API, MCP, webhooks
**Key Deliverables:** Developer platform, AI agent integration

## Worktree Strategy

Phase 4 consists of two independent streams that can run in parallel:

```
develop
├── worktree/phase4-rest-api    (E4.1) - API stream
└── worktree/phase4-mcp-server  (E4.2) - MCP stream
```

**Branch Naming:** `phase4/<epic>/<area>-<feature>`
**Example:** `phase4/E4.1/api-rate-limiting`

---

## E4.1 - REST API

**Owner:** Backend Lead
**Duration:** 5 days
**Priority:** P2 - Ecosystem Growth
**Branch:** `phase4/E4.1/api-rest`

**User Story:**
> As a developer, I need a REST API to integrate the academy platform with external systems so that I can automate workflows.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E4.1-001 | Design API endpoint structure | `DOCS` | 2 | - | - | - |
| E4.1-002 | Create API key table and mutations | `BACKEND` `DB` | 2 | - | E0.3 | - |
| E4.1-003 | Implement API key generation | `BACKEND` | 1.5 | ✅ | E4.1-002 | - |
| E4.1-004 | Implement API key validation middleware | `BACKEND` | 2 | - | E4.1-002 | - |
| E4.1-005 | Implement scope-based permissions | `BACKEND` | 2 | - | E4.1-004 | - |
| E4.1-006 | GET /api/courses (public) | `API` `BACKEND` | 1.5 | ✅ | E4.1-001 | - |
| E4.1-007 | GET /api/courses/:id (public) | `API` `BACKEND` | 1 | ✅ | E4.1-006 | - |
| E4.1-008 | GET /api/cohorts/:courseId (public) | `API` `BACKEND` | 1.5 | ✅ | E4.1-006 | - |
| E4.1-009 | GET /api/verify/:certificateId (public) | `API` `BACKEND` | 1.5 | ✅ | E2.4-009 | - |
| E4.1-010 | POST /api/enrollments (authenticated) | `API` `BACKEND` | 2.5 | - | E4.1-004 | - |
| E4.1-011 | GET /api/enrollments/:userId (authenticated) | `API` `BACKEND` | 1.5 | ✅ | E4.1-004 | - |
| E4.1-012 | POST /api/waitlist (authenticated) | `API` `BACKEND` | 1.5 | ✅ | E4.1-004 | - |
| E4.1-013 | GET /api/users/me (authenticated) | `API` `BACKEND` | 1 | ✅ | E4.1-004 | - |
| E4.1-014 | POST /api/courses (admin) | `API` `BACKEND` | 2 | - | E4.1-005 | - |
| E4.1-015 | PATCH /api/courses/:id (admin) | `API` `BACKEND` | 1.5 | ✅ | E4.1-014 | - |
| E4.1-016 | DELETE /api/courses/:id (admin) | `API` `BACKEND` | 1 | ✅ | E4.1-014 | - |
| E4.1-017 | POST /api/cohorts (admin) | `API` `BACKEND` | 2 | ✅ | E4.1-005 | - |
| E4.1-018 | GET /api/analytics (admin) | `API` `BACKEND` | 2 | - | E4.1-005 | - |
| E4.1-019 | Implement rate limiting (Upstash Redis) | `BACKEND` `DEVOPS` | 3 | - | E4.1-004 | - |
| E4.1-020 | Add rate limit headers to responses | `BACKEND` | 1 | ✅ | E4.1-019 | - |
| E4.1-021 | Implement pagination for list endpoints | `BACKEND` | 2 | - | E4.1-006 | - |
| E4.1-022 | Configure CORS for allowed origins | `BACKEND` `DEVOPS` | 1 | ✅ | E4.1-001 | - |
| E4.1-023 | Create standard error response format | `BACKEND` | 1.5 | - | E4.1-001 | - |
| E4.1-024 | Generate OpenAPI 3.0 spec | `DOCS` | 3 | - | E4.1-018 | - |
| E4.1-025 | Setup Swagger UI at /api/docs | `FRONTEND` `DEVOPS` | 2 | - | E4.1-024 | - |
| E4.1-026 | Write code examples (curl, JS, Python) | `DOCS` | 2.5 | ✅ | E4.1-024 | - |
| E4.1-027 | API E2E tests | `TESTING` | 3 | - | E4.1-025 | - |

**Area Legend:**
- `API` - REST endpoint implementation
- `BACKEND` - Business logic, middleware
- `FRONTEND` - Swagger UI
- `DB` - API key storage
- `DEVOPS` - Redis, CORS config
- `DOCS` - OpenAPI, examples
- `TESTING` - E2E tests

**Parallel Streams:**
- **Stream A (Auth):** E4.1-002 → E4.1-003/004 → E4.1-005
- **Stream B (Public):** E4.1-006 → E4.1-007/008/009 (all parallel)
- **Stream C (Authenticated):** E4.1-010 → E4.1-011/012/013 (parallel after E4.1-004)
- **Stream D (Admin):** E4.1-014 → E4.1-015/016/017/018
- **Stream E (Infrastructure):** E4.1-019 → E4.1-020/021

**Acceptance Criteria:**
- [ ] All endpoints return correct responses
- [ ] Authentication rejects invalid API keys
- [ ] Rate limiting returns 429 Too Many Requests
- [ ] CORS configured for allowed origins
- [ ] Error responses follow standard format
- [ ] API docs accessible at /api/docs
- [ ] Pagination works on list endpoints

**Dependencies:** E0.3 (Database - all queries)
**Risks:** API abuse (implement strict rate limits)

---

## E4.2 - MCP Server

**Owner:** Backend Lead
**Duration:** 4 days
**Priority:** P3 - Innovation
**Branch:** `phase4/E4.2/api-mcp`

**User Story:**
> As an AI agent, I need an MCP server to interact with the academy platform so that I can assist users with course enrollment and information.

### Thin-Sliced Tasks

| ID | Task | Area | Hours | Parallel | Dependencies | Assignee |
|----|------|------|-------|----------|--------------|----------|
| E4.2-001 | Setup MCP server project structure | `BACKEND` | 1.5 | - | E0.1 | - |
| E4.2-002 | Implement @modelcontextprotocol/sdk integration | `BACKEND` `AI/ML` | 2 | - | E4.2-001 | - |
| E4.2-003 | Implement list_courses tool | `BACKEND` `AI/ML` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-004 | Implement search_courses tool | `BACKEND` `AI/ML` | 2 | ✅ | E4.2-002 | - |
| E4.2-005 | Implement get_cohorts tool | `BACKEND` `AI/ML` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-006 | Implement enroll_user tool | `BACKEND` `AI/ML` | 2.5 | - | E4.2-002 | - |
| E4.2-007 | Implement get_enrollments tool | `BACKEND` `AI/ML` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-008 | Implement ask_chatbot tool | `BACKEND` `AI/ML` | 3 | - | E4.2-002, E2.3 | - |
| E4.2-009 | Define course:// resource handler | `BACKEND` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-010 | Define cohort:// resource handler | `BACKEND` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-011 | Define enrollment:// resource handler | `BACKEND` | 1.5 | ✅ | E4.2-002 | - |
| E4.2-012 | Define certificate:// resource handler | `BACKEND` | 1 | ✅ | E4.2-002 | - |
| E4.2-013 | Implement API key authentication | `BACKEND` | 2 | - | E4.1-004 | - |
| E4.2-014 | Implement scope-based permissions | `BACKEND` | 1.5 | - | E4.2-013 | - |
| E4.2-015 | Implement rate limiting (100/min/client) | `BACKEND` | 2 | - | E4.2-013 | - |
| E4.2-016 | Create example .mcp/config.json | `DOCS` | 1 | ✅ | E4.2-002 | - |
| E4.2-017 | Write tool documentation | `DOCS` | 2 | - | E4.2-008 | - |
| E4.2-018 | Write resource URI documentation | `DOCS` | 1.5 | ✅ | E4.2-017 | - |
| E4.2-019 | Create Claude Desktop setup guide | `DOCS` | 1.5 | ✅ | E4.2-017 | - |
| E4.2-020 | MCP server integration tests | `TESTING` | 2.5 | - | E4.2-019 | - |

**Area Legend:**
- `BACKEND` - MCP server implementation
- `AI/ML` - Tool definitions, LLM integration
- `DOCS` - Setup guides, documentation
- `TESTING` - Integration tests

**Parallel Streams:**
- **Stream A (Setup):** E4.2-001 → E4.2-002
- **Stream B (Tools):** E4.2-003/004/005/006/007/008 (mostly parallel after E4.2-002)
- **Stream C (Resources):** E4.2-009/010/011/012 (all parallel after E4.2-002)
- **Stream D (Auth):** E4.2-013 → E4.2-014/015

**Acceptance Criteria:**
- [ ] MCP server starts and accepts connections
- [ ] All tools execute correctly
- [ ] Resources return correct data
- [ ] Authentication enforced
- [ ] Rate limiting works
- [ ] Documentation includes setup instructions
- [ ] Example .mcp/config.json provided

**Dependencies:** E4.1 (REST API - shares authentication)
**Risks:** MCP spec changes (monitor for updates)

---

## Phase 4 Summary

**Total Duration:** ~9 days (1.8 weeks) sequential, ~6-7 days with parallelization
**Total Tasks:** 47 tasks

### Task Distribution by Area

| Area | Task Count | Total Hours |
|------|------------|-------------|
| `BACKEND` | 28 | ~42h |
| `API` | 14 | ~22h |
| `AI/ML` | 8 | ~14h |
| `DOCS` | 8 | ~13.5h |
| `DEVOPS` | 4 | ~6h |
| `FRONTEND` | 1 | ~2h |
| `DB` | 1 | ~2h |
| `TESTING` | 2 | ~5.5h |
| **Total** | **47 tasks** | **~107h** |

### Parallel Execution Plan

With 2 engineers, Phase 4 compresses to **~6-7 days**:

| Day | Engineer 1 (API) | Engineer 2 (MCP) |
|-----|-----------------|------------------|
| 1-2 | E4.1 Auth + Key mgmt | E4.2 Setup + SDK |
| 3-4 | E4.1 Public endpoints | E4.2 Tools |
| 5 | E4.1 Auth'd + Admin endpoints | E4.2 Resources + Auth |
| 6 | E4.1 Rate limiting + CORS | E4.2 Rate limiting |
| 7 | E4.1 OpenAPI + Docs | E4.2 Documentation + Tests |

### Deliverables:
- ✅ REST API with public, authenticated, and admin endpoints
- ✅ MCP server for AI agent integration
- ✅ API documentation with code examples
- ✅ Rate limiting and authentication
- ✅ OpenAPI 3.0 specification

**Next Phase:** [Phase 5 (ICP Features)](./07f-epics-phase5-icp-features.md) - v2.1 expansion
