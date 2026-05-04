# SW-FIG-INFRA-01 — Switching canonical paper figures: `.fig` export compliance

## 1. Executive summary

The PowerShell driver `scripts/run_switching_canonical_paper_figures.ps1` generates a temporary MATLAB script that exported PNG and PDF for two canonical paper-candidate figures but did not write matching `.fig` files. Per `reports/maintenance/repo_language_figure_policy_INFRA_01B.md`, scientific MATLAB-rendered figures should ship **`.fig` + `.png`** (PDF does not replace `.fig`). This task adds `savefig` immediately after the existing `exportgraphics` calls for both figures. No data reads, plotting logic, layout, or labels were changed—only export mechanics.

## 2. Target script and prior INFRA-03 finding

- **Target:** `scripts/run_switching_canonical_paper_figures.ps1`
- **Context (`reports/maintenance/repo_nonmatlab_P0_figure_decision_INFRA_03.md`):** This script is not a standalone non-MATLAB renderer; it invokes MATLAB via `tools/run_matlab_safe.bat`. The compliance gap was that raster/vector exports existed without paired `.fig` files.

## 3. Exact code-level change summary

In the embedded MATLAB block (here-string written to `scripts/tmp_run_switching_canonical_paper_figures.m`):

- After `exportgraphics` for **figure 1** (main panel): added  
  `savefig(fig1, fullfile(outFigDir, 'switching_main_candidate_map_cuts_collapse.fig'));`  
  before `close(fig1)`.
- After `exportgraphics` for **figure 2** (supplement): added  
  `savefig(fig2, fullfile(outFigDir, 'switching_supp_Xeff_components.fig'));`  
  before `close(fig2)`.

In PowerShell:

- Defined `$mainFig` and `$suppFig` paths parallel to PNG/PDF.
- Extended success checks `$mainWritten` / `$suppWritten` to require the `.fig` files alongside PNG and PDF.
- Extended manifest rows and the generated markdown report output list to include `main_fig` and `supp_fig`.

**Not used:** `tools/save_run_figure.m` — would pull in run-directory conventions; inline `savefig` keeps the change minimal.

## 4. Execution / static validation result

**Executed:** `scripts/run_switching_canonical_paper_figures.ps1` completed successfully (MATLAB wrapper exit code 0, ~126 s). Full pipeline run; not static-only.

## 5. Figure output audit

Files produced or verified under `results/switching/figures/canonical_paper/`:

| Artifact | File |
|----------|------|
| Main PNG | `switching_main_candidate_map_cuts_collapse.png` |
| Main PDF | `switching_main_candidate_map_cuts_collapse.pdf` |
| Main FIG | `switching_main_candidate_map_cuts_collapse.fig` |
| Supp PNG | `switching_supp_Xeff_components.png` |
| Supp PDF | `switching_supp_Xeff_components.pdf` |
| Supp FIG | `switching_supp_Xeff_components.fig` |

Machine-readable audit: `tables/maintenance_switching_canonical_paper_figures_fig_export_INFRA_01_file_audit.csv`.

## 6. Limitations

- Success verdicts in the script still depend on inputs existing; missing inputs short-circuits before MATLAB (unchanged behavior).
- `.fig` format is MATLAB-version dependent; reopening in another release may show minor rendering differences (standard MATLAB constraint).

## 7. Recommended next step

If other Switching pipelines embed MATLAB export blocks without `savefig`, apply the same pattern (PNG + optional PDF + **mandatory `.fig`**) or route through `tools/save_run_figure.m` where a run directory contract already exists.
