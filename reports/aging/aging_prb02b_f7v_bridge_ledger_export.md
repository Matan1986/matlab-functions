# AGING-PRB-02B — F7V bridge ledger / export prototype

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging bridge-ledger prototype (repository artifacts; **no comparison runner**; **no tau/ratio** computation in this task).

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Execution:** **No MATLAB, no Python, no replay** — the ledger was assembled from **committed validation tables** and **on-disk** `tau_*_sidecar.csv` files under the **c7e5d41** run roots (read for `source_run` / `source_dataset_id` / `tau_method` text).

---

## What was delivered

| Artifact | Role |
|----------|------|
| [`tables/aging/aging_prb02b_f7v_bridge_ledger.csv`](../../tables/aging/aging_prb02b_f7v_bridge_ledger.csv) | **13** rows: **12** baseline (**Dip** + **FM** × **six** `Tp` from OUTPUT-SANITY-01 pairing) + **1** forensic **blocked** placeholder (**no invented F6 rows**) |
| [`tables/aging/aging_prb02b_f7v_bridge_ledger_audit.csv`](../../tables/aging/aging_prb02b_f7v_bridge_ledger_audit.csv) | Audit outcomes incl. **CHK_BRIDGE_LEDGER_PRESENT** **PASS** and **CHK_ID_BRIDGE_CO_REGISTERED** **PARTIAL** |
| [`tables/aging/aging_prb02b_f7v_bridge_input_sources.csv`](../../tables/aging/aging_prb02b_f7v_bridge_input_sources.csv) | Provenance of inputs |
| [`tables/aging/aging_prb02b_f7v_bridge_status.csv`](../../tables/aging/aging_prb02b_f7v_bridge_status.csv) | Status keys |

**No** `Aging/validation/run_aging_prb02b_f7v_bridge_ledger_export.m` was added — regeneration can be manual or scripted later.

---

## Interpretation (strict)

- **`CHK_BRIDGE_LEDGER_PRESENT`:** **Satisfied** — a ledger file exists with baseline **co_registered_group_id** keys (`CO_REG_BASELINE_TP_*`).
- **`ID_BRIDGE_CO_REGISTERED`:** **Partially** satisfied — prototype emits **`bridge_row_id`**, **`pathway_id`**, **`co_registered_group_id`**, and **`row_identity_key`**. It does **not** yet emit arbitrary **pauseRun** **`left_row_uid`/`right_row_uid`** pairs required for full cross-grain **F7V** bridges (**BRIDGE_LONG_COMPONENT_TABLE** class).
- **Row identity “validated fully”:** **NO** — sidecars still carry **PARTIAL** lineage strings (`REQUIRES_DATASET_PATH…`, `…PENDING_F7S`).
- **Old-fit / F6:** **Forensic only** — placeholder row **`BLOCKED_NO_REGISTERED_FORENSIC_ROWS`**; **no fake** `Tp`/`tw`/`source_run`.

---

## Cross-module

No Switching, Relaxation, Maintenance-INFRA, MT, or unrelated Aging pipeline edits.
