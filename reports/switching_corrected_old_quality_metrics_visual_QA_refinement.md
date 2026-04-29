# Switching TASK_002A — Visual QA Refinement (corrected-old diagnostic)

**Task ID:** TASK_002A (visual QA refinement layered on TASK_002 quality-metrics closure; diagnostic QA only, not publication.)

## Scope and constraints

- Switching-only visual QA refinement.
- No corrected-old builder edits.
- No physics logic changes.
- No authoritative table modification.
- No reconstruction rerun.
- PNG only; no FIG/PDF.
- Diagnostic QA only, not publication-ready.

## Inputs used

- Clean source view: `results/switching/runs/run_2026_04_24_233348_switching_canonical/tables/switching_canonical_source_view.csv`
- Authoritative corrected-old tables:
  - `tables/switching_corrected_old_authoritative_backbone_map.csv`
  - `tables/switching_corrected_old_authoritative_residual_map.csv`
  - `tables/switching_corrected_old_authoritative_mode1_reconstruction_map.csv`
  - `tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv`
  - `tables/switching_corrected_old_authoritative_phi1.csv`
  - `tables/switching_corrected_old_authoritative_kappa1.csv`
  - `tables/switching_corrected_old_quality_metrics_by_T.csv`
- Support context:
  - `tables/switching_corrected_old_finite_grid_support_by_T.csv`
  - `tables/switching_corrected_old_finite_grid_x_support_audit.csv`

## Implementation

Refinement driver:

- `Switching/diagnostics/run_switching_corrected_old_task002_visual_QA_refinement.m`

Key rendering choices:

- Unsupported values (`NaN`) are rendered via `AlphaData` masking with axis background color set to light gray.
- Annotation text explicitly states: gray is unsupported / outside finite aligned support (not zero).
- Residual comparison includes:
  - same-scale before/after view using symmetric limits from residual-before max abs,
  - zoomed residual-after view with its own symmetric limits.
- Source map is included (builder window `T=4:2:30`; current bins filtered to fully finite support across the window -> 6 currents).
- Phi1 plot shows finite support markers and connector caveat.
- Kappa1 panel marks 22 K, 24 K region and 30 K boundary caution.
- Quality-by-T panel adds improvement factor `RMSE_backbone / RMSE_after_mode1`.

## Refined outputs

All files are under:

- `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/`

Generated PNGs:

- `switching_corrected_old_QA_refined_source_backbone_mode1_residual.png`
- `switching_corrected_old_QA_refined_residual_before_after_same_scale.png`
- `switching_corrected_old_QA_refined_residual_after_zoomed_masked.png`
- `switching_corrected_old_QA_refined_phi1_kappa1_support_annotated.png`
- `switching_corrected_old_QA_refined_quality_by_T_improvement.png`

## Visual review guidance

1. Source -> backbone -> mode1 -> residual-after figure should be read as a pipeline view, with gray cells treated as unsupported support regions, not low values.
2. Same-scale residual before/after figure is the magnitude-reduction truth view.
3. Zoomed residual-after figure is the structure-inspection view.
4. Phi1 markers identify finite support points; line segments are visual connectors.
5. Quality-by-T figure highlights that 30 K remains a caution boundary where residual metrics worsen.

## Status and manifest

- Status: `tables/switching_corrected_old_quality_metrics_visual_QA_refined_status.csv`
- Manifest: `tables/switching_corrected_old_quality_metrics_visual_QA_refined_manifest.csv`

## Outcome

Refinement completed for honest manual QA visualization.
Publication authorization remains unchanged (still partial at program level).
