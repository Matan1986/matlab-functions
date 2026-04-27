# F6H Pre-fit tau shape mismatch audit (Aging)

Legacy observable dataset: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv`

## Summary

Compares legacy `Dip_depth` / `FM_abs` to canonical TrackB columns on shared `tw`. No new tau fitting; F4A/F4B tables unchanged.

## Verdicts

- **F6H_PREFIT_SHAPE_AUDIT_COMPLETED**: YES
- **LEGACY_PREFIT_DATA_FOUND**: YES
- **CANONICAL_PREFIT_DATA_FOUND**: YES
- **SHARED_TW_DOMAIN_EXISTS**: YES
- **DIP_SHAPE_COMPATIBLE_UP_TO_SCALE**: NO
- **FM_SHAPE_COMPATIBLE_UP_TO_SCALE**: YES
- **DIP_TAU_MISMATCH_VISIBLE_PREFIT**: YES
- **FM_TAU_MISMATCH_VISIBLE_PREFIT**: NO
- **CANONICAL_26K_AFM_LATE_POINT_DOMINATED**: YES
- **CANONICAL_26K_AFM_NONMONOTONIC**: YES
- **LEGACY_26K_DIP_FAST_HALF_RISE**: YES
- **FIT_MODEL_PRIMARY_CAUSE**: YES
- **SIGNAL_SHAPE_PRIMARY_CAUSE**: YES
- **DOMAIN_GATE_PRIMARY_CAUSE**: NO
- **OLD_VALUES_USED_AS_CANONICAL_EVIDENCE**: NO
- **NEW_TAU_FITTING_PERFORMED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO
- **CROSS_MODULE_SYNTHESIS_PERFORMED**: NO
- **READY_FOR_NEXT_ACTION**: YES

## Scale/affine tests (primary Tp 22, 26, 30)

| Tp | sector | n_shared | affine R2 | scale R2 | compatible |
|---|---|---:|---:|---:|---|
| 22 | DIP | 4 | 0.0788 | -1.0751 | NO |
| 26 | DIP | 4 | 0.0033 | -0.6759 | NO |
| 30 | DIP | 3 | 0.1417 | -12.1859 | NO |
| 22 | FM | 4 | 1.0000 | 1.0000 | YES |
| 26 | FM | 4 | 1.0000 | 1.0000 | YES |
| 30 | FM | 3 | 1.0000 | 1.0000 | YES |

## 26 K focused

- **legacy_dip_y_tw**: tw:[3,36,360,3600] y:[2.312464e-07 1.036912e-06 9.625914e-07 9.104078e-07]
- **canonical_afm_y_tw**: tw:[3,36,360,3600] y:[7.941211e-07 5.197899e-07 7.894150e-07 1.589533e-06]
- **legacy_fm_y_tw**: tw:[3,36,360,3600] y:[6.014472e-07 7.326403e-07 8.861816e-07 2.074272e-06]
- **canonical_fm_y_tw**: tw:[3,36,360,3600] y:[6.014472e-07 7.326403e-07 8.861816e-07 2.074272e-06]
- **dip_scale_r2**: -0.675856811311
- **dip_affine_r2**: 0.00328631898424
- **fm_scale_r2**: 1
- **fm_affine_r2**: 1
- **dip_tau_mismatch_visible_prefit**: YES
- **fm_tau_mismatch_visible_prefit**: NO
- **canonical_afm_late_point_dominated**: YES
- **canonical_afm_nonmonotonic**: YES
- **legacy_dip_fast_half_rise_heuristic**: YES

## Fit source (existing tables)

- **legacy_26K_dip_tau_consensus_seconds**: 9.39314322655
- **legacy_26K_dip_tau_logistic_half_seconds**: 9.39314322655
- **legacy_26K_dip_tau_stretched_half_seconds**: 2.16172439218
- **legacy_26K_dip_tau_half_range_seconds**: 10.3923048454
- **legacy_26K_dip_consensus_methods**: half_range, logistic_log_tw, stretched_exp
- **legacy_26K_dip_method_count**: 3
- **legacy_26K_dip_method_spread_decades**: 0.681911554724
- **legacy_26K_fm_tau_consensus_seconds**: 863.920752534
- **legacy_26K_fm_consensus_methods**: half_range_primary
- **legacy_26K_fm_method_count**: 1
- **legacy_26K_fm_method_spread_decades**: 18.002914977
- **canonical_26K_AFM_selected_model**: single_exponential_approach_primary
- **canonical_26K_AFM_tau_seconds**: 8000
- **canonical_26K_AFM_r2_primary**: 0.936029609481
- **canonical_26K_AFM_rmse_primary**: 1.01272138578e-07
- **canonical_26K_FM_selected_model**: single_exponential_approach_primary
- **canonical_26K_FM_tau_seconds**: 2674.06849632
- **canonical_26K_FM_r2_primary**: 0.995748480175
- **mismatch_ABCD_code**: A_DIP_PREFIT_SHAPE_B_FM_FIT_PIPELINE
- **mismatch_note**: Legacy dip: consensus tau_effective_seconds blends logistic_log_tw, stretched_exp, half_range (tau_vs_Tp row). Canonical AFM/FM: single_exponential_approach_primary selection in model_fits + selected_values.

## Interpretation boundary

Shape / scale / domain descriptors only. No mechanism claims. Legacy numbers are not treated as canonical evidence.
