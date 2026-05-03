# F7R — Aging FM tau lineage policy and metadata hardening plan

Governance planning artifact only. **No** MATLAB, **no** code edits in this task, **no** ratio writers, **no** physics interpretation, **no** branch ranking, **no** staging / commit / push. Evidence draws on committed **F7N / F7O / F7P / F7Q** artifacts and static inspection of `Aging/analysis/aging_fm_timescale_analysis.m`. Reference: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Anchor:** `8ccd3fa` — *Audit Aging F7Q FM tau lineage resolution*.

---

## 1. Purpose

Convert **F7Q** lineage findings into **actionable policy** and a **metadata-hardening specification** so future `tau_FM_vs_Tp.csv` outputs and downstream consumers cannot silently mix branches, misuse ineligible rows, or treat auxiliary inputs as lineage-closed without explicit rules.

---

## 2. Checkpoint naming (post-F7R)

The required module checkpoint after lineage/metadata **repairs** is:

**`F7S_AGING_MODULE_POST_REPAIR_READINESS_AUDIT`**

This is a **module-level post-repair readiness / health audit** for Aging—internal consistency, artifact completeness, hardened-or-explicitly-blocked metadata, and clear allowed/forbidden next steps—**before** **R_age / clock-ratio** work or broad modeling. It is **not** a ratio-specific step and must not be labeled as a “pre-ratio alignment stop” as the primary name.

**Order of operations:** F7R planning (this memo) → **`F7R_IMPLEMENT_METADATA_HARDENING`** (implementation tranche; chartered separately) → **`F7S_AGING_MODULE_POST_REPAIR_READINESS_AUDIT`**.

---

## 3. Summary decisions

| Area | Decision |
|------|-----------|
| **Metadata** | Add **row-level** and **run-level** machine-readable lineage: **branch_id**, cfg triple (**datasetPath**, **dipTauPath**, **failedDipClockMetricsPath**), **FM_abs** convention fields, **row_* use flags**, exclusion reasons; either **new CSV columns** and/or **canonical sidecar manifest** referencing the same run (see tables). |
| **FM_abs convention** | **Not** fully resolved by code alone—**PARTIAL**: writer fits **`FM_abs`** as read (**no** `abs()` in `analyzeFmTpGroup`). Policy requires **dataset contract** + optional signed-column reconciliation **before** treating “abs” as semantically guaranteed. |
| **Row use** | **`has_fm = 0`** or non-finite **`tau_effective_seconds`**: **no model use / no ratio use**. Low **`n_points`** / **fragile_low_point_count**: **scoped use only** unless governance upgrades. |
| **Branches** | **FM_O_22row_A** and **FM_O_30row_B** (or successor IDs)—**no silent mixing**, **no untagged** `tau_FM`, cross-branch numerators/denominators **forbidden** without explicit charter. |
| **dipTauPath** | **Accepted as paired input**—does **not** feed FM tau fit per F7Q; future ratio use requires **branch-pair compatibility** manifest with FM tau row selection (do **not** reopen dip extraction unless mismatch is evidenced). |
| **failedDipClockMetricsPath** | Classify uses: **smoke/audit** and **report narrative** OK with shared archival **if documented**; **model-use** and **ratio-use** require **written policy**—either approve shared auxiliary + disclosure or **per-branch regen** (**NEEDS_POLICY** until closed). |
| **Code hygiene** | **`loadFailedDipClockMetrics`** hard-coded **`run_id`**, missing triple in tau rows, duplicated global **`model_use_allowed`** on ineligible rows—schedule explicit tasks (**no implementation here**). |
| **Model-use gate** | **`NO_UNLESS_LINEAGE_RESOLVED`** remains until hardening tasks + dataset convention + optional F7S pass—see **`aging_F7R_model_use_gate.csv`**. |
| **R_age / clock-ratio** | **Not generally approved**—requires hardened metadata, branch manifest, row rules, and failed-clock policy resolution per gates table. |

---

## 4. Machine-readable deliverables

| File |
|------|
| `reports/aging/aging_F7R_lineage_policy_metadata_hardening_plan.md` (this file) |
| `tables/aging/aging_F7R_required_metadata_fields.csv` |
| `tables/aging/aging_F7R_fm_convention_policy.csv` |
| `tables/aging/aging_F7R_row_use_policy.csv` |
| `tables/aging/aging_F7R_branch_policy.csv` |
| `tables/aging/aging_F7R_dip_tau_compatibility_policy.csv` |
| `tables/aging/aging_F7R_failed_clock_policy.csv` |
| `tables/aging/aging_F7R_code_hardening_tasks.csv` |
| `tables/aging/aging_F7R_model_use_gate.csv` |
| `tables/aging/aging_F7R_R_age_clock_ratio_gate.csv` |
| `tables/aging/aging_F7R_F7S_post_repair_readiness_audit_spec.csv` |
| `tables/aging/aging_F7R_remaining_actions.csv` |
| `tables/aging/aging_F7R_status.csv` |

Verdicts: `tables/aging/aging_F7R_status.csv`.

---

## 5. Constraint confirmation

| Constraint | Status |
|------------|--------|
| Aging-only governance planning | **Yes** |
| No Switching / Relaxation / MT | **Yes** |
| No implementation in F7R | **Yes** |
