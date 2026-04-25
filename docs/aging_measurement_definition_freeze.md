# Aging measurement definition freeze and dataset contract (Stage D)

**Scope:** documentation and tabular contracts only. No analysis, plotting, or config code was modified. No producer implementation and no scientific reruns were performed. This document follows `docs/repo_execution_rules.md` for future execution expectations.

## Executive summary

This stage **freezes measurement semantics** for (a) **Track A / BR_STAGE56** summary observables and (b) **Track B–style** stage4 scalar fields that feed the **legacy five-column** `aging_observable_dataset.csv` **reader contract**. The file `aging_observable_dataset.csv` is **not** treated as an existing source of truth; it is defined as a **downstream consolidation contract** to be rebuilt from **candidate structured outputs**, preferably `observable_matrix.csv` / `observables.csv` from `aging_structured_results_export.m` (via `buildObservableMatrix`).

The **missing implementation** remains a **thin consolidation** plus a **`source_run` policy** (later task, not done here).

## Separation of Track A vs Track B

**Track A (summary / fit contract, default `Main_Aging` path per `stage6_extractMetrics.m`):**

- `AFM_like` is defined from **`Dip_area_selected`** (Gaussian / fit-area lineage).
- `FM_like` is defined from **`FM_E`** (tanh-step RMS on fit window).

These are **explicitly not** the same objects as stage4 **`dip_signed` / `FM_signed`** fields (`stage6_extractMetrics.m` header comments).

**Track B–style (stage4 scalar contract for the consolidation dataset):**

- **`Dip_depth`**, **`FM_abs`**, **`FM_step_mag`** (pipeline field), **`AFM_RMS`**, **`FM_signed`**, etc., come from **decomposition / plateau** logic in **`stage4_analyzeAFM_FM.m`** and **`analyzeAFM_FM_components.m`** (or derivative mode in **`analyzeAFM_FM_derivative.m`**), not from substituting **`Dip_area_selected`** or **`FM_E`**.

**Rule:** do **not** equate Track A and Track B names when building or auditing the consolidation CSV.

## Definition freeze table

Authoritative rows: `tables/aging/aging_measurement_definition_freeze.csv`.

Highlights:

| Name | Role |
|------|------|
| `Dip_depth` | Consolidation **`Dip_depth`** = stage4 **`Dip_depth`** semantics; **not** `Dip_area_selected`. |
| `FM_abs` | Magnitude **`abs(FM_signed)`** after stage4 assigns **`FM_signed`** from **`FM_step_raw`** (preferred) or **`FM_step_mag`** fallback. |
| `FM_step_mag` | **Signed** step stored under a **misleading** `_mag` name in direct path (equals **`FM_step_raw`**); **not** in the five-column reader contract. |
| `AFM_like` / `FM_like` | Track A summary only; **out of scope** for the five-column CSV contract. |

Code anchors:

```35:47:Aging/pipeline/stage6_extractMetrics.m
% AFM_like:
%   - defined as Dip_area_selected
%   - currently sourced from Dip_area_fit (Gaussian fit)
%
% FM_like:
%   - defined as FM_E
%   - derived from tanh step fit
%
% IMPORTANT:
%   - These are fit-derived observables.
%   - They are NOT the same as:
%       dip_signed (stage4)
%       FM_signed  (stage4)
```

```148:152:Aging/analysis/aging_structured_results_export.m
obsMatrixTbl = buildObservableMatrix(curves);
obsExportTbl = removevars(obsMatrixTbl, {'FM_step_mag'});
writetable(obsExportTbl, fullfile(run_output_dir, 'observables.csv'));
fprintf('Saved table: %s\n', fullfile(run_output_dir, 'observables.csv'));
save_run_table(obsMatrixTbl, 'observable_matrix.csv', run_output_dir);
```

## `aging_observable_dataset.csv` contract

Authoritative table: `tables/aging/aging_observable_dataset_contract.csv`.

**Frozen reader contract (five columns):**

1. `Tp` — pause temperature (K), rename from `Tp_K` in structured wide tables.
2. `tw` — wait time (s), rename from `tw_seconds`.
3. `Dip_depth` — stage4-style dip scalar as exported in structured tables; **never** mapped from `Dip_area_selected` / `AFM_like`.
4. `FM_abs` — stage4 magnitude metric; **never** mapped from `FM_E` / `FM_like`.
5. `source_run` — provenance string per **`source_run` policy** below.

**`FM_step_mag`:** **Excluded** from this five-column contract. It remains available in **`observable_matrix.csv`** for diagnostics; name/sign semantics are **not** “magnitude” unless separately proven and documented.

## Mapping from structured outputs

Authoritative table: `tables/aging/aging_dataset_mapping_from_structured_outputs.csv`.

Minimum frozen transforms:

| Contract column | Preferred source |
|-----------------|------------------|
| `Tp` | `Tp_K` |
| `tw` | `tw_seconds` |
| `Dip_depth` | `Dip_depth` |
| `FM_abs` | `FM_abs` |
| `source_run` | Derived from **`run_manifest.json`** `run_id` plus row disambiguators (`sample`, `dataset`) — see policy |

## `source_run` policy (frozen)

**Purpose:** readers treat `source_run` as an opaque grouping key (see `aging_timescale_extraction.m`).

**Preferred encoding (recommended for the future producer):**

