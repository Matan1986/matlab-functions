# Switching high-risk artifact header / warning hardening

**Mode:** Documentation and **comment-only** headers in code. No physics logic changes, no reruns, no figure regeneration.

**Machine-readable audit:** `tables/switching_high_risk_artifact_header_hardening.csv`  
**Status:** `tables/switching_high_risk_artifact_header_hardening_status.csv`

---

## Scope

Completed the partial **`HIGH_RISK_ARTIFACT_HEADERS_ADDED`** work from namespace remediation by:

1. Applying the **SWITCHING NAMESPACE / EVIDENCE WARNING** template (plus **`CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md`**) to prioritized MATLAB scripts, one PowerShell spine script, and selected markdown governance reports.
2. Leaving **machine-readable data CSVs** and **binary PNGs** as **`INDEX_ONLY`** — warnings remain **external** via **`reports/switching_quarantine_index.md`** and **`tables/switching_high_risk_artifact_header_hardening.csv`** rows.

---

## Scripts updated (comment blocks only)

| Artifact |
|----------|
| `Switching/analysis/run_phi2_kappa2_canonical_residual_mode.m` |
| `Switching/analysis/run_switching_canonical_collapse_hierarchy.m` |
| `Switching/analysis/run_switching_phi1_kappa1_experimental_replay.m` |
| `Switching/analysis/run_switching_canonical.m` |
| `Switching/analysis/run_switching_canonical_collapse_visualization.m` |
| `Switching/analysis/run_switching_mode_hierarchy_synthesis_audit.m` |
| `Switching/analysis/switching_residual_decomposition_analysis.m` |
| `Switching/diagnostics/run_switching_corrected_old_task002_visual_QA_refinement.m` |
| `Switching/diagnostics/run_switching_corrected_old_task002_quality_QA_and_closure.m` |
| `scripts/run_switching_canonical_map_spine.ps1` |
| `scripts/run_sw_corr_old_replay_auth.m` |
| `scripts/run_sw_old_inv_phi1_viz.m` |
| `scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m` |

---

## Markdown updated (warning blockquotes)

| Artifact |
|----------|
| `reports/switching_canonical_output_separation_design.md` |
| `reports/switching_quarantine_index.md` |
| `reports/switching_corrected_old_authoritative_builder.md` |

---

## INDEX_ONLY (no inline CSV/PNG edit)

- `tables/switching_analysis_classification_status.csv`
- `tables/switching_canonical_output_separation_status.csv`
- `tables/switching_misleading_or_dangerous_artifacts.csv`
- `tables/switching_missing_reconstruction_tasks.csv`
- `figures/switching/canonical/switching_corrected_old_backbone_map.png` (representative quarantined figure — **all** such PNGs covered by quarantine index policy)

---

## Verdict

Quarantine **warnings are more visible** through the **blockquoted** header on **`reports/switching_quarantine_index.md`** plus script-level blocks on **QUARANTINED / EXPERIMENTAL** flows. **`HIGH_RISK_ARTIFACT_HEADERS_ADDED`** is set to **YES** in remediation status (with **`INDEX_ONLY`** discipline for unsafe formats).
