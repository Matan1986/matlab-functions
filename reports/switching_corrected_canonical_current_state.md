# Switching corrected / canonical — current state (**start here**)

**Last updated:** 2026-04-29 (namespace remediation + final governance micro-pass cross-links).  
**Scope:** Switching only. **`PHYSICS_LOGIC_CHANGED=NO`** for this documentation wave.

---

## 1. What is the manuscript-authoritative path?

**`CORRECTED_CANONICAL_OLD_ANALYSIS`** backed by **authoritative CSVs** from the gated corrected-old builder:

- Index: **`tables/switching_corrected_old_authoritative_artifact_index.csv`** / **`reports/switching_corrected_old_authoritative_artifact_index.md`**
- Gate record: **`tables/switching_corrected_old_authoritative_builder_status.csv`**
- Narrative contract: **`docs/switching_analysis_map.md`**

**Core inputs** to that path: clean **`switching_canonical_source_view.csv`** (canonical **`S_percent`**), **`tables/switching_corrected_old_effective_observables_locked.csv`**, verified legacy **`PT_matrix.csv`** route — **not** mixed **`S_model_pt_percent`** from **`run_switching_canonical.m`**.

---

## 2. What is only canonical source?

**`CANON_GEN_SOURCE`:** measured **`S_percent`** (and identity axes **`T_K`**, **`current_mA`**) from **`run_switching_canonical.m`**, preferably via **post-run** **`switching_canonical_source_view.csv`** when claiming clean-source boundaries.

---

## 3. What is experimental / diagnostic?

- **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`:** **`S_model_pt_percent`**, **`CDF_pt`**, **`PT_pdf`** in **`switching_canonical_S_long.csv`** — **not** the selected manuscript backbone under the current narrative decision.
- **`DIAGNOSTIC_MODE_ANALYSIS`:** **`residual_percent`**, **`S_model_full_percent`**, **`switching_canonical_phi1.csv`**, observables **kappa1** from the mixed producer — **forbidden** as authoritative corrected-old manuscript evidence.

**Column map:** **`reports/switching_canonical_S_long_column_namespace.md`**

---

## 4. What is old / legacy reference?

- **`OLD_FULL_SCALING`**, **`OLD_BARRIER_PT`**, **`OLD_RESIDUAL_DECOMP`** families — historical pipelines (`switching_residual_decomposition_analysis`, alignment runs, **`results_old/...`** provenance). Use **explicit family id** when citing.

**Family tree:** **`reports/switching_backbone_family_tree.md`**

---

## 5. What is quarantined?

**Registry:** **`tables/switching_misleading_or_dangerous_artifacts.csv`**  
**Visibility index:** **`reports/switching_quarantine_index.md`**

Includes **misleading `switching_corrected_old_*.png`** built from **diagnostic PT/CDF** flows — **do not** cite as authoritative corrected-old figures.

---

## 6. What is already reconstructed?

Authoritative **backbone, residual, Phi1, kappa1, mode1 reconstruction, residual-after-mode1, quality metrics** — see artifact index.  
**TASK_001** finite-grid audit tables — complete (`tables/switching_corrected_old_finite_grid_*.csv`).  
**TASK_002A** quality closure + QA diagnostics — complete per **`tables/switching_corrected_old_quality_metrics_closure_status.csv`**.

---

## 7. What remains missing?

| Gap | Status |
|-----|--------|
| Authoritative **Phi2 / kappa2** under corrected-old recipe | **Not reconstructed** |
| **TASK_002B** backbone parity bridge table | **Not completed** (program dependency language still uses legacy **`TASK_002`** id in archival CSV — see alignment doc) |
| **Publication figures** | Gate **`PARTIAL`** — **`TASK_009`–`TASK_012`** program |

---

## 8. What is the next allowed task?

Per **`reports/switching_corrected_canonical_reconstruction_program.md`** and aligned task table **`tables/switching_missing_reconstruction_tasks_aligned.csv`**:

- **TASK_002B_backbone_parity_bridge** may proceed when inputs are ready (after TASK_001 closure).
- **TASK_002A_visual_QA_refinement** is a **documentation-safe** refinement step using **source view + authoritative tables** (see diagnostics script headers).

---

## 9. Which file should agents read first?

**This file:** **`reports/switching_corrected_canonical_current_state.md`**

Then:

1. **`tables/switching_corrected_old_authoritative_artifact_index.csv`**
2. **`reports/switching_stale_governance_supersession.md`** (if reading older status CSVs)
3. **`reports/switching_quarantine_index.md`**
4. **`reports/switching_reconstruction_task_id_alignment.md`**

---

## 10. What terms are forbidden unless namespaced?

From **`tables/switching_forbidden_conflations.csv`** / **`tables/switching_namespace_contract_rules.csv`**:

- Bare **`X`**, bare **`collapse`**, bare **`Phi1`/`Phi2`/`kappa`** / **`backbone`** without **`namespace_id`** and formula/grid context.
- Equating **`Phi*_old`** with **`Phi*_canon`** or **`kappa_old`** with authoritative **`kappa*`** by name only.
- **`X_old`** or **`collapse_old`** as **canonical evidence** without replay namespace.

---

## Quick links

| Topic | Path |
|-------|------|
| Artifact index | `reports/switching_corrected_old_authoritative_artifact_index.md` |
| Backbone families | `reports/switching_backbone_family_tree.md` |
| Stale blocker supersession | `reports/switching_stale_governance_supersession.md` |
| S_long columns | `reports/switching_canonical_S_long_column_namespace.md` |
| Quarantine | `reports/switching_quarantine_index.md` |
| Task vocabulary | `reports/switching_reconstruction_task_id_alignment.md` |
| Reconstruction program | `reports/switching_corrected_canonical_reconstruction_program.md` |
| Legacy separation contract | `reports/switching_legacy_canonical_separation_contract.md` |
| Broad artifact ambiguity sweep | `reports/switching_broad_artifact_ambiguity_sweep.md` |
| Final governance micro-pass (closure) | `reports/switching_final_governance_micro_pass.md` |
| Historical / diagnostic class inventory | `reports/switching_historical_diagnostic_artifact_inventory.md` |

---

## Width / W policy

**Allowed:** **`W`/`width`** as **alignment-only** input for **`x=(I-I_peak)/width`** when **`WIDTH_CANONICAL_OVERCLAIMED=NO`** and lock tables apply — see **`tables/switching_corrected_old_effective_observable_validation_status.csv`**.

**Forbidden:** Universal canonical **`X`** or width-overclaim — **`X_CANONICAL_OVERCLAIMED=NO`**.
