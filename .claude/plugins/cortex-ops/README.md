# Cortex Operations Plugin

Playbook bundle for running Cortex (SiYuan) as the second-brain headquarters. Includes the master agent, task logging skills, and commands for keeping notebooks aligned with repository docs.

## Included Assets
- **Agents**: `cortex-siyuan-ops`
- **Skills**: `cortex-task-log`, `cortex-notebook-curation`
- **Commands**: `/cortex:log-task`, `/cortex:curate`
- **Hooks**: task log notifier stub (ready for MCP/webhook integration)

## Usage
1. Ensure the Cortex MCP server is registered (`mcp/cortex`).
2. Install the plugin locally: `claude plugin install cortex-ops@local` after running `scripts/sync/claude-sync.sh`.
3. Call `/cortex:log-task` after completing work; the skill appends a structured entry and links to supporting artefacts.
4. Run `/cortex:curate` during weekly reviews to triage the inbox, refresh dashboards, and reconcile with `.docs` exports.

The Markdown files are mirrored from `.docs/`—update the canonical sources before regenerating the plugin bundle.
