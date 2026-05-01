# Aging observable branch router

This document is **governance and routing only**. It does not change code, configs, formulas, or defaults. Execution hygiene for runnable work remains in [`repo_execution_rules.md`](repo_execution_rules.md).

**Principle:** The Aging module supports **multiple observable-definition branches** at once. Here, **canonical** means **controlled, documented, and comparable** — **not** one final physics truth. Use this router to pick an **existing** branch that matches your question; do not collapse branches into winner/loser lists without explicit, staged science gates.

---

## Quick decision table

| User question | Recommended branch | Primary field(s) | Artifact / script | FM sign visible? | Fit / direct | Allowed claim class (see §9) |
|---------------|-------------------|------------------|-------------------|------------------|--------------|------------------------------|
| I need **current five-column tau input** (`Dip_depth` / `FM_abs` readers) | Thin consolidation + upstream structured export | `Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run` | `tables/aging/aging_observable_dataset.csv` from `run_aging_observable_dataset_consolidation.m`; sources `observable_matrix.csv` via pointer | **No** (magnitude `FM_abs` only) | **Direct** rename/filter (non-fit) | Pipeline validation + exploration **if** lineage pointer OK; metadata verification **pending** F7I-style gates |
| I need **signed FM / short-tw sign reversal** | Wide structured export + optional F3b audit | `FM_signed` on pauseRuns; **`FM_step_mag`** in matrix (signed semantics); F3b uses matrix + sidecar audit | `observable_matrix.csv` from `aging_structured_results_export.m`; `run_aging_F3b_FM_signed_short_tw_rescue.m` | **Yes** at matrix / audit layers | Direct plateau extraction upstream; audit is non-fit join | Sign audit / diagnostics; **not** interchangeable with five-column tau CSV |
| I need **Track A summary figures** (`Y_AFM`, `Y_FM` style) | Track A stage6 summaries | `AFM_like`, `FM_like`; upstream `Dip_area_selected`, `FM_E` | `stage6_extractMetrics.m` / `Main_Aging.m` path | N/A (summary magnitudes) | **Fit-heavy** (dip area / tanh RMS lineage) | Summary semantics + high-level trends; **do not** alias to `Dip_depth`/`FM_abs` |
| I need **direct dip/background decomposition** on \(\Delta M(T)\) | Stage4 **direct** mode | `DeltaM_smooth`, `DeltaM_sharp`, `dip_signed`, `AFM_amp`, `FM_step_raw`, `FM_signed`, `AFM_RMS` | `analyzeAFM_FM_components.m` via `stage4_analyzeAFM_FM.m` when `cfg.agingMetricMode` is `direct`/`model`/`fit` (direct family) | **Yes** (`FM_signed`) | **Direct** window metrics | Physical exploration at pause-run grain; document cfg windows |
| I need **derivative-assisted** branch | Stage4 **derivative** mode | Derivative-assisted fields on `pauseRuns` | `analyzeAFM_FM_derivative.m` via `stage4_analyzeAFM_FM.m` | Signed FM per helper outputs | Mixed derivative pipeline | Alternate decomposition diagnostics |
| I need **extrema_smoothed** branch | Stage4 **extrema** mode | `AFM_extrema_smoothed`, `FM_extrema_smoothed` | `analyzeAFM_FM_extrema_smoothed.m` via `stage4_analyzeAFM_FM.m` | Extrema magnitudes | Direct features on smoothed curves | Track A feed when mode active; distinct from residual `Dip_depth` |
| I need **Gaussian dip / tanh FM fits** (Track A inputs) | Stage5 fits | `Dip_area_fit`, `FM_E`, dip area selections | `stage5_fitFMGaussian.m` | Fit magnitudes | **Fit** | Track A summary path; not consolidation `Dip_depth` |
| I need **wide matrix with diagnostics** | Structured export | Full scalar grid per export run | `observable_matrix.csv`; narrowed `observables.csv` drops `FM_step_mag` | Wide: **yes** for signed plateau column family; narrow: **sign dropped** | Carries computed scalars | Materialization for audits / SVD / mode joins |
| I need **old replay / archival parity** | Dataset + script tagged replay | varies | `results_old/...` snapshots; F6-family replay scripts; **always** pair with manifest / contract tables | Depends on artifact | Depends on replay | Parity / forensic claims only with explicit pairing rules |
| I need **`R_age` clock ratio** \(\tau_{FM}/\tau_{dip}\) | Clock-ratio downstream | Prior `tau_vs_Tp.csv`, `tau_FM_vs_Tp.csv` inputs | `aging_clock_ratio_analysis.m`, `aging_clock_ratio_temperature_scaling.m` | N/A at raw FM layer | Combines **prior tau tables** + regression fits on ratio | Comparative analysis **if** tau files lineage-locked |
| I need **paper-candidate physical trend** | **No single router row** — compare branches deliberately | Branch-specific | Multiple | Branch-specific | Mixed | **Future work:** paper-ready requires locked lineage + explicit branch comparison — not implied by this doc |

