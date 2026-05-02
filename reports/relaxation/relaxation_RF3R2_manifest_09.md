# RLX-RF3R2-MANIFEST-09 — Relaxation RF3R2 canonical manifest and input-integrity audit

## 1. Purpose and scope

This manifest locks **paths**, **roles**, **column-to-contract mappings**, and **replay gates** for the RF3R2-based Relaxation activity closure chain documented in **RLX-CANONICAL-SURVEY-08A**, **RLX-NAMING-AUDIT-09**, and **CLOSURE-07**. It performs **no new physics**, **no fitting**, **no cross-module joins**, and **no AX or Switching comparisons**.

Inputs were verified **on disk** via CSV headers, row counts (excluding headers where noted), and existing status tables. **Staging index was empty** at task start per repo safety rules.

---

## 2. Input artifacts found / missing

### Found (canonical spine)

| Layer | Path |
|-------|------|
| Time-series grid | `tables/relaxation/relaxation_RF3R2_repaired_curve_samples.csv` (~8838 data rows) |
| Trace metadata | `tables/relaxation/relaxation_RF3R2_repaired_curve_index.csv` (18 data rows) |
| Build provenance | `tables/relaxation/relaxation_RF3R2_repaired_build_status.csv` |
| Scalar bundle | `tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv` (18 data rows) |
| RCON lineage | `tables/relaxation/relaxation_RCON_02B_sources.csv`, `relaxation_RCON_02B_status.csv` |
| **A_T_canon** bridge | `tables/relaxation/relaxation_AT_canon_lineage_06_scalar_table.csv` (8 data rows; strict mask) |
| **A_svd_LOO_canon** inputs | `tables/relaxation/relaxation_activity_representation_02_loo_svd_fold_metrics.csv` (8 data rows) |
| Closure definitions | `tables/relaxation/relaxation_activity_final_closure_07_scalar_dictionary.csv` |

### Missing / not applicable for numeric manifest

| Item | Status |
|------|--------|
| **A_T_old** numeric export | **Absent** — deliberate; lineage forbids numeric reconciliation (see column map) |
| `relaxation_RF3R2_default_replay_temperature_coverage.csv` | **Not present** under this name. **RF3R-era** default-replay coverage **does** exist: `tables/relaxation/relaxation_RF3R_default_replay_temperature_coverage.csv` (and related `relaxation_RF3R_default_replay_*.csv`). Use for **RF3R policy lineage**; canonical **RF3R2** replay gates in this task are taken from **`relaxation_RF3R2_repaired_curve_index.csv`** and **`relaxation_RF3R2_repaired_build_status.csv`**. |

Details: `tables/relaxation/relaxation_RF3R2_manifest_09_artifact_inventory.csv`.

---

## 3. RF3R2 source manifest

**Primary physical input** to the closed curve object: `relaxation_RF3R2_repaired_curve_samples.csv` (long format: time, **delta_m**, per-trace keys), with one row per sample and **trace_id** join to the index.

**Index** `relaxation_RF3R2_repaired_curve_index.csv` supplies **temperature**, trace validity, **valid_for_default_replay**, quality marks, and pointers to the samples table.

**Build identity** (hashes, temperature count 18, exclusion of 35 K, mask policy `sample_index_ge_10`): `relaxation_RF3R2_repaired_build_status.csv`.

**Activity scalars** for amplitude closure: **`relaxation_RCON_02B_Aproj_vs_SVD_score.csv`** — authoritative tabular join key **`temperature_K`** with **`A_obs`** (direct observable column mapped to **`A_obs_canon`** in prose), **`SVD_score_mode1`** / **`m0_svd`** family (**`A_svd_full_canon`** members per closure dictionary), and **`A_proj_nonSVD`** (projection family — distinct alias from pure **`A_svd_canon`** naming family where methodology differs).

**Lineage:** **`relaxation_AT_canon_lineage_06_scalar_table.csv`** defines **`A_T_canon`** (**`A_T_canon_oriented`** preferred for signed story), **`m0_svd`**, **`m0_LOO_SVD_projection`**, **`inclusion_status`** on an **eight-temperature strict subset** of the 18-point ladder.

**Producers (discoverable from tables only):** **`relaxation_RF3R2_repaired_build_status.csv`** records **`SOURCE_RUN_ID`** `run_2026_04_26_234453`, **`RF3R2_BUILD_ID`** `rf3r2_repaired_20260427_193555_src_run_2026_04_26_234453`, and pre/post CSV hashes for curve index and samples. **`relaxation_RCON_02B_sources.csv`** lists upstream tables feeding RCON (including **`relaxation_RF5A_RF3R2_m0_svd_scores.csv`** as external SVD score source reference). Executable MATLAB script paths are **not** rewritten here; see **`Relaxation ver3/`** and **`run_relaxation_*.m`** inventory in survey **08A**.

---

## 4. Scalar / column naming map

Contract vocabulary follows **`docs/relaxation_activity_naming_contract_08A.md`**. Source CSV columns **retain legacy names** (**`A_obs`**, **`m0_LOO`**, etc.); this manifest maps them to contract names **without renaming files**.

Full mapping: `tables/relaxation/relaxation_RF3R2_manifest_09_column_scalar_map.csv`.

Summary:

