# Functional Form Scan Report

## Scope and constraints
- Reused aligned table only: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`.
- Reused aging R(T) where available: `results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv` (`R_tau_FM_over_tau_dip`).
- No raw data recomputation and no new observables were created.
- Existing scans reused first: 27-point local basin + 121-point constrained basin.

## Scan design (coarse-to-fine)
- Family: `Y_{a,b,c}(T) = I_peak(T)^a / (w(T)^b * S_peak(T)^c)`.
- Domain: `a,b,c in [0.5, 2]`.
- Coarse: 343 points (`step=0.25`), reused=27, newly computed=316.
- Refine: around top 8 seeds (`delta=+-0.15`, `step=0.05`), newly computed=1423.
- Total unique candidates (basic metrics): 1766.

## Top candidates (ranked)
| Rank | a | b | c | Pearson(A,Y) | Spearman(A,Y) | beta | power R^2 | |DeltaT| K | corr(Y,R) Pearson | LOO min Pearson | perturb sens |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.95 | 0.55 | 1.10 | 0.988244 | 1.000000 | 0.7253 | 0.975098 | 0.00 | 0.862870 | 0.986523 | 0.000186 |
| 2 | 0.95 | 0.55 | 1.05 | 0.988378 | 1.000000 | 0.7581 | 0.974495 | 0.00 | 0.863375 | 0.986735 | 0.000153 |
| 3 | 0.90 | 0.55 | 1.05 | 0.988381 | 1.000000 | 0.7524 | 0.974821 | 0.00 | 0.862839 | 0.986611 | 0.000226 |
| 4 | 0.90 | 0.55 | 1.00 | 0.988420 | 1.000000 | 0.7878 | 0.974234 | 0.00 | 0.863527 | 0.986702 | 0.000205 |
| 5 | 0.95 | 0.55 | 1.00 | 0.988285 | 1.000000 | 0.7940 | 0.973710 | 0.00 | 0.864075 | 0.986695 | 0.000240 |
| 6 | 0.85 | 0.55 | 1.00 | 0.988257 | 1.000000 | 0.7815 | 0.974269 | 0.00 | 0.862967 | 0.986408 | 0.000356 |
| 7 | 0.90 | 0.55 | 0.95 | 0.988224 | 1.000000 | 0.8266 | 0.973457 | 0.00 | 0.864431 | 0.986532 | 0.000260 |
| 8 | 0.85 | 0.55 | 0.95 | 0.988193 | 1.000000 | 0.8198 | 0.973678 | 0.00 | 0.863859 | 0.986370 | 0.000330 |
| 9 | 1.00 | 0.55 | 1.05 | 0.988094 | 1.000000 | 0.7638 | 0.973715 | 0.00 | 0.863901 | 0.986463 | 0.000251 |
| 10 | 0.85 | 0.50 | 1.00 | 0.988704 | 1.000000 | 0.7961 | 0.975189 | 0.00 | 0.856103 | 0.987100 | 0.000194 |

## Canonical X = (1,1,1)
- X rank in full scanned set: 1456/1766.
- X basic metrics: Pearson=0.975060, Spearman=0.986810, |DeltaT|=0.00 K, LOO min Pearson=0.971640.
- X scaling/aging/stability: beta=0.6801, power R^2=0.952743, corr(Y,R) Pearson=0.911179 (n=4), perturb sensitivity=0.001681.
- X classification: **in a broad basin**.
- Broad near-best basin size: 1169 candidates.

## Failure modes of alternatives
- Misalignment: `(a,b,c)=(0.50,1.00,0.50)`, |DeltaT|=4.00 K.
- Aging breakdown: `(a,b,c)=(2.00,2.00,0.50)`, corr(Y,R) Pearson=0.825151 (n=4).
- Instability: `(a,b,c)=(2.00,2.00,2.00)`, perturb sensitivity=0.002059, LOO min Pearson=0.933492.
- Degraded scaling: `(a,b,c)=(2.00,2.00,0.50)`, power R^2=0.819261, corr(T,resid)=0.274574.

## Verdict
X is not uniquely preferred; multiple parameterizations are effectively equivalent or better on the scanned criteria.

