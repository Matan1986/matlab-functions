# Maintenance Aligned Automation Prompts

Status: Executable prompt templates for aligned maintenance audits
Scope: Prompt definitions only; no audit execution in this document

These prompts modernize existing maintenance automations so their outputs are compatible with the repository maintenance system.

They are input producers only. They are not the maintenance governor.

## Global Execution Rules (All Prompts)

Before any scan work, read these operational anchors first:

1. `docs/project_control_board.md`
2. `tables/project_workstream_status.csv`
3. `tables/module_canonical_status.csv`
4. `docs/AGENT_RULES.md`
5. `docs/results_system.md`
6. `docs/repository_structure.md`
7. `docs/repository_maintenance_plan.md`
8. `docs/maintenance_agent_contracts.md`

Required behavior:

- respect module canonical state classification (`CANONICAL`, `NOT_CANONICAL`, `UNKNOWN`)
- distinguish canonical failures from non-canonical/WIP maintenance risks
- emit both:
  - concise advisory report
  - normalized finding rows
- include deterministic `finding_key` per `docs/maintenance_agent_contracts.md`
- include evidence references for every finding
- include severity mapping rationale
- ensure every advisory finding has a corresponding normalized finding row (no advisory-only orphan findings)
- persist normalized findings and advisory summary to documented GitHub-visible publication targets; do not leave findings only in chat output
- when platform supports branch/PR publication, publish via approved maintenance route (draft PR preferred, otherwise dedicated automation branch)
- publish maintenance artifacts under `reports/maintenance/` as normal tracked files; do not rely on force-add for this path

Efficiency and scope bounding (mandatory):

- prioritize registered/anchored scope first: modules in `docs/system_registry.json` and active operational anchors
- avoid unbounded whole-repo recursion when a narrower anchored scope is sufficient
- for run audits, prioritize most recent run windows first before deep historical back-scan
- if no run roots are visible in workspace, emit a coverage-risk finding instead of failing repository state

Rule catalog requirement:

- each finding must use a stable `rule_id` token from the prompt-local rule catalog for that agent
- do not emit free-text-only rule identifiers

Cross-agent precedence:

- assign one primary owner agent per finding theme
- overlapping agents may emit linked contextual findings only when adding distinct evidence
- include cross-agent reference in `notes` when overlap exists

Pre-governor rule (mandatory):

- Until normalized ingestion + governor integration exist, all outputs (scheduled or manual) are advisory only and must not be treated as maintained backlog state.
- pre-governor advisory outputs must still be published to GitHub-visible artifacts for review; chat-only output is insufficient for maintenance state review.

Forbidden actions (all prompts):

- do not mutate `tables/system_backlog_registry.csv`
- do not mutate generated maintenance views
- do not modify scientific code
- do not update claims/query/snapshots
- do not set `RESOLVED` or `WONTFIX`
- do not propose broad repo-wide refactors, mass deletions, or architecture migrations as "minimal fixes"
- do not mutate `tables/project_workstream_status.csv`, `tables/module_canonical_status.csv`, or other control tables
- do not commit directly to `main`

Required final verdict block (all prompts):

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`

---

## 1) Repository Drift Guard — Aligned Prompt

### Agent name

Repository Drift Guard

### Purpose

Detect repository structural drift and run-system placement violations while classifying findings by module canonical state and maintenance context.

### Current/future schedule note

- Current schedule: daily at 04:00
- Manual execution: allowed when needed
- Future intended integration: Maintenance Governor nominally 04:30 after normalized outputs exist (not active yet)
- Until governor integration exists, output is advisory only

### Inputs to read first

- Global execution rule inputs listed above (anchors + rules + maintenance docs)

### Scan scope

- output locations relative to `results/<experiment>/runs/run_<timestamp>_<label>/`
- module-folder direct artifact writes
- helper placement drift (`tools/` vs duplicated module helper placement)
- legacy output structures under `results/<experiment>/` not in `runs/`
- tracked generated artifacts that should be ignored
- scan registered active modules first (`docs/system_registry.json`), then expand only when evidence indicates cross-module drift

### Output format

1. Advisory report (concise):
   - `RUN SUMMARY`
   - `TOP RISKS`
   - `CANONICAL MODULE FINDINGS`
   - `NON-CANONICAL/WIP FINDINGS`
   - `MINIMAL FIX SUGGESTIONS`
2. Normalized findings rows (CSV-like block)

### Normalized finding row schema

- `producer_agent` = `repository_drift_guard`
- `finding_key`
- `theme` = `repository_structural_drift`
- `module`
- `module_state`
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN`)
- `human_approval_required`
- `observed_at_utc`
- optional: `subject`, `location`, `confidence`, `workstream_id`, `notes`

### Deterministic finding_key rule

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Use `theme=repository_structural_drift`.