---

## Branch summaries (minimum set)

### Track A stage6 summaries: `AFM_like` / `FM_like`

- **Measures:** Summary vectors per pause temperature for default Main_Aging-style outputs.
- **Producer:** `stage6_extractMetrics.m` — `AFM_like` from `Dip_area_selected`; `FM_like` from `FM_E`.
- **Artifact:** In-memory / pipeline outputs tied to `Main_Aging.m` summary path.
- **Fit vs direct:** **Fit-derived** summaries (not raw stage4 dip_signed).

### Stage4 direct core: `Dip_depth`, `FM_signed`, `FM_abs`, baseline fields

- **Measures:** Residual dip height / plateau FM step from \(\Delta M\) decomposition.
- **Producer:** `analyzeAFM_FM_components.m` orchestrated by `stage4_analyzeAFM_FM.m`.
- **FM:** `FM_signed` from `FM_step_raw` (preferred) or step fallback; **`FM_abs = abs(FM_signed)`** when finite.
- **Dip:** `Dip_depth` may follow `AFM_amp` residual path; `Dip_depth_source` documents branch on `pauseRuns`.

### Stage4 derivative branch

- **Router:** `cfg.agingMetricMode = 'derivative'` in `stage4_analyzeAFM_FM.m`.
- **Producer:** `analyzeAFM_FM_derivative.m` — derivative-assisted scalars (distinct from direct plateau split).

### Stage4 `extrema_smoothed` branch

- **Router:** `cfg.agingMetricMode = 'extrema_smoothed'`.
- **Producer:** `analyzeAFM_FM_extrema_smoothed.m` — extrema on smoothed curves; feeds stage6 extrema pathway.

### Stage5 Gaussian / tanh fit branch

- **Producer:** `stage5_fitFMGaussian.m`.
- **Outputs:** Dip area metrics and `FM_E` (tanh-window RMS style) used by Track A summaries — **not** the consolidation `Dip_depth`/`FM_abs` contract.

### Structured export wide matrix: `observable_matrix.csv`

- **Producer:** `aging_structured_results_export.m`.
- **Contains:** `Dip_depth`, `FM_abs`, **`FM_step_mag`** (signed plateau raw per measurement freeze), auxiliary columns.
- **`observables.csv`:** Narrow export **strips** `FM_step_mag` — sign easily **lost** unless joined back to the matrix.

### Five-column consolidation: `aging_observable_dataset.csv`

- **Producer:** `run_aging_observable_dataset_consolidation.m`.
- **Contract:** Five columns only — **`FM_abs` magnitude**, **no** `FM_signed`.
- **Pointer:** `tables/aging/consolidation_structured_run_dir.txt` selects structured-export input.

### F3b short-tw signed FM audit branch

- **Script:** `run_aging_F3b_FM_signed_short_tw_rescue.m`.
- **Role:** Audits **sign** via **`FM_step_mag`** on a short-\(t_w\) grid (e.g. 3 s), compares to sidecar audit columns — **parallel** to five-column reader contract.

### Low-T 6/10 K FM diagnostic branch

- **Script:** `run_aging_lowT_6_10_fm_fit_vs_direct_diagnostic.m`.
- **Role:** Explains **`FM_abs` NaN** vs finite `Dip_depth` at low \(T_p\) (plateau/window validity), not a replacement definition.

### Tau Dip multi-curve-fit family

- **Script:** `aging_timescale_extraction.m`.
- **Input observable:** **`Dip_depth`** vs `tw` per \(T_p\).
- **Output:** `tau_vs_Tp.csv` with multiple fit summaries + `tau_effective_seconds` legacy column + **F7G metadata** (`WF_TAU_DIP_CURVEFIT`).
- **Metadata:** Pending lineage until dataset + dip branch resolved (F7I/F7H narrative).

### Tau FM multi-curve-fit family

- **Script:** `aging_fm_timescale_analysis.m`.
- **Input observable:** **`FM_abs`** only (magnitude).
- **Output:** `tau_FM_vs_Tp.csv` + **F7G metadata** (`WF_TAU_FM_CURVEFIT`).

### `R_age` / clock-ratio downstream branch

- **Scripts:** `aging_clock_ratio_analysis.m`, `aging_clock_ratio_temperature_scaling.m`.
- **Inputs:** Prior **`tau_vs_Tp`** / **`tau_FM_vs_Tp`** artifacts — **not** raw \(\Delta M\).
- **Metadata:** `WF_CLOCK_RATIO_R_AGE`; pairing and lineage gates apply.

---

## FM sign visibility matrix

| Statement | Notes |
|-----------|--------|
| **`FM_signed` preserves sign** | On `pauseRuns` after stage4 assignment (`FM_step_raw` preferred). |
| **`FM_step_mag` in `observable_matrix.csv` is signed** | Despite **`_mag` in the name**, measurement freeze treats it as **signed plateau raw** in the direct path — **do not** assume magnitude-only from the label alone. |
| **`FM_abs` collapses sign** | **`abs(FM_signed)`** when finite — **no reversal story**. |
| **Five-column `aging_observable_dataset.csv`** | **`FM_abs` only** — **cannot** encode short-\(t_w\) FM **sign reversal** as a distinct observable column. |
| **`aging_fm_timescale_analysis`** | Reads **`FM_abs` only** — **sign reversal invisible** at tau-ingest layer. |
| **Short-\(t_w\) sign reversal tracing** | Use **`FM_signed`**, **`FM_step_mag`** (matrix), **`run_aging_F3b_...`**, or sidecar **`fm_step_mag_audit_signed_per_input_only`** when present — not the five-column file alone. |

---

## Dataset branch coverage (metadata level)

Summarized from `tables/aging/aging_F7J_dataset_branch_coverage_comparison.csv` and F7I audit:

| Dataset surrogate | Rows | \(T_p\) (K) | \(t_w\) (s) | FM in CSV |
|-------------------|------|-------------|-------------|-----------|
| Current workspace consolidation `tables/aging/aging_observable_dataset.csv` | 22 | **14, 18, 22, 26, 30, 34** | **3, 36, 360, 3600** | **`FM_abs` only** (magnitude) |
| Historical `results_old/.../aging_observable_dataset.csv` snapshot | 30 | Adds **6, 10** plus same upper grid | Same \(t_w\) grid | **`FM_abs` only**; some rows may have **NaN `FM_abs`** |

**No physics winner is selected here.** Dataset branch choice changes **coverage** and **which claims** are even meaningful (low-\(T\) rows, NaN handling).

---

## Fit vs direct map

| Kind | Examples |
|------|----------|
| **Direct / non-fit stage4 scalars** | Residual dip metrics, plateau FM step, consolidation rename-only |
| **Fit-heavy Track A** | `Dip_area_selected`, `FM_E`, Gaussian dip, tanh RMS window |
| **Tau curve-fit families** | Logistic / stretched / half-range summaries in `aging_timescale_extraction`, `aging_fm_timescale_analysis` |
| **Downstream ratio / regression** | Clock ratio and temperature scaling on **prior tau CSVs** |
| **Optimizer / rescaling** | `aging_time_rescaling_collapse.m` (rescaling tau family) |

---

## Proposed config taxonomy (documentation only)

The following keys are **names for future routing** — **not** implemented as a unified config object today. Source: `tables/aging/aging_F7J_config_taxonomy_proposal.csv`.

| Key | Role |
|-----|------|
| `observable_branch` | Track A vs Track B vs derivative vs extrema vs consolidation-only workflows |
| `dip_extraction_method` | Residual vs derivative vs extrema naming; ties to `cfg.AFM_metric_main`, windows |
| `background_method` | Smoothing / baseline conventions (`smoothWindow_K`, baseline fields) |
| `fm_signal_mode` | Signed vs magnitude vs export-wide vs narrow strip |
| `fm_short_tw_policy` | `excludeLowT_*`, `FM_plateau_K`, plateau validity interplay |
| `tau_method` | Dip vs FM vs rescaling vs clock-ratio downstream |
| `fit_family` | Gaussian/tanh vs logistic tau fits vs power laws on ratios |
| `direct_tau_method` | Half-range vs consensus tie-break inside extraction scripts |
| `dataset_source_branch` | Which structured export / consolidation pointer |
| `lineage_policy` | F7G metadata gates (`canonical_status`, `model_use_allowed`, etc.) |

---

## Allowed claims (classes)

Use **`tables/aging/aging_F7J_allowed_claims_map.csv`** for branch-by-branch detail. High-level classes:

| Class | Meaning |
|-------|---------|
| **Metadata verification** | F7G/F7H-style CSV metadata checks when outputs exist and lineage is wired |
| **Replay parity** | Historical / F6-style comparisons with explicit artifact pairing |
| **Pipeline validation** | Reader smoke, consolidation contract, cfg-path sanity |
| **Physical trend exploration** | Hypothesis-driven analysis with branch labels documented |
| **Paper-ready candidate** | **Not auto-selected** — requires locked lineage + explicit branch comparison plan |
| **Blocked / pending lineage** | Default for many tau/R outputs until dataset + dip/FM branch resolution |
| **Unclear** | Stop and resolve naming / pointer / manifest identity |

**Paper-ready selection is future work**, not implied by choosing one branch in this router.

---

## Known risks / do not confuse

- **Track A `AFM_like` / `FM_like`** are **not** **`Dip_depth` / `FM_abs`** (consolidation Track B contract).
- **`FM_step_mag`** naming is **misleading** — value can be **signed** in the direct path.
- **`FM_abs`** cannot represent **sign reversal** by itself.
- **Tau/R CSV outputs** carry F7G metadata but remain subject to **dataset and lineage gates** (F7I/F7H).
- **Repeated historical `run_*` defaults** in scripts are **not** automatic authority — reconcile with `tables/aging` consolidation and **`AGING_OBSERVABLE_DATASET_PATH`** policy when applicable.
- **Absence** of a phenomenon in a branch that **filters**, **collapses sign**, or **drops columns** is **not** proof of absence in the experiment — check branch semantics first.

---

## Next steps

1. **Branch-specific validation:** pick a question row from the quick table, then validate **only** the listed artifacts and lineage surfaces.
2. **Controlled config routing** (future): implement taxonomy keys **only** with explicit mapping tables — **no** duplicate extraction paths without a proven gap (`F7J duplication risk` narrative).
3. **Do not** add parallel numerical extraction methods until a gap is demonstrated **after** this router and existing audits.
4. **Do not** fix the “final paper definition” here — compare branches under recorded cfg and dataset pointers first.

---

## Related artifacts

- [`aging_measurement_definition_freeze.md`](aging_measurement_definition_freeze.md) — Track A vs B freeze.
- [`aging_canonicalization_roadmap.md`](aging_canonicalization_roadmap.md) — F-series governance pointers.
- [`reports/aging/aging_F7J_observable_definition_scope_map.md`](../reports/aging/aging_F7J_observable_definition_scope_map.md) — F7J scope map audit.
- `tables/aging/aging_F7J_*.csv` — inventories and maps referenced above.

---

## Status

Machine-readable completion flags: `tables/aging/aging_F7K_branch_router_status.csv`.
