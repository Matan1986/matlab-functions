# Phi avalanche / depinning collective mode test

## Inputs read
- `docs/repo_state.json`
- `phi_structure_physics.md` (**not found in repository at analysis time**)

Primary evidence sources used:
- `results/switching/runs/run_2026_03_25_041314_phi_physical_structure_test/tables/phi_shape.csv`
- `results/switching/runs/run_2026_03_25_041314_phi_physical_structure_test/tables/phi_physical_kernel_correlations.csv`
- `results/switching/runs/run_2026_03_25_041314_phi_physical_structure_test/tables/phi_kernel_reconstruction_metrics.csv`
- `results/switching/runs/run_2026_03_25_042423_kappa_phi_temperature_structure_test/reports/residual_temperature_structure_report.md`
- `results/switching/runs/run_2026_03_25_042423_kappa_phi_temperature_structure_test/tables/rank1_vs_rank2_summary.csv`
- `results/switching/runs/run_2026_03_25_160915_phi_pt_restricted_deformation_stable/tables/phi_pt_restricted_reconstruction_summary.csv`
- `results/switching/runs/run_2026_03_25_160915_phi_pt_restricted_deformation_stable/tables/phi_local_tangent_summary.csv`

## Hypothesis
Phi arises from collective threshold activation cascades (avalanche/depinning-like dynamics).

---

## 1) Localization near switching threshold (`x=0`)

From `phi_shape.csv`, energy concentration of Phi near `x=0` is low:
- `|x| <= 0.05`: **1.47%** of total Phi L2 energy
- `|x| <= 0.10`: **2.17%**
- `|x| <= 0.20`: **2.53%**
- `|x| <= 0.30`: **4.58%**

Peak magnitude location:
- `argmax |Phi|` at `x ~ 0.6985` (not near `x=0`)

Near-zero structure:
- left slope around 0: `+1.008`
- right slope around 0: `-1.583`
- slope jump: `-2.591` (clear cusp/kink around threshold)

Interpretation: Phi has a threshold-centered *shape feature* (kink), but **not threshold-localized energy**.

---

## 2) Scaling / coordinate invariance checks

Using PT-restricted deformation diagnostics:
- Global restricted deformations can reproduce Phi with very high correlation:
  - best `corr_with_phi = 0.9901` (`no_22K`)
  - best `rmse_ratio = 12.28` vs `kappa*Phi` baseline scale
- Local tangent reconstruction is also high-correlation:
  - `corr_tangent = 0.9910` (`no_22K`)
  - `rmse_ratio_tangent = 1.63`

Interpretation: Phi is highly stable under structured PT-coordinate deformations (strong invariance/robustness of the dominant shape manifold).

---

## 3) Mode-2 / structured deviation link to `I_peak`

From residual temperature-structure audit:
- strongest correlation of orthogonal (non-rank1) leftover norm with scalar observables is:
  - `corr(leftover_norm, I_peak_mA) = -0.898977`

Rank structure:
- rank-2 gain over rank-1 (`T <= 30 K`): **0.0759** relative Frobenius error reduction
- mode-1 still dominant (`energy_frac_mode1 = 0.9576`)

Interpretation: there is a **strong structured secondary coupling** tied to `I_peak` (consistent with requested mode-2 coupling signature), but it is a correction on top of dominant rank-1 behavior.

---

## 4) Similarity to symmetric bump kernels (corr + RMSE)

From physical-kernel comparison:
- Symmetric Gaussian bump vs Phi (canonical low-T):
  - `pearson_r = 0.8651`
  - even-part correlation: `0.9890`

But reconstruction quality vs `kappa*Phi` baseline is much worse:
- `rmse_single_kernel = 0.03744`
- `rmse_baseline_kappa_phi = 0.01044`
- ratio `rmse_single / rmse_baseline = 3.587`

Interpretation: Phi has strong symmetric-bump overlap in shape, but symmetric bump alone does not capture full residual dynamics at decomposition quality.

---

## Consolidated assessment against expected avalanche/depinning signatures

- Localization near threshold: **weak/absent** (energy not concentrated near `x=0`)
- Sensitivity to `I_peak` scale: **strong evidence** (`~ -0.90` structured leftover link)
- Scaling structure around `x=0`: **present** (sharp cusp + robust deformation-space reconstruction)
- Structured deviations (mode-2 coupling): **present but secondary** (rank-2 gain is real, not dominant)

## FINAL VERDICT

**AVALANCHE_MODE: PARTIAL**

## Interpretation

Phi is **partially consistent** with depinning-like collective dynamics: it shows a threshold-anchored cusp and strong structured coupling to `I_peak`/secondary modes, but it fails the strongest localization criterion expected for a clean avalanche-threshold mode (most Phi energy is away from `x=0`).
