# Adversarial Observable Report

## Scope

Existing aligned datasets only were used. No raw recomputation and no new base observables were created.

- Source A-table: `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/tables/composite_observables_table.csv`
- Source R-table: `results/cross_experiment/runs/run_2026_03_16_173307_R_X_reconciliation_analysis/tables/R_X_canonical_overlap_table.csv`

Baseline: `X = I_peak/(w*S_peak)`

## Baseline Metrics (X)

| Metric | Value |
| --- | ---: |
| Pearson(A, X) | 0.9751 |
| Spearman(A, X) | 0.9868 |
| beta in `A ~ X^beta` | 0.6801 |
| R^2 in `A ~ X^beta` | 0.9609 |
| Peak offset `|T_peak(X)-T_peak(A)|` (K) | 0 |
| Pearson(R, X) | 0.9112 |
| Spearman(R, X) | 1.0000 |

## Best-performing Alternatives

| Candidate | Family | Pearson(A,Y) | R^2 | RMSE(log-resid) | Peak offset (K) | Pearson(R,Y) | Stability |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| N2: X^1.5 | nonlinear_pow | 0.9619 | 0.9609 | 0.0914 | 0 | 0.9400 | 0.0029 |
| N2: X^1.2 | nonlinear_pow | 0.9712 | 0.9609 | 0.0914 | 0 | 0.9237 | 0.0014 |
| H3: X+0.2(I/w) | hybrid3 | 0.9747 | 0.9611 | 0.0912 | 0 | 0.9124 | 0.0008 |
| N2: X^0.8 | nonlinear_pow | 0.9768 | 0.9609 | 0.0914 | 0 | 0.8973 | 0.0005 |
| R1: (I+0.5w)/(S+0.01w) | ratio1 | 0.9518 | 0.9266 | 0.1252 | 0 | 0.8565 | 0.0002 |
| H2: (I+0.5w)/(S+0.01w)+0.5(I/w) | hybrid2 | 0.9514 | 0.9261 | 0.1257 | 0 | 0.8572 | 0.0002 |

## Full Candidate Comparison vs X

| Candidate | Family | d|Pearson(A)| vs X | dR^2 vs X | dRMSE(log) vs X | dPeak(K) vs X | d|Pearson(R)| vs X | Stability |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| X = I/(w*S) | baseline | +0.0000 | +0.0000 | +0.0000 | +0 | +0.0000 | 0.0009 |
| L: 1*In + 1*wn + 1*Sn | linear | -0.0571 | -0.1117 | +0.0881 | +0 | -0.1502 | 0.0005 |
| L: 1*In + 1*wn + -1*Sn | linear | -0.2895 | -0.4255 | +0.2236 | +0 | -0.4937 | 0.0000 |
| L: 1*In + -1*wn + 1*Sn | linear | -0.0340 | -0.1222 | +0.0942 | +0 | -0.4118 | 0.0021 |
| R1: (I+0.5w)/(S+0.01w) | ratio1 | -0.0233 | -0.0344 | +0.0339 | +0 | -0.0547 | 0.0002 |
| R1: (I+1w)/(S+0.02w) | ratio1 | -0.0422 | -0.0551 | +0.0504 | +0 | -0.0582 | 0.0001 |
| R2: I/(w+5 S) | ratio2 | -0.2331 | -0.3430 | +0.1943 | +0 | -0.5338 | 0.0000 |
| R2: I/(w+10 S) | ratio2 | -0.1948 | -0.2845 | +0.1715 | +0 | -0.4549 | 0.0000 |
| R3: I/w + 2 S | ratio3 | -0.8682 | -0.9473 | +0.3676 | +0 | -0.8712 | 0.0000 |
| R3: I/w + 4 S | ratio3 | -0.2963 | -0.5559 | +0.2651 | +0 | -0.7664 | 0.0001 |
| N1: log(X) | nonlinear_log | -0.0168 | -0.0290 | +0.0292 | +0 | -0.0820 | 0.0002 |
| N2: X^0.8 | nonlinear_pow | +0.0017 | +0.0000 | +0.0000 | +0 | -0.0139 | 0.0005 |
| N2: X^1.2 | nonlinear_pow | -0.0039 | +0.0000 | +0.0000 | +0 | +0.0125 | 0.0014 |
| N2: X^1.5 | nonlinear_pow | -0.0132 | +0.0000 | +0.0000 | +0 | +0.0288 | 0.0029 |
| N3: exp(-kX), k=1/mean(X) | nonlinear_exp | -0.0071 | -0.0227 | +0.0235 | +0 | -0.0999 | 0.0013 |
| H1: I/(w+5S)+1.5S | hybrid1 | -0.5369 | -0.7497 | +0.3191 | +0 | -0.7481 | 0.0001 |
| H2: (I+0.5w)/(S+0.01w)+0.5(I/w) | hybrid2 | -0.0237 | -0.0349 | +0.0343 | +0 | -0.0540 | 0.0002 |
| H3: X+0.2(I/w) | hybrid3 | -0.0003 | +0.0001 | -0.0002 | +0 | +0.0013 | 0.0008 |

## Where Alternatives Fail

### Alignment
- In this focused adversarial set, top candidates preserve `0 K` peak alignment with `A(T)`, so alignment is not the main failure mode.
- Alignment alone is therefore insufficient to declare a replacement; cross-target consistency is the discriminating criterion.

### Aging consistency
- Candidates strong on `A(T)` often lose performance on canonical aging `R(T)` overlap.
- The `R(T)` overlap has only 4 temperatures, so weak constructions become unstable quickly.

### Stability
- Small perturbation sensitivity is generally low for monotonic reparameterizations of `X`.
- More complex additive/ratio forms do not deliver proportional gains relative to their extra tuning freedom.

### Interpretability
- Linear normalized sums and multi-term hybrids are tunable but less mechanistic than the compact multiplicative form of `X`.

## Final Adversarial Verdict

Alternatives that matched operational thresholds:
- `N2: X^1.2`
- `H3: X+0.2(I/w)`
- `N2: X^0.8`
These are tradeoff-equivalent, not clearly superior across all criteria.

## Method Notes
- Candidate space was compact by design (non-brute-force, physically simple forms).
- Scaling model: `A(T) ~ Y(T)^beta` via log-log regression with residual diagnostics.
- Stability score: worst local change under small perturbations of `Y` (scale and shift, 2% level) in `|Pearson(A)|`, `|Pearson(R)|`, and `R^2`.

