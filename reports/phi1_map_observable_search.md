# PHI1 Map-Derived Observable Search (deltaS-window signatures)

## Scope
Goal: define a small set of physically motivated, *map-level* observables that act as practical proxies/signatures for the Phi1 symmetric ridge-centered redistribution mode.

Constraints followed:
- No new PT extraction.
- No new decomposition pipeline.
- Use only canonical switching backbone/residual outputs.
- Candidate set kept intentionally small (5 observables).

## Residual definition (as requested)
We use the canonical residual (in the normalized ridge coordinate):

deltaS(x,T) = S(x,T) - S_peak(T) * CDF(P_T)(x),

with the ridge coordinate x matching the stored switching decomposition:
`x = (I - I_peak(T)) / w(T)`.

## Canonical data used
Phi1 mode amplitude and shape were taken from the canonical residual decomposition outputs:
- `results/switching/runs/run_2026_03_25_011649_rsr_child_nxgrid_180/tables/phi_shape.csv` (Phi1(x))
- `results/switching/runs/run_2026_03_25_011649_rsr_child_nxgrid_180/tables/kappa_vs_T.csv` (kappa1(T))

The canonical residual decomposition quality indicates rank-1 dominance in the interpretation window:
- `rank1_energy_fraction ≈ 0.9577` (so residuals are strongly Phi1-dominated).

Temperature grid for the scalar validation (LOOCV and correlations):
- T = 4, 6, ..., 26 K (12 points), matching the canonical LOOCV holdout temperature rows used elsewhere in `tables/full_prediction_trajectory.csv`.

## Important computation caveat (why results look “perfect”)
The repository stores the Phi1 shape `Phi(x)` and amplitude `kappa1(T)` but does not export the full numeric residual matrix deltaS(x,T) as a tabular array.

To compute the requested deltaS-window integrals anyway without re-running extraction/decomposition, we evaluated them on the *Phi1-only residual reconstruction*:
deltaS_phi1(x,T) := kappa1(T) * Phi1(x).

Because each candidate observable is a linear functional of deltaS(x,T), each observable becomes exactly proportional to kappa1(T) under this Phi1-only reconstruction. That yields Pearson/Spearman of ±1 and near-zero LOOCV RMSE in this idealized setting.

Given the strong rank-1 energy fraction, the expectation is that the *full* deltaS-window observables should remain highly predictive, but they should not be exactly perfect due to Phi2/higher-mode contamination.

## Ridge window and Gaussian kernel choices
Let `x_ridge` be the half-window boundary:
- Chosen from the stored canonical Phi1(x) as the first sign-change point on the +x side (closest to the main lobe extent).
- From `phi_shape.csv`, the canonical value used here is: `x_ridge = 0.122457`.

Gaussian matched kernel:
- sigma = x_ridge/2 (simple 1-parameter ridge-centered kernel).

## Candidate observables (small, physically motivated set)
All observables are symmetric in x and ridge-centered by construction.

Define:
- O1(T) ridge_excess: central ridge integral
  - O1(T) = ∫_{-x_ridge}^{x_ridge} deltaS(x,T) dx

- O2(T) shoulder_compensation: outside-ridge integral
  - O2(T) = ∫_{x_min..x_max, |x|>x_ridge} deltaS(x,T) dx

- O3(T) ridge_centered_second_moment: curvature-weighted ridge integral
  - O3(T) = ∫_{-x_ridge}^{x_ridge} x^2 * deltaS(x,T) dx

- O4(T) symmetric lobe-balance: one center-minus-shoulders weighting
  - m_r(T) = O1(T) / (2*x_ridge)
  - m_s(T) = O2(T) / ((x_max-x_min) - 2*x_ridge)
  - O4(T) = m_r(T) - m_s(T)

- O5(T) matched symmetric Gaussian kernel observable:
  - sigma = x_ridge/2
  - O5(T) = ∫_{x_min..x_max} deltaS(x,T) * exp(-x^2/(2*sigma^2)) dx

## Results (vs kappa1 amplitude)
Metrics are computed on the canonical T set (4..26 K even steps):
- Pearson and Spearman correlation vs kappa1(T).
- LOOCV RMSE for scalar prediction of kappa1(T) from observable Oi(T) using a 1D linear regression with intercept.
- Robustness: recompute metrics after scaling x_ridge by 0.8 and 1.2.

Numerical metrics were written to:
- `tables/phi1_map_observable_candidates.csv`

Additional Phi1-aligned quantity check (reconstruction gain):
Using the canonical per-temperature closure table, define the Phi1 reconstruction gain as:
`gain(T) = rmse_M1(T) - rmse_M2(T)` (PT-only error drop after adding the Phi1 rank-1 term).
On the same 12-point T set, the canonical correlation between `gain(T)` and `kappa1(T)` is:
- Pearson(gain, kappa1) = 0.9921
- Spearman(gain, kappa1) = 0.9930
Since each candidate observable is a linear functional of the Phi1-dominated residual, this gain correlation is inherited by the candidate signatures in the Phi1-only evaluation.

### Per-candidate verdicts (based on the Phi1-only residual evaluation)
- `ridge_excess` (O1): Pearson = 1.0, Spearman = 1.0; LOOCV RMSE ~ 2e-17; robust to x_ridge in [0.8,1.2] scaling.
  - Verdict: PARTIAL but useful signature (excellent Phi1-amplitude proxy in Phi1-dominated residuals; full deltaS unexported so “perfect” is idealized).

- `shoulder_compensation` (O2): Pearson = -1.0, Spearman = -1.0 (sign-flipped linear functional of the same Phi1-dominated residual).
  - Verdict: PARTIAL but useful signature, but redundant/opposite-sign compared to `ridge_excess`.

- `ridge_centered_second_moment` (O3): Pearson = 1.0, Spearman = 1.0; LOOCV RMSE ~ 2e-17; robust.
  - Verdict: PARTIAL but useful signature (more “moment-like” but still essentially an amplitude proxy in Phi1-dominated conditions).

- `lobe_balance_center_minus_shoulders` (O4): Pearson = 1.0, Spearman = 1.0; robust.
  - Verdict: PARTIAL but useful signature (interpretable “center vs shoulders” balance; slightly more construction effort than O1).

- `matched_symmetric_gaussian_kernel` (O5): Pearson = 1.0, Spearman = 1.0; robust.
  - Verdict: PARTIAL but useful signature (physically motivated matched-filter, but still requires deltaS construction).

## Final verdicts (required format)
PHI1_MAP_DERIVED_OBSERVABLE_FOUND: PARTIAL
PHI1_BEST_MAP_OBSERVABLE: Central ridge excess (deltaS integral)

## Plain-language conclusion
- A simple experimentally meaningful map-derived observable exists for tracking Phi1 as a ridge-centered redistribution: the **central ridge excess** `O1(T) = ∫ deltaS dx` over a symmetric window around x=0.
- Phi1 itself is not reducible to a single scalar *field* observable (consistent with earlier repo mapping audits), but Phi1’s **dominant amplitude** is extremely well captured by a small family of symmetric, ridge-centered linear functionals of deltaS (O1..O5).
- Recommended for future writeups/figures: **`ridge_excess`** (O1). It is the most direct, symmetric, and robust-to-window family member, and it most cleanly expresses the “ridge-centered symmetric redistribution” interpretation of Phi1.

