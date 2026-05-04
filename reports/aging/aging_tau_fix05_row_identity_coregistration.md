# AGING-TAU-FIX-05-ROW-IDENTITY-COREGISTRATION

## 1. Scope and exclusions

- **Scope:** Validate **row identity** and **Dip/FM co-registration** for baseline curve-fit tau lanes from **committed** PRB02B bridge ledger and PRB03 bundle inventory only.
- **Exclusions:** No MATLAB, Python, Node, replay; no tau recompute/refit, ratios, figures; no code or sidecar-writer edits; no Switching, Relaxation, Maintenance-INFRA, or MT product files; no final canonical readiness decision (FIX-06); no physical row-level CSV body validation in this task.

## 2. Executive summary

Baseline **Dip** and **FM** rows share the formal key **`ID_TAU_VS_TP_ROW`**, are **co-registered** by **shared `Tp` wait-temperature** and **shared `co_registered_group_id` = `CO_REG_BASELINE_TP_<Tp>_PRB02B`**, and share **identical** `source_dataset_id`, `source_run`, and `tw` export grain token **`NOT_APPLICABLE_TP_SUMMARY_EXPORT`**. **Component observables** differ as required: **`Dip_depth`** vs **`FM_abs`**. The **finite overlap domain** is **six** `Tp` values **{14, 18, 22, 26, 30, 34}** with a **1:1** Dip/FM pair per `Tp` in committed tables; **no** missing, duplicate, or unmatched pairs are present in the **ledger/inventory** layer. **tau_vs_Tp** / **tau_FM_vs_Tp** **row bodies** remain **run-local**; this task does not verify numeric cell alignment in git. **Row-identity documentation** is **closed**; **body-level** proof remains **out-of-git** until a future run or FIX-06 refresh.

## 3. Commit hygiene / staging verification note

FIX-05 uses a **seven-path allow-list** under `reports/aging/` and `tables/aging/` only. **Maintenance** Switching audit files may be **tracked** but **must not** appear in the FIX-05 index entry.

## 4. FIX-01C / FIX-02 / FIX-03 / FIX-04 context

Upstream **dataset identity**, **Dip/FM branch** definitions, and **sidecar metadata** inventories are **closed** in prior tasks; FIX-05 addresses **row keying** and **pairing** across pathways.

## 5. Row identity key definition

- **Formal key token (both pathways):** **`ID_TAU_VS_TP_ROW`** (`PRB02B` / `PRB03` columns `row_identity_key`).
- **Primary physical join for baseline pairing:** numeric **`Tp`** (wait-temperature index for per-Tp summary exports) plus **`pathway_id`** disambiguation.
- **Grain:** `tw` in tau summary tables is **`NOT_APPLICABLE_TP_SUMMARY_EXPORT`** — **not** a per-`tw` row key for `tau_vs_Tp.csv` / `tau_FM_vs_Tp.csv` exports (ledger notes).

## 6. Dip row identity evidence

Representative rows **`TB_INV_BL_DIP_TP14`** … **`TB_INV_BL_DIP_TP34`**: `pathway_id`=`AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`, `source_observable`=`Dip_depth`, `row_identity_key`=`ID_TAU_VS_TP_ROW`, `co_registered_group_id`=`CO_REG_BASELINE_TP_<Tp>_PRB02B`.

## 7. FM row identity evidence

Representative rows **`TB_INV_BL_FM_TP14`** … **`TB_INV_BL_FM_TP34`**: `pathway_id`=`AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`, `source_observable`=`FM_abs`, same **`row_identity_key`** and **matching** `co_registered_group_id` per **`Tp`**.

## 8. Dip/FM co-registration audit

For each **`Tp` in {14,18,22,26,30,34}`**, exactly **one** Dip ledger row and **one** FM ledger row exist with the **same** `source_dataset_id`, `source_run`, `tw` grain token, and **same** `co_registered_group_id`. **Match_status:** **MATCH** on committed metadata.

## 9. Overlap domain and unmatched-row discussion

- **Finite overlap:** **six** `Tp` knots (see `aging_tau_fix05_overlap_domain.csv`).
- **Partial grid caveat:** PRB03 notes **Tp 30** and **Tp 34** **tw** ladder differences vs **Tp 14–26** (`PARTIAL_GRID`); comparison eligibility remains **conservative** (`PARTIAL_PENDING_VALIDATION`).
- **Unmatched/missing/duplicate:** **none** in committed **PRB02B** baseline block (12 rows); forensic placeholder excluded from baseline pairing.

## 10. Local/run dependency disclosure

**Tau CSV** and **sidecar** files referenced by paths under **`results/aging/runs/...`** are **not** guaranteed in every clone; identity proof for this task is **metadata-level** in committed CSVs.

## 11. Row-identity blocker resolution

Governance documentation of **keys and pairing** is **complete**. **UID-complete** row bridge and **comparison_eligibility** flags remain **FIX-06** / policy refresh scope.

## 12. Remaining blockers after FIX-05

- **FIX-06:** Canonical readiness gate; PRB03 **`WARN_LINEAGE_PARTIAL`**, **`rows_comparison_eligible_now=0`**, lineage tokens not **COMPLETE**.
- **Optional:** Regenerate/repair run-local tables for body-level audit.

## 13. What remains forbidden

Canonical tau use, ratios, comparison runner, replay, tau recompute—unchanged.

## 14. Final verdicts

- **Row identity / co-registration (committed semantics):** **CLOSED** with **`PARTIAL_BODY_RUN_LOCAL`** caveat for on-disk bodies.
- **Proceed to FIX-06:** **YES** as next serial gate.

**Explicit:** **No tau values were recomputed** in FIX-05.

See `tables/aging/aging_tau_fix05_status.csv` for machine-readable fields.
