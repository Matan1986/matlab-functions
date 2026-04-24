# Aging Plotting Config

## Mode: `basic_plots`

Set:

```matlab
cfg = agingConfig();
cfg.mode = 'basic_plots';
```

This practical mode keeps Aging plotting minimal and predictable for basic use.

Produces:

- `\Delta M` vs Temperature through `plotAgingMemory(...)`
- AFM-like / FM-like vs pause temperature through `stage6_extractMetrics(...)`
- `M(T)` from `plotAgingMemory(...)` as an expected side-effect

Suppresses:

- diagnostic plots
- debug plots
- robustness plots
- extra stage-7 analysis panels
- single-run decomposition plots
- stage-9 summary table figure

## Example usage

```matlab
cfg = agingConfig();
cfg.mode = 'basic_plots';
state = Main_Aging(cfg);
```

## Notes

- `M(T)` cannot currently be disabled because `plotAgingMemory(...)` creates both `M(T)` and `\Delta M(T)` together.
- No other plots should appear in this mode.
- The previous `basic_plots` behavior was incorrect because it used a single-run decomposition figure as if it were the basic AFM/FM observable summary.
- The corrected `basic_plots` mapping is:
  - `stage8_plotting -> plotAgingMemory(...)`
  - `stage6_extractMetrics(...)` summary figure `Aging memory summary`
- The diagnostic single-run decomposition path is:
  - `stage4_analyzeAFM_FM -> plotDecompositionExamples -> plotAFM_FM_decomposition(...)`
  - this path is disabled in `basic_plots`.
