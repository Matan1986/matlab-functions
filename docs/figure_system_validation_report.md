# Figure System Validation Report

Date: March 10, 2026

## Overall status

Repository visualization infrastructure is **partially compliant**: the helper layer now exists and the central export helper is publication-aware, but repository-wide adoption is not yet complete, so the repository is **not yet fully publication-ready from source**.

- MATLAB files scanned: 568
- Files with direct export-path violations outside `tools/save_run_figure.m`: 68
- Total direct export calls outside the canonical helper: 179
- Files with forbidden colormap usage (`jet`, `hsv`, `turbo`, or `rainbow` tokens): 28
- Files with `LineWidth < 1` literals: 11
- Files with `FontSize < 9` literals: 35
- Plot-like files missing `xlabel` and/or `ylabel` by static scan: 54
- Files explicitly referencing `General ver2` outside the legacy folder: 1

## Export path verification

The repository is not yet consistent with the canonical export path. `tools/save_run_figure.m` is the only allowed place for direct `saveas`, `savefig`, `exportgraphics`, or `print` calls, but the scan still found many direct exports elsewhere.

Top direct-export violators:
- `GUIs/FinalFigureFormatterUI.m` : 9 direct export call(s) via `exportgraphics|print|savefig`
- `Switching/analysis/switching_mechanism_survey.m` : 8 direct export call(s) via `saveas`
- `Fitting ver1/fit_script_ver_sinN.m` : 8 direct export call(s) via `exportgraphics|savefig`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` : 7 direct export call(s) via `saveas`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m` : 6 direct export call(s) via `saveas`
- `GUIs/FCS_export.m` : 6 direct export call(s) via `exportgraphics|print|savefig`
- `Switching/analysis/switching_shape_rank_analysis.m` : 6 direct export call(s) via `saveas`
- `Aging/diagnostics/diagnose_mode1_separability.m` : 6 direct export call(s) via `saveas`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` : 5 direct export call(s) via `saveas`
- `Relaxation ver3/aging_geometry_visualization.m` : 5 direct export call(s) via `saveas`

Highest-priority active-module offenders:
- `Switching/analysis/switching_mechanism_survey.m` : 8 direct export call(s)
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` : 7 direct export call(s)
- `Aging/diagnostics/diagnose_mode1_separability.m` : 6 direct export call(s)
- `Switching/analysis/switching_shape_rank_analysis.m` : 6 direct export call(s)
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m` : 6 direct export call(s)
- `Aging/diagnostics/diagnose_highT_basis_comparison.m` : 5 direct export call(s)
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m` : 5 direct export call(s)
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` : 5 direct export call(s)
- `Relaxation ver3/aging_geometry_visualization.m` : 5 direct export call(s)
- `Aging/analysis/debugAgingStage4.m` : 4 direct export call(s)

## Colormap policy check

Forbidden or publication-disallowed colormaps are still present in active scripts, especially `turbo` in Switching/Relaxation diagnostics and `jet` in several Aging/Relaxation paths.

- `Aging/analysis/aging_geometry_visualization.m` : `jet|turbo`
- `Aging/diagnostics/diagnose_deltaM_shifted_byTp_waittimes.m` : `jet`
- `Aging/diagnostics/diagnose_mode1_separability.m` : `turbo`
- `Aging/plotAgingMemory.m` : `jet`
- `Aging/plots/plotAFM_FM_robustnessCheck.m` : `turbo`
- `Aging/plots/plotAgingMemory.m` : `jet`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m` : `turbo`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m` : `turbo`
- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m` : `turbo`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m` : `turbo`
- `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m` : `turbo`
- `Relaxation ver3/getFileList_relaxation.m` : `jet`
- `Relaxation ver3/overlayRelaxationFits.m` : `jet`
- `Relaxation ver3/Plots_relaxation.m` : `jet`
- `Switching/analysis/switching_alignment_audit.m` : `turbo`
- `Switching/analysis/switching_mechanism_followup.m` : `turbo`
- `Switching/analysis/switching_mechanism_survey.m` : `turbo`
- `Switching/analysis/switching_observable_stability_survey.m` : `turbo`

Note: `tools/figures/figure_quality_check.m` intentionally contains `jet`/`hsv`/`turbo` references because it detects forbidden colormaps; that helper is not itself a violation.

## Figure style anti-patterns

Static scan findings indicate that style normalization is not yet universal at source level, even though exports through `save_run_figure.m` now receive the publication overlay automatically.

Examples with `LineWidth < 1`:
- `Aging/colorMarkersByTp_activeFigure.m` : `49:0.8`
- `Aging/models/fitFMstep_plus_GaussianDip.m` : `175:0.8|178:0.8`
- `Aging/plotAgingMemory.m` : `57:0.6`
- `Aging/plots/plotAgingMemory.m` : `57:0.6`
- `General ver2/appearanceControl/addGradientTempArrowPRL.m` : `64:0.35|74:0.35`
- `GUIs/FigureControlStudio.m` : `2332:0|2639:0|5833:0|5854:0|5866:0`
- `GUIs/FinalFigureFormatterGUI.m` : `633:0.5|961:0.6|1050:0.6`
- `GUIs/SmartFigureEngine.m` : `347:0.5|385:0.5|785:0|861:0.01`
- `GUIs/tests/legacy/FinalFigureFormatterGUI.m` : `633:0.5|961:0.6|1050:0.6`
- `Switching ver12/debugPlotGlobalPulseDrift_blocks.m` : `41:0.75`

Examples with `FontSize < 9`:
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes_clean.m` : `129:8|156:8|167:8|200:8`
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m` : `240:7`
- `Aging/diagnostics/diagnose_FM_construction_audit.m` : `240:8|253:8|268:8|285:8|307:8|313:8`
- `Aging/diagnostics/diagnose_mode1_separability.m` : `377:8`
- `Fitting ver1/fit_script_sin2.m` : `152:8`
- `Fitting ver1/fit_script_sin3.m` : `159:8`
- `Fitting ver1/fit_sinxsin.m` : `114:8`
- `Fitting ver1/New/fitTwoSineFixedB.m` : `133:1|137:2|148:2|153:2|164:3|169:2`
- `Fitting ver1/TwoSinMult.m` : `114:8`
- `General ver2/appearanceControl/addGradientTempArrowPRL.m` : `43:0.95`

Axis-label heuristic examples (plot-like files lacking `xlabel` and/or `ylabel` tokens):
- `AC HC MagLab ver8/ACHC_buildFoldingTable.m` : missing_xlabel=True, missing_ylabel=True
- `Aging/colorMarkersByTp_activeFigure.m` : missing_xlabel=True, missing_ylabel=True
- `Aging/fitAFM_FM_MeanField_and_DipGaussian.m` : missing_xlabel=True, missing_ylabel=True
- `Aging/pipeline/stage9_export.m` : missing_xlabel=True, missing_ylabel=True
- `Aging/utils/dbgFigure.m` : missing_xlabel=True, missing_ylabel=True
- `General ver2/appearanceControl/addGradientTempArrowPRL.m` : missing_xlabel=True, missing_ylabel=True
- `General ver2/appearanceControl/addTemperatureArrowPRL.m` : missing_xlabel=True, missing_ylabel=True
- `General ver2/appearanceControl/combineOpenFiguresToPanels.m` : missing_xlabel=True, missing_ylabel=True
- `General ver2/appearanceControl/combineOpenFiguresToPanels_v2.m` : missing_xlabel=True, missing_ylabel=True
- `General ver2/appearanceControl/CommonFormatting/formatThreeFiguresForPaper.m` : missing_xlabel=True, missing_ylabel=True

This axis-label check is heuristic and includes utilities, GUI code, tests, and legacy folders; it is best interpreted as a review queue, not a proof of broken figures.

## Helper usage analysis

Required helper files exist and are reachable:
- `tools/figures/create_figure.m`
- `tools/figures/apply_publication_style.m`
- `tools/figures/figure_quality_check.m`

Adoption summary:
- `save_run_figure(...)` is used in 16 non-helper files across 62 call sites.
- Direct external use of `create_figure(...)`: 0 call sites.
- Direct external use of `apply_publication_style(...)`: 0 call sites (styling is currently applied indirectly through `save_run_figure.m`).
- Direct external use of `figure_quality_check(...)`: 0 call sites (quality checks are currently applied indirectly through `save_run_figure.m`).

This means the infrastructure is in place, but the lightweight figure-creation API has not yet been adopted by analysis scripts.

## Legacy code safety

No explicit runtime imports or path additions for `General ver2/` were found outside the legacy folder itself. The only external reference found by static scan is a documentation string in `GenerateREADME.m`, which still describes `General ver2/` as containing shared plotting utilities.

- `GenerateREADME.m` : documentation text references `General ver2/`

## Compliance conclusion

The repository now has a credible publication visualization infrastructure:
- `save_run_figure.m` is publication-aware and centralizes export.
- `apply_publication_style.m` and `figure_quality_check.m` are automatically invoked on helper-routed exports.
- `create_figure.m` provides a consistent entry point for new figure-producing scripts.

However, the repository is **not yet robustly publication-ready as a whole** because direct export bypasses, disallowed colormaps, and source-level style violations remain widespread. The highest-leverage next step is to migrate the remaining direct-export scripts to `save_run_figure(...)`, starting with the active-module offenders listed above.

## Artifact

- Detailed per-file results: `docs/figure_system_validation_table.csv`
