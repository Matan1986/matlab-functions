# Rank-2 Stability Report

## Inputs
- Residual matrices and temperature slices from: `results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test`.
- Mode-1 (Phi) and mode-2 diagnostics from SVD tables.

## SVD and Stability
- Decision subset: **no_22K**.
- sigma1/sigma2 = **6.2635**.
- Variance mode-1 = **0.9598**; mode-(1+2) = **0.9843**.
- RMSE rank-1 = **0.2005**; rank-2 = **0.1255**; gain = **0.0751**.
- Mode stability (LOO cosine, no_22K): min **0.9993**, mean **0.9999**, max angle **2.08 deg**.

## Mode-2 Correlation Readout
- corr(mode2, I_peak) = **-0.9265**.
- corr(mode2, kappa) = **-0.6970**.
- Tail observables: mean-threshold **-0.8751**, std-threshold **-0.8896**, skewness **-0.5705**, cdf-rmse **-0.3494**.
- Strongest descriptor: **I_peak_mA** (**-0.9265**).

## Final Verdict
- MODE2_REAL: **YES**
- MODE2_LINKED_TO_LANDSCAPE: **YES**
- RANK1_SUFFICIENT: **NO**
