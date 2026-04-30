# Phase 4B_C02B primary collapse variant audit

QA / inspection only. Not a manuscript physics interpretation.

## Why C02 differed

- Phase 4B_C02 used corrected-old authoritative residual-after-mode1 map vs x_aligned; that is residual-map QA, not P0-backed primary collapse.
- C02B rebuilds **primary collapse** overlays from P0 + gauge definitions and mixed S_long S_percent reads, matching forensic and stabilized-gauge scripts.

## Variants

- PRIMARY: S_percent/S_peak vs (I-I_peak)/W_I from `run_switching_old_fig_forensic_and_canonical_replot.m` logic.
- G014 / G254: S_percent/S_area_positive vs (I-I0)/W with gauge centers from `run_switching_stabilized_gauge_figure_replay.m` logic.
- ATLAS_G001_DOC_ONLY: extra triplets appear in `run_switching_gauge_atlas_preview.m` (not regenerated here).

## Outputs

- Registry: `tables/switching_phase4B_C02B_collapse_variant_registry.csv`
- Defects: `tables/switching_phase4B_C02B_collapse_variant_defects.csv`
- Reference map: `tables/switching_phase4B_C02B_collapse_variant_reference_match.csv`
- Figures: `figures/switching/canonical/phase4B_C02B_*`

## Defect metric

Per variant: interpolate each T curve onto a shared x grid; mean across T; residual = curve - mean; RMSE/MAE per T plus global row (T_K=NaN).

## S_long path used

- C:\Dev\matlab-functions\results\switching\runs\run_2026_04_24_233348_switching_canonical\tables\switching_canonical_S_long.csv
