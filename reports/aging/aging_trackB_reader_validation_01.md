# Aging Track B five-column reader validation (inventory only)

**Task:** Narrow audit whether the **Track B** thin consolidation CSV is safe as the **first** source for Dip/FM vs wait-time science **planning and inventory plots** -- **not** convergence fitting, tau extraction, or ratios.  
**Anchors:** `2af3d6f`, `e1a5025`; guides [`docs/aging_observable_user_guide_draft.md`](../../docs/aging_observable_user_guide_draft.md), [`reports/aging/aging_canonical_reentry_map_01.md`](aging_canonical_reentry_map_01.md).  
**Hygiene:** No MATLAB, Python, replay, tau, ratios, or new physics claims; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Repository policy:** Default `.gitignore` rules ignore broad `reports/**` and `tables/**` trees; the deliverable files in this task still exist on disk but may not show as untracked until explicitly added (for example with a path-precise add that your archive policy allows).

---

## Scope

- **Primary question:** Is **`tables/aging/aging_observable_dataset.csv`** the best current Track B reader artifact for **`Tp`**, **`tw`**, **`Dip_depth`**, **`FM_abs`**, **`source_run`**?
- **Out of scope:** Running convergence models, tau scripts, clock-ratio scripts, or editing consolidation code.

---

## Source basis

- `docs/aging_observable_user_guide_draft.md` (ABS_ONLY `FM_abs`, Track B lane)
- `reports/aging/aging_canonical_reentry_map_01.md`, `tables/aging/aging_canonical_reentry_route_matrix_01.csv`, `tables/aging/aging_canonical_reentry_next_slice_options_01.csv`
- `reports/aging/aging_F7U_decomposition_tau_path_readiness_survey.md`, `tables/aging/aging_F7U_decomposition_tau_compatibility_matrix.csv`
- `tables/aging/aging_F7X7_safe_use_matrix.csv` (five-column row semantics)
- **Repository inspection:** `tables/aging/aging_observable_dataset.csv`, `tables/aging/aging_observable_dataset_contract.csv`, `tables/aging/consolidation_structured_run_dir.txt`, `tables/aging/aging_observable_dataset_sidecar.csv`
- **Legacy comparison only:** `results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv` (not primary)

---

## Candidate sources

See **`tables/aging/aging_trackB_reader_candidate_sources_01.csv`**.

**Verdict:** **`TB001`** — `tables/aging/aging_observable_dataset.csv` — **primary**. **`TB002`** archived build retained for historical replay only (**FM_abs** NaN issues documented elsewhere).

---

## Primary Track B source

**Path:** **`tables/aging/aging_observable_dataset.csv`**

- **22 rows**, header **`Tp,tw,Dip_depth,FM_abs,source_run`** — matches Stage D five-column contract.
- **Pointer:** `tables/aging/consolidation_structured_run_dir.txt` → `aggregate_structured_export_aging_Tp_tw_2026_04_26_085033`.
- **Sidecar:** `tables/aging/aging_observable_dataset_sidecar.csv` maps rows to `observable_matrix.csv` inputs for lineage depth when needed.

---

## Column audit summary

Machine table: **`tables/aging/aging_trackB_reader_column_audit_01.csv`**.

**Answers:** All five required columns **present**, **numeric** (or nonempty string for **`source_run`**), **no missing** cells in this snapshot. **`FM_abs`** is **magnitude-only** (`PASS_WITH_DISCLOSURE`). **`Dip_depth`** includes one **small negative** value at **Tp=14**, **tw=360** — acceptable for inventory **with disclosure**, not a physics interpretation event here.

---

## `Tp × tw` grid audit summary

Machine table: **`tables/aging/aging_trackB_reader_grid_audit_01.csv`**.

- **No duplicate** `(Tp, tw, source_run)` keys (**0** duplicate groups).
- **Tp ∈ {14,18,22,26}:** **4** distinct **`tw`** values **`{3,36,360,3600}`** — **READY_FOR_CONVERGENCE** for wait-time curve inventory **subject** to science thresholds later.
- **Tp ∈ {30,34}:** **3** **`tw`** points only (**36,360,3600**) — **`tw=3`** row **absent** vs lower temperatures → **PARTIAL_BUT_USABLE** for cross-Tp comparison unless short-time point is required **symmetrically**.

---

## Lineage and allowed-use audit

Machine table: **`tables/aging/aging_trackB_reader_lineage_audit_01.csv`**.

- **Track B reader contract:** Matches **`aging_observable_dataset_contract.csv`** at column-name level.
- **Tau extraction later:** Reader path is **compatible** per F7U CX001/CX002 **but** **metadata bundle** (F7X5 **B-003**) still **gates** authoritative tau display — validation marks **`YES_WITH_METADATA`**, not permission to skip gates.
- **Ratio / `R_age` later:** **Not** authorized from this CSV alone — downstream tau pairing and manifests remain **blocked** until tau artifacts exist (**NO** for ratio-from-reader-only).

---

## Readiness verdict

**Thin Dip/FM wait-time inventory (plots vs `tw`, grouped by `Tp`):** **ALLOWED NEXT** using **`TB001`**, with captions reflecting **`FM_abs`** ABS semantics and optional **`Dip_depth`** sign disclosure where negative.

**Tau extraction:** **Still gated** — do **not** treat this audit as approval to run **`aging_timescale_extraction`** without separate metadata policy closure.

**Ratios:** **Still blocked** until paired tau outputs + lineage (**per F7U / canonical re-entry map**).

---

## What is still blocked

1. **Tau authority:** F7X5 **B-003** (`tau_effective_seconds` / dual-builder disclosure) — **metadata completion** before tau-first scientific claims.  
2. **Ratio re-entry:** Requires **`tau_vs_Tp`** / **`tau_FM_vs_Tp`** pairing manifest — **not** this reader table.  
3. **Symmetric tw grid:** High **`Tp`** (**30**, **34**) lack **`tw=3`** — constrain cross-T convergence narratives unless regenerated.

---

## Recommended next task

**`AGING-DIP-FM-TW-INVENTORY-01`** — produce **inventory figures/tables** (Dip_depth(**Tp**,**tw**), FM_abs(**Tp**,**tw**), optional residuals vs log **tw**) **without** tau fit or ratio — aligns Dip and FM on the **same** grid. If work is split, **`AGING-DIP-TW-01`** can cover Dip-only first; current grid supports **joint** Dip+FM.

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT files were modified. No F7X/F7Y or canonical re-entry source files were edited.
