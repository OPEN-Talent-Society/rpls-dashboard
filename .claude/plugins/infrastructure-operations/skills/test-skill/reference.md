# Test Skill Reference

## Skill Format Documentation

Based on testing, here's the working Claude Code skill format:

### Directory Structure
```
.claude/skills/skill-name/
├── SKILL.md (required - YAML frontmatter + markdown)
├── reference.md (optional - this file)
├── examples.md (optional)
├── scripts/ (optional - executable scripts)
│   ├── script.sh
│   └── script.py
└── templates/ (optional - template files)
    └── template.md
```

### SKILL.md Format
```yaml
---
name: skill-name
description: What the skill does and when to use it
---
# Skill Content

Markdown content describing usage, examples, etc.
```

### Key Requirements
- Use lowercase letters, numbers, hyphens only (max 64 chars)
- Scripts must be executable (chmod +x)
- Skill directory name must match the `name` in frontmatter
- Description should include both what it does AND when to use it

### Testing Results
- ✅ Scripts execute correctly from skill directory
- ✅ Both shell and Python scripts work
- ✅ File operations and network testing work
- ❌ Skill tool doesn't recognize skill by name yet (may need restart)

### Notes
- Skills are model-invoked (Claude decides when to use them)
- Different from slash commands (user-invoked)
- Can access files and execute commands
- Templates support variable substitution