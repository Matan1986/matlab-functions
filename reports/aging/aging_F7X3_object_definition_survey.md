# Aging F7X3 — Object definition survey (pre–naming contract)

Read-only **object-definition audit**. This is **not** a naming contract, does not select final names, does not rename code or artifacts, and does not modify F7W/F7X/F7X2 or router documents. No MATLAB/Python/replay/tau/ratio execution. Execution hygiene for any future runs remains [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

## Purpose and scope

F7X2 mapped **routes, methods, and name risks**. F7X3 asks, for each surveyed **object or term**: what is measured; relative to what baseline or residual; on what window and grain; what smoothing/fit/sign rules apply; whether the definition is explicit in code/docs or only inferred; and whether the object may serve as decomposition output, tau input/output, ratio output, diagnostic, or legacy-only reference.

## Files inspected

### Governance and prior surveys (read)

- `docs/repo_execution_rules.md`
- `docs/aging_observable_branch_router.md`
- `docs/aging_measurement_definition_freeze.md` (cross-read for freeze rows)
- `reports/aging/aging_F7X2_route_name_method_survey.md`
- `tables/aging/aging_F7X2_existing_route_name_inventory.csv`
- `tables/aging/aging_F7X2_decomposition_method_inventory.csv`
- `tables/aging/aging_F7X2_tau_method_inventory.csv`
- `tables/aging/aging_F7X2_name_confusion_risk_inventory.csv`
- `tables/aging/aging_F7X2_candidate_naming_dimensions.csv`
- `tables/aging/aging_F7X2_candidate_display_names.csv`
- `tables/aging/aging_F7X2_survey_status.csv`
- `reports/aging/aging_F7X_bridge_export_implementation.md`
- `tables/aging/aging_F7X_bridge_component_long.csv` (sample rows)
- `tables/aging/aging_F7X_bridge_component_index.csv`
- `tables/aging/aging_F7X_bridge_pairing_policy.csv`
- `tables/aging/aging_F7X_bridge_status.csv`

### MATLAB sources (text-only; actual paths)

| Requested path (prompt) | Repo path used |
|-------------------------|----------------|
| `Aging/stage4_analyzeAFM_FM.m` | **Missing at that path** — read `Aging/pipeline/stage4_analyzeAFM_FM.m` |
| `Aging/analyzeAFM_FM_components.m` | **Missing** — read `Aging/models/analyzeAFM_FM_components.m` |
| `Aging/analyzeAFM_FM_derivative.m` | **Missing** — read `Aging/models/analyzeAFM_FM_derivative.m` (header + signature) |
| `Aging/analyzeAFM_FM_extrema_smoothed.m` | **Missing** — read `Aging/models/analyzeAFM_FM_extrema_smoothed.m` (header + intro) |
| `Aging/stage5_fitFMGaussian.m` | **Missing** — read `Aging/pipeline/stage5_fitFMGaussian.m` |
| `Aging/stage6_extractMetrics.m` | **Missing** — read `Aging/pipeline/stage6_extractMetrics.m` |
| `Aging/analysis/aging_structured_results_export.m` | Present — read entry and freeze-cited strip of `FM_step_mag` |
| `Aging/analysis/run_aging_observable_dataset_consolidation.m` | Present — read entry and contract checks |
| `Aging/analysis/aging_timescale_extraction.m` | Present — read metadata block + `buildTauTable` grep |
| `Aging/analysis/aging_fm_timescale_analysis.m` | Present — read header + metadata |
| `Aging/analysis/aging_clock_ratio_analysis.m` | Present — read header + `loadTauTable` usage |

### Not fully read (disclosed)

- Full body of `analyzeAFM_FM_derivative.m` (result field list).
- `fitFMstep_plus_GaussianDip` implementation (stage5 callee).
- Entire `aging_structured_results_export.m` beyond opening and freeze anchor.

## Missing inputs

- User-short paths under `Aging/*.m` without `pipeline/` or `models/` — **not present**; actual implementations are under `Aging/pipeline/` and `Aging/models/` as tabulated above.
- Complete enumeration of **derivative** output fieldnames without a dedicated pass over the full `analyzeAFM_FM_derivative.m` body.

## Object-definition findings (synthesis)

- **Direct stage4 core** (`analyzeAFM_FM_components.m`): **Explicit** canonical relations in headers and code: smooth background `dM_smooth` via **Savitzky–Golay** (`sgolayfilt`) on interpolated `dM_work` with window derived from `smoothWindow_K` and median `dT`; **sharp** residual `dM_sharp = dM - dM_smooth`; **canonical signed dip** `dip_signed = DeltaM_signed - dM_smooth`; **AFM_RMS** = RMS of `dM_sharp` inside `dip_window_K`; **AFM_amp** / **AFM_area** from `dipMetric` branch; **FM_step_raw** / **FM_step_mag** (same signed value in direct path) from plateau bases. **Grain**: per pause run, **per_curve** on `T_common` with scalar summaries keyed by `waitK` (`Tp`).
- **Important nuance**: `dM_sharp` uses the **active analysis observable** `dM` while `dip_signed` uses **`DeltaM_signed`** — they need not coincide if `DeltaM` vs `DeltaM_signed` diverge (`definition_status` for `DeltaM_sharp` flagged **PARTIAL**/**MEDIUM** ambiguity in inventory).
- **Orchestrator** (`stage4_analyzeAFM_FM.m`): **Explicit** assignment of `FM_signed`, `FM_abs`, optional **`Dip_depth`** fill from **`AFM_amp`** with **`Dip_depth_source`**.
- **Stage5** (`stage5_fitFMGaussian.m`): **Explicit** selection semantics for **`Dip_area_selected`** with `Dip_area_selected_source`; **`Dip_area`** mirrors selected value; comments flag **legacy overload**.
- **Stage6** (`stage6_extractMetrics.m`): **Explicit** that **`AFM_like`** / **`FM_like`** are fit-summary vectors, not `dip_signed` / `FM_signed`.
- **Tau / ratio**: **Explicit** separation — tau scripts consume **consolidated** `Dip_depth` / `FM_abs` curves; **`tau_effective_seconds`** is a **legacy alias** requiring **F7G metadata** for domain; **`R_age`** is a **ratio_output** from **prior** tau tables.

## Background / baseline / residual findings

See `tables/aging/aging_F7X3_background_baseline_inventory.csv`. Distinctions:

| Concept | Primary locus | Notes |
|---------|----------------|-------|
| Smooth FM background | `dM_smooth` | Savitzky–Golay smooth of working DeltaM |
| Residual sharp | `dM_sharp` | Subtract smooth from **dM** (legacy-compatible observable) |
| Canonical signed dip | `dip_signed` | Subtract smooth from **DeltaM_signed** |
| Plateau baseline for FM step | Plateau windows | Used in `computeFMFromBases` paths (variant-dependent) |
| Fit baseline / dip | Stage5 Gaussian+tanh | Parametric model — **not** the same object as consolidation `Dip_depth` |
| Extrema smoothed | `analyzeAFM_FM_extrema_smoothed` | **Different** smoothing narrative (`movmean` in file intro) vs direct `sgolay` |

## Sign / smoothing / window / normalization findings

See `tables/aging/aging_F7X3_signal_processing_inventory.csv`.

- **Smoothing**: direct branch uses **sgolayfilt** with adaptive `winPts`, optional **low-T masking** (`excludeLowT_FM`, `excludeLowT_mode`).
- **Windows**: **`dip_window_K`** around `Tp` for dip metric integration; **FM plateau** spacing via **`FM_buffer_K`**, **`FM_plateau_K`** (see analyzer; not every numeric detail re-derived here).
- **Sign**: **`dip_signed`** and **`FM_step_raw`** signed; **`FM_abs`** **ABS_ONLY**; **`FM_step_mag`** **signed** despite name (freeze).
- **Normalization**: stage6 diagnostics use **z-score** helper for comparisons only; not a universal observable normalization.

## Tau-object definition findings

See `tables/aging/aging_F7X3_tau_object_definition_inventory.csv`.

- **Tau inputs** are **curves** `Dip_depth(tw)` and `FM_abs(tw)` **per `Tp`** from the consolidation dataset — **not** the same grain as **per-`Tp` only** summary vectors (`AFM_like`, `FM_like`) without an adapter.
- **Tau outputs** are **rows in `tau_vs_Tp.csv` / `tau_FM_vs_Tp.csv`** with a **zoo** of fit columns plus **`tau_effective_seconds`** (ambiguous without metadata).
- **Ratio outputs** (`R_age`) are **downstream** of those tau artifacts.

## Ambiguity / conflict findings

See `tables/aging/aging_F7X3_object_conflict_risk_inventory.csv` (includes all F7X2-mandated-style risks plus grain and bridge rows).

## Readiness for naming contract

`tables/aging/aging_F7X3_definition_readiness_matrix.csv` summarizes groups. **Overall: PARTIAL.** Core direct scalars are largely **EXPLICIT**; **derivative** outputs, **full fit callee** internals, and **tau_effective_seconds** cross-domain alias remain **gaps** for a strict contract without appendix work.

## Recommended next safe step

**`RESOLVE_DEFINITION_GAPS_THEN_DRAFT_NAMING_CONTRACT`** (mirrors `F7X3_NEXT_SAFE_STEP` in `tables/aging/aging_F7X3_survey_status.csv`): (1) complete a **field inventory** for `analyzeAFM_FM_derivative.m` results; (2) decide **mandatory sidecar** columns (`Dip_depth_source`, plateau validity) for consolidation; (3) freeze **tau primary column** policy or require **metadata** on every tau CSV row; (4) then draft naming contract **binding names to producer_id + grain + tau_role** without collapsing Track A/B.

## Deliverables

| File | Role |
|------|------|
| `tables/aging/aging_F7X3_object_definition_inventory.csv` | Per-object definition sentence attempt |
| `tables/aging/aging_F7X3_background_baseline_inventory.csv` | Background/baseline/residual concepts |
| `tables/aging/aging_F7X3_signal_processing_inventory.csv` | Processing chain notes |
| `tables/aging/aging_F7X3_tau_object_definition_inventory.csv` | Tau and ratio object roles |
| `tables/aging/aging_F7X3_object_conflict_risk_inventory.csv` | Conflicts blocking full contract clarity |
| `tables/aging/aging_F7X3_definition_readiness_matrix.csv` | Group readiness |
| `tables/aging/aging_F7X3_survey_status.csv` | Verdict keys |

## Cross-module touch

**None.** Only new **Aging** survey files under `reports/aging/` and `tables/aging/` were added; Switching, Relaxation, and MT paths were not edited.
