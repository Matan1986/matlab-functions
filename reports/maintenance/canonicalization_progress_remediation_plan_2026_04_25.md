# Canonicalization Progress Remediation Plan (2026-04-25)

Status: Advisory remediation planning only  
Scope: Minimal, non-destructive remediation options for PR #15 Canonicalization Progress Guard findings  
Policy: Preserve WIP evidence, clarify status signals, avoid scientific/code mutation

## Guardrails Applied

- Do not modify scientific code or pipeline logic.
- Do not delete analyses, outputs, or historical/WIP material.
- Do not rewrite scientific conclusions.
- Do not mark Aging or Relaxation canonical.
- Do not mutate `tables/system_backlog_registry.csv`.
- Do not close or merge PR #15.
- Treat contradictory status as governance mismatch, not scientific invalidity.

## Input Notes

- PR #15 local artifact files were not present in this workspace:
  - `reports/maintenance/agent_outputs/2026_04_25/canonicalization_progress_guard_report.md`
  - `reports/maintenance/agent_outputs/2026_04_25/canonicalization_progress_guard_findings.csv`
- Plan below uses the five findings provided in task context plus current control tables and `tables/mt_canonicalization_blockers.csv`.

## Remediation Plan Table

| finding | affected files | recommended action | implementation class | delete? | risk | human approval needed |
|---|---|---|---|---|---|---|
| 1) Aging workstream `canonical_code_status=YES` while module table says `NOT_CANONICAL` | `tables/project_workstream_status.csv`, `tables/module_canonical_status.csv`, `docs/project_control_board.md` | Keep module canonical status unchanged (`NOT_CANONICAL`). Update Aging workstream row wording to explicit governance signal: `WIP`, `NOT_CANONICAL_SOURCE`, and avoid canonical-ready phrasing. Optionally change workstream `canonical_code_status` from `YES` to explicit non-canonical-aligned marker only if table convention is approved. | SAFE_NOW for wording clarifications; APPROVAL_REQUIRED for status-field semantic change | NO | High (false-closure narrative risk) | YES for changing status-token convention; NO for warning wording |
| 2) Relaxation workstream `canonical_code_status=YES` while module table says `NOT_CANONICAL` | `tables/project_workstream_status.csv`, `tables/module_canonical_status.csv`, `docs/project_control_board.md` | Keep module canonical status unchanged (`NOT_CANONICAL`). Add explicit mismatch warning and downgrade language in Relaxation workstream `do_not_assume`/`next_action` to `WIP` and `NOT_CANONICAL_SOURCE`. Any structural field reinterpretation should be approved first. | SAFE_NOW for warning/wording; APPROVAL_REQUIRED for changing meaning of `canonical_code_status` | NO | High (cross-table contradiction) | YES for schema/semantic reinterpretation; NO for warning wording |
| 3) Relaxation saved-output scripts use canonical wording while module remains `NOT_CANONICAL` | Relaxation docs/reporting text and metadata labels (not MATLAB logic), optionally `docs/project_control_board.md` warning line | Add label/wording downgrade only in documentation/metadata surfaces: tag such outputs as `ADVISORY`, `WIP`, `NOT_CANONICAL_SOURCE` until canonicalization closes. Defer script text/code cleanup touching analysis pipeline files. | SAFE_NOW for docs/metadata labels; DEFERRED for code/script wording cleanup | NO | Medium-High (reader misclassification) | YES for code-side wording cleanup |
| 4) Aging structural-collapse outputs narrated as canonical/paper-ready before full canonicalization | Aging-facing docs/report metadata, `docs/project_control_board.md`, `tables/project_workstream_status.csv` (Aging row wording) | Preserve outputs; add explicit narrative downgrade in status/docs: `ADVISORY`, `WIP`, `NOT_CANONICAL_SOURCE`, and “not canonical closure evidence.” Avoid changing scientific content. | SAFE_NOW for narrative/status labels | NO | Medium | NO (for label-only clarifications) |
| 5) MT ver2 active with blockers but missing canonicalization coverage rows | `tables/project_workstream_status.csv`, `tables/module_canonical_status.csv`, `docs/project_control_board.md`, `docs/system_registry.json`, `tables/mt_canonicalization_blockers.csv` | Add explicit `COVERAGE_GAP` tracking via a new MT canonicalization workstream row and module-status row as `UNKNOWN`/`NOT_CANONICAL` (do not claim canonical). Link blockers table as anchor. If row schema or token policy is disputed, keep as documented deferred action. | SAFE_NOW for adding coverage tracking rows with conservative status; APPROVAL_REQUIRED if token/schema conventions uncertain | NO | Medium (blind spot in canonicalization governance) | YES if new-row convention requires ratification; NO if existing schema supports straightforward addition |

## SAFE_NOW Actions (Recommended)

1. Add explicit governance warnings for Aging/Relaxation status mismatch (`WIP`, `NOT_CANONICAL_SOURCE`) in control/status text.
2. Downgrade canonical/paper-ready narrative wording in documentation/metadata surfaces only (no code or scientific changes).
3. Add MT canonicalization coverage tracking as `COVERAGE_GAP` with conservative status (`UNKNOWN`/`NOT_CANONICAL`) and blockers anchor linkage.

## APPROVAL_REQUIRED Actions

1. Any redefinition of `canonical_code_status` semantics beyond current table convention.
2. Any broad/automated wording updates across many generated outputs.
3. Any status-schema token expansion not already accepted.

## DEFERRED Actions

1. Script-level wording cleanup inside Relaxation/Aging pipeline files (even if text-only in code files).
2. Any canonicalization claim upgrades pending actual module closure evidence.

## Strict Implementation Order

1. **Contradiction containment first**: Aging/Relaxation governance mismatch warnings in status/control layers.
2. **Narrative downgrade second**: apply `ADVISORY`/`WIP`/`NOT_CANONICAL_SOURCE` labels to docs/metadata where canonical/paper-ready wording appears.
3. **Coverage closure third**: add MT canonicalization coverage rows and blocker linkage as `COVERAGE_GAP`.
4. **Deferred code wording pass last**: only after approval and without scientific logic changes.

## Action Register (This Task)

- Actions taken now:
  - Created this remediation plan document only.
- Actions intentionally not taken:
  - No scientific code changes.
  - No module canonical-status upgrades.
  - No backlog mutation.
  - No PR state changes.
  - No additional audit execution.
