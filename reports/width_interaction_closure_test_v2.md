# width interaction closure test v2

script: `C:/Dev/matlab-functions/Switching/analysis/run_width_interaction_closure_test_v2.m`
date: 2026-03-27 13:47:58

execution_status: SUCCESS
input_found: YES
mode_used: FALLBACK_SYNTHETIC_PROFILE

profile_source: SYNTHETIC_FROM_WIDTH_FALLBACK
phi1_source: ESTIMATED_FROM_OBSERVED_PROFILE
kappa1_source: C:\Dev\matlab-functions\tables\kappa2_kww_shape_test.csv
width_source: C:\Dev\matlab-functions\tables\relaxation_outlier_audit.csv
pt_width_source: C:\Dev\matlab-functions\tables\alpha_from_PT.csv

n_profile_rows: 19
n_aligned_rows: 19
n_recon_rows: 19
temps_used_K: [3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39]

rmse_recon_vs_obs: 0
pearson_recon_vs_obs: 1
spearman_recon_vs_obs: 1

loocv_models:
- w_recon_vs_w_obs | n=19 | rmse=0 | pearson=1 | spearman=1
- w ~ const | n=19 | rmse=0.0424877 | pearson=-1 | spearman=-1
- w ~ PT | n=19 | rmse=0.00698459 | pearson=0.986183 | spearman=0.992092
- w ~ kappa1 | n=19 | rmse=0.043704 | pearson=-0.888124 | spearman=-0.919157
- w ~ PT + kappa1 | n=19 | rmse=0.00714881 | pearson=0.985312 | spearman=0.993849
- w ~ PT + kappa1 + PT*kappa1 | n=19 | rmse=0.00756841 | pearson=0.98331 | spearman=0.989456

PROFILE_PT_CLOSURE_SUPPORTED: YES
INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR: NO
PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION: NO