`source_run = sprintf('%s|%s|%s', manifest_run_id, sample_id, dataset_key)`

where:

- `manifest_run_id` is read from the **structured export** run directory’s `run_manifest.json` (`run_id` field) that emitted the `observable_matrix.csv` row, and  
- `sample_id` and `dataset_key` are taken from the **`sample`** and **`dataset`** columns of **`observable_matrix.csv`** for that row.

**Rules:**

- The string MUST be stable across re-runs that intend to reproduce the same logical row.
- Do not overload `source_run` with physics units or numeric temperatures.
- If a row is synthetic or repaired, use an explicit prefix `SYNTHETIC|` only if policy-approved.

**Risk:** `FM_plateau_valid` and related validity are **not** in the five-column contract; for FM-heavy analyses consider a **future companion CSV** (out of scope for the reader contract but recommended in `aging_observable_dataset_contract.csv`).

## Warning: `FM_step_mag` naming

In the direct decomposition path, **`FM_step_mag` is assigned the signed raw step** (same as **`FM_step_raw`**), not `abs(...)`. Treat the column name as **legacy**; consult `analyzeAFM_FM_components.m` before any rename in code (forbidden in Stage D).

## Implications for old analyses

- **Interpretation:** Old tau / clock / collapse scripts that read the five-column file are **interpretable** under this freeze: they consume **`Dip_depth` / `FM_abs`** with the **stage4** meanings above, not Track A summaries.
- **Reproducibility:** Numeric replay of **historical** outputs is **not** claimed until the **thin producer** exists and inputs (cfg snapshots, structured runs) are aligned.
- Matrix: `tables/aging/aging_analysis_unblock_matrix.csv`.

## Implications for Paper 1 direct figures

Per `tables/aging/aging_old_analysis_usage_inventory.csv` (e.g. ANA024–ANA025), **Paper 1–style direct scripts** targeted **`Main_Aging`** `pauseRuns` fields such as **`AFM_RMS`** / **`FM_signed`**, **not** the consolidated `aging_observable_dataset.csv`. This contract **does not block** those scripts by definition; they remain subject to their own cfg / pipeline audits.

## Implications for Switching cross-analysis

Scripts that **read** the consolidated dataset for the Aging side (e.g. `analysis/aging_fm_switching_sector_link.m`) remain **blocked on disk artifact + producer** until the consolidation exists. Scripts that only need **`observable_matrix.csv`** from a structured export follow the **mapping table** and a separate manifest policy.

## Exact next implementation task (out of scope for Stage D)

1. Add a **single MATLAB entry script** (new file, not done here) that:  
   - Reads **`observable_matrix.csv`** (and `run_manifest.json`) from a chosen **structured export** run directory,  
   - Applies the **rename map** (`Tp_K`→`Tp`, `tw_seconds`→`tw`),  
   - Copies **`Dip_depth`** and **`FM_abs`** without reinterpretation,  
   - Emits **`aging_observable_dataset.csv`** with the **five-column** contract,  
   - Optionally emits **`aging_observable_dataset_sidecar.csv`** with `FM_plateau_valid`, `Dip_depth_source`, etc.  
2. Run it **only** via `tools/run_matlab_safe.bat` with a recorded cfg snapshot per `docs/repo_execution_rules.md`.

## Verdict block (required)

| Key | Verdict |
|-----|---------|
| `AGING_MEASUREMENT_FREEZE_CREATED` | **YES** |
| `TRACK_A_TRACK_B_DISTINCT` | **YES** |
| `AGING_OBSERVABLE_DATASET_DEFINED_AS_CONTRACT` | **YES** |
| `AGING_OBSERVABLE_DATASET_EXISTING_SOT` | **NO** |
| `DIP_DEPTH_CONTRACT_FROZEN` | **YES** |
| `FM_ABS_CONTRACT_FROZEN` | **YES** |
| `FM_STEP_MAG_EXCLUDED_OR_WARNED` | **YES** |
| `TP_TW_MAPPING_FROZEN` | **YES** |
| `SOURCE_RUN_POLICY_DEFINED` | **YES** |
| `OLD_ANALYSES_INTERPRETABLE_AFTER_CONSOLIDATION` | **PARTIAL** |
| `PAPER1_DIRECT_FIGURES_UNBLOCKED` | **YES** |
| `READY_FOR_THIN_CONSOLIDATION_PRODUCER` | **YES** |
| `READY_FOR_ROBUSTNESS_AUDIT` | **PARTIAL** |
| `READY_FOR_SWITCHING_CROSS_ANALYSIS` | **PENDING** |

## Related artifacts

- `tables/aging/aging_measurement_definition_freeze.csv`
- `tables/aging/aging_observable_dataset_contract.csv`
- `tables/aging/aging_dataset_mapping_from_structured_outputs.csv`
- `tables/aging/aging_analysis_unblock_matrix.csv`
- Prior lineage: `reports/aging/aging_observable_dataset_deep_lineage_recovery.md`
- Optional cross-read: `docs/aging_observable_contract.md` (if present; do not override this Stage D freeze without a new stage).

## Next recommended stage

**E — Thin consolidation producer implementation + one reference run** (emit CSV, manifest, and optional sidecar; validate against `harness_aging_dataset_ok` and one reader smoke path), executed strictly through `tools/run_matlab_safe.bat`, followed by a **robustness audit** once a frozen reference artifact exists.
