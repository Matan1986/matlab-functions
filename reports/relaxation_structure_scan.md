# Relaxation data structure scan

**Scope:** `C:/Dev/matlab-functions/results/aging`, `C:/Dev/matlab-functions/results/switching` (first ~20 CSV files, sorted paths)
**EXECUTION_STATUS:** SUCCESS
**N_FILES_SCANNED:** 20
**LONG_FORMAT_FOUND:** NO
**WIDE_FORMAT_FOUND:** YES
**LIKELY_SOURCE_FILE:** ``

## Per-file summary
| file | n_rows | n_cols | temp | time | signal | format |
|---|---:|---:|:--:|:--:|:--:|:---|
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_171522_observable_mode_correlation/tables/observable_mode_correlations.csv` | 36 | 12 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_171522_observable_mode_correlation/tables/observable_mode_joined_table.csv` | 60 | 35 | YES | YES | NO | wide |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/observables.csv` | 210 | 8 | YES | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/observable_matrix.csv` | 30 | 13 | YES | YES | NO | wide |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/observable_mode_correlations.csv` | 36 | 7 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/svd_mode_coefficients.csv` | 60 | 12 | YES | YES | NO | wide |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/svd_singular_values.csv` | 60 | 6 | NO | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/observables.csv` | 3 | 11 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/DeltaM_map.csv` | 450 | 3 | NO | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/T_axis.csv` | 450 | 1 | YES | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/observable_matrix.csv` | 3 | 11 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/observable_mode_correlations.csv` | 15 | 6 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_U.csv` | 450 | 4 | YES | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_V.csv` | 3 | 8 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_mode_coefficients.csv` | 3 | 9 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_singular_values.csv` | 3 | 5 | NO | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/tw_axis.csv` | 3 | 6 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/observables.csv` | 4 | 11 | NO | YES | NO | unknown |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/tables/DeltaM_map.csv` | 450 | 4 | NO | NO | NO | feature |
| `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/tables/T_axis.csv` | 450 | 1 | YES | NO | NO | feature |

## Column names (semicolon-separated)
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_171522_observable_mode_correlation/tables/observable_mode_correlations.csv**
  `matrix_name; coefficient; observable; n_points; wait_time_count; tp_min; tp_max; pearson_r; pearson_p; spearman_rho; spearman_p; best_abs_correlation`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_171522_observable_mode_correlation/tables/observable_mode_joined_table.csv**
  `sample; dataset; wait_time; temperature; Tp; matrix_name; coeff_mode1; coeff_mode2; coeff_mode3; Dip_depth; Dip_sigma; Dip_T0; FM_abs; FM_E; FM_step_mag; n_settings; n_default_settings; FM_abs_aux; FM_signed_aux; FM_present_aux; reconstruction_error_rank1; reconstruction_error_rank2; reconstruction_error_rank3; Dip_depth_std; Dip_depth_n; Dip_sigma_std; Dip_sigma_n; Dip_T0_std; Dip_T0_n; FM_abs_std; FM_abs_n; FM_E_std; FM_E_n; FM_step_mag_std; FM_step_mag_n`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/observables.csv**
  `experiment; sample; temperature; observable; value; units; role; source_run`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/observable_matrix.csv**
  `sample; dataset; wait_time; tw_seconds; log10_tw_seconds; temperature; Tp; Dip_depth; Dip_T0; Dip_sigma; FM_abs; FM_E; FM_step_mag`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/observable_mode_correlations.csv**
  `matrix_name; coefficient; observable; n_points; pearson_correlation; spearman_correlation; best_abs_correlation`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/svd_mode_coefficients.csv**
  `matrix_name; dataset; wait_time; tw_seconds; log10_tw_seconds; Tp; coeff_mode1; coeff_mode2; coeff_mode3; reconstruction_error_rank1; reconstruction_error_rank2; reconstruction_error_rank3`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_200643_observable_mode_correlation/tables/svd_singular_values.csv**
  `matrix_name; mode; singular_value; normalized_singular_value; explained_variance_ratio; cumulative_variance_ratio`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/observables.csv**
  `sample; dataset; wait_time; tw_seconds; log10_tw_seconds; Tp_K; Dip_depth; Dip_T0; Dip_sigma; FM_abs; FM_step_mag`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/DeltaM_map.csv**
  `tw_36s; tw_360s; tw_3600s`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/T_axis.csv**
  `T_K`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/observable_matrix.csv**
  `sample; dataset; wait_time; tw_seconds; log10_tw_seconds; Tp_K; Dip_depth; Dip_T0; Dip_sigma; FM_abs; FM_step_mag`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/observable_mode_correlations.csv**
  `mode; observable; n_points; pearson_correlation; spearman_correlation; best_abs_correlation`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_U.csv**
  `T_K; U_mode1; U_mode2; U_mode3`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_V.csv**
  `tw_index; tw_seconds; log10_tw_seconds; dataset; wait_time; V_mode1; V_mode2; V_mode3`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_mode_coefficients.csv**
  `tw_index; tw_seconds; log10_tw_seconds; dataset; wait_time; Tp_K; coeff_mode1; coeff_mode2; coeff_mode3`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/svd_singular_values.csv**
  `mode; singular_value; normalized_singular_value; explained_variance_ratio; cumulative_variance_ratio`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_220738_tp_30_structured_export/tables/tw_axis.csv**
  `tw_index; tw_seconds; log10_tw_seconds; dataset; wait_time; Tp_K`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/observables.csv**
  `sample; dataset; wait_time; tw_seconds; log10_tw_seconds; Tp_K; Dip_depth; Dip_T0; Dip_sigma; FM_abs; FM_step_mag`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/tables/DeltaM_map.csv**
  `tw_3s; tw_36s; tw_360s; tw_3600s`
- **C:/Dev/matlab-functions/results/aging/runs/run_2026_03_10_223913_tp_6_structured_export/tables/T_axis.csv**
  `T_K`
