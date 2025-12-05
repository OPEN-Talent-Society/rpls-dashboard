# doc-ingest

---

name: doc-ingest
description: Knowledge ingestion agent syncing documents between Google Workspace, Docmost, and SiYuan
model: sonnet
color: green
id: doc-ingest
summary: Import/export documents, maintain metadata, and prevent drift between knowledge systems.
status: active
owner: knowledge-ops
last_reviewed_at: 2025-10-28
domains:

- productivity
- knowledge
  tooling:
- google-drive
- docmost
- siyuan

---

# Document Ingestion SOP

#knowledge #automation #runbook #class/runbook

## Responsibilities

- Sync Google Docs → Docmost and maintain canonical version markers.
- Export Docmost Markdown packages → SiYuan bundles via `scripts/sync/siyuan-export.py`.
- Tag documents with metadata (owner, status, review date).
- Run drift detection and raise PRs when differences appear.

## Related Skills

- ​`doc-sync`
- cortex-task-log[^1]
- cortex-notebook-curation[^30]

[^1]: # cortex-task-log

    ---

    name: cortex-task-log
    description: Capture and append structured agent task reports into Cortex via SiYuan APIs.
    status: active
    owner: knowledge-ops
    last_reviewed_at: 2025-11-04
    tags:

    - cortex
    - siyuan
      dependencies:
    - cortex-siyuan-ops
    - doc-sync
      outputs:
    - cortex-task-entry
    - sync-proof

    ---

    # Cortex Task Log Skill

     Operated by Cortex (SiYuan) Operations Agent[^2] and referenced in Cortex (SiYuan) Operations &amp; Usage Guide[^3].

    #skills #cortex #automation #class/skill

    1. Determine the target notebook/page using metadata (project, runbook, or tracker) and create it when missing with `/api/filetree/createDocWithMd`.
    2. Append a timestamped block summarising the task outcome, decisions, links to artefacts, and follow-up actions using `/api/block/appendBlock`.
    3. Tag the entry with responsible agent(s), status, and review date via `/api/block/setBlockAttrs` so dashboards stay current.
    4. Trigger optional notifications or digests (Brevo email, Docmost sync) once the log entry is confirmed.
    5. Record the update in the Git workspace (e.g., `MIGRATION_TASKS.md`) to maintain bidirectional traceability.


