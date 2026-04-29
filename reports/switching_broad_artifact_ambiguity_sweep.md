# Switching broad artifact ambiguity sweep

**Mode:** Read-only classification + **comment-only** headers where clearly safe. No physics reruns, no figure regeneration, no scientific CSV body edits.

**Outputs:**

- `tables/switching_broad_artifact_ambiguity_sweep.csv` — classified sample across Switching/scripts/reports/tables/docs
- `tables/switching_broad_artifact_ambiguity_new_candidates.csv` — net-new or deferred items vs prior passes
- `tables/switching_broad_artifact_ambiguity_sweep_status.csv` — verdicts
- `tables/switching_broad_artifact_warning_updates.csv` — scripts touched with headers this pass
- `tables/switching_historical_diagnostic_artifact_inventory.csv` + `reports/switching_historical_diagnostic_artifact_inventory.md` — lightweight category inventory

---

## 1. Executive summary

Prior work already centralized **authoritative paths**, **quarantine**, **S_long column namespaces**, **TASK_002A/B vocabulary**, and **high-risk headers**. This sweep **samples ~970 files** in the Switching-related search space (`727` `tables/switching_*.csv`, `199` `Switching/**/*.m`, `41` `scripts/*switching*`, plus docs/reports/figures/results pointers) and records **37 representative rows** in the sweep table.

**New ambiguity surfaced:** additional **`run_switching_canonical_*`** visualization scripts, **`canonical` misnamed** utilities (`run_minimal_canonical`, **`tmp_run_switching_canonical_paper_figures`**), **alignment robustness** (`run_parameter_robustness_switching_canonical`), **PTCDF-heavy audits** (`run_switching_backbone_validity_audit`), **Phi2/geocanon audits**, and **forensic replot** scripts. Most are **medium risk** from naming alone; **no new high-risk class** was discovered that lacked any governance hook — **`NEW_HIGH_RISK_MISSED_ARTIFACTS_FOUND=NO`**.

---

## 2. Already covered by prior remediation

- **`reports/switching_corrected_canonical_current_state.md`** — start here.
- **`tables/switching_corrected_old_authoritative_artifact_index.csv`** — positive authoritative list.
- **`reports/switching_quarantine_index.md`** + **`tables/switching_misleading_or_dangerous_artifacts.csv`** — negative / hazard list.
- **`reports/switching_canonical_S_long_column_namespace.md`** — column-level split for **`switching_canonical_S_long.csv`**.
- **`tables/switching_high_risk_artifact_header_hardening.csv`** — first header pass.
- **`reports/switching_reconstruction_task_id_alignment.md`** — TASK_002A vs TASK_002B.

---

## 3. New ambiguous artifacts (highlights)

| Theme | Examples |
|-------|----------|
| **Canonical + visualization** | `run_switching_canonical_map_visualization.m`, `run_switching_canonical_ptcdf_collapse_overlay.m`, `run_switching_canonical_map_backbone_residual_visualization.m`, `run_switching_canonical_reconstruction_visualization.m` |
| **Canonical name ≠ CANON_GEN producer** | `run_parameter_robustness_switching_canonical.m` (alignment samples), `run_minimal_canonical.m` (scaffold), `tmp_run_switching_canonical_paper_figures.m` (scratch) |
| **PTCDF audit density** | `run_switching_backbone_validity_audit.m` |
| **Phi2 / geocanon audits** | `run_switching_phi2_replacement_audit.m`, `run_switching_geocanon_descriptor_audit.m` |
| **Forensic replay** | `run_switching_old_fig_forensic_and_canonical_replot.m` |

---

## 4. Risk counts (from sweep + pass actions)

| Level | Interpretation |
|-------|----------------|
| **HIGH** (missed earlier) | **0** new orphan high-risk producers |
| **MEDIUM** | Multiple visualization / audit / tmp scripts — **headers added** where safe |
| **LOW** | Inventories, maintenance reports, legacy doc titles |

---

## 5. Direct headers vs index-only

**Headers added (comment-only):** see **`tables/switching_broad_artifact_warning_updates.csv`** (**11** scripts this pass).

**Index-only:** mixed **`switching_canonical_S_long.csv`** run outputs, **PNG** quarantine assets, central **registry CSVs** — do not inject free-text headers into data files.

---

## 6. Historical/diagnostic inventory

**Needed at category level:** **`PARTIAL`** — satisfied by **`reports/switching_historical_diagnostic_artifact_inventory.md`** (not a full file-by-file crawl).

---

## 7. Start-here / index updates

**No mandatory update** to **`reports/switching_corrected_canonical_current_state.md`** — it already links family tree, quarantine, S_long namespace, and authoritative index. Optional follow-up: add one bullet under “Related” pointing to **`reports/switching_broad_artifact_ambiguity_sweep.md`** (deferred to avoid churn).

---

## 8. TASK_002A visual QA refinement

**Safe to resume:** **`SAFE_TO_RESUME_TASK002A_VISUAL_QA_REFINEMENT=YES`** — unchanged inputs; this sweep does not alter diagnostics scripts beyond optional future additions.

---

## 9. Recommended next step

1. Optional **micro-pass** on remaining **`run_phi*.m` / `run_switching_canonical_*.m`** without headers (search `Switching/analysis` for files starting with `clear` without `SWITCHING NAMESPACE`).
2. When **`reports/switching_corrected_old_replay_inventory_and_phi1_visual_sanity.md`** is generated, prepend the standard markdown warning block (tracked as **`NEEDS_HUMAN_REVIEW`** / materialization-dependent).
3. Optional link from **`reports/maintenance/switching_source_of_truth_owner_decision_audit.md`** to **`tables/switching_corrected_old_authoritative_artifact_index.csv`** (additive “Related” paragraph only).
