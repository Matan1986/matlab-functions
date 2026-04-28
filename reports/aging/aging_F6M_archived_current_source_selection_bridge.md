# F6M archived-vs-current source-selection bridge

diagnostic bridge only; no canonical reinterpretation.

## Inputs

- `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_11_011643_observable_identification_audit\tables\aging_observable_point_aggregation.csv`
- `C:\Dev\matlab-functions\tables\aging\consolidation_structured_run_dir.txt`
- `C:\Dev\matlab-functions\tables\aging\aggregate_structured_export_aging_Tp_tw_2026_04_26_085033\tables\observable_matrix.csv`

## Main bridge finding

- Primary divergence layer: `SOURCE_TRACE_SELECTION_CHANGED`.
- Across overlapping Tp/tw rows, FM is mostly stable while Dip shifts with source-run family change (March archived vs April current).
- 26K shows the same pattern: Dip differs at all tw while FM matches.

## 26K values

- tw=3: Dip archived=2.31246381576e-07, Dip current=7.94121124072e-07, FM archived=6.01447161069e-07, FM current=6.01447161069e-07
- tw=36: Dip archived=1.03691245288e-06, Dip current=5.19789946402e-07, FM archived=7.32640312217e-07, FM current=7.32640312217e-07
- tw=360: Dip archived=9.625914172e-07, Dip current=7.89415049548e-07, FM archived=8.86181574951e-07, FM current=8.86181574951e-07
- tw=3600: Dip archived=9.10407833456e-07, Dip current=1.58953335102e-06, FM archived=2.07427201171e-06, FM current=2.07427201171e-06

## Code/config bridge audit

- name_status_vs_archived_commit: RECORDED
- structured_export_script_changed_or_added: YES
- stage4_changed_vs_archived: YES
- model_components_changed_vs_archived: YES
- consolidation_contract_mapping_same: YES
- drift_plausibly_explains_dip_shift: YES

## Mixed replay availability

- archived_source_archived_code_available: YES
- archived_source_current_code_available_without_rerun: PARTIAL
- current_source_archived_code_available_without_rerun: NO
- archived_vs_current_source_bridge_from_existing_artifacts: YES
- full_mixed_replay_without_pipeline_rerun: NO

## Next action

- NEXT_ACTION: F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY
- RATIONALE: Primary divergence is source-trace selection with concurrent stage4/model drift; bridge replay should isolate source-vs-code contributions using archived-equivalent inputs.
- ALTERNATE_NOT_CHOSEN: DIRECT_NON_RMS_METHOD_SEARCH deferred until source bridge closure
- READY_FOR_F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY: YES
- READY_FOR_F6N_CURRENT_SOURCE_DIP_REPAIR_AUDIT: YES
- READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH: NO

## Verdicts

- **F6M_SOURCE_SELECTION_BRIDGE_COMPLETED**: YES
- **ARCHIVED_CURRENT_SOURCE_MAP_CREATED**: YES
- **DIVERGENCE_LAYER_CLASSIFIED**: YES
- **PRIMARY_DIVERGENCE_LAYER**: SOURCE_TRACE_SELECTION_CHANGED
- **TP26_BRIDGE_DIAGNOSIS_COMPLETED**: YES
- **CODE_CONFIG_BRIDGE_AUDIT_COMPLETED**: YES
- **MIXED_REPLAY_AVAILABILITY_ASSESSED**: YES
- **ARCHIVED_FAST_DIP_SOURCE_IDENTIFIED**: NO
- **CURRENT_SLOW_DIP_SOURCE_IDENTIFIED**: YES
- **SOURCE_TRACE_SELECTION_CHANGED**: YES
- **STAGE4_DECOMPOSITION_CHANGED**: YES
- **STRUCTURED_EXPORT_CODE_CHANGED**: YES
- **FILTERING_OR_FINITE_FM_CHANGED**: YES
- **SAMPLE_DATASET_SELECTION_CHANGED**: NO
- **READY_FOR_F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY**: YES
- **READY_FOR_F6N_CURRENT_SOURCE_DIP_REPAIR_AUDIT**: YES
- **READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH**: NO
- **METHOD_SEARCH_PERFORMED**: NO
- **R_VS_X_ANALYSIS_PERFORMED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO
- **RELAXATION_TOUCHED**: NO
- **SWITCHING_TOUCHED**: NO
