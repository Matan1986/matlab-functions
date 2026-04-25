# Maintenance Agent Contracts

Status: Alignment specification for existing audit automations
Scope: Contract definitions only (no execution)

This document aligns existing repository audit automations to the maintenance system defined in `docs/repository_maintenance_plan.md`.

These contracts define required normalized outputs and safety boundaries so findings can later feed governor merge/dedup.

This is not an active governor implementation.
This does not authorize audit execution by itself.

## Global Contract Rules

- Existing automations are input producers, not the maintenance system itself.
- Agents must emit normalized findings, not only free-form reports.
- Agents must not mutate `tables/system_backlog_registry.csv` directly.
- Agents must not set `RESOLVED` or `WONTFIX`.
- Agents must read operational anchors first before classification:
  - `docs/project_control_board.md`
  - `tables/project_workstream_status.csv`
  - `tables/module_canonical_status.csv`
  - applicable rules docs (`docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/repository_structure.md`)
- Until normalized ingestion + governor integration exist, all outputs (scheduled and manual) are advisory raw audit outputs only and are not maintained backlog state.

## Normalized Output Schema (All Five Agents)

Required fields:

- `producer_agent` (`repository_drift_guard|helper_duplication_guard|run_output_audit|switching_canonical_boundary_guard|canonicalization_progress_guard`)
- `finding_key`
- `theme`
- `module`
- `module_state` (`CANONICAL|NOT_CANONICAL|UNKNOWN`)
- `scope`
- `rule_id`
- `severity`
- `title`
- `description`
- `evidence_ref`
- `proposed_action`
- `status_proposal` (must be `OPEN` only)
- `human_approval_required` (`YES|NO`)
- `observed_at_utc`

Optional fields:

- `subject`
- `location`
- `confidence`
- `workstream_id`
- `notes`

### Deterministic `finding_key` baseline

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

Normalization rules:

- lowercase ASCII
- trim whitespace
- normalize path separators to `/`
- collapse repeated separators and spaces
- stable `rule_id` token required (no free text)

Collision handling:

- if two distinct findings collide, append deterministic evidence locus token (`|row:<id>` or `|file:<stem>`), then hash again.

### Evidence reference format

Use semicolon-separated references:

- file refs: `path:<repo-relative-path>`
- table row refs: `table:<path>#row:<key-or-index>`
- doc rule refs: `doc:<path>#<section-token>`

Example:

`doc:docs/results_system.md#output-rules;path:results/switching/runs/run_2026_.../run_manifest.json`

### Severity baseline

- `HIGH`: direct rule or contract breach with reproducibility/governance impact
- `MEDIUM`: likely policy drift or incomplete structure with bounded impact
- `LOW`: hygiene, consistency, or optimization opportunity

Module-state adjustment rule:

- For `NOT_CANONICAL`/`UNKNOWN` modules, downgrade hard-failure framing to maintenance/WIP risk unless an explicit global hard rule is violated.

State-token normalization note:

- if a producer internally emits `NON_CANONICAL`, normalize to `NOT_CANONICAL` before publishing rows.

## Cross-Agent Ownership and Precedence

Primary ownership:

- Structural/output placement drift -> `repository_drift_guard`
- Helper duplication clusters -> `helper_duplication_guard`
- Run artifact integrity/completeness -> `run_output_audit`
- Switching canonical boundary confusion -> `switching_canonical_boundary_guard`
- Cross-module canonicalization progress consistency -> `canonicalization_progress_guard`

Overlap policy:

- Overlap is allowed for context, but one finding must have a single primary owner.
- Secondary agents may emit linked findings only when they add distinct evidence or boundary interpretation.
- When overlap occurs, include a cross-reference note in `notes` using the other agent theme/rule token.

## 1) Repository Drift Guard Contract

### Purpose

Detect structural drift against repository architecture and run-output placement rules, then emit normalized maintenance findings.

### Required inputs / operational anchors (read first)

- `docs/project_control_board.md`
- `tables/project_workstream_status.csv`
- `tables/module_canonical_status.csv`
- `docs/AGENT_RULES.md`
- `docs/results_system.md`
- `docs/repository_structure.md`

### Scope

