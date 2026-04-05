# Switching parameter robustness update audit

## Exact 4 blockers addressed

1. `temperature_filter`
- Added explicit admissibility filtering before acceptance metrics:
  - boundary exclusions at 4 K and 30 K,
  - forced remove at 34 K,
  - high-T exclusion when width is missing with peak-at-lowest-current or low-amplitude condition.

2. `parameter_filter`
- Acceptance perturbations now use canonical-equivalent method sets only.
- Non-equivalent method families were removed from acceptance sweep.

3. `data_selection_trust`
- Legacy hardcoded alignment-audit source was removed.
- Script now selects input from TRUSTED_CANONICAL run classification and loads canonical Switching table input.

4. `coordinate_definition`
- Variant-dependent coordinate scaling sweep was removed from acceptance path.
- Acceptance metrics now use fixed canonical coordinate handling.

## What changed in the script

- Converted the file to an executable script entry (`clear; clc;`) with inline execution status handling.
- Added trust-locked canonical input selection and run-backed output directory creation.
- Added temperature decision table generation and acceptance include-mask application.
- Replaced 4x4x3x3 non-equivalent sweep with canonical-equivalent perturbation grid.
- Added required canonical artifact names:
  - `tables/switching_parameter_robustness.csv`
  - `tables/switching_parameter_robustness_status.csv`
  - `reports/switching_parameter_robustness.md`
  - `execution_status.csv`
- Preserved legacy artifact pattern by continuing to write:
  - `tables/parameter_robustness_summary.csv`
  - `tables/parameter_robustness_verdicts.csv`
  - `tables/parameter_robustness_profiles_by_T.csv`
  - `reports/parameter_robustness_report.md`
  - `status/parameter_robustness_status.txt`

## What was preserved unchanged

- Switching-only analysis scope.
- Existing robustness verdict threshold values:
  - I_peak >= 0.90
  - width >= 0.85
  - S_peak >= 0.90
  - kappa1 >= 0.80
  - collapse ratio in [0.67, 1.50]
- Existing report/table writing style (summary + verdict + profile + markdown report).

## Rerun readiness in principle

Based on the four validated minimal blockers, script-level handling is now present for all four components.

`SCRIPT_NOW_RERUN_READY_IN_PRINCIPLE=YES`

Note:
- MATLAB execution was not run in this update turn. Runtime validation still depends on the repository execution wrapper behavior in the current workspace.
