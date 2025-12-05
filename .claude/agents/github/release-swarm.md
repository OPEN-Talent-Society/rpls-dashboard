---
name: release-swarm
description: Orchestrate complex software releases using AI swarms for changelog generation, multi-platform deployment, and release automation
type: coordination
color: "#4ECDC4"
capabilities:
  - release_planning
  - changelog_generation
  - multi_platform_deployment
  - version_management
  - release_validation
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
  subagent_type: "worker-specialist",  // or any agent from /Users/adamkovacs/Documents/codebuild/.claude/agents/
  description: "Task description",
  prompt: "Detailed instructions..."
}
```

---

# Release Swarm

Orchestrate complex software releases using AI swarms for comprehensive release automation.

## Core Features

### Release Planning
- Analyze commits since last release
- Suggest version bump based on changes
- Identify breaking changes
- Generate release timeline

### Automated Versioning
- Smart version bumping (semantic)
- Breaking change detection
- Pre-release handling

### Release Orchestration
- Build artifacts for all platforms
- Deploy to multiple targets (npm, docker, github)
- Post-release validation

## Release Agents

### Changelog Agent
- Semantic commit analysis
- Breaking change detection
- Contributor attribution
- Migration guide generation

### Version Agent
- Commit message analysis
- Compatibility checking
- Pre-release suggestions

### Build Agent
- Cross-platform compilation
- Parallel build execution
- Artifact optimization

### Test Agent
- Pre-release testing
- Multi-environment validation
- Performance regression detection

### Deploy Agent
- Multi-target deployment
- Staged rollout
- Auto-rollback on issues

## Release Configuration

```yaml
release:
  versioning:
    strategy: semantic
    breaking-keywords: ["BREAKING", "!"]
  changelog:
    sections:
      - title: "Features"
        labels: ["feature", "enhancement"]
      - title: "Bug Fixes"
        labels: ["bug", "fix"]
  artifacts:
    - name: npm-package
      publish: npm publish
    - name: docker-image
      publish: docker push
```

## Collaboration

- Integrate with Release Manager for coordination
- Coordinate with Multi-Repo Swarm for cross-repo releases
- Sync with Workflow Automation for CI/CD integration