- Repository structure and output-location drift only
- Generated outputs placement, run-root usage, helper placement, legacy output migration signals, and tracked-generated-artifact risks

### What it may report

- outputs outside canonical run roots
- module-folder direct output writes
- helper placement drift (`tools/` vs duplicated module helpers)
- legacy flat outputs not under `runs/` where migration risk exists
- tracked generated artifacts that should be ignored

### What it must not infer

- scientific validity or physics correctness
- canonical failure closure for non-canonical modules
- backlog lifecycle transitions beyond proposing `OPEN`

### Module-state awareness rules

- `CANONICAL` module: classify direct canonical-path violations as policy drift findings.
- `NOT_CANONICAL` module: classify as maintenance migration/WIP risk unless explicit hard rule breach.
- `UNKNOWN` module: classify as `UNKNOWN_STATE_RISK`; avoid closure language.

### Deterministic `finding_key` rule

Theme token: `repository_structural_drift`

Subject: normalized violation class (for example `output_outside_run_root`)
Location: normalized path (file or directory)
Rule: stable token (`RS_OUT_001`, `RS_HELPER_002`, etc.)

### Human approval requirements

- required for any later transition to `RESOLVED`/`WONTFIX` (outside this agent)
- agent output itself sets `human_approval_required=NO` unless recommendation includes policy exception request

### Do-not-modify rules

- no file edits
- no schema edits
- no backlog writes

### Schedule/integration note

- Current schedule: daily at 04:00
- Manual execution: allowed when needed
- May run before governor exists: yes
- Pre-governor treatment: advisory raw audit output only
- Proposed future integration: governor nominally at 04:30 after normalized audit outputs exist (not active yet)

## 2) Helper Duplication Guard Contract

### Purpose

Identify duplicate or near-duplicate helper logic and emit normalized maintenance findings for consolidation planning.

### Required inputs / operational anchors (read first)

- `docs/project_control_board.md`
- `tables/project_workstream_status.csv`
- `tables/module_canonical_status.csv`
- `docs/AGENT_RULES.md`
- `docs/repository_structure.md`

### Scope

- helper duplication across `tools/`, `<module>/utils/`, and `<module>/analysis/`
- naming and behavioral duplication patterns

### What it may report

- likely duplicate helper pairs/clusters
- near-duplicate numeric conversion/map/correlation/smoothing/export/run-output helpers
- consolidation opportunities with minimal reuse recommendations

### What it must not infer

- runtime correctness regressions without evidence
- mandatory deletion decisions
- canonical failure for non-canonical modules

### Module-state awareness rules

- `CANONICAL` module: duplicates may be reported as maintainability/compliance drift.
- `NOT_CANONICAL` module: report as migration/WIP duplication risk.
- `UNKNOWN` module: report as `UNKNOWN_STATE_RISK` with lower confidence.

### Deterministic `finding_key` rule

Theme token: `helper_duplication`

Subject: normalized function cluster signature (sorted function names)
Location: normalized sorted path set hash
Rule: stable token (`HD_SIM_001`, `HD_NAME_002`, etc.)

### Human approval requirements

- consolidation/deletion decisions always require human approval in subsequent workflow
- agent output proposals remain advisory

### Do-not-modify rules

- no code edits
- no automatic consolidation
- no backlog writes

### Schedule/integration note

- Current schedule: Sundays at 04:20
- Manual execution: allowed when needed
- May run before governor exists: yes
- Pre-governor treatment: advisory raw audit output only
- Proposed future integration: governor nominally at 04:30 after normalized audit outputs exist (not active yet)

## 3) Run Output Audit Contract

### Purpose

Assess recent run artifact completeness/integrity and emit normalized maintenance findings for run-system reliability tracking.

### Required inputs / operational anchors (read first)

- `docs/project_control_board.md`
- `tables/project_workstream_status.csv`
- `tables/module_canonical_status.csv`
- `docs/AGENT_RULES.md`
- `docs/results_system.md`

### Scope

- run directories under `results/<experiment>/runs/`
- required run-root metadata and expected artifact presence
- suspicious/incomplete run signatures

### What it may report

