# Aging Artifact Policy (Phase 3)

## 1) Clean Aging-only scope
- This policy applies only to Aging-owned scopes:
  - `Aging/`
  - `tables/aging/`
  - `reports/aging/`
  - `figures/aging/`
  - `results/aging/`
  - `results_old/aging/`
  - `tables_old/aging/`
  - `docs/aging*` and `docs/AGING_*` (if present)
- Clean rerun status required for Aging-only governance:
  - `AGING_ARTIFACT_AUDIT_CONTAMINATED=NO`
  - `NEEDS_AGING_AUDIT_RERUN=NO`
  - `CROSS_MODULE_SYNTHESIS_PERFORMED=NO`

## 2) Excluded cross-module policy
- The following are excluded from Aging-only claims:
  - `Switching/`
  - `Relaxation ver3/`
  - `results/switching/`, `results/relaxation/`
  - `tables/switching/`, `tables/relaxation/`
  - `reports/switching/`, `reports/relaxation/`
  - `figures/switching/`, `figures/relaxation/`
  - cross-module bridge/comparison paths
  - explicitly blocked bridge scripts named by policy
- Excluded candidates are tracked in `tables/aging/aging_artifact_excluded_cross_module_candidates.csv`.
- Excluded paths may be documented only as excluded/blocked, never as Aging-owned proof.

## 3) Artifact class definitions
- `canonical`: Aging outputs accepted as canonical candidates, with explicit lineage and scope-safe evidence.
- `replay`: regenerated or comparison outputs used to validate lineage/parity claims; non-canonical by default.
- `diagnostic`: troubleshooting/probe outputs; non-canonical by default.
- `legacy`: historical artifacts in write-closed namespaces, retained for replay/reference only.

## 4) results_old/aging handling
- `results_old/aging/` is write-closed legacy.
- No new writes, promotions, or cleanup actions are allowed by default.
- Use only for historical lineage replay or audit context with explicit labeling.

## 5) results/aging/debug_runs policy
- `results/aging/debug_runs/` is for debug/probe evidence and intermediate diagnostics.
- Debug outputs are non-canonical by default.
- Promotion from `debug_runs` requires:
  - explicit lineage link to a reproducible run or script
  - explicit classification (`diagnostic` or promoted durable)
  - index/report updates in Aging durable layers

## 6) Invalid/stale material policy
- Invalid, stale, archive, and ambiguous materials must be retained with status labels; no silent cleanup.
- No movement/deletion based only on filename intuition, token matching, or partial scans.
- No cleanup authorization is granted by this policy.

## 7) Promotion rules to tables/reports/figures
- Promotion target layers:
  - tables -> `tables/aging/`
  - reports -> `reports/aging/`
  - figures -> `figures/aging/`
- Promotion requires:
  - source run or script lineage (`results/aging/runs/...` or documented Aging producer path)
  - canonicality status (`canonical_candidate`, `replay`, `diagnostic`, `legacy_reference`)
  - scope tag confirming Aging-only admissibility
  - no cross-module contamination evidence
- Promotion is blocked if lineage is missing or cross-module scope is ambiguous.

## 8) No cleanup without lineage checks
- No movement, rename, deletion, or consolidation is authorized without:
  - lineage verification
  - consumer/reference checks
  - scope safety verification
- This policy is documentation/index governance only.
