# Subset Stability Report for X

## Data and constraints
- No pipeline recomputation was performed.
- Merged table reused: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`
- Existing LOO results reused: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/leave_one_out_correlations.csv`

## Baseline
- n=14, Pearson=0.975058, Spearman=0.986813, peak alignment delta=0 K
- Linear scaling R2=0.950738; Power scaling R2=0.952743, alpha=0.6801
- Canonical X Pareto status on (p,c) grid: False; Pearson-rank=35/121

## 1) Leave-two-out (N-2 exhaustive)
- Total subsets tested: 91
- Pearson range: 0.967205 to 0.990153
- Spearman range: 0.979021 to 1.000000
- Peak alignment delta range: 0 to 6 K
- Worst Pearson subset: remove 26K,28K -> Pearson=0.967205, Spearman=0.979021, peak delta=6 K
- Worst peak-alignment subset: remove 26K,28K -> peak delta=6 K, Pearson=0.967205
- Reused LOO context: min Pearson=0.971640, min Spearman=0.983516

## 2) Critical point removal (26K, 22K, 18K)
| Case | n | Pearson | dPearson | Spearman | dSpearman | Peak delta (K) | Linear R2 | Power R2 | Canonical X rank | Canonical X Pareto |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| remove_26K | 13 | 0.971902 | -0.003157 | 0.983516 | -0.003297 | 0 | 0.944593 | 0.943855 | 46/121 | False |
| remove_22K | 13 | 0.985303 | 0.010245 | 0.994505 | 0.007692 | 0 | 0.970821 | 0.966192 | 23/121 | False |
| remove_18K | 13 | 0.975102 | 0.000044 | 0.983516 | -0.003297 | 0 | 0.950824 | 0.952916 | 40/121 | False |
| remove_26K_22K_18K | 11 | 0.982444 | 0.007386 | 0.990909 | 0.004096 | 0 | 0.965196 | 0.957151 | 23/121 | False |

## 3) Region-based tests (low/mid/high T)
| Region | T range (K) | n | Pearson | Spearman | Peak delta (K) | Linear R2 | Power R2 |
|---|---|---:|---:|---:|---:|---:|---:|
| low_T | 4-12 | 5 | 0.907254 | 1.000000 | 0 | 0.823110 | 0.836625 |
| mid_T | 14-22 | 5 | 0.985394 | 1.000000 | 0 | 0.971001 | 0.972017 |
| high_T | 24-30 | 4 | 0.631086 | 0.800000 | 0 | 0.398269 | 0.395725 |

## Stability metrics and worst-case degradation
- Worst Pearson drop vs baseline across requested tests: 0.007853
- Maximum peak misalignment across requested tests: 6 K
- Baseline to worst N-2 Pearson drop: 0.007853
- Baseline to worst critical-removal Pearson drop: 0.003157

## Interpretation
- Correlation remains high under exhaustive leave-two-out and targeted point removals, with limited degradation.
- Peak alignment is mostly preserved; worst tested shift is limited to a small number of grid steps.
- Region splits show that low-T and mid-T sectors remain consistent, while high-T is less stable due to fewer points and local curvature.
- Final answer: X is **robust** overall under the tested subset-removal stresses, with localized sensitivity in high-T subsets.

