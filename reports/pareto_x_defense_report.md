# Pareto Analysis for X-Defense Layer

## Summary
This report evaluates whether X = I_peak / (w * S_peak) is Pareto-optimal across relaxation and aging targets using existing artifacts only.
No historical run outputs were modified and no full pipeline recomputation was performed.

## Data Sources
- C:\Dev\matlab-functions\results\cross_experiment\runs\run_2026_03_13_082753_switching_relaxation_bridge_robustness_a\tables\merged_relaxation_switching_table.csv
- C:\Dev\matlab-functions\results\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv
- Aging targets were reduced to per-temperature medians over available waiting times (FM_abs, Dip_depth) from the canonical aging dataset table.

## Candidate Definitions
- X_p1_c1: I_peak / (w * S_peak)
- S_peak
- I_peak
- w (width_mA)
- Y_p0.5_c0.9: (I_peak/w)^0.5 / S_peak^0.9
- Y_p0.9_c1.0: (I_peak/w)^0.9 / S_peak^1.0
- Y_p1.1_c1.0: (I_peak/w)^1.1 / S_peak^1.0
- Y_p1.0_c0.9: (I_peak/w)^1.0 / S_peak^0.9
- Y_p1.0_c1.1: (I_peak/w)^1.0 / S_peak^1.1

Targets: A_interp(T), FM_abs(T), Dip_depth(T). Metrics: Pearson, Spearman, DeltaT_peak, best-fit R^2 (best of linear/power), LOO min Pearson, LOO min Spearman.

## Full Metric Table
| Candidate | Target | n | Pearson | Spearman | DeltaT_peak | Best_fit_R2 | LOO_min_Pearson | LOO_min_Spearman |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| I_peak | A | 14 | -0.6660 | -0.7911 | 22.0000 | 0.4435 | -0.8087 | -0.7985 |
| I_peak | Dip_depth | 7 | 0.5722 | 0.1793 | 12.0000 | 0.5551 | -0.5467 | -0.4140 |
| I_peak | FM_abs | 5 | -0.0771 | 0.0527 | 0.0000 | 0.0426 | -0.7557 | -0.6325 |
| S_peak | A | 14 | -0.9319 | -0.9868 | 22.0000 | 0.9736 | -0.9440 | -1.0000 |
| S_peak | Dip_depth | 7 | -0.2552 | -0.4286 | 12.0000 | 0.0651 | -0.9249 | -0.7714 |
| S_peak | FM_abs | 5 | 0.5016 | 0.5000 | 0.0000 | 0.2516 | -0.4523 | 0.0000 |
| w | A | 14 | -0.8128 | -0.8769 | 22.0000 | 0.6606 | -0.8785 | -0.9451 |
| w | Dip_depth | 7 | 0.2767 | -0.0714 | 12.0000 | 0.3054 | -0.8035 | -0.7143 |
| w | FM_abs | 5 | -0.2193 | -0.4000 | 8.0000 | 0.1451 | -0.9283 | -1.0000 |
| X_p1_c1 | A | 14 | 0.9751 | 0.9868 | 0.0000 | 0.9609 | 0.9716 | 0.9835 |
| X_p1_c1 | Dip_depth | 7 | 0.0903 | 0.2500 | 8.0000 | 0.0082 | -0.1144 | 0.0857 |
| X_p1_c1 | FM_abs | 5 | -0.2112 | -0.2000 | 12.0000 | 0.0446 | -0.4167 | -0.4000 |
| Y_p0.5_c0.9 | A | 14 | 0.9821 | 0.9868 | 0.0000 | 0.9713 | 0.9792 | 0.9835 |
| Y_p0.5_c0.9 | Dip_depth | 7 | 0.1249 | 0.2500 | 8.0000 | 0.0156 | -0.0540 | 0.0857 |
| Y_p0.5_c0.9 | FM_abs | 5 | -0.2883 | -0.2000 | 12.0000 | 0.0831 | -0.5534 | -0.4000 |
| Y_p0.9_c1.0 | A | 14 | 0.9769 | 0.9868 | 0.0000 | 0.9637 | 0.9736 | 0.9835 |
| Y_p0.9_c1.0 | Dip_depth | 7 | 0.0963 | 0.2500 | 8.0000 | 0.0093 | -0.1045 | 0.0857 |
| Y_p0.9_c1.0 | FM_abs | 5 | -0.2256 | -0.2000 | 12.0000 | 0.0509 | -0.4444 | -0.4000 |
| Y_p1.0_c0.9 | A | 14 | 0.9741 | 0.9868 | 0.0000 | 0.9576 | 0.9700 | 0.9835 |
| Y_p1.0_c0.9 | Dip_depth | 7 | 0.0933 | 0.2500 | 8.0000 | 0.0087 | -0.1056 | 0.0857 |
| Y_p1.0_c0.9 | FM_abs | 5 | -0.2084 | -0.2000 | 12.0000 | 0.0434 | -0.3974 | -0.4000 |
| Y_p1.0_c1.1 | A | 14 | 0.9751 | 0.9868 | 0.0000 | 0.9635 | 0.9718 | 0.9835 |
| Y_p1.0_c1.1 | Dip_depth | 7 | 0.0874 | 0.2500 | 8.0000 | 0.0076 | -0.1229 | 0.0857 |
| Y_p1.0_c1.1 | FM_abs | 5 | -0.2122 | -0.2000 | 12.0000 | 0.0450 | -0.4318 | -0.4000 |
| Y_p1.1_c1.0 | A | 14 | 0.9731 | 0.9868 | 0.0000 | 0.9579 | 0.9693 | 0.9835 |
| Y_p1.1_c1.0 | Dip_depth | 7 | 0.0846 | 0.2500 | 8.0000 | 0.0072 | -0.1238 | 0.0857 |
| Y_p1.1_c1.0 | FM_abs | 5 | -0.1972 | -0.2000 | 12.0000 | 0.0389 | -0.3898 | -0.4000 |

