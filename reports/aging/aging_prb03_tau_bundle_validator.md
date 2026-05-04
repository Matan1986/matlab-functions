# Aging PRB03 — Tau-bundle validator prototype

**Validator version:** `PRB03_V1`  
**Primary ledger:** PRB02B F7V bridge (`tables/aging/aging_prb02b_f7v_bridge_ledger.csv`)

This document records a **metadata-only** tau-bundle completeness check. It does **not** perform science comparisons, does **not** compute or refit tau, does **not** compute ratios or metrics, and does **not** generate figures.

---

## 1. Scope and non-scope

**In scope**

- Map each PRB02B ledger row to a `bundle_row_id` inventory row.
- Verify presence or explicit disclosure of charter tau-bundle fields and PRB governance columns using existing tables and run-local sidecars referenced by the ledger.
- Classify each bundle row as `WARN_LINEAGE_PARTIAL`, `FAIL_BLOCKED`, etc., and set conservative `comparison_eligibility`.
- Emit inventory, per-field validation (representative rows), pathway-level summary, and machine-readable status flags.

**Out of scope**

- Comparison runners, ratio engines, multipath tau equivalence claims, recomputation of numerical tau, refits, metrics, or visualizations.
- Changes to Switching, Relaxation, Maintenance-INFRA, MT, or unrelated repo backlog.

---

## 2. Inputs read

| Artifact | Role |
| --- | --- |
| `reports/aging/aging_pathway_registry_bridge_charter_01.md` | Bridge charter context |
| `tables/aging/aging_pathway_registry_bridge_charter_01_tau_bundle_contract.csv` | Required tau-bundle field names |
| `tables/aging/aging_pathway_registry_bridge_charter_01_allowed_comparisons.csv` | Policy cross-reference (not executed here) |
| `tables/aging/aging_pathway_registry_bridge_charter_01_status.csv` | Charter status snapshot |
| `reports/aging/aging_prb01_pathway_registry_table.md` | Registry narrative |
| `tables/aging/aging_prb01_pathway_registry.csv` | Pathway definitions and decomposition text |
| `tables/aging/aging_prb01_pathway_registry_aliases.csv` | Alias map |
| `tables/aging/aging_prb01_pathway_registry_validation.csv` | Registry validation |
| `tables/aging/aging_prb01_pathway_registry_status.csv` | Registry status |
| `reports/aging/aging_prb02b_f7v_bridge_ledger_export.md` | PRB02B export narrative |
| `tables/aging/aging_prb02b_f7v_bridge_ledger.csv` | **Primary row source** |
| `tables/aging/aging_prb02b_f7v_bridge_ledger_audit.csv` | Audit cross-check |
| `tables/aging/aging_prb02b_f7v_bridge_input_sources.csv` | Input provenance |
| `tables/aging/aging_prb02b_f7v_bridge_status.csv` | Bridge status |
| `results/.../tau_vs_Tp_sidecar.csv` (Dip run cited by ledger) | Dip tau-bundle metadata |
| `results/.../tau_FM_vs_Tp_sidecar.csv` (FM run cited by ledger) | FM tau-bundle metadata |

Baseline sanity / sidecar emission reports listed in the task were **not** required to resolve blocking flags beyond PRB02B + sidecars; they remain optional corroboration for future audits.

---

## 3. Tau-bundle contract summary

Per `aging_pathway_registry_bridge_charter_01_tau_bundle_contract.csv`, the following **minimum** fields are validated (values sourced from ledger + sidecars + PRB01 narrative where cited):

- `tau_value_field`, `tau_units`, `tau_domain`, `tau_method`, `tau_input_object`, `tau_input_axis`
- `source_observable`, `decomposition_method`, `component_definition`, `producer_script`, `source_artifact`, `source_run`, `source_dataset_id`
- `lineage_status`, `sign_or_magnitude_disclosure`, `grid_disclosure`, `output_artifact`

**PRB governance** (additional required validation targets):

- `pathway_id`, `pathway_family`, `row_identity_key`, `co_registered_group_id`, `row_identity_status`, `forensic_only`, `allowed_for_comparison`

---

## 4. How PRB02B ledger rows map into bundle rows

| bridge_row_id | bundle_row_id | Rule |
| --- | --- | --- |
| `BL_DIP_TP*` | `TB_INV_BL_DIP_TP*` | One-to-one; validator_version `PRB03_V1`; bridge_version `PRB02B_V1`. Dip sidecar fields merged for metadata columns. |
| `BL_FM_TP*` | `TB_INV_BL_FM_TP*` | One-to-one; FM sidecar merged similarly. |
| `FORENSIC_F6_NO_ROW_LEDGER` | `TB_INV_FORENSIC_F6_NO_ROW_LEDGER` | Placeholder forensic row; ledger explicitly lacks committed row-level sources. |

No synthetic rows were added; **13** ledger rows yield **13** inventory rows.

---

## 5. Bundle field completeness results

**Baseline Dip (`AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`)**

