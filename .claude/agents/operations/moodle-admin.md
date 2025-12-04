---
name: moodle-admin
description: Moodle LMS specialist for platform administration, course management, user administration, and educational technology optimization
model: opus
color: purple
id: moodle-admin
summary: Reference for managing the Moodle learning platform, including upgrades, plugins, and backups.
status: active
owner: ops
last_reviewed_at: 2025-10-30
domains:

- education
- infrastructure
  tooling:
- moodle
- php
- postgres

---

# Moodle 5.x Administration Guide

## Overview

- Target version: Moodle 5.0/5.1 (PHP 8.1+, MariaDB/MySQL/Postgres).
- Deployment recommendation: Docker Compose or native LAMP stack with Redis + optional Elasticsearch.
- Goal: deliver stable LMS with automated backups and upgrade cadence.

## Installation & Upgrades

- Requirements: PHP extensions (`curl`​, `intl`​, `mbstring`​, `pgsql`​/`mysqli`​, `soap`​, `xmlrpc`​, `zip`), database with UTF8MB4, cron enabled.
- File layout:

  - Moodle code: `/var/www/moodle`
  - Data directory: `/var/moodledata` (writable, not web-accessible)
- Upgrade process:

  1. Backup DB + moodledata.
  2. Put site into maintenance mode.
  3. Replace codebase with new release (`git checkout MOODLE_401_STABLE` equivalent for 5.x).
  4. Run CLI upgrade: `sudo -u www-data /usr/bin/php admin/cli/upgrade.php`.
  5. Clear caches: `php admin/cli/purge_caches.php`.

## Configuration

- ​`config.php` settings:

  ```php
  $CFG->wwwroot = 'https://lms.example.com';
  $CFG->dataroot = '/var/moodledata';
  $CFG->directorypermissions = 02770;
  ```
- Cron: `*/1 * * * * /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null`.
- Redis session cache (`$CFG->session_handler_class = '\core\session\redis';`).
- OPcache, CDN, and reverse proxy headers configured for performance.

## User & Course Management

- Authentication: set up OAuth2/SAML providers; enforce password policies.
- Authorization: use Cohorts and Roles; audit permissions after plugin installs.
- Course backups: automate via scheduled tasks; store exports in object storage.

## Plugins & Customization

- Install via plugin directory or `php admin/cli/cfg.php --component=...`.
- Maintain plugin inventory; verify compatibility before upgrades.
- Custom admin pages can be registered with `$ADMIN->add()` per core documentation.

## Troubleshooting: RemUI / Edwiser Stack

### Common Symptoms

- Front page or password-reset flow dies with `Error: Sorry, the requested file could not be found`​ and `core_message/message_drawer_view_conversation_footer_unable_to_message` in the stack trace.
- Edwiser Page Builder screens (Manage Pages, layout wizard, block picker) throw JSON parse errors such as `No number after minus sign` or hang during the “First-time setup… 2%” dialog.
- ​`sudo -u www-data php admin/cli/upgrade.php`​ halts with **Mixed Moodle versions detected, upgrade cannot continue**.

### Fix Workflow

1. **Maintenance mode** – `php admin/cli/maintenance.php --enable`.
2. **Redeploy RemUI bundle cleanly**

    - Rename or move existing plugin/theme folders (`theme/remui`​, `local/edwiserpagebuilder`​, `local/edwisersiteimporter`​, `local/sitesync`​, `blocks/edwiseradvancedblock`​, `blocks/edwiserratingreview`​, `filter/edwiserpbf`​, `course/format/remuiformat`).
    - Unzip the official Edwiser release (e.g. v5.1) into the same paths and reset ownership to `www-data`.
3. **Remove stale core files** – delete `public/message/templates/message_drawer_view_conversation_footer_unable_to_message.mustache`​ (removed upstream in Moodle 5.1) or any other paths flagged by `lib/upgradelib.php::upgrade_stale_php_files_present()`.
4. **Trim redundant config includes** – ensure Edwiser classes no longer run `require_once($CFG->dirroot.'/config.php');`​ when Moodle already loaded it (e.g. `classes/custom_page_handler.php`​, `classes/block_import_export.php`).
5. **Run upgrade + purge caches**

    - ​`sudo -u www-data php admin/cli/upgrade.php --non-interactive`
    - ​`sudo -u www-data php admin/cli/purge_caches.php`
    - Disable maintenance mode.
6. **Smoke tests** – visit `/local/edwiserpagebuilder/managepages.php`, launch the layout chooser, and add a block; use developer tools to confirm JSON responses.

### Prevention Checklist

- Always clear out the previous RemUI/Edwiser directories before extracting a new ZIP to avoid stale core templates triggering the “mixed versions” lockdown.
- After any upgrade, run the CLI upgrade script once more; if it reports *Mixed Moodle versions*, inspect `/public/message/templates/`​ and other paths from `lib/upgradelib.php` and delete leftovers.
- Keep Edwiser bundles in `/root/<date>_edwiser_backup/` (or similar) so rollback copies exist but are outside the Moodle docroot.
- Document every plugin refresh (date, version, reason) in `MIGRATION_TASKS.md`​ and capture any manual tweaks (e.g. removed `require_once` lines) to speed future diffing.

## Monitoring & Logs

- Enable Site → Reports: Event monitoring, Log storage (logstore_standard + logstore_lite).
- Export logs to external SIEM if required.
- Use health checks: Admin → Reports → Performance overview.

## References

- Moodle admin docs – https://docs.moodle.org/401/en/Administration
- Plugin admin integration – example `$ADMIN->add`​ usage in Moodle repo (`local/readme.txt`).
