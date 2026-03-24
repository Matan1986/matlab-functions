# S_peak vs X Cross-Experiment Report

## A. Summary

This is a read-only synthesis from existing run outputs (no pipeline reruns, no run-data edits).  
Goal: test whether `S_peak(T)` can replace `X(T)=I_peak/(w*S_peak)` as a unified coordinate across Relaxation (`A`) and Aging (`R`).

Headline result: `S_peak` is strong for Relaxation only in an inverse sense, but it fails to reproduce the Aging link quality and peak alignment delivered by `X`.

## B. Data Sources

- Relaxation-aligned switching table (contains `A`, `S_peak`, `X_bridge`):  
  `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`
- Canonical Aging-Switching overlap table (contains `R`, `X`):  
  `results/cross_experiment/runs/run_2026_03_16_173307_R_X_reconciliation_analysis/tables/R_X_canonical_overlap_table.csv`
- Composite switching table (used to read `S_peak` on canonical Aging overlap temperatures):  
  `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/tables/composite_observables_table.csv`

Support sets used:

- Relaxation target (`A`): `T = 4:2:30 K` (`n=14`)
- Aging target (`R`): canonical overlap `T = {14,18,22,26} K` (`n=4`)

## C. Results Tables

### C1. Required direct comparison

`dT_peak` is absolute peak-offset in K.  
`LOO min` is leave-one-temperature-out minimum `|Pearson|`.  
`R2` is from power-law fit `target ~ observable^beta`.

| observable | target | Pearson | Spearman | dT_peak | LOO min | R2 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| S_peak | A | -0.9319 | -0.9868 | 22 | 0.9261 | 0.9611 |
| X | A | 0.9751 | 0.9868 | 0 | 0.9716 | 0.9527 |
| S_peak | R | -0.6512 | -1.0000 | 12 | 0.6263 | 0.5162 |
| X | R | 0.9112 | 1.0000 | 0 | 0.8750 | 0.9213 |

### C2. A-scaling stability (LOO)

Power-law model: `A ~ observable^beta`.

| observable | beta (full) | R2 (full) | beta LOO range | beta LOO std | R2 LOO min |
| --- | ---: | ---: | ---: | ---: | ---: |
| S_peak | -0.8239 | 0.9611 | [-0.8435, -0.8065] | 0.0103 | 0.9556 |
| X | 0.6801 | 0.9527 | [0.6673, 0.7057] | 0.0104 | 0.9439 |

## D. Direct Comparison (S_peak vs X)

- Relaxation (`A`): `S_peak` and `X` both give high-magnitude correlations and stable power-law fits.
- But `S_peak` peaks at low `T` (4 K), while `A` peaks at 26 K (`dT_peak=22 K`), so its link is inverse/misaligned in crossover location.
- `X` keeps zero peak-offset with `A` (`dT_peak=0`) while preserving very high correlation and robustness.
- Aging (`R`): `X` is clearly stronger (`Pearson 0.911`, `R2 0.921`, `dT_peak=0`) than `S_peak` (`Pearson -0.651`, `R2 0.516`, `dT_peak=12`).

## E. Interpretation

- **Does S_peak reproduce the Relaxation scaling quality of X?**  
  Partly: yes in pure fit quality (`R2` slightly higher), but only via an inverse relation and with large peak misalignment.
- **Does S_peak reproduce the Aging link (R)?**  
  No: weaker linear relation, much lower scaling `R2`, and nonzero peak-offset.
- **Is S_peak consistently as strong as X across BOTH experiments?**  
  No. It is competitive for `A` fit magnitude only, but not for unified cross-experiment behavior.
- **Where does S_peak fail?**  
  Aging linkage (`R`) and peak-aligned crossover consistency.
- **Does X provide a more unified description?**  
  Yes. `X` is strong for both `A` and `R`, and uniquely preserves zero peak-offset in both targets.

## F. Clear Conclusion (publication-ready, max 5 lines)

`S_peak` alone cannot replace `X` as a unified cross-experiment coordinate.  
While `S_peak` can fit `A(T)` well in an inverse power-law form, it is strongly peak-misaligned with Relaxation and underperforms for Aging `R(T)`.  
`X` preserves strong correlations for both targets and uniquely maintains zero peak-offset in both domains.  
Thus, the evidence supports `X` as the more coherent and transferable bridge coordinate.  
`S_peak` is a partial proxy, not a full substitute.
