# Switching Phase 4B_C02 corrected-old collapse-like panel range lock

Narrow QA inspection slice only. No broad replay, no rename, no Relaxation or Aging comparison.

## Source selection

- Candidate sources listed in `tables/switching_phase4B_C02_collapse_like_panel_source_trace.csv`.
- Selected panel numeric source when resolved: authoritative `tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv` (CORRECTED_CANONICAL_OLD_ANALYSIS, residual after rank-one mode).
- `switching_canonical_S_long` was not used.
- PTCDF/CDF/backbone diagnostic columns were not promoted to corrected-old authority.

## Range lock and display policy

- Range lock table: `tables/switching_phase4B_C02_collapse_like_panel_range_lock.csv`.
- Display filters and axis limits are display-only; not written back to source CSVs.
- Forbidden tokens: `collapse_canon`, `X_canon` (not used).

## Figures (QA only)

- PNG: `figures/switching/phase4B_C02_collapse_like_panel_range_lock.png`
- FIG: `figures/switching/phase4B_C02_collapse_like_panel_range_lock.fig` (interactive inspection only)

## Status

- Status CSV: `tables/switching_phase4B_C02_status.csv`