- missing required run-root metadata (`run_manifest.json`, `config_snapshot.m`, `log.txt`, `run_notes.txt`) for actual run directories
- empty or malformed `observables.csv` only when observables were exported or explicitly expected by run intent
- missing expected artifacts/partially written runs (artifact families are conditional by run intent, not globally mandatory per run)
- duplicate run labels
- suspiciously small/inconsistent runs
- missing run-root visibility in Codex/artifact-limited workspace as audit coverage limitation (not repository failure)

### What it must not infer

- scientific conclusion quality
- script-level blame without evidence
- canonical failure for non-canonical modules
- hard-failure from absence of optional artifacts when the run intent does not require them
- repository/canonical failure solely from absent `results/<experiment>/runs/run_*` in artifact-limited Codex workspace

### Module-state awareness rules

- `CANONICAL` module: missing required run-root metadata can be `HIGH` policy findings.
- `NOT_CANONICAL` module: classify as migration/WIP run-system risk unless hard global contract breach.
- `UNKNOWN` module: classify as `UNKNOWN_STATE_RISK`; avoid closure claims.
- when workspace has no run roots available, emit coverage-risk under `UNKNOWN` state and request artifact-access route for full validation.

### Deterministic `finding_key` rule

Theme token: `run_output_audit`

Subject: normalized run issue type (for example `missing_run_manifest`)
Location: normalized run directory path
Rule: stable token (`RO_MANIFEST_001`, `RO_OBS_SCHEMA_002`, etc.)

Coverage-limit mapping:

- `rule_id=RO_SUSPICIOUS_006` may be used for `NO_RUN_ROOTS_VISIBLE_IN_WORKSPACE` coverage-risk finding in artifact-limited Codex runs.
- default coverage-risk severity/confidence: `MEDIUM` / `HIGH`.

### Compatibility anchors (mandatory interpretation)

- `docs/results_system.md` defines run-root metadata requirements and conditional observables behavior.
- `docs/AGENT_RULES.md` and `docs/repository_structure.md` define output and placement constraints.
- `docs/project_control_board.md`, `tables/project_workstream_status.csv`, and `tables/module_canonical_status.csv` define operational-state and canonicalization context.

### Human approval requirements

- any proposed transition beyond `OPEN` is out-of-scope and human-controlled
- closure decisions require governor + human ratification flow

### Do-not-modify rules

- no run artifact rewrites
- no script changes
- no backlog writes
- no generated-view writes

### Schedule/integration note

- Current schedule: daily at 04:10
- Manual execution: allowed when needed
- May run before governor exists: yes
- Pre-governor treatment: advisory raw audit output only
- Proposed future integration: governor nominally at 04:30 after normalized audit outputs exist (not active yet)

## 4) Switching Canonical Boundary Guard Contract

### Purpose

Detect boundary confusion between canonical Switching analysis and legacy/non-canonical/advisory Switching material, and emit normalized boundary findings.

### Required inputs / operational anchors (read first)

- `docs/project_control_board.md`
- `tables/project_workstream_status.csv`
- `tables/module_canonical_status.csv`
- `tables/system_backlog_registry.csv` (read-only context only)
- `docs/analysis_module_reconstruction_and_canonicalization_full_workflow.md`
- `docs/AGENT_RULES.md`
- `docs/results_system.md`
- `docs/repository_structure.md`
- `docs/system_registry.json`

### Scope

- Switching canonical entrypoint/run-anchor references in docs/reports/tables metadata layers
- canonical metadata/sidecar gate references where applicable
- classification language for new Switching reports/tables (`canonical|non-canonical|WIP|advisory`)
- stale context/snapshot/claims/query references presented as canonical-current truth
- silent reuse risk of old width-scaling/backbone assumptions in canonical-labeled outputs

### What it may report

- ambiguous or conflicting canonical labeling in Switching artifacts
- canonical claims without canonical metadata anchors
- legacy/non-canonical analyses presented as canonical-current
- stale knowledge-layer references used as if current canonical truth
- missing explicit status-classification labels on new Switching analysis outputs

### What it must not infer

- physics validity of Switching conclusions
- closure of claims/query/snapshot alignment from one artifact
- automatic canonical invalidation without anchor evidence

### Module-state awareness rules

