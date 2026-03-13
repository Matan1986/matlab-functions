# Figure Repair Repository Scan

Date: March 10, 2026

## Summary

The repository already has a central figure export helper and a publication-style helper layer, but figure production is still mixed between canonical run exports and older direct export code. Editable `.fig` artifacts are present in run-scoped `figures/` folders, which makes a standalone post hoc repair workflow feasible without touching experiment pipelines.

## Where figures are saved

- Canonical run outputs are stored under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Canonical figure outputs are stored under `results/<experiment>/runs/<run_id>/figures/`.
- Existing repository runs under `results/aging/runs/`, `results/relaxation/runs/`, `results/switching/runs/`, and `results/cross_experiment/runs/` already contain `.fig` files inside `figures/`.
- Historical `run_legacy_*` folders also contain `figures/` directories and editable `.fig` artifacts.

## Current export behavior

- `tools/save_run_figure.m` is the canonical export helper.
- The helper resolves the run root, creates `figures/` if needed, and exports:
  - `.pdf` via `exportgraphics(..., 'ContentType', 'vector')`
  - `.png` via `exportgraphics(..., 'Resolution', 600)`
  - `.fig` via `savefig(...)`
- The helper applies `apply_publication_style(fig)` and `figure_quality_check(fig)` before export when those helpers are available.
- FIG export is present for helper-routed figures, but FIG creation is not yet consistent repository-wide because many older scripts still export directly with `saveas`, `savefig`, or `exportgraphics`.

## Existing repair-like functionality

- No dedicated repository repair module exists yet under `tools/figure_repair/`.
- Older figure post-processing or repair-adjacent code exists outside the new helper layer, including:
  - `GUIs/tests/legacy/BATCH_FIX_AGING_FIGURES.m`
  - `GUIs/tests/legacy/ANALYZE_FIG_QUALITY.m`
  - `GUIs/FinalFigureFormatterUI.m`
  - `GUIs/SmartFigureEngine.m`
- Legacy visualization utilities also exist in `General ver2/`, but repository policy explicitly forbids using them for new development.

## Potential conflicts and design implications

- The new repair system must remain separate from experiment pipelines because some pipelines and diagnostics still use direct exports and older helper paths.
- The repository already treats run-generated figures as artifacts under `results/.../figures/`, so repaired outputs should live alongside runs but outside the original `figures/` directory.
- Because `save_run_figure.m` already applies publication styling on export, the repair system should reuse the same style/check helpers where safe, but it must not depend on pipeline execution.
- Existing GUI and legacy repair-like scripts show that figure post-processing has happened before, but those paths are not standardized, not policy-safe for automated repository use, and should not be wired into the new repair architecture.
- The repair system must enforce immutable-source behavior because `.fig` files already serve as editable archival artifacts and may be reused for manual publication preparation.

## Conclusion

The repository is ready for a standalone, opt-in figure repair system that operates on existing `.fig` files and writes repaired outputs into a separate directory tree. The main compatibility requirement is to preserve the run-based artifact layout while keeping repair actions completely manual and non-destructive.
