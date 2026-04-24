# Aging Observable Contract

## Scope

This document defines the current observable contract for the Aging module
without changing computation, figure routing, or pipeline order.

## Current Default Config Path

Current default selection is controlled by:

```matlab
cfg.agingMetricMode = 'derivative';
cfg.AFM_metric_main = 'area';
cfg.dipAreaSource   = 'legacy_fit';
```

In `Main_Aging.m`, the active default path is:

1. `stage3_computeDeltaM`
2. `stage4_analyzeAFM_FM`
3. `stage5_fitFMGaussian`
4. `stage6_extractMetrics`

Even when `cfg.agingMetricMode = 'derivative'`, `stage5_fitFMGaussian` still
runs and provides the fit-derived observables used by the default stage6
summary figure.

## Default Observable Contract

DEFAULT OBSERVABLE CONTRACT:

```matlab
AFM_like = state.pauseRuns(i).Dip_area_selected
FM_like  = state.pauseRuns(i).FM_E
```

Under the current default config and execution path:

```matlab
state.pauseRuns(i).Dip_area_selected = state.pauseRuns(i).Dip_area_fit
state.pauseRuns(i).Dip_area_fit      = state.pauseRuns(i).Dip_A * sqrt(2*pi) * state.pauseRuns(i).Dip_sigma
FM_like                              = state.pauseRuns(i).FM_E
```

## Exact Sources

### AFM_like

- Exact source variable: `state.pauseRuns(i).Dip_area_selected`
- Current default source alias: `state.pauseRuns(i).Dip_area_fit`
- Upstream path:
  - `stage3_computeDeltaM` builds `DeltaM`
  - `stage5_fitFMGaussian` fits the tanh step + Gaussian dip model
  - `stage5_fitFMGaussian` computes `Dip_A`, `Dip_sigma`, and `Dip_area_fit`
  - `stage5_fitFMGaussian` assigns `Dip_area_selected = Dip_area_fit`
    under the default `cfg.dipAreaSource = 'legacy_fit'`
  - `stage6_extractMetrics` uses `Dip_area_selected` for the summary
    `AFM_like`
- Type: fit-derived observable

### FM_like

- Exact source variable: `state.pauseRuns(i).FM_E`
- Upstream path:
  - `stage3_computeDeltaM` builds `DeltaM`
  - `stage5_fitFMGaussian` fits the tanh step + Gaussian dip model
  - `stage5_fitFMGaussian` stores `FM_E`
  - `stage6_extractMetrics` uses `FM_E` for the summary `FM_like`
- Type: fit-derived observable

`FM_E` is the stage5 fit-derived FM strength metric. It is not a direct
stage4 decomposition field.

## Distinction From Stage4 Quantities

The default summary observables are not the same as the stage4 decomposition
signals:

- `dip_signed` is the signed residual-like dip signal from the stage4
  smooth-plus-residual decomposition.
- `FM_signed` is the signed FM component from the stage4 decomposition
  convention.
- `AFM_like` is currently the selected fit-derived dip strength summary.
- `FM_like` is currently the selected fit-derived FM strength summary.

In short:

- `dip_signed` and `FM_signed` are stage4 decomposition quantities.
- `AFM_like` and `FM_like` are stage6 summary observables.
- In the current default path, both summary observables are fit-derived.
