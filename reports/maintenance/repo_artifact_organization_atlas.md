# Repository Artifact Organization Atlas

## Executive summary

- This is an audit-only snapshot of repository artifact topology, writer patterns, and cleanup risk. No scientific artifacts were moved, renamed, deleted, or rewritten.
- Canonical policy evidence points to `results/<experiment>/runs/run_<timestamp>_<label>/` as the intended output root, but the repository also contains repo-root artifact stores, legacy parallel roots, module-local artifact areas, status fixtures that shadow canonical layouts, and scratch/runtime spillover.
- The highest cleanup risk is not raw clutter alone; it is mixed lineage. Canonical run manifests, execution status files, old roots, fixture mirrors, and policy/claim documents are all present and would require traceability checks before any relocation.

## Artifact topology map

### Top-level areas observed in the atlas

- results_old/: 8769 atlas rows
- results/: 5009 atlas rows
- tables/: 2259 atlas rows
- reports/: 981 atlas rows
- status/: 720 atlas rows
- tables_old/: 157 atlas rows
- archive/: 47 atlas rows
- docs/: 40 atlas rows
- figures/: 30 atlas rows
- GUIs/: 15 atlas rows
- Aging/: 12 atlas rows
- analysis/: 10 atlas rows
- tmp/: 10 atlas rows
- claims/: 9 atlas rows
- surveys/: 7 atlas rows
- junk/: 6 atlas rows
- analysis_new/: 5 atlas rows
- canonical/: 3 atlas rows
- runs/: 2 atlas rows
- Switching ver12/: 2 atlas rows

### Canonical run-tree coverage observed on disk

- results/aging/runs/: 280 run directories detected
- results/analysis/runs/: 82 run directories detected
- results/cross_experiment/runs/: 9 run directories detected
- results/mt/runs/: 15 run directories detected
- results/relaxation/runs/: 34 run directories detected
- results/relaxation_canonical/runs/: 2 run directories detected
- results/relaxation_post_field_off_canonical/runs/: 6 run directories detected
- results/relaxation_post_field_off_RF3R_canonical/runs/: 3 run directories detected
- results/switching/runs/: 202 run directories detected
- results/xx_relaxation/runs/: 7 run directories detected

### Legacy run-tree coverage observed on disk

- results_old/aging/runs/: 88 run directories detected
- results_old/cross_analysis/runs/: 1 run directories detected
- results_old/cross_experiment/runs/: 218 run directories detected
- results_old/legacy_root/runs/: 1 run directories detected
- results_old/phaseC/runs/: 1 run directories detected
- results_old/relaxation/runs/: 55 run directories detected
- results_old/relaxation_canonical/runs/: 1 run directories detected
- results_old/repository_audit/runs/: 5 run directories detected
- results_old/repository_cleanup/runs/: 0 run directories detected
- results_old/review/runs/: 3 run directories detected
- results_old/switching/runs/: 321 run directories detected
- results_old/system/runs/: 3 run directories detected
- results_old/tests/runs/: 0 run directories detected

### Policy/reference documents used for alignment checks

- README.md: run outputs should remain under results/<experiment>/runs/run_<timestamp>_<label>/
- CONTRIBUTING.md: analysis code must not write files outside results/
- docs/AGENT_RULES.md: all outputs must be written to run folders; do not write inside module directories.
- docs/output_artifacts.md: canonical run subfolders are figures/, tables/, reports/, review/.
- docs/results_system.md: historical flat output roots may remain, but new outputs must not use them.
- docs/write_system_enforcement_plan.md: known repo-root reports, debug sinks, and helper bypasses already documented.

## Major disorder patterns

- Repo-root artifact stores remain active as tracked content: `tables/`, `reports/`, `figures/`, plus root-level maintenance CSV/MD/log files. This mixes maintenance, governance, and potentially science-facing artifacts outside the canonical run tree.
- Legacy parallel roots exist alongside current ones: `results_old/`, `tables_old/`, `archive/invalid`, `archive/stale`, `_legacy/`, and multiple `legacy` subtrees. These look historically important rather than disposable.
- Status and fixture trees shadow live artifact layout. Under `status/`, fixtures embed nested `results/.../runs/.../tables`, `reports`, and `figures` paths that can be mistaken for real runs during cleanup automation.
- Module-local artifact surfaces remain present under requested modules and adjacent tooling, including `Switching ver12/tables`, `zfAMR ver11/tables`, `tools/figure_repair/_validation_tmp`, `docs/reports/legacy`, and diagnostic-heavy module trees.
- Scratch/runtime spillover exists at repo root and maintenance roots: `probe_outputs/`, `logs/`, `tmp/`, `temp/`, `junk/`, `.codex_tmp/`, and root log/status files. These are neither clearly canonical nor clearly disposable by policy.

