# F7P — Aging FM tau lineage-resolution planning (before R_age / clock-ratio)

Read-only planning artifact. **No** MATLAB execution, **no** tau extraction, **no** FM tau writer runs, **no** R_age / clock-ratio writer runs, **no** old analysis replay, **no** numeric tau physics inspection, **no** 22-row vs 30-row ranking, **no** canonical branch selection, **no** code edits to Aging analysis code, **no** staging / commit / push. Execution hygiene reference: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

---

## 1. HEAD / preflight summary

| Check | Result |
|-------|--------|
| **HEAD** | `0ed6928` — *Add Relaxation RF3R2 manifest audit* (repo state at F7P authoring) |
| **`git diff --cached --name-only`** | **Empty** (no staged files) |
| **Anchors referenced** | `2513067` (F7O closure), `872764a`, `935e45f`, `d8916b9` (F7O-B/A/F7N stack), `eff35e1` (dip tau metadata closure) — all appear in recent history |

---

## 2. Exact artifacts read (committed)

### F7N

- `reports/aging/aging_F7N_fm_tau_metadata_readiness.md`
- `tables/aging/aging_F7N_candidate_input_paths.csv`
- `tables/aging/aging_F7N_fm_cfg_field_inventory.csv`
- `tables/aging/aging_F7N_fm_run_plan.csv`
- `tables/aging/aging_F7N_status.csv`

### F7O-A

- `reports/aging/aging_F7O_A_fm_tau_real_output_metadata_verification.md`
- `tables/aging/aging_F7O_A_fm_real_output_verification.csv`
- `tables/aging/aging_F7O_A_fm_metadata_columns.csv`
- `tables/aging/aging_F7O_A_execution_outcome.csv`
- `tables/aging/aging_F7O_A_status.csv`

### F7O-B

- `reports/aging/aging_F7O_B_fm_tau_real_output_metadata_verification.md`
- `tables/aging/aging_F7O_B_fm_real_output_verification.csv`
- `tables/aging/aging_F7O_B_fm_metadata_columns.csv`
- `tables/aging/aging_F7O_B_execution_outcome.csv`
- `tables/aging/aging_F7O_B_vs_A_metadata_comparison.csv`
- `tables/aging/aging_F7O_B_status.csv`

### F7O series closure

- `reports/aging/aging_F7O_fm_tau_metadata_series_closure.md`
- `tables/aging/aging_F7O_series_closure_summary.csv`
- `tables/aging/aging_F7O_series_branch_matrix.csv`
- `tables/aging/aging_F7O_series_open_items.csv`
- `tables/aging/aging_F7O_series_status.csv`

---

## 3. What remains unresolved in FM tau lineage?

Aggregated from F7N static mapping, F7O-A/B emitted metadata, and `aging_F7O_series_open_items.csv`:

1. **`FM_tau_lineage_resolution_for_model_use`** — Still **OPEN**. Verified `tau_FM_vs_Tp.csv` rows carry `model_use_allowed = NO_UNLESS_LINEAGE_RESOLVED` and `lineage_status = REQUIRES_DATASET_PATH_AND_FM_CONVENTION_RESOLUTION` (F7O-A/B metadata tables; F7O closure).
2. **`FM_convention_resolution`** — **OPEN**: naming, dataset/FM observable identity, and writer semantics remain governed by conservative flags until an explicit lineage-resolution task closes them (same column values on both branches).
3. **`datasetPath` identity and branch provenance** — **Dual verified branches**, not a single canonical aging observable dataset for FM: **22-row consolidation** (`tables/aging/aging_observable_dataset.csv`) vs **30-row archival snapshot** under `results_old/.../211204_...`. F7O proves branch-internal consistency; it does **not** select one branch as canonical.
4. **`dipTauPath` identity and branch alignment** — **Must pair** with `datasetPath` per F7N/F7O policy (Run A with 22-row; Run B with 30-row). Mis-pairing is a lineage defect (governance), not resolved by F7O beyond documenting correct pairs.
5. **`failedDipClockMetricsPath` shared archival auxiliary policy** — F7O-A/B both used the **same** archival `results_old/.../005134_.../fm_collapse_using_dip_tau_metrics.csv`. F7N/F7O document **cross-epoch** auxiliary use vs dip tau runs; **strict per-branch regeneration** remains an **optional** open item (`regenerate_failed_dip_clock_metrics_per_branch_if_strict_lineage_required`).
6. **`canonical_status = non_canonical_pending_lineage`** — Present on verified outputs; **not** cleared by F7O (metadata verification only).
7. **`22-row vs 30-row branch policy without ranking`** — **No physics winner**; coverage and row counts **differ** by design (`aging_F7O_B_vs_A_metadata_comparison.csv`). Policy is **branch-aligned pairs** and **no cross-branch mixing** for hygiene — **not** a resolution of which branch is “the” dataset for downstream ratios unless explicitly chartered later.

---

## 4. Which unresolved items block what?

| Layer | Blocked until… |
|-------|----------------|
| **Metadata column verification (F7O scope)** | **Closed** for real-output FM tau CSVs on both branches — lineage flags still conservative but columns verified. |
| **Model-use (`tau_FM` in calibrated / model-facing contexts)** | Blocked while **`FM_tau_lineage_resolution_for_model_use`**, **`FM_convention_resolution`**, **`canonical_status` pending**, and **`model_use_allowed` encoding** remain as on disk (**`NO_UNLESS_LINEAGE_RESOLVED`**) unless a future task explicitly escalates with evidence (out of F7P scope). |
| **R_age / clock-ratio writers** | Blocked from **authoritative** use of **`tau_FM`** as if lineage were closed. Ratios **must not silently inherit** unresolved FM tau lineage — see gates below. Documentation-only warnings (e.g. `semantic_status` legacy alias text) **do not** block continuing **metadata-level** documentation work. |