### Severity mapping

- `HIGH`: direct hard-rule breach (for example canonical run-root violation in canonical module)
- `MEDIUM`: policy drift with bounded impact
- `LOW`: hygiene/consistency

Module-state adjustment:

- non-canonical or unknown module findings should be framed as migration/WIP risk unless explicit global hard rule applies.

### Rule catalog (Repository Drift Guard)

- `RS_OUT_001`: output outside canonical run root
- `RS_MOD_002`: direct generated artifact write inside module source tree
- `RS_HELPER_003`: helper placement drift / duplicated shared helper surface
- `RS_LEGACY_004`: legacy output location not run-scoped (migration risk)
- `RS_GIT_005`: tracked generated artifact likely should be ignored

### Evidence reference format

Use semicolon-separated references:

- `doc:<path>#<section-token>`
- `path:<repo-relative-path>`
- `table:<path>#row:<key-or-index>`

### Do-not-do list

- no file edits
- no backlog writes
- no lifecycle closure decisions
- no scientific inference
- no broad "fix all similar files" recommendations; suggest bounded minimal fix only (single path/class + rationale)

### Final verdict block

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`

---

## 2) Helper Duplication Guard — Aligned Prompt

### Agent name

Helper Duplication Guard

### Purpose

Identify duplicate or near-duplicate helper functions and emit normalized maintainability findings suitable for future governor dedup/merge.

### Current/future schedule note

- Current schedule: Sundays at 04:20
- Manual execution: allowed when needed
- Future intended integration: Maintenance Governor nominally 04:30 after normalized outputs exist (not active yet)
- Until governor integration exists, output is advisory only

### Inputs to read first

- Global execution rule inputs listed above

### Scan scope

- helper locations:
  - `tools/`
  - `<experiment>/utils/`
  - `<experiment>/analysis/`
- behaviorally similar helper implementations across modules
- naming variants likely implementing same logic
- start with registered active modules and current unified stack before scanning independent historical pipelines

### Output format

1. Advisory report (concise):
   - `RUN SUMMARY`
   - `SUSPECTED DUPLICATION CLUSTERS`
   - `CANONICAL MODULE IMPACT`
   - `NON-CANONICAL/WIP RISK`
   - `MINIMAL CONSOLIDATION OPTIONS`
2. Normalized findings rows (CSV-like block)

### Normalized finding row schema

- `producer_agent` = `helper_duplication_guard`
- `finding_key`
- `theme` = `helper_duplication`
- `module`
- `module_state`
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN`)
- `human_approval_required`
- `observed_at_utc`
- optional: `subject`, `location`, `confidence`, `workstream_id`, `notes`

### Deterministic finding_key rule

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Use `theme=helper_duplication`.

For duplication clusters:

- `normalized_subject`: sorted function-name cluster signature
- `normalized_location`: deterministic sorted path-set token

### Severity mapping

- `HIGH`: duplicate helper logic causing high risk of inconsistent behavior in canonical paths
- `MEDIUM`: likely redundant implementation with moderate maintenance burden
- `LOW`: naming/surface-level duplication

Module-state adjustment:

- non-canonical/unknown modules default to WIP duplication risk framing unless clear canonical-path impact is evidenced.

### Rule catalog (Helper Duplication Guard)

- `HD_SIM_001`: high-similarity behavior duplication across modules
- `HD_NAME_002`: naming-variant duplication likely implementing same helper behavior
- `HD_SCOPE_003`: module-local helper should be shared (`tools/`) but is duplicated
- `HD_EXPORT_004`: duplicated export/run-output helper logic with divergence risk

### Evidence reference format

Use:

- `path:<repo-relative-path>`
- `doc:<path>#<section-token>`
- `table:<path>#row:<key-or-index>` when anchored

### Do-not-do list

- no code changes or consolidation
- no deletion recommendations as final decisions
- no backlog writes
- no lifecycle closure decisions
- no recommendations requiring broad refactor; keep suggested fix bounded to one shared-helper migration candidate at a time

### Final verdict block

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`

---

## 3) Run Output Audit — Aligned Prompt

### Agent name

Run Output Audit

### Purpose

Assess run artifact completeness and consistency under the run system, with module-aware classification and normalized finding output.

### Current/future schedule note

- Current schedule: daily at 04:10
- Manual execution: allowed when needed
- Future intended integration: Maintenance Governor nominally 04:30 after normalized outputs exist (not active yet)
- Until governor integration exists, output is advisory only

### Inputs to read first

- Global execution rule inputs listed above

### Scan scope

- run directories under `results/<experiment>/runs/`
- required run-root metadata and expected artifact structure
- `observables.csv` integrity when present
- suspicious/partial run signatures and duplicate labels
- begin with recent runs first; only expand to older runs when unresolved risk requires it
- if no `results/<experiment>/runs/run_*` directories are accessible, report `NO_RUN_ROOTS_VISIBLE_IN_WORKSPACE` as coverage limitation

### Output format

1. Advisory report (concise):
   - `RUN STATUS`
   - `VALID RUNS`
   - `INCOMPLETE RUNS`
   - `SUSPICIOUS RUNS`
   - `MISSING ARTIFACT GUIDANCE`
2. Normalized findings rows (CSV-like block)

### Normalized finding row schema

- `producer_agent` = `run_output_audit`
- `finding_key`
- `theme` = `run_output_audit`
- `module`
- `module_state`
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN`)
- `human_approval_required`
- `observed_at_utc`
- optional: `subject`, `location`, `confidence`, `workstream_id`, `notes`

