# Switching P0 — tracking and archival decision audit

**Date:** 2026-04-29  
**HEAD:** `72215df`  
**Scope:** Switching only. No staging, no commits, no rebuilds, no physics changes, no edits to authoritative numerical outputs.

This document records which Switching artifacts should be **force-added** to git to close P0 blockers from `tables/switching_full_integrity_clarity_audit_risk_register.csv` (R01, R02, R03), and which should stay **optional**, **out of plan**, or **external review**.

**Machine-readable deliverables:** `tables/switching_p0_tracking_archival_decision_audit.csv` (per-path classification), `tables/switching_p0_tracking_archival_decision_status.csv` (verdicts), `tables/switching_p0_force_add_plan.csv` (explicit `git add -f` list, `SWITCHING_ONLY`).

---

## 1. Git commands run and recorded

### `git status --short --ignored` (excerpt)

The working tree still shows many **non-Switching** untracked paths (`Relaxation ver3/`, root Aging scripts, Relaxation Python helpers). Switching-relevant excerpts:

- **Modified (`M`):** canonical analysis scripts under `Switching/analysis/`, gauge diagnostics under `figures/switching/diagnostics/`, `scripts/run_switching_canonical_map_spine.ps1`, `scripts/run_switching_gauge_atlas_preview.m`, `docs/switching_governance_persistence_manifest.md`, `tables/switching_analysis_classification_status.csv`, etc.
- **Untracked (`??`), Switching:** `Switching/analysis/run_switching_corrected_old_authoritative_builder.m`, `Switching/analysis/run_switching_corrected_old_builder_readiness_check.m`, `Switching/diagnostics/run_switching_cdf_backbone_repair_aggressiveness_audit.m`, several `scripts/run_switching_*.m|ps1`, `run_switching_fixed_T_current_cuts_canonical_replay.m`, etc.
- **Ignored (`!!`):** large vendor/tmp directories (`.codex_tmp/`, `.matlab_prefs/`, etc.) — **not** part of this force-add plan.

### `git diff --name-only`

Same 35 modified paths as prior audits (canonical/gauge/governance tables): listed in `tables/switching_full_integrity_clarity_audit_git_state.csv` and in `git status` above.

### `git ls-files --others --ignored --exclude-standard`

Outputs a very long list (starting under `.codex_tmp/`, `.codex_matlab_prefs/`, etc.). **None** of those paths appear in `tables/switching_p0_force_add_plan.csv`.

### `git ls-files` (Switching note)

Authoritative corrected-old **numeric** CSVs and most governance **tables/reports** are **not** listed until force-added. Representative **tracked** Switching paths from `72215df` include `tables/switching_corrected_old_finite_grid_interpolation_status.csv`, `Switching/diagnostics/run_switching_corrected_old_task002_visual_QA_refinement.m`, and diagnostic QA PNGs under `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/`.

---

## 2. Non-Switching safety check

| Path pattern | Classification |
|--------------|----------------|
| `Relaxation ver3/**` | `OUT_OF_SCOPE_DO_NOT_COMMIT` (28 untracked `.m` files) |
| `run_aging_F6*.m` (repo root) | `OUT_OF_SCOPE_DO_NOT_COMMIT` |
| `scripts/build_rf3r2_repaired_replay_object.py`, `scripts/run_relaxation_phase2_A_canon_lock.py` | `OUT_OF_SCOPE_DO_NOT_COMMIT` |
| `docs/decisions/switching_main_narrative_namespace_decision.md` | Switching content; `TRACK_OPTIONAL` / `NEEDS_HUMAN_REVIEW` (under `docs/decisions/`, not `Switching/` — confirm policy) |
| Other `docs/decisions/*` (if added later) | `UNKNOWN_NEEDS_HUMAN_REVIEW` unless Switching-scoped |

**Verdict:** `NON_SWITCHING_FILES_INCLUDED_IN_FORCE_ADD_PLAN=NO`, `NON_SWITCHING_FILES_RECOMMENDED_FOR_COMMIT=NO`.

---

## 3. Candidate groups — decisions

### A. Corrected-old authoritative code

