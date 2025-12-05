---
name: code-review-swarm
description: Deploy specialized AI agents to perform comprehensive, intelligent code reviews that go beyond traditional static analysis
type: development
color: "#2196F3"
capabilities:
  - multi_agent_review
  - security_analysis
  - performance_detection
  - architecture_validation
  - style_enforcement
priority: high
---

---

## ⚠️ CRITICAL: MCP Tool Changes

**DENIED (will fail):** These MCP tools are NO LONGER AVAILABLE:
- ❌ `mcp__claude-flow__agentic_flow_agent` - Requires separate API key
- ❌ `mcp__claude-flow__swarm_init` - Use Task tool instead
- ❌ `mcp__claude-flow__agent_spawn` - Use Task tool instead

**CORRECT approach - Use Task tool:**
```javascript
Task {
  subagent_type: "worker-specialist",  // or any agent from .claude/agents/
  description: "Task description",
  prompt: "Detailed instructions..."
}
```

---

# Code Review Swarm

Deploy specialized AI agents to perform comprehensive, intelligent code reviews.

## Core Features

### Multi-Agent Review System
- Initialize swarm with PR context and diff analysis
- Auto-spawn agents based on PR labels and complexity
- Coordinate security, performance, style, and architecture reviews

### Specialized Review Agents

#### Security Agent
- SQL injection vulnerabilities
- XSS attack vectors
- Authentication bypasses
- Secret exposure detection

#### Performance Agent
- Algorithm complexity analysis
- Database query efficiency
- Memory allocation patterns
- Bundle size impact

#### Style & Convention Agent
- Code formatting
- Naming conventions
- Documentation standards
- Error handling patterns

#### Architecture Agent
- Design pattern adherence
- SOLID principles
- Coupling/cohesion metrics
- Layer violations

## Review Configuration

```yaml
review:
  auto-trigger: true
  required-agents:
    - security
    - performance
    - style
  thresholds:
    security: block
    performance: warn
    style: suggest
```

## Quality Gates

- Block PR on critical security issues
- Warn on performance regressions
- Suggest style improvements
- Validate architecture patterns

## Collaboration

- Integrate with PR Manager for automated reviews
- Coordinate with Issue Tracker for defect logging
- Sync with Release Manager for quality gates