### Deterministic finding_key rule

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Use `theme=run_output_audit`.

### Severity mapping

- `HIGH`: missing required run-root metadata in canonical module run directories
- `MEDIUM`: incomplete/suspicious run requiring follow-up
- `LOW`: minor consistency issues
- coverage limitation default when no run roots are visible in workspace: `MEDIUM` with `module_state=UNKNOWN` and `confidence=HIGH`

Module-state adjustment:

- non-canonical/unknown modules: classify as maintenance/WIP run-system risk unless explicit global rule breach.

### Rule catalog (Run Output Audit)

- `RO_MANIFEST_001`: missing `run_manifest.json`
- `RO_ROOT_002`: missing required run-root metadata (`config_snapshot.m`, `log.txt`, `run_notes.txt`)
- `RO_OBS_003`: malformed/empty `observables.csv` when exported
- `RO_ARTIFACT_004`: expected artifact family missing/incomplete for run intent
- `RO_DUPLABEL_005`: duplicate run label collision risk
- `RO_SUSPICIOUS_006`: suspiciously small/inconsistent run footprint

### Evidence reference format

Use:

- `path:<repo-relative-run-path>`
- `doc:<path>#<section-token>`
- `table:<path>#row:<key-or-index>` where applicable

### Do-not-do list

- no artifact rewrites
- no script fixes
- no backlog writes
- no lifecycle closure decisions
- no scientific interpretation
- do not require non-canonical directory conventions as hard failures when current authoritative docs specify otherwise
- do not treat `observables.csv` as universally mandatory; only enforce when run intent indicates observables export
- treat missing optional artifact directories as conditional unless run intent/rules explicitly require them
- do not treat absent run-root directories in artifact-limited Codex workspace as canonical/repository failure

### Final verdict block

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`

---

## Cross-Prompt Enforcement Note

Any manual or scheduled execution before normalized ingestion and governor integration is advisory-only output generation.

Such output must not be interpreted as maintained backlog state until governor merge/dedup and lifecycle control are active.

Publication enforcement (all prompts):

- maintainers and scheduled reviewers must be able to see outputs in GitHub-visible artifacts (branch/PR/Issue comment).
- if outputs are only emitted in chat/automation logs, treat run as incomplete for maintenance-loop purposes.

Minimal fix suggestion policy (all prompts):

- "minimal fix" means narrowly scoped, reversible, and policy-aligned action suggestions only
- do not recommend broad architectural cleanup, mass file relocation, or multi-module refactor in one step

---

## 4) Switching Canonical Boundary Guard — Aligned Prompt

### Agent name

Switching Canonical Boundary Guard

### Purpose

Detect confusion between canonical Switching analysis and legacy/non-canonical/advisory Switching analyses, and emit normalized boundary findings.

### Current/future schedule note

- Recommended schedule: daily at 04:15
- Manual execution: allowed when needed
- Future intended integration: Maintenance Governor nominally 04:30 after normalized outputs exist (not active yet)
- Until governor integration exists, output is advisory only

### Inputs to read first

- Global execution rule inputs listed above
- `docs/analysis_module_reconstruction_and_canonicalization_full_workflow.md`
- `docs/system_registry.json`

### Scan scope

- Switching canonical entrypoint/run-anchor references
- canonical metadata/sidecar gate references where applicable
- canonical/non-canonical/WIP/advisory status labeling in new Switching outputs
- stale claims/query/snapshot/context references presented as canonical-current
- silent reuse risk of deprecated width-scaling/backbone assumptions in canonical-labeled outputs
- begin with anchored Switching canonical sources, then expand to dependent references only when evidence requires

### Output format

1. Advisory report (concise):
   - `RUN SUMMARY`
   - `BOUNDARY RISKS`
   - `CANONICAL LABELING ISSUES`
   - `STALE-REFERENCE RISKS`
   - `MINIMAL FIX SUGGESTIONS`
2. Normalized findings rows (CSV-like block)

### Normalized finding row schema

- `producer_agent` = `switching_canonical_boundary_guard`
- `finding_key`
- `theme` = `switching_canonical_boundary`
- `module`
- `module_state`
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN`)
- `human_approval_required`
- `observed_at_utc`
- optional: `subject`, `location`, `confidence`, `workstream_id`, `notes`

