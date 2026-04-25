# Maintenance Governor Design

Last updated: 2026-04-25
Status: Design ratification document (no implementation)
Scope: Merge/dedup/lifecycle layer for maintenance agent outputs

## 0) Purpose and Boundaries

The Maintenance Governor is the merge/dedup/lifecycle layer for normalized findings emitted by:

1. Repository Drift Guard
2. Helper Duplication Guard
3. Run Output Audit
4. Switching Canonical Boundary Guard
5. Canonicalization Progress Guard

This document defines behavior and output contracts only.

Out of scope:

- no technical audit execution
- no direct script implementation
- no direct mutation of `tables/system_backlog_registry.csv` by default
- no scientific code or claims/query/snapshot edits

## 1) Normalized Output Storage Decision

### 1.1 Pre-governor and future-governor storage convention

Ratified convention:

- Per-agent normalized output files:
  - `reports/maintenance/agent_outputs/<yyyy_mm_dd>/<agent_name>_findings.csv`
- Optional staging merge input:
  - `reports/maintenance/agent_outputs/<yyyy_mm_dd>/combined_findings_staging.csv`
- Governor generated outputs:
  - `tables/maintenance_findings_latest.csv`
  - `tables/maintenance_findings_events.csv`
  - `tables/maintenance_governor_summary.csv`
  - `reports/maintenance/governor_summary_<yyyy_mm_dd>.md`
  - `reports/maintenance/governor_summary_latest.md`
  - `reports/maintenance/approval_queue_<yyyy_mm_dd>.md`
  - `reports/maintenance/approval_queue_latest.md`

### 1.2 Tracked vs generated policy

- `docs/*` design artifacts are tracked.
- `reports/maintenance/agent_outputs/*` and governor-generated tables/reports are generated operational artifacts and should be treated as local/advisory unless and until tracking policy is explicitly approved.
- `tables/system_backlog_registry.csv` remains durable SSOT; governor outputs are supporting/generated views.

### 1.3 Codex publication policy for cloud/worktree runs

- Agent/governor outputs required by the maintenance loop must not remain chat-only.
- Outputs from Codex cloud/worktree executions must be published to GitHub-visible locations before they are considered reviewable inputs.
- Direct commits to `main` are disallowed unless explicitly approved by future policy.

Approved publication routes:

1. draft PR containing generated maintenance artifacts
2. dedicated maintenance automation branch
3. GitHub Issue/PR comment for summaries and approval queue notes

Coverage interpretation rule for artifact-limited workspaces:

- If a Run Output Audit producer reports no accessible run roots in Codex workspace, interpret as `coverage limitation`, not canonical failure.
- Expected normalized classification for this scenario:
  - `rule_id=RO_SUSPICIOUS_006`
  - `module_state=UNKNOWN`
  - `severity=MEDIUM`
  - `confidence=HIGH`
- Governor/summary layers should surface this as advisory coverage risk and request a run with artifact access route, not closure or failure claim.

## 2) Required Schemas

## 2.1 Per-agent normalized finding rows (required)

Columns (required unless noted optional):

- `provisional_finding_id` (required pre-backlog assignment; empty allowed only if `finding_id` present)
- `finding_id` (optional pre-SSOT mapping; required once mapped)
- `finding_key` (required)
- `theme` (required)
- `rule_id` (required)
- `agent_name` (required; one of 5 agent slugs)
- `title` (required)
- `description` (required)
- `module` (required)
- `module_state` (required: `CANONICAL|NOT_CANONICAL|UNKNOWN`)
- `scope` (required)
- `location` (required; normalized path/token)
- `severity` (required: `HIGH|MEDIUM|LOW`)
- `confidence` (required: `HIGH|MEDIUM|LOW`)
- `status` (required; must be `OPEN` in agent outputs)
- `evidence_ref` (required)
- `owner_agent` (required pre-governor proposal; can be self at source)
- `secondary_agents` (optional; semicolon-separated)
- `human_approval_required` (required: `YES|NO`)
- `next_action` (required)
- `dedup_status` (required: `PRIMARY|REFERENCE_ONLY|UNRESOLVED_COLLISION`)
- `dup_of` (optional; required when `dedup_status=REFERENCE_ONLY`)
- `observed_at_utc` (required ISO-8601 UTC)
- `notes` (optional)

