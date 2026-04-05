# Reconstruction v1

## Scope
- Read-only reconstruction from existing artifacts only.
- Deterministic PT backbone from observed map only; no fitting or smoothing.
- Exact rectangular intersection retained: N_T=9, N_I=6.

## Inputs
- results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv
- tables/phi1_local_shape_v2_20260329_234420.csv
- tables/kappa1_phi1_local_v2_20260329_234420.csv
- tables/kappa1_from_PT_aligned.csv

## Global Metrics
- PT_ONLY: RMSE=0.00119976569154929, corr=0.999932395655933, residual_corr=NaN, collapse_rmse=0.166229547033825
- PT_PLUS_LEGACY: RMSE=0.0555356049587325, corr=0.978837910117563, residual_corr=-0.0578313857611522, collapse_rmse=0.115653990498456
- PT_PLUS_LOCAL: RMSE=0.172829380806903, corr=0.916741079114121, residual_corr=-0.193998024708451, collapse_rmse=0.266844636614643

## Comparison
- IMPROVEMENT_OVER_PT: delta_RMSE_legacy_vs_PT=-0.0543358392671832, delta_RMSE_local_vs_PT=-0.171629615115353
- LOCAL_VS_LEGACY: delta_RMSE_local_vs_legacy=-0.11729377584817, delta_corr_local_vs_legacy=-0.0620968310034429

## Verdicts
- PT_SUFFICIENT: YES
- LEGACY_IMPROVES_OVER_PT: NO
- LOCAL_IMPROVES_OVER_PT: NO
- LOCAL_BETTER_THAN_LEGACY: NO
- SINGLE_MODE_SUFFICIENT: NO
- FINAL_RECONSTRUCTION_MODEL: PT_ONLY

## Interpretation
- Phi1 residual capture: residual_corr(local)=-0.193998024708451, residual_corr(legacy)=-0.0578313857611522. Values near +1 indicate strong residual-structure capture; values near 0 or negative indicate weak capture.
- Local vs legacy physical reconstruction: assessed by delta_RMSE_local_vs_legacy=-0.11729377584817 and delta_corr_local_vs_legacy=-0.0620968310034429.
- One-mode sufficiency from this test: SINGLE_MODE_SUFFICIENT=NO.
- Minimal physical model supported by observed metrics: PT_ONLY.