[^2]: # cortex-siyuan-ops

    ---

    name: cortex-siyuan-ops
    description: Cortex (SiYuan) steward responsible for knowledge capture, logging automation, and workspace governance.
    model: sonnet
    color: purple
    id: cortex-siyuan-ops
    summary: Maintain Cortex notebooks, log every agent task, and extend SiYuan automations and integrations.
    status: active
    owner: knowledge-ops
    last_reviewed_at: 2025-11-04
    domains:

    - knowledge
    - productivity
      tooling:
    - siyuan
    - cortex-mcp
    - cloudflare-access
    - brevo

    ---

    # Cortex (SiYuan) Operations Agent

     Start with Cortex (SiYuan) Operations &amp; Usage Guide[^3] and Migration Activity Log[^5] for system context.

    #cortex #knowledge #automation #ops #class/agent

    ## Responsibilities

    - Log every completed agent task into Cortex using structured templates and backlinks.
    - Curate notebooks, templates, and automations so Cortex remains the canonical knowledge base.
    - Operate SiYuan API/WebDAV endpoints via the Cortex MCP server for scripted updates.
    - Coordinate backups, token rotation, and environment checks with DevOps operators.
    - Flag gaps between Cortex and Git-based documentation, raising sync tickets when drift appears.

    ## Operating Modes

     Task Logging: Create or locate the relevant project page, append a timestamped summary, and attach source artefacts (Docmost, GitHub, NocoDB links). Knowledge Stewardship: Review daily inbox, archive resolved items, and promote insights to playbooks or trackers (#docsync). Automation Expansion: Prototype SiYuan database blocks, webhooks, and plugin scripts that expose Cortex APIs to other agents. Ops Coordination: Work with DevOps Operations Guide[^10] to keep /srv/cortex healthy, backups current, and credentials rotated.

    ## Related Skills

    - ​`cortex-task-log`
    - ​`cortex-notebook-curation`
    - ​`doc-sync`

    ## Tooling Requirements

    - Valid Cloudflare Access identity or automation service token stored in `/srv/cortex/.env`.
    - ​`SIYUAN_API_TOKEN`​ exported locally (rotate via `/srv/cortex/conf/conf.json`).
    - Cortex MCP server (`mcp/cortex`) installed and registered in Codex/Claude configs.
    - Brevo SMTP sender `cortex@aienablement.academy` for outbound notifications.

    ## Runbook Links

     Cortex (SiYuan) Operations &amp; Usage Guide[^3] Docmost &amp; NocoDB Migration Programme[^4] scripts/sync/siyuan-export.py


[^3]: # cortex-siyuan-system

    ---

    id: cortex-siyuan-system
    title: Cortex (SiYuan) Operations & Usage Guide
    summary: Runbook and usage playbook for the Cortex knowledge system powered by SiYuan on the OCI Docker host.
    status: draft
    owner: ops
    tags:

    - cortex
    - siyuan
    - knowledge
      last_reviewed_at: 2025-11-03

    ---

    # Cortex (SiYuan) Operations & Usage Guide

     Linked resources: Cortex (SiYuan) Operations Agent[^2], Docmost &amp; NocoDB Migration Programme[^4], Migration Activity Log[^5]

    #cortex #knowledge #siyuan #automation

    Cortex is the second-brain workspace for AI Enablement Academy, delivered via [SiYuan](https://github.com/siyuan-note/siyuan) and hosted on the OCI Ampere Docker node. This guide covers day-to-day operations, structure, and workflows so both the agent collective and the human operator can expand, review, and track knowledge from a single hub.

    ## 1. Quick Facts

    - **URL**: `https://cortex.aienablement.academy`
    - **Origin stack**: `/srv/cortex`​ (`docker-compose.yml`​, `.env`​, `workspace/`)
    - **Container**: `cortex-siyuan`​ (`b3log/siyuan:v3.3.6`)
    - **Auth**: Protected solely by GitHub (Cloudflare Access); SiYuan bypasses the code check
    - **API token**: `conf/conf.json`​ → `api.token` (rotate via config update + container recreate; do not commit the value)
    - **WebDAV**: `/webdav/`​ endpoint proxied through Caddy; requires a valid API token in `Authorization: Token ...`
    - **Cloudflare Access**: Locked behind Access app `cortex`​ (allow `*@aienablement.academy` + automation service token)
    - **Login methods**: GitHub OAuth (via Cloudflare Access) or service token headers for automations
    - **SMTP**: Brevo (`smtp-relay.brevo.com:465`) with sender derived from Docmost credentials
    - **Backups**: Included in `ops/backup/backup-doc-platform.sh`​ (workspace tarball + `.env` copy)

    ## 2. Access & Onboarding

    1. **Authenticate via Cloudflare Access**: click “Continue with GitHub” and approve the OAuth flow.
    2. SiYuan loads immediately (code requirement is disabled); create or open your local profile.
    3. Set the interface language (Settings → Appearance) and confirm the workspace path if asked (`/siyuan/workspace`).

    > **Note**: Collaborative access is handled entirely by Cloudflare Access. Add new operators by granting GitHub access under the `cortex` Access app; no SiYuan code changes are required.
    >

    ## 3. Workspace Layout (Recommended)

    SiYuan stores data in `/siyuan/workspace`​ (bind mount to `/srv/cortex/workspace`). Within that directory:

    - ​`assets/`: uploaded files, images, and attachments
    - ​`templates/`: block templates for rapid page creation
    - ​`storage/`: saved searches, layout presets, flashcards
    - ​`snippets/`: code or text snippets
    - Notebook folders (`*.sy` files): actual documents as JSON blocks

    To accelerate adoption, seed notebooks with the following structure:

    |Notebook|Purpose|Suggested sub-pages|
    | ----------| ----------------------------------------------| ------------------------------------------------|
    |​`0-Inbox`|Quick capture, meeting notes, fleeting ideas|Daily notes, voice transcript drops|
    |​`Projects`|Active initiatives with PARA-style grouping|Project dashboards, deliverables, retro|
    |​`Knowledge Base`|Canonical references and research|Playbooks, vendor intel, industry analyses|
    |​`Ops Runbooks`|Operational procedures (`ops/`​, `.docs`)|Stack runbooks, health checks, deployment logs|
    |​`Growth Experiments`|Knowledge expansion tracker|Hypotheses, experiments, insights, learnings|
    |​`Templates`|Document skeletons|Meeting notes, decision records, SOP template|

    ### Capture & Linking Practices

    - Use block references (`((block-id))`) for cross-linking decisions, experiments, and supporting evidence.
    - Create a “Project Tracker” table (SiYuan database block) with fields for owner, phase, metrics, and next review date.
    - Mirror the “knowledge expansion” tracker with columns: `Domain`​, `Goal`​, `Evidence`​, `Next Action`​, `Status`.
    - Embed Docmost/NocoDB URLs or use SiYuan's iframe block to surface external dashboards as context panes.

    ## 4. Programmatic & External Access

    ### 4.1 REST API

    - **Endpoint**: `https://cortex.aienablement.academy/api/*`
    - **Auth header**: `Authorization: Token <api-token>`​ (`api.token`​ in `conf/conf.json`)
    - **Example** – version check:

      ```bash
      curl -X POST https://cortex.aienablement.academy/api/system/version \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Token ${SIYUAN_API_TOKEN}' \
        -d '{}'
      ```
    - **Notes**

      - Reverse proxy (Caddy) forwards all `/api/` requests through Cloudflare Access. Supply the API token and (for automations) the Access service token headers.
      - Responses follow `{ "code": 0, "msg": "", "data": ... }`​ per upstream docs (`API.md`).
      - Use the API for notebooks, documents, block manipulation, SQL queries, and exports.

    ### 4.2 WebDAV

    - **Endpoint**: `https://cortex.aienablement.academy/webdav/`
    - **Auth**: supply both the API token and Cloudflare Access service token headers (Basic auth is ignored by the kernel):

      ```bash
      curl -X PROPFIND https://cortex.aienablement.academy/webdav/data/ \
        -H 'Depth: 1' \
        -H 'Authorization: Token ${SIYUAN_API_TOKEN}' \
        -H 'CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}' \
        -H 'CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}'
      ```
    - Mount from macOS Finder or rclone by injecting the headers (e.g., `rclone --header "Authorization: Token $SIYUAN_API_TOKEN" --header "CF-Access-Client-Id: ..." --header "CF-Access-Client-Secret: ..." `).

    ### 4.3 MCP Tooling (`mcp/cortex`)

     Register the Cortex MCP server in Codex/Claude configs to unlock task logging automation. Available tools: siyuan_request – raw API POST helper for advanced operations. siyuan_list_notebooks – enumerate all notebooks to validate structure before logging tasks. siyuan_export_markdown – pull markdown content for summaries or diffs. siyuan_create_doc – create or upsert a document via /api/filetree/createDocWithMd. siyuan_append_block – append a paragraph, list, or markdown block to an existing page using /api/block/appendBlock. siyuan_set_block_attrs – set attributes (tags, status, due date) on a block for dashboard queries. siyuan_sql_query – run /api/query/sql for reporting dashboards (read-only). Supply CF Access headers (CF-Access-Client-Id/Secret) and SIYUAN_API_TOKEN as environment variables when spawning the server. See Cortex (SiYuan) Operations Agent[^2] for task-log prompts and sample tool call flows. WebDAV exposes data/, conf/, temp/ for remote sync/backup; prefer read-only mounts for automations.

    ### 4.3 Webhooks & Notifications

    - SiYuan does **not** emit outbound webhooks. Options:

      1. Poll the API for recently modified blocks (`/api/block/getRecentUpdatedLimit`) from n8n or custom MCP tooling.
      2. Use the `/api/notification/pushMsg` endpoint in automations to fan out events to Slack/Teams/etc.
      3. For richer triggers, tap into the kernel WebSocket (`/api/system/connect`) and bridge events to n8n.
    - Future work: build a lightweight watcher (Go/Python) that subscribes to the WebSocket channel and forwards normalized webhooks to the automation layer.

    ## 5. MCP Integration Blueprint

    - **Current server**: `mcp/cortex` (TypeScript) registers three tools:

      - ​`siyuan_request` – generic POST helper for any endpoint/payload
      - ​`siyuan_list_notebooks` – lists notebook metadata
      - ​`siyuan_export_markdown` – fetches markdown for a document/block ID
    - **Auth strategy**: server reads `SIYUAN_BASE_URL`​, `SIYUAN_API_TOKEN`​, `CF_ACCESS_CLIENT_ID`​, `CF_ACCESS_CLIENT_SECRET` and applies headers automatically.
    - **Usage**:

      1. ​`cd mcp/cortex && npm install && npm run build`
      2. Launch with `node dist/index.js` (stdio transport).
      3. Register the MCP endpoint in `~/.codex/config.toml`​, `.claude/.claude.json`, etc., so agents can call the tools.
      4. For Claude Z.AI or Claude Code, point `.claude/mcp.json`​ at `scripts/mcp/cortex-mcp.sh`​ (it loads `~/.config/cortex-mcp.env`​ for `SIYUAN_API_TOKEN`​, `CF_ACCESS_CLIENT_ID`​, `CF_ACCESS_CLIENT_SECRET`).
    - **Next steps**:

      - Add path-based lookup/search helpers and write/update support.
      - Publish a short client README (`mcp/cortex/README.md`) once the toolset stabilises.
      - Consider packaging for reuse (npm script or binary) if multiple environments need it.

    ## 6. Content Pipelines

    ### Import from Canonical Docs

    Leverage the existing exporter to move curated docs into Cortex:

    ```bash
    cd /Users/adamkovacs/Documents/codebuild/codex-sandbox/scripts/sync
    python3 siyuan-export.py --upload  # uses SIYUAN_BASE_URL + token when configured
    ```
    Steps:

    1. Ensure `SIYUAN_BASE_URL`​ and `SIYUAN_TOKEN`​ are configured in your shell or `.env`.
    2. Run the exporter to package `.docs` agents/projects/knowledge into a SiYuan-compatible zip.
    3. Upload via the API (`/api/export/importZip`) or use the in-app “Import → SiYuan package”.

    ### Daily Journaling / Meeting Notes

    - Create a `Daily` template with fields for highlights, blockers, metrics, and follow-ups.
    - Schedule a reminder (n8n, calendar) to review the `0-Inbox` notebook and triage into Projects or Knowledge weekly.

    ### Knowledge Expansion Tracker

    - Use a table block with filters for domain (`AI Ops`​, `Automation`, etc.).
    - Attach data sources (Docmost pages, NocoDB views) via hyperlinks.
    - Record learnings as bullet blocks and tag with status (e.g., `#learned`​, `#pending-experiment`).

    ## 7. Operations & Maintenance

    ### Lifecycle Commands

    ```bash
    cd /srv/cortex
    sudo docker compose pull
    sudo docker compose up -d
    sudo docker compose logs -f
    ```
    ### Health Checks

    - Internal: `sudo docker run --rm --network reverse-proxy curlimages/curl:7.88.1 -s -o /dev/null -w "%{http_code}\n" http://cortex-app:6806`​ (expect `401`).
    - External: `curl -I https://cortex.aienablement.academy`​ (HTTP/2 `200`).

    ### SMTP Integration (Brevo)

    Environment keys set in `/srv/cortex/.env`:

    ```
    BREVO_SMTP_HOST=smtp-relay.brevo.com
    BREVO_SMTP_PORT=465
    BREVO_SMTP_USER=...
    BREVO_SMTP_PASS=...
    BREVO_FROM_EMAIL=…
    BREVO_FROM_NAME=AI Enablement Academy
    ```
    A connectivity test already ran (`Cortex SMTP connectivity test`). For future tests:

    ```bash
    set -a; source /srv/cortex/.env; set +a
    python3 /srv/cortex/scripts/send-test-email.py  # create as wrapper if desired
    ```
    ### Backups

    - Nightly timer (`backup-doc-platform.timer`​) now tars `/srv/cortex/workspace`​ and copies `/srv/cortex/.env`​ to `/srv/backups/daily/`.
    - Verify successful runs: `sudo journalctl -u backup-doc-platform.service --since today`.
    - Restore drill: untar into `/srv/cortex/workspace`​ (after stopping container) and relaunch `docker compose up -d`.

    ### TLS & DNS

    - TLS issued via Let’s Encrypt (`cortex.aienablement.academy`).
    - DNS managed through Cloudflare (`A cortex → 163.192.41.116`, proxied).
    - Rotate `Caddyfile`​ backups (`/srv/proxy/Caddyfile.bak-<date>`​), format with `caddy fmt --overwrite` during next proxy maintenance window.

    ## 8. Usage Patterns & Workflows

    1. **Strategic Planning**: Map OKRs → Projects → Tasks within the `Projects` notebook. Embed progress trackers and link to NocoDB tables for metrics.
    2. **Research Library**: Each research artifact gets a page with summary, sources, action items. Use backlinks to surface where the insight is applied.
    3. **Experiment Journal**: Document experiments with hypotheses, setup, outcomes, and lessons; cross-link to knowledge expansion entries.
    4. **Runbooks & SOPs**: Mirror `.docs/agents` content; use templates to create consistent operational pages that link to actionable scripts (Docmost, GitHub, etc.).
    5. **Second Brain Review**: Weekly review of `0-Inbox`​, `Projects`​, and `Growth Experiments` to clean, archive, or escalate insights.

    ## 9. Automation & Integrations

    - **n8n Hooks**: Consider building flows that listen for new SiYuan blocks via API (`/api/blockTree/*`) and broadcast summaries to Docmost or Slack.
    - **Exports**: Schedule `siyuan-export.py` on the workstation or host to push curated updates back into version-controlled archives.
    - **Search Enhancements**: Explore SiYuan plugins (stored under `plugins/`) to integrate with AI summarizers or spaced repetition.
    - **Cron Sync**: Workstation cron (`*/15 * * * *`​) runs `scripts/sync/siyuan-export.py --upload`​ with SiYuan + CF Access credentials, keeping Cortex within ~15 minutes of repo changes (logs at `scripts/sync/siyuan-export.log`).

    ## 10. Security & Governance

     Maintain 600 perms on .env, workspace subdirectories, and backups. Rotate SMTP credentials per Brevo policy and update .env + redeploy. Cloudflare Access app cortex guards the domain; rotate service tokens annually and update /srv/cortex/.env + crontab. Log significant changes in Migration Activity Log[^5] with timestamp, commands, and verification steps.

    ## 11. Roadmap & Follow-Ups

    1. **Backups**: Integrate with existing `/srv/backups` pipeline and document restore drills.
    2. **Access Hardening**: Bring Cortex behind Cloudflare Access or Tailscale ACLs; evaluate multi-user authentication.
    3. **Templates Library**: Build canonical templates (Decision Record, Experiment Card, Meeting Note) and store under `Templates`.
    4. **Automation**: Wire n8n flows for daily digest emails using Brevo + SiYuan API.
    5. **Monitoring**: Add Cortex health check to Uptime Kuma (once hub alerts removed) and ensure TLS renewal notifications include the new host.

    With these guidelines, Cortex becomes the central hub for project tracking, knowledge expansion, and operational memory—mirroring the agent collective’s workflows while staying accessible to the human-in-the-loop.


[^4]: # docmost-nocodb-plan

    ---

    id: docmost-nocodb-plan
    title: Docmost & NocoDB Migration Programme
    summary: Source plan governing the transition from Plane to Docmost/NocoDB across infrastructure, monitoring, and automation.
    status: active
    owner: ops
    tags:

    - docmost
    - nocodb
    - migration
      last_reviewed_at: 2025-10-28

    ---

    # Docmost & NocoDB Migration Programme

    ## 1. Context Snapshot (SPARC)

    |Phase|Situation|Problem|Actions (Thin Slice)|Result Target|Confirmation (Testing)|
    | --------------------------------------| --------------------------------------------------| ---------------------------------------------------------------------------| -------------------------------------------------------------------------------------------------------------------------------------| ----------------------------------------------------------------| -------------------------------------------------------------------------|
    |P0 – Plane Decommission|Plane CE stack (Docker) running on OCI Ampere A1|Plane competes for ports/secrets; not part of future stack|Inventory services → export/back up if needed → `docker compose down` → prune volumes/images → revoke DNS|Clean slate host; no Plane artifacts; freed disk/network ports|​`docker ps`​ empty; `docker volume ls`​ sans `plane-app_*`; curl to former domain returns 404|
    |P1 – Core Platform Bootstrap|New stack needs reliable base|OCI host lacks documented baseline after cleanup|Apply security updates → capture resource baseline → configure monitoring script|Hardened host with reference metrics|​`apt upgrade`​ log; baseline report saved under `/var/log/infra-baseline.txt`​; `ufw status` documented|
    |P2 – Reverse Proxy & TLS Foundation|Multiple services share single IP|Without shared proxy, SSL + routing becomes fragile|Deploy Caddy (or Traefik) docker service → issue staging certs via Let’s Encrypt → test `wiki.*`​, `ops.*`, and dashboard host routes|Stable TLS termination + routing before app deployment|​`curl -I https://wiki.example` => 502 from proxy until upstream ready; Caddy logs show valid cert|
    |P3 – Docmost Service|Replace Plane knowledge base|Need ARM-compatible Docmost with persistent storage|Bootstrap Postgres (Docker) → deploy Docmost container on internal network → configure SMTP/auth → smoke test|Docmost reachable at `https://wiki.*`, admin created|​`docker compose ps`​ healthy; `/api/health` returns 200; e2e sign-in works|
    |P4 – NocoDB Service|Deliver Airtable alternative|Must co-exist without port conflicts and ensure data persistence|Launch NocoDB container → configure storage volume & JWT secret → connect to optional external DB|NocoDB accessible at `https://ops.*`, initial workspace ready|​`curl -I https://ops.*` 200; create base & confirm persistence after restart|
    |P5 – Formbricks Surveys|Publish branded survey platform|Need first-party survey tooling with file uploads + SMTP|Deploy Formbricks stack (`/srv/formbricks`) → configure Brevo sender → wire S3 storage bucket → smoke-test uploads|​`forms.aienablement.academy` live with admin onboarding complete|​`curl -I https://forms.*` 307→/setup, upload logo succeeds|
    |P5 – Unified Dashboard (dash)|Provide single entry point|Users need consistent front door post-Plane|Deploy static hub at `dash.aienablement.academy` → link Wiki/Ops/roadmap cards → reserve space for status badges|Dashboard live with navigation + placeholders for monitoring|​`curl -I https://dash.aienablement.academy` 200; cards route correctly|
    |P6 – Observability & Alerts|Protect service reliability|No current uptime/alerting|Launch Uptime Kuma + Dozzle stack → configure monitors (Wiki/Ops/Dash/health) → wire alert channel|HTTP/TLS checks with actionable notifications|Alert fires when target down; Dozzle accessible for logs|
    |P7 – Automation Layer (n8n)|Enable workflow automation|No orchestration service yet|Provision `/srv/n8n` (n8n + datastore) → expose via proxy/DNS → seed starter flow → document ops|n8n reachable, basic flow runs, dashboard card updated|​`curl -I https://n8n.*` 200; sample flow executes|
    |P8 – Collaboration Hub (Colanode)|Provide shared, offline-first workspace|Need governed place for cross-team chat/docs/databases alongside wiki/ops|Stand up Colanode stack under `/srv/colanode`​ → wire reverse proxy/Nginx for API + SPA → publish `hub.aienablement.academy` → seed pilot workspace + onboarding guide|Colanode reachable at `https://hub.aienablement.academy`, API responds, workspace seeded|​`curl -s https://hub.aienablement.academy/config` returns JSON; smoke test login via web client|

    ## 2. Business Framing (BMAD)

    |Dimension|Docmost|NocoDB|Dashboard / Proxy|
    | -----------| ----------------------------------------------------------------------------| ------------------------------------------------------------| -------------------------------------------------------------------|
    |**Business Benefit**|Replace Plane with markdown-first collaboration; reduce license dependency|Low-code database alternative for product ops|Single pane of glass; faster navigation; lowered support overhead|
    |**Metric**|Knowledge adoption (% active weekly users), MTTR for knowledge retrieval|Number of operational workspaces, automations enabled|Dashboard load < 1s, bounce rate < 10%, TLS renewal success|
    |**Action**|Seed key docs, train champions, integrate with SSO roadmap|Import core datasets, document workflows, enable API usage|Promote dashboard as default bookmark, integrate health widgets|
    |**Deliverable**|Docmost PRD + onboarding guide|NocoDB schema templates + ops runbook|Dashboard card library + proxy templates|

    ## 3. Programme Plan (Thin Slices)

    ### Phase 4 – Email & Auth Hardening

    1. Swap Docmost/NocoDB SMTP to Brevo with TLS 465 (implicit) and verify password reset flows; log in `MIGRATION_TASKS.md`.
    2. Remove Mailpit from compose; backup `.env` and compose before pruning; redeploy to confirm no fallback SMTP remains.
    3. Document Brevo sender + API usage; ensure service tokens stored in `/srv/docmost/.env`​ and `/srv/nocodb/.env` with 600 perms.

    ### Phase 5 – Dashboard & Surveys

    1. Deploy Formbricks stack under `/srv/formbricks`​ with Postgres + Valkey; configure S3 bucket (`aea-formbricks`) for uploads; update runbooks.
    2. Publish `forms.aienablement.academy` with Cloudflare Access gating admin UI; ensure Brevo SMTP tests pass.
    3. Launch static dashboard (`dash.aienablement.academy`) summarizing wiki, ops, monitoring, automation, and migration state.

    ### Phase 6 – Observability & Backup

    1. Create `/srv/monitoring`​ compose for Uptime Kuma + Dozzle (+ optional Netdata) behind Caddy routes (`status`​, `uptime`​, `monitor`​, `metrics`).
    2. Wire monitors for `wiki`​, `ops`​, `dash`​, `n8n`, Brevo SMTP, and the OCI host ping; configure Brevo SMTP + backup channel (Telegram or Slack webhook) for alerts and enable TLS expiry notifications.
    3. Restrict access: publish Kuma status page read-only, guard Dozzle behind Caddy basic-auth, and place Netdata behind Cloudflare access or disable external exposure.
    4. Formalize backup cadence: nightly `pg_dump` (Docmost/NocoDB/n8n) + tar snapshots to OCI Object Storage with retention notes; surface backup status on dashboard card.
    5. Tests: simulate outage (stop container) → alert received within SLA, review Dozzle log tail, ensure Netdata dashboards render, and perform restore dry-run from newest backup.

    ### Phase 7 – Automation Layer (n8n)

    1. Create `/srv/n8n`​ docker-compose (n8n + Postgres/SQLite) with resource limits; join `reverse-proxy`.
    2. Update Caddyfile + Cloudflare (`n8n.aienablement.academy`), smoke test TLS.
    3. Seed starter workflow (e.g., webhook → Brevo email) and document operations (backup, update, restart).
    4. Update dash card to link to n8n and note status; add to runbooks and tracker.

    ## 5. Delivery Cadence (Thin Slices & Milestones)

    |Week|Deliverable|Exit Criteria|
    | --------| -------------------------| ------------------------------------------------------------------------|
    |Week 0|P0 completed|Plane fully decommissioned; DNS cleaned; baseline captured|
    |Week 1|Proxy foundation live|Valid TLS for subdomains; Team sign-off on routing|
    |Week 2|Docmost GA|Admin onboarded; sample knowledge base seeded|
    |Week 3|NocoDB GA|Initial datasets migrated; API reachable|
    |Week 4|Dashboard live|​`dash.*` online with navigation + placeholders|
    |Week 5|Observability & Backups|Uptime Kuma/Dozzle alerting verified; backup restore dry-run complete|
    |Week 6|n8n MVP|n8n deployed, sample flow executed, dashboard card linked|
    |Week 7|Colanode pilot live|​`hub.*` online with first workspace + onboarding docs|

    ### Colanode Thin Slices

    |Slice|Objective|Exit Criteria|Status|Notes|
    | --------------------------------| ------------------------------------------------------------------| -----------------------------------------------------------------------------------------------| ----------| ----------------------------------------------------------------------------------------|
    |A – Stack Bootstrap|Deliver self-hosted Colanode stack with HTTPS|​`/srv/colanode`​ compose running; `curl -s https://hub.aienablement.academy/config` returns server JSON; API routed via nginx|Complete|2025-10-28: Stack deployed with custom nginx proxy + Cloudflare DNS/Caddy integration.|
    |B – Workspace Pilot|Seed first workspace, invite pilot users, capture onboarding doc|Pilot workspace created, test accounts invited, onboarding runbook linked from Docmost|Planned|Coordinate with product ops for data import + access policy.|
    |C – Safeguards & Integrations|Wire backups/exporters + notifications|Nightly pg_dump + storage backup logged; webhook to Uptime Kuma/n8n for incident automations|Planned|Reuse existing backup timers; add health monitor to Kuma Slice D.|

    ### Backup Enhancements (2025-10-26)

    - Extend backup stack to capture Docmost Postgres (`pg_dump`) and upload archives alongside existing markdown exports (OCI bucket + Google Drive).
    - Include Docmost uploads/storage volume snapshots so restores bring back attachments.
    - Keep Markdown/GDocs exports running for human + AI consumption; treat Docmost as the authoritative editor.
    - Explore Docmost API/MCP integration so agents can query live content in addition to markdown mirrors.

    ## 6. Risk Register (First Principles)

    |Risk|Mitigation|Owner|
    | ---------------------------------------------| -------------------------------------------------------------------| -------|
    |TLS issuance blocked by Cloudflare proxying|Use DNS challenge or temporarily disable proxy|Infra|
    |Resource exhaustion on free tier|Monitor `docker stats`; set container resource limits|Infra|
    |Backup storage growth|Implement lifecycle policies in Object Storage; compress archives|Ops|

    ## 7. Observability & Alerting PRD

    ### Problem & Goals

    - **Situation**: Wiki (`wiki.*`​), data hub (`ops.*`​), automation (`n8n.*`​), and dashboard (`dash.*`) now run on a single OCI Ampere VM without proactive monitoring or alerting.
    - **Pain**: Outages or TLS regressions would be detected manually; Docker log access requires SSH; no shared status page for stakeholders.
    - **Goal**: Deliver a lightweight observability layer that catches incidents within 5 minutes, centralizes log access, and keeps operational overhead minimal on free-tier resources.

    ### Success Metrics

    - MTTA (mean-time-to-acknowledge) < 5 minutes for HTTP downtime or TLS expiry.
    - At least 6 synthetic monitors (wiki, ops, dash, n8n, SMTP, host ping) green ≥ 99% over 30 days.
    - Log review accessible via authenticated UI without SSH; < 200 MB RAM combined footprint for Kuma + Dozzle; optional Netdata < 400 MB.
    - Alert delivery via Brevo email and one secondary channel (Telegram/Slack webhook) validated with live fire drill.

    ### Proposed Architecture

    |Component|Purpose|Deployment Notes|
    | --------------------| ---------------------------------------------------------| ----------------------------------------------------------------------------------------------------------------------------------------------------|
    |Uptime Kuma|HTTP/S, ping, TCP, TLS expiry monitoring + status pages|Run as `/srv/monitoring`​ service with persistent volume, mount docker socket read-only if using Docker monitor, expose via Caddy (`status.aienablement.academy` TBD) with viewer/basic auth.|
    |Dozzle|Real-time Docker log viewer|Shares docker socket read-only; protect behind Caddy basic auth and optional IP allow-list; no log retention to keep footprint tiny.|
    |Netdata (optional)|Host resource and container metrics + anomaly detection|Runs privileged but within same compose; expose only via Cloudflare Access or tunnel; provides per-container CPU/RAM, disk, network.|
    |Alert Channels|Brevo SMTP + secondary webhook|Kuma’s notifier uses existing Brevo credentials; configure Telegram or Slack webhook for redundancy.|

    ### Thin-Slice Execution

    1. **Slice A – Scaffold**: Create `/srv/monitoring`​ compose defining Kuma (port 3001), Dozzle (8080 internal), and Netdata (if enabled). Join `reverse-proxy`, allocate volumes, and confirm containers stay < 250 MB RAM aggregate.
    2. **Slice B – Monitors & Alerts**: Add monitors for wiki, ops, dash, n8n, SMTP (`smtp-relay.brevo.com:465`​ TCP), and host ICMP; configure notifications (Brevo email + webhook); publish read-only status page at `status.aienablement.academy`.
    3. **Slice C – Hardening**: Integrate Caddy routes for admin `uptime.aienablement.academy`​, Dozzle `monitor.aienablement.academy`​, and future Netdata `metrics.aienablement.academy`​; protect with Cloudflare Access and document access procedures.  *(Access apps + allow policies now active with*  *​`@aienablement.academy`​*​ *sign-in; metrics portal also has a service token for automation fetches.)*
    4. **Slice D – Validation**: Simulate outages (stop Docmost container, expire TLS via staging domain) to ensure alerts fire; record fire-drill outcomes in `MIGRATION_TASKS.md`; add dashboard badges fed from Kuma status JSON.

    ### Dependencies & Risks

    - Requires Brevo SMTP throughput headroom; add rate-limit guardrails.
    - Docker socket exposure must remain read-only; consider socket-proxy if stricter isolation needed.
    - Netdata needs elevated privileges; monitor CPU impact and be ready to disable if utilization spikes.

    ## 8. Next Steps Checklist

    - [X] Capture Brevo password-reset proof (logs/DB tokens) and retire Mailpit after 24 h observation (compose backup → remove service → redeploy; completed 2025-10-21).
    - [X] Approve lightweight monitoring stack (Uptime Kuma + Dozzle [+ Netdata optional]) and alert routing (email/webhook).
    - [X] Define backup retention & restoration SOP for Docmost/NocoDB (target storage, rotation, verification cadence) — see `.docs/projects/docmost-nocodb-backup-sop.md`.
    - [X] Finalize n8n architecture (datastore selection, resource limits, DNS naming) and add to infra approvals.
    - [X] Stand up Docmost → Markdown → Google Drive exporter running every 10 minutes (containerised `docmost-exporter` service).
    - [ ] Seed initial n8n workflow + document ops runbook (backups, auth, upgrades).
    - [ ] Update dashboard content plan (status badges JSON source, automation card copy) ahead of monitoring/n8n launch.
    - [X] Slice A – Deploy `/srv/monitoring` compose with Uptime Kuma + Dozzle (+ Netdata optional) and join reverse proxy (2025-10-21).
    - [X] Slice B – Configure monitors, Brevo/webhook notifications, and publish read-only status page on `status.aienablement.academy` (Cloudflare proxied after TLS issuance).
    - [ ] Slice C – Harden access controls (`uptime.`​, `monitor.`​, `metrics.aienablement.academy` with basic auth/Cloudflare Access) and document credentials.
    - [ ] Slice D – Run monitoring fire drill, capture results in `MIGRATION_TASKS.md`, surface status badges on dashboard.
    - [ ] Integrate Tailscale across OCI host (and future nodes) once credentials provided; update runbooks and compose profiles accordingly.
    - [X] Configure weekly Object Storage sync + monthly retention pruning for backups per SOP (see `sync-to-oci.sh` + systemd service/timer; first run scheduled 2025-10-26 03:30 UTC).
    - [ ] Plan maintenance window to reboot OCI host onto kernel `6.8.0-1037-oracle` after pending updates.


[^5]: # migration-tasks

    # Migration Activity Log

    #ops #docmost #nocodb #cortex

    ## 2025-11-02 – Proxmox Jellyfin GPU/NAS Fix

    - Repaired LXC `103`​ GPU passthrough by switching `/etc/pve/lxc/103.conf`​ from `/dev/dri/card1`​ to `/dev/dri/card0`​ and adding `lxc.cgroup2.devices.allow: c 226:* rwm`​, then restarted the container to confirm VA-API availability (`vainfo`, Jellyfin dashboard).
    - Cleared redundant manual `lxc.mount.entry` directives that conflicted with the autodev hook, allowing device nodes to be created cleanly during boot.
    - Updated NAS mapping after the QNAP moved networks: changed `/etc/fstab`​ CIFS entry to `//192.168.50.251/Jellyfin`​, remounted to `/mnt/qnap/jellyfin`​, and bounced LXC `103`​ so `/media/Movies`​ and `/media/Shows` populated again.
    - Verified Jellyfin service health (`systemctl status jellyfin`​, `curl -I http://192.168.50.153:8096`) and reintroduced the media libraries for playback tests.
    - Captured lessons learned in `proxmox-ops`​, `infra-health`​, and `backup-rotation` runbooks (GPU mapping, bind-mount checks, NAS mount validation).

    ## 2025-11-02 – Harbor Proxy Inventory & Jellyfin Host

    - Drafted service inventory at `ops/proxy/harbor-services.yaml`​ to describe harbor.fyi subdomains, targets, and TLS handling; added `scripts/infra/generate_harbor_proxy.py` to render managed Nginx snippets.
    - Created managed entry for `jellyfin.harbor.fyi`​ (targets `192.168.50.153:8096`​, certificate `npm-24`​) and generated config into `ops/proxy/generated/`.
    - Synced inventory output into Nginx Proxy Manager LXC (`/data/nginx/inventory/jellyfin.harbor.fyi.conf`​), extended both `/etc/nginx/nginx.conf`​ and `/usr/local/openresty/nginx/conf/nginx.conf` to include the inventory directory, and reloaded Nginx.
    - Archived the legacy `proxy_host/5.conf`​, marked the corresponding NPM record deleted, and confirmed external requests to `jellyfin.harbor.fyi` resolve through the new inventory-managed host only.
    - Inserted Jellyfin mapping into NPM SQLite (`proxy_host`​ id `18`​, certificate `24`) to keep the UI aware of the host alongside the generated config.
    - Ran `nginx -t && nginx -s reload`​ to validate deployment; noted follow-up to ensure Porkbun DDNS includes `jellyfin.harbor.fyi` and to evaluate a Porkbun MCP adapter if we want agent-based DNS updates later.

    ## 2025-11-02 – ddns.harbor.fyi Hardening

    - Restored the ddns proxy host in Nginx Proxy Manager (`proxy_host`​ id `5`​) pointing at `192.168.50.149:8001`​ with certificate `npm-22`​, and tightened access controls to `allow 100.64.0.0/10; allow 127.0.0.1; deny all;`.
    - Installed `dnsmasq`​ on the proxy LXC and added `/etc/dnsmasq.d/harbor.conf`​ (tracked at `ops/proxy/dnsmasq-harbor.conf`​) so `ddns.harbor.fyi`​ resolves to the proxy’s Tailnet IP (`100.85.205.49`​) while other `harbor.fyi` records still use the home router.
    - Reconfigured script tooling (`ops/proxy/harbor-services.yaml`​) to treat ddns as UI-managed (`managed: false`) so future inventory renders do not overwrite the NPM definition.
    - Validated from the Mac client (`nslookup`​, `curl`) that Tailnet-connected devices receive the Tailnet IP and load the dashboard, while public requests return 403/405.
    - Rotated Porkbun API keys in `/root/docker-compose.yml`​ and `config.json`​ inside the ddns-updater data volume, set `PUBLICIP_HTTP_PROVIDERS=url:https://ipinfo.io/ip`​, and redeployed the container with `docker compose up -d ddns-updater`​; health probe now returns `healthy` and the dashboard shows successful syncs.

    ## 2025-10-30 – Moodle RemUI Recovery

     Reinstalled Edwiser RemUI v5.1 bundle (theme, blocks, filter, course format, page builder, site importer, sitesync) into /var/www/moodle_1click/public, setting ownership back to www-data and archiving the prior copies under /root/edwiser_backups_20251030/. Removed legacy template public/message/templates/message_drawer_view_conversation_footer_unable_to_message.mustache and redundant require_once($CFG->dirroot.'/config.php'); calls in Edwiser classes so Moodle 5.1 stops flagging “Mixed Moodle versions detected”. Ran maintenance → admin/cli/upgrade.php → purge_caches.php cycle; verified Edwiser APIs (do_page_action, edwiser_fetch_layout_list, edwiser_fetch_addable_blocks) return valid JSON response bodies. Documented the full remediation and prevention checklist in Docmost &amp; NocoDB Lessons Learned[^6] to avoid future stale-file regressions after RemUI upgrades.

    ## 2025-10-20 – Phase 0 & 1

    - Identified active Plane CE stack on OCI host `docker-host`​ (163.192.41.116) running from `/home/ubuntu/plane-deployment/plane-app`.
    - Captured backups before teardown: Postgres dump at `/srv/backups/plane/plane_db_2025-10-20.sql`​ and MinIO uploads archive at `/srv/backups/plane/plane_uploads_2025-10-20.tar.gz`.
    - Brought the Plane stack down via `docker compose down`​, removed associated volumes/images, and confirmed `docker ps`​ and `docker volume ls` are empty.
    - Ran `apt-get update && apt-get upgrade -y`​ and stored a host baseline snapshot at `/var/log/infra-baseline.txt`.
    - Attempted to remove `pm.aienablement.academy`​ DNS via Cloudflare API, but token `9109 Invalid access token` response blocked progress pending a new scoped token.
    - Installed `backup-doc-platform.sh`​ to `/usr/local/sbin`​ with accompanying systemd unit/timer on the OCI host; enabled the timer and executed an immediate run (`systemctl start backup-doc-platform.service`) to validate end-to-end.
    - Verified the service generated fresh artifacts under `/srv/backups/daily/`​ (database dumps, volume archives, `.env`​ snapshots) and logged actions to `/srv/backups/backup-doc-platform.log`; timer next scheduled for 02:18 UTC.
    - ​`apt`​ install of `sqlite3`​ during this session surfaced a pending kernel upgrade (`6.8.0-1037-oracle`); schedule a maintenance window to reboot and apply when convenient.

    ## 2025-10-22 – Status Page Footer Sanitized

    - Installed `sqlite3`​ and updated `status_page.footer_text`​ inside `/srv/monitoring/uptime-kuma-data/kuma.db`​ to replace the public contact email with a Docmost support link; ran `PRAGMA wal_checkpoint(FULL)`​ and `VACUUM` to persist the change.
    - Confirmed via `curl -s https://status.aienablement.academy` that the rendered JSON now shows “Need help? Visit https://wiki.aienablement.academy for support.” in the footer payload.

    ## 2025-10-22 – Google Drive Sync Scaffold

    - Installed rclone v1.71.2 on the OCI host and secured `/root/.config/rclone`.
    - Added `/usr/local/sbin/sync-to-gdrive.sh`​ plus `backup-sync-gdrive.service`​/`.timer`; timer scheduled for 02:45 UTC with randomized delay.
    - Verified manual log output in `/srv/backups/gdrive-sync.log`​; remote `gdrive`​ still needs OAuth authorization via `sudo rclone config` before the sync will succeed.

    ## 2025-10-22 – Dashboard IA Draft

     Captured the high-level layout, card structure, and data sources for dash.aienablement.academy within Docmost &amp; NocoDB Migration Programme[^4] under “Dashboard Information Architecture (Current Concept)” to guide the next UI iteration.

    ## 2025-10-22 – Monitoring Subdomain Routing

    - Created Cloudflare A records (`753de8f101c0a5590dd088f95ef2a8db`​, `fdc7203d195a95b99a9e33dbb93b5908`​) for `uptime.aienablement.academy`​ and `monitor.aienablement.academy`​ pointing at `163.192.41.116`, staged DNS-only for ACME issuance, then re-enabled proxied mode after certificates succeeded.
    - Updated `/srv/proxy/Caddyfile`​ to proxy `uptime.*`​ → `uptime-kuma:3001`​ and `monitor.*`​ → `dozzle:8080`​, wrapping both behind Caddy `basic_auth`​ (user `opsadmin`​, password `Ops!Dash2025`; stored in 1Password “Monitoring Admin Gate”).
    - Reloaded Caddy and confirmed Let’s Encrypt orders for both hosts completed (see `docker compose logs caddy`​ around `ts:1761093366`​); smoke-tested with `curl --resolve ...` receiving HTTP/2 401 as expected.

    ## 2025-10-22 – OCI Inventory (CLI & MCP)

    - Queried tenancy `hello7142`​ with OCI CLI: `oci compute instance list`​, `oci compute vnic-attachment list`​, and `oci network vnic get`​ to capture instance OCID, AD, and public/private IP for `docker-host`.
    - Activated `~/OCI-MCP-Servers/.venv`​ (Python 3.11), installed MCP dependencies, and invoked `compute.list_compute_instances` via MCP module to cross-check instance metadata outside of the CLI.

    ## 2025-10-22 – Google Drive Sync Live

    - Authorized the `gdrive`​ remote using OAuth token from local workstation and wrote `/root/.config/rclone/rclone.conf`​ with Drive scope `drive.file`.
    - Ran `sudo systemctl start backup-sync-gdrive.service`​; service completed successfully and uploaded the latest backup set (`20251022T0325`​) to `gdrive:doc-platform-backups/daily/<stamp>`.
    - Confirmed remote contents via `sudo rclone ls gdrive:doc-platform-backups/daily/20251022T0325` (env snapshots, pg_dumps, and tar archives present) and log tail shows successful completion.

    ## 2025-10-22 – OCI Object Storage Weekly Sync

     Authored ops/backup/sync-to-oci.sh to promote the most recent daily backup set into /srv/backups/weekly and /srv/backups/monthly, upload to OCI Object Storage bucket infra-backups, and prune retention (keep 4 weekly / 6 monthly locally and remotely). Script logs to /srv/backups/oci-sync.log. Added supporting units ops/backup/sync-to-oci.service and ops/backup/sync-to-oci.timer (scheduled Sundays 03:30 UTC with 5 m jitter) and documented the installation procedure in Docmost &amp; NocoDB Backup SOP[^7]. Updated Docmost &amp; NocoDB Migration Programme[^4] and Docmost &amp; NocoDB Project Tracker[^8] to mark the backup workstream complete; first scheduled OCI sync will run after the nightly backup cycle on 2025-10-26. Refined export-docmost-markdown.sh to stage exports in-memory, refresh only /srv/docmost/exports/markdown/latest, and prune any older timestamp directories so Google Drive retains just the newest Markdown set (Drive keeps versions automatically).

    ## 2025-10-22 – Docmost Exporter Containerisation

    - Removed the legacy systemd service/timer for the Docmost Markdown sync and introduced a dedicated container build (`ops/docmost-exporter/`​) that bundles `export-markdown.sh` with its dependencies.
    - Added an interval supervisor (`entrypoint.sh`​) so the container loops every 600 s by default, with support for one-off runs via `EXPORT_RUN_ONCE=true`.
    - Updated the backup playbook to reference the container deployment and mapped `/srv/docmost/exports/markdown` volume within the compose stack.

    ## 2025-10-29 – Formbricks Deployment

     Deployed Formbricks stack (/srv/formbricks) with Postgres (formbricks-postgres), Valkey, and app containers; connected to reverse-proxy and exposed via Caddy block for forms.aienablement.academy. Configured Brevo SMTP (MAIL_HOST=smtp-relay.brevo.com, MAIL_PORT=465, MAIL_SECURE=true, MAIL_USER, MAIL_PASSWORD) in /srv/formbricks/.env; ensured env file permissions set to 600. Added Caddy basicauth for /admin as temporary guard until Cloudflare Access is configured; confirmed Let’s Encrypt certificate issuance after toggling Cloudflare proxy. Follow-ups: run the Formbricks onboarding wizard to create the initial admin, configure organization settings, and trigger a Brevo test email/invite from the UI once domains/senders are confirmed. Consider adding backup hooks for formbricks_db_data and documenting operational runbooks under Docmost &amp; NocoDB Migration Programme[^4]. Updated Formbricks sender identity per comms guidance: /srv/formbricks/.env now sets MAIL_FROM=learn@aienablement.academy and MAIL_FROM_NAME="AI Enablement Academy"; restarted formbricks-app to load the change (docker compose exec formbricks-app env | grep ^MAIL confirms). Configured external S3 storage for Formbricks uploads using AWS bucket aea-formbricks (region us-east-2). Added S3_ACCESS_KEY, S3_SECRET_KEY, S3_REGION, and S3_BUCKET_NAME to /srv/formbricks/.env, restarted the app, and confirmed the variables are loaded in the container. Pending: verify a test upload via the UI to ensure IAM permissions and CORS allow PUT/POST operations.

    ## 2025-10-29 – MCP Estate Update

     Cloned and built mcp-servers/codex-subagents-mcp, then registered it with Codex CLI, Claude Code, and Claude Z.AI (Node entrypoint + agents dir wired in configs) to unlock delegate flows. Added DigitalOcean MCP with inline token plus Z.AI Web Search (https://api.z.ai/api/mcp/web_search_prime/mcp) and Vision (npx -y @z_ai/mcp-server) servers across Codex CLI (~/.codex/config.toml), Claude Code (claude-code/.claude/.claude.json), and Claude Z.AI (claude-zai/.claude/.claude.json); verified connectivity via codex mcp list and claude mcp list. Exercised delegates and documented outcomes; noted the Web Search transport limitation for follow-up. Updated runbooks (DigitalOcean Operations Guide[^9], .docs/agents/digitalocean-operations.md) and the infrastructure expansion roadmap to document the new MCP surface area; tokens noted for rotation. 2025-11-02 follow-up: removed the Z.AI Web Search HTTP entry from Codex CLI config to prevent missing field command errors until native HTTP transports land; catalog + AGENTS docs updated with the mitigation.

    ## 2025-11-02 – Colanode Decommission & Cortex Prep

    - Captured `/srv/colanode`​ snapshot (`/srv/backups/colanode-<UTC>.tgz`) ahead of removal for potential rollback.
    - Brought the Colanode stack down via `sudo docker compose down --volumes`​ and purged `/srv/colanode` to reclaim disk and stop postgres/valkey containers.
    - Removed the `hub.aienablement.academy`​ site block from `/srv/proxy/Caddyfile`​ (backup `Caddyfile.bak-20251102` saved) and reloaded Caddy to drop routing.
    - Deleted the Cloudflare DNS `A`​ record for `hub.aienablement.academy`​ and confirmed NXDOMAIN via `curl`.
    - Follow-up: prune any Uptime Kuma monitors/webhooks referencing the former hub endpoint to avoid false alerts.

    ## 2025-11-02 – Cortex (Siyuan) Bootstrap

    - Provisioned `/srv/cortex`​ with `docker-compose.yml`​ (Siyuan `b3log/siyuan:v3.3.6`​) and workspace volume, generated access code (`SIYUAN_ACCESS_AUTH_CODE`​) stored in `/srv/cortex/.env` (600 perms).
    - Joined the stack to `reverse-proxy`​, added `cortex.aienablement.academy`​ block to `/srv/proxy/Caddyfile`, and reloaded Caddy after pruning stale locks to obtain Let’s Encrypt TLS.
    - Created Cloudflare `A`​ record for `cortex`​ → `163.192.41.116` (proxied) once the origin cert issued.
    - Seeded Brevo SMTP variables from Docmost `.env`​; validated SSL login + outbound delivery by sending a test message from the host via Python (`Cortex SMTP connectivity test`).
    - Verified service health with `docker run --rm --network reverse-proxy curlimages/curl ... http://cortex-app:6806`​ (401) and external checks (`curl https://cortex.aienablement.academy`).
    - Follow-ups: add Cortex workspace directory to backup rotation, document onboarding, run `caddy fmt` during next proxy maintenance.

    ## 2025-11-03 – Cortex API Hardening & Backup Integration

    - Rotated Cortex authentication secrets and updated `/srv/cortex/.env`​ + `conf/conf.json`; recreated container with fresh args.
    - Verified API + WebDAV endpoints behind Caddy using the new token, and noted the kernel still responds to unauthenticated requests → enforce Cloudflare Access/header guards.
    - Extended `/srv/cortex/workspace`​ into `ops/backup/backup-doc-platform.sh` so nightly timer captures Cortex data alongside Docmost/NocoDB/Uptime Kuma.
    - Planned follow-up: confirm timer status on next host session.

    ## 2025-11-03 – Cortex Cloudflare Access Lockdown

    - Created Cloudflare Access app `cortex`​, added allow policies for `*@aienablement.academy`​, and issued automation service token `cortex-automation`.
    - Stored service token credentials in `/srv/cortex/.env`; Caddy now receives Access headers for automations.
    - Switched the service-token policy to `decision=non_identity`​; verified `curl` with headers succeeds while unauthenticated browsers see the login prompt.
    - Added GitHub OAuth IdP and attached it to the Cortex Access app so operators authenticate with GitHub.
    - Removed SiYuan access code requirement now that GitHub/Access fronts the app; container recreated with `SIYUAN_ACCESS_AUTH_CODE_BYPASS=true`.

    ## 2025-11-03 – Cortex MCP Server & Near-Live Sync

    - Scaffolded `mcp/cortex`​ MCP server exposing `siyuan_request`​, `siyuan_list_notebooks`​, and `siyuan_export_markdown` tools over stdio.
    - Updated `scripts/sync/siyuan-export.py` to forward CF Access headers when pushing ZIP bundles.
    - Installed cron job (`*/15 * * * *`​) on the workstation to run `siyuan-export.py --upload`​, logging to `scripts/sync/siyuan-export.log`.
    - Added `mcp_servers.cortex`​ entry to `~/.codex/config.toml` so Codex CLI can spawn the server with the correct environment.

    ## 2025-11-03 – Cortex Documentation Seed Import

    - Ran `scripts/sync/siyuan-export.py --upload`​ with refreshed API token to push the current `.docs` bundle into Cortex.
    - Confirmed import success via 200 response; in-app review pending to verify notebook mapping.
    - Next: establish scheduled import cadence until bidirectional sync strategy is defined.

    ## 2025-11-04 – Cortex Agent Enablement

     Authored Cortex (SiYuan) Operations Agent[^2] and associated skills (cortex-task-log, cortex-notebook-curation). Extended mcp/cortex server with document creation, append, attribute update, and SQL query tools. Scaffolded plugins/cortex-ops with mirrored agent/skill docs and logging commands; published plugin manifest for Claude/Codex installs. Refreshed Cortex (SiYuan) Operations &amp; Usage Guide[^3] with MCP tool guidance and synced plugins via scripts/sync/claude-sync.sh. Verified MCP toolchain end-to-end via local stub test (create doc → append block → set attrs → SQL query). Added launcher script scripts/mcp/cortex-mcp.sh and registered the server in Claude configs; secrets load from ~/.config/cortex-mcp.env to expose the tools to Claude clients.

    ## 2025-11-03 – Cortex Governance Upgrade

    - Published Cortex Metadata Standards[^13] and Tag &amp; Hashtag Taxonomy[^14] to codify second-brain metadata and tagging.
    - Added dashboards: Projects Dashboard[^15], Knowledge Freshness Dashboard[^16], Automation Inventory Dashboard[^17].
    - Created quick-start template Metadata &amp; Tag Check Template[^18] and governance section in Knowledge Base Overview[^19].
    - Backfilled block references across runbooks, backups, and automation logs to enable graph navigation.
    - Imported key infrastructure runbooks linux-server-operations[^25], oci-operations[^26], tailscale-operations[^27], uptime-kuma-operations[^28], formbricks-operations[^29] into Cortex and wired them into Agents Overview.


[^6]: # docmost-nocodb-lessons

    ---

    id: docmost-nocodb-lessons
    title: Docmost & NocoDB Lessons Learned
    summary: Field notes and operational lessons captured during the Docmost and NocoDB migration programme.
    tags:

    - docmost
    - nocodb
    - postmortem
      status: active
      owner: ops
      last_reviewed_at: 2025-10-26

    ---

    # Docmost & NocoDB Lessons Learned

    ## DNS & TLS

    - **Always set DNS first**: Provision Cloudflare records before editing Caddy; Let’s Encrypt validation fails with `NXDOMAIN` if the record lags.
    - **Redirect strategy**: Keep legacy hostnames (e.g., `docs.*`​) active but redirect permanently after the new hostname (`wiki.*`​) is ready. Test with `curl -I` to verify status codes (301 → 200).
    - **Caddy reload flow**: Update `Caddyfile`​, run `caddy fmt`​ (optional), then reload inside container. Watch logs for `certificate obtained successfully` to confirm issuance.

    ## SMTP Integration

    - **Brevo ports**: STARTTLS on `587`​ produced TLS version errors in containers; implicit TLS on `465`​ worked consistently. Configure Docmost (`SMTP_SECURE=true`​) and NocoDB (`NC_SMTP_SECURE=true`) accordingly.
    - **Verification**: After switching providers, run a direct SMTP test from the host (Python `smtplib`). Check Brevo dashboard/API to ensure domain is verified and API token is valid; otherwise messages queue but never deliver.

    ## OCI Workflow

    - **Firewall pitfalls**: Oracle Linux images ship with `firewalld` enabled—disable or open ports via console connection before relying on SSH.
    - **Reserved IP hygiene**: Keep track of assigned public IPs; document any detachment to avoid orphaned resources.
    - **Automation**: The `oci-compute` MCP + CLI combo accelerates inventory tasks; keep virtualenv dependencies pinned to Python 3.11.

    ## Docker Host Practices

    - **Stack isolation**: One `/srv/<service>` directory per compose stack simplifies restarts and log collection.
    - **Backups before changes**: Copy `.env`/compose files with timestamp suffix prior to edits; prune old backups monthly.
    - **Mailpit retention**: Retain Mailpit container for troubleshooting until Brevo deliverability is confirmed end-to-end.
    - **NocoDB bootstrap**: Only set `NC_ADMIN_EMAIL/NC_ADMIN_PASSWORD`​ during the very first run—leaving them in `.env` forces the service to replay bootstrap logic on every restart and can break once multiple super users exist.

    ## Documentation & Tracking

    - Log every substantive change in `MIGRATION_TASKS.md` with timestamp + verification.
    - Use the project tracker (`.docs/projects/docmost-nocodb-tracker.md`) to capture remaining work, blockers, and owners—prevents scope drift between phases.
    - When creating new runbooks, link them from `AGENTS.md` under the relevant expertise section to keep discovery simple.

    ## Related Knowledge

     See Docmost &amp; NocoDB Migration Programme[^4] for the end-to-end project blueprint. Cross-check backup details in Docmost &amp; NocoDB Backup SOP[^7]. Reference field diary entries in Migration Activity Log[^5].

    #docmost #nocodb #postmortem #ops


[^7]: # docmost-nocodb-backup-sop

    ---

    id: docmost-nocodb-backup-sop
    title: Docmost & NocoDB Backup SOP
    summary: Standard operating procedure for database, storage, and offsite backups covering Docmost and NocoDB.
    status: active
    owner: ops
    tags:

    - backup
    - docmost
    - nocodb
      last_reviewed_at: 2025-10-26

    ---

    # Docmost & NocoDB Backup SOP

    ## Scope & Targets

    - **Docmost**: Postgres database (`docmost`​), Redis not persisted, file storage under `/srv/docmost/storage`.
    - **NocoDB**: Postgres database (`nocodb`​), attachment directory `/srv/nocodb/nc_data`​, config files (`.env`​, `docker-compose.yml`).
    - **Monitoring data**: Uptime Kuma SQLite (`/srv/monitoring/uptime-kuma-data/kuma.db`) included in weekly cycle.

    ## Backup Layout

    - Local staging root: `/srv/backups`.

      - ​`daily/` – most recent 7 rolling dumps.
      - ​`weekly/` – retained for 4 weeks.
      - ​`monthly/` – retained for 6 months.
    - Offsite: OCI Object Storage bucket `infra-backups`​ (Standard tier). Sync via `oci os object put`.

    ## Daily Job (02:15 UTC)

    1. Create timestamp variable: `STAMP=$(date -u +"%Y%m%dT%H%M")`.
    2. Dump Docmost DB:

        ```bash
        sudo docker exec docmost-postgres pg_dump -Fc -U docmost docmost \
          > /srv/backups/daily/docmost-db-${STAMP}.dump
        ```
    3. Dump NocoDB DB:

        ```bash
        sudo docker exec nocodb-postgres pg_dump -Fc -U nocodb nocodb \
          > /srv/backups/daily/nocodb-db-${STAMP}.dump
        ```
    4. Archive file stores:

        ```bash
        sudo tar -C /srv/docmost -czf /srv/backups/daily/docmost-files-${STAMP}.tar.gz storage
        sudo tar -C /srv/nocodb -czf /srv/backups/daily/nocodb-files-${STAMP}.tar.gz nc_data
        ```
    5. Copy stack configs:

        ```bash
        sudo cp /srv/docmost/.env /srv/backups/daily/docmost-env-${STAMP}
        sudo cp /srv/nocodb/.env /srv/backups/daily/nocodb-env-${STAMP}
        ```
    6. Prune local dailies older than 7 days: `find /srv/backups/daily -mtime +7 -delete`.

    _Automation_: place commands in `/usr/local/bin/backup-doc-platform.sh`​ and trigger via systemd timer (`backup-doc-platform.service`​ / `.timer`).

    ## Weekly Offsite Sync (Sundays 03:30 UTC)

    The systemd timer `backup-sync-oci.timer`​ calls `/usr/local/sbin/sync-to-oci.sh`, which:

    1. Determines the latest backup stamp (`docmost-db-*.dump`​) and copies matching artifacts from `/srv/backups/daily`​ into `/srv/backups/weekly/<stamp>/`.
    2. If the run falls on the first Sunday of the month, promotes the same stamp into `/srv/backups/monthly/<stamp>/`.
    3. Uploads the staged folders to OCI Object Storage bucket `infra-backups`​ under `weekly/<hostname>/<stamp>/`​ (and `monthly/<hostname>/<stamp>/`​ when applicable) via `oci os object sync`.
    4. Prunes local folders beyond retention windows (weekly: 35 days / 4 copies, monthly: 6 months / 6 copies) and trims remote prefixes older than the retain window using `oci os object bulk-delete`.
    5. Logs to `/srv/backups/oci-sync.log` for post-run validation.

    ## Restore Workflow

    ### Docmost

    1. Stop stack: `cd /srv/docmost && sudo docker compose down`.
    2. Restore storage: `sudo tar -C /srv/docmost -xzf /srv/backups/<tier>/docmost-files-YYYYMMDDT*.tar.gz`.
    3. Restore DB:

        ```bash
        sudo docker compose up -d docmost-postgres
        cat /srv/backups/<tier>/docmost-db-YYYYMMDDT*.dump | \
          sudo docker exec -i docmost-postgres pg_restore -U docmost -d docmost --clean
        ```
    4. Restart stack: `sudo docker compose up -d`.

    ### NocoDB

    1. Stop stack: `cd /srv/nocodb && sudo docker compose down`.
    2. Restore attachments: `sudo tar -C /srv/nocodb -xzf /srv/backups/<tier>/nocodb-files-YYYYMMDDT*.tar.gz`.
    3. Restore DB similarly:

        ```bash
        sudo docker compose up -d nocodb-postgres
        cat /srv/backups/<tier>/nocodb-db-YYYYMMDDT*.dump | \
          sudo docker exec -i nocodb-postgres pg_restore -U nocodb -d nocodb --clean
        ```
    4. Bring stack online: `sudo docker compose up -d`.

    ### Uptime Kuma (weekly)

    ```bash
    sudo docker compose down uptime-kuma
    sudo cp /srv/backups/<tier>/uptime-kuma-data-YYYYMMDDT*.tar.gz /srv/monitoring/
    sudo tar -C /srv/monitoring -xzf uptime-kuma-data-YYYYMMDDT*.tar.gz
    sudo docker compose up -d uptime-kuma
    ```
    ## Verification Cadence

    - **Daily**: monitor backup script exit codes (systemd `Status=`​), ensure files appear under `/srv/backups/daily`.
    - **Weekly**: confirm OCI bucket upload (`oci os object list -bn infra-backups --prefix weekly/${HOSTNAME}/${STAMP}`).
    - **Quarterly**: perform restore drill in staging VM; document outcome in `MIGRATION_TASKS.md`.
    - **After major upgrades**: run immediate manual backup prior to deploy.

    ## Security & Compliance

    - Restrict `/srv/backups` to root (700). Provide read-only SFTP role if human access required.
    - Store Object Storage auth keys in `/home/ubuntu/.oci/config` (600).
    - Encrypt archives at rest if auditing demands (`gpg --symmetric`).

    ## Change Management

    - Log backup/restore events in `MIGRATION_TASKS.md`.
    - If retention windows or storage targets change, update this SOP and notify Ops via Docmost runbook.

    ## Automation Assets

    - Script: `ops/backup/backup-doc-platform.sh`
    - Systemd unit: `ops/backup/backup-doc-platform.service`
    - Systemd timer: `ops/backup/backup-doc-platform.timer`
    - Log file: `/srv/backups/backup-doc-platform.log`
    - Validate with `sudo systemctl status backup-doc-platform.timer`​ and inspect `/srv/backups/backup-doc-platform.log` after the first run.

    ### Offsite Sync – Google Drive

    - Script: `ops/backup/sync-to-gdrive.sh`
    - Systemd unit: `ops/backup/sync-to-gdrive.service`
    - Systemd timer: `ops/backup/sync-to-gdrive.timer`
    - Remote: `gdrive:doc-platform-backups`

    #### Remote Configuration

    1. Install rclone (`curl -s https://rclone.org/install.sh | sudo bash` already executed on host).
    2. As root, run `sudo rclone config`​ and create a remote named `gdrive`:

        - Storage: `drive`
        - Scope: `drive.file`​ (or `drive` for full access as required)
        - Use `rclone authorize "drive"` on a workstation to complete the OAuth flow and paste the token back into the host.
        - Leave `root_folder_id`​ empty unless using a shared drive; set `team_drive` only if needed.
    3. Protect `/root/.config/rclone/rclone.conf` (mode 600).

    #### Deployment Steps

    ```bash
    sudo install -m 700 ops/backup/sync-to-gdrive.sh /usr/local/sbin/sync-to-gdrive.sh
    sudo install -m 644 ops/backup/sync-to-gdrive.service /etc/systemd/system/backup-sync-gdrive.service
    sudo install -m 644 ops/backup/sync-to-gdrive.timer /etc/systemd/system/backup-sync-gdrive.timer
    sudo systemctl daemon-reload
    sudo systemctl enable --now backup-sync-gdrive.timer
    ```
    - Timer schedule: 02:45 UTC daily (after local backup). Check status with `sudo systemctl status backup-sync-gdrive.timer`.
    - Logs: `/srv/backups/gdrive-sync.log`.
    - Remote retention: script prunes Google Drive objects older than 35 days and removes empty folders.
    - Verification: `sudo rclone ls gdrive:doc-platform-backups/daily/<STAMP>` should list tar/dump artifacts (initial run confirmed 20251022T0325 upload).

    ### Offsite Sync – OCI Object Storage

    - Script: `ops/backup/sync-to-oci.sh`
    - Systemd unit: `ops/backup/sync-to-oci.service`
    - Systemd timer: `ops/backup/sync-to-oci.timer`
    - Bucket: `infra-backups`​ (Standard tier), namespace retrieved via `oci os ns get`.

    #### Deployment Steps

    ```bash
    sudo install -m 700 ops/backup/sync-to-oci.sh /usr/local/sbin/sync-to-oci.sh
    sudo install -m 644 ops/backup/sync-to-oci.service /etc/systemd/system/backup-sync-oci.service
    sudo install -m 644 ops/backup/sync-to-oci.timer /etc/systemd/system/backup-sync-oci.timer
    sudo systemctl daemon-reload
    sudo systemctl enable --now backup-sync-oci.timer
    ```
    - Timer schedule: Sundays 03:30 UTC (after nightly runs) with `RandomizedDelaySec=5m`.
    - Logs: `/srv/backups/oci-sync.log`.
    - Remote retention: script keeps the newest four weekly and six monthly prefixes; older data removed via `oci os object bulk-delete`.
    - Verification: `oci os object list -bn infra-backups --prefix weekly/<hostname>/` should show the promoted stamp; confirm monthly path after the first-Sunday run.

    ### Docmost Markdown Sync (Container, every 10 minutes)

    - Script: `ops/docmost/export-markdown.sh`
    - Container assets: `ops/docmost-exporter/Dockerfile`​, `ops/docmost-exporter/entrypoint.sh`
    - Runtime config: provide Docmost credentials via an env file (`/secrets/docmost-export.env`​) or environment variables (supports either `DOCMOST_EMAIL`​/`DOCMOST_PASSWORD`​ or a pre-generated `DOCMOST_AUTH_TOKEN`​). `DOCMOST_AUTH_TOKEN` is preferred for long-lived automation; when set, username/password are optional.
    - Destination: `/srv/docmost/exports/markdown/latest/`​ mirrored to `gdrive:docmost-markdown`
    - Rclone config is copied into a tmpfs workspace each run before syncing so refresh tokens written by rclone never touch the host filesystem.

    #### Build Image

    ```bash
    docker build -f ops/docmost-exporter/Dockerfile -t docmost-exporter .
    ```
    #### Deploy via Compose

    ```yaml
    services:
      docmost-exporter:
        image: docmost-exporter
        restart: unless-stopped
        environment:
          DOCMOST_BASE_URL: https://wiki.aienablement.academy
          DOCMOST_AUTH_TOKEN: ${DOCMOST_AUTH_TOKEN:-}
          DOCMOST_EMAIL: ${DOCMOST_EMAIL:-}
          DOCMOST_PASSWORD: ${DOCMOST_PASSWORD:-}
          REMOTE_NAME: gdrive
          REMOTE_PATH: docmost-markdown
          EXPORT_INTERVAL: 600
          CONFIG_FILE: ""                 # rely on env vars instead of file
          RCLONE_CONFIG: /secrets/rclone.conf
        volumes:
          - /srv/docmost/exports/markdown:/exports
          - /root/.config/rclone/rclone.conf:/secrets/rclone.conf:ro
        networks:
          - reverse-proxy
    ```
    > If you prefer file-based secrets, mount `/etc/docplatform/docmost-export.env`​ into the container at `/secrets/docmost-export.env`​. Supported keys: `DOCMOST_BASE_URL`​, `DOCMOST_EMAIL`​, `DOCMOST_PASSWORD`​, `DOCMOST_AUTH_TOKEN`.
    >

    - Interval: default 600 s (`EXPORT_INTERVAL`​). Each run regenerates `/exports/<space>/…` and prunes stale directories before syncing to Google Drive.
    - Verification: observe container logs (`docker compose logs -f docmost-exporter`​) and confirm new Markdown files under `/srv/docmost/exports/markdown/latest`​ plus `rclone ls gdrive:docmost-markdown`.
    - One-off run: set `EXPORT_RUN_ONCE=true`​ (e.g., `docker run --rm -e EXPORT_RUN_ONCE=true … docmost-exporter`) to trigger a manual export without starting the loop.

    ### NocoDB CSV Snapshots (Host script, hourly)

    - Script: `ops/backup/export-nocodb-csv.sh`
    - Purpose: export every public table from the NocoDB Postgres database to CSV for quick analysis without restoring dumps.
    - Output: `/srv/nocodb/exports/csv/<stamp>/schema_table.csv`​ with `latest/` symlink; retention trims directories older than 14 days.
    - Deployment:

      ```bash
      sudo install -m 700 ops/backup/export-nocodb-csv.sh /usr/local/sbin/export-nocodb-csv.sh
      ```
      Add a systemd timer (e.g., hourly) or reuse existing backup timer to run after nightly DB dumps:

      ```ini
      # /etc/systemd/system/export-nocodb-csv.service
      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/export-nocodb-csv.sh

      # /etc/systemd/system/export-nocodb-csv.timer
      [Timer]
      OnCalendar=*-*-* 02:30:00
      RandomizedDelaySec=5m
      Persistent=true

      [Install]
      WantedBy=timers.target
      ```
      Reload systemd and enable:

      ```bash
      sudo systemctl daemon-reload
      sudo systemctl enable --now export-nocodb-csv.timer
      ```
    - Optional offsite sync: extend the existing Google Drive sync script to copy `/srv/nocodb/exports/csv/latest`​ to `gdrive:nocodb-csv/latest` for analyst access.
    - Verification: confirm CSV files appear under `/srv/nocodb/exports/csv/<stamp>`​ and run `rclone ls gdrive:nocodb-csv/latest` if offsite sync is configured.


[^8]: # docmost-nocodb-tracker

    ---

    id: docmost-nocodb-tracker
    title: Docmost & NocoDB Project Tracker
    summary: Status tracker for migration tasks, thin slices, and operational follow-ups across Docmost and NocoDB.
    status: active
    owner: ops
    tags:

    - tracker
    - docmost
    - nocodb
      last_reviewed_at: 2025-10-28

    ---

    # Docmost & NocoDB Project Tracker

    |Workstream|Task|Owner|Status|Notes / Next Step|
    | -----------------------| --------------------------------------------------------------------------------------| ------------------| -------------| ---------------------------------------------------------------------------------------------------------------------------------------------------------------|
    |Phase 4 – Email|Verify Brevo deliverability from Docmost & NocoDB (invite/reset flows)|Ops|Complete|2025-10-21: Docmost `user_tokens`​ + NocoDB `reset_password_token` updated after API-triggered resets; Brevo path validated.|
    |Phase 4 – Email|Retire Mailpit once Brevo stability confirmed|Ops|Complete|2025-10-21: Mailpit service removed from `/srv/docmost/docker-compose.yml`, stack redeployed against Brevo-only SMTP; container/volume pruned.|
    |Phase 5 – Dashboard|Define replacement dashboard hostname (post-`pm` removal) and stand up landing service|App Team|In progress|​`dash.aienablement.academy` online with static hub; next: wire live status tiles, ops log timeline, and redesign per new data strategy.|
    |Phase 5 – Surveys|Deploy Formbricks stack (`/srv/formbricks`) behind proxy + DNS|Infra|Complete|2025-10-29: `forms.aienablement.academy`​ live (Formbricks 4.0.1, Postgres pgvector, Valkey). SMTP set to Brevo sender `learn@aienablement.academy`.|
    |Phase 5 – Surveys|Configure S3 storage for Formbricks uploads|Infra|Complete|AWS bucket `aea-formbricks`​ (us-east-2) wired via IAM user `aea-formbricks-s3`​; CORS + IAM policy documented in `formbricks-operations` runbook. Next: fold DB volume into nightly backups.|
    |Phase 5 – Hub|Deploy Colanode collaboration hub (`/srv/colanode`) behind proxy + DNS|Infra|Complete|2025-10-28: `hub.aienablement.academy` live with API routed through custom nginx config; next: seed workspaces and document onboarding.|
    |Phase 5 – UX|Document navigation paths (wiki ↔ ops ↔ dashboard) and update internal links|Content|Not started|Update Docmost landing pages once dashboard goes live.|
    |Phase 7 – n8n|Deploy automation stack (`/srv/n8n`) behind proxy + Cloudflare|Infra|Complete|2025-10-21: `n8n.aienablement.academy` live (Postgres backend, basic auth). Next: seed starter workflow + ops runbook.|
    |Phase 6 – Backups|Automate nightly `pg_dump` + volume tar for Docmost/NocoDB|Ops|Complete|Nightly timer + Google Drive sync operational; new `/usr/local/sbin/sync-to-oci.sh`​ + `backup-sync-oci.timer` promote weekly/monthly sets and push to OCI Object Storage with retention pruning.|
    |Phase 6 – Monitoring|Approve monitoring stack blueprint|Ops|Complete|2025-10-21: Selected Uptime Kuma + Dozzle with optional Netdata; slices A–D defined in programme plan.|
    |Phase 6 – Monitoring|Slice A – Deploy `/srv/monitoring` compose & join proxy|Ops|Complete|2025-10-21: Stack live with Kuma/Dozzle on `reverse-proxy`​; Netdata available via `metrics` profile, containers healthy.|
    |Phase 6 – Monitoring|Slice B – Configure monitors & notifications|Ops|Complete|Uptime Kuma seeded with Brevo SMTP notifier + monitors (wiki/ops/dash/n8n/SMTP); status page `main`​ live at `status.aienablement.academy` (Cloudflare proxied post-cert).|
    |Phase 6 – Monitoring|Slice C – Harden access & document|Ops|Complete|Cloudflare Access apps + policies guard `uptime.`​ `monitor.`​ `metrics.`; Dozzle basic auth removed, service token stored on host for metrics portal automation, docs update pending.|
    |Phase 6 – Monitoring|Slice D – Fire drill & dashboard badges|Ops|Not started|Simulate outage, verify alert delivery, log results in `MIGRATION_TASKS.md`​, surface status JSON + Access/Tailscale health on `dash.*`.|
    |Phase 6 – Backups|Docmost Markdown sync to Google Drive every 10 min|Ops|Complete|Containerised `docmost-exporter`​ (Alpine + rclone) runs `export-markdown.sh`​, refreshes `/srv/docmost/exports/markdown/latest`​, and syncs to `gdrive:docmost-markdown`.|
    |Phase 6 – Networking|Enroll infrastructure in Tailscale|Ops|Complete|​`docker-host`​ joined tailnet (`100.114.104.8`​, tag `infra`​); ACLs grant `autogroup:admin/member` SSH to tagged hosts. Next: document ops usage and integrate services.|
    |Phase 5 – Dashboard|Implement authenticated access & invite flow|App/Infra|Planned|Choose auth provider (Supabase vs Cloudflare Access upgrade), add invite-based registration, update runbooks & `.env` templates.|
    |Knowledge Base|Seed starter tables/workspaces in NocoDB|Product Ops|In progress|Create base templates (CRM, project tracker) to encourage adoption.|
    |Security|Review IAM/API keys (OCI, Cloudflare, Brevo) and schedule rotation|Ops|Not started|Add rotation cadence to OCI handbook once completed.|
    |Documentation|Keep runbooks (`.docs/agents/*.md`) current after each change|All contributors|Ongoing|Reference `MIGRATION_TASKS.md` for change history; update knowledge doc with lessons.|

    *Last updated: 2025-10-28.*


[^9]: # digitalocean-operations

    ---

    name: digitalocean-operations
    description: DigitalOcean cloud platform specialist for droplet management, storage, networking, and infrastructure automation
    model: opus
    color: blue
    id: digitalocean-operations
    summary: Procedures for administering DigitalOcean infrastructure, networking, and backups.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - infrastructure
    - cloud
      tooling:
    - digitalocean
    - terraform
    - networking

    ---

    # DigitalOcean Operations Guide

     Related playbooks: DevOps Operations Guide[^10], Docker Host Operations Guide[^11], Network Engineering Playbook[^12], Docmost &amp; NocoDB Backup SOP[^7].

    #digitalocean #cloud #infrastructure #ops

    ## Scope

    - Manage DigitalOcean account resources (Droplets, VPC, Spaces) alongside OCI stack.
    - Utilize `doctl`, Terraform, or MCP integration for automation.

    ## Access & Tooling

    - CLI setup:

      ```
      doctl auth init --access-token <token>
      doctl account get
      ```
    - Terraform provider:

      ```hcl
      provider "digitalocean" {
        token = var.do_token
      }
      ```
    - Store API tokens in a locked-down env file or operator-approved vault; rotate every 90 days.

    ## Droplet Management

    - Provisioning: prefer Terraform modules; ensure tags for environment and service.
    - Tag operations: `POST /v2/droplets/actions?tag_name=infra { "type": "enable_backups" }`.
    - Backups & snapshots: enable weekly backups or schedule snapshots prior to major changes.
    - Firewall: use cloud firewalls + ufw on host.

    ## Networking

     VPC: isolate workloads per environment; record CIDRs in Network Engineering Playbook[^12]. Floating IPs: attach for HA; update DNS accordingly. Monitoring: enable DO metrics agent; integrate with Uptime Kuma.

    ## Storage & Databases

    - Spaces: enforce lifecycle policies; store offsite backups.
    - Managed DB: configure trusted sources, rotate credentials, enable automated backups.

    ## Housekeeping

    - Monthly cost review; tag orphaned resources.
    - Use Projects to group related assets.
    - Audit account activity and ensure MFA enabled for all users.

    ## MCP Integration

    - Repository: `digitalocean-labs/mcp-digitalocean`.
    - Quick smoke: `npx @digitalocean/mcp --services droplets`.
    - Claude CLI example:

      ```bash
      claude mcp add digitalocean-mcp \
        -e DIGITALOCEAN_API_TOKEN=<token> \
        -- npx @digitalocean/mcp --services droplets,apps
      ```
    - Current estate: Codex CLI and both Claude installs already wired with DigitalOcean MCP plus Z.AI search/vision and codex-subagents.
    - 2025-10-31 smoke: `devops`​ subagent ran `digitalocean.droplet-list`​ → droplet `Moodle`​ (`id 523294750`​, status `active`​). See `.docs/kb/mcp-catalog.md`.

    ## References

    - DigitalOcean API docs – https://docs.digitalocean.com/reference/api/api-reference/
    - Tag actions – https://docs.digitalocean.com/products/droplets/how-to/tag/


[^10]: # devops-operations

    ---

    name: devops-operations
    description: DevOps engineering specialist for CI/CD, infrastructure automation, deployment strategies, and operational excellence
    model: opus
    color: red
    id: devops-operations
    summary: End-to-end operations handbook covering CI/CD, infrastructure automation, and incident response practices.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - infrastructure
    - automation
      tooling:
    - docker
    - git
    - ci-cd

    ---

    # DevOps Operations Guide

     Related playbooks: DigitalOcean Operations Guide[^9], Docker Host Operations Guide[^11], Cortex (SiYuan) Operations Agent[^2], Docmost &amp; NocoDB Migration Programme[^4].

    #devops #ops #automation #cicd

    ## Core Responsibilities

     Own CI/CD, configuration management, and observability for all self-hosted services. Enforce infrastructure-as-code (Terraform or Ansible) for OCI, DigitalOcean, and future clouds. Maintain environment parity (dev → staging → prod) and document release cadences in Migration Activity Log[^5].

    ## Tooling Baseline

    - Source control: git hooks + Conventional Commits; gate via PR templates.
    - Pipelines: GitHub Actions (preferred) with reusable workflows for lint, test, build, image publish.
    - Secrets: manage via locked-down env files (0600) and repository-based `.env.example`; never commit credentials.
    - Infra automation: Terraform modules per cloud provider; Ansible/Shell for host bootstrapping.

    ## CI/CD Checklist

     Build phase – compile assets, run unit tests, build Docker images with content-addressable tags (`git rev-parse --short HEAD`​). Test phase – execute integration or e2e suites (Vitest/Playwright) and upload artifacts. Security – run `npm audit`​, `trivy image`​, and secret scanners; break build on high severity. Deploy – push signed container images, update compose manifests via SSH or GitOps; record change in Migration Activity Log[^5].

    ## Observability & Incident Flow

    - Monitor (`/srv/monitoring`) health dashboards and Uptime Kuma alerts (Brevo + webhook).
    - Define SLOs per service; page on burn-rate thresholds.
    - Incident runbook: acknowledge alert, gather logs (Dozzle), evaluate via Netdata, mitigate, document postmortem within 24 h.

    ## Change Management

    - All infra changes require RFC in `.docs/projects/...` before execution.
    - Use feature flags or canary deployments where possible; schedule maintenance windows with status page notices.
    - Backups: verify nightly jobs, perform restore drills quarterly.

    ## References

    - HashiCorp Terraform IaC patterns – https://developer.hashicorp.com/terraform/intro
    - GitHub Actions best practices – https://docs.github.com/actions
    - Incident management primer – https://sre.google/sre-book/incident-response/


[^11]: # docker-host-operations

    ---

    name: docker-host-operations
    description: Expert in Docker host management, container orchestration, and infrastructure operations on Ubuntu servers. Use for Docker Engine troubleshooting, container lifecycle management, performance optimization, and system administration tasks.
    model: opus
    color: blue
    id: docker-host-operations
    summary: Runbook for managing the OCI Ampere Docker host, including container lifecycle, networking, and storage.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - infrastructure
    - containers
      tooling:
    - docker
    - caddy
    - linux

    ---

    # Docker Host Operations Guide

    > Related: DevOps Operations Guide[^10], Docmost &amp; NocoDB Backup SOP[^7], Migration Activity Log[^5], Docmost &amp; NocoDB Migration Programme[^4].
    >

    #docker #infrastructure #containers #ops

    ## Host Overview

    - **Platform**: Ubuntu 22.04 on OCI Ampere A1 (`163.192.41.116`).
    - **Primary user**: `ubuntu`​ (SSH via `~/Downloads/ssh-key-2025-10-17.key`).
    - **Docker/Compose**: Docker Engine 24+, Compose v2 (invoked as `docker compose`).
    - **Service root**: `/srv` — one directory per stack.

      ```
      /srv
      ├── proxy       # Caddy reverse proxy
      ├── docmost     # Docmost + Postgres + Redis + Mailpit
      ├── nocodb      # NocoDB + Postgres
      └── dash        # nginx landing page (dash.aienablement.academy)
      └── n8n         # n8n automation (Postgres-backed)
      ```

    ## Networks & Volumes

    - Shared network: `reverse-proxy` (external) connects app stacks to Caddy.
    - Docmost volumes:

      - ​`docmost_db_data` (Postgres)
      - ​`docmost_redis_data`
      - App data stored in `/srv/docmost/data` mounted via compose.
    - NocoDB volumes:

      - ​`nocodb_db_data`
      - ​`nocodb_data`
    - Proxy data: `proxy_caddy_data`​ holds TLS certs; do **not** delete unless intentionally rotating.

    ## Core Commands

    ```bash
    cd /srv/<service>
    sudo docker compose ps
    sudo docker compose logs -f
    sudo docker compose up -d
    sudo docker compose exec docmost-app sh
    ```
    ## Service-Specific Notes

    - ### Proxy (`/srv/proxy`)

      - Config file: `Caddyfile` (redirects docs → wiki, proxies docmost/nocodb, placeholder for dashboard).
      - Reload after edits: `sudo docker compose exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile`.
      - TLS certificates auto-managed; ensure new hostnames are added both to Caddyfile and Cloudflare DNS.
    - ### Docmost (`/srv/docmost`)

      - ​`.env`​ contains secrets (600 perms). Key entries: `APP_URL=https://wiki.aienablement.academy`, Brevo SMTP config.
      - Health checks: `curl -I https://wiki.aienablement.academy/api/health`.
      - Postgres debugging: `sudo docker compose exec docmost-db psql -U docmost -d docmost`.
      - Mailpit kept for troubleshooting; can be stopped if Brevo fully replaces it.
    - ### NocoDB (`/srv/nocodb`)

      - ​`.env`​ includes `NC_SMTP_*` (Brevo) and admin credentials.
      - Promote users via Postgres: `UPDATE nc_users_v2 SET roles='org-level-creator,super' WHERE email='...'`.
      - Remove `NC_ADMIN_EMAIL`​ / `NC_ADMIN_PASSWORD` after bootstrap to avoid rerun loops.
      - Health: `curl -I https://ops.aienablement.academy/api/v1/health`.
    - ### Dash (`/srv/dash`)

      - Static hub served by `nginx:alpine`​; edit `/srv/dash/html/index.html` for bookmark updates.
      - Health: `curl -I https://dash.aienablement.academy`.
    - ### n8n (`/srv/n8n`)

      - ​`.env` holds auth, Postgres creds, encryption key (600 perms).
      - Stack control: `sudo docker compose ps`​, `sudo docker compose logs -f n8n-app`.
      - Health: `curl -sSf https://n8n.aienablement.academy/healthz` (expects HTTP/2 200). Admin UI requires basic auth.

    ## Deploying New Services

    1. Create `/srv/<service>`​ with compose file + `.env`.
    2. Join `reverse-proxy` network in compose.
    3. Add site block to `/srv/proxy/Caddyfile`.
    4. Update Cloudflare DNS pointing to `163.192.41.116`.
    5. ​`sudo docker compose up -d`, then reload Caddy.

    ## Maintenance Tasks

    - Upgrades: `sudo docker compose pull && sudo docker compose up -d`​; log in Migration Activity Log[^5].
    - Backups: leverage scripts in `ops/backup/`​ (see Docmost &amp; NocoDB Backup SOP[^7]) and confirm nightly timers succeed.
    - Disk monitoring: `df -h /srv`​, `sudo docker system df`.
    - Cleanup (post-validation): `sudo docker system prune --volumes`.

    ## Troubleshooting

    - 502 from Caddy → confirm target stack via `docker compose ps`, inspect logs.
    - TLS issuance issues → verify Cloudflare DNS + Caddyfile entries; check `docker logs caddy-proxy`.
    - SMTP failures → run Python `smtplib` test from host/container; ensure Brevo domain verified.
    - High CPU → `sudo docker stats`, inspect container-level metrics (Netdata, Uptime Kuma).

    ## Change Logging

    - Record every significant change in Migration Activity Log[^5] and trackers like Docmost &amp; NocoDB Project Tracker[^8] with:

      - UTC timestamp
      - Commands/scripts executed
      - Verification steps
    - Snapshot compose/env files before experiments (`cp file file.bak-YYYYMMDD`).


[^12]: # network-engineering-playbook

    ---

    id: network-engineering-playbook
    title: Network Engineering Playbook
    summary: Reference architecture and operational guidelines for network design across OCI, Cloudflare, and Tailscale.
    tags:

    - networking
    - infrastructure
      status: active
      owner: ops
      last_reviewed_at: 2025-10-26

    ---

    # Network Engineering Playbook

    ## Topology & Addressing

    - Maintain inventory of VPCs/subnets per provider (OCI 10.0.0.0/24, future DigitalOcean VPC TBD).
    - Reserve CIDRs for services requiring private connectivity (e.g., database backplane).
    - Document DNS zones (Cloudflare) and subdomain assignments (`wiki`​, `ops`​, `dash`​, `status`​, `uptime`​, `monitor`​, `metrics`​, `n8n`).

    ## Connectivity Patterns

    - Reverse proxy (Caddy) terminates TLS for all web services; ensure Cloudflare proxy toggled during ACME issuance.
    - Internal access via Tailscale overlay; advertise subnets only when necessary.
    - For remote Docker hosts, expose socket through TLS proxies or Tailscale-only endpoints.

    ## Security Controls

    - Enforce least privilege security lists/firewalls (allow 80/443/22 only).
    - Use Cloudflare Access or Tailscale ACLs for admin surfaces.
    - Enable logging/analytics on Cloudflare to detect anomalies.
    - TLS: issue Let's Encrypt via Caddy; auto-renew; monitor expiry with Uptime Kuma.

    ## Monitoring & Diagnostics

    - Synthetic checks: Uptime Kuma HTTP/TCP/ICMP monitors.
    - Flow analysis: Netdata charts for network throughput.
    - Troubleshooting commands:

      ```
      ping, mtr, traceroute
      ss -tulpn
      sudo tcpdump -i eth0 port 443
      tailscale status
      ```

    ## Change Management

    - Before DNS changes: lower TTL to 120 seconds, plan maintenance window, update MIGRATION_TASKS.md.
    - After change: verify with `dig`​, `curl`​, and SSL handshake (`openssl s_client -connect host:443`).
    - Maintain rollback plan (previous DNS records, snapshot of proxy config).

    ## Future Enhancements

    - Evaluate HAProxy/Envoy if traffic scales.
    - Consider dedicated logging pipeline (Vector + Loki) for network events.
    - Automate firewall audits through Terraform or `doctl/oci` CLI.

    ## References

    - Cloudflare DNS & Access docs – https://developers.cloudflare.com/
    - Tailscale networking – https://tailscale.com/kb/


[^13]: # metadata-standards

    ---

    id: metadata-standards
    title: Cortex Metadata Standards
    summary: Required fields, attributes, and validation rules for Cortex documents.
    status: active
    owner: knowledge-ops
    tags:

    - cortex
    - metadata
    - governance
      last_reviewed_at: 2025-11-03

    ---

    # Cortex Metadata Standards

    #governance #metadata #cortex

    ## Front Matter Requirements

    Every canonical note (projects, runbooks, knowledge articles, logs) must include YAML front matter with the following keys:

    - ​`id`: stable slug matching Git source (kebab-case).
    - ​`title`: human-friendly name.
    - ​`summary`: one-line description for search results.
    - ​`status`​: `draft`​, `active`​, or `archived`.
    - ​`owner`​: primary steward (`ops`​, `knowledge-ops`​, `revops`, etc.).
    - ​`tags`: array of taxonomy hashtags (see [[Tag Taxonomy]]) plus topic keywords.
    - ​`last_reviewed_at`: ISO date of last manual verification.

    Optional keys:

    - ​`domains`​: array (e.g., `infrastructure`​, `automation`​, `gtm`).
    - ​`dependencies`: list of upstream artefacts.
    - ​`outputs`: generated artefacts from the process.

    ## Block Attributes (Future Automation)

    When MCP automation supports it, set block attributes on the document root:

    - ​`status`​, `owner`​, `review_date`​, `domain`​, `automation` (values mirror front matter).
    - Use `siyuan_set_block_attrs`​ or the upcoming `metadata-harmonizer` script to enforce.

    ## Hashtags & Inline Metadata

    - Add canonical hashtags in the first paragraph (e.g., `#ops #backup`).
    - Reference related artefacts with block refs `((block-id "Label"))` to light up backlinks and the graph.
    - When logging actions, include timestamp + agent in plain text and refer back to the owning runbook/log entry.

    ## Validation Workflow

    1. New content: use Templates (`/Templates/Metadata Check`) to scaffold front matter and tag block.
    2. Weekly: run `scripts/qa/metadata-audit.py`​ (to be built) to flag missing fields or stale `last_reviewed_at`.
    3. Monthly: knowledge steward updates `Knowledge Freshness Dashboard` database and triggers review reminders.

    ## Review Cadence

    - Project plans: every 2 weeks or at phase completion.
    - Runbooks/SOPs: quarterly.
    - Logs & trackers: continuous; ensure entries reference knowledge assets via block refs.

    Document updates to this standard in Migration Activity Log[^5] and notify stewards in Docmost.


[^14]: # tag-taxonomy

    ---

    id: tag-taxonomy
    title: Cortex Tag & Hashtag Taxonomy
    summary: Controlled vocabulary for hashtags and domains across Cortex notebooks.
    status: active
    owner: knowledge-ops
    tags:

    - cortex
    - metadata
    - taxonomy
      last_reviewed_at: 2025-11-03

    ---

    # Cortex Tag & Hashtag Taxonomy

    #taxonomy #hashtags #metadata

    ## Namespace Principles

    - Use lowercase with `/`​ namespace for hierarchies (e.g., `#ops/backup`​, `#ops/network`).
    - Generic qualifiers (e.g., `#runbook`​, `#project`​, `#decision`​, `#experiment`) supplement domain tags.
    - Every page should have at least one domain tag and one artefact type tag.

    ## Core Domains

    |Tag|Description|Examples|
    | ------| -------------------------------------------| --------------------------------------------------------------------------------|
    |​`#ops/infrastructure`|Infrastructure runtime, hosts, networking|[[Network Engineering Playbook]], [[System Architecture Guidelines]]|
    |​`#ops/backup`|Backup & restoration procedures|[[Docmost & NocoDB Backup SOP]]|
    |​`#ops/automation`|MCP, scripts, n8n flows|[[Tools & Scripts Overview]], cortex-task-log[^1]|
    |​`#ops/knowledge`|Second-brain governance|[[Cortex Metadata Standards]], [[Tag & Hashtag Taxonomy]]|
    |​`#ops/projects`|Programme plans & trackers|[[Docmost & NocoDB Migration Programme]], [[Docmost & NocoDB Project Tracker]]|
    |​`#ops/logs`|Activity logs & change diaries|[[Migration Activity Log]]|
    |​`#gtm/research`|Market, competitor, research docs|research-intelligence (pending import)|
    |​`#product/workflow`|Product discovery/delivery templates|[[Knowledge Base Overview]] (link to templates)|

    ## Artefact Types

    - ​`#runbook` – Operational procedure.
    - ​`#project` – Multi-step initiative or plan.
    - ​`#tracker` – Status board or thin-slice log.
    - ​`#decision` – Decision record or outcome summary.
    - ​`#experiment` – Experiment log or test.
    - ​`#template` – Reusable document skeleton.

    ## Status Tags (optional)

    - ​`#status/draft`
    - ​`#status/active`
    - ​`#status/archived`

    ## Enforcement

    - Apply hashtags in the first paragraph of each page.
    - Automation will validate tags during sync; missing tags raise alerts in the Knowledge Freshness dashboard.
    - When introducing new tags, append to this taxonomy and broadcast via Docmost release note.

    Update taxonomy changes in Migration Activity Log[^5] and ensure runbooks adopt the new tags during their next review.


[^15]: # projects-dashboard

    ---

    id: projects-dashboard
    title: Projects Dashboard
    summary: Snapshot of active programmes with owners, status, and next reviews.
    status: active
    owner: ops
    tags:

    - ops
    - dashboard
    - projects
      last_reviewed_at: 2025-11-03

    ---

    # Projects Dashboard

    #dashboard #projects #ops

    |Project|Owner|Status|Next Review|Linked Artefact|
    | ----------------------------------------------| -------------| -----------| -----------| ---------------|
    |Docmost & NocoDB Migration|ops|Active|2025-11-10|Programme|
    |Backup SOP Enhancements|ops|Active|2025-11-07|SOP|
    |((20251103054501-a628uze "Cortex Enablement"))|knowledge-ops|In Progress|2025-11-08|Usage Guide|
    |Automation Estate (MCP + Scripts)|ops|In Progress|2025-11-12|Tools & Scripts|

    > Update this table weekly or convert to a SiYuan database block when the automation suite is ready.
    >


[^16]: # knowledge-freshness

    ---

    id: knowledge-freshness-dashboard
    title: Knowledge Freshness Dashboard
    summary: Review schedule and confidence for critical knowledge assets.
    status: active
    owner: knowledge-ops
    tags:

    - dashboard
    - knowledge
    - ops
      last_reviewed_at: 2025-11-03

    ---

    # Knowledge Freshness Dashboard

    #dashboard #knowledge #ops

    |Artefact|Owner|Last Reviewed|Target Cadence|Confidence|Notes|
    | ------------------------------------------------------------| -------------| -------------| --------------| ----------| -----------------------------------------------------|
    |Network Engineering Playbooknetwork-engineering-playbook|ops|2025-10-26|Quarterly|High|Coordinate CIDR updates with Cloudflare + Tailscale.|
    |System Architecture Guidelinessystem-architecture-guidelines|ops|2025-10-26|Quarterly|Medium|Add Cortex integration diagrams next review.|
    |Docmost & NocoDB Lessons Learneddocmost-nocodb-lessons|ops|2025-10-26|Monthly|Medium|Capture Formbricks follow-ups post verification.|
    |Cortex (SiYuan) Operations & Usage Guidecortex-siyuan-system|knowledge-ops|2025-11-03|Bi-weekly|Medium|Update metadata automation section once scripts ship.|
    |Knowledge Base Overviewknowledge-base-overview|knowledge-ops|2025-11-03|Weekly|High|Ensure new docs added after sync runs.|

    Use this dashboard during weekly reviews to assign refresh tasks and log updates in Migration Activity Log[^5].


[^17]: # automation-inventory

    ---

    id: automation-inventory-dashboard
    title: Automation Inventory Dashboard
    summary: Overview of scripts, MCP tools, and automation coverage.
    status: active
    owner: ops
    tags:

    - dashboard
    - automation
    - ops
      last_reviewed_at: 2025-11-03

    ---

    # Automation Inventory Dashboard

    #dashboard #automation #ops

    |Asset|Type|Owner|Coverage|Linked Artefact|Last Touch|
    | -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| -------------| -------------| ---------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ----------|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`scripts/sync/siyuan-export.py\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|Sync Script|knowledge-ops|Git → Cortex|Skillcortex-task-log|2025-11-03|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`ops/backup/backup-doc-platform.sh\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|Backup Script|ops|Docmost/NocoDB/Cortex|SOPdocmost-nocodb-backup-sop|2025-10-22|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`ops/backup/sync-to-oci.sh\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|Backup Script|ops|OCI Offsite|Log EntryAuthored ops/backup/sync-to-oci.sh to promote the most recent daily backup set into /srv/backups/weekly and /srv/backups/monthly, upload to OCI Object Storage bucket infra-backups, and prune retention (keep 4 weekly / 6 monthly locally and remotely). Script logs to /srv/backups/oci-sync.log. Added supporting units ops/backup/sync-to-oci.service and ops/backup/sync-to-oci.timer (scheduled Sundays 03:30 UTC with 5 m jitter) and documented the installation procedure in Docmost &amp; NocoDB Backup SOP[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^7]. Updated Docmost &amp; NocoDB Migration Programme[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^4] and Docmost &amp; NocoDB Project Tracker[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^8] to mark the backup workstream complete; first scheduled OCI sync will run after the nightly backup cycle on 2025-10-26. Refined export-docmost-markdown.sh to stage exports in-memory, refresh only /srv/docmost/exports/markdown/latest, and prune any older timestamp directories so Google Drive retains just the newest Markdown set (Drive keeps versions automatically).|2025-10-22|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`mcp/cortex\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|MCP Server|knowledge-ops|Cortex Automation|Agentcortex-siyuan-ops|2025-11-03|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`mcp-servers/codex-subagents-mcp\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|MCP Server|ops|Delegate Workflows|Log EntryCloned and built mcp-servers/codex-subagents-mcp, then registered it with Codex CLI, Claude Code, and Claude Z.AI (Node entrypoint + agents dir wired in configs) to unlock delegate flows. Added DigitalOcean MCP with inline token plus Z.AI Web Search (https://api.z.ai/api/mcp/web\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_search\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_prime/mcp) and Vision (npx -y @z\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_ai/mcp-server) servers across Codex CLI (\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\~/.codex/config.toml), Claude Code (claude-code/.claude/.claude.json), and Claude Z.AI (claude-zai/.claude/.claude.json); verified connectivity via codex mcp list and claude mcp list. Exercised delegates and documented outcomes; noted the Web Search transport limitation for follow-up. Updated runbooks (DigitalOcean Operations Guide[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^9], .docs/agents/digitalocean-operations.md) and the infrastructure expansion roadmap to document the new MCP surface area; tokens noted for rotation. 2025-11-02 follow-up: removed the Z.AI Web Search HTTP entry from Codex CLI config to prevent missing field command errors until native HTTP transports land; catalog + AGENTS docs updated with the mitigation.|2025-10-29|
    |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`scripts/mcp/cortex-mcp.sh\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\`|Launcher|knowledge-ops|Cortex MCP|Tools & ScriptsSkill[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^1] – Uploads knowledge bundles to Cortex; maintained by Cortex (SiYuan) Operations Agent[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^2].   Docmost &amp; NocoDB Backup SOP[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^7] – Nightly Docmost/NocoDB/Cortex backup driver; see Docmost &amp; NocoDB Backup SOP[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^7].   ops/backup/sync-to-gdrive.sh – Google Drive offsite sync companion; referenced in Migration Activity Log[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^5].   ops/backup/sync-to-oci.sh – OCI Object Storage promotion for weekly/monthly sets; linked from Docmost &amp; NocoDB Backup SOP[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^7].   ops/docmost/export-markdown.sh & container build (ops/docmost-exporter/) – Continuous Docmost markdown exporter; governed by Docmost Administration Guide[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^32].   scripts/infra/generate\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_harbor\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_proxy.py – Generates harbor.fyi proxy configs; see Migration Activity Log[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^5] entries on Harbor inventory.   scripts/mcp/cortex-mcp.sh – Launch helper for mcp/cortex; tied to Cortex (SiYuan) Operations &amp; Usage Guide[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^3].   Cortex (SiYuan) Operations &amp; Usage Guide[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^3] TypeScript bridge – Provides automation surface for Cortex; owned by Cortex (SiYuan) Operations Agent[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^2].   mcp-servers/codex-subagents-mcp/ – Delegation framework for Codex/Claude; coordinate with DevOps Operations Guide[\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\^10].|2025-11-03|

    Add new automation assets here during deployment and link to their runbooks and logs. Highlight gaps or desired coverage in the Knowledge Freshness review.


[^18]: # metadata-check-template

    ---

    id: metadata-check-template
    title: Metadata & Tag Check Template
    owner: knowledge-ops
    status: active
    last_reviewed_at: 2025-11-03
    tags:

    - template
    - metadata

    ---

    # Metadata & Tag Check Template

    ```
    ---
    id:
    title:
    summary:
    status: draft
    owner:
    tags:
      -
    last_reviewed_at:
    ---

    # <Title>

    #<domain> #<type>

    > Related: ((block-id "Label")), ((block-id "Label"))
    ```
    ## Quick Checklist

    - [ ] Front matter fields populated (id, summary, status, owner, tags, last_reviewed_at).
    - [ ] Hashtags added in first paragraph using taxonomy from Tag &amp; Hashtag Taxonomy[^14].
    - [ ] Linked artefacts referenced via block refs `((block-id "Label"))`.
    - [ ] Metadata attributes captured for automation (status, owner, review cadence).
    - [ ] Entry added to relevant dashboard (Projects, Knowledge Freshness, Automation).

    Duplicate this template when creating new knowledge assets.


[^19]: # knowledge-base-overview

    # Knowledge Base Overview

    #knowledge #index #ops

    ## Core Playbooks

     Network Engineering Playbook[^12] – Subnetting, DNS, TLS, and connectivity guardrails. System Architecture Guidelines[^20] – Platform principles and reference architecture. SQL &amp; PostgreSQL Playbook[^21] – Database administration, tuning, and recovery guidance. Docmost &amp; NocoDB Lessons Learned[^6] – Field notes and caveats from the migration programme. Cortex (SiYuan) Operations &amp; Usage Guide[^3] – How the second brain is structured and automated.

    ## Projects & Programmes

     Docmost &amp; NocoDB Migration Programme[^4] – End-to-end plan for the documentation/data platform transition. Docmost &amp; NocoDB Backup SOP[^7] – Nightly/weekly/monthly backup procedures and scripts. Docmost &amp; NocoDB Project Tracker[^8] – Thin-slice progress and follow-ups. Infrastructure &amp; Operations Inventory[^22] – Estate map across OCI, Proxmox, DigitalOcean, SaaS. Cloudflare Workers MCP Architecture[^23] – Edge automation strategy and fallback design. Multi-Environment Infrastructure Operations Expansion[^24] – Roadmap for unified ops coverage. Projects Dashboard[^15] – Active initiative tracker. Knowledge Freshness Dashboard[^16] – Review cadence board. Automation Inventory Dashboard[^17] – Script and MCP coverage summary.

    ## Operational Logs

     Migration Activity Log[^5] – Chronological record of stack changes, incidents, and validations.

    > Use this page as the second-brain landing zone—add new knowledge assets here with hashtags and cross-links so they appear in the graph and backlinks panels.
    >

    ## Metadata & Governance

    - Cortex Metadata Standards[^13] – Required front matter, attributes, and review cadence.
    - Tag &amp; Hashtag Taxonomy[^14] – Controlled hashtags and domain namespaces.
    - Metadata &amp; Tag Check Template[^18] – Quick template for new notes.


[^20]: # system-architecture-guidelines

    ---

    id: system-architecture-guidelines
    title: System Architecture Guidelines
    summary: High-level architecture principles for the AI Enablement platform, covering service boundaries and resilience patterns.
    tags:

    - architecture
    - infrastructure
      status: active
      owner: ops
      last_reviewed_at: 2025-10-26

    ---

    # System Architecture Guidelines

    ## Principles

    - Favor modular services with clear ownership (Docmost, NocoDB, n8n, monitoring).
    - Prioritize resilience: no single container should compromise the stack; use separate Postgres instances where necessary.
    - Document data flow and dependencies; update diagrams in `.docs/diagrams/` when architecture changes.

    ## Reference Architecture

    - Entry: Cloudflare → Caddy reverse proxy (`/srv/proxy`).
    - Application tier: Docker Compose stacks (`/srv/<service>`​), each on isolated network + shared `reverse-proxy`.
    - Data tier: Postgres instances per workload; backups synced to external storage.
    - Observability: Uptime Kuma (synthetic), Dozzle (logs), optional Netdata (metrics).
    - Automation: n8n orchestrates cross-service workflows.

    ## Non-Functional Requirements

    - Availability: target ≥ 99 % uptime; perform change during low-traffic windows.
    - Performance: maintain < 200 ms TTFB for primary apps; monitor through synthetic checks.
    - Security: enforce HTTPS everywhere, keep secrets in locked-down env files or an operator-approved vault, and apply the principle of least privilege.
    - Scalability: design for horizontal expansion (additional OCI or DO nodes) via Terraform modules.
    - Maintainability: keep runbooks up to date; use thin slices for rollouts.

    ## Decision Framework (SPARC/BMAD)

    - Situation/Problem: capture context and constraints before choosing tools.
    - Actions: incremental slices with measurable verification.
    - Results: define success metrics (uptime, latency, adoption).
    - Confirmation: smoke tests + documentation updates after each change.

    ## Change Evaluation Checklist

    1. Does the change introduce a new dependency? Document configuration & backup plans.
    2. Is rollback defined (e.g., previous compose file, DB snapshot)?
    3. Have security/privacy implications been reviewed?
    4. Are monitoring hooks updated (Kuma monitors, dashboard links)?
    5. Has the team been notified (Docmost release notes, MIGRATION_TASKS.md)?

    ## References

    - Google SRE Workbook – https://sre.google/workbook/table-of-contents/
    - Architectural decision records (ADR) template – https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions


[^21]: # sql-postgres-playbook

    ---

    id: sql-postgres-playbook
    title: SQL & PostgreSQL Playbook
    summary: Administration and optimization guide for PostgreSQL instances backing Docmost, NocoDB, and automation stacks.
    tags:

    - postgres
    - database
      status: active
      owner: ops
      last_reviewed_at: 2025-10-26

    ---

    # SQL & PostgreSQL Playbook

    ## Administration Checklist

    - Connection URL format: `postgres://user:pass@host:5432/db?sslmode=require`.
    - Use least-privilege roles (`CREATE ROLE app_user LOGIN PASSWORD '***'; GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO app_user;`).
    - Enforce UTF8MB4 encoding and `lc_collate=en_US.UTF-8`.

    ## Maintenance

    - Backups: nightly `pg_dump -Fc` per database; weekly base backups for point-in-time recovery.
    - VACUUM/ANALYZE: schedule `pg_cron`​ or run `VACUUM (ANALYZE)` on busy tables to prevent bloat.
    - Upgrades: perform `pg_upgrade` or logical replication; test on staging first.

    ## Performance Tuning

    - Monitor with `pg_stat_statements` (create extension); analyze top queries.
    - Key parameters:

      - ​`shared_buffers = 25% RAM`
      - ​`work_mem = 16MB` (adjust per workload)
      - ​`maintenance_work_mem = 256MB`
      - ​`effective_cache_size = 50% RAM`
    - Index strategy: composite indexes match query patterns; avoid redundant indexes.
    - Use EXPLAIN (ANALYZE, BUFFERS) to diagnose slow queries.

    ## Backup & Restore

    - Dump:

      ```
      pg_dump -Fc --no-owner --dbname=docmost > docmost_$(date +%F).dump
      ```
    - Restore:

      ```
      pg_restore --clean --create --dbname=postgres docmost.dump
      ```
    - Verify checksums (`pg_verifybackup`) and perform restore drills quarterly.

    ## Security

    - Enforce TLS (configure `ssl = on`, provide cert/key).
    - Restrict access via `pg_hba.conf`​ (use `hostssl`, CIDR).
    - Rotate credentials; store secrets in host-scoped env files (`0600`) or another operator-approved vault.
    - Enable logging (`log_min_duration_statement = 500`​, `log_checkpoints=on`).

    ## Monitoring

    - Collect metrics via Netdata or Prometheus exporters.
    - Track replication lag (`pg_stat_replication`).
    - Watch for autovacuum conflicts, deadlocks, disk usage.

    ## References

    - PostgreSQL docs – https://www.postgresql.org/docs/
    - Tuning guide – https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server


[^22]: # infra-inventory

    ---

    id: infra-inventory
    title: Infrastructure & Operations Inventory
    summary: Canonical list of infrastructure, SaaS, and automation assets managed by Codex/Claude.
    status: draft
    owner: ops
    tags:

    - infrastructure
    - automation
    - inventory
      last_reviewed_at: 2025-10-28

    ---

    # Infrastructure & Operations Inventory

    ## 1. Physical & Virtual Hosts

    |Host|Location|Role|Key Services|Notes|
    | ------| ----------------| ---------------| -----------------------------------------------------------------------------| --------------------------------------------------|
    |​`oci-ampere-01`|OCI (PHX)|Primary stack|Docmost, NocoDB, Caddy proxy, Uptime Kuma, Dozzle, Netdata, n8n, dashboards|Ubuntu 22.04, Docker Compose, Cloudflare proxied|
    |​`local-proxmox-01`|On-prem (rack)|Hypervisor|Proxmox VE, Portainer, local n8n, misc containers|Behind Tailscale; hosts Whisper/Ollama plans|
    |​`local-nas-01`|QNAP NAS|Storage|File shares, backup targets, media vault|Needs snapshot + offsite sync SOP|
    |​`do-moodle-01`|DigitalOcean|LMS|Moodle production|Email via Brevo; nightly backups to OCI|

    ## 2. Core Services & Containers

    |Service|Host|Type|Status/Notes|
    | --------------------------| ----------------------| ------------------| -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    |Docmost|​`oci-ampere-01`​ (`/srv/docmost`)|Documentation|Prod + Brevo SMTP; Markdown exporter container running|
    |NocoDB|​`oci-ampere-01`​ (`/srv/nocodb`)|Low-code DB|Public at `ops.aienablement.academy`; Brevo SMTP|
    |Caddy Proxy|​`oci-ampere-01`​ (`/srv/proxy`)|Reverse proxy|Handles TLS for wiki/ops/status/monitor/metrics/n8n/dash|
    |n8n|​`oci-ampere-01`​ (`/srv/n8n`)|Automation|Behind Cloudflare Access; Postgres backend|
    |Uptime Kuma|​`oci-ampere-01`​ (`/srv/monitoring`)|Monitoring|Protected by Cloudflare Access|
    |Dozzle|​`oci-ampere-01`​ (`/srv/monitoring`)|Logs|Cloudflare Access|
    |Netdata|​`oci-ampere-01`​ (`/srv/monitoring`)|Metrics|Exposed via `metrics.aienablement.academy` portal|
    |Static Dash|​`oci-ampere-01`​ (`/srv/dash`)|Status dashboard|Consumes monitoring + backup data|
    |Docmost Exporter|​`oci-ampere-01`​ (`/srv/docmost-exporter`)|Markdown sync|10-minute cadence, rclone to Google Drive|
    |Local n8n|​`local-proxmox-01`|Automation|For home stack workflows|
    |Portainer|​`local-proxmox-01`|Container UI|Manage home containers|
    |DDNS Updater|​`docker.harbor.fyi`​ (Proxmox VM `101`)|DNS automation|qdm12/ddns-updater; UI proxied at `ddns.harbor.fyi`​ (Tailnet-only via NPM host id 5 + dnsmasq override on `nginxproxymanager`​); compose file `/root/docker-compose.yml`​; config volume `/var/lib/docker/volumes/root_ddns-updater-data/_data/config.json`​; rotate Porkbun keys and redeploy with `docker compose up -d ddns-updater`|
    |Jellyfin|​`local-proxmox-01`​ (`pct 103`)|Media server|AMD Radeon 780M passthrough; exposed via `jellyfin.harbor.fyi`|
    |Whisper/Ollama (planned)|​`local-proxmox-01`|AI inference|GPU sizing TBD|
    |Qdrant (planned)|​`oci-ampere-02` (future)|Vector DB|For embeddings / search|

    ## 3. SaaS & Cloud Providers

    |Provider|Scope|Integrations|Notes|
    | -------------------| ----------------------------| -------------------------------------| ----------------------------------------|
    |Cloudflare|DNS, Access, Zero Trust|Proxy, Access apps, Tunnel (future)|Official MCP available|
    |Stripe|Billing|Stripe CLI, reporting|Use Stripe Agent Toolkit|
    |Brevo|Email SMTP|Docmost + NocoDB transactional mail|Monitor deliverability|
    |Google Workspace|Docs, Slides, Drive, Gmail|Manual|Need Workspace MCP/automation wrappers|
    |Ghost CMS|Marketing site|Manual deploy|Build automation + MCP adapter|
    |JS marketing site|Marketing|Git-based deploy|Add CI/CD + analytics tagging|
    |DigitalOcean|Moodle hosting|Droplet mgmt|Evaluate DO MCP or CLI|

    ## 4. Data & AI Assets

    |Asset|Location|Description|Notes|
    | --------------------------| --------------------| --------------------------------------| -------------------------|
    |Docmost Markdown Exports|GDrive `docmost-markdown`|Latest Markdown snapshot|Nightly + manual export|
    |Siyuan Notebook|​`.docs/exports/siyuan-export-20251026...zip`|Knowledge import bundle|Update weekly|
    |NocoDB tables|​`ops.aienablement.academy`|Project trackers, automation assets|Will host KPIs|
    |Model Artifacts|TBD (local server)|Whisper/Ollama models, RLHF datasets|Plan versioning/storage|

    ## 5. Automation & Scripts

    |Path|Purpose|Notes|
    | ------| ------------------------------------------------| ---------------------------------------------------|
    |​`scripts/sync/claude-sync.sh`|Sync agents/skills/plugins to Claude installs|Needs extension for new plugins|
    |​`scripts/sync/build_index.py`|Build docs index metadata|Runs inside sync|
    |​`scripts/sync/nocodb-sync.py`|Placeholder for NocoDB automation|Complete implementation|
    |​`scripts/sync/siyuan-export.py`|Siyuan export tooling|Align with new schedule|
    |​`scripts/export_ops_activity.py`|Dashboard data export|Feeds ops dashboard|
    |​`scripts/infra/generate_harbor_proxy.py`|Render harbor.fyi Nginx configs from inventory|Sync output to `/data/nginx/inventory/` on proxy LXC, then reload Nginx|
    |​`/srv/docmost-exporter/export-markdown.sh`|Docmost markdown export|Cron container|

    ## 6. Credentials & Secrets (inventory only)

    |Scope|Storage|Rotation Plan|
    | ------------------------| -----------------------| --------------------------------------|
    |Cloudflare API token|1Password vault / env|Rotate quarterly|
    |Brevo SMTP|​`/srv/docmost/.env`​, `/srv/nocodb/.env`|Rotate with Brevo policy|
    |Docmost automation JWT|​`/srv/docmost-exporter/secrets`|Long-lived; refresh annually|
    |Stripe keys|Secure vault|Use Stripe CLI tokens for automation|
    |OCI auth|​`~/.oci/config`|Already rotating via IAM policies|

    ## 7. Pending Additions

    |Initiative|Owner|Target Window|Concrete Actions|
    | -----------------------------| ---------------| ---------------| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    |Qdrant Vector DB (`oci-ampere-02`)|ML Ops|Q4 2025|- Provision Ampere A1 instance with block volume (500 GB).<br />- Deploy via `docker compose`​ using manifests under `mcp/oci-fallback/manifests`.<br />- Wire backups with `scripts/ml/qdrant-backup.py` + NAS sync.<br />- Expose read-only endpoints through Cloudflare Worker adapter (already scaffolded).|
    |Whisper & Ollama Stack (`local-proxmox-01`)|Infra Ops|Q1 2026|- Install NVIDIA GPU + drivers, enable passthrough to Ubuntu VM.<br />- Containerise Whisper + Ollama with `scripts/ml/model-deploy.sh` for model lifecycle.<br />- Publish inference endpoints via Tailscale + Cloudflare Worker fallback.<br />- Document resource monitoring via Netdata integration.|
    |CRM Selection & Integration|RevOps|Q4 2025|- Evaluate HubSpot vs Salesforce (licensing, API breadth, MCP availability).<br />- Prototype ingestion using NocoDB mirror + Cloudflare Worker adapter stub (`stripe` pattern).<br />- Finalise CRM data residency + security controls in Docmost runbook.<br />- Update Claude/Codex marketplace manifests once platform selected.|
    |Google Workspace Automation|Workspace Ops|Q4 2025|- Build service account + domain-wide delegation.<br />- Extend Worker project with `workspace` adapter (Docs, Slides, Drive).<br />- Implement scheduled exports to Docmost via `scripts/run-export.sh` templates.<br />- Add compliance logging to NocoDB audit tables.|

    > This inventory mirrors to Docmost under `Operations/Inventory/Infra`. Update both repositories whenever assets change.
    >


[^23]: # cloudflare-workers-mcp-architecture

    ---

    id: cloudflare-workers-mcp-architecture
    title: Cloudflare Workers MCP Architecture
    summary: Deployment plan for hosting Model Context Protocol servers on Cloudflare Workers with OCI fallback.
    status: draft
    owner: ops
    tags:

    - mcp
    - cloudflare
    - automation
      last_reviewed_at: 2025-10-28

    ---

    # Cloudflare Workers MCP Architecture

    ## 1. Goals

    - Provide low-latency, globally distributed MCP endpoints for Claude Code, Claude Z.AI, and Codex CLI.
    - Centralise authentication, observability, and rate limiting for shared services (DNS, Access, analytics, marketing APIs).
    - Maintain OCI-based fallback deployment for workloads unsuitable for Workers (long-running tasks, heavy CPU/GPU).

    ## 2. Topology Overview

    ```
    Claude / Codex Clients
            │
            ▼
    Cloudflare Workers (MCP) ──► Service Adapters (HTTP/GraphQL/gRPC)
            │                        │
            │                        ├─ Cloudflare APIs (DNS, Access, Zero Trust)
            │                        ├─ Stripe Agent Toolkit MCP
            │                        ├─ Oracle MCP servers (via OCI private workers or direct)
            │                        ├─ SaaS REST APIs (Ghost, HubSpot/Salesforce, Brevo)
            │                        └─ Internal services (Docmost, NocoDB, Qdrant, Proxmox via Tunnel)
            ▼
    Observability Stack (Workers Logs → Logpush → R2/SIEM)
    ```
    ## 3. Workers Deployment Pattern

    - **Repository**: `cloudflare/mcp-server-cloudflare` (fork for custom routes).
    - **Runtime**: Workers Durable Objects for stateful actions (e.g., caching API tokens, rate limits).
    - **Auth**:

      - Use Cloudflare Access service tokens for machine-to-machine requests.
      - For SaaS APIs, store credentials in Workers Secrets (retrieved from 1Password via GitHub Actions during deploy).
      - For internal services (Proxmox/NAS), expose via Cloudflare Tunnel with mutual TLS.
    - **Routing**:

      - ​`https://mcp.aienablement.academy/<service>/<tool>`
      - Each service registers a `tools` manifest consumed by Claude/Codex.
    - **Logging**:

      - Workers → Logpush → R2 (or Cloudflare Logs) → Grafana/Elastic for analysis.
      - Error budget alerts into Slack/n8n.
    - **Deployment**:

      - GitHub Actions workflow triggered on `main` changes.
      - ​`wrangler deploy` with environment-specific secrets.

    ## 4. Service Adapters

    |Service|Adapter Strategy|Notes|
    | -----------------------------------------------| --------------------------------------------------------------------------------------| ----------------------------------------------------|
    |Cloudflare DNS/Access|Use official `mcp-server-cloudflare` modules|Supports DNS record CRUD, Access policies|
    |Stripe|Integrate `stripe/agent-toolkit` via Workers (TCP fallback to OCI if needed)|Rate limit per API key; map to finance automations|
    |Oracle Cloud (OCI)|Call Oracle MCP servers via Workers fetch or direct from OCI fallback|Use signed requests and private endpoints|
    |Ghost CMS|Custom Worker invoking Ghost Admin API|Include preview/auth tokens|
    |HubSpot/Salesforce (CRM)|Workers calling CRM REST; store OAuth tokens in Durable Objects|Evaluate official MCP if released|
    |Proxmox/QNAP|Expose through Cloudflare Tunnel to Workers; sign requests, enforce IP allow list|Heavy operations fall back to OCI worker|
    |Qdrant|REST API forwarded via Worker; limit to read/query operations|Write-heavy tasks run on OCI fallback|
    |Google Workspace|Use Google REST APIs with service account JWT; consider Cloudflare CASB for auditing|Workspace MCP is TBD|
    |Creative APIs (Sora, Veo, Midjourney, Runway)|Workers fetch to vendor endpoints; ensure async job polling + webhook handling|May need Cloudflare Queues for job status|

    ## 5. Fallback (OCI MCP Cluster)

    - Deploy Oracle’s `mcp`​ servers on `oci-ampere-02` behind Cloudflare Tunnel.
    - Use when requests exceed Workers limits (CPU >10ms, large payloads).
    - Provide identical manifests so clients can switch to backup by toggling endpoint in config.

    ## 6. Security Controls

    - Cloudflare Access policies enforce user/device authentication before hitting MCP endpoints.
    - All outbound service calls use scoped API tokens; secrets rotated quarterly.
    - Workers implement IP/FQDN allow lists where possible.
    - Add logging for all mutation requests; forward to NocoDB audit table via webhook.

    ## 7. Observability & Testing

    - Each service exposes `/_health` route returning status + upstream latency.
    - Workers log structured JSON (request id, service, tool, duration, success flag).
    - Nightly smoke tests via n8n: call key tools, alert on failures.

    ## 8. Implementation Checklist

    1. Fork `cloudflare/mcp-server-cloudflare`; scaffold monorepo for multi-service routes.
    2. Define secrets/key management process (1Password → GitHub Actions → Workers Secrets).
    3. Implement initial adapters: Cloudflare DNS, Stripe, Docmost/NocoDB (read-only).
    4. Configure Logpush → R2, integrate with monitoring dashboard.
    5. Document fallback switch procedure (Workers outage → OCI endpoint).
    6. Publish manifest documentation in `.docs/kb/infra-inventory.md` and Docmost.

    ### Repository Implementation Notes (2025-10-30)

    - ✅ `mcp/cloudflare-workers` contains the Worker project with adapters for Cloudflare, Stripe, Docmost, and NocoDB plus fallback routing.
    - ✅ `mcp/oci-fallback` mirrors manifests and bundles a Compose stack for the OCI cluster.
    - ✅ Configuration stubs (`wrangler.toml`​, `env.example`, service manifests) are ready for secret injection.
    - ⏳ Observability + CI wiring still pending.


[^24]: # infrastructure-ops-expansion

    ---

    id: infrastructure-ops-expansion
    title: Multi-Environment Infrastructure Operations Expansion
    summary: Roadmap to unify management of on-prem, OCI, DigitalOcean, and SaaS estates with mirrored automation across Codex CLI, Claude Code, and Claude Z.AI.
    status: drafting
    owner: ops
    tags:

    - infrastructure
    - automation
    - roadmap
      last_reviewed_at: 2025-10-28

    ---

    # Multi-Environment Infrastructure Operations Expansion

    - Expand from infra-only ops to a holistic operations + GTM automation layer that spans infrastructure, data, product, marketing, sales, finance, and creative tooling.
    - Establish a single control plane for all infrastructure footprints (OCI, local Proxmox/NAS stack, DigitalOcean Moodle, Ghost CMS site, JS marketing site, Stripe billing, AI/ML services).
    - Deliver mirrored automation packs (agents, skills, plugins, hooks, scripts) for Codex CLI and both Claude installations so every workflow is repeatable regardless of interface.
    - Stand up secure MCP hosting (stdio-compatible) for shared services with Cloudflare/edge hardening and continuous backups.
    - Extend monitoring, backups, and documentation so new assets appear in the canonical knowledge base, Docmost, and NocoDB trackers by default.
    - Anchor execution to measurable outcomes so we can judge success and prioritise work with ROI in mind.
    - **Observability coverage**: 100% of managed services report into Uptime Kuma and/or Netdata with <5 minute lag after change; alerts configured for any host missing data for >10 minutes.
    - **Backup integrity**: Weekly verification runs (restore or checksum) logged for every critical system (Docmost, NocoDB, Moodle, NAS, Proxmox VMs, AI models, Qdrant indices).
    - **Automation adoption**: Top 10 recurring infra/ops tasks (tracked in NocoDB) must have codified skills or scripts before Phase 4 exit; usage telemetry captured via hooks.
    - **Revenue & GTM velocity**: Sales/marketing automations reduce manual cycle time by 50% (baseline from current outreach + campaign workflows) and keep pipeline metrics current daily.
    - **Creative throughput**: AI media generation workflows (Sora/Veo/Midjourney/presentation/email sequences) produce approved assets within 24 hours with brand compliance checks logged.
    - **Cross-interface parity**: New agents/skills usable in Codex CLI and both Claude installs within 24 hours of landing in repo (enforced via sync pipeline reporting).

    ### Operating Guardrails

    - Ship only when access, logging, and rollback steps are documented in both repo and Docmost.
    - Embed compliance checks (e.g., scraping/legal limits, PII handling) into relevant skills and hooks.
    - Maintain least-privilege secrets management; every new automation identifies its secret boundary and rotation cadence.

    ## 2. Environment Inventory & Gaps

    |Domain|Current Notes|Gaps / To Do|
    | ---------------------------------------------------| ----------------------------------------------------------------------------| ---------------------------------------------------------------------------------------------------------|
    |OCI (Ampere A1, future GPU/Ampere)|Docmost, NocoDB, n8n, monitoring, proxy live; future Qdrant target|Add Qdrant stack, Ollama/Whisper integration, reinforcement-learning sandbox, infra tagging|
    |Local server (Proxmox/NAS)|Runs nginx, n8n, Portainer, multiple containers|Document topology, harden access (Tailscale + Cloudflare Access), add to monitoring/backups|
    |Home NAS (QNAP)|Untracked in current runbooks|Add to managed inventory, define export/sync routines, snapshots to cloud|
    |DigitalOcean Moodle|Existing droplets, partial docs|Bring into Claude/Codex skills, add automated backup/test hooks|
    |SaaS / APIs (Stripe, cloud providers, AI vendors)|Scattered configs|Centralize credentials via secret mgmt, author skills for billing/usage audits, recurring usage reports|
    |Data/Research Ops|Ad-hoc workflows|Stand up search, web scraping, market intel agents with compliance guardrails|
    |Marketing & Web Presence|Ghost CMS, JS marketing site, SEO tooling, email marketing|Automate content pipelines, SEO audits, A/B testing, campaign orchestration|
    |Creative Media Stack|AI video/image generators (Sora, Veo, Midjourney, Runway), audio (Whisper)|Define generation standards, storage, review workflows, rights management|
    |Sales & CRM|Stripe billing, outreach sequences, lead tracking|Add CRM integration plan, automate Stripe reconciliations, outreach cadences|
    |Productivity & Knowledge|Google Workspace, Slides, Docs, GDrive, email|Build templating agents, filing automations, knowledge ingestion to Docmost/Siyuan|
    |Finance & Compliance|Billing providers, expense tracking, contracts|Automate reporting, approvals, audit trails, integrate with MCP guardrails|

    ### Primary Personas & Service Blueprint

    |Persona|Core Jobs-to-be-Done|Supporting Systems|Success Signals|DRI|
    | ---------------------| -------------------------------------------------------| --------------------------------------------------------------------| --------------------------------------------------------------------------| ----------------|
    |Infra SRE|Provision/patch OCI + on-prem services, ensure uptime|Proxmox, Portainer, Caddy, Tailscale, Cloudflare, monitoring stack|Mean downtime < 30 min/month, zero surprise drift|Ops (Adam)|
    |Data/AI Engineer|Manage Whisper/Ollama/Qdrant, run RL experiments|Proxmox GPU VM, OCI Ampere/GPU, Qdrant, Netdata, Docmost|Model deployment cycle < 3 days, RL experiments reproducible|ML Ops lead|
    |Automation Engineer|Build cross-system workflows (n8n, Workers, cron)|n8n, Cloudflare Workers/Tunnels, GitHub Actions, CLI scripts|Automation backlog velocity > 3 shipped per week, rollback docs current|Ops|
    |Product Ops|Maintain product trackers, spec kits, data sync|NocoDB, Docmost, dashboards, Slack/Teams|Metrics dashboards current daily, spec cycle < 7 days|Product Ops|
    |Creative Ops|Generate, review, and publish multimedia assets|AI media tools (Sora, Veo, Midjourney), Adobe suite, asset library|Asset turnaround < 24 h, brand compliance 100%, asset metadata complete|Creative Ops|
    |Marketing Ops|Run campaigns, A/B tests, and analytics|Ghost, JS site, Brevo, GA, SEO stack, HubSpot/Salesforce|Campaign launch cycle < 3 days, analytics dashboards current|Marketing lead|
    |Sales/RevOps|Orchestrate outreach, maintain CRM hygiene|NocoDB/CRM, Stripe, analytics, email outreach|Pipeline data accurate daily, follow-up SLAs met|RevOps|
    |Finance/Ops|Reconcile billing, manage contracts, audit trails|Stripe, QuickBooks/Xero, Docmost, NocoDB|Monthly close < 5 days, zero compliance incidents|Finance lead|
    |Knowledge Ops|Maintain documentation, second-brain exports|Docmost, Siyuan, Git repo, automation scripts|Knowledge sync drift < 24 h, docs review cadence met|Knowledge Ops|

    ### Dependency Matrix (simplified)

    |Workstream|Depends on|Provides For|Critical Path|
    | --------------------------| ----------------------------------------------------------| ---------------------------| -------------------------------------------------|
    |Asset Discovery|--|All other streams|Yes|
    |Documentation Sync|Asset Discovery|Knowledge Ops, Compliance|Runs in parallel once inventory baseline exists|
    |Automation Scaffold|Asset Discovery, Reuse evaluation|Ops|Product Ops|
    |MCP & Tooling|Automation Scaffold (agent definitions), Security review|ML Ops lead|Ops|
    |AI/ML & Research Stack|Asset Discovery, MCP & Tooling|ML Ops lead|Data Science|
    |GTM, Sales & Marketing|Asset Discovery, Automation Scaffold|Marketing Lead|RevOps|
    |Creative Media Pipeline|Automation Scaffold, GTM inputs|Creative Ops|Marketing Lead|
    |Productivity & Knowledge|Asset Discovery, Documentation Sync|Knowledge Ops|Ops|
    |Monitoring & Backups|Asset Discovery|Ops|SRE Guild|
    |Documentation Sync|Asset Discovery|Knowledge Ops|Ops|

    ### Reuse Evaluation Strategy

    1. Build catalogue of candidate agents/plugins from:

        - ​`wshobson/agents`
        - ​`0xfurai/claude-code-subagents`
        - ​`davepoon/claude-code-subagents-collection`
        - Community GTM/marketing automation libraries (HubSpot, Salesforce, GA wrappers, etc.)
        - Creative tooling prompts/templates repositories.
    2. Score each asset on:

        - Capability fit to persona/service blueprint
        - Maintenance cost (update cadence, complexity)
        - Licensing/compatibility / commercial terms
        - Integration effort (hooks needed, dependencies)
        - Security/compliance posture (data handling, rate limits)
    3. Prefer adoption over build when score ≥ 80%; otherwise design bespoke asset.
    4. Record decisions in NocoDB `automation_assets` table for traceability.

    ### Risk & Mitigation Register

    |ID|Risk|Impact|Mitigation|Owner|
    | ----| ------------------------------------------------------------------------| --------| ------------------------------------------------------------------------------------------| --------------|
    |R1|Cloudflare Workers limits (execution time, cold starts) degrade MCP UX|High|Load test early; document OCI fallback; cache responses where safe|ML Ops lead|
    |R2|Scraping/research/marketing automations breach compliance/ToS|High|Embed compliance checklist + throttling; legal review before launch; maintain blocklists|BizOps|
    |R3|Secret sprawl across new automations|Medium|Centralise secrets via chosen manager; enforce rotation cadences|Ops|
    |R4|Backup verification skipped under load|High|Hook verification tasks into automation with alerting; track in NocoDB|Ops|
    |R5|On-prem hardware failure (NAS/Proxmox) causes data loss|High|Replicate snapshots to cloud; document DR runbooks; test quarterly|Ops|
    |R6|Brand/creative compliance issues from AI-generated assets|High|Implement human-in-the-loop approval, metadata tagging, brand style checks|Creative Ops|
    |R7|Marketing/sales data quality gaps drive bad decisions|Medium|Automate data validation, add anomaly detection on pipeline metrics|RevOps|
    |R8|Licensing or API usage costs spike with creative tooling|Medium|Track usage, set budget alerts, evaluate per-provider limits|Finance|

    ## 4. Deliverables

    - New agent/skill markdown packs + plugin(s) for infrastructure expansion.
    - MCP deployment guide with cost comparison and security model.
    - Infrastructure runbooks in Docmost + `.docs/kb/`.
    - Monitoring dashboards updated with new hosts/services.
    - Backup scripts for Proxmox, NAS, Moodle, AI stack.
    - Stripe + billing audit workflow integrated into NocoDB tracker.

    ## 5. Sequencing & Milestones

    |Phase|Focus|Target|
    | ---------| -----------------------------------------| ------------|
    |Phase 1|Inventory + Documentation Baseline|2025-11-05|
    |Phase 2|Automation & Plugin Scaffold|2025-11-12|
    |Phase 3|MCP Prototype + AI/ML Stack|2025-11-19|
    |Phase 4|Monitoring/Backups Integration|2025-11-26|
    |Phase 5|Harden & Handoff (CI checks, docs sync)|2025-12-03|

    ## 6. Decisions & Open Questions

    - **MCP Hosting**: target Cloudflare Workers (primary) with OCI fallback if latency/resource limits appear.
    - **Canonical Inventory**: mirror repo `.docs/kb/infra-inventory.md` and Docmost entries via automation.
    - GPU/accelerator requirements for Whisper/Ollama workloads?
    - How to balance duplication between Docmost and future Siyuan adoption?
    - Credential management standard (Vault vs Doppler vs Cloudflare Secrets)?

    ## 7. Next Immediate Actions

    1. Compile infrastructure + business stack asset list from existing notes (Docmost wiki, MIGRATION log, GTM docs) into `.docs/kb/infra-inventory.md` and seed mirrored Docmost page.
    2. Validate the expanded service blueprint with stakeholders; confirm DRIs/backup DRIs and fill gaps (marketing, creative, finance).
    3. Instrument KPI tracking (monitoring coverage, backup verification, automation adoption, GTM cycle time, creative throughput) in NocoDB dashboards.
    4. Run first pass reuse scoring on external repositories and log results in `automation_assets` table.
    5. Draft Cloudflare Workers MCP architecture doc (routing, auth, observability, fallback) for review.
    6. Outline initial agent/skill specs (Proxmox, NAS, Moodle, Qdrant, Whisper, Ollama, RLHF lab, research, sales, marketing, creative, workspace automations) incorporating compliance guardrails and secret boundaries.
    7. Define storage + review workflow for AI-generated assets (versioning, approval, metadata) and capture in creative pipeline runbook.

    ## 8. Execution Checklist (Codex & Claude Parity)

    - Every new agent/skill/plugin must ship with:

      - Repo source under `.docs/` + corresponding plugin bundle.
      - ​`claude-sync` + Codex sync updates ensuring parity within 24 h.
      - Docmost entry (runbook or SOP) linked from Source of Truth plan.
    - MCP endpoints exposed via Cloudflare Workers must register both Claude clients and Codex CLI (through `codex-subagent-mcp`).
    - Add regression tests or scripted smoke checks wherever automations mutate infrastructure or external services.
    - Record material updates in `MIGRATION_TASKS.md` and, when business-facing, in GTM changelog (to be created).


[^25]: # linux-server-operations

    ---

    name: linux-server-operations
    description: Linux server administration specialist for system management, security, performance tuning, and infrastructure automation
    model: opus
    color: orange
    id: linux-server-operations
    summary: Guidance for administering the underlying OCI Linux host, including security, patching, and troubleshooting.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - infrastructure
    - security
      tooling:
    - linux
    - ssh
    - monitoring

    ---

    # Linux Server Operations Guide

    #linux #ops/infrastructure #runbook #class/runbook

    ## Scope

    - Applies to Ubuntu 22.04+ hosts (OCI `docker-host`) and future Linux servers.
    - Covers system updates, hardening, monitoring, and troubleshooting.

    ## Baseline Setup

    ```
    sudo apt update && sudo apt upgrade -y
    sudo unattended-upgrade
    ```
    - Users & SSH: create admin user, grant sudo via `/etc/sudoers.d/<user>`, disable password auth and root login, enable fail2ban.
    - Firewall:

    ```
    sudo ufw allow 22,80,443/tcp
    sudo ufw enable
    ```
    - Time sync: ensure `systemd-timesyncd`​ active; set timezone `timedatectl set-timezone UTC`.

    ## Monitoring & Logs

    - Journald persistent storage (`/etc/systemd/journald.conf`​: `Storage=persistent`).
    - Review logs:

    ```
    sudo journalctl -u docker -n 200
    sudo journalctl --since "1 hour ago" -p err
    ```
    - Resource checks: `htop`​, `iostat`​, `df -h`​, `docker stats`.
    - Integrate with Netdata/Uptime Kuma for continuous monitoring.

    ## Maintenance

    - Security patches: monitor CVEs or subscribe to Ubuntu Pro.
    - Kernel updates: schedule reboots during low traffic (announce via status page).
    - Backups: include `/etc`​, `/var/backups`, and application volumes in offsite sync.
    - Disk management: alert at 70 %, prune old logs and Docker artifacts.

    ## Troubleshooting

    - Service failures: `systemctl status <service>`, restart if necessary.
    - Network: `ip addr`​, `ip route`​, `ss -tulpn`​, `sudo tcpdump -i eth0 port 443`.
    - Filesystem: `sudo smartctl -H /dev/sda`​, plan maintenance for `fsck`.
    - Performance: inspect high CPU, swap usage, adjust sysctl (`vm.swappiness`​, `net.core.somaxconn`).

    ## References

    - Ubuntu Server Docs – https://ubuntu.com/server/docs
    - journald – https://www.freedesktop.org/software/systemd/man/journalctl.html


[^26]: # oci-operations

    ---

    name: oci-operations
    description: Oracle Cloud Infrastructure expert specializing in OCI Ampere A1 instances, VPC networking, DNS management, and cloud resource optimization. Use for OCI console operations, CLI automation, infrastructure troubleshooting, and cost optimization.
    model: opus
    color: red
    id: oci-operations
    summary: Handbook for administering Oracle Cloud Infrastructure resources, IAM policies, and networking.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - infrastructure
    - cloud
      tooling:
    - oci
    - terraform
    - networking

    ---

    # OCI Operations Handbook

    #ops/infrastructure #cloud #runbook #class/runbook

    ## Host & Account Quick Reference

    - **Tenancy**: `hello7142`​ (region `us-sanjose-1`).
    - **Primary VM**: Ampere A1 (4 OCPUs / 24 GB RAM) running Ubuntu 22.04; public IP `163.192.41.116`.
    - **SSH Access**: `ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116`.
    - **Reserved IPs**: `192.18.138.10` (unused, keep available for expansion).

    ## CLI & API Tooling

    - OCI CLI: `/Users/adamkovacs/bin/oci`​, config `~/.oci/config`​, key `~/.oci/oci_api_key.pem`.
    - MCP: `oci-compute`​ under `~/OCI-MCP-Servers`​ (`source ~/OCI-MCP-Servers/.venv/bin/activate`).
    - GitHub CLI shares SSH key above for repo + host access.
    - Common commands:

    ```
    /Users/adamkovacs/bin/oci compute instance list --compartment-id <ocid>
    /Users/adamkovacs/bin/oci network public-ip list --compartment-id <ocid>
    /Users/adamkovacs/bin/oci network security-list update --security-list-id <ocid> --ingress-security-rules file://rules.json
    ```
    ## Networking & DNS

    - Security list (`ocid1.securitylist...`) allows SSH/HTTP/HTTPS; edit via CLI/console.
    - DNS managed in Cloudflare zone `78bc8afbb8fbc182da21dde984fd005f` (token stored securely).
    - Example record creation:

    ```
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data '{"type":"A","name":"sub","content":"163.192.41.116","ttl":1,"proxied":true}'
    ```
    ## Backup & Baseline

    - Baseline log: `/var/log/infra-baseline.txt`​; refresh after `sudo apt update && sudo apt upgrade -y`.
    - Snapshot instance shape/boot volume ocids after major changes; note in Migration Activity Log[^5].

    ## Operational Runbooks

    1. **Provision New VM** – `oci compute instance launch`, attach reserved IP, update Cloudflare + Caddy.
    2. **Firewall Block Resolution** – disable `firewalld` or adjust rules; document outcome.
    3. **Incident Response** – check `/srv/*`​ stacks (`docker compose ps`​), TLS logs `docker logs caddy-proxy`​, verify DNS with `dig`.

    ## MCP / Automation Notes

    - ​`oci-compute` MCP handles instance queries and soft reboot actions.
    - Chrome-control + Playwright agents available for Cloudflare console tasks.
    - Store OCI automation scripts in `~/oci` and mirror steps here.

    ## Access Hygiene

    - Rotate API keys annually; update config + console user.
    - Keep SSH key secure; if rotated, update VM metadata and log change.
    - Never commit secrets; rely on host `.env` files documented in runbooks.

    ## References

    - Project plan: ((20251103054959-jjcvofl "Docmost & NocoDB Migration Programme") ).
    - Tracker: Docmost &amp; NocoDB Project Tracker[^8].
    - Logbook: Migration Activity Log[^5].


[^27]: # tailscale-operations

    ---

    name: tailscale-operations
    description: Tailscale VPN specialist for mesh network management, secure connectivity, and distributed system networking
    model: opus
    color: pink
    id: tailscale-operations
    summary: Operations guide for zero-trust access via Tailscale, including policy management and troubleshooting.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - networking
    - security
      tooling:
    - tailscale
    - dns
    - acl

    ---

    # Tailscale Operations Guide

    #networking #security #runbook #class/runbook

    ## Purpose

    - Provide zero-trust overlay for OCI host (`docker-host`) and future systems.
    - Enable private access to admin services (uptime, monitor, metrics, DB ports).
    - Support Tailscale SSH + device tags (`tag:infra`​). Tailnet `TLfcML35y821CNTRL`​ (account `adambkovacs.github`).

    ## Installation (Linux)

    ```
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up --authkey tskey-<one-time> --hostname docker-host --advertise-tags=tag:infra --ssh
    ```
    - Store auth keys securely; use reusable, expiring keys.
    - Enable: `sudo systemctl enable --now tailscaled`.
    - Verify: `tailscale status --json | jq '.Self.TailscaleIPs'`​; log IP + tag in Migration Activity Log[^5].

    ## Configuration

    - ACLs: Admin Console → allow `autogroup:admin`​/`autogroup:member`​ to `tag:infra` nodes.
    - Tailscale SSH: restrict to admin users via policy (GitHub SSO).
    - Subnet routing (optional): `sudo tailscale up --advertise-routes=10.0.0.0/24`.
    - DERP: default network; self-host `derper` if latency issues emerge.

    ## Container & Service Access

    - Use `tailscale sidecar`​ or `tailscaled --socket` for containers needing tailnet connectivity.
    - Taildrop / `tailscale file cp` for secure transfers.
    - Harbor DDNS split-DNS via `dnsmasq`​ on NPM host (`/etc/dnsmasq.d/harbor.conf`​); restart `dnsmasq` after edits.

    ## Operations

    - Status: `sudo tailscale status`​, `sudo tailscale ip`.
    - Key rotation: revoke devices in Admin Console post-decommission.
    - Audit: review activity logs; consider SIEM export.
    - Integration: see Kubernetes guide (link below) for `TS_AUTHKEY` usage.

    ## Troubleshooting

    - Connectivity: ensure `tailscaled` running; firewall allows UDP/443.
    - Auth failures: regenerate auth key, confirm ACL assignment.
    - DNS: configure MagicDNS or disable via `tailscale up --accept-dns=false`.
    - Harbor DDNS issues: check VM `101 (Docker-Debian)`​ -> `docker logs ddns-updater`​, rotate Porkbun keys in `/root/docker-compose.yml`​ & volume config, `docker compose up -d ddns-updater`.

    ## References

    - Tailscale docs – https://tailscale.com/kb/
    - Kubernetes auth secret example – https://github.com/tailscale/tailscale/blob/main/docs/k8s/README.md


[^28]: # uptime-kuma-operations

    ---

    name: uptime-kuma-operations
    description: When managing and interacting and working with or doing work realted to Uptime Kuma on my infra
    model: opus
    color: orange
    id: uptime-kuma-operations
    summary: Playbook for configuring, monitoring, and maintaining the Uptime Kuma observability stack.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-26
    domains:

    - observability
    - infrastructure
      tooling:
    - uptime-kuma
    - dozzle
    - brevo

    ---

    # Uptime Kuma Operations Guide

    #ops/observability #runbook #class/runbook

    ## Overview

    - Stack path: `/srv/monitoring`​ (`uptime-kuma` service).
    - Public status page: `status.aienablement.academy`.
    - Admin UI: `uptime.aienablement.academy`​ (Cloudflare Access → Kuma login `opsadmin`​ / `Ops!Dash2025`).

    ## Configuration

    ```
    TZ=UTC
    UPTIME_KUMA_ENABLE_EMBEDDED_MARIADB=1
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/custom.pem
    UPTIME_KUMA_WS_ORIGIN_CHECK=strict
    ```
    - Data volume: `./uptime-kuma-data` (nightly tar backup).
    - Mount `/var/run/docker.sock` read-only for Docker monitoring.

    ## Monitor Setup

    1. HTTP monitors: wiki, ops, dash, n8n.
    2. TCP monitor: `smtp-relay.brevo.com:465`.
    3. ICMP: `docker-host` ping.
    4. Notifications: Brevo SMTP notifier + secondary channel (Slack/Telegram/n8n webhook).

    ## Operations

    - Upgrade: `docker compose pull uptime-kuma && docker compose up -d`.
    - Backup: export config via UI; include volume in Docmost &amp; NocoDB Backup SOP[^7].
    - Incident management: configure status page incidents and maintenance windows.

    ## Troubleshooting

    - Service issues: `docker compose logs -f uptime-kuma`.
    - Notification failures: revalidate Brevo credentials.
    - WebSocket errors: adjust `UPTIME_KUMA_WS_ORIGIN_CHECK`.
    - Database corruption: stop container, backup `uptime-kuma-data`​, remove `kuma.db-shm/wal`, restart.

    ## References

    - Env vars – https://github.com/louislam/uptime-kuma-wiki/blob/master/Environment-Variables.md
    - Reverse proxy – https://github.com/louislam/uptime-kuma-wiki/blob/master/Reverse-Proxy.md


[^29]: # formbricks-operations

    ---

    name: formbricks-operations
    description: Guide for operating the self-hosted Formbricks stack (survey suite) on the OCI Ampere host.
    model: opus
    color: purple
    id: formbricks-operations
    summary: Runbook covering deployment layout, AWS S3 integration, SMTP settings, and day-to-day maintenance for Formbricks.
    status: active
    owner: ops
    last_reviewed_at: 2025-10-29
    domains:

    - product
    - infrastructure
      tooling:
    - docker
    - aws
    - cloudflare

    ---

    # Formbricks Operations Runbook

    #product #ops/infrastructure #runbook #class/runbook

    ## Stack Overview

    - Location: `/srv/formbricks`​ on OCI Ampere (`163.192.41.116`).
    - Compose services: `formbricks-app`​, `formbricks-db`​ (pgvector), `formbricks-redis` (Valkey).
    - Network/Proxy: joins `reverse-proxy`​, exposed at `https://forms.aienablement.academy` via Caddy.
    - Persistent volumes: `formbricks_db_data`​, `formbricks_redis_data`; uploads stored in AWS S3.

    ## Configuration

    - ​`/srv/formbricks/.env`​ (600): contains `WEBAPP_URL`​, `NEXTAUTH_SECRET`​, `ENCRYPTION_KEY`​, `CRON_SECRET`, DB/Redis URLs.
    - SMTP (Brevo): `MAIL_FROM=learn@aienablement.academy`​, `MAIL_FROM_NAME="AI Enablement Academy"`​, host `smtp-relay.brevo.com:465` with TLS.
    - AWS S3 uploads:

      - Bucket `aea-formbricks`​ (us-east-2) with IAM user `aea-formbricks-s3` and limited policy.
      - Env vars: `S3_ACCESS_KEY`​, `S3_SECRET_KEY`​, `S3_REGION`​, `S3_BUCKET_NAME`.
      - CORS example:

    ```
    [
      {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST"],
        "AllowedOrigins": ["https://forms.aienablement.academy"],
        "ExposeHeaders": ["ETag"]
      }
    ]
    ```
    - DNS: Cloudflare proxied A record → `163.192.41.116`.

    ## Commands

    ```
    cd /srv/formbricks
    sudo docker compose ps
    sudo docker compose logs -f
    sudo docker compose up -d
    sudo docker compose exec formbricks-app env | grep '^S3_'
    ```
    ## Health Checks

    - Internal: `curl --resolve forms.aienablement.academy:443:163.192.41.116 https://forms.aienablement.academy/setup/intro`.
    - External: `curl -I https://forms.aienablement.academy/healthz`.
    - Upload test: add survey upload question; confirm S3 200.

    ## Backups & Maintenance

    - Include `formbricks_db_data`​ in nightly backup (see Docmost &amp; NocoDB Backup SOP[^7]).
    - Rotate IAM keys annually; add bucket lifecycle (pending).
    - Upgrade: `sudo docker compose pull && sudo docker compose up -d --remove-orphans`.

    ## Troubleshooting

    - Upload 403: check IAM policy, bucket CORS, env var reload.
    - TLS: verify Cloudflare proxy + Caddy logs.
    - SMTP: trigger password reset; inspect Brevo creds.

    ## Change Log

    - 2025-10-29 – Initial deployment, Brevo sender updated, AWS S3 integrated.


[^30]: # cortex-notebook-curation

    ---

    name: cortex-notebook-curation
    description: Maintain Cortex notebook structure, templates, and automated dashboards for the second-brain system.
    status: active
    owner: knowledge-ops
    last_reviewed_at: 2025-11-04
    tags:

    - cortex
    - knowledge
      dependencies:
    - cortex-siyuan-ops
      outputs:
    - notebook-audit
    - template-pack

    ---

    # Cortex Notebook Curation Skill

     Partner documents: Cortex (SiYuan) Operations Agent[^2], Cortex (SiYuan) Operations &amp; Usage Guide[^3], Knowledge Base Overview[^19].

    #skills #cortex #knowledge #class/skill

    1. Audit notebooks for alignment with PARA layout, archiving stale pages and resurfacing critical runbooks.
    2. Standardise templates (task log, decision record, experiment log) and publish them under `Templates` for quick reuse.
    3. Build SiYuan database blocks that power dashboards (project tracker, knowledge expansion, backlog), ensuring required attributes exist.
    4. Configure automation hooks (cron, n8n) that sync `.docs` exports and update Cortex indexes.
    5. Document structural changes and update `.docs/knowledge/cortex-siyuan-system.md` to keep the runbook accurate.
