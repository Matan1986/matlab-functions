# Corrected-old authoritative artifact index (Switching)

**Purpose:** One-page map from **role → path → allowed/forbidden use** for `CORRECTED_CANONICAL_OLD_ANALYSIS` / **corrected_old_authoritative** evidence.

**Machine-readable:** `tables/switching_corrected_old_authoritative_artifact_index.csv`

**Producer summary:** `reports/switching_corrected_old_authoritative_builder.md`  
**Gate record:** `tables/switching_corrected_old_authoritative_builder_status.csv`

---

## Authoritative manuscript path (corrected-old)

Use **only** these tables for **authoritative** backbone / residual / Phi1 / kappa1 / mode1 / residual-after-mode1 / quality metrics under the gated builder run:

| Role | Path |
|------|------|
| Clean canonical `S` input | `results/switching/runs/run_2026_04_24_233348_switching_canonical/tables/switching_canonical_source_view.csv` |
| Locked effective observables | `tables/switching_corrected_old_effective_observables_locked.csv` |
| Legacy PT_matrix (template-locked) | `results_old/switching/runs/run_2026_03_24_212033_switching_barrier_distribution_from_map/tables/PT_matrix.csv` |
| Backbone map | `tables/switching_corrected_old_authoritative_backbone_map.csv` |
| Residual map | `tables/switching_corrected_old_authoritative_residual_map.csv` |
| Phi1 | `tables/switching_corrected_old_authoritative_phi1.csv` |
| Kappa1 | `tables/switching_corrected_old_authoritative_kappa1.csv` |
| Mode1 reconstruction | `tables/switching_corrected_old_authoritative_mode1_reconstruction_map.csv` |
| Residual after mode1 | `tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv` |
| Quality metrics | `tables/switching_corrected_old_authoritative_quality_metrics.csv` |

**Still forbidden as authoritative corrected-old evidence:** columns from mixed `switching_canonical_S_long.csv` / `run_switching_canonical.m` outputs — `S_model_pt_percent`, `CDF_pt`, `PT_pdf`, `residual_percent`, `switching_canonical_phi1.csv`, canonical diagnostic **kappa1** — see `reports/switching_canonical_S_long_column_namespace.md`.

### Mixed `switching_canonical_S_long.csv` per run (INDEX_ONLY classification)

Each **`results/switching/runs/<CANONICAL_RUN_ID>/tables/switching_canonical_S_long.csv`** is a **mixed** producer artifact: **`S_percent`** is **`CANON_GEN_SOURCE`**; **`S_model_pt_percent` / `CDF_pt` / `PT_pdf`** are **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**; residual/phi columns are **`DIAGNOSTIC_MODE_ANALYSIS`**. It is **not** listed as a single authoritative corrected-old table — use **column-level** semantics or **`switching_canonical_source_view.csv`** for clean **`S`**.

### Builder invocation (metadata only)

- **`scripts/run_switching_corrected_old_authoritative_builder.ps1`** — wrapper to the gated builder; evidence remains the **`tables/switching_corrected_old_authoritative_*.csv`** package plus **`tables/switching_corrected_old_authoritative_builder_status.csv`**.

---

## TASK_001 (finite-grid / interpolation audit)

Supporting audit tables (read-only closure of finite-fraction semantics):

- `tables/switching_corrected_old_finite_grid_interpolation_status.csv`
- `tables/switching_corrected_old_finite_grid_support_by_T.csv`
- `tables/switching_corrected_old_finite_grid_current_bin_audit.csv`
- `tables/switching_corrected_old_finite_grid_x_support_audit.csv`
- `tables/switching_corrected_old_finite_grid_downstream_risk.csv`
- `tables/switching_corrected_old_finite_grid_recommended_actions.csv`

---

## TASK_002A (quality metrics closure + diagnostic QA figures)

Vocabulary: **TASK_002A** = quality closure / visual QA work (supersedes ambiguous “TASK_002” label in older notes).

- Status: `tables/switching_corrected_old_quality_metrics_closure_status.csv`
- Per-T metrics: `tables/switching_corrected_old_quality_metrics_by_T.csv`
- QA manifest: `tables/switching_corrected_old_quality_metrics_visual_QA_manifest.csv`
- Refined QA manifest/status: `tables/switching_corrected_old_quality_metrics_visual_QA_refined_manifest.csv`, `tables/switching_corrected_old_quality_metrics_visual_QA_refined_status.csv`
- Figure directories (non-publication):  
  `figures/switching/diagnostics/corrected_old_task002_quality_QA/`  
  `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/`

---

## Known missing / not complete

| Item | Status |
|------|--------|
| Authoritative **Phi2 / kappa2** under corrected-old recipe | **Not reconstructed** — do not substitute **PHI2_KAPPA2_HYBRID** or **CANON_GEN** diagnostics as authoritative. |
| **Backbone parity bridge** (old vs corrected-old comparison table) | **Not completed** — program historically used id **TASK_002**; use **TASK_002B** vocabulary (`reports/switching_reconstruction_task_id_alignment.md`). |
| **Publication figures** | **Not fully authorized** — `SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL` until reconstruction program gates say otherwise. |

---

## Quick forbidden reminders

- Quarantined **corrected_old**-named figures built from **PT/CDF diagnostic** backbone: see `reports/switching_quarantine_index.md`.
- **Bare** Phi1/Phi2/kappa/backbone/collapse/X without **namespace_id**: forbidden for manuscript claims (`tables/switching_namespace_contract_rules.csv`).
