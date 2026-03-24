# Snapshot System Map

## 1) Snapshot system overview
- Snapshot artifact: `L:\My Drive\For agents\snapshot\auto\snapshot_repo.zip`
- Generated at: `2026-03-22T14:55:21+02:00` (`snapshot_system_v1`)
- Packaging style: one outer ZIP containing module ZIPs + META manifest files
- Included module ZIPs:
  - `core_infra.zip` (~681.8 MB)
  - `unified_stack.zip` (~1.3 MB)
  - `experimental_pipelines.zip` (~0.21 MB)
  - `visualization_stack.zip` (~68.5 MB)

## 2) ZIP tree structure (depth 2-3)

### Outer package
```text
snapshot_repo.zip
├─ core_infra.zip
├─ unified_stack.zip
├─ experimental_pipelines.zip
├─ visualization_stack.zip
└─ META/
   ├─ manifest.json
   └─ snapshot_info.json
```

### core_infra.zip (mixed infra + outputs)
```text
core_infra.zip
├─ results/
│  ├─ aging/runs/...
│  ├─ cross_experiment/runs/...
│  ├─ switching/runs/...
│  ├─ relaxation/runs/...
│  ├─ cross_analysis/runs/...
│  ├─ repository_audit/runs/...
│  └─ review/runs/...
├─ docs/
│  ├─ reports/legacy/...
│  ├─ observables/...
│  └─ *.md, *.json (system docs/registry)
├─ reports/
│  ├─ *.md
│  ├─ *.csv
│  └─ *.json
├─ tools/
│  ├─ run_review/
│  ├─ survey_*/
│  ├─ claims/
│  └─ figure_repair/
├─ runs/experimental/...
├─ scripts/
├─ surveys/
├─ Switching ver12/
├─ MathWorks/ServiceHost/mci/
├─ .git/...
├─ .matlab_prefs/, .codex_*/, tmp/
└─ root wrappers (*.m, *.ps1, README, etc.)
```
Main file types: `png, fig, pdf, csv, json, txt, m, md, zip, mat` (plus repo/system artifacts).

### unified_stack.zip (analysis/pipeline code)
```text
unified_stack.zip
├─ Aging/
│  ├─ analysis/
│  ├─ pipeline/
│  ├─ diagnostics/
│  ├─ tests/
│  ├─ utils/
│  └─ docs/, models/, plots/, verification/
├─ Switching/
│  ├─ analysis/
│  └─ utils/
├─ Relaxation ver3/
│  └─ diagnostics/ (+ core relaxation scripts)
└─ analysis/
   ├─ cross-experiment synthesis scripts
   ├─ observable/bridge tests
   └─ switching/aging/relaxation comparison scripts
```
Main file types: mostly `*.m`, plus `*.md`, some `*.ps1`, minimal logs/asv.

### experimental_pipelines.zip (instrument-specific code)
```text
experimental_pipelines.zip
├─ AC HC MagLab ver8/
├─ ARPES ver1/
├─ FieldSweep ver3/
├─ MH ver1/
├─ MT ver2/
├─ PS ver4/
├─ Resistivity MagLab ver1/
├─ Resistivity ver6/
├─ Susceptibility ver1/
└─ zfAMR ver11/
   ├─ analysis/
   ├─ parsing/
   ├─ plots/
   ├─ tables/
   └─ utils/
```
Main file types: mostly `*.m` (+ a few `*.asv`, one `*.txt`).

### visualization_stack.zip (visualization infrastructure + palettes)
```text
visualization_stack.zip
├─ GUIs/
│  ├─ tests/
│  ├─ reports/
│  ├─ FigureControlStudio*.m
│  └─ formatter/export utilities
├─ General ver2/
│  ├─ appearanceControl/
│  ├─ figureSaving/
│  └─ Plot Metadata API ver1/
└─ github_repo/
   ├─ ScientificColourMaps8/...
   └─ cmocean/...
```
Main file types: palette/map assets (`txt, pal, mat, spk, gpl, lut, ct, xcmap, tbl, svg`), plus MATLAB scripts and figure assets (`m, png, pdf, py, xml`).

## 3) Per-ZIP role and workflow mapping
- `core_infra.zip`
  - Contains: mixed (`code + results + reports + metadata + figures + internal/repo state`)
  - Workflow role: infrastructure + run outputs + audits + orchestration history
  - Notes: this is where most produced analysis artifacts actually reside (`results/*/runs/*`).

- `unified_stack.zip`
  - Contains: analysis code, diagnostics, pipelines, cross-experiment comparison scripts
  - Workflow role: unified analysis/pipelines/observables logic (authoring layer)
  - Notes: mostly source scripts, not bulk numeric output.

- `experimental_pipelines.zip`
  - Contains: experiment/instrument ingestion and pipeline scripts
  - Workflow role: experiment-specific pipelines
  - Notes: strongly code-centric, almost no generated artifacts.

- `visualization_stack.zip`
  - Contains: GUI/formatting tools + colormap libraries/assets
  - Workflow role: visualization and figure styling/export
  - Notes: includes many static color-map assets and GUI tests/reports.

## 4) Where key elements are located
- Analysis results:
  - Primarily in `core_infra.zip -> results/*/runs/*`
  - Major domains: `results/aging/runs`, `results/cross_experiment/runs`, `results/switching/runs`, `results/relaxation/runs`

- Reports:
  - Scattered across:
    - `core_infra.zip -> results/*/runs/*/reports/*`
    - `core_infra.zip -> results/*/runs/*/review/*` (often zipped review bundles)
    - `core_infra.zip -> reports/*` (cross-run aggregate reports)
    - `core_infra.zip -> docs/reports/*`

- Cross-experiment outputs:
  - `core_infra.zip -> results/cross_experiment/runs/*`
  - Includes figures/tables/manifests/review zips for unified comparisons and bridges.

- Observables:
  - Runtime outputs: inside run folders in `core_infra.zip`, often as `observables.csv`, `tables/observable_*.csv`, and observable-focused reports.
  - Logic and definitions: in `unified_stack.zip` (`analysis/*observable*`, `cross_experiment_observables.m`) and `core_infra.zip/docs/observables/`.

## 5) Known structural issues / limitations
- Results concentration vs module naming mismatch:
  - Most valuable scientific outputs are concentrated in `core_infra.zip`, while other ZIPs are mostly source/tooling.
- Strong fragmentation of reporting:
  - Reports are spread across `results/.../reports`, `results/.../review`, root `reports/`, and `docs/reports/`.
- Nested ZIP layering:
  - Review/archives (`*.zip`) appear inside run folders, adding another packaging layer.
- Non-essential repository/system payload in `core_infra`:
  - Includes `.git`, temp folders, matlab prefs, and tool-state artifacts mixed with scientific outputs.
- Heterogeneous semantics inside one module:
  - `core_infra` mixes infra, historical run outputs, audits, temporary artifacts, and documentation.
- Potential duplication/near-duplication:
  - Similar report themes and review bundles appear both as standalone reports and per-run review zips.

## 6) Intended usage when sharing
- Share `snapshot_repo.zip` as the full reproducibility bundle.
- Use `core_infra.zip` to inspect concrete run outputs, evidence tables, figures, and review artifacts.
- Use `unified_stack.zip` to inspect/execute unified analysis and cross-experiment scripts.
- Use `experimental_pipelines.zip` for instrument-specific preprocessing/analysis pipelines.
- Use `visualization_stack.zip` for GUI tooling, formatting workflows, and color-map resources.
