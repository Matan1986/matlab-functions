# Switching Alignment Audit Inventory

## 1. MAIN ANALYSIS SCRIPT

Main script:
`Switching/analysis/switching_alignment_audit.m`

Purpose:
Build and audit the switching map
`S(T,I_0) = dR/R [%]`
from legacy `Switching ver12` data, then generate geometry, decomposition, and robustness diagnostics.

Pipeline stages in the script:
1. Path/context setup, options, output directory resolution.
2. Legacy data ingestion per `Temp Dep ...` folder.
3. Metric extraction into `rawTbl` and export of raw samples CSV.
4. Map construction `Smap(T,I)`.
5. Temperature cleanup (rounded bins) and cleanup diagnostic.
6. Observable extraction from `Smap` (ridge, widths, susceptibility, asymmetry).
7. SVD/NMF decomposition diagnostics and reconstructions.
8. Ridge/scaling/structural diagnostics.
9. CSV exports and full figure export.
10. Console summaries (errors, rank comparisons, temperature cleanup summary).

### Related Functions Called

Local helper functions in the same script:
- `resolveDefaultParentDir`: reads default dataset path from legacy `Switching_main.m`.
- `resolveOutputDir`: uses `getResultsDir('switching','alignment_audit')` if available.
- `findAmpTempSubdirs`: finds subfolders starting with `Temp Dep`.
- `resolveNormalizeTo`, `resolveCurrentAndScale`: normalize/current parsing for legacy pipeline calls.
- `resolveChannels`: channel selection via `analyzeSwitchingStability`.
- `extractMetricFromTable`: maps `tableData` columns to `Tvec`, `Svec` by `metricType`.
- `collapseDuplicateTemperatures`: averages duplicate temperatures within a single channel trace.
- plotting helpers: `plotTemperatureCuts`, `plotCurrentCuts`, `applyDivergingColormap`.

External functions (legacy module, inspected):
- `Switching ver12/getFileListSwitching.m`:
  - Parses folder metadata (`Current_mA`, etc.), sorts files, returns `sortedValues`.
- `Switching ver12/main/processFilesSwitching.m`:
  - Core pulse/plateau processing.
  - Returns `stored_data` and per-channel `tableData`.
  - `tableData` row layout is:
    `[sortedValue, avg_p2p, avg_resall, change_pct, std_p2p, p2p_uncert, refBase]`.
- `Switching ver12/main/analyzeSwitchingStability.m`:
  - Computes stability metrics and auto-detects switching channel (`stability.switching.globalChannel`).
- `Switching ver12/parsing/extract_dep_type_from_folder.m`:
  - Classifies dependence type from folder name.

## 2. EXISTING OBSERVABLES

Below are observables/derived variables currently computed in `switching_alignment_audit.m`.