## 2.2 Latest findings view (governor-generated)

`tables/maintenance_findings_latest.csv` required columns:

- `finding_id`
- `finding_key`
- `theme`
- `rule_id`
- `title`
- `description`
- `module`
- `module_state`
- `scope`
- `location`
- `severity`
- `confidence`
- `status` (`OPEN|ACKNOWLEDGED|PLANNED|FIXED_PENDING_VERIFY|RESOLVED|WONTFIX`)
- `owner_agent`
- `secondary_agents`
- `evidence_ref`
- `first_seen_utc`
- `last_seen_utc`
- `seen_count`
- `clean_cycle_count`
- `human_approval_required`
- `next_action`
- `dedup_status`
- `dup_of`
- `last_governor_run_id`
- `last_governor_run_utc`

## 2.3 Event log view (governor-generated append-only)

`tables/maintenance_findings_events.csv` required columns:

- `event_id`
- `governor_run_id`
- `event_utc`
- `finding_id`
- `finding_key`
- `event_type` (`NEW|RESURFACED|SEEN|MISSING_THIS_RUN|CANDIDATE_RESOLVED|STATUS_CHANGE|COLLISION|VALIDATION_ERROR|APPROVAL_RECORDED`)
- `from_status`
- `to_status`
- `agent_name`
- `owner_agent`
- `severity`
- `confidence`
- `evidence_ref`
- `notes`
- `approval_ref` (optional)

## 2.4 Governor summary view (per run)

`tables/maintenance_governor_summary.csv` required columns:

- `governor_run_id`
- `run_utc`
- `agents_expected`
- `agents_received`
- `schema_errors_count`
- `new_count`
- `resurfaced_count`
- `still_open_count`
- `candidate_resolved_count`
- `stale_planned_count`
- `duplicate_reference_count`
- `human_decision_required_count`
- `blocked_count`
- `overall_health` (`GREEN|YELLOW|RED`)

## 3) Deterministic Key, Dedup, and Collision Policy

## 3.1 Deterministic `finding_key`

Base formula:

