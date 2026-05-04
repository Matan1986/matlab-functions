# AGING-PRB-01 — Pathway registry table (version PRB01_V1)

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging infrastructure (repository artifacts only — **no MATLAB**, **no code**, **no comparison logic**).

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Anchors:** [`aging_pathway_registry_bridge_charter_01`](../tables/aging/aging_pathway_registry_bridge_charter_01_pathway_id_contract.csv) (`3c2b084`); baseline evidence **`c7e5d41`**, **`e58b237`**.

---

## Purpose

Ship the **first versioned** Aging **`pathway_id` → semantics** registry as machine-readable CSVs. This **implements PRB_01** from [`aging_pathway_registry_bridge_charter_01_next_tasks.csv`](../../tables/aging/aging_pathway_registry_bridge_charter_01_next_tasks.csv) at the **artifact** layer only.

---

## Contents

| File | Role |
|------|------|
| [`tables/aging/aging_prb01_pathway_registry.csv`](../../tables/aging/aging_prb01_pathway_registry.csv) | Authoritative rows (**PRB01_V1**) |
| [`tables/aging/aging_prb01_pathway_registry_aliases.csv`](../../tables/aging/aging_prb01_pathway_registry_aliases.csv) | Forbidden routing labels vs **`pathway_id`** |
| [`tables/aging/aging_prb01_pathway_registry_validation.csv`](../../tables/aging/aging_prb01_pathway_registry_validation.csv) | Registry self-checks |
| [`tables/aging/aging_prb01_pathway_registry_status.csv`](../../tables/aging/aging_prb01_pathway_registry_status.csv) | Status keys |

---

## Initial rows (PRB01_V1)

1. **`AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`** — consolidation **`Dip_depth`** → **`DIP_DEPTH_CURVEFIT`** tau (evidence **`c7e5d41`** + **`e58b237`**).
2. **`AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`** — consolidation **`FM_abs`** → **`FM_ABS_CURVEFIT`** tau (same evidence commits).
3. **`AGN_WF_FORENSIC_OLD_FIT_REPLAY_F6_V0`** — **forensic** old-fit / F6 / replay family (**not** baseline-validated).

**`comparison_allowed_now`:** **CONDITIONAL** on the two baseline rows (charter **CMP_TAU_BASELINE_DIP_VS_FM**); **multipath robustness** remains **forbidden** until further PRBs. **Forensic** row is **forensic_only YES**.

---

## Non-goals

- No bridge implementation (**PRB_02**).
- No tau-bundle validator code (**PRB_03**).
- No comparison runner (**PRB_05**).
- **`Track A` / `Track B`** are **not** `pathway_id` values (see aliases table).
- **`tau_effective_seconds`** is **not** a pathway (column name only; **G003** bundle required for science use).

---

## Cross-module

No Switching, Relaxation, Maintenance-INFRA, MT, or Aging `.m` edits.
