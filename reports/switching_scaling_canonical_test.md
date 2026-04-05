# Switching Canonical Scaling Test

## 1. Definition of scaling tested

- Hypothesis tested (coordinate scaling only): `y = S/S_peak` vs `x = (I - I_peak)/width`.
- Source of truth: `docs/switching_canonical_definition.md`.
- Data source restricted to TRUSTED canonical runs: run_2026_04_02_234844_switching_canonical, run_2026_04_03_000008_switching_canonical, run_2026_04_03_000147_switching_canonical
- Primary run loaded: `run_2026_04_03_000147_switching_canonical`.
- Required tables loaded: `switching_canonical_S_long.csv`, `switching_canonical_observables.csv`.
- Width definition (baseline): FWHM from canonical `S_percent` at half-height (`S/S_peak = 0.5`), using linear interpolation on each side of `I_peak`.
- Width sensitivity definition: `width = 2*sigma_I` with positive `S_percent` weights around `I_peak` (canonical data only).

## 2. Metric results

- Baseline mean inter-curve std: `0.151136`
- Baseline mean RMSE to mean curve: `0.099647`
- Baseline common x-range: `[0.000000, 0.698515]`
- Canonical model (Scdf + kappa1*Phi1) mean inter-curve std: `0.246760`
- Canonical model mean RMSE to mean curve: `0.185302`
- Delta vs canonical model (data - model, inter-curve std): `-0.095624`

## 3. Comparison to canonical model

- Comparison basis: same `(I_peak, S_peak, width)` extracted from canonical data, applied to both measured `S_percent` and canonical model `S_model_full_percent`.
- `delta_vs_canonical_model` is reported in `tables/switching_scaling_metrics_summary.csv` as:
  `mean_intercurve_std(measured scaled curves) - mean_intercurve_std(canonical-model scaled curves)`.

## 4. Sensitivity analysis

- Width definition sensitivity (rms_2sigma): mean inter-curve std `0.188084`, mean RMSE `0.141520`.
- Delta vs baseline for width definition: std `0.036948`, RMSE `0.041873`.
- Remove 22-24 K sensitivity: mean inter-curve std `0.152626`, mean RMSE `0.102682`.
- Delta vs baseline after removing 22-24 K: std `0.001490`, RMSE `0.003035`.
- Remove 30 K sensitivity: mean inter-curve std `0.156006`, mean RMSE `0.104715`.
- Delta vs baseline after removing 30 K: std `0.004870`, RMSE `0.005068`.

## 5. Final verdict

- `SCALING_COLLAPSE_EXISTS = PARTIAL`
- `SCALING_REQUIRED_FOR_MODEL = NO`

Evidence-only conclusion based on reported metrics and sensitivities above.
