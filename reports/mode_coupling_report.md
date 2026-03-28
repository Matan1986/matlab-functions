# Mode Coupling Report

## Data and definitions
- kappa1(T): `kappa` from `results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_structure_vs_T.csv` (`subset = no_22K`)
- kappa2(T): `rel_orth_leftover_norm` from same table (mode-2 proxy)
- PT(T): `mean_threshold_mA` from `results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_summary.csv`
- Aligned temperatures: 11

## Results
- corr(kappa1, kappa2) = -0.672660
- corr(kappa2, PT | kappa1) = -0.757600
- Model: kappa2 = intercept + b1*kappa1 + b2*PT
  - intercept = 1.011872
  - b1 = -0.110209
  - b2 = -0.034905
  - R^2 = 0.766730
  - adjusted R^2 = 0.708413

## Final verdict
- MODES_INDEPENDENT: NO
- COUPLING_STRUCTURE_SIMPLE: YES
