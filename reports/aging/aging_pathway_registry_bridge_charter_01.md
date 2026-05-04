# AGING-PATHWAY-REGISTRY-BRIDGE-CHARTER-01

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging infrastructure/specification (contracts only — **no code**, **no execution**).

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Anchors:** [`AGING-DECOMPOSITION-TAU-GAP-SURVEY-01`](./aging_decomposition_tau_gap_survey_01.md) (`47d1e2a`); baseline emission [`c7e5d41`](./aging_baseline_tau_sidecar_emission_validation_01.md); baseline output sanity [`e58b237`](./aging_baseline_tau_output_sanity_01.md); **F7V** `tables/aging/aging_F7V_required_bridge_contract.csv`; **F7X2** (Track labels insufficient as IDs).

---

## Purpose

Define **automation-grade contracts** that close gaps **G001** (row identity / bridge), **G002** (pathway registry / opaque IDs), and **G003** (tau bundle / safe `tau_effective_seconds` use) before any **comparison-runner** implementation, **multipath** tau comparison, **multipath** ratio re-entry, or **multipath** visuals / paper figures.

This charter **does not** implement registries, bridges, validators, or runners. It **does not** assert that production MATLAB emits new artifacts yet.

---

## Non-goals

- **Do not** treat **`Track A`** or **`Track B`** as canonical **`pathway_id`** strings (allowed only as **`forbidden_aliases`** or routing notes).
- **Do not** compare numeric **`tau_effective_seconds`** across writers **without** the **tau bundle** (main column + sidecar / companion metadata + lineage).
- **Do not** elevate **old-fit / replay / F6** routes to “baseline canonical” without **bridge audit + paired validation** — default classification remains **forensic / conditional**.

---

## Three contract packets (machine-readable)

| Contract | File | Resolves |
|----------|------|----------|
| **G002** Pathway identity | `aging_pathway_registry_bridge_charter_01_pathway_id_contract.csv` | Opaque `pathway_id` tied to **source observable**, **decomposition/source family**, **tau method/domain**, **dataset family** |
| **G001** Row identity / bridge | `aging_pathway_registry_bridge_charter_01_row_identity_contract.csv` | Mandatory keys for pairing rows across families; **bridge outputs** when crossing **grain** or **family** |
| **G003** Tau bundle | `aging_pathway_registry_bridge_charter_01_tau_bundle_contract.csv` | Minimum fields; maps **`tau_effective_seconds`** to **`tau_value_field`** only inside bundle |

---

## Allowed comparisons (declarative)

Authoritative rows: `tables/aging/aging_pathway_registry_bridge_charter_01_allowed_comparisons.csv`.

- **Baseline Dip vs FM** (\(\tau\) **comparison** on matched **Tp**): **CONDITIONAL** — requires **both** pathways’ **tau bundles** + **same** `source_dataset_id` / consolidation hash policy + **OUTPUT-SANITY-01**-class pairing; **ratio** / **authoritative** claims remain **F7T** / **F7S** gated.
- **Consolidation vs Track-A summaries**: **NO** or **CONDITIONAL** only **after** chartered **F7V**-style **bridge** rows exist and pass audit (**G001**).
- **Multipath robustness**: **NO** until registry rows + bridges + bundles exist for **every** pathway in the matrix.

---

## Relationship to F7V bridge table

`aging_F7V_required_bridge_contract.csv` lists **bridge_id** patterns (**BRIDGE_SIGN_VISIBILITY**, **BRIDGE_LONG_COMPONENT_TABLE**, …). This charter **requires** any cross-family comparison to name **which bridge_id** applies and to emit **`required_bridge_output`** per **`row_identity_contract`** — **implementation remains future**.

---

## Next implementation tasks

See `tables/aging/aging_pathway_registry_bridge_charter_01_next_tasks.csv` (registry table → bridge/audit → tau bundle validator → comparison matrix → **later** runner).

---

## Cross-module

No Switching, Relaxation, Maintenance-INFRA, MT, or MATLAB edits. No MATLAB, Python, replay, tau, ratio, or visualization execution.
