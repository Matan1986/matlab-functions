# Aging F7X4 — Definition gap resolution (pre–contract)

Focused **gap-resolution audit** only. Does **not** write a full naming contract, rename identifiers, edit F7W/F7X/F7X2/F7X3 artifacts or router docs, or run MATLAB/Python/replay/tau/ratio. Hygiene: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

## Purpose

Close the **highest-risk** definition gaps called out in F7X3 (`PARTIAL` naming-contract readiness) using **explicit code and governance text** only. Where code does not fully close a topic, status is **PARTIAL** or **BLOCKING** with a **contract rule** (not a code fix).

## Files inspected (this pass)

- F7X3 package: `reports/aging/aging_F7X3_object_definition_survey.md`, `tables/aging/aging_F7X3_*.csv`
- Governance: `docs/aging_observable_branch_router.md`, `docs/aging_measurement_definition_freeze.md` (spot checks)
- **Core code:** `Aging/models/analyzeAFM_FM_components.m` (dM / `DeltaM_signed` / smooth / sharp / `dip_signed`), `Aging/pipeline/stage4_analyzeAFM_FM.m` (router + derivative input preference), `Aging/models/analyzeAFM_FM_derivative.m` (full result surface), `Aging/models/analyzeAFM_FM_extrema_smoothed.m`, `Aging/pipeline/stage5_fitFMGaussian.m`, `Aging/pipeline/stage6_extractMetrics.m`, `Aging/Main_Aging.m` (stage order)
- **Tau:** `Aging/analysis/aging_timescale_extraction.m` (`buildConsensusTau`), `Aging/analysis/aging_fm_timescale_analysis.m` (`buildEffectiveFmTau`), headers/metadata for `tau_effective_seconds`
- **Repo-wide grep (counts):** `dM`, `DeltaM_signed`, `agingMetricMode` under `Aging/**/*.m` (for scope only)

## Gap-by-gap findings

### 1. `dM` vs `DeltaM_signed` (G1) — **RESOLVED**

**Code fact (direct `analyzeAFM_FM_components.m`):**

- `dM = pauseRuns(i).DeltaM(:)` — **pipeline analysis observable** (comment: legacy-compatible).
- `DeltaM_signed` is taken from `pauseRuns(i).DeltaM_signed` when present and non-empty; else **`DeltaM_signed = dM`** with `DeltaM_signed_source = 'fallback_from_DeltaM_observable'`; if lengths mismatch, **`DeltaM_signed = dM`** again with `'fallback_length_mismatch'`.
- **`DeltaM_smooth`** is built from **`dM_work`** derived from **`dM`** (with optional low-T masking), via **`sgolayfilt`**.
- **`DeltaM_sharp = dM - dM_smooth`** — uses **`dM`**, not `DeltaM_signed`.
- **`dip_signed = DeltaM_signed - dM_smooth`** — uses **`DeltaM_signed`**, same smooth component.

**Implication:** Whenever `pauseRuns.DeltaM` and `pauseRuns.DeltaM_signed` **differ**, **`DeltaM_sharp` and `dip_signed` are not the same residual**. Contract must **not** equate them without proving equality (e.g. via `DeltaM_signed_source` and byte-wise alignment policy).

**Derivative path:** Orchestrator passes `dM_for_derivative = run.DeltaM_signed` when present else `run.DeltaM` into `analyzeAFM_FM_derivative`. Nested `analyzeAFM_FM_components` uses **`tmpRun` with only `DeltaM` set** to that vector, so nested `DeltaM_signed` **falls back to the same passed trace** — consistent for that call.

### 2. Background / baseline / residual vocabulary (G2) — **PARTIAL**

**Resolved mapping** (see `tables/aging/aging_F7X4_background_baseline_resolution.csv`):

| Contract token | Maps to |
|----------------|---------|
| `SMOOTH_COMPONENT` | `DeltaM_smooth` (sgolay of `dM_work`) |
| `SHARP_RESIDUAL_DELTA_M_OBSERVABLE` | `DeltaM_sharp = dM - smooth` |
| `SIGNED_DIP_RESIDUAL` | `dip_signed = DeltaM_signed - smooth` |
| `PLATEAU_REFERENCE_FM` | Plateau bases for `FM_step_raw` (direct variants) |
| `DERIVATIVE_MEDIAN_BASELINE_ON_SMOOTH` | Medians of `dM_smooth` outside dip for derivative `FM_step_raw` |
| `STAGE5_FIT_PARAMETRIC` | Gaussian + tanh fit outputs (`FM_E`, `Dip_A`, …) — **not** `DeltaM_smooth` |
| `EXTREMA_MOVMEAN_SMOOTH` | `movmean(DeltaM,11)` then min/max — **different** smoother than direct branch |

**Remainder:** Header prose still says “background” colloquially; **contract should ban unqualified `background`** as a normative identifier (use category-qualified labels).

### 3. Derivative branch outputs (G3) — **RESOLVED**

