# Switching figure recovery inventory (narrow switching)

This step performs inventory/recovery only. No new figures were generated and no analysis logic was modified.

## Scope searched

- `Switching/analysis/`
- `scripts/`
- `results_old/switching/runs/`
- `results/switching/runs/`
- `tables/`
- `tables_old/`
- `reports/`
- `snapshot_scientific_v3/` (presence checked)

## Inputs treated as canonical anchors

- `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv`
- `tables/switching_P0_effective_observables_values.csv`
- `tables/switching_P0_old_collapse_freeze_metrics.csv`
- `tables/switching_P1_asymmetry_LR_values.csv`
- `tables/switching_P2_T22_crossover_metrics.csv`

## Inventory result

- Recovery scripts and canonical visualization scripts were found for all target families:
  - canonical S-map cuts
  - collapse plots
  - X / X_eff
  - X decomposition (`I_peak`, `W_I`, `S_peak`)
- In this workspace snapshot, figure artifact files were not present under `results/switching/runs/` or `results_old/switching/runs/`; inventory therefore uses script/report evidence and explicit old-output references.
- Candidate and decision tables are written:
  - `tables/switching_figure_recovery_inventory.csv`
  - `tables/switching_figure_recovery_candidates.csv`
  - `tables/switching_figure_recovery_decision.csv`
  - `tables/switching_figure_recovery_status.csv`

## Canonical compatibility and boundaries

- Canonical replot is feasible from existing scripts with locked S/P0/P1/P2 inputs.
- `X_eff` is treated as an effective gauge coordinate only.
- No claims of `X_canon` or unique `W` are allowed.
- `22 K` remains inside primary domain.
- `32/34 K` remain diagnostic-only.
- `SAFE_TO_WRITE_SCALING_CLAIM = NO`.
- `CROSS_MODULE_SYNTHESIS_PERFORMED = NO`.

## Required verdicts

- `SWITCHING_FIGURE_RECOVERY_INVENTORY_COMPLETE = YES`
- `OLD_CUT_FIGURES_FOUND = YES`
- `OLD_COLLAPSE_FIGURES_FOUND = YES`
- `OLD_X_FIGURES_FOUND = YES`
- `OLD_X_COMPONENT_FIGURES_FOUND = YES`
- `CANONICAL_REPLOT_FEASIBLE = YES`
- `MAIN_TEXT_FIGURE_CANDIDATE_IDENTIFIED = YES`
- `SUPPLEMENT_FIGURE_CANDIDATES_IDENTIFIED = YES`
- `SAFE_TO_GENERATE_CANONICAL_FIGURES = YES`
- `X_CANON_CLAIMED = NO`
- `UNIQUE_W_CLAIMED = NO`
- `SAFE_TO_WRITE_SCALING_CLAIM = NO`
- `CROSS_MODULE_SYNTHESIS_PERFORMED = NO`
