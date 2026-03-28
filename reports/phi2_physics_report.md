# Phi2 (mode-2) shape physics

## Inputs
- Residual decomposition replay: alignment `run_2026_03_10_112659_alignment_audit`, scaling `run_2026_03_12_234016_switching_full_scaling_collapse`, PT `run_2026_03_24_212033_switching_barrier_distribution_from_map`.
- Low-T window: T ≤ 30.0 K; n_low = 14.

## 1. Symmetry
- Even energy fraction: **0.5984**; odd energy fraction: **0.3976**.

## 2. Localization
- Energy fraction with |x| ≤ 1.00: **1.0000** (wide cut; full x-grid may lie inside this band).
- Energy fraction with |x| ≤ 0.50: **0.7833** (tight cut).
- RMS |x| (|Phi2|^2-weighted): **0.3896**.

## 3. Structure
- Cusp proxy: |d^2 Phi2/dx^2| at nearest grid point to 0 / mean(|d2|) = **9.1014**.
- Shoulder / tail: mean(|Phi2|, x>0.3) / mean(|Phi2|, x<-0.3) = **0.2189**.
- Zero crossings (oscillation proxy): **1**.

## 4. Kernel comparison (zero-mean unit L2)
- `dPhi1_dx`: r = -0.8860, RMSE = 0.1309.
- `gaussian_bump`: r = -0.2186, RMSE = 0.1053.
- `antisymmetric_bump`: r = 0.6406, RMSE = 0.0572.
- `width_modulation_x_phi1`: r = -0.8916, RMSE = 0.1311.

## 5. Stability
- LOO SVD Phi2 vs full Phi2 cosine: min **0.1396**, mean **0.9349**, std **0.2290**.
- Regime subsets vs full Phi2:
- `T_le_20K`: cosine to full Phi2 = 0.0916.
- `T_14_to_26K`: cosine to full Phi2 = -0.6560.
- `T_ge_22K`: cosine to full Phi2 = -0.9757.

## Final verdict
- PHI2_SYMMETRIC: **YES** (even energy fraction ≥ 0.55).
- PHI2_LOCALIZED: **YES** (tight-center energy ≥ 0.45 for |x| ≤ 0.50, or RMS |x| ≤ 0.55).
- PHI2_SIMPLE_KERNEL_REDUCIBLE: **YES** (max |corr(simple kernel)| ≥ 0.72).
- PHI2_STABLE: **NO** (min LOO cosine ≥ 0.88).