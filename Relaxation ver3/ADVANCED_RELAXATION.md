# Advanced relaxation analysis (additive, non-breaking)

This module extends the current pipeline **without changing existing outputs** when advanced mode is off.

## Entry point
- `analyzeRelaxationAdvanced.m`

## Usage
```matlab
advCfg = struct();
advCfg.useMultiStart = true;
advCfg.enableLogModel = true;
advCfg.modelCriterion = 'AIC';
advCfg.makePerCurvePlots = true;
advCfg.debugResidualPlot = false;
adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, advCfg);
```

## Configuration toggles
- `useMultiStart` (default `true`): perform multi-start stretched-exponential refit for robustness.
- `enableLogModel` (default `true`): fit alternative model `M = M0 - S*log(t)`.
- `modelCriterion` (`'AIC'` or `'BIC'`, default `'AIC'`): metric for model choice.
- `modelSelectionMode` (`'best_metric'` or `'force_baseline'`, default `'best_metric'`): whether to force original model.
- `nStarts` (default `10`): number of random starts for stretched-exponential fit.
- `minPoints` (default `15`): minimum points required in fit window.
- `tauUnresolvedFactor` (default `2.0`): marks `tau_unresolved=true` if `tau > factor * fitWindowSpan`.
- `minR2_ok` (default `0.90`): quality threshold for `fit_ok` status.
- plotting toggles: `makePerCurvePlots`, `makeSummaryPlot`, `makeCollapsePlot`, `debugResidualPlot`, `figureVisible`.

## New outputs
`adv.results` table includes:
- `fit_ok`, `fit_status`
- `RMSE`, `exitflag`, `Npts`
- `tau_unresolved`
- selected model (`baseline`, `stretched_multistart`, `log_model`)
- model comparison metrics (`AIC`, `BIC`) and baseline metrics.

## Figures
- Per-curve figure: data + selected fit + fit-window shading + annotation.
- Optional debug residual figure: residual vs log-time.
- Summary figure: `tau` vs `T` (color by `beta`, marker by status).
- Collapse figure: `(M-Minf)/dM` vs `(t/tau)^beta`.

## Non-breaking guarantee
- Existing functions and signatures remain unchanged.
- Existing scripts behave exactly as before unless `advancedMode=true` in `main_relexation.m`.
