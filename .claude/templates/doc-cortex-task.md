---
title: "Task - {{TASK_NAME}}"
created: {{TIMESTAMP}}
type: task
agent: {{AGENT_VARIANT}}
agent_email: {{AGENT_EMAIL}}
nocodb_task: {{NOCODB_TASK_ID}}
status: {{STATUS}}
priority: {{PRIORITY}}
sprint: {{SPRINT_NAME}}
tags: [task, {{CATEGORY}}, {{AGENT_VARIANT}}]
---

# {{TASK_NAME}}

## Objective
{{OBJECTIVE}}

## Acceptance Criteria
{{CRITERIA}}

---

## Planning
### Approach
{{APPROACH}}

### Dependencies
{{DEPENDENCIES}}

### Risks
{{RISKS}}

---

## Progress

### {{DATE}} - Started
- Initial setup and planning

### Actions Taken
1. {{ACTION_1}}
2. {{ACTION_2}}
3. {{ACTION_3}}

### Decisions Made
| Decision | Rationale | Date |
|----------|-----------|------|
| {{DECISION_1}} | {{RATIONALE_1}} | {{DATE}} |

### Blockers
- [ ] {{BLOCKER_1}}

---

## Findings
{{FINDINGS}}

## Learnings
- [[Learning-{{LEARNING_1}}]]
- [[Learning-{{LEARNING_2}}]]

---

## Completion

### Summary
{{SUMMARY}}

### Files Changed
- `{{FILE_1}}` - {{CHANGE_1}}
- `{{FILE_2}}` - {{CHANGE_2}}

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing complete

---

## Metadata
- **NocoDB Task**: #{{NOCODB_TASK_ID}}
- **Agent**: {{AGENT_VARIANT}} ({{AGENT_EMAIL}})
- **Created**: {{CREATED_DATE}}
- **Completed**: {{COMPLETED_DATE}}

#task #{{CATEGORY}} #{{AGENT_VARIANT}} #automated

{: custom-nocodb-task="{{NOCODB_TASK_ID}}" custom-status="{{STATUS}}" custom-agent="{{AGENT_VARIANT}}" }
