# Repository Maintenance Plan

Last updated: 2026-04-25
Status: Draft for schema/lifecycle ratification
Scope: Repository maintenance and automation governance only (no scientific refactor)

## 1) Purpose and Non-Goals

### Purpose

This plan defines a lightweight, durable maintenance layer for repository health findings and follow-up.

The layer is designed to:

- start read-only and evidence-first
- normalize maintenance findings into stable, deduplicated records
- preserve finding lifecycle history over time
- connect recurring audits to a single actionable backlog and governor summary

### Non-goals

This plan does not:

- perform scientific refactoring or reinterpretation
- run technical audits by itself
- apply automatic destructive fixes
- migrate claims, snapshot, or query systems as part of maintenance bootstrap
- introduce a parallel governance system that competes with existing repository controls

## 2) Repository Truth Hierarchy

Maintenance decisions and finding interpretation must follow this order:

1. `docs/repo_execution_rules.md` and `docs/AGENT_RULES.md` (execution and agent safety boundaries)
2. `docs/project_control_board.md` (operational coordination layer and warnings)
3. `tables/project_workstream_status.csv` (operational state gate per workstream)
4. `tables/module_canonical_status.csv` (module canonical status and do-not-assume guardrails)
5. `tables/system_backlog_registry.csv` (durable backlog source of truth)

Context caveats:

- `context`, `snapshot`, `claims`, and `query` artifacts are valuable evidence inputs, but may be partial, lagging, or mixed; maintenance automation must not treat them as an unconditional closure source without anchor confirmation from control board/workstream state.

## 3) Maintenance Finding Lifecycle

All maintenance findings use the following statuses:

- `OPEN` - Newly observed and not yet triaged.
- `ACKNOWLEDGED` - Confirmed as valid by human triage.
- `PLANNED` - Remediation approach accepted and queued.
- `FIXED_PENDING_VERIFY` - Change completed; awaiting repeated verification.
- `RESOLVED` - Verified clean and explicitly approved for closure.
- `WONTFIX` - Accepted risk with documented rationale.

Transition notes:

- `OPEN -> ACKNOWLEDGED -> PLANNED -> FIXED_PENDING_VERIFY -> RESOLVED` is the normal path.
- `OPEN|ACKNOWLEDGED|PLANNED -> WONTFIX` is allowed only via human decision.
- If a resolved issue reappears, it reopens under the same identity (see identity rules below).

Allowed non-terminal fallback transitions (to avoid ambiguous dead-ends):

- `FIXED_PENDING_VERIFY -> PLANNED` (verification failed; remediation plan update needed)
- `FIXED_PENDING_VERIFY -> OPEN` (verification failed and item must be re-triaged)
- `ACKNOWLEDGED -> OPEN` (triage reversal when evidence is invalidated)

## 4) Human Approval Rules

The following require explicit human approval:

- transition to `RESOLVED` (or repeated clean verification plus explicit approval)
- any transition to `WONTFIX` (human-only, with rationale and anchor)
- schema changes to maintenance finding fields or lifecycle definitions
- adding a new recurring audit agent/theme

Automation may propose candidate transitions but must not finalize these decisions without approval.

## 5) Finding Identity and Deduplication

Each finding must have:

- a durable `finding_id` (backlog identity)
- a stable `finding_key` (dedup identity)

`finding_key` must be deterministic from:

- `theme`
- normalized subject
- normalized location
- `rule_id` (or equivalent policy/check identity)

Dedup rules:

- same deterministic key maps to the same logical finding
- new observations update `last_seen` and `seen_count`, not a new item
- reappearance after `RESOLVED` reopens the same `finding_id` (status returns to `OPEN` or `ACKNOWLEDGED` based on policy)

Minimum normalization and collision controls:

- normalize subject/location strings to lowercase ASCII with trimmed whitespace and normalized path separators
- normalize rule identity to a stable token (`rule_id`) from policy/check source
- maintain a `finding_key_version` policy marker in generator logic so normalization changes do not silently fork identity
- if two logically distinct findings collide on key, append deterministic disambiguator from evidence locus (for example anchor row id or file stem token)

## 6) Backlog Integration Model

Durable SSOT:

- `tables/system_backlog_registry.csv` is the single authoritative backlog.

Namespace:

- maintenance findings use `MNT-*` IDs within that registry.

Supporting generated views (non-SSOT):

- `maintenance_findings_latest` (current snapshot view)
- `maintenance_findings_events` (append-only lifecycle/event stream)

These supporting views are generated operational outputs and must not become a competing backlog.

Governance guard:

- no manual edits to generated views
- no lifecycle decisions are accepted from generated views unless mirrored in `tables/system_backlog_registry.csv`
- governor summary is read-only status reporting, not a backlog authority

## 7) Recurring Audit Agents (Required Themes)

The maintenance program includes these recurring audit themes:

1. repository structural drift
2. helper duplication
3. run output audit
4. anchor validation
5. gitignore/tracked-anchor validation
6. context/snapshot drift
7. runnable script contract compliance
8. workstream status freshness

