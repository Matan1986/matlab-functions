# F7D full structured export sidecar verification

- Run command: `tools/run_matlab_safe.bat "C:\Dev\matlab-functions\Aging\analysis\aging_structured_results_export.m"`
- Run root: `C:\Dev\matlab-functions\results\aging\runs\run_2026_04_30_170602_tp_22_structured_export`
- Execution result: success (`PRE_EXECUTION_GUARD=OK`, wrapper reached `AFTER_MATLAB_CALL`).

## Real structured export outputs found

- `observables.csv`
- `tables/observable_matrix.csv`
- `tables/DeltaM_map.csv`
- `tables/T_axis.csv`
- `tables/tw_axis.csv`
- `tables/svd_singular_values.csv`
- `tables/svd_U.csv`
- `tables/svd_V.csv`
- `tables/svd_mode_coefficients.csv`
- `tables/observable_mode_correlations.csv`

## Sidecar coverage

Per-artifact sidecars and manifests were created for all ten real output CSVs:

- `<artifact>_lineage.csv`
- `<artifact>_lineage.json`
- `<artifact>_manifest.csv`

Aggregate sidecar outputs exist in run tables:

- `tables/structured_export_sidecar_manifest.csv`
- `tables/structured_export_sidecar_issues.csv`

## Metadata verification summary

Across real structured export artifacts:

- `writer_family_id = WO_STRUCTURED_EXPORT`
- `validation_mode = audit_only`
- `model_readiness = diagnostic_only`
- `canonical_status = not_canonical`
- `model_use_allowed = no`
- `canonical_use_allowed = no`
- `tau_or_R_flag = NOT_APPLICABLE` (no false tau/R population)

Warning behavior:

- `F7A_PLAIN_DIP_DEPTH_UNRESOLVED` warning appears for:
  - `observables.csv`
  - `tables/observable_matrix.csv`

No output claims model-ready or canonical promotion.

## Notes / limitations

- This is a controlled full structured-export execution verification only.
- No tau extraction run, no clock-ratio run, no consolidation patch, no model analysis.
- No cross-module comparison was performed.
- No staging, commit, or push in F7D.