`analyzeAFM_FM_derivative.m` **result** surface is enumerable from `initResult` plus the main body: copies **`DeltaM_smooth`**, **`DeltaM_sharp`**, **`dip_signed`**, **`DeltaM_definition_canonical`**, **`dip_definition_canonical`**, **`AFM_*`**, cfg echo fields; then **redefines** **`FM_step_raw` / `FM_step_mag`** from **median `dM_smooth` outside dip`**; sets **`baseline_*`**, **`FM_plateau_*`**, and **`diagnostics`** (`dMdT`, masks, counts). Allowed use: **decomposition + diagnostics**; not automatically five-column unless exported.

### 4. `cfg.agingMetricMode='fit'` vs true stage5 fit (G4) — **RESOLVED**

- **`stage4_analyzeAFM_FM.m`** `case {'direct','model','fit'}` → **`analyzeAFM_FM_components`** — **stage4 direct family**, **not** stage5 nonlinear fit.
- **`Main_Aging.m`** order: **stage4 → stage5 → stage6** — stage5 **always runs after** stage4 in this entry path.
- **`AFM_like` / `FM_like`**: **stage6** summaries from **`Dip_area_selected`** / **`FM_E`** (and extrema branch substitutes) — **Track A**, not consolidation `Dip_depth` / `FM_abs` (freeze).

**PARTIAL sub-gap:** `fitFMstep_plus_GaussianDip` **callee** not line-audited here — stage5 objects are **contract-safe at interface** (`stage5_fitFMGaussian.m`) with **internal formula** deferred.

### 5. `tau_effective_seconds` (G5) — **PARTIAL** at column level, **RESOLVED** per script

- **Dip script:** `buildConsensusTau` — `tau_effective_seconds = 10^median(log10(tauValues))` over trusted methods (`aging_timescale_extraction.m` ~428–456).
- **FM script:** `buildEffectiveFmTau` — if `tau_half_range_status == "ok"` and finite `>0`, **`tau_effective_seconds = tau_half_range_seconds`** with `nMethods=1` and `methodNames='half_range_primary'`; **else** same log-median recipe as dip (~741–773).

**Contract implication:** Same **column name**, **two algorithms**; safe only with **`writer_family_id` / `semantic_status` / `source_artifact_path`** (F7G pattern already in writers) **plus** `tau_consensus_methods`.

### 6. Stage boundaries (G6) — **RESOLVED** (map artifact)

See `tables/aging/aging_F7X4_stage_boundary_map.csv` for **grain**, **producer**, and **allowed_downstream_use** per layer.

## What was resolved vs partial

| Topic | Status |
|-------|--------|
| dM vs DeltaM_signed vs sharp vs dip_signed | **RESOLVED** (explicit assignments) |
| Derivative output inventory | **RESOLVED** |
| agingMetricMode `fit` vs stage5 fit | **RESOLVED** |
| Stage order stage4/5/6 | **RESOLVED** |
| Background vocabulary | **PARTIAL** (colloquial overload remains in prose) |
| tau_effective_seconds **as a bare global name** | **PARTIAL** (needs domain + companion columns) |
| stage5 fit callee internals | **PARTIAL** (OUT_OF_SCOPE for line-audit in F7X4) |

## Implications for naming / definition contract

1. **Definition contract should precede or wrap naming** for any row touching **`DeltaM_sharp`** vs **`dip_signed`** — require **`DeltaM_signed_source`** (or proof of equality).
2. **Ban unqualified** `background`; use **`resolved_category`** tokens from `aging_F7X4_background_baseline_resolution.csv`.
3. **Derivative route** gets an appendix **field list** (from F7X4 derivative table).
4. **`tau_effective_seconds`**: allow only as **`LEGACY_EFFECTIVE_TAU`** with mandatory **`script_domain`** (`DIP_CURVEFIT` vs `FM_CURVEFIT`) and **`tau_consensus_methods`** / half_range_primary disclosure.
5. **Track A summaries**: still **no default tau_input** without adapter (unchanged governance).

## Recommended next safe step

**`DRAFT_DEFINITION_CONTRACT_WITH_BRANCH_QUALIFIERS_AND_TAU_METADATA_GATE`** — encode F7X4 tables as normative rows; do **not** promote bare `tau_effective_seconds` or `background` to primary keys without qualifiers.

## Deliverables

| Artifact |
|----------|
| `reports/aging/aging_F7X4_definition_gap_resolution.md` |
| `tables/aging/aging_F7X4_gap_resolution_matrix.csv` |
| `tables/aging/aging_F7X4_dM_deltaM_signed_resolution.csv` |
| `tables/aging/aging_F7X4_background_baseline_resolution.csv` |
| `tables/aging/aging_F7X4_derivative_branch_resolution.csv` |
| `tables/aging/aging_F7X4_fit_stage_boundary_resolution.csv` |
| `tables/aging/aging_F7X4_tau_effective_seconds_resolution.csv` |
| `tables/aging/aging_F7X4_stage_boundary_map.csv` |
| `tables/aging/aging_F7X4_contract_readiness_update.csv` |
| `tables/aging/aging_F7X4_status.csv` |

## Cross-module

**No** Switching, Relaxation, or MT edits — new Aging survey files only.
