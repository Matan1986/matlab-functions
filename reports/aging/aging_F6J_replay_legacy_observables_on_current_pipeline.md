# F6J-REPLAY: legacy observable definitions on current structured exports

diagnostic_replay_only; not_canonical; not_physical_claim.

- Legacy reference dataset: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv`
- Current structured aggregate dir: `C:\Dev\matlab-functions\tables\aging\aggregate_structured_export_aging_Tp_tw_2026_04_26_085033`
- Matrix file: `C:\Dev\matlab-functions\tables\aging\aggregate_structured_export_aging_Tp_tw_2026_04_26_085033\tables\observable_matrix.csv`

## Definition (summary)

Legacy `Dip_depth` / `FM_abs` in the five-column contract are **identity copies** of `observable_matrix.csv` columns produced by structured export (`aging_structured_results_export` / Stage4/stage pipeline), consolidated by `run_aging_observable_dataset_consolidation.m`. Stage4 sets `Dip_depth` from residual/AFM amplitude path and `FM_abs = abs(FM_signed)` (`stage4_analyzeAFM_FM.m`). This replay **does not** use `Dip_depth_direct_TrackB`.

## Verdicts

- **F6J_REPLAY_COMPLETED**: YES
- **LEGACY_OBSERVABLE_BUILDER_FOUND**: YES
- **CURRENT_CANONICAL_INPUTS_FOUND**: YES
- **EXACT_OLD_OBSERVABLE_REPLAY_POSSIBLE**: PARTIAL
- **APPROXIMATE_OLD_OBSERVABLE_REPLAY_PERFORMED**: YES
- **OLDDEF_CURRENT_OBSERVABLE_DATASET_CREATED**: YES
- **OLD_TAU_LAYER_REPLAYED_ON_CURRENT_OBSERVABLES**: YES
- **OLD_R_REPRODUCED_ON_CURRENT_RUNS**: PARTIAL
- **OLD_26K_SPIKE_REPRODUCED_ON_CURRENT_RUNS**: NO
- **OLD_VALUES_USED_AS_CANONICAL_EVIDENCE**: NO
- **NEW_METHOD_SEARCH_PERFORMED**: NO
- **R_VS_X_ANALYSIS_PERFORMED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO
- **READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH**: YES

## Tau run directories (diagnostic)

- Dip extraction: `C:\Dev\matlab-functions\results\aging\runs\run_2026_04_28_082702_aging_timescale_extraction`
- FM extraction: `C:\Dev\matlab-functions\results\aging\runs\run_2026_04_28_082928_aging_F6J_fm_tau_replay`

## Shape comparison notes

At 26 K, t_w=3600 s: rel_diff_dip=0.746, rel_diff_fm=0 (see CSV for full grid).

## Tables

See `tables/aging/aging_F6J_*.csv`.
