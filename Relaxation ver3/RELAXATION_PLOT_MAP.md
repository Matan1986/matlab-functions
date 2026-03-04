# Relaxation ver3 plot map

Central switch is defined in `main_relaxation.m`:

```matlab
plots = struct();
plots.core = true;
plots.diagnostics = false;
plots.debug = false;
```

## Figure ownership and gating

| File | Function | Plot / Figure type | Gate |
|---|---|---|---|
| `Plots_relaxation.m` | `Plots_relaxation` | Raw relaxation curves | `plots.core` |
| `overlayRelaxationFits.m` | `overlayRelaxationFits` | Final fitted overlay (canonical) | `plots.core` |
| `plotRelaxationParamsVsTemp.m` | `plotRelaxationParamsVsTemp` | `tau(T)`, `beta(T)` | `plots.core` |
| `plotRelaxationCollapse.m` | `plotRelaxationCollapse` | Stretched-exponential collapse plot | `plots.core` |
| `fitAllRelaxations.m` | `fitAllRelaxations` | **Guaranteed no figures in core**; optional fitting debug output routed via `debugMode` or `fitParams.debugFit` | `plots.debug` (for debug figure path via called helpers) |
| `fitStretchedExp.m` | `fitStretchedExp` | **Guaranteed no figures**; only text diagnostics when debug is true | `plots.debug` (text only) |
| `pickRelaxWindow.m` | `pickRelaxWindow` | Window detection plot | debug argument (`plots.debug` / fit debug gate) |
| `plotArrhenius.m` | `plotArrhenius` | Arrhenius diagnostics | `plots.diagnostics` |
| `analyzeRelaxationAdvanced.m` | `localPlotSummary` | AIC model comparison | `plots.diagnostics` |
| `analyzeRelaxationAdvanced.m` | `localPlotResidualDiagnostics` | Residual diagnostics | `plots.diagnostics` |
| `analyzeRelaxationAdvanced.m` | `localPlotTauDistribution` | Intermediate diagnostics helper | `plots.diagnostics` |
| `analyzeRelaxationAdvanced.m` | `localPlotPerCurve` | Per-curve fit plots | `plots.debug` |
| `analyzeRelaxationAdvanced.m` | `localPlotResidualDebug` | Per-curve residual debug | `plots.debug` |

## Canonicalization decisions

- Final fit overlay is produced only by `overlayRelaxationFits`.
- `plotRelaxationFits` remains backward-compatible as a wrapper to `overlayRelaxationFits`.
- Core collapse plot is `plotRelaxationCollapse`.
- Advanced collapse/physics figures from `analyzeRelaxationAdvanced` are disabled in `main_relaxation.m` for core mode.

## TRM/IRM compare detection and display trimming notes

- `main_relaxation.m` now auto-detects TRM/IRM comparison from `fileList` content (case-insensitive filename tokens), not from the folder name.
- Auto-enable notice is printed only when comparison mode is turned on by this detection.
- `Plots_relaxation.m` and `overlayRelaxationFits.m` both use `t >= 0` as the default display mask so raw and overlay figures show a consistent displayed time range.
- `trimToFitWindow` in `overlayRelaxationFits.m` remains an optional extra display trim and does not change fitting windows or fit calculations.

## Self-check (manual, MATLAB)

```matlab
% Core-only sanity check: fitting should spawn zero debug figures
close all;
plots.core = true; plots.diagnostics = false; plots.debug = false;
run('main_relaxation.m');
% Expectation: only core figures (raw, overlay, tau/beta, collapse),
% and no extra figures from fitAllRelaxations/fitStretchedExp/pickRelaxWindow.

% Debug sanity check: fitting debug figures are allowed
close all;
plots.core = true; plots.diagnostics = false; plots.debug = true;
run('main_relaxation.m');
% Expectation: window/per-curve debug figures may appear.
```
