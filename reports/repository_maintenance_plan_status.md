# Repository Maintenance Plan Status

Date: 2026-04-25
Plan document: `docs/repository_maintenance_plan.md`

## Current status

- maintenance plan drafted: YES
- scope is documentation-only: YES
- second backlog introduced: NO
- technical audits executed: NO
- automation scripts implemented: NO

## Ratification checklist

- lifecycle states defined: YES
- human approval gates defined: YES
- finding identity/dedup policy defined: YES
- SSOT backlog integration defined (`tables/system_backlog_registry.csv` + `MNT-*` namespace): YES
- recurring audit themes and parallelization model defined: YES
- governor loop and summary categories defined: YES

## Open decision points (for Stage 0 ratification)

- confirm final normalized field set (compatibility mapping and sidecar policy now documented)
- confirm repeated clean-verification threshold for `RESOLVED` (default documented as 2 clean cycles + approval)
- confirm `MNT-*` ID issuance policy and owner assignment convention

## Program verdicts

- `MAINTENANCE_PLAN_WRITTEN = YES`
- `READY_FOR_SCHEMA_LIFECYCLE_RATIFICATION = YES`
- `READY_FOR_TECHNICAL_AUDITS = NO`

## Existing automation prompt capture

- existing maintenance automation prompts captured in `docs/maintenance_existing_automation_prompts.md`: YES
- ready for alignment to normalized maintenance agent contracts: YES
- prompts have not been converted to normalized contracts yet: YES
- technical audits executed as part of capture: NO

## Existing automation contract alignment

- aligned contracts for Repository Drift Guard, Helper Duplication Guard, and Run Output Audit documented in `docs/maintenance_agent_contracts.md`: YES
- contracts specify normalized finding outputs and deterministic `finding_key`: YES
- contracts explicitly mark pre-governor scheduled/manual outputs as advisory only: YES
- proposed governor timing (nominal 04:30) documented as future target only, not active: YES

## Aligned automation prompts (modernized)

- executable aligned prompt templates documented in `docs/maintenance_aligned_automation_prompts.md`: YES
- each prompt includes normalized finding schema + deterministic `finding_key` + evidence format: YES
- each prompt includes advisory report + normalized rows output requirement: YES
- each prompt includes mandatory final verdict block and pre-governor advisory-only constraint: YES

## Prompt fit and safety audit (pre dry-run)

- prompt-fit audit completed against maintenance plan, contracts, and operational anchors: YES
- added minimal clarifications for bounded scope, stable `rule_id` catalogs, and minimal-fix safety wording: YES
- added efficiency guardrails (anchored scope first, recent-run prioritization): YES
- run-output wording aligned to authoritative run-system expectations to reduce avoidable false positives: YES

## Canonical-boundary agents and Run Output compatibility

- new contracts added: `Switching Canonical Boundary Guard` and `Canonicalization Progress Guard`: YES
- aligned prompt templates added for both new agents: YES
- Run Output Audit contract/prompt compatibility checked against current output contracts and status anchors: YES
- Run Output Audit clarified for conditional observables/optional artifact families and module-state-aware severity: YES

## Maintenance Governor design

- governor design document created: `docs/maintenance_governor_design.md`: YES
- normalized output storage conventions and generated output set ratified: YES
- confidence policy set to mandatory before dry-run: YES
- lifecycle merge/dedup/candidate-resolution rules documented and ratified: YES
- rule catalog governance and approval protocol documented for implementation: YES

## ChatGPT scheduled review layer

- daily ChatGPT scheduled review policy (09:00 Asia/Jerusalem) documented in governor design: YES
- latest-readable review artifacts specified (`governor_summary_latest.md`, `approval_queue_latest.md`): YES
- dated + latest approval/governor review artifact pattern documented: YES
- advisory-only and non-mutating constraints preserved (no direct RESOLVED/WONTFIX): YES

## Minimal governor schema fixture (dry-run layer)

- fixture inputs created under `reports/maintenance/fixtures/` (valid + invalid rows): YES
- minimal fixture generator implemented: `tools/maintenance/run_maintenance_governor_fixture.ps1`: YES
- generated support outputs written (`tables/maintenance_findings_latest.csv`, `tables/maintenance_findings_events.csv`, `tables/maintenance_governor_summary.csv`): YES
- generated review artifacts written (dated + latest in `reports/maintenance/`): YES
- validation checks confirmed (required fields, mandatory confidence, malformed rows rejected as validation errors): YES
- system backlog mutated as part of fixture run: NO
- real maintenance audits run as part of fixture run: NO

## Codex automation output publishing policy

- Codex cloud/worktree output publication policy documented in maintenance plan/governor design: YES
- maintenance outputs required by the loop must not remain chat-only: YES
- approved GitHub-visible publication routes documented (draft PR, dedicated branch, Issue/PR comment): YES
- direct commits to `main` disallowed by policy unless explicit future approval: YES
- governor latest-readable artifacts explicitly required for published review (`governor_summary_latest.md`, `approval_queue_latest.md`): YES
- Codex deployment pack implemented: NO (pending)
- technical audits unblocked by publishing policy alone: NO

## Codex deployment pack

- deployment pack created: `docs/maintenance_codex_deployment_pack.md`: YES
- five standalone automation prompts included (3 updates + 2 new): YES
- schedule table, publishing policy, expected output artifacts, and safety notes included: YES
- manual deployment checklist documented: YES
- codex automations updated/deployed by this task: NO
- readiness for first advisory dry-run after manual deployment: YES

## First advisory dry-run (Run Output Audit)

- publication loop to GitHub issue succeeded (`FIRST_ADVISORY_DRY_RUN_PUBLISHING = PASS`): YES
- normalized row emitted with mandatory confidence and `status_proposal=OPEN`: YES
- advisory-only constraints preserved and backlog mutation prevented: YES
- codex workspace lacked run roots (`results/<experiment>/runs/run_*`), so real run-output coverage result recorded as limited (`RUN_OUTPUT_AUDIT_REAL_COVERAGE = LIMITED`): YES
- emitted as coverage-risk (`rule_id=RO_SUSPICIOUS_006`, `module_state=UNKNOWN`, `severity=MEDIUM`, `confidence=HIGH`): YES
- issue #13 remains open as advisory coverage signal (not maintained backlog state): YES