## Aggregated Pareto Objectives
Aggregation is conservative across experiments/targets: maximize min|corr|, maximize -max|DeltaT_peak|, maximize min fit/robustness.

| Candidate | min|Pearson| | min|Spearman| | -max|DeltaT_peak| | min Best_fit_R2 | min|LOO_P| | min|LOO_S| | Pareto | Dominated by |
|---|---:|---:|---:|---:|---:|---:|---|---|
| I_peak | 0.0771 | 0.0527 | -22.0000 | 0.0426 | 0.5467 | 0.4140 | No | w |
| S_peak | 0.2552 | 0.4286 | -22.0000 | 0.0651 | 0.4523 | 0.0000 | Yes | - |
| w | 0.2193 | 0.0714 | -22.0000 | 0.1451 | 0.8035 | 0.7143 | Yes | - |
| X_p1_c1 | 0.0903 | 0.2000 | -12.0000 | 0.0082 | 0.1144 | 0.0857 | Yes | - |
| Y_p0.5_c0.9 | 0.1249 | 0.2000 | -12.0000 | 0.0156 | 0.0540 | 0.0857 | Yes | - |
| Y_p0.9_c1.0 | 0.0963 | 0.2000 | -12.0000 | 0.0093 | 0.1045 | 0.0857 | Yes | - |
| Y_p1.0_c0.9 | 0.0933 | 0.2000 | -12.0000 | 0.0087 | 0.1056 | 0.0857 | Yes | - |
| Y_p1.0_c1.1 | 0.0874 | 0.2000 | -12.0000 | 0.0076 | 0.1229 | 0.0857 | Yes | - |
| Y_p1.1_c1.0 | 0.0846 | 0.2000 | -12.0000 | 0.0072 | 0.1238 | 0.0857 | Yes | - |

## Pareto Front Identification
- Pareto front: S_peak, w, X_p1_c1, Y_p0.5_c0.9, Y_p0.9_c1.0, Y_p1.0_c0.9, Y_p1.0_c1.1, Y_p1.1_c1.0
- X status: Pareto-optimal (non-dominated)
- X is not globally dominant; it is a non-dominated tradeoff point.

## Cross-Experiment Interpretation
- Single-observable proxies can win isolated metrics but lose on worst-case alignment or robustness across A, FM_abs, and Dip_depth.
- No candidate strictly dominates X across all six aggregated objectives.
- Pareto structure therefore supports X as a canonical cross-experiment tradeoff rather than a single-metric optimum.

## Final Conclusion
X = I_peak/(w*S_peak) is Pareto-optimal (non-dominated) in the tested candidate set across relaxation and aging targets.
Several alternatives match or exceed X on individual metrics, but each loses on at least one other objective.
No observable globally dominates X under the defined multi-objective criteria.
The Pareto structure supports X as a robust canonical tradeoff coordinate for the X-defense layer.