| Contract | Primary source column(s) |
|----------|-------------------------|
| **`T_K`** | **`temperature_K`** (RCON bundle); **`T_K`** (Lineage-06); **`heldout_T_K`** (AR02 folds) |
| **`A_obs_canon`** | **`A_obs`** in **`relaxation_RCON_02B_Aproj_vs_SVD_score.csv`** |
| **`A_svd_canon`** | **Family** — implement via **`SVD_score_mode1`**, **`m0_LOO`** / dictionary **`m0_LOO_SVD_projection`**, **`m0_svd`**, plus lineage **`A_T_canon_*`** per alias CSV |
| **`A_T_canon`** | **`A_T_canon_oriented`** (preferred) in **`relaxation_AT_canon_lineage_06_scalar_table.csv`** |
| **`A_svd_LOO_canon`** | **`m0_LOO`** in **`relaxation_activity_representation_02_loo_svd_fold_metrics.csv`** |
| **`A_svd_full_canon`** | **`SVD_score_mode1`** / **`m0_svd`** (RCON bundle and lineage table) |
| **`A_T_old`** | **No numeric column** |

Forbidden for current manifest prose: bare **`A`**, **`m0`**, **`A_T`**, and undefined **`A_canon`**. Legacy headers in CSVs are **source names**, not new claims.

---

## 5. Inclusion / replay flag map

Primary gates live on **`relaxation_RF3R2_repaired_curve_index.csv`**: **`trace_valid_for_relaxation`**, **`is_quality_flagged`**, **`valid_for_default_replay`** (default narrow replay — can exclude rows even when trace remains relaxation-valid), **`invalid_reason`**, **`rf3r2_sample_mask_policy`**. Long-table duplicates: **`relaxation_RF3R2_repaired_curve_samples.csv`** carries **`quality_flag`** and **`valid_for_default_replay`** per sample row.

Build-level: **`SAMPLE_INDEX_GE_10_MASK_APPLIED`**, **`THIRTYFIVE_K_EXCLUDED`** in **`relaxation_RF3R2_repaired_build_status.csv`**.

Lineage strict inclusion: **`inclusion_status`** on **`relaxation_AT_canon_lineage_06_scalar_table.csv`**.

Table: `tables/relaxation/relaxation_RF3R2_manifest_09_inclusion_flags.csv`.

---

## 6. Internal consistency checks

Conservative desktop checks only (see `relaxation_RF3R2_manifest_09_integrity_checks.csv`):

- **Temperature axes:** Present and finite in sampled rows across RCON bundle, curve index, and lineage tables (**PASS** for structural presence).
- **Linkability:** **`trace_id`** / **`run_id`** shared between samples and index (**PASS**).
- **RCON vs index:** **18** temperatures / rows aligned with **`RF3R2_TEMPERATURE_COUNT`** (**PASS**).
- **Strict Lineage-06 mask:** **8** temperatures vs **18** in bundle — **expected subset**, not a table mismatch (**PARTIAL** overall verdict — scope labeling required).
- **Verdict:** **PARTIAL** — suitable for continued Relaxation-only work when **mask vs full ladder** is explicitly labeled.

---

## 7. Readiness for KWW / RF5A / figures

| Next task | Readiness | Rationale |
|-----------|-----------|-----------|
| **KWW-TAU-BETA-SURVEY-09** | **READY (with caveats)** | Inputs exist (`relaxation_tau_RF3R2_*`, RF3R2 curves). Prior **`relaxation_tau_RF3R2_status.csv`** records **`TAU_CANON_PUBLICATION_READY`** **NO** — survey should **inventory scope**, not assert publication-ready tau canon. **`relaxation_RF5A_RF3R2_status.csv`** records **`SAFE_TO_CONTINUE_TAU_AUDIT`** **NO** — treat as **prior gate**, not missing files. |
| **RLX-RF5A-HARMON-09** | **READY** | RF5A RF3R2 tables and status present; task is **naming alignment**, not recomputation. |
| **RLX-FIG-READINESS-09** | **READY** | Scalar bundle + curves + **08A** naming contract supply caption vocabulary. |

Matrix: `tables/relaxation/relaxation_RF3R2_manifest_09_readiness_matrix.csv`.

---

## 8. Remaining gaps (manifest layer)

1. **Optional consolidated checksum row** in a future manifest revision if repo policy requires a single **human-readable** checksum table for gitignored large CSVs (08A inventory already notes checksum policy).
2. **Tau canon publication** — blocked by prior tau status flags for **publication-ready** wording; does **not** block a **survey-only** KWW/tau/beta task.
3. **Explicit script-name registry** linking each table to one `.m` runner — partially spread across survey **08A**; optional narrow follow-up without editing archived artifacts.

**Cross-module dependency:** **None** for this manifest or for scheduling Relaxation-only survey/harmonization/figure tasks.

---

## 9. Final verdict

The **RF3R2 repaired curves**, **curve index**, **RCON 02B scalar bundle**, **Lineage-06 scalar table**, and **AR02 LOO metrics** form a **coherent**, **documented** Relaxation-only spine for amplitude and coordinate narratives. **Internal consistency** is **PARTIAL** solely due to **strict eight-temperature lineage subset vs eighteen-temperature bundle** — an expected **scope** distinction, not evidence of corrupted joins. **Further Relaxation-only tasks** may proceed using this manifest as the **source-of-truth map**; **no AX or cross-module input** is required at this layer.

---

*Artifacts: this report; `relaxation_RF3R2_manifest_09_*.csv` under `tables/relaxation/`.*
