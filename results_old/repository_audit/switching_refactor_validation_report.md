# Switching helper refactor validation report

Date: 2026-03-09
Workspace: C:/Dev/matlab-functions
Scope: End-to-end validation of the 9 refactored scripts under Switching/analysis

## Overall result

All 9 target scripts executed successfully in separate clean MATLAB sessions after the helper extraction refactor.

Validated scripts:

1. Switching/analysis/switching_alignment_audit.m
2. Switching/analysis/switching_mechanism_survey.m
3. Switching/analysis/switching_mechanism_followup.m
4. Switching/analysis/switching_mode23_analysis.m
5. Switching/analysis/switching_observable_basis_test.m
6. Switching/analysis/switching_second_coordinate_duel.m
7. Switching/analysis/switching_second_structural_observable_search.m
8. Switching/analysis/switching_shape_rank_analysis.m
9. Switching/analysis/switching_XI_Xshape_analysis.m

No runtime failures were observed.

## Run directories generated

- switching_alignment_audit.m -> results/switching/runs/run_2026_03_09_222702_alignment_audit/
- switching_mechanism_survey.m -> results/switching/runs/run_2026_03_09_223621_mechanism_survey/
- switching_mechanism_followup.m -> results/switching/runs/run_2026_03_09_224017_mechanism_followup/
- switching_mode23_analysis.m -> results/switching/runs/run_2026_03_09_224359_mode23_analysis/
- switching_observable_basis_test.m -> results/switching/runs/run_2026_03_09_224738_observable_basis_test/
- switching_second_coordinate_duel.m -> results/switching/runs/run_2026_03_09_225131_second_coordinate_duel/
- switching_second_structural_observable_search.m -> results/switching/runs/run_2026_03_09_225513_second_observable_search/
- switching_shape_rank_analysis.m -> results/switching/runs/run_2026_03_09_225929_shape_rank_analysis/
- switching_XI_Xshape_analysis.m -> results/switching/runs/run_2026_03_09_230048_XI_Xshape_analysis/

## Artifact summary

Each script loaded its required inputs, built switching-map/observable outputs, and produced new artifacts.

- switching_alignment_audit.m
  - Artifacts observed: 9 CSV, 70 PNG, 2 MAT, run metadata files.
  - Representative outputs: observables CSV, temperature cleanup figure, ridge/scaling figures, SVD/NMF outputs.
- switching_mechanism_survey.m
  - Artifacts observed: 2 CSV, 8 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: fit metrics CSV, observables summary CSV, mechanism figures, report, review ZIP.
- switching_mechanism_followup.m
  - Artifacts observed: 3 CSV, 3 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: local Arrhenius metrics, mode2 metrics, ridge-shape metrics, report, review ZIP.
- switching_mode23_analysis.m
  - Artifacts observed: 2 CSV, 4 PNG, 4 FIG, 1 MD, run metadata files.
  - Representative outputs: correlation/regression tables, scatter/regression figures, report.
- switching_observable_basis_test.m
  - Artifacts observed: 3 CSV, 3 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: correlations, pair comparison, geometry CSVs, basis figures, report, review ZIP.
- switching_second_coordinate_duel.m
  - Artifacts observed: 3 CSV, 3 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: metrics, residuals, geometry CSVs, reconstruction figures, report, review ZIP.
- switching_second_structural_observable_search.m
  - Artifacts observed: 3 CSV, 3 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: candidate summary, pair comparison, geometry CSVs, report, review ZIP.
- switching_shape_rank_analysis.m
  - Artifacts observed: 2 CSV, 6 PNG, 1 MD, 1 ZIP, run metadata files.
  - Representative outputs: singular values table, reconstruction metrics, rank-analysis figures, report, review ZIP.
- switching_XI_Xshape_analysis.m
  - Artifacts observed: 2 CSV, 3 PNG, 3 FIG, 1 MD, run metadata files.
  - Representative outputs: regression metrics, mode-space directions, scatter/geometry figures, report.

## Run-layout verification

Expectation checked:

results/switching/runs/run_<timestamp>_<label>/
    figures/
    tables/
    reports/
    review/

