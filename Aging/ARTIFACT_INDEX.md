# Aging Artifact Index (Phase 3)

## Scope and authority
- This index is Aging-only and is based on the clean rerun audit state:
  - `AGING_ARTIFACT_AUDIT_CONTAMINATED=NO`
  - `NEEDS_AGING_AUDIT_RERUN=NO`
  - `CROSS_MODULE_SYNTHESIS_PERFORMED=NO`
- Authoritative inputs for this index:
  - `reports/aging/aging_artifact_organization_audit.md`
  - `tables/aging/aging_artifact_family_map.csv`
  - `tables/aging/aging_artifact_excluded_cross_module_candidates.csv`

## Aging-owned roots
- Module source root: `Aging/`
- Run roots (current): `results/aging/runs/`, `results/aging/debug_runs/`
- Durable roots: `tables/aging/`, `reports/aging/`, `figures/aging/`
- Legacy roots (write-closed): `results_old/aging/`, `tables_old/aging/`
- Aging docs roots: `docs/aging*`, `docs/AGING_*` (when present)

## Artifact families (clean rerun family map)
- `general_aging`
- `clock_ratio`
- `FM`
- `canonicalization`
- `tau`
- `diagnostics`
- `dip`
- `trackA`
- `F6_lineage`
- `replay`

## Canonical candidates
- Clean rerun summary currently tracks canonical candidates via `canonicality_status=canonical_candidate`.
- Baseline count from clean rerun audit: `60`.
- Canonical candidate separation is governed through Aging-only indexes in `tables/aging/` and Aging-only reports in `reports/aging/`.

## Replay / archived families
- Replay family evidence is tracked in Aging-only outputs (family `replay` in family map and replay reports in `reports/aging/aging_*replay*.md`).
- Archived/current lineage parity families are tracked under:
  - `F6L` (archived lineage parity replay)
  - `F6M` (archived vs current source selection bridge)
  - `F6N` (direct archived source compatibility check)
- Replay run containers are expected under `results/aging/runs/run_*_aging_*replay*/`.

## Diagnostics
- Diagnostics are non-canonical unless explicitly promoted with lineage.
- Diagnostic family evidence is tracked via:
  - `diagnostic_status=diagnostic`
  - `Aging/diagnostics/` producers
  - diagnostic tables/reports in `tables/aging/` and `reports/aging/`

## Invalid / stale / archive material handling
- Invalid, stale, and ambiguous cross-module candidates are not Aging-only evidence.
- They are tracked as excluded or blocked through:
  - `tables/aging/aging_artifact_excluded_cross_module_candidates.csv`
  - `tables/aging/aging_artifact_cleanup_risks.csv`
- Legacy namespaces (`results_old/aging/`, `tables_old/aging/`) are historical reference only and write-closed.

## F6 and gate navigation

### F6 (AFM/FM tau comparison gate)
- Tables: `tables/aging/aging_F6_AFM_FM_tau_*.csv`
- Report: `reports/aging/aging_F6_AFM_FM_tau_comparison.md`
- Runs: `results/aging/runs/run_*_aging_F6_AFM_FM_tau_comparison/`

### F6I (controlled tau definition gate)
- Tables: `tables/aging/aging_F6I_*.csv`
- Report: `reports/aging/aging_F6I_controlled_tau_definition_test.md`
- Runs: `results/aging/runs/run_*_aging_F6I_controlled_tau_definition/`

### F6J (legacy observable replay on current pipeline gate)
- Tables: `tables/aging/aging_F6J_*.csv`
- Report: `reports/aging/aging_F6J_replay_legacy_observables_on_current_pipeline.md`
- Runs: `results/aging/runs/run_*_aging_F6J*/`

### F6L (archived lineage parity replay gate)
- Tables: `tables/aging/aging_F6L_*.csv`
- Report: `reports/aging/aging_F6L_archived_lineage_parity_replay_repair.md`
- Runs: `results/aging/runs/run_*_aging_F6L*/`

### F6L2 (30K tau NaN invalidation gate)
- Tables: `tables/aging/aging_F6L2_*.csv`
- Report: `reports/aging/aging_F6L2_30K_tau_nan_gate_audit.md`
- Runs: `results/aging/runs/run_*_aging_F6L2*/`

### F6M (archived/current source selection bridge gate)
- Tables: `tables/aging/aging_F6M_*.csv`
- Report: `reports/aging/aging_F6M_archived_current_source_selection_bridge.md`
- Runs: `results/aging/runs/run_*_aging_F6M*/`

## Excluded cross-module candidate summary
- Cross-module and ambiguous bridge/comparison paths are excluded from Aging-only claims.
- Clean rerun exclusion baseline: `773` excluded candidates.
- Exclusion registry: `tables/aging/aging_artifact_excluded_cross_module_candidates.csv`.
- Explicit bridge exclusions include named bridge files such as:
  - `analysis/aging_switching_clock_bridge.m`
  - `analysis/finalize_relaxation_aging_run.m`
  - `Switching/analysis/run_aging_kappa_comparison.m`
  - `Relaxation ver3/aging_geometry_visualization.m`

## Where future Aging outputs should go
- New run lineage outputs: `results/aging/runs/run_<timestamp>_<label>/`
- Debug-only intermediate outputs: `results/aging/debug_runs/<timestamp_or_run_id>/`
- Promoted durable tables: `tables/aging/`
- Promoted durable reports: `reports/aging/`
- Promoted durable figures: `figures/aging/`
- No new writes to `results_old/aging/` or `tables_old/aging/`.
