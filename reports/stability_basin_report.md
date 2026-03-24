# Stability Basin Report for \(X = I_{peak}/(width_I \cdot S_{peak})\)

## Input and provenance

- Relevant run directory (composite observables source): `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/`
- Scan-ready aligned table used for the exponent grid evaluation: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`
- This report consolidates the already produced 27-point exponent-neighborhood scan (no recomputation in this update, no run data modified).

## A. Summary of scan

We analyzed the local exponent family
\[
Y(a,b,c)=\frac{I_{peak}^a}{width_I^b \, S_{peak}^c},
\quad a,b,c \in \{0.5,1,1.5\}
\]
for all 27 combinations.

Metrics used:

- **Pearson(A,Y):** linear association between \(A(T)\) and \(Y(T)\).
- **Spearman(A,Y):** rank-monotonic association.
- **Peak alignment \(\Delta T_{peak}\):** \(T_{peak}(Y)-T_{peak}(A)\) in K (0 is ideal).
- **LOO robustness:** leave-one-temperature-out minima (`loo_min_pearson`, `loo_min_spearman`), plus spread diagnostics.

## B. Top candidates

### B1. Full 27-point scan table

The complete neighborhood scan is listed below in lexicographic \((a,b,c)\) order.  
`rank` is the global performance rank used in this report.

| a | b | c | Pearson | Spearman | \(\Delta T_{peak}\) (K) | LOO min Pearson | LOO min Spearman | rank |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.5 | 0.5 | 0.5 | 0.97473 | 0.98681 | 0 | 0.96990 | 0.98352 | 8 |
| 0.5 | 0.5 | 1.0 | 0.98152 | 0.98681 | 0 | 0.97854 | 0.98352 | 5 |
| 0.5 | 0.5 | 1.5 | 0.97172 | 0.98681 | 0 | 0.96720 | 0.98352 | 9 |
| 0.5 | 1.0 | 0.5 | 0.92315 | 0.94286 | 4 | 0.91073 | 0.92857 | 22 |
| 0.5 | 1.0 | 1.0 | 0.94399 | 0.96484 | 2 | 0.93328 | 0.95604 | 18 |
| 0.5 | 1.0 | 1.5 | 0.94102 | 0.98242 | 2 | 0.93024 | 0.97802 | 15 |
| 0.5 | 1.5 | 0.5 | 0.85786 | 0.92967 | 4 | 0.83274 | 0.91209 | 26 |
| 0.5 | 1.5 | 1.0 | 0.88764 | 0.95165 | 4 | 0.86983 | 0.93956 | 25 |
| 0.5 | 1.5 | 1.5 | 0.89224 | 0.95165 | 4 | 0.87213 | 0.93956 | 24 |
| 1.0 | 0.5 | 0.5 | 0.95264 | 0.97363 | 0 | 0.94417 | 0.96703 | 14 |
| 1.0 | 0.5 | 1.0 | 0.98736 | 1.00000 | 0 | 0.98567 | 1.00000 | 1 |
| 1.0 | 0.5 | 1.5 | 0.98181 | 1.00000 | 0 | 0.97903 | 1.00000 | 2 |
| 1.0 | 1.0 | 0.5 | 0.95312 | 0.96923 | 2 | 0.94458 | 0.96154 | 16 |
| 1.0 | 1.0 | 1.0 | 0.97506 | 0.98681 | 0 | 0.97164 | 0.98352 | 7 |
| 1.0 | 1.0 | 1.5 | 0.96896 | 0.98681 | 0 | 0.96495 | 0.98352 | 10 |
| 1.0 | 1.5 | 0.5 | 0.90874 | 0.92527 | 2 | 0.89404 | 0.90659 | 23 |
| 1.0 | 1.5 | 1.0 | 0.93494 | 0.95604 | 2 | 0.92271 | 0.94505 | 19 |
| 1.0 | 1.5 | 1.5 | 0.93412 | 0.98242 | 2 | 0.92163 | 0.97802 | 17 |
| 1.5 | 0.5 | 0.5 | 0.84248 | 0.85495 | 0 | 0.80975 | 0.81868 | 27 |
| 1.5 | 0.5 | 1.0 | 0.96309 | 0.98242 | 0 | 0.95798 | 0.97802 | 13 |
| 1.5 | 0.5 | 1.5 | 0.97500 | 0.99560 | 0 | 0.97200 | 0.99451 | 4 |
| 1.5 | 1.0 | 0.5 | 0.92858 | 0.93846 | 0 | 0.91455 | 0.92308 | 20 |
| 1.5 | 1.0 | 1.0 | 0.98070 | 0.98681 | 0 | 0.97763 | 0.98352 | 6 |
| 1.5 | 1.0 | 1.5 | 0.98025 | 0.99560 | 0 | 0.97699 | 0.99451 | 3 |
| 1.5 | 1.5 | 0.5 | 0.92948 | 0.95165 | 2 | 0.91745 | 0.93956 | 21 |
| 1.5 | 1.5 | 1.0 | 0.96364 | 0.98681 | 0 | 0.95742 | 0.98352 | 11 |
| 1.5 | 1.5 | 1.5 | 0.96187 | 0.98681 | 0 | 0.95789 | 0.98352 | 12 |

### B2. Top candidates

Top 5 (ranked by \(|\)Spearman\(|\), then \(|\)Pearson\(|\), then \(|\Delta T_{peak}|\), then LOO floor):

| Rank | a | b | c | Pearson | Spearman | \(\Delta T_{peak}\) (K) | LOO min Pearson | LOO min Spearman |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0 | 0.5 | 1.0 | 0.98736 | 1.00000 | 0 | 0.98567 | 1.00000 |
| 2 | 1.0 | 0.5 | 1.5 | 0.98181 | 1.00000 | 0 | 0.97903 | 1.00000 |
| 3 | 1.5 | 1.0 | 1.5 | 0.98025 | 0.99560 | 0 | 0.97699 | 0.99451 |
| 4 | 1.5 | 0.5 | 1.5 | 0.97500 | 0.99560 | 0 | 0.97200 | 0.99451 |
| 5 | 0.5 | 0.5 | 1.0 | 0.98152 | 0.98681 | 0 | 0.97854 | 0.98352 |

## C. Position of \(X\) \((a,b,c)=(1,1,1)\)

- \(X\) corresponds to \((1,1,1)\): Pearson `0.97506`, Spearman `0.98681`, \(\Delta T_{peak}=0\) K, LOO minima `(0.97164, 0.98352)`.
- Rank of \((1,1,1)\) in the 27-combination neighborhood: **7/27**.
- Comparison to top candidate \((1,0.5,1)\):
  - Pearson gap: `0.98736 - 0.97506 = 0.01230`
  - Spearman gap: `1.00000 - 0.98681 = 0.01319`
  - Peak alignment: both `0 K`
  - Robustness remains high for both.

## D. Stability basin analysis

- The response is **not sharply peaked** at a single exponent triplet.
- A broad high-performance region exists around:
  - \(b \in [0.5, 1]\),
  - \(c \in [1, 1.5]\),
  - \(a \in [0.5, 1.5]\) (with best concentration near \(a=1\) to \(1.5\)).
- Many nearby candidates retain zero peak offset and very high LOO floors, indicating basin-like stability.
- Clear degradation appears when denominator weighting is too strong (notably \(b=1.5\) with low \(c\)), where correlations drop and peak shifts (\(+2\) to \(+4\) K) appear.

## E. Dimensional constraints

If \(I_{peak}\) and \(width_I\) both carry current units, dimensional consistency requires \(a \approx b\) (so \(I^a/width^b\) is unit-neutral up to \(S\), which is dimensionless here).

Dimensionless-grid candidates (\(a=b\)) include:

- \(a=b=0.5\): \((0.5,0.5,1)\) is best in this subset (Pearson `0.98152`, Spearman `0.98681`, \(\Delta T_{peak}=0\), LOO min Pearson `0.97854`).
- \(a=b=1\): canonical \(X=(1,1,1)\) remains strong and near-optimal.
- \(a=b=1.5\): \((1.5,1.5,1)\) and \((1.5,1.5,1.5)\) remain robust but with weaker Pearson than the best \(a=b=0.5\) and \(a=b=1\) options.

## F. Interpretation

- \(X\) is **not** an isolated optimum in this local exponent neighborhood.
- \(X\) lies inside a **robust stability basin** with many nearby high-performing choices.
- Nearby exponent choices can modestly improve correlation metrics, but do not change the qualitative alignment picture.
- The canonical \((1,1,1)\) form preserves zero peak-offset and strong LOO robustness, supporting it as a defensible central choice.

## G. Conclusion (max 5 lines)

The exponent-neighborhood scan shows basin behavior, not a single sharp optimum.  
\(X=(1,1,1)\) is near-optimal (\(7/27\)) with strong Pearson/Spearman, perfect peak alignment, and robust LOO floors.  
Top alternatives improve correlation slightly but do not alter the core physical alignment outcome.  
Dimensionally consistent candidates (\(a \approx b\)) also populate the high-performance region.  
Therefore, \(X\) is well-supported as a robust, publication-defensible activation coordinate.
