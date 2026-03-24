# Repository Map

Last updated: 2026-03-21

## Root Tree

```text
matlab-functions/
  .appdata/  .codex_matlab_prefs/  .codex_tmp/  .git/  .github/
  .localappdata/  .matlab_pref/  .matlab_prefs/  .mwhome/  .tmp_test/  .vscode/
  AC HC MagLab ver8/
  Aging/ (analysis, diagnostics, docs, models, pipeline, plots, tests, utils, verification)
  Aging old/ (docs, pipeline)
  analysis/
  ARPES ver1/
  claims/
  docs/
  FieldSweep ver3/
  Fitting ver1/ (New/)
  General ver2/ (appearanceControl, figureSaving, Plot Metadata API ver1)
  github_repo/ (cmocean, ScientificColourMaps8)
  GUIs/ (reports, tests)
  HC ver1/  MathWorks/  MH ver1/  MT ver2/  PS ver4/
  Relaxation ver3/ (diagnostics)
  reports/
  Resistivity MagLab ver1/  Resistivity ver6/
  results/
  runs/ (experimental)
  surveys/ (aging_dynamics, cross_experiment, project_synthesis, relaxation_dynamics, switching_dynamics)
  Susceptibility ver1/
  Switching/ (analysis, utils)
  Switching ver12/ (main, parsing, plots, tables, utils)
  tests/ (switching_stability)
  tmp/  tmp_root_cleanup_quarantine/
  tools/ (claims, figures, figure_repair, run_review, survey_audit, survey_builder, survey_registry)
  Tools ver1/
  zfAMR ver11/ (analysis, main, parsing, plots, tables, utils)
```

## Logical Grouping

### Core Infrastructure
- `docs/`
- `tools/`
- `runs/`
- `tests/`

### Active Science Stack
- `Aging/`
- `Switching/`
- `Relaxation ver3/`
- `analysis/` (cross-experiment)

### Independent Experimental Pipelines
- `AC HC MagLab ver8/` (active independent pipeline)
- `ARPES ver1/` (active independent pipeline)
- `FieldSweep ver3/` (active independent pipeline)
- `HC ver1/` (active independent pipeline)
- `MH ver1/` (active independent pipeline)
- `MT ver2/` (active independent pipeline)
- `PS ver4/` (active independent pipeline)
- `Resistivity MagLab ver1/` (active independent pipeline)
- `Resistivity ver6/` (active independent pipeline)
- `Susceptibility ver1/` (active independent pipeline)
- `zfAMR ver11/` (active independent pipeline)

### Legacy Science Pipelines
- `Aging old/`
- `Switching ver12/`

### Visualization / Figure / GUI Systems
- `GUIs/`
- `tools/figures/`
- `tools/figure_repair/`
- `General ver2/appearanceControl/` and `General ver2/figureSaving/` (legacy)

### Metadata / Review Layers
- `claims/`
- `surveys/`
- `reports/`

### Generated Outputs
- `results/`

### External Vendor Assets
- `github_repo/`

### Local Environment / Machine State
- `.appdata/`, `.codex_matlab_prefs/`, `.codex_tmp/`, `.localappdata/`, `.matlab_pref/`, `.matlab_prefs/`, `.mwhome/`, `.tmp_test/`, `.vscode/`, `tmp/`, `tmp_root_cleanup_quarantine/`, `MathWorks/`

## Dependency Overlay

### Aging
- Depends on: `tools/`, `results/`, and legacy helper surface in `General ver2/` via broad path setup.
- Used by: `Switching/`, `Relaxation ver3/diagnostics`, `analysis/`, `runs/experimental`.
- Hidden coupling: root appdata run context (`runContext`, `MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT`).

### Switching
- Depends on: `Aging/` (run helper surface), `tools/`, `results/`.
- Additional hard legacy dependency in one critical script: `Switching ver12/` (`switching_alignment_audit.m`).
- Hidden coupling: broad `addpath(genpath(...))`, source run-ID lookup from `results/switching/runs`.

### Relaxation ver3
- Diagnostics depend on: `Aging/`, `tools/`, `results/relaxation/runs`.
- Legacy `main_relaxation.m` depends on machine-local paths and global workspace state.

### analysis (cross-experiment)
- Depends on: `Aging/`, `tools/`, and run outputs under `results/aging`, `results/switching`, `results/relaxation`, `results/cross_experiment`.
- Hidden coupling: hardcoded/default source run IDs, wildcard scans of `results/*/runs`.

### GUIs
- Depends on: internal GUI stack (`SmartFigureEngine`, `FigureControlStudio`, `FinalFigureFormatterUI`) and optional colormap assets in `github_repo/ScientificColourMaps8`.
- Hidden coupling: appdata/prefs for UI state and figure target resolution.

### tools
- Depends on: `Aging/utils` run-helper surface (`createRunContext`, `getResultsDir`) for bootstrap paths in `init_run_output_dir`.
- Used by: all active science modules.

## Problem Zones

1. Legacy mixing in active stack:
- `Switching/analysis/switching_alignment_audit.m` requires `Switching ver12`.

2. Name collision risk:
- `safeCorr.m` exists in both `Aging/utils` and `Switching/utils`.
- duplicate helper names exist across legacy modules.
- broad `addpath(genpath(...))` increases ambiguity.

3. Results-system inconsistency pockets:
- non-canonical subfolders (`plots/`, `report/`) still appear in some scripts/runs.

4. Local path fragility:
- several legacy modules hardcode local drive paths.

5. Data-coupled reproducibility:
- many analyses require selected historical run directories under `results/`.


### Category Note
- independent experimental pipelines: not in the unified Aging/Switching/Relaxation stack, but actively used and scientifically relevant.

## Agent Context Workflow

- Read `docs/context_bundle.json` before tasks.
- Optional: `docs/context_bundle_full.json` for ChatGPT/analysis.
