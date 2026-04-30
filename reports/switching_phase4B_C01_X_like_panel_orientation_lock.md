# Switching Phase 4B_C01 corrected-old X-like panel orientation/range lock

This is a narrow QA/inspection slice only. No broad replay was run.

## Source selection

- Exact source tables considered:
  - `tables/switching_corrected_old_authoritative_backbone_map.csv` (**used**)
  - `tables/switching_corrected_old_authoritative_residual_map.csv` (candidate, not used in panel)
  - `tables/switching_corrected_old_authoritative_artifact_index.csv` (metadata only)
- Family classification used in this slice:
  - `switching_corrected_old_authoritative_backbone_map.csv` -> `CORRECTED_CANONICAL_OLD_ANALYSIS`
  - `switching_corrected_old_authoritative_residual_map.csv` -> `canonical_residual_decomposition` (kept separate from selected panel)
  - `switching_corrected_old_authoritative_artifact_index.csv` -> authoritative index metadata (lineage/gate proof, not panel data)
- Why "authoritative":
  - "Authoritative" label comes from the gated builder output package and the artifact index/status records, not from ad-hoc replay.
- PTCDF diagnostic/backbone/residual columns used as authority:
  - **No** PTCDF diagnostic columns were used for the selected panel source.
- `switching_canonical_S_long` usage:
  - **No** direct `switching_canonical_S_long` input used in this slice.
  - If used in later slices, classification must be column-level: `S_percent` = source S (`CANON_GEN_SOURCE`), PT/CDF/backbone/residual columns = diagnostic (`EXPERIMENTAL_PTCDF_DIAGNOSTIC`).
- Silent family mixing:
  - **No silent mixing** performed. Only one source family (`CORRECTED_CANONICAL_OLD_ANALYSIS`) was used for plotted values.
- Source trace CSV: `tables/switching_phase4B_C01_X_like_panel_source_trace.csv`
- Orientation lock CSV: `tables/switching_phase4B_C01_X_like_panel_orientation_lock.csv`
- Status CSV: `tables/switching_phase4B_C01_status.csv`

## QA output posture

- Figure role: inspection/QA only
- Manuscript claim status: not allowed in this slice
- Display-only transforms/range decisions are not written back into source data
- Forbidden naming not used (`X_canon` etc. not used)
- No Relaxation/Aging comparison and no rename executed
- If source resolution becomes ambiguous in a future rerun, this slice must set `SOURCE_RESOLVED=NO` and avoid producing a misleading reconstruction panel.

## Figure output

- PNG written: `figures/switching/phase4B_C01_X_like_panel_orientation_lock.png`
