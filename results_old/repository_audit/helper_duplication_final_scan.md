# Helper Duplication Final Scan

## Scope

Inspection-only repository-wide scan for helper definitions outside the canonical shared helper locations:

- `tools/`
- `<experiment>/utils/`

Reviewed repository guidance first:

- `docs/AGENT_RULES.md`
- `docs/results_system.md`
- `docs/repository_structure.md`

No code was refactored, moved, or modified as part of this scan.

## Overall Result

The repository is **not globally duplication-free**, but the recent Switching helper extraction appears to be holding cleanly.

- The extracted Switching helper set is centralized in `Switching/utils/`.
- No matching reimplementations of that extracted helper set were found in `Switching/analysis/`.
- Remaining duplication is concentrated mostly in older diagnostics / plotting code in `Relaxation ver3`, `Aging`, `zfAMR ver11`, and a few historical utility areas.

## Duplicated Helper Candidates

### 1. Relaxation preprocessing / defaults cluster

Candidate functions:

- `setDef`
- `parseNominalTemp`
- `findRuns`
- `cleanAligned`
- `detectRelaxStart`

Representative locations:

- `Relaxation ver3/analyzeRelaxationAdvanced.m`
- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`
- `Relaxation ver3/diagnostics/survey_relaxation_observables.m`
- `Relaxation ver3/diagnostics/validate_relaxation_band_boundaries.m`
- `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m`
- `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m`

Assessment:

- These look like real extraction candidates for a future `Relaxation/utils/` cleanup.
- The `setDef`, `parseNominalTemp`, and `findRuns` repetitions are broad enough to justify later extraction.
- Some plotting-adjacent helpers in the same files may still be script-local.

Recommendation:

- Extract later, but only as a small dedicated Relaxation cleanup. Keep local for now.

### 2. Relaxation plotting / map preparation cluster

Candidate functions:

- `plotMap`
- `plotTempCuts`
- `plotTimeCuts`
- related geometry-grid / heatmap preparation helpers

Representative locations:

- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`
- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`
- `Relaxation ver3/diagnostics/visualize_relaxation_band_maps.m`
- `Relaxation ver3/diagnostics/visualize_relaxation_geometry.m`

Assessment:

- These are conceptually duplicated, but some may differ enough in labels / assumptions to keep local.

Recommendation:

- Review later for narrow extractions only where signatures already match.

### 3. Aging diagnostics scalar / window helpers

Candidate functions:

- `getScalarOrNaN`
- `getFieldOrNaN`
- `getFieldOrEmpty`
- `clampWindow`
- `extractDeltaMCurve`
- `patchWindow`

Representative locations:

- `Aging/diagnostics/auditDecompositionStability.m`
- `Aging/diagnostics/diagnose_baseline_subtracted_FM.m`
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes.m`
- `Aging/diagnostics/diagnose_decomposition_audit_waittimes_clean.m`
- `Aging/diagnostics/diagnose_deltaM_svd_pca.m`
- `Aging/diagnostics/diagnose_fit_vs_derivative_audit.m`
- `Aging/diagnostics/diagnose_FM_construction_audit.m`
- `Aging/analysis/aging_geometry_visualization.m`
- `Aging/verification/verifyRobustBaseline_*.m`

Assessment:

- This is one of the larger active duplication clusters outside Switching.
- These helpers are small, stable, and likely reusable across Aging diagnostics.

Recommendation:

- Good future extraction candidates into `Aging/utils/`, but not urgent for this audit.

### 4. zfAMR plotting helper cluster

Candidate functions:

- `clean_and_clip_segments`
- `pretty_label`
- `firstNonEmptyTable`
- `wrapTo180`
- `ternary`

Representative locations:

- `zfAMR ver11/plots/plot_extracted_cooling_segments.m`
- `zfAMR ver11/plots/plot_extracted_warming_segments.m`
- `zfAMR ver11/plots/plot_founded_angle_segments.m`
- `zfAMR ver11/plots/plot_founded_decreasing_temperature_segments.m`
- `zfAMR ver11/plots/plot_founded_field_segments.m`
- `zfAMR ver11/plots/plot_founded_increasing_temperature_segments.m`
- `zfAMR ver11/analysis/analyze_physical_fourier.m`
- `zfAMR ver11/analysis/plot_harmonic_locking.m`
- `zfAMR ver11/plots/plot_fcAMR_polar.m`
- `zfAMR ver11/plots/plot_R_vs_temp_field_at_angle.m`
- `zfAMR ver11/plots/plot_zfAMR.m`
- `zfAMR ver11/plots/pretty_label.m`
- `zfAMR ver11/firstNonEmptyTable.m`

Assessment:

- Several wrappers are duplicated both as standalone helpers and as local script functions.
- `pretty_label` and `firstNonEmptyTable` are especially clear duplication cases.

Recommendation:

- Later cleanup should prefer the existing standalone helpers instead of local forks where behavior matches.

### 5. Historical / legacy utility duplication

Examples:

- `unique_name` across many files in `General ver2/figureSaving/`
- `makeSafeFilename` across multiple files in `Fitting ver1/`
- helper duplication inside `Switching ver12/`

Assessment:

- These are historical areas and not evidence that the recent Switching refactor regressed.
- `Switching ver12/` remains intentionally untouched.

Recommendation:

- Leave as-is unless there is a separate legacy cleanup project.

## Switching-Specific Confirmation

Checked extracted helper names:

- `safeCorr`
- `buildSwitchingMapRounded`
- `buildMapRounded`
- `computeXshapeFromMap`
- `analyzeShapeSubspace`
- `buildShapeMaps`
- `toNumericColumn`
- `toNumeric`
- `toNum`

Result:

- All of these resolve to `Switching/utils/` for the Switching refactor target set.
- No copies of these helpers were found embedded in `Switching/analysis/`.
- The only non-`Switching/utils` match in this name set was `safeCorr` in Aging code (`Aging/utils/safeCorr.m` and one Aging test-local helper), which is a separate module and not a Switching regression.

## Should They Remain Local Or Be Extracted Later?

Keep local for now:

- highly script-specific plotting wrappers
- one-off formatting helpers
- helpers with strong assumptions tied to a single diagnostic script

Reasonable future extraction targets:

- Relaxation preprocessing / defaults helpers
- Aging scalar / field / window helpers
- zfAMR standalone-vs-local wrapper duplication (`pretty_label`, `firstNonEmptyTable`, `wrapTo180`-style helpers)

## Conclusion

The repository is **not fully duplication-free across all historical modules**, but the canonical helper architecture is working in the recently cleaned areas.

Most important confirmation from this audit:

- The Switching helper extraction remains intact.
- No accidental reimplementation of the extracted Switching helper set was found in `Switching/analysis/`.
- Remaining duplicate helper candidates are concentrated in older diagnostics / plotting areas and can be addressed later as targeted module-specific cleanups.