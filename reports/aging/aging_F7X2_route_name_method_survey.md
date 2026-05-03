# Aging F7X2 — Route / component name and method survey (pre-contract)

Read-only **survey and recommendation package**. This deliverable **does not** write a naming contract, select final aliases, rename code identifiers, modify F7W/F7X committed artifacts beyond this new F7X2 namespace, or execute MATLAB/Python/replay/tau/ratio work. Repository execution hygiene for any future runs remains [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

## Purpose

Inventory **active Aging observable routes** (decomposition producers, materialization sinks, tau extractors, ratio combinators) and relate them to **existing human-facing names** (`Track A`/`Track B`, stage4/stage5/stage6 fields, consolidation columns, tau CSVs, `R_age`). The user requested understanding of what names *should* encode **before** any contract — so this file ends with **candidate naming styles and open questions**, not verdict tables that lock vocabulary.

## Why no contract was written yet

A contract would prematurely **freeze identifiers** while several dimensions remain **partially observed** across branches: `cfg.agingMetricMode` routes multiple decomposition families; consolidation **drops** signed FM channels; `FM_step_mag` carries **signed** semantics under a **misleading** suffix; tau outputs are **separate artifacts** with their own metadata and lineage gates (`F7G`/`F7I` narratives). Writing a contract now would risk encoding **false equivalences** (Track A vs Track B, tau vs decomposition, ratio vs raw scalar) that governance documents already forbid.

## Why `Track A` / `Track B` are insufficient as primary names

- **Track A** (`docs/aging_observable_branch_router.md`, `stage6_extractMetrics.m` headers) denotes **fit-summary** vectors (`AFM_like` from `Dip_area_selected`, `FM_like` from `FM_E`). It does **not** specify Gaussian vs extrema selection details unless one reads stage6 branches, and it carries **`PER_TP_SUMMARY_ONLY`** grain — different from **`TW_CURVE_PER_TP`** consolidation readers used by tau scripts on `Dip_depth`/`FM_abs`.
- **Track B** denotes **stage4-style** scalars and the **five-column** consolidation reader contract (`docs/aging_measurement_definition_freeze.md`). It does **not** encode whether the upstream stage4 branch was **direct**, **derivative**, or **extrema_smoothed**, nor whether `Dip_depth` was filled via **`AFM_amp`** fallback (`Dip_depth_source` in `stage4_analyzeAFM_FM.m`).
- Therefore **track labels are routing shorthand**, not sufficient **machine identities** for bridge rows, tau pairing, or multipath robustness (see `tables/aging/aging_F7U_decomposition_tau_compatibility_matrix.csv` and F7V forbidden substitutions).

## Why component names should encode **both** decomposition method **and** tau method (when tau exists)

- **Decomposition** answers *how a scalar was formed from \(\Delta M\)* (direct window split, derivative-assisted fields, extrema on smoothed curves, Gaussian/tanh fits, or **consolidation-only** identity mapping).
- **Tau** answers *how a time-scale was inferred from a curve or table* (log-time **curve-fit zoo** including half-range variants in `aging_timescale_extraction.m` / `aging_fm_timescale_analysis.m`, rescaling optimizer, or **none** for summary vectors until a chartered adapter exists — `tables/aging/aging_F7V_tau_readiness_by_component_path.csv`).
- **Re-using the same column name** (`Dip_depth`, `FM_abs`) across export and tau reader without also stating **tau_method** invites treating **tau outputs** as if they were **native pauseRun fields** (risk row `RISK_TAU_NOT_DECOMP` in `tables/aging/aging_F7X2_name_confusion_risk_inventory.csv`).
- **Ratios** (`R_age` via `aging_clock_ratio_analysis.m`) are **downstream combinators** on **prior tau CSVs**, not decomposition products — naming should keep that layer visible.

## Active route / name families found (high level)

| Family | Representative names | Producer / sink | Decomposition class (survey label) |
|--------|------------------------|-------------------|-------------------------------------|
| Stage4 direct core | `dip_signed`, `DeltaM_smooth`, `AFM_amp`, `AFM_area`, `FM_step_raw`, `FM_step_mag`, `FM_signed`, `FM_abs` | `analyzeAFM_FM_components.m` via `stage4_analyzeAFM_FM.m` when `agingMetricMode` in `direct`/`model`/`fit` | Direct / window metrics |
| Stage4 router fills | `Dip_depth`, `Dip_depth_source`, `Dip_area`, `Dip_area_direct` | `stage4_analyzeAFM_FM.m` post-pass | Orchestrator binding / diagnostics |
| Stage4 derivative | derivative pauseRun fields | `analyzeAFM_FM_derivative.m` | Derivative-assisted |
| Stage4 extrema | `AFM_extrema_smoothed`, `FM_extrema_smoothed` | `analyzeAFM_FM_extrema_smoothed.m` | Extrema-based |
| Stage5 fit | `Dip_area_fit`, `Dip_area_selected`, `FM_E` | `stage5_fitFMGaussian.m` | Fit |
| Stage6 Track A summary | `AFM_like`, `FM_like` | `stage6_extractMetrics.m` | Fit-summary |
| Structured export | `observable_matrix.csv`, `observables.csv`, `Dip_depth`, `FM_abs`, `FM_step_mag` | `aging_structured_results_export.m` | Materialization (mixed sign policies) |
| Thin consolidation | `aging_observable_dataset.csv` (`Tp`,`tw`,`Dip_depth`,`FM_abs`,`source_run`) | `run_aging_observable_dataset_consolidation.m` | Consolidation-only |
| F7X bridge long/index | `C_DIP_DEPTH_B`, `C_FM_ABS_B`, `STREAM_*` | Bridge tables in `tables/aging/aging_F7X_*.csv` | `CONSOL_EXPORT` slice in current implementation |
| Tau dip | `tau_vs_Tp.csv`, `tau_effective_seconds` (+ metadata) | `aging_timescale_extraction.m` | Curve-fit on `Dip_depth` vs `tw` |
| Tau FM | `tau_FM_vs_Tp.csv` | `aging_fm_timescale_analysis.m` | Curve-fit on `FM_abs` vs `tw` (+ aux inputs) |
| Ratio | `R_age`, `table_clock_ratio.csv` | `aging_clock_ratio_analysis.m`, `aging_clock_ratio_temperature_scaling.m` | Downstream from tau tables |

## Tau methods and which routes they apply to

Authoritative survey rows: `tables/aging/aging_F7X2_tau_method_inventory.csv` (extends F7J/F7U inventories).

- **Dip curve-fit family** applies to **`Dip_depth` vs `tw` curves** from the consolidated dataset path expected by `aging_timescale_extraction.m` — **not** to `AFM_like` / `Dip_area_selected` without a new reader/adapter (`F7U` compatibility `CX004`).
- **FM curve-fit family** applies to **`FM_abs` vs `tw` curves** on the same consolidation contract — **not** to `FM_signed` by default (`TAU_NONE_FM_SIGNED_DEFAULT` row) and **not** to `FM_like` without adapter (`CX003`).
- **Stage4** itself writes **no** `tau_vs_Tp` columns; any **half-range** or logistic column lives in **tau output tables**, not in pauseRun decomposition outputs.
- **Clock ratio** scripts consume **prior** `tau_vs_Tp` / `tau_FM_vs_Tp` artifacts; they do not re-derive \(\tau\) from raw \(\Delta M\) in the surveyed path.

## Misleading or high-risk names (observed)

- **`FM_step_mag`**: `_mag` suggests magnitude; freeze and router state **signed plateau raw** semantics in the direct path (`docs/aging_measurement_definition_freeze.md`).
- **`FM_abs`**: name is honest about `abs`, but analysts may still treat it as a stand-in for **signed FM physics** — impossible for reversal claims (`FM_short_tw` policy tables).
- **`tau_effective_seconds`**: **legacy alias** on both dip and FM tau tables; requires **F7G metadata** to know domain (`semantic_status` fields in writer structs in `aging_timescale_extraction.m` / `aging_fm_timescale_analysis.m`).
- **`C_DIP_DEPTH_B` / `C_FM_ABS_B`**: compact bridge ids — **do not** encode derivative vs direct, nor tau method (`reports/aging/aging_F7X_bridge_export_implementation.md` uses consolidation-only sources for populated rows).
- **`cfg.agingMetricMode` values `direct` / `model` / `fit`**: all route into **`analyzeAFM_FM_components`** in `stage4_analyzeAFM_FM.m` — easy to confuse with **stage5** nonlinear **fit** unless readers distinguish **stage4 direct family** vs **stage5 Gaussian/tanh fit**.

## Naming dimensions that appear necessary

See `tables/aging/aging_F7X2_candidate_naming_dimensions.csv` for machine-readable rows. Minimum set suggested by repo evidence:

1. **component_role** — dip vs FM vs ratio vs summary.
2. **source_field** vs **source_artifact** — pauseRuns vs CSV column vs tau file.
3. **decomposition_class** and **decomposition_method** — direct / derivative / extrema / fit / consolidation / bridge / downstream.
4. **sign_or_magnitude_policy** — especially FM surfaces (`SIGN_PRESERVED` vs `ABS_ONLY` vs misleading legacy).
5. **scalar_type** — depth vs area vs energy-window vs plateau step (`F7W` schema echoes).
6. **grain/grid** — `TW_CURVE_PER_TP` vs `PER_TP_SUMMARY_ONLY` (`F7U`/`F7W` guardrails).
7. **tau_status** and **tau_method** — separate from decomposition; `NO_TAU` vs `CURVEFIT_*` vs `CLOCK_RATIO`.
8. **lineage_status** — `COMPLETE` vs `PARTIAL` vs metadata pending strings (`F7X` long table uses `PARTIAL` lineage on sample rows).

## Candidate naming styles (non-final)

Illustrative pipe-strings (all **`CANDIDATE_ONLY`** in `tables/aging/aging_F7X2_candidate_display_names.csv`):

- `Dip_depth | decomp=stage4-direct-or-orchestrator-fallback | tau=dip-curvefit-downstream`
- `FM_abs | decomp=stage4-abs(FM_signed) | tau=FM-curvefit-downstream | sign=ABS_ONLY`
- `tau_dip_curvefit | input=Dip_depth | tau=curvefit | artifact=tau_vs_Tp.csv`
- `tau_FM_abs_curvefit | input=FM_abs | tau=curvefit | artifact=tau_FM_vs_Tp.csv`
- `R_age | input=tau_FM/tau_dip | ratio=downstream | artifact=table_clock_ratio.csv`

**Machine ids** should likely carry opaque **`decomposition_path_id`** (as F7X index already does) plus **producer tokens**, rather than trying to compress physics into short literals.

## Open questions before a future naming contract

1. **Canonical display string grammar**: pipes vs structured JSON vs fixed-column side tables (bridge long already uses wide columns — duplication risk vs human readability).
2. **`Dip_depth_source` in consolidation**: will five-column contract remain strict five columns with **mandatory sidecar** for source and plateau validity, or will contract widen?
3. **Track A tau adapters**: chartered path for `AFM_like`/`FM_like` **vs `tw`** if ever required for tau readers, or explicit **no tau** classification forever (`F7V` `NO_TRACK_A_READER`).
4. **`FM_step_mag` rename**: requires coordinated code + freeze + export regeneration policy — not a documentation-only rename.
5. **`agingMetricMode` vocabulary**: should `model`/`fit` strings be deprecated in favor of explicit `stage4_direct_family` token separate from `stage5_fit_invoked` boolean?
6. **F7X placeholder streams** with `n_rows_available=0`: naming policy when a component is **disclosed but not materialized** in a given bridge run.
7. **Environment overrides**: `AGING_OBSERVABLE_DATASET_PATH` changes effective identity of `Dip_depth`/`FM_abs` rows — how to embed pointer + hash in `source_run` without overloading semantics (`freeze` `source_run` policy).

## Deliverables (this survey)

| Artifact | Role |
|----------|------|
| `tables/aging/aging_F7X2_existing_route_name_inventory.csv` | Row-level inventory of required names + decomposition/tau/sign knowledge flags |
| `tables/aging/aging_F7X2_decomposition_method_inventory.csv` | Producer methods from stage4 through bridge |
| `tables/aging/aging_F7X2_tau_method_inventory.csv` | Tau/ratio/downstream methods and applicability |
| `tables/aging/aging_F7X2_name_confusion_risk_inventory.csv` | Documented confusion patterns and possible resolutions |
| `tables/aging/aging_F7X2_candidate_naming_dimensions.csv` | Dimensions for a future contract |
| `tables/aging/aging_F7X2_candidate_display_names.csv` | Example display/machine strings (`CANDIDATE_ONLY`) |
| `tables/aging/aging_F7X2_survey_status.csv` | Machine-readable survey completion flags |

## Evidence anchors (non-exhaustive)

- Governance: `docs/aging_observable_branch_router.md`, `docs/aging_measurement_definition_freeze.md`, `docs/aging_canonicalization_roadmap.md`
- F7J/F7U/F7V/F7W/F7X tables and reports cited inline above
- Code read as text only: `stage4_analyzeAFM_FM.m`, `analyzeAFM_FM_components.m` (headers), `stage5_fitFMGaussian.m` (header), `stage6_extractMetrics.m` (header), `aging_structured_results_export.m` (entry), `run_aging_observable_dataset_consolidation.m` (entry), `aging_timescale_extraction.m`, `aging_fm_timescale_analysis.m`, `aging_clock_ratio_analysis.m`

## Principle reaffirmed

**Survey only** — clarity and comparability without selecting a single physics-canonical branch.