- `CANONICAL` module (Switching): boundary confusion is a high-priority governance risk when canonical labeling is ambiguous.
- `NOT_CANONICAL` modules referenced by Switching: classify as dependency/WIP boundary risk, not canonical failure.
- `UNKNOWN` module references: classify as coverage gap / unknown-state risk.

### Deterministic `finding_key` rule

Theme token: `switching_canonical_boundary`

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

### Severity mapping

- `HIGH`: canonical-label confusion that can misstate current canonical truth or evidence lineage
- `MEDIUM`: boundary ambiguity or stale-reference risk with bounded interpretation impact
- `LOW`: classification hygiene gaps

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

### Human approval requirements

- all transitions beyond `OPEN` are human-governed
- any boundary reinterpretation touching claims/query/snapshot meaning requires human review

### Do-not-modify rules

- no edits to scientific code
- no edits to claims/query/snapshot/context sources
- no backlog writes
- no lifecycle closure decisions

### Schedule/integration note

- Recommended schedule: daily at 04:15 (between run output audit and governor target), or at minimum daily post-audit
- Manual execution: allowed when needed
- May run before governor exists: yes
- Pre-governor treatment: advisory raw audit output only
- Proposed future integration: governor nominally at 04:30 after normalized audit outputs exist (not active yet)

## 5) Canonicalization Progress Guard Contract

### Purpose

Track canonicalization progress and boundary confusion across active modules (including Aging, Relaxation, MT, and others), and emit normalized progress-risk findings.

### Required inputs / operational anchors (read first)

- `docs/project_control_board.md`
- `tables/project_workstream_status.csv`
- `tables/module_canonical_status.csv`
- `tables/system_backlog_registry.csv` (read-only context only)
- `docs/analysis_module_reconstruction_and_canonicalization_full_workflow.md`
- `docs/system_registry.json`
- `docs/AGENT_RULES.md`
- `docs/results_system.md`
- `docs/repository_structure.md`

### Scope

- consistency between module canonical status and workstream state
- premature canonical labeling of WIP analyses
- confusion between direct/paper figures and canonical closure
- Aging/Relaxation canonical evidence usage before validation/freeze signals
- stale blockers/next-actions visibility and module coverage gaps

### What it may report

- status inconsistencies across control-board/workstream/module tables
- WIP analyses labeled as canonical prematurely
- missing or stale next-action/blocker signals
- active modules in registry missing in canonicalization coverage tracking
- reports/scripts missing explicit status-classification labels

### What it must not infer

- canonical failure merely from missing coverage row
- scientific invalidity from governance incompleteness
- forced canonical closure deadlines

### Module-state awareness rules

- `CANONICAL` module: regressions or contradictions are governance risk findings.
- `NOT_CANONICAL` module: classify findings as canonicalization-progress risk, not canonical-failure.
- `UNKNOWN` module: classify as coverage gap / unknown-state risk.

### Deterministic `finding_key` rule

Theme token: `canonicalization_progress`

`finding_key = sha1(lower(theme) + "|" + lower(normalized_subject) + "|" + lower(normalized_location) + "|" + lower(rule_id))`

### Severity mapping

- `HIGH`: contradictory status signaling that can mislead operational decisions
- `MEDIUM`: stale or incomplete canonicalization progress signals
- `LOW`: labeling/documentation hygiene issues

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

### Human approval requirements

- all transitions beyond `OPEN` are human-governed
- reclassification of module canonical status is out-of-scope for this audit agent

### Do-not-modify rules

- no table mutation (including status/backlog tables)
- no scientific code edits
- no claims/query/snapshot updates
- no lifecycle closure decisions

### Schedule/integration note

- Recommended schedule: daily at 04:25 (after core audits, before governor target) or at minimum once daily
- Manual execution: allowed when needed
- May run before governor exists: yes
- Pre-governor treatment: advisory raw audit output only
- Proposed future integration: governor nominally at 04:30 after normalized audit outputs exist (not active yet)

## Integration Readiness Notes

- These contracts are ready for implementation planning and agent-output normalization.
- They do not activate governor behavior and do not replace the maintenance plan.
- No technical audits should be interpreted as maintained backlog state until normalized ingestion and governor merge are implemented.
