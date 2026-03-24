# Observable Combination Survey Report

## Scope and provenance

This report consolidates existing observable-search outputs only. No data were recomputed and no analysis scripts were rerun.

Primary source runs used:

- `results/switching/runs/run_legacy_observable_basis_test`
- `results/switching/runs/run_legacy_second_observable_search`
- `results/switching/runs/run_legacy_second_coordinate_duel`
- `results/switching/runs/run_legacy_XI_Xshape_analysis`
- `results/switching/runs/run_legacy_shape_rank_analysis`
- `results/switching/runs/run_2026_03_10_112659_alignment_audit`
- `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse`
- `results/switching/runs/run_2026_03_13_152008_switching_effective_observables`
- `results/cross_experiment/runs/run_2026_03_10_233449_simple_switching_vs_relaxation_search`
- `results/cross_experiment/runs/run_2026_03_12_004907_switching_relaxation_observable_comparis`
- `results/cross_experiment/runs/run_2026_03_12_081243_relaxation_switching_observable_scan`
- `results/cross_experiment/runs/run_2026_03_13_071713_switching_composite_observable_scan`
- `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a`
- `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis`
- `results/cross_experiment/runs/run_2026_03_13_123230_AX_scaling_temperature_robustness`
- `results/cross_experiment/runs/run_2026_03_16_151513_observable_basis_sufficiency_test`
- `results/cross_experiment/runs/run_2026_03_16_153106_observable_basis_sufficiency_robustness`

## A. Tested observables and combinations

### A1. Base switching observables

- `S_peak`, `I_peak`, `width_I`, `halfwidth_diff_norm`, `asym`
- Effective coordinate: `X = I_peak / (width_I * S_peak)`

### A2. Shape and second-coordinate candidates

- `X_shape`
- `halfwidth_diff_norm`
- `curvature_near_peak`
- `skew_m3`
- Pair tests: `(I_peak, X_shape)`, `(I_peak, width_I)`, `(X_shape, width_I)`, `(I_peak, halfwidth_diff_norm)`, `(I_peak, curvature_near_peak)`, `(I_peak, skew_m3)`

### A3. Derivative/motion/support candidates vs relaxation

- Motion-like: `|dI_peak/dT|`, `|d^2I_peak/dT^2|`, `|dI_centroid/dT|`, `|dwidth_I/dT|`, signed and absolute step metrics
- Shape/support-like: `chi_shape`, `ridge_band_width_rel30`, `ridge_supported_area_rel30`, `ridge_participation_count_rel30`, `ridge_top_fraction_width_rel80`

### A4. Structured low-order composite scan over `w=width_I`, `S=S_peak`, `I=I_peak`

Singles:

- `w`, `S`, `I`

Products:

- `w*S`, `w*I`, `S*I`

Ratios:

- `w/S`, `S/w`, `w/I`, `I/w`, `S/I`, `I/S`

Variants:

- `w^2/S`, `S^2/w`, `w^2/I`, `I^2/w`, `S^2/I`, `I^2/S`, `w/(S*I)`, `S/(w*I)`, `I/(w*S)`

### A5. Functional and robustness tests for `A` vs `X`

- Functional families: linear, power law, offset power law, exponential, exponential with offset
- Robustness: leave-one-temperature-out, endpoint trimming, exhaustive subsets, interpolation sensitivity, width-definition sensitivity, peak-region exclusion, high-T/low-T exclusion
- Basis sufficiency models for `A`: `X_only`, `kappa_only`, `X_kappa` across multiple alignment methods

## B. Summary table (observable -> performance)

### B1. `A` vs observable/composite performance

