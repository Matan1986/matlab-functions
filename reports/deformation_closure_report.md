# Deformation-closure test (Agent 19E)

## Canonical inputs

- **Alignment:** `run_2026_03_10_112659_alignment_audit`
- **Full scaling:** `run_2026_03_12_234016_switching_full_scaling_collapse`
- **PT matrix (CDF reconstruction):** `run_2026_03_24_212033_switching_barrier_distribution_from_map`
- **Canonical window:** T ≤ 30 K (same as residual decomposition pipeline)

Residuals `deltaS` and the common x-grid follow `Switching/analysis/switching_residual_decomposition_analysis.m` (PT-based CDF where available; no barrier PT recomputation).

## 1. Basis identification — Phi2 vs deformation kernels

Define K1(x) = dPhi1/dx, K2(x) = x·Phi1 on the decomposition x-grid. Orthonormalize (K1, K2) for the span projection row.

| Quantity | Value |
| --- | --- |
| corr(Phi2, K1_raw) | −0.886 |
| corr(Phi2, K2_raw) | −0.892 |
| Pearson(Phi2, projection onto span{K1,K2}) | 0.414 (updated when script re-run; see `tables/deformation_basis_projection.csv`) |
| Cosine(Phi2, span{K1,K2}) | 0.414 |
| RMSE(Phi2 − projection onto span) | 0.061 |

**Reading:** Phi2 is strongly linearly related to both elementary deformation directions (derivative and first moment of Phi1), but the **projection residual is not negligible** (RMSE ~0.06 on the shape grid). Phi2 is **not** a pure element of span{K1,K2}; it carries additional structure orthogonal to this deformation plane.

## 2. Per-temperature reconstruction (aligned overlap)

Models on the interpolated residual rows `R(I,x)`:

- **A:** κ1(T)·Phi1 — rank-1 projection fit.
- **B:** κ1·Phi1 + κ2·Phi2 — two-mode algebraic fit with SVD Phi2.
- **C:** a1·Phi1 + b1·K1 + b2·K2 — three-term deformation fit.
- **D:** κ1·Phi1 + β1·K1 + β2·K2 — κ1 fixed to the rank-1 κ(T).
- **SVD rank-2:** row reconstruction from the low-T SVD (matches B when Phi1, Phi2 align with that SVD).

Approximate **mean per-row RMSE** over the 14 temperatures (from `tables/deformation_closure_metrics.csv`):

| Model | Mean RMSE |
| --- | --- |
| A | 0.00891 |
| B | 0.00567 |
| C | 0.00656 |
| D | 0.00755 |
| SVD rank-2 | 0.00567 (≈ B) |

**Reading:** The **algebraic rank-2 model (B) is tighter on average than the deformation triple (C)**. The deformation model still **beats rank-1 alone** on average (C vs A). The constrained model (D) is slightly worse than (C), showing that freezing κ1 while fitting only (β1, β2) leaves measurable mismatch versus the fully free three-term fit.

At **22 K**, rank-1 correlation drops (corr A ≈ 0.75 in the table); both B and C restore higher curve correlation — the “boundary” row is anomalous for rank-1 but is captured similarly by rank-2 and deformation expansions.

## 3. Coefficient physics (qualitative)

From the same table: **κ2(T)** tracks the second SVD amplitude and shows a large swing at the highest T (e.g. 30 K) together with **β1, β2** — consistent with both pictures coupling strongly to the same regime crossover. **β1, β2** are natural candidates for interpreting width/current asymmetry (they load on dPhi1/dx and x·Phi1); **κ2** mixes those effects into a single orthogonal direction and is less directly labeled.

Formal Pearson numbers are left in the CSV columns (`kappa2_fit`, `beta1_fixedKappa`, `beta2_fixedKappa`, `kappa1`, `I_peak_mA`, spreads) for regression review.

## 4. Regime 22–24 K

In the 22–24 K band, **κ2** and **β** coefficients all vary; the rank-1 failure at 22 K is shared. Whether the bend is “cleaner” in β-space than in κ2 is **not** decisive from RMSE alone: deformation coordinates **explain the boundary row** about as well as Phi2, but **do not** remove the need for extra degrees of freedom beyond κ1·Phi1.

## 5. Stability (LOOCV)

Re-run `analysis/run_deformation_closure_agent19e.m` to populate LOOCV metrics in the report tail. The intended comparison is:

- **Phi2 direction:** stability of the second singular vector when one low-T row is removed.
- **Deformation kernels:** stability of K1 = dPhi1/dx when Phi1 is perturbed by LOO — expected to track the high rank-1 energy fraction (~0.96) more tightly than Phi2.

## Final verdict

| Question | Answer |
| --- | --- |
| **PHI2_IS_DEFORMATION_OF_PHI1** | **PARTIAL** — Phi2 is strongly aligned with (K1, K2) but not equivalent; non-negligible orthogonal residual. |
| **DEFORMATION_BASIS_MATCHES_RANK2** | **NO** — mean RMSE (C) > mean RMSE (B); rank-2 SVD/algebraic two-mode fit wins on average. |
| **DEFORMATION_COORDINATES_MORE_PHYSICAL** | **PARTIAL** — β1, β2 map onto explicit geometry (derivative / moment of Phi1); interpretability is higher even where RMSE is slightly worse than (B). |
| **BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE** | **PARTIAL** — 22 K anomaly is visible in both κ2 and (β1, β2); deformation language does not uniquely simplify the bend. |

## Short physical interpretation

The data support a **single dominant residual shape Phi1** plus a **small, structured remainder**. That remainder is **largely expressible** as combinations of **local deformation** of Phi1 (derivative and moment), which is why Phi2 correlates strongly with K1 and K2. However, the **remaining misfit** after projecting Phi2 onto {K1, K2}, together with the **better mean RMSE of the two-mode SVD fit** than the three-term deformation fit, indicates that a **pure “one mode + deformation”** closure is **incomplete**: a **second amplitude κ2(T) along an SVD direction** (or an equivalent two-dimensional subspace) still **adds information** beyond the elementary deformation basis.

**Practical view:** treat **Phi2 as mostly deformation-like** for interpretation, but retain **rank-2 (or subspace) language** for **prediction and RMSE-optimal** reconstruction.

## Artifacts

- `tables/deformation_closure_metrics.csv`
- `tables/deformation_basis_projection.csv`
- `figures/deformation_vs_rank2_comparison.png`
- `figures/beta_vs_Ipeak.png`
- Driver: `analysis/run_deformation_closure_agent19e.m` (full analysis), `analysis/export_deformation_closure_figs.m` (figures from CSV)