| Observable | Variable(s) | Meaning | Where computed |
|---|---|---|---|
| Raw sample table | `rawTbl` | Long-form samples `(current_mA, T_K, S_percent, channel, folder, metricType)` | After collection loop |
| Switching map | `Smap` | Mean switching amplitude on `(T,I)` grid | Map construction block |
| Temperature axis (cleaned) | `temps` | Rounded and merged temperature bins | Temperature cleanup block |
| Current axis | `currents` | Unique pulse-current values | Map construction block |
| Ridge current | `Ipeak` | `argmax_I S(T,I)` per temperature | "Temperature-dependent switching observables" block |
| Peak amplitude | `S_peak` | `max_I S(T,I)` per temperature | same block |
| Half-max peak width | `width_I` | Current width at `S >= 0.5*S_peak` | same block |
| Relative width | `width_rel` | `width_I / Ipeak` | immediately after ridge observables |
| Current susceptibility map | `dS_dI` | Numerical derivative `dS/dI` row-wise | susceptibility map block |
| Second current derivative map | `d2S_dI2` | Numerical `d2S/dI2` row-wise | susceptibility block |
| Susceptibility activation current | `Ichi` | `argmax_I dS_dI(T,I)` | susceptibility observables block |
| Susceptibility peak | `chiPeak` | `max_I dS_dI(T,I)` | same block |
| Susceptibility FWHM proxy | `chiWidth` | Half-max width on `dS_dI` | same block |
| Positive susceptibility area | `chiArea` | `integral max(dS_dI,0) dI` | same block |
| Peak asymmetry | `asym` | Area-right / area-left around `Ipeak` | asymmetry block |
| SVD singular spectrum | `singvals`, `svals_raw` | Normalized singular values and raw values | `runSVD` block |
| SVD reconstruction errors | `err_svd_1/2/3` | Frobenius relative errors for rank 1/2/3 | `runSVD` block |
| SVD improvements | `imp_svd_12`, `imp_svd_23`, `rel_svd_23` | absolute/relative reconstruction gain | `runSVD` block |
| SVD mode amplitudes (legacy) | `mode1_T`, `mode2_T` | `U(:,k)*S(k,k)` for first two modes | SVD mode diagnostics block |
| **Mode observables (T)** | `coeff_mode1/2/3` | First 3 SVD temperature-mode amplitudes | SVD mode diagnostics block |
| **Mode observables (I)** | `coeffI_mode1/2/3` | First 3 SVD current-mode amplitudes | SVD mode diagnostics block |
| Mode ratio | `mode_ratio`, `mode_ratio_smooth` | `|mode2|/|mode1|` and moving average | SVD mode diagnostics block |
| NMF errors | `err_nmf_2`, `err_nmf_3` | Rank-2 and rank-3 NMF reconstruction errors | `runNMF` block |
| NMF improvement | `imp_nmf_23`, `rel_nmf_23` | Rank 2->3 improvement metrics | `runNMF` block |
| Normalized map | `SmapNorm` | Row-normalized `S/max(S)` | normalized-map block |
| Ridge smoothing | `I_ridge_smooth` | Smoothed `Ipeak(T)` | ridge curve block |
| Width slope | `dWidth_dT` | `d(width_I)/dT` | activation-width block |
| Peak derivatives | `dS_peak_dT`, `dIpeak_dT`, `d2S_peak_dT2` | T-derivatives/curvature of peak observables | derivative-tests block |
| Ridge derivative alias | `dSpeak_dT` | Alias of `dS_peak_dT` | ridge-derivative block |
| Characteristic temperatures | `charTbl` (`charNames`, `charTemps`) | crossover markers from extrema in observables | characteristic-temp block |
| Ridge-centered coordinates | `dIgrid`, `S_shifted` | map/curves in `?I = I-Ipeak(T)` coordinates | ridge-collapse block |
| High-T peak tracking | `T_peak_high`, `T_width_high` | high-temperature peak position/width vs current | temperature-peak-tracking block |
| Low-T background vs current | `S_lowT` | mean `S` over `4=T=8 K` per current | low-T background block |
| Structural background residual | `S_background`, `S_residual` | residual map after subtracting low-T baseline | background subtraction block |
| SVD stability vectors | `sBefore`, `sAfter` | singular spectra before/after removing `T<10K` | SVD stability block |
| Curvature map in temperature | `curvT` | `?²S/?T²` across current columns | curvature block |

## 3. EXISTING DIAGNOSTICS

Diagnostics and plots currently generated by the script include:

- Base map and cuts:
  - `switching_alignment_heatmap.png`
  - `switching_alignment_temperature_cuts.png`
  - `switching_alignment_current_cuts.png`
  - `switching_alignment_two_panel.png`
- Ridge / geometry:
  - `switching_alignment_ridge.png`
  - `switching_alignment_ridge_curve.png`
  - `switching_alignment_ridge_observables.png`
  - `switching_alignment_ridge_derivatives.png`
  - `switching_alignment_ridge_law_tests.png`
  - `switching_alignment_map_with_ridge.png`
- Susceptibility and derivatives:
  - `switching_alignment_dSdI_heatmap.png`
  - `switching_alignment_d2SdI2_heatmap.png`
  - `switching_alignment_susceptibility_observables.png`
  - `switching_alignment_susceptibility_cuts.png`
  - `switching_alignment_susceptibility_width_vs_T.png`
