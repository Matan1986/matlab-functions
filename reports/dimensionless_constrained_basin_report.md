# Dimensionless Constrained Basin Report (X-Defense)

## 1) Scope and reused artifacts

This report addresses only the constrained dimensionless family:

`Y(p,c) = (I_peak / w)^p / S_peak^c`

with canonical `X = I_peak / (w*S_peak)` at `(p,c)=(1,1)`.

No historical run data were modified. The scan reused existing aligned observables and existing metric conventions.

### Source artifacts used

- Primary aligned table (A, I_peak, w, S_peak on common T grid):
  - `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`
- Metric conventions reused from prior X-defense analyses:
  - `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan/`
  - `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/`
- New constrained scan run:
  - `results/cross_experiment/runs/run_2026_03_22_091808_dimensionless_constrained_basin_scan/`

## 2) Scan design

- Constraint enforced: only dimensionless coordinates (`a=b`) were scanned.
- Domain: `p,c in [0.5, 1.5]`.
- Resolution: `0.1` step in both axes (`11 x 11 = 121` coordinates).
- Temperatures: 14 points (`4-30 K`, step 2 K).
- Metrics per coordinate:
  - Pearson(A,Y)
  - Spearman(A,Y)
  - Peak alignment `DeltaT_peak = T_peak(Y) - T_peak(A)`
  - LOO robustness (`loo_min_pearson`, `loo_min_spearman`)
  - Descriptive fit quality (`linear_A_from_Y`, `power_A_from_Y`, best `R^2`)

Full machine-readable table:

- `results/cross_experiment/runs/run_2026_03_22_091808_dimensionless_constrained_basin_scan/tables/dimensionless_constrained_scan_full.csv`

## 3) Main empirical results in constrained (p,c) plane

### Top 5 constrained coordinates

| Rank | p | c | Pearson | Spearman | DeltaT_peak (K) | LOO min Pearson | LOO min Spearman | Best fit R^2 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.5 | 0.9 | 0.982084 | 0.986813 | 0 | 0.979164 | 0.983516 | 0.964917 |
| 2 | 0.5 | 0.8 | 0.981947 | 0.986813 | 0 | 0.978977 | 0.983516 | 0.964221 |
| 3 | 0.5 | 1.0 | 0.981524 | 0.986813 | 0 | 0.978540 | 0.983516 | 0.965718 |
| 4 | 0.6 | 0.9 | 0.981101 | 0.986813 | 0 | 0.978093 | 0.983516 | 0.963383 |
| 5 | 0.5 | 0.7 | 0.980923 | 0.986813 | 0 | 0.977729 | 0.983516 | 0.962210 |

### Canonical X position

Canonical `(p,c)=(1,1)`:

- Rank: `35 / 121`
- Pearson: `0.975058`
- Spearman: `0.986813`
- DeltaT_peak: `0 K`
- LOO min Pearson/Spearman: `0.971640 / 0.983516`
- Best fit: `power_A_from_Y`, `R^2 = 0.952743`

Gap vs best constrained point `(0.5,0.9)`:

- Pearson gap: `0.007026`
- Spearman gap: `0.000000`
- Peak alignment gap: `0 K`

### Basin geometry (data summary)

- Points with identical Spearman to canonical (`0.986813`): `88 / 121`.
- Points with zero peak shift: `101 / 121`.
- High-quality points (threshold: Spearman>=0.98, Pearson>=0.97, |DeltaT|<=2, LOO mins strong): `59 / 121`.
- High-quality extent:
  - `p in [0.5, 1.2]`
  - `c in [0.5, 1.5]`

This is a broad basin, not a sharp isolated optimum.

## 4) Required comparisons

### Canonical X vs nearby alternatives

| Coordinate (p,c) | Rank | Pearson | Spearman | DeltaT_peak (K) |
| --- | ---: | ---: | ---: | ---: |
| (0.9, 1.0) | 23 | 0.976870 | 0.986813 | 0 |
| (1.0, 1.0) canonical X | 35 | 0.975058 | 0.986813 | 0 |
| (1.1, 1.0) | 48 | 0.973054 | 0.986813 | 0 |
| (1.0, 0.9) | 43 | 0.974060 | 0.986813 | 0 |
| (1.0, 1.1) | 34 | 0.975115 | 0.986813 | 0 |

Nearby points remain very close in all primary metrics.

### Boundary/edge behavior

- Strong boundary case: `(0.5,0.9)` is rank 1.
- Also strong at `(0.5,1.5)` with Pearson `0.971716`, Spearman `0.986813`, DeltaT `0`.
- Clear degradation at high-p / low-c corner, e.g. `(1.5,0.5)`:
  - Pearson `0.929485`, Spearman `0.951648`, DeltaT `+2 K`.

## 5) Which exponent matters more inside constrained family?

Using global variation across the 2D grid:

- Mean std of |Spearman| when varying `p` at fixed `c`: `0.005152`
- Mean std of |Spearman| when varying `c` at fixed `p`: `0.006719`
- Mean std of |Pearson| when varying `p` at fixed `c`: `0.007353`
- Mean std of |Pearson| when varying `c` at fixed `p`: `0.007002`

Net: sensitivity is mixed, but `c` is slightly more influential overall in ranking behavior (mainly via Spearman/peak-structure changes at low-c boundary).

## 6) Separation of claims

### (a) Empirical performance

The constrained family contains many high-performing coordinates with near-identical monotonic alignment, including canonical X.

### (b) Physical admissibility

Only `a=b` coordinates are dimensionless; this scan enforced that admissibility directly.

### (c) Interpretation

Because performance remains high over a broad admissible basin (not a single tuned point), X is supported as a canonical simple representative of the admissible drive/response class rather than a uniquely optimized formula.

## 7) X-defense conclusion (paper-ready)

Within the dimensionless constrained family `Y(p,c)`, performance forms a broad high-quality basin. Canonical `X=(1,1)` is not the top-ranked point on the dense grid, but it remains inside the robust basin with strong Pearson/Spearman, zero peak offset, and strong LOO floors. Many nearby admissible alternatives are similar, and ranking differences are small relative to the shared monotonic/peak-alignment behavior. The constrained scan therefore strengthens the X-defense claim: `X = I_peak/(w*S_peak)` is a justified canonical choice by simplicity within a broad physically admissible basin, not a fragile tuned optimum.