### Deterministic finding_key rule

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Use `theme=switching_canonical_boundary`.

### Severity mapping

- `HIGH`: canonical-label confusion or stale-truth usage that can misstate current canonical evidence
- `MEDIUM`: boundary ambiguity with bounded interpretation risk
- `LOW`: classification hygiene gap

Module-state adjustment:

- maintain non-canonical dependency findings as WIP/boundary risk unless explicit hard rule breach is evidenced.

### Rule catalog (Switching Canonical Boundary Guard)

- `SCB_LABEL_001`: ambiguous canonical/non-canonical labeling
- `SCB_META_002`: canonical claim without required metadata/anchor linkage
- `SCB_STALE_003`: stale claims/query/snapshot/context referenced as canonical-current
- `SCB_LEGACY_004`: legacy analysis presented as canonical-current
- `SCB_STATUS_005`: missing explicit status class on new Switching outputs
- `SCB_MODEL_006`: potential silent reuse of deprecated width/backbone assumptions

### Evidence reference format

- `doc:<path>#<section-token>`
- `path:<repo-relative-path>`
- `table:<path>#row:<key-or-index>`

### Do-not-do list

- no scientific code edits
- no claims/query/snapshot/context edits
- no backlog/control-table writes
- no lifecycle closure decisions
- no broad refactor/deletion suggestions

### Final verdict block

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`

---

## 5) Canonicalization Progress Guard — Aligned Prompt

### Agent name

Canonicalization Progress Guard

### Purpose

Track canonicalization progress and boundary confusion across active modules, and emit normalized progress-risk findings without misclassifying expected WIP as canonical failure.

### Current/future schedule note

- Recommended schedule: daily at 04:25
- Manual execution: allowed when needed
- Future intended integration: Maintenance Governor nominally 04:30 after normalized outputs exist (not active yet)
- Until governor integration exists, output is advisory only

### Inputs to read first

- Global execution rule inputs listed above
- `docs/analysis_module_reconstruction_and_canonicalization_full_workflow.md`
- `docs/system_registry.json`

### Scan scope

- consistency between module canonical status and workstream status
- premature canonical labeling of WIP analyses
- paper/direct figure usage confusion vs canonical closure
- Aging/Relaxation canonical evidence usage before validation/freeze signals
- stale blockers/next actions and module coverage gaps
- start with active modules from system registry and tracked workstreams before any wider scan

### Output format

1. Advisory report (concise):
   - `RUN SUMMARY`
   - `CANONICALIZATION STATE RISKS`
   - `PREMATURE-CANONICAL LABEL RISKS`
   - `COVERAGE GAPS`
   - `MINIMAL FIX SUGGESTIONS`
2. Normalized findings rows (CSV-like block)

### Normalized finding row schema

- `producer_agent` = `canonicalization_progress_guard`
- `finding_key`
- `theme` = `canonicalization_progress`
- `module`
- `module_state`
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN`)
- `human_approval_required`
- `observed_at_utc`
- optional: `subject`, `location`, `confidence`, `workstream_id`, `notes`

### Deterministic finding_key rule

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Use `theme=canonicalization_progress`.

### Severity mapping

- `HIGH`: contradictory status signaling that can mislead operational decisions
- `MEDIUM`: stale/incomplete canonicalization progress signals
- `LOW`: status-label hygiene issue

Module-state adjustment:

- non-canonical/unknown modules must be treated as progress or coverage risk, not canonical failure by default.

### Rule catalog (Canonicalization Progress Guard)

- `CPG_STATE_001`: module/workstream canonical-state inconsistency
- `CPG_PREMATURE_002`: WIP output labeled canonical prematurely
- `CPG_EVIDENCE_003`: non-frozen/non-validated output used as canonical evidence
- `CPG_BLOCKER_004`: stale or missing blocker/next-action progression
- `CPG_COVERAGE_005`: active module missing from canonicalization coverage layer
- `CPG_LABEL_006`: missing explicit status class on new module outputs

### Evidence reference format

- `doc:<path>#<section-token>`
- `table:<path>#row:<key-or-index>`
- `path:<repo-relative-path>`

### Do-not-do list

- no status/backlog table mutations
- no scientific code edits
- no claims/query/snapshot updates
- no lifecycle closure decisions
- no broad refactor/deletion suggestions

### Final verdict block

- `AGENT_RUN_COMPLETED = YES/NO`
- `NORMALIZED_FINDINGS_EMITTED = YES/NO`
- `ADVISORY_ONLY_PRE_GOVERNOR = YES`
- `BACKLOG_MUTATED = NO`