- Peak/ridge observables:
  - `switching_alignment_observables.png`
  - `switching_alignment_additional_observables.png`
  - `switching_alignment_peak_width_vs_T.png`
  - `switching_alignment_activation_width_vs_T.png`
  - `switching_alignment_Ipeak_vs_T.png`
  - `switching_alignment_chiPeak_vs_T.png`
- Scaling/collapse diagnostics:
  - `switching_alignment_scaling_I_over_Ipeak.png`
  - `switching_alignment_scaling_I_minus_Ipeak.png`
  - `switching_alignment_scaling_threshold_normalized.png`
  - `switching_alignment_scaling_I_norm.png`
  - `switching_alignment_energy_scale_collapse.png`
  - `switching_alignment_heatmap_normalized.png`
  - `switching_alignment_ridge_collapse_map.png`
  - `switching_alignment_ridge_collapse_curves.png`
- SVD diagnostics:
  - `switching_alignment_svd_scree.png`
  - `switching_alignment_svd_explained_variance.png`
  - `switching_alignment_svd_T.png`
  - `switching_alignment_svd_I.png`
  - `switching_alignment_svd_mode_amplitudes_vs_T.png`
  - `switching_alignment_mode_ratio_vs_T.png`
  - `switching_alignment_mode_ratio_smoothed.png`
  - `switching_alignment_svd_current_modes.png`
  - `switching_alignment_mode_reconstruction.png`
  - `switching_alignment_mode_scatter.png`
  - `switching_alignment_mode_observable_correlations.png`
  - `switching_alignment_mode_observables.png`
  - `switching_alignment_svd_rank2_reconstruction.png`
  - `switching_alignment_svd_rank3_reconstruction.png`
  - `switching_alignment_residual_rank2.png`
  - `switching_alignment_residual_rank3.png`
  - `switching_alignment_svd_stability.png`
- NMF diagnostics:
  - `switching_alignment_nmf_T.png`
  - `switching_alignment_nmf_I.png`
  - `switching_alignment_nmf_component1.png`
  - `switching_alignment_nmf_component2.png`
  - `switching_alignment_nmf_reconstruction.png`
  - `switching_alignment_nmf_rank3_reconstruction.png`
  - `switching_alignment_nmf_stability.png`
- Structural extensions:
  - `switching_alignment_temperature_peak_tracking.png`
  - `switching_alignment_lowT_background.png`
  - `switching_alignment_mode_maps.png`
  - `switching_alignment_mode_localization.png`
  - `switching_alignment_mode_correlation.png`
  - `switching_alignment_width_scaling.png`
  - `switching_alignment_background_subtracted_map.png`
  - `switching_alignment_curvature_map.png`
  - `switching_alignment_derivative_tests.png`
  - `switching_alignment_activation_test.png`
- Cleanup diagnostics:
  - `switching_alignment_temperature_cleanup.png`

## 4. EXPORTED DATA PRODUCTS

Primary export directory:
`results/switching/alignment_audit/`

### CSV exports

- `switching_alignment_samples.csv`
  - Raw long-form sample table per measurement point:
    `current_mA, T_K, S_percent, channel, folder, metricType`.
- `switching_alignment_observables_vs_T.csv`
  - Temperature-indexed observables table including ridge, susceptibility, SVD-mode observables, derivatives, etc.
  - Current columns include (at least):
    `T_K, Ipeak, S_peak, width_I, Ichi, chiPeak, chiWidth, chiArea, asym, mode1_T, mode2_T, coeff_mode1, coeff_mode2, coeff_mode3, mode_ratio, mode_ratio_smooth, width_rel, dIpeak_dT, dSpeak_dT`.
- `switching_alignment_characteristic_temperatures.csv`
  - Named crossover temperatures extracted from observable extrema.
- `switching_alignment_extended_observables.csv`
  - Extended mixed table used for additional diagnostics (`T_K`, `I0_mA`, `invT`, `log_Ipeak`, `S_lowT`, `T_peak_high`, `T_width_high`).

### MAT exports

- No `.mat` export is performed by `switching_alignment_audit.m`.

### Figure exports

- All diagnostics listed in Section 3 are saved as `.png` in the same output directory.

---

This inventory reflects the current implementation state of `Switching/analysis/switching_alignment_audit.m` and its direct dependencies used by this script.