## 8) Existing Automation Alignment

Existing useful automations include:

- Repository Drift Guard
- Helper Duplication Guard
- Run Output Audit

Alignment requirements:

- convert free-form outputs to normalized finding rows
- read operational anchors first (`project_control_board`, workstream/module status, rules)
- classify findings relative to module canonical state (for example, avoid overstating closure in non-canonical modules)
- emit deterministic `finding_key` and evidence references

## 9) Governor Loop (Minimal Durable Loop)

Governor responsibilities:

1. collect recurring agent outputs
2. normalize to canonical finding schema
3. deduplicate by deterministic `finding_key`
4. update lifecycle tracking fields (`first_seen`, `last_seen`, `seen_count`)
5. produce governor summary

Required governor summary buckets:

- `new`
- `resurfaced`
- `still_open`
- `candidate_resolved`
- `blocked`
- `human_decision_required`

## 9A) Codex Automation Output Publishing Policy

Context:

- Maintenance automations may run in Codex cloud/worktree environments that are not the user's local working copy.
- Therefore, maintenance outputs required by the governance loop must be published to GitHub-visible artifacts.

Policy:

- Maintenance findings must not remain only in Codex chat/automation output.
- Any output required by the maintenance loop must be persisted to GitHub-visible artifacts.
- Pre-governor automation outputs remain advisory only, even when published.
- Published outputs must preserve the normalized finding contract (`finding_key`, `rule_id`, `severity`, `confidence`, `evidence_ref`, status proposal rules).
- Direct commits to `main` are disallowed unless explicitly approved by future policy.

Approved publication routes (preferred order):

1. draft PR containing generated maintenance reports/tables
2. dedicated maintenance automation branch
3. GitHub Issue/PR comment for summary and approval-queue publication

Review-reader requirement:

- ChatGPT scheduled review can only consume artifacts that are GitHub-visible (files in branch/PR, or Issue/PR comments).
- Governor-readable latest artifacts are:
  - `reports/maintenance/governor_summary_latest.md`
  - `reports/maintenance/approval_queue_latest.md`

## 10) Parallelization Model

Parallel execution lanes:

- Lane A: structural drift + helper duplication + runnable contract compliance
- Lane B: run output audit + anchor validation + gitignore/tracked-anchor validation
- Lane C: context/snapshot drift + workstream status freshness

Merge policy:

- governor merge/dedup/lifecycle update is serial only

## 11) Staged Implementation Plan

- Stage 0: ratify schema and lifecycle policy (this document)
- Stage 1: wire 2-3 highest-signal agents to normalized findings
- Stage 2: implement governor normalize/dedup/first_seen-last_seen logic
- Stage 3: onboard remaining recurring agents
- Stage 4: run recurring governor summary and optional controlled automation

Gate note:

- `READY_TO_RUN_TECHNICAL_AUDITS = NO` until Stage 0 ratification is complete.

## 12) Do-Not-Do List

- no second independent backlog
- no free-form findings without normalized rows
- no auto-close after one clean run
- no destructive fixes from maintenance automation
- no claims/snapshot/query migration in maintenance bootstrap
- no hidden schema changes without explicit approval

## 13) Minimal Proposed Finding Fields (for ratification)

This section documents proposed fields only; it does not modify existing backlog schema.

Proposed normalized fields:

- `finding_id`
- `finding_key`
- `theme`
- `title`
- `status`
- `severity`
- `scope`
- `rule_id`
- `evidence_ref`
- `first_seen_utc`
- `last_seen_utc`
- `seen_count`
- `owner`
- `next_action`
- `human_approval_required`
- `dup_of` (optional)

These fields should be ratified before implementation and mapped carefully onto `tables/system_backlog_registry.csv` + generated support views.

### 13.1 Backlog compatibility mapping (current schema)

Primary mapping into `tables/system_backlog_registry.csv`:

- `finding_id` -> `backlog_id` (use `MNT-*` namespace)
- `theme` -> `category`
- `title`/`description` -> `description` and `standardized_description`
- `status` -> `current_status`
- `severity` -> `risk_level`
- `next_action` -> `notes` and/or `alignment_notes`
- `evidence_ref` -> `notes` (and `diagnosis_source` when structured)
- `scope` -> `scope_position`
- `rule_id` -> `diagnosis_source` (or `alignment_notes` if composite)

Fields that do not fit cleanly in SSOT without schema expansion:

- `finding_key`
- `first_seen_utc`
- `last_seen_utc`
- `seen_count`
- `human_approval_required`
- `dup_of`
- event-level transition history

Therefore:

- keep SSOT schema unchanged for Stage 0/1
- store unmatched fields in generated support views only (`maintenance_findings_latest`, `maintenance_findings_events`)
- if later promoted into SSOT, require explicit human-approved schema change

### 13.2 Resolution verification threshold (ratification default)

Default ratification target for closure:

- `RESOLVED` requires human approval and either:
  - explicit one-time human-verified closure decision, or
  - at least 2 consecutive clean governor cycles for the same `finding_key` plus approval.
