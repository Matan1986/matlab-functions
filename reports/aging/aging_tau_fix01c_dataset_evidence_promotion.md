# AGING-TAU-FIX-01C-DATASET-EVIDENCE-PROMOTION

## 1. Scope and exclusions

- **Scope:** Promote a compact, committed evidence bundle that captures shared upstream **dataset-lineage** facts for the baseline Dip and FM tau lanes (same consolidated dataset identity, shared `source_dataset_id`, shared `source_run` token, and required column axes), without committing full local run trees or the ignored consolidation CSV blob.
- **Exclusions:** No MATLAB, Python, Node, or replay execution; no tau computation, refit, ratios, comparison runners, or new figures; no Aging pipeline code edits; no Switching, Relaxation, Maintenance-INFRA, or MT changes; no staging or commit of full `results/aging/runs/` artifacts or `aging_observable_dataset.csv` as a bulk data commit.

## 2. Executive summary

FIX-01 established that baseline Dip and FM rows in committed PRB tables reference the **same** `source_dataset_id`, the **same** summarized `source_run` token, and the same consolidation semantics. FIX-01 remained **PARTIAL** because governance needed a **committed** compact package that explicitly promotes those facts and maps the source token, instead of relying only on narrative pointers to ignored local files.

FIX-01C writes six committed artifacts: this report, a lineage evidence table, a source-token mapping table, a bundle manifest, blocker resolution, and status. Together they close the **missing committed dataset-lineage evidence** gap for shared upstream identity. They do **not** clear Dip/FM branch canonical readiness, sidecar hardening, row identity, or final tau canonical gates (FIX-02 through FIX-06).

## 3. FIX-01 / FIX-01B context

- **FIX-01** (`reports/aging/aging_tau_fix01_shared_dataset_lineage.md` and companion tables) audited PRB03, PRB02B, PRB01, and the consolidation dataset header. It concluded Dip and FM share `c:/Dev/matlab-functions/tables/aging/aging_observable_dataset.csv` as `source_dataset_id`, share the PRB03 `source_run` token, and require columns `Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`. Blocker status for dataset lineage remained **PARTIAL** because the consolidation file and run-local tau/sidecars are not committed canonical artifacts.
- **FIX-01B** (`reports/aging/aging_tau_fix01b_dataset_evidence_promotion_plan.md`) recommended **no** full run commit and **yes** compact committed tables derived from already committed PRB anchors plus minimal extracted fields. **Ready for dataset evidence promotion: YES.**

## 4. Why full run promotion is intentionally avoided

Committing entire `results/aging/runs/...` trees would blend machine-local outputs with governance, inflate the repo, and violate the repository policy of compact evidence. The baseline shared **identity** is already provable from committed PRB03 and PRB02B rows; FIX-01C adds an explicit, auditable bundle without promoting ignored run folders or the full consolidation CSV.

## 5. Compact evidence bundle contents

| Artifact | Role |
| -------- | ---- |
| `reports/aging/aging_tau_fix01c_dataset_evidence_promotion.md` | Human-readable promotion audit and verdicts |
| `tables/aging/aging_tau_fix01c_dataset_lineage_evidence.csv` | Row-level promoted facts with PRB/FIX-01 provenance |
| `tables/aging/aging_tau_fix01c_source_token_mapping.csv` | Committed mapping for `source_dataset_id`, `source_run`, and pathway linkage |
| `tables/aging/aging_tau_fix01c_promoted_bundle_manifest.csv` | Manifest of this promotion and source inputs |
| `tables/aging/aging_tau_fix01c_blocker_resolution.csv` | Blocker state before/after FIX-01C |
| `tables/aging/aging_tau_fix01c_status.csv` | Machine-readable gate fields |

## 6. Shared dataset identity evidence

Committed anchors:

- `tables/aging/aging_prb03_tau_bundle_inventory.csv` — baseline Dip and FM rows list **identical** `source_dataset_id` (`c:/Dev/matlab-functions/tables/aging/aging_observable_dataset.csv`).
- `tables/aging/aging_prb02b_f7v_bridge_ledger.csv` — bridge rows for Dip and FM at the same `Tp` share the same `source_dataset_id` and `source_run`.

FIX-01C tabulates these as promoted facts in `aging_tau_fix01c_dataset_lineage_evidence.csv` with explicit source rows.

## 7. Source token / source run mapping

The shared PRB03/PRB02B `source_run` value is a **single summarized token** (not a filesystem path). It is recorded verbatim in `aging_tau_fix01c_source_token_mapping.csv` with parsing notes (`aggregate_structured_export_aging_Tp_tw_2026_04_26_085033|MG119|MG119_3sec | ... | MG119_36sec`).

## 8. Required column evidence

FIX-01 evidence row E05 documented the consolidation header: `Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`. FIX-01C **commits** that column list as a promoted extract in `aging_tau_fix01c_dataset_lineage_evidence.csv`, so the required-column claim no longer depends only on a local ignored CSV file for auditors reading the repo.

## 9. Evidence that Dip and FM share the same upstream dataset

PRB03 inventory rows for pathways `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1` and `AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1` both reference the same `source_dataset_id` and the same `source_run`. PRB02B ledger rows `BL_DIP_TP*` and `BL_FM_TP*` at matched `Tp` repeat the same fields. This is direct committed-table proof of a **shared** upstream consolidation dataset for the baseline lane.

## 10. What this promotion closes

- The governance gap: **absence of a committed, compact package** explicitly documenting shared dataset lineage (FIX-01 partial cause).
- Reliance on narrative-only references for the **required column list** — now duplicated in a committed CSV row with provenance.

## 11. What remains open after FIX-01C

- **FIX-02:** Dip branch / component-definition and lineage completion for the Dip lane.
- **FIX-03:** FM branch / policy and lineage completion for the FM lane.
- **FIX-04:** Sidecar hardening and naming guard.
- **FIX-05:** Row identity and co-registration.
- **FIX-06:** Final canonical readiness gate.
- **Reproducibility:** The consolidation CSV file body and run-local tau tables remain **not** committed; optional future canonical regeneration remains **PARTIAL** per FIX-01B.

## 12. What remains forbidden

Canonical tau-as-evidence claims, ratios, comparison-runner execution, replay, tau recomputation/refit, new figures, bulk commit of `results/aging/runs/`, and pipeline edits — unchanged from FIX-01/FIX-01B policy.

## 13. Final verdicts

- **Dataset-lineage committed-evidence gap:** addressed by FIX-01C compact bundle (**closure of that specific gap: YES**).
- **Dip/FM tau canonical-ready:** **NO** — branch tasks remain.
- **Safe to use tau as canonical evidence / ratios / comparison runner:** **NO**.

See `tables/aging/aging_tau_fix01c_status.csv` for machine-readable fields.