| Artifact | Decision |
|----------|----------|
| `Switching/analysis/run_switching_corrected_old_authoritative_builder.m` | **TRACK_REQUIRED** — not ignored; **untracked**; reproducibility of authoritative CSVs. |
| `Switching/analysis/run_switching_corrected_old_builder_readiness_check.m` | **TRACK_REQUIRED** — referenced by builder workflow. |
| `scripts/run_switching_corrected_old_authoritative_builder.ps1` | **TRACK_REQUIRED** — documented wrapper. |
| `scripts/run_switching_corrected_old_builder_readiness_check.ps1` | **TRACK_REQUIRED** — documented wrapper. |
| `scripts/run_switching_canonical_output_separation.ps1` | **TRACK_REQUIRED** — post-run splitter for clean source views and separation gates (not in original list A–D; added as critical provenance). |

### B. Corrected-old authoritative numerical bundle

All eight map/metrics CSVs plus `switching_corrected_old_authoritative_builder_status.csv` exist on disk; combined size **~21 KB** (text CSV). **Recommendation:** **TRACK_REQUIRED** via **`git add -f`** (masked by `tables/**`, `tables/*_map*`, `tables/*metrics*`, `tables/*status*`).

**`EXTERNAL_ARCHIVE_REQUIRED`** was considered and **not** selected as default here because sizes are small and text-diff-friendly; use **external vault** only if org policy forbids large-table commits (not size-driven today).

### C. Governance / quarantine / clarity

All paths listed in the prompt (current_state, artifact index, backbone family tree, S_long namespace, quarantine index, task alignment, remediation status, header hardening, broad sweep, historical inventory, final micro-pass + status) are **`TRACK_REQUIRED`** and ignored until **`git add -f`**.

### D. Full integrity/clarity audit outputs

All `tables/switching_full_integrity_clarity_audit_*.csv` and `reports/switching_full_integrity_clarity_audit.md` are **`TRACK_REQUIRED`** (matched by `tables/*audit*`, `reports/**`).

### E. TASK_001 / TASK_002 / TASK_002A — already in `72215df`

**No gap** for the finite-grid tables, quality closure / consistency tables, refined QA manifest/status, diagnostic drivers, and QA PNGs listed in `git show 72215df --name-only`. Representative **already tracked** rows appear in `tables/switching_p0_tracking_archival_decision_audit.csv` (`ALREADY_TRACKED`).

---

## 4. Optional / do-not-track / human review

| Artifact | Decision |
|----------|----------|
| `docs/decisions/switching_main_narrative_namespace_decision.md` | **TRACK_OPTIONAL** — confirm repo policy for `docs/decisions/` versus `reports/`. |
| `scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m` | **TRACK_OPTIONAL** — quarantine-listed; only if keeping hazard scripts in-repo. |
| `Switching/diagnostics/run_switching_cdf_backbone_repair_aggressiveness_audit.m` | **TRACK_OPTIONAL** — diagnostic audit script. |
| `scripts/tmp_run_switching_canonical_paper_figures.m` | **DO_NOT_TRACK** — scratch. |

---

## 5. TRACK_REQUIRED — explicit `git add -f` commands (50 paths)

Run only after human approval. **Do not** use broad `git add -f tables` or `git add -f reports`.

One command per line (copy from `tables/switching_p0_force_add_plan.csv` column `recommended_command`). Order is **scripts → authoritative CSVs → governance → integrity audit → this P0 audit bundle**.