- Charter columns are largely **PRESENT** via `tau_vs_Tp.csv` run folder and `tau_vs_Tp_sidecar.csv` (method, units, domain, inputs, disclosures, output artifact name).
- `lineage_status` is **REQUIRES_DATASET_PATH_AND_DIP_BRANCH_RESOLUTION** — not a COMPLETE closure token → bundle graded **`WARN_LINEAGE_PARTIAL`**.
- `row_identity_status` from PRB02B is **OK_LINEAGE_PARTIAL_REQUIRES_F7S** → **`comparison_eligibility` = `PARTIAL_PENDING_VALIDATION`** per conservative rule.

**Baseline FM (`AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`)**

- Charter columns **PRESENT** from `tau_FM_vs_Tp_sidecar.csv` and ledger paths.
- `lineage_status` **LINEAGE_METADATA_HARDENED_PENDING_F7S** → **`WARN_LINEAGE_PARTIAL`**; **`PARTIAL_PENDING_VALIDATION`**.

**Forensic old-fit replay (`AGN_WF_FORENSIC_OLD_FIT_REPLAY_F6_V0`)**

- `source_artifact` = **`MISSING_COMMITTED_ROW_LEVEL_SOURCE`**; tau columns explicitly **NOT_APPLICABLE** / **UNKNOWN** where ledger records UNKNOWN.
- **`forensic_only` = YES** → **`comparison_eligibility` = NO** mandatorily.
- **`tau_bundle_status` = FAIL_BLOCKED** for this prototype row.

**Field validation table scope**

- Per-field rows are emitted for **three representatives**: `TB_INV_BL_DIP_TP14`, `TB_INV_BL_FM_TP14`, `TB_INV_FORENSIC_F6_NO_ROW_LEDGER`.
- Remaining baseline rows at other `Tp` reuse **identical** sidecar-backed metadata within each pathway family (only `bridge_row_id`, `Tp`, and `co_registered_group_id` differ per PRB02B).

---

## 6. Pathway-level conclusions

See `tables/aging/aging_prb03_tau_bundle_pathway_summary.csv`.

- **Dip** and **FM** consolidation pathways: **0** rows at **`PASS`** bundle state; **6** rows each at **`WARN`**; dominant blockers are **incomplete lineage / conditional comparison**.
- **Forensic F6**: **1** row, **`FAIL_BLOCKED`**, dominant blocker **no registered row-level source**.
- **`rows_comparison_eligible_now` = 0** for every pathway in this prototype classification.

---

## 7. Explicit blocked actions (until policy clears)

- Multipath tau comparison **not authorized** by this artifact.
- Ratio re-entry and comparison runner implementation **remain blocked** (`safe_for_* = NO` in pathway summary).
- Forensic pathway remains **audit-only** until a committed tau-bearing row set and sidecars exist.

---

## 8. Whether comparison matrix design may proceed

**Yes — declaratively only.**  
`READY_FOR_COMPARISON_MATRIX_DESIGN` is **YES** because pass / warn / fail semantics and blocking columns are now tabulated. Matrix design must treat cells as **eligibility grammar**, not execution permission.

---

## 9. Why comparison runner, ratio work, and visualization remain blocked

- **Runner:** `allowed_for_comparison` is **CONDITIONAL**, lineage tokens are not **COMPLETE**, and forensic rows are hard-blocked — insufficient for a trustworthy automated join or runner contract.
- **Ratios:** Partial lineage and partial grid disclosure (`PARTIAL_GRID` family) block authoritative cross-pathway or cross-grid ratio claims without additional governance closure.
- **Visualization:** Out of scope for PRB03; no viz artifacts produced.

---

## 10. Recommended next action

1. **Archive** the five PRB03 artifacts together as an evidence bundle when committing Aging work.
2. **Close lineage blockers** called out in Dip and FM sidecars (dataset path / Dip branch resolution; F7S FM hardening) before lifting `WARN` states.
3. **Register forensic sources** or extend PRB02B with explicit row-level artifacts before revisiting forensic bundle status.

---

## Mandatory non-claims (explicit)

- This validator **does not compute tau**.
- This validator **does not refit tau**.
- This validator **does not compute ratios**.
- This validator **does not permit multipath comparison** by itself.
- Old-fit / replay remains **forensic** unless a **complete tau bundle** and **complete row identity** are proven from committed artifacts.

---

## Output artifacts

| File | Description |
| --- | --- |
| `reports/aging/aging_prb03_tau_bundle_validator.md` | This report |
| `tables/aging/aging_prb03_tau_bundle_inventory.csv` | One row per PRB02B ledger row |
| `tables/aging/aging_prb03_tau_bundle_field_validation.csv` | Per-field validation for representative bundle rows |
| `tables/aging/aging_prb03_tau_bundle_pathway_summary.csv` | Aggregated pathway posture |
| `tables/aging/aging_prb03_tau_bundle_status.csv` | Key/value status for automation and humans |

**Execution:** MATLAB **NO** / Python **NO** / Node **NO** — tables produced by direct synthesis from existing CSV inputs and verified sidecar paths.
