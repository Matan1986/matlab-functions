# F6K Dip replay gap root-cause audit

diagnostic_only; not_canonical; not_physical_claim; no R-vs-X.

## Inputs

- Legacy dataset build report: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\reports\aging_dataset_build_report.md`
- F6J replay report: `C:\Dev\matlab-functions\reports\aging\aging_F6J_replay_legacy_observables_on_current_pipeline.md`
- Git name-status vs legacy commit:

```
A	Aging/analysis/aging_structured_results_export.m
A	Aging/analysis/run_aging_observable_dataset_consolidation.m
M	Aging/models/analyzeAFM_FM_components.m
M	Aging/pipeline/stage4_analyzeAFM_FM.m

```

## Key findings

1. Five-column observable contract (`Tp,tw,Dip_depth,FM_abs,source_run`) is the same in replay logic.
2. Lineage diverges upstream: archived dataset used March structured-export sources (`run_2026_03_10_*` via observable_identification_audit), while current replay used April aggregate sources (`run_2026_04_26_*`).
3. Code lineage diverges by commit (`ec3ea0b` vs newer commit): stage4/model decomposition files changed materially.
4. FM is stable across aligned rows, but Dip_depth differs strongly by row; at 26 K this moves Dip tau from short legacy clock to long replay clock, collapsing old R spike.

## 26 K values

- tw=3 s: Dip legacy=2.31246381576e-07, Dip current=7.94121124072e-07, rel_diff=2.43409; FM legacy=6.01447161069e-07, FM current=6.01447161069e-07
- tw=36 s: Dip legacy=1.03691245288e-06, Dip current=5.19789946402e-07, rel_diff=-0.498714; FM legacy=7.32640312217e-07, FM current=7.32640312217e-07
- tw=360 s: Dip legacy=9.625914172e-07, Dip current=7.89415049548e-07, rel_diff=-0.179906; FM legacy=8.86181574951e-07, FM current=8.86181574951e-07
- tw=3600 s: Dip legacy=9.10407833456e-07, Dip current=1.58953335102e-06, rel_diff=0.745957; FM legacy=2.07427201171e-06, FM current=2.07427201171e-06

## Verdicts

- **F6K_ROOT_CAUSE_AUDIT_COMPLETED**: YES
- **ARCHIVED_LEGACY_LINEAGE_TRACED**: YES
- **CURRENT_LINEAGE_TRACED**: YES
- **SAME_OBSERVABLE_CONTRACT_CONFIRMED**: YES
- **UPSTREAM_DIP_SOURCE_MATCHES**: NO
- **SOURCE_TRACE_ALIGNMENT_CONFIRMED**: NO
- **DIP_GAP_ROOT_CAUSE_IDENTIFIED**: YES
- **PRIMARY_ROOT_CAUSE**: CURRENT_EXPORT_NOT_EQUIVALENT_TO_ARCHIVED_EXPORT
- **OLD_DATASET_BIT_REPLAYABLE_FROM_CURRENT_EXPORTS**: NO
- **OLD_DATASET_REPLAYABLE_FROM_ARCHIVED_INPUTS**: YES
- **CURRENT_EXPORT_EQUIVALENT_TO_ARCHIVED_EXPORT**: NO
- **READY_FOR_PARITY_REPLAY_FIX**: YES
- **READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH**: NO
- **NEW_METHOD_SEARCH_PERFORMED**: NO
- **R_VS_X_ANALYSIS_PERFORMED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO

## Next action decision

Root cause is primarily source-trace + upstream decomposition drift (current exports not equivalent to archived exports). Recommend parity replay repair first: rebuild replay using archived-equivalent source runs/commit where possible, then reassess. Direct non-RMS search is not started in this audit.
