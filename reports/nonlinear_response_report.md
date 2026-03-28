# Nonlinear response test (Agent 19H)

## Sources
- Alignment: `run_2026_03_10_112659_alignment_audit`
- Full scaling: `run_2026_03_12_234016_switching_full_scaling_collapse`
- PT matrix: `run_2026_03_24_212033_switching_barrier_distribution_from_map`
- Canonical window: decomposition uses T <= 30 K for SVD; fits below use **all** valid rows.

## Model
On the **x-grid** (same as residual decomposition), fit per temperature:
`deltaS(x) ≈ a1(T)*S_CDF(x) + a2(T)*S_CDF(x)^2`, with `S_CDF` interpolated from the current-axis backbone.
Baselines: **rank-1** `kappa1*Phi1`, **rank-2** LSQ on `[Phi1, Phi2]` (same as Agent 19E).
Also report **linear** `deltaS ≈ a_lin * S_CDF` (single term) to isolate the quadratic piece.

## Mean RMSE (finite rows)
| Model | mean RMSE |
| --- | --- |
| kappa1*Phi1 (rank-1) | 0.008913 |
| rank-2 Phi1+Phi2 | 0.005668 |
| nonlinear a1*S_CDF + a2*S_CDF^2 | 0.031210 |
| linear a*S_CDF only | 0.034925 |

## Diagnostics
- Improvement nonlinear vs linear-in-S_CDF only: **0.003715** (mean RMSE); **0.4168** relative to mean rank-1 RMSE
- Improvement rank-2 vs rank-1: **0.003246** (mean RMSE)
- Mean |a2| relative to |a1|/Speak scale: **1.411472**
- Mean |cos(unit Phi2, unit pred_nl)|: **0.3350**; vs rank-2 recon: **0.1754**
- Quadratic helps vs linear CDF (mean RMSE ratio > 1.03): **YES**
- Phi2-like alignment heuristic (cos pred_nl vs Phi2): **YES**

## Task 3 — Does the nonlinear expansion reproduce Phi2-like structure?
Mean |cos(unit Phi2, unit NL prediction)| is **~0.34**, below a **0.55** “strong alignment” cutoff and only modestly above the cosine of Phi2 with the rank-2 reconstruction (**~0.18**). So the NL backbone fit does **not** robustly reproduce a Phi2-like shape, even where a quadratic term helps versus linear-in-S_CDF.

## Final verdict
| Question | Answer |
| --- | --- |
| RESIDUAL_IS_NONLINEAR_RESPONSE | **NO** |
| NONLINEAR_MODEL_COMPETES_WITH_RANK2 | **NO** |

Interpretation: **RESIDUAL_IS_NONLINEAR_RESPONSE** = YES if either (A) mean RMSE(NL) is within **5%** of mean RMSE(rank-2), or (B) quadratic clearly beats linear-in-S_CDF (ratio > 1.03, gain ≥1% of mean rank-1 RMSE) *and* mean RMSE(NL) is within **5%** of mean RMSE(rank-1) (same backbone explains the strip).
**NONLINEAR_MODEL_COMPETES_WITH_RANK2** = YES if mean RMSE(NL) <= **1.05** * mean RMSE(rank-2).
**Phi2-like structure (heuristic):** mean |cos(unit Phi2, unit pred_nl)| = **0.3350**; rank-2 reconstruction **0.1754**; alignment flag **YES** (|cos|≥0.55 or ≥ rank-2 recon + 0.05).
