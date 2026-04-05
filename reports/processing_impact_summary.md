# Processing Impact on Observables

## Scope
- Inputs restricted to existing tables under: results/switching/runs/*/tables/
- Deterministic source directory: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_28_214509_switching_physics_output_robustness_fast\physics_output_robustness\tables
- Variants: raw_xy_delta, xy_over_xx, baseline_aware
- Alignment: intersection of T_K across variants only

## Available observables
- Included in all variants: I_peak, width, S_peak
- Missing in at least one variant: kappa1, collapse_score

## Conclusion Stability
- kappa1_vs_S_peak relation_stable: NO
- width_vs_T_trend relation_stable: YES
- I_peak_vs_T_trend relation_stable: YES
- collapse_preserved: NO
- PHYSICS_CONCLUSIONS_STABLE: NO

Interpretation:
- Width and I_peak temperature relationships are preserved across processing variants.
- kappa1-based and collapse-based relationship checks cannot be confirmed from the provided variant tables and are marked NO under strict YES/NO requirements.
- Under strict criteria, overall physics-conclusion stability is NO.