`sha1(lower(theme) + "|" + lower(normalized_subject_or_title_token) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Normalization:

- lowercase ASCII
- normalized separators (`/`)
- trimmed/collapsed whitespace

## 3.2 Cross-agent dedup

If same `finding_key` appears across agents:

- assign one `owner_agent` using precedence table
- mark others `dedup_status=REFERENCE_ONLY` and `dup_of=<owner finding_id>`
- preserve secondary evidence in `secondary_agents` and events

Ownership precedence:

1. structural placement -> `repository_drift_guard`
2. helper duplication behavior -> `helper_duplication_guard`
3. run artifact completeness -> `run_output_audit`
4. Switching canonical boundary -> `switching_canonical_boundary_guard`
5. cross-module canonicalization progress -> `canonicalization_progress_guard`

## 3.3 Collision handling (unrelated issues sharing key)

When unrelated findings collide:

- set `dedup_status=UNRESOLVED_COLLISION`
- generate deterministic disambiguated key using evidence-locus suffix then re-hash
- log `COLLISION` event
- keep both findings active

## 4) Lifecycle Merge and Candidate Resolution Rules

## 4.1 Core lifecycle constraints

- agents may emit `OPEN` only
- agents cannot emit `RESOLVED`/`WONTFIX`
- governor may compute candidate states but not finalize `WONTFIX`

## 4.2 Clean cycle definition

A finding increments `clean_cycle_count` only when:

1. governor run is valid (all expected required-agent outputs present or explicitly waived)
2. the finding is absent from all relevant owner/secondary agent outputs for that cycle
3. no schema failure blocks interpretation for relevant agents

If any relevant agent output is missing/malformed, `clean_cycle_count` does not increment.

## 4.3 Candidate-resolved policy

- `candidate_resolved` when `clean_cycle_count >= 2` and no conflicting resurfacing event
- transition to `RESOLVED` requires human approval record
- reappearance after `RESOLVED` reopens same `finding_id` with status `OPEN`, increments `seen_count`, resets `clean_cycle_count=0`

## 4.4 Stale planned items

- `PLANNED` item with no evidence/status update beyond threshold (default 14 days) enters `stale_planned`
- no automatic status closure

## 5) Failure Handling Policy

If one agent output missing:

- governor run marked `YELLOW` (or `RED` if critical missing pattern)
- no resolution advancement for affected themes
- emit `VALIDATION_ERROR` + `MISSING_THIS_RUN` events

If malformed schema:

- quarantine row(s), record `VALIDATION_ERROR`
- do not merge malformed rows into latest view

If anchor files missing:

- emit blocked governor state (`blocked_count` increment)
- mark affected findings as `human_decision_required`

If `rule_id` unknown:

- keep row with `severity=MEDIUM` default guard
- tag as `VALIDATION_ERROR` requiring rule-catalog review

If `confidence` missing:

- reject row (confidence is mandatory before dry-run ratification)

If `module_state` unrecognized:

- coerce to `UNKNOWN`
- add `VALIDATION_ERROR` note

If `evidence_ref` path missing:

- keep row with reduced confidence floor at `LOW`
- mark `human_decision_required=YES`

If timestamps invalid:

- reject row from merge
- log `VALIDATION_ERROR`

## 6) Human Approval Protocol

Ratified interim protocol (pre-implementation):

- approvals recorded in event stream (`APPROVAL_RECORDED`) once event table exists
- until then, manual approval records are documented in governor markdown summary with stable approval IDs

Required approval types:

- `RESOLVED_APPROVAL`
- `WONTFIX_APPROVAL` (with rationale)
- `SCHEMA_CHANGE_APPROVAL`
- `RULE_CATALOG_CHANGE_APPROVAL`
- `NEW_AGENT_OR_THEME_APPROVAL`

Approval data fields:

- `approval_id`
- `approval_type`
- `finding_id` (if applicable)
- `approved_by`
- `approved_at_utc`
- `rationale`
- `evidence_ref`

## 7) Rule Catalog Governance

Catalogs covered:

- `RS_*`, `HD_*`, `RO_*`, `SCB_*`, `CPG_*`

Ownership:

- maintenance governance owner (human) approves catalog changes
- agents consume, do not invent ad-hoc IDs during governed runs

Change policy:

- additions/deprecations require human approval and changelog entry in docs
- deprecated IDs remain valid for historical findings; map to successor IDs via alias table when needed

Documentation location:

- authoritative catalog listing remains in `docs/maintenance_agent_contracts.md`
- aligned prompts reference and use the same IDs

## 8) Daily-Light / Weekly-Deep Policy

Ratified mode policy:

- **Daily light**
  - anchored-scope-first
  - recent-run windows first
  - no broad historical recursion by default
- **Weekly deep**
  - expanded historical windows
  - broader cross-module path coverage
  - deeper duplication/boundary scans

Recommended per agent:

- Drift Guard: daily light + weekly deep
- Run Output Audit: daily light (recent runs) + weekly deep (older runs)
- Helper Duplication Guard: weekly deep primary; optional daily light on changed/anchored surfaces
- Switching Boundary Guard: daily light
- Canonicalization Progress Guard: weekdays daily light + weekly deep

Governor interpretation:

- daily runs are sufficient for incremental state updates
- deep-run findings can elevate confidence/severity or resolve uncertainty flags

## 9) Governor Outputs and SSOT Relationship

Generated outputs (supporting, non-SSOT):

- `tables/maintenance_findings_latest.csv`
- `tables/maintenance_findings_events.csv`
- `tables/maintenance_governor_summary.csv`
- `reports/maintenance/governor_summary_<yyyy_mm_dd>.md`
- `reports/maintenance/governor_summary_latest.md`
- `reports/maintenance/approval_queue_<yyyy_mm_dd>.md`
- `reports/maintenance/approval_queue_latest.md`

Agent normalized input artifacts:

- `reports/maintenance/agent_outputs/<yyyy_mm_dd>/<agent>_findings.csv`

SSOT rule:

- `tables/system_backlog_registry.csv` remains durable SSOT for core maintenance items (`MNT-*` namespace)
- governor must not silently mutate SSOT
- optional future backlog proposal export only (human-reviewed)

Latest-readable artifact rule:

- `*_latest.md` artifacts are generated convenience views for human and automated review readers.
- `*_latest.md` artifacts are not SSOT and must not be treated as durable lifecycle authority.
- Dated artifacts remain the immutable chronological record for generated review outputs.

## 9A) ChatGPT Scheduled Review Layer (Advisory)

Context:

- A scheduled ChatGPT review automation runs outside the repository at 09:00 Asia/Jerusalem.
- It reads the latest governor summary and approval queue from the GitHub repository.

Inputs expected by the scheduled review:

- `reports/maintenance/governor_summary_latest.md`
- `reports/maintenance/approval_queue_latest.md`

GitHub visibility requirement:

- Scheduled ChatGPT review can only read artifacts that were published to GitHub-visible files/PRs/Issues.
- If artifacts were produced in an isolated Codex environment but not published, they are out-of-band and non-actionable for scheduled review.

Review summary responsibilities:

- summarize `new findings`
- summarize `candidate resolved items`
- summarize `WONTFIX candidates`
- summarize `blockers`
- summarize `human-decision-required items`
- summarize `recommended next actions`

Policy constraints (initial phase):

- ChatGPT scheduled review is advisory only.
- It must not mutate durable lifecycle state.
- It must not directly mark `RESOLVED` or `WONTFIX`.
- It must not mutate `tables/system_backlog_registry.csv`.

Approval policy linkage:

- low-risk auto-approval is out-of-scope unless explicitly approved by future policy.
- `WONTFIX` always requires explicit user approval.
- `RESOLVED` for canonical/scientific/state-boundary findings always requires explicit user approval.

Integration posture:

- The scheduled review layer is a read/summarize layer on top of governor outputs.
- It does not replace governor merge/dedup/lifecycle logic.

## 10) Minimal Implementation Order

Stage 1: schema fixtures only

- publish sample CSV fixtures for agent rows/latest/events/summary
- validate column contracts and enumerations

Stage 2: ingest one agent in dry-run parser mode

- choose `run_output_audit` as first parser
- validate deterministic key + schema/error handling

Stage 3: ingest all five agents in dry-run mode

- no SSOT mutations
- generate validation and dedup diagnostics only

Stage 4: generate latest/events/summary outputs

- enforce lifecycle counters (`seen_count`, `clean_cycle_count`)
- compute new/resurfaced/still-open/candidate-resolved

Stage 5: optional backlog proposal export

- produce proposal rows for SSOT mapping (`MNT-*`), human review only

Stage 6: optional scheduled integration

- schedule agents + governor sequence
- keep advisory-only mode until governance sign-off

## 11) Ratification Summary

- normalized output storage locations: ratified
- confidence policy: ratified as mandatory before dry-run
- rule catalog governance: ratified
- daily/weekly mode policy: ratified
- human approval protocol: ratified (interim documented + future event-table integration)
- lifecycle merge and candidate resolution rules: ratified

Technical audits remain blocked until implementation and dry-run validation are completed.