```text
git add -f "Switching/analysis/run_switching_corrected_old_authoritative_builder.m"
git add -f "Switching/analysis/run_switching_corrected_old_builder_readiness_check.m"
git add -f "scripts/run_switching_corrected_old_authoritative_builder.ps1"
git add -f "scripts/run_switching_corrected_old_builder_readiness_check.ps1"
git add -f "scripts/run_switching_canonical_output_separation.ps1"
git add -f "tables/switching_corrected_old_authoritative_builder_status.csv"
git add -f "tables/switching_corrected_old_authoritative_backbone_map.csv"
git add -f "tables/switching_corrected_old_authoritative_residual_map.csv"
git add -f "tables/switching_corrected_old_authoritative_phi1.csv"
git add -f "tables/switching_corrected_old_authoritative_kappa1.csv"
git add -f "tables/switching_corrected_old_authoritative_mode1_reconstruction_map.csv"
git add -f "tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv"
git add -f "tables/switching_corrected_old_authoritative_quality_metrics.csv"
git add -f "reports/switching_corrected_canonical_current_state.md"
git add -f "tables/switching_corrected_old_authoritative_artifact_index.csv"
git add -f "reports/switching_corrected_old_authoritative_artifact_index.md"
git add -f "tables/switching_backbone_family_tree.csv"
git add -f "reports/switching_backbone_family_tree.md"
git add -f "tables/switching_canonical_S_long_column_namespace.csv"
git add -f "reports/switching_canonical_S_long_column_namespace.md"
git add -f "tables/switching_quarantine_index.csv"
git add -f "reports/switching_quarantine_index.md"
git add -f "tables/switching_reconstruction_task_id_alignment.csv"
git add -f "reports/switching_reconstruction_task_id_alignment.md"
git add -f "tables/switching_namespace_confusion_remediation_status.csv"
git add -f "tables/switching_high_risk_artifact_header_hardening.csv"
git add -f "reports/switching_high_risk_artifact_header_hardening.md"
git add -f "tables/switching_broad_artifact_ambiguity_sweep.csv"
git add -f "reports/switching_broad_artifact_ambiguity_sweep.md"
git add -f "tables/switching_historical_diagnostic_artifact_inventory.csv"
git add -f "reports/switching_historical_diagnostic_artifact_inventory.md"
git add -f "tables/switching_final_governance_micro_pass.csv"
git add -f "reports/switching_final_governance_micro_pass.md"
git add -f "tables/switching_final_governance_micro_pass_status.csv"
```

Then add each `tables/switching_full_integrity_clarity_audit_*.csv` (alphabetical order in `switching_p0_force_add_plan.csv`), then:

```text
git add -f "reports/switching_full_integrity_clarity_audit.md"
git add -f "tables/switching_p0_tracking_archival_decision_audit.csv"
git add -f "tables/switching_p0_tracking_archival_decision_status.csv"
git add -f "reports/switching_p0_tracking_archival_decision_audit.md"
git add -f "tables/switching_p0_force_add_plan.csv"
```

The canonical source of truth for ordering is **`tables/switching_p0_force_add_plan.csv`** (`order` column 1–50).

---

## 6. Answers (final response mapping)

1. **Important ignored/untracked Switching artifacts:** **50** paths enumerated as **`TRACK_REQUIRED`** in the force-add plan (plus **4** optional/review paths and **2** reference-only already-tracked rows in the decision CSV).
2. **`TRACK_REQUIRED`:** section 5 and column `tracking_recommendation` in `tables/switching_p0_tracking_archival_decision_audit.csv`.
3. **`TRACK_OPTIONAL`:** decision CSV rows for `docs/decisions/switching_main_narrative_namespace_decision.md`, quarantine inventory script, CDF audit script.
4. **`DO_NOT_TRACK`:** `scripts/tmp_run_switching_canonical_paper_figures.m`.
5. **`NEEDS_HUMAN_REVIEW`:** optional docs/quarantine scripts; org policy on committing authoritative CSVs vs external archive (currently **not** size-forced).
6. **Exact commands:** section 5 and `switching_p0_force_add_plan.csv`.
7. **Non-Switching in plan:** **none**.
8. **Safe to run force-add:** **yes** for listed paths (text/small CSV; no destructive ops).
9. **Safe to commit after force-add:** **PARTIAL** — verify `git diff --cached --name-only` contains **only** intended Switching paths; **do not** stage Relaxation/Aging/Relaxation scripts.
10. **Remaining blockers after tracking plan:** stale artifact-index rows (content fix), **35 modified** canonical scripts not yet committed as a bundle, and ongoing `.gitignore` friction for future `tables/*` outputs unless patterns are adjusted later.

---

## 7. Verdict row

See `tables/switching_p0_tracking_archival_decision_status.csv`.