Machine-readable mapping: `tables/aging/aging_F7P_lineage_blocker_inventory.csv`.

---

## 5. Exact model-use gate for `tau_FM`

**Definition:** `tau_FM` may be treated as **model-usable** only when **all** of the following hold:

1. **`lineage_status`** is no longer **`REQUIRES_DATASET_PATH_AND_FM_CONVENTION_RESOLUTION`**, **or** a written charter explicitly defines **scoped** model use under documented unresolved lineage (F7P does **not** author that charter).
2. **`FM_convention_resolution`** is **CLOSED** with recorded definitions (dataset column identity, FM tau domain, writer contract) tied to a **single** agreed observable lineage **or** explicitly parallel scoped lineages.
3. **`datasetPath` / `dipTauPath` / optional `failedDipClockMetricsPath`** provenance for the **specific** `tau_FM` table is **unambiguous** and **branch-aligned** (no accidental cross-branch pairing).
4. **`canonical_status`** and **`model_use_allowed`** on the emitted CSV reflect the resolved policy (**not** left at `non_canonical_pending_lineage` + `NO_UNLESS_LINEAGE_RESOLVED` unless explicitly accepting non-canonical scope).

**F7P does not upgrade flags.** Current verified outputs remain **`NO_UNLESS_LINEAGE_RESOLVED`**.

Detail: `tables/aging/aging_F7P_model_use_gate_plan.csv`.

---

## 6. Exact prerequisite gate for R_age / clock-ratio

**Definition:** No **R_age** or **clock-ratio** writer run should be treated as **lineage-complete** while FM tau lineage is unresolved **if** that ratio pipeline **consumes `tau_FM`** (or inherits its metadata) **without** one of:

1. **Explicit input manifest** naming which **`datasetPath` / dip / auxiliary** triple produced each `tau_FM` column used in the ratio, **or**
2. **Completed FM lineage-resolution task** (successor to F7P, e.g. F7Q) that defines allowed inputs for ratios, **or**
3. **Explicit “parallel branch” ratio policy** that computes separate ratios per branch and **never** merges numerators/denominators across branches without disclosure.

**Inheritance rule:** **R_age / clock-ratio may not inherit unresolved `tau_FM` lineage** as if F7O had closed lineage — F7O closed **metadata verification**, not lineage (`aging_F7O_series_status.csv`: `F7O_SAFE_FOR_R_AGE_OR_CLOCK_RATIO = NO`).

Detail: `tables/aging/aging_F7P_R_age_prerequisite_gate.csv`.

---

## 7. Documentation warnings (non-blocking for metadata-level work)

Examples that **do not** block **metadata-level** documentation or **F7O-style** verification claims:

- **`semantic_status = tau_effective_seconds_is_legacy_alias_FM_ABS_CURVEFIT`** — clarifies naming; not a lineage resolver.
- **Cross-epoch `failedDipClockMetricsPath`** — acceptable for F7N/F7O **metadata smoke** when **`run_notes`** document auxiliary lineage; stricter regeneration is optional (`aging_F7O_series_open_items.csv`).
- **Untracked harness scripts** (`tmp_f7o_*_UNTRACKED`) — operational note from F7O reports; does not change committed verification tables.

---

## 8. Ordered next actions (planning-level)

See `tables/aging/aging_F7P_required_next_actions.csv`. Summary:

1. **Execute or audit FM tau lineage resolution** (labeled **F7Q** in status: lineage execution / audit charter — **not** run in F7P).
2. **Define** whether strict **`failedDipClockMetricsPath`** regeneration is required before model-use or ratios.
3. **Only after** lineage gates are satisfied or explicitly scoped: charter **R_age / clock-ratio metadata verification** with explicit `tau_FM` input binding.

---

## 9. Explicit statement: no ratios yet

**Do not run R_age or clock-ratio writers** under the assumption that F7O closed FM tau **lineage**. F7O closed **FM tau real-output metadata verification** only (`aging_F7O_fm_tau_metadata_series_closure.md` §4–5).

---

## 10. Constraint confirmation

| Constraint | Status |
|------------|--------|
| Aging scope only; lineage planning only | **Yes** |
| No MATLAB / no extraction / no writers | **Yes** (planning artifact only) |
| No physics decisions; no branch ranking; no canonical selection | **Yes** |
| No `model_use_allowed` upgrade; no lineage resolved by this memo | **Yes** |
| No Switching / Relaxation / MT | **Yes** |
| No staging / commit / push for F7P | **Yes** (authoring deliverables only) |

---

## Deliverables

| File |
|------|
| `reports/aging/aging_F7P_fm_tau_lineage_resolution_plan.md` (this file) |
| `tables/aging/aging_F7P_lineage_blocker_inventory.csv` |
| `tables/aging/aging_F7P_model_use_gate_plan.csv` |
| `tables/aging/aging_F7P_R_age_prerequisite_gate.csv` |
| `tables/aging/aging_F7P_required_next_actions.csv` |
| `tables/aging/aging_F7P_status.csv` |

Machine-readable verdicts: `tables/aging/aging_F7P_status.csv`.
