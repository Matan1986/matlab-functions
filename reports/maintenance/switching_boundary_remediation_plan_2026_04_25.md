# Switching Boundary Remediation Plan (2026-04-25)

Status: Advisory remediation planning only  
Scope: Minimal mitigation plan for PR #14 Switching canonical-boundary findings  
Policy: MARK_LEGACY_NOT_DELETE

## Guardrails Applied

- Preserve historical/non-canonical findings and artifacts.
- Do not delete claims, snapshots, context bundles, or old analyses.
- Do not rewrite scientific conclusions or canonical physics.
- Do not perform broad claims/query/snapshot migration.
- Do not mutate `tables/system_backlog_registry.csv`.
- Do not mark any finding `RESOLVED`/`WONTFIX` in this step.

## Input Findings (PR #14)

1. `SCB_STALE_003`  
   Query layer can surface stale or out-of-repo context as canonical-current.

2. `SCB_MODEL_006`  
   Width-based X / w-dependent claims appear canonical-current while current canonical collapse hierarchy states `used_width_scaling = NO`.

3. `SCB_META_002`  
   `tables/switching_canonical_identity.csv` is referenced as authoritative anchor but is missing.

## Remediation Plan Table

| finding | affected files | recommended action | delete? | risk | human approval needed |
|---|---|---|---|---|---|
| `SCB_STALE_003` | `analysis/query/query_system.m`, `docs/project_control_board.md`, `tables/project_workstream_status.csv` | **Phase A (safe now):** docs/status warning only, explicitly state query outputs may include stale/non-canonical evidence and must not be treated as canonical-current without anchor checks. **Phase B (approval-gated):** minimal query warning/gating message that tags stale/non-canonical source provenance in output (no broad rewrite). | NO | Medium (misleading canonical-current interpretation) | YES for query behavior change; NO for docs/status warning |
| `SCB_MODEL_006` | `claims/` (selected Switching claim files), `snapshot_scientific_v3/` (labels only), Switching reporting docs where width-based X is presented | **Phase A (safe now):** apply metadata/status labeling only: mark width-based X / w-dependent statements as `LEGACY`/`ADVISORY`/`NON_CANONICAL` with note: canonical collapse hierarchy currently reports `used_width_scaling = NO`. **Phase B (approval-gated):** propagate standardized label convention across all legacy claim surfaces. | NO | High (canonical-boundary confusion) | YES for broad label rollout; NO for narrow doc-level clarification |
| `SCB_META_002` | `docs/project_control_board.md`, `tables/project_workstream_status.csv`, `tables/switching_canonical_identity.csv` (if restored from evidence) | **Option 1 (preferred if evidence exists):** restore/regenerate missing anchor from existing authoritative source chain, include provenance note. **Option 2 (safe fallback):** downgrade/remove authoritative anchor reference until tracked replacement exists; annotate as missing anchor risk. Do not invent canonical identity content. | NO | Medium (anchor trust/traceability gap) | YES for restoring new anchor content; NO for reference downgrade |

## Safe-Now Actions vs Deferred

### Safe now (no scientific/code rewrite)

1. Add explicit remediation warning record (this document) with `MARK_LEGACY_NOT_DELETE`.
2. Use docs/status clarifications to prevent canonical-current over-interpretation of stale query and width-based legacy statements.
3. Treat missing identity anchor as governance/coverage risk and downgrade reference until evidence-backed restoration is approved.

### Deferred (requires human approval)

1. Any behavior change inside `analysis/query/query_system.m` (even minimal warning/gating output).
2. Any broad label propagation across generated claims/snapshot/query surfaces.
3. Any restoration of `tables/switching_canonical_identity.csv` content (must be evidence-backed and reviewed).

## Minimal Implementation Order (When Approved)

1. **Anchor safety first**: downgrade missing anchor reference in control metadata or restore with evidence (approval).
2. **Boundary labeling second**: add explicit `LEGACY/ADVISORY/NON_CANONICAL` labels for width-based X statements where currently presented as canonical-current.
3. **Query warning third**: add minimal provenance warning/gating in query output to separate canonical vs legacy/stale sources.
4. Re-run Switching boundary advisory audit only after steps above are merged through approved route.

## Action Register for This Task

- Actions taken now:
  - Wrote this narrow remediation plan document only.
- Actions intentionally not taken:
  - No deletions.
  - No scientific code modifications.
  - No claims/query/snapshot migrations.
  - No backlog mutation.
  - No issue/PR state changes.

## Interim Decision Summary

- Historical evidence is preserved; remediation posture is label-and-warning, not delete-and-rewrite.
- Width-based X finding should be addressed via explicit non-canonical/legacy labeling before any deeper integration change.
- Missing anchor finding should be handled by evidence-backed restoration or temporary reference downgrade; fabrication is disallowed.
