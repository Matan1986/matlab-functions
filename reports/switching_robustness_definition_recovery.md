# Switching robustness definition recovery

## Original robustness definition

Evidence source set (Switching only):
- reports/parameter_robustness_stage1_canonical_report.md
- tables_old/parameter_robustness_stage1_canonical_methods.csv
- tables_old/parameter_robustness_stage1_canonical_summary.csv
- reports/parameter_robustness_stage1b_width_kappa_report.md
- tables_old/parameter_robustness_stage1b_verdicts.csv
- Switching/analysis/switching_energy_scale_collapse_filtered.m
- reports/temperature_boundary_audit.md
- tables_old/temperature_boundary_audit.csv
- tables_old/switching_measurement_robustness_summary.csv

Recovered pre-canonical robustness behavior:
1. Parameter filtering was constrained to canonical-equivalent definitions (Stage1 methods table), with explicit exclusions for non-equivalent observables and variant-specific x scaling.
2. Data source was source-locked to alignment audit samples (run_2026_03_10_112659_alignment_audit) and S_percent.
3. Stability was evaluated primarily as variant-vs-canonical, not all-vs-all: corr_vs_canonical, rmse_abs, median_rel_dev, worst_rel_dev.
4. Forensic robustness (Stage1B) added causal checks: coarse-grid and half-max undersampling ratios, kappa sensitivity cases A-D, and map-vs-scalarization separation.
5. Temperature handling existed in historical Switching robustness artifacts:
- explicit filter controls in switching_energy_scale_collapse_filtered (forcedRemoveTemps_K=34; highTempBoundary_K=30; width_missing and peak-position conditions), and
- explicit boundary-effect audit on 4K and 30K.

## Canonical robustness behavior

From Switching/analysis/run_parameter_robustness_switching_canonical.m:
1. Input paths are hardcoded to run_2026_03_10_112659_alignment_audit alignment files.
2. Variant set is exhaustive 4x4x3x3 (144), including methods historically marked excluded in Stage1 method filtering.
3. Temperature handling keeps all Tgrid rows with at least 5 finite points; no explicit phase-transition boundary exclusions.
4. Metrics are global min pairwise correlations and collapse ratio range, with fixed thresholds:
- IPEAK >= 0.90
- WIDTH >= 0.85
- SPEAK >= 0.90
- KAPPA1 >= 0.80
- collapse ratio in [0.67, 1.50]

## Key mismatches

See tables/switching_robustness_definition_recovery.csv.

High-severity mismatches recovered:
1. Missing historical temperature-boundary filtering/exclusion behavior.
2. Removal of canonical-equivalent parameter filtering (script now includes historically excluded variants).
3. Canonical input trust mismatch (hardcoded historical run instead of current TRUSTED_CANONICAL run target).
4. Collapse-coordinate rule mismatch (historically fixed canonical coordinate vs variant-specific scaling modes).

## Root cause of failure

Based on current repository evidence for the failed canonical robustness attempt:
1. INPUT_MISMATCH:
- Requested canonical input was run_2026_04_03_000147_switching_canonical.
- Script is hardcoded to run_2026_03_10_112659_alignment_audit.
- Required source files for that hardcoded run are absent in this workspace.
2. EXECUTION_FAILURE:
- tools/run_matlab_safe.bat currently launches tools/temp_runner.m and does not execute the requested script path.
- This prevents artifact generation even when invocation appears successful.
3. SCRIPT_LOGIC_GAP:
- Output contract differs from requested switching_parameter_robustness artifact names.
- No canonical-trust validation logic is present.
4. MISSING_FILTER:
- Historical robustness included explicit temperature-boundary handling not represented in the canonical parameter robustness script.

Primary root-cause class for the failed run outcome (RUN_VALID=NO, CANONICAL_INPUT_CONFIRMED=NO, no artifacts):
- INPUT_MISMATCH + EXECUTION_FAILURE.

## Required adjustments (conceptual only, NO code changes)

1. Restore the historical definition split in audit interpretation:
- canonical-equivalent parameter robustness versus exploratory non-equivalent sweep.
2. Reintroduce explicit temperature-boundary handling as a documented requirement for robustness interpretation (especially near 30K boundary and edge-effect temperatures).
3. Enforce canonical input trust lock in robustness execution criteria before interpreting metrics.
4. Keep variant-vs-canonical metrics and Stage1B forensic diagnostics as first-class outputs when claiming continuity with pre-canonical robustness definitions.
