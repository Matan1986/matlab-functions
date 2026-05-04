# AGING-PRB-02 — F7V row-identity bridge audit design

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging bridge/audit **design only** — **no MATLAB**, **no bridge implementation**, **no validator**, **no runner**.

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Anchors:** [`aging_pathway_registry_bridge_charter_01`](../../tables/aging/aging_pathway_registry_bridge_charter_01_row_identity_contract.csv) (`3c2b084`); **PRB01** registry (`1da9829`); **`aging_F7V_required_bridge_contract.csv`**.

---

## Scope

Turn the charter **row-identity contract** and **F7V bridge table** into an **executable audit specification**: what inputs a future bridge job must read, which **identity keys** must be satisfied, which **checks** pass/fail, and which **failure modes** block **canonical cross-pathway comparison** vs allow **forensic/audit-only** output.

This document **does not** claim:
- the bridge is **implemented** (`BRIDGE_IMPLEMENTED = NO`);
- any row pair is **validated** (`ROW_IDENTITY_VALIDATED = NO`);
- **multipath** comparison is **allowed** (`MULTIPATH_COMPARISON_ALLOWED_NOW = NO`).

---

## Audit flow (future implementation)

1. **Load** inputs listed in `aging_prb02_f7v_bridge_input_inventory.csv` (charter, registry, consolidation dataset, sidecars when comparing tau, F7V bridge contract).
2. For each candidate comparison in `aging_pathway_registry_bridge_charter_01_allowed_comparisons.csv`, select **identity keys** from `aging_prb02_f7v_bridge_identity_keys.csv` by `pathway_id` / family.
3. Run **audit checks** in `aging_prb02_f7v_bridge_audit_checks.csv` in order; record pass/fail and whether **comparison** or **runner** is blocked.
4. On fail, map to `aging_prb02_f7v_bridge_failure_modes.csv` for **severity** and **required response** (e.g. emit bridge long table, halt science lane, allow audit-only table).

**Track A / Track B:** remain **aliases only** per `aging_prb01_pathway_registry_aliases.csv` — not `pathway_id` values.  
**Old-fit / F6:** remain **forensic** until `ID_FORENSIC_LEGACY_ROW` + optional F6 bridge manifest satisfies checks.

---

## Machine-readable deliverables

| File | Role |
|------|------|
| `tables/aging/aging_prb02_f7v_bridge_input_inventory.csv` | Required inputs and roles |
| `tables/aging/aging_prb02_f7v_bridge_identity_keys.csv` | Keys, joins, missingness |
| `tables/aging/aging_prb02_f7v_bridge_audit_checks.csv` | Pass/fail gates |
| `tables/aging/aging_prb02_f7v_bridge_failure_modes.csv` | Severity and responses |
| `tables/aging/aging_prb02_f7v_bridge_status.csv` | Status keys |

---

## Cross-module

No Switching, Relaxation, Maintenance-INFRA, MT, or Aging `.m` edits.