## Highest-risk artifact families

- **Canonical run trees and run metadata**: `results/*/runs/run_*` | risk `BLOCKER` | Lineage-bearing outputs mixed with large volumes of generated artifacts.
- **Legacy parallel roots**: `results_old/, tables_old/, archive/` | risk `HIGH` | Duplicate and historical storage roots coexist with active canonical trees.
- **Repo-root tracked artifact stores**: `tables/, reports/, figures/, root *.csv/*.md/*.log` | risk `HIGH` | Policy, maintenance, and potentially scientific artifacts are colocated outside canonical run roots.
- **Status fixture trees shadow canonical layout**: `status/` | risk `BLOCKER` | Fixture directories embed nested results/.../runs/.../tables and report trees that resemble live artifacts.
- **Module-local artifact roots**: `Switching ver12/tables, zfAMR ver11/tables, tools/figure_repair/_validation_tmp, docs/reports/legacy` | risk `HIGH` | Artifact-like directories exist under source modules and tooling areas rather than under results/*/runs.
- **Scratch and runtime spillover**: `probe_outputs/, logs/, tmp/, temp/, junk/, .codex_tmp/` | risk `HIGH` | Runtime scratch, probes, and preserved diagnostics share repository space with durable artifacts.
- **Policy and canonical source-of-truth documents**: `docs/AGENT_RULES.md, docs/results_system.md, docs/output_artifacts.md, docs/write_system_enforcement_plan.md, canonical/, claims/` | risk `BLOCKER` | Multiple documentation layers and canonical claim directories influence artifact interpretation.
- **Writer patterns bypassing helpers or using parallel roots**: `scripts, analysis, Aging, Relaxation ver3, Switching, tools` | risk `HIGH` | Repository scripts still use writetable/saveas/exportgraphics/fopen/mkdir/copyfile/movefile directly in mixed locations.

## Evidence-backed examples

- `README.md`, `CONTRIBUTING.md`, and `docs/AGENT_RULES.md` all assert that analysis outputs belong under `results/<experiment>/runs/run_<timestamp>_<label>/`, while `docs/write_system_enforcement_plan.md` separately records existing exceptions such as repo-root `reports/` writers and debug sinks.
- Canonical run evidence is widespread on disk: many `results/*/runs/run_*` directories contain `run_manifest.json` and `execution_status.csv`, matching `docs/results_system.md` and making those locations lineage-bearing rather than safe cleanup targets.
- `status/p02_fast_batch_*` and `status/s5_p01_case_roots/*` contain fixture layouts with nested `results/.../runs/.../tables` and `reports` folders, meaning canonical-looking paths are not always live scientific outputs.
- Repo-root maintenance and governance artifacts include files such as `source_of_truth_audit.csv`, `script_asset_inventory.csv`, `canonical_state_freeze.csv`, `cleanup_execution_log.csv`, and `execution_status.csv`, showing that tracked artifact state is not confined to `results/`.
- Module-local and tooling-local artifact roots are physically present, for example `Switching ver12/tables`, `zfAMR ver11/tables`, `tools/figure_repair/_validation_tmp/runtime`, and `docs/reports/legacy`, which means cleanup planning cannot assume repo-root-only disorder.

## Writer-pattern scan summary

- Risk `MEDIUM`: 9224 writer-pattern rows
- Risk `HIGH`: 804 writer-pattern rows
- Risk `LOW`: 211 writer-pattern rows

- Function `fprintf`: 5753 writer-pattern rows
- Function `mkdir`: 1525 writer-pattern rows
- Function `writetable`: 1453 writer-pattern rows
- Function `fopen`: 946 writer-pattern rows
- Function `copyfile`: 176 writer-pattern rows
- Function `exportgraphics`: 170 writer-pattern rows
- Function `saveas`: 155 writer-pattern rows
- Function `save`: 42 writer-pattern rows
- Function `print`: 16 writer-pattern rows
- Function `movefile`: 3 writer-pattern rows

High-signal writer observations from repository evidence:

- Direct artifact APIs remain common even when outputs appear run-scoped, especially `writetable`, `exportgraphics`, `saveas`, `fopen`/`fprintf`, and `mkdir`. This means path cleanup alone is unsafe without script-by-script contract review.
- The repository already contains documented helper-bypass concerns in `docs/write_system_enforcement_plan.md`, including repo-root `reports/` writers and raw API usage inside otherwise run-like analyses.
- `copyfile` and `movefile` usage was scanned because relocation logic can silently duplicate or re-home artifacts; those call sites are captured in `tables/maintenance_artifact_writer_patterns.csv` for later manual triage.

## Requested module-local artifact surfaces

- `Aging/diagnostics` | type `artifact_container` | risk `HIGH` | evidence: container name/location match; sample=aging_F6I_canonical_exponential_fit.m; aging_F6I_legacy_fm_tau_from_curve.m; aging_F6I_legacy_tau_from_curve.m
- `docs/reports` | type `report_store` | risk `HIGH` | evidence: container name/location match; sample=legacy
- `docs/reports/legacy` | type `legacy_archive_store` | risk `HIGH` | evidence: container name/location match; sample=AGING_AUDIT_REPORT.md; AGING_STABILIZATION_COMPLETE.md; AGING_VERIFICATION_FINAL.md
- `Relaxation ver3/diagnostics` | type `artifact_container` | risk `HIGH` | evidence: container name/location match; sample=analyze_relaxation_derivative_smoothing.m; compare_relaxation_models.m; compute_relaxation_coordinates.m
- `tools/figures` | type `figure_store` | risk `HIGH` | evidence: container name/location match; sample=apply_publication_style.m; create_figure.m; figure_quality_check.m

## Files that appear to be source-of-truth indexes, manifests, status files, reports, or policy docs

- Canonical run metadata families: `run_manifest.json`, `execution_status.csv`, `config_snapshot.m`, `run_notes.txt`, `log.txt`, and run-root `observables.csv` inside `results/*/runs/run_*`.
- Policy/source documents: `docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/output_artifacts.md`, `docs/run_system.md`, `docs/infrastructure_laws.md`, `docs/repo_execution_rules.md`, and `docs/write_system_enforcement_plan.md`.
- Canonical or claim-bearing registries: files under `canonical/` and `claims/`, including `canonical/xy_switching/status.md` and related summaries referenced by other audits.
- Maintenance indexes and inventories at repo root: `source_of_truth_audit.csv`, `source_of_truth_audit_no_run_classified.csv`, `source_of_truth_likely_run_confirmed.csv`, `script_asset_inventory.csv`, `canonical_state_freeze.csv`, and cleanup status logs.
- Run and maintenance reports: repo-root `reports/`, `reports/aging/`, `reports/relaxation/`, `reports/maintenance/`, and `docs/reports/legacy/` all contain text artifacts that appear to be durable narrative outputs.

## Proposed next-stage module audits

- `Aging`: separate canonical run outputs, `results/aging/debug_runs`, legacy replay/bridge material, and any module-local diagnostics or verification sinks.
- `Switching` and `Switching ver12`: reconcile module-local `tables/`, repo-root `figures/`/`reports/` references, and run-scoped switching outputs, with explicit lineage to `results_old/switching/` where needed.
- `Relaxation ver3`: inspect diagnostics and visualization writers against the canonical run system, especially where repo-root `figures/relaxation` and run trees coexist.
- `analysis/` and `analysis_new/`: review cross-experiment scripts that may build run-like trees or reports with local factories or raw APIs instead of shared helpers.
- `tools/` and `status/`: classify tooling/runtime/fixture roots so later cleanup tooling can exclude them from scientific artifact migration plans by default.

## Audit boundary

- No files were moved, renamed, deleted, or rewritten as part of scientific artifact cleanup in this task.
- This report makes canonicality guesses only from repository evidence and existing docs. It does not declare any disputed artifact family canonical without on-disk and documented support.
- Cleanup is not safe to begin directly from location names alone; lineage, fixture boundaries, and policy precedence must be checked first.

## Status

```text
ARTIFACT_ATLAS_COMPLETE = YES
FILES_MOVED = NO
CLEANUP_SAFE_TO_BEGIN = NO
POLICY_DOC_REQUIRED = YES
MODULE_AUDITS_REQUIRED = YES
```
