# Switching robustness rerun readiness

## Minimal canonical robustness recipe

Validated minimal set (critical components):
1. `temperature_filter` (PHYSICALLY_REQUIRED)
2. `parameter_filter` (PHYSICALLY_REQUIRED)
3. `data_selection_trust` (CANONICAL_REPLACED)
4. `coordinate_definition` (CANONICAL_REPLACED)

Execution-ready canonical recipe for robustness acceptance:
1. Load input only from a TRUSTED_CANONICAL Switching run.
2. Apply explicit temperature admissibility filtering (boundary and high-T guards) before metric aggregation.
3. Evaluate only canonical-equivalent perturbations in acceptance logic.
4. Keep canonical coordinate handling fixed for acceptance (no coordinate sweep in primary acceptance path).

## Current implementation gaps

Cross-check against `Switching/analysis/run_parameter_robustness_switching_canonical.m`:
1. Temperature filter gap:
- script uses only `validRows = sum(isfinite(Smap),2) >= 5` and has no boundary/high-T exclusion block.
2. Parameter filter gap:
- script includes non-equivalent methods (`com`, `halfmax_mid`, `dsdi_peak`, `rms`, `iqr`, `asymmetric`, `local_*`) in acceptance sweep.
3. Data selection trust gap:
- script hardcodes legacy alignment run paths (`run_2026_03_10_112659_alignment_audit`) and does not enforce TRUSTED_CANONICAL selection.
4. Coordinate definition gap:
- script sweeps `scaleModes = [fwhm,rms,asymmetric]`, i.e., variant-dependent coordinates.

## Exact blockers to rerun

Blocking items for minimal-component readiness:
1. `temperature_filter` not implemented in canonical robustness script.
2. `parameter_filter` not enforced in canonical acceptance path.
3. `data_selection_trust` not enforced; legacy input hardcoding remains.
4. `coordinate_definition` is implemented in conflicting form (variant sweep) rather than canonical fixed handling.

Additional execution-level blocker already documented in contract evidence:
- Wrapper currently executes `tools/temp_runner.m` instead of the requested script path, preventing valid execution confirmation.

## Rerun decision

Rerun cannot proceed immediately.

`RERUN_CAN_PROCEED_NOW=NO`

Script update is required first to satisfy the four validated minimal canonical components, and execution-entry validity must also be enforced.