| Observable | Pearson with `A` | Spearman with `A` | Peak offset vs `A` peak (K) | Notes |
| --- | ---: | ---: | ---: | --- |
| `I/(w*S)` (`X`) | `0.9751` | `0.9868` | `0` | Best overall bridge in composite and robustness audits |
| `I/S` | `0.9549` | `0.9692` | `0` | Strong, but below `X` |
| `w/S` | `0.8622` | `0.9385` | `-4` | Positive but weaker and less peak-aligned |
| `I/w` | `0.6902` | `0.7626` | `+2` | Moderate |
| `|dI_peak/dT|` | `0.7306` | `0.7567` | `+1` | Best non-composite single-feature tracker |
| `|d^2I_peak/dT^2|` | `0.6874` | `0.7964` | `-1` | Strong curvature alternative but below `X` |
| `asym` | `0.5251` | `0.1813` | n/a | Weak rank-order consistency |
| `halfwidth_diff_norm` | `-0.4065` | `-0.6296` | n/a | Anti-aligned |
| `width_I` | `-0.8128` | `-0.8769` | `-22` | Strong inverse low-T behavior |
| `S_peak` | `-0.9319` | `-0.9868` | `-22` | Strong inverse control |
| `I_peak` | `-0.6660` | `-0.7911` | `-22` | Inverse and weak as crossover tracker |
| `chi_shape` (full / mobile) | `-0.3640` / `0.6956` | `-0.0206` / `0.7143` | `-17` | Regime dependent |

### B2. Shape-sector pair tests (map/geometry organization)

| Pair | Full joint EV | Full excess error ratio | Robust joint EV | Robust excess error ratio | Outcome |
| --- | ---: | ---: | ---: | ---: | --- |
| `(I_peak, halfwidth_diff_norm)` | `0.7949` | `0.3897` | `0.8008` | `0.5484` | Best in second-observable search |
| `(I_peak, width_I)` | `0.7840` | `0.4072` | `0.7906` | `0.5732` | Nearly tied with halfwidth-based pair |
| `(I_peak, curvature_near_peak)` | `0.7765` | `0.4193` | `0.7824` | `0.5932` | Slightly below top two |
| `(I_peak, X_shape)` | `0.5151` | `1.3544` | `0.8077` | `0.6156` | Unstable across subsets; weak full-set map reconstruction |

### B3. `A` vs `X` scaling robustness

| Test | Result |
| --- | --- |
| Baseline `A` vs `X` | Pearson `0.9751`, Spearman `0.9868`, peak offset `0 K` |
| Leave-one-out correlations | Pearson min/max `0.9716/0.9853`; Spearman min/max `0.9835/1.0000` |
| Exhaustive subsets (`N-2` kept) | Pearson min `0.9672`; Spearman min `0.9790` |
| Log-log exponent (`full`) | `beta = 0.6801`, `R^2 = 0.9609` |
| Excluding peak region | `beta = 0.6801` (no meaningful change) |
| Excluding high temperatures (`T > 26 K`) | `beta = 0.6972` (small shift) |
| Excluding low temperatures (`T < 26 K`) | `beta = 1.3521` (unstable due to 3-point subset) |
| Best functional family | Power law (best AIC/BIC; linear close but secondary) |

## C. Key negative results

- `S_peak`, `width_I`, and `I_peak` strongly anti-align with the relaxation crossover window (all peak at `4 K`, about `-22 K` from `A` peak).
- `X_shape` does not provide a stable standalone second coordinate in full-set reconstruction (`excess_error_ratio = 1.3544` in full subset).
- Asymmetry-only variables (`asym`, `halfwidth_diff_norm`) do not match the full relaxation dynamics consistently.
- `chi_shape` changes behavior by temperature window (negative full-range, positive only in the 20-32 K mobile window), so it is not a globally stable organizing coordinate.
- Second-coordinate duels show only small differences between top candidates (`width_I` vs `halfwidth_diff_norm`), so no unique second scalar emerges from those tests.
- In basis sufficiency robustness, `A` remains mostly `EXPLAINED_BY_X` but is alignment-sensitive (3/5 methods `EXPLAINED_BY_X`, 1/5 `EXPLAINED_BY_X_KAPPA`, 1/5 no overlap points).

## D. Final conclusion

Within the tested observable combinations, `X = I_peak / (width_I * S_peak)` is the only coordinate that jointly achieves:

- the strongest `A` correlation,
- zero peak-offset alignment with the relaxation crossover,
- stable performance under leave-one-out, trimming, and subset stress tests,
- and consistent superiority over simpler alternatives (`I/S`, `w/S`, singles, derivatives, and asymmetry-only metrics).

Other candidates capture partial aspects (motion, support width, or asymmetry), but none matches the full combination of correlation strength, peak alignment, and robustness shown by `X`.

Accordingly, the current repository evidence supports a data-driven claim of practical uniqueness of `X` under the tested observable set.
