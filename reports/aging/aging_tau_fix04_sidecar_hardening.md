# AGING-TAU-FIX-04-SIDECAR-HARDENING (V2)

## 1. Scope and exclusions

- **Scope:** Harden **committed governance metadata** for baseline **Dip** and **FM** curve-fit tau **sidecars** and bundle policy (PRB03 inventory/field validation/pathway summary), including inventory of required fields, run-local dependency, lineage/policy tokens, and explicit statement that **no tau values were recomputed** in this task.
- **Exclusions:** No MATLAB, Python, Node, replay; no tau computation, refit, ratios, figures; no edits to extraction/fitting logic; no Switching, Relaxation, Maintenance-INFRA, or MT product files; no row-identity closure (FIX-05), readiness gate (FIX-06), ratios, or comparison runner.

## 2. Executive summary

PRB03 **field validation** (`FV_00001`–`FV_00048`) shows required tau-bundle and governance columns **present** for representative baseline rows **TB_INV_BL_DIP_TP14** and **TB_INV_BL_FM_TP14**, with values mirrored from **ledger**, **inventory**, and **sidecar** intent. Run-local paths (`tau_vs_Tp_sidecar.csv`, `tau_FM_vs_Tp_sidecar.csv`, tau tables under `results/aging/runs/...`) are **not** bulk-committed but are **fully referenced** in committed tables. **Lineage** and **row_identity** fields remain **WARN** in PRB03 (not `COMPLETE`), so **tau_bundle_status** stays **`WARN_LINEAGE_PARTIAL`** until FIX-05/FIX-06 refresh PRB policy rows—this FIX-04 **documents** and **freezes** metadata evidence; it does not rewrite PRB03 CSVs.

## 3. Updated repo hygiene policy after MAINT-F01A decision

- **`reports/maintenance/switching_identity_resolver_F01A_audit.md` may be tracked** on `main`; FIX-04 **does not** require it absent from the index.
- FIX-04 staging uses an **exact allow-list** of **seven** paths under `reports/aging/` and `tables/aging/` only.
- **No** `reports/maintenance`, **Switching**, **Relaxation**, or **MT** paths are staged for this commit.

## 4. FIX-01C / FIX-02 / FIX-03 context

- **FIX-01C:** Shared `source_dataset_id`, `source_run`, required consolidation columns (committed bundle).
- **FIX-02:** Dip branch lineage closed at documentation layer (`AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`).
- **FIX-03:** FM branch lineage closed at documentation layer (`AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`).

## 5. Dip sidecar metadata inventory

- **Sidecar path (metadata):** `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_134220_aging_timescale_extraction/tables/tau_vs_Tp_sidecar.csv`
- **Adjacent tau table:** `.../tau_vs_Tp.csv`
- **Producer:** `Aging/analysis/aging_timescale_extraction.m`
- **Key tokens:** `source_dataset_id`, `source_run`, `tau_method` (pointer to full string in sidecar file), `tau_domain`=`DIP_DEPTH_CURVEFIT`, `tau_units`=`seconds`, `tau_input_object`=`Dip_depth`, `tau_input_axis`=`tw`, `lineage_status`=`REQUIRES_DATASET_PATH_AND_DIP_BRANCH_RESOLUTION` (FV still WARN until broader gate).

## 6. FM sidecar metadata inventory

- **Sidecar path (metadata):** `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_135134_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp_sidecar.csv`
- **Adjacent tau table:** `.../tau_FM_vs_Tp.csv`
- **Producer:** `Aging/analysis/aging_fm_timescale_analysis.m`
- **Key tokens:** same shared `source_dataset_id` / `source_run` as Dip baseline; `lineage_status`=`LINEAGE_METADATA_HARDENED_PENDING_F7S`; ABS_ONLY disclosure; `tau_domain`=`FM_ABS_CURVEFIT`.

## 7. Required metadata field matrix

See `tables/aging/aging_tau_fix04_required_metadata_matrix.csv`. All **closure-rule** fields for Dip and FM are **present** in **committed** PRB03 field validation and inventory; **full verbatim sidecar file bodies** remain **run-local**; **policy WARN** remains on lineage/row_identity until FIX-05/FIX-06.

## 8. Local run dependency disclosure

The **on-disk** sidecar and tau CSV files live under **`results/aging/runs/...`** and may be **gitignored**; governance relies on **committed** PRB03/PRB02B paths and PRB03 field validation text. Clones without local runs still have **complete metadata references** in git.

## 9. Policy / lineage status update

- **Pre-FIX-04 (PRB03 pathway summary):** `tau_bundle_status` = **`WARN_LINEAGE_PARTIAL`** for both baseline pathways; dominant blockers **LINEAGE_NOT_COMPLETE_SIDEcar_REQUIRES_DATASET_PATH** (Dip) and **LINEAGE_METADATA_HARDENED_PENDING_F7S** (FM).
- **FIX-04 metadata layer:** **Documented complete** field inventory and disclosure; **does not** automatically change PRB03 status CSV rows.
- **Recommended next lineage tokens:** charter refresh in FIX-05/FIX-06 (out of scope here).

## 10. Sidecar blocker resolution

Governance gap **“what sidecars contain and where”** is **closed** in committed tables; **PRB03 WARN** posture remains until identity/policy tasks.

## 11. Remaining blockers after FIX-04

- **FIX-05:** Row identity / co-registration / partial-grid policy.
- **FIX-06:** Canonical readiness gate; PRB03 policy flags (`BASELINE_*_BUNDLE_STATUS`).
- **PRB03 row refresh:** Optional future edit to flip `lineage_status` / bundle status when chartered.

## 12. What remains forbidden

Canonical tau-as-evidence, ratios, comparison runner, replay, tau recompute—unchanged.

## 13. Final verdicts

- **Sidecar metadata documentation blocker (field inventory + disclosure):** **CLOSED** via FIX-04 artifacts.
- **PRB03 WARN_LINEAGE_PARTIAL** at **policy row level:** **not** auto-cleared here.
- **Proceed to FIX-05:** **YES** as **next governance step** (row identity); conservative **canonical/ratio** use remains **NO**.

**Explicit:** **No tau values were recomputed or refit** in FIX-04.

See `tables/aging/aging_tau_fix04_status.csv` for machine-readable fields.