Findings:

- All 9 runs were created under results/switching/runs/run_<timestamp>_<label>/.
- All 9 runs contain the expected run-root metadata files (run_manifest.json, config_snapshot.m, log.txt, run_notes.txt).
- Artifact layout compliance is mixed.

Per-run layout status:

- run_2026_03_09_222702_alignment_audit
  - Warning: artifacts were written partly at run root and partly under alignment_audit/; no run-root figures/, tables/, reports/, or review/ folders were created.
- run_2026_03_09_223621_mechanism_survey
  - Warning: artifacts were written under mechanism_survey/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_224017_mechanism_followup
  - Warning: artifacts were written under mechanism_followup/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_224359_mode23_analysis
  - Partial compliance: mode23_analysis/ contains figures/, tables/, and reports/, but no review/ folder was created.
- run_2026_03_09_224738_observable_basis_test
  - Warning: artifacts were written under observable_basis_test/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_225131_second_coordinate_duel
  - Warning: artifacts were written under second_coordinate_duel/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_225513_second_observable_search
  - Warning: artifacts were written under second_observable_search/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_225929_shape_rank_analysis
  - Warning: artifacts were written under shape_rank_analysis/ without figures/, tables/, reports/, or review/ subfolders.
- run_2026_03_09_230048_XI_Xshape_analysis
  - Partial compliance: XI_Xshape_analysis/ contains figures/, tables/, and reports/, but no review/ folder was created.

Conclusion on layout requirement:

- Workflow execution succeeded for all 9 scripts.
- The refactor did not break artifact generation.
- The canonical figures/tables/reports/review folder layout is not yet uniformly enforced across these scripts.

## Helper-resolution verification

Local-helper definition scan result:

- No local definitions remain in Switching/analysis for these extracted helpers:
  - safeCorr
  - buildSwitchingMapRounded
  - buildMapRounded
  - computeXshapeFromMap
  - analyzeShapeSubspace
  - buildShapeMaps
  - toNumericColumn
  - toNumeric
  - toNum

MATLAB clean-session resolution result:

- safeCorr -> C:\Dev\matlab-functions\Switching\utils\safeCorr.m
- buildSwitchingMapRounded -> C:\Dev\matlab-functions\Switching\utils\buildSwitchingMapRounded.m
- buildMapRounded -> C:\Dev\matlab-functions\Switching\utils\buildMapRounded.m
- computeXshapeFromMap -> C:\Dev\matlab-functions\Switching\utils\computeXshapeFromMap.m
- analyzeShapeSubspace -> C:\Dev\matlab-functions\Switching\utils\analyzeShapeSubspace.m
- buildShapeMaps -> C:\Dev\matlab-functions\Switching\utils\buildShapeMaps.m
- toNumericColumn -> C:\Dev\matlab-functions\Switching\utils\toNumericColumn.m
- toNumeric -> C:\Dev\matlab-functions\Switching\utils\toNumeric.m
- toNum -> C:\Dev\matlab-functions\Switching\utils\toNum.m

This confirms the refactored scripts are resolving shared helper calls from Switching/utils.

## Switching ver12 protection check

- No files under Switching ver12 were modified during this validation pass.

## Warnings and failures

Warnings:

- Artifact layout is inconsistent with the canonical run-folder subdirectory policy for 7 runs, and only partially compliant for 2 runs.
- review/ folders were not created for the new mode23_analysis and XI_Xshape_analysis runs; several other scripts still write review ZIPs directly inside their label subdirectory instead of a review/ folder.
- alignment_audit still writes some generated artifacts directly at the run root in addition to its alignment_audit/ subdirectory.

Failures:

- None.

## Final assessment

The helper extraction refactor is validated from a workflow-execution standpoint:

- all 9 updated scripts run successfully end to end in clean MATLAB sessions
- data loading and observable/map generation succeeded
- figures, tables, reports, and review artifacts were produced where each script currently expects to write them
- shared helper resolution is correct and no duplicated local helper definitions remain in Switching/analysis
- Switching ver12 remained untouched

The remaining issues are run-layout compliance warnings, not runtime failures introduced by the helper extraction refactor.