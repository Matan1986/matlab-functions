# AGING-BASELINE-TAU-DISCLOSURE-CLOSURE-01 — B-003 baseline tau disclosure contract

**Agent:** Narrow Aging tau-disclosure closure (metadata only).  
**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Execution:** No MATLAB, no replay, no tau computation, no ratio computation, no modifications to existing tau scripts or outputs in this task. No edits to existing governance docs under `docs/`; this report and companion CSVs are additive artifacts under `reports/aging/` and `tables/aging/`.  
**Preflight:** `git diff --cached --name-only` was **empty** at task start.  
**Precedence:** Runs after `AGING-TAU-METADATA-GATE-01`, `AGING-DIP-FM-TW-INVENTORY-01`, `AGING-OLD-FIT-SUMMARY-METHOD-AUDIT-01`, and commit `a5959b9` (baseline re-entry gate archive).

---

## Scope

Define the **baseline dip** and **baseline FM** tau **disclosure and sidecar contract** required before any **authoritative** use of the shared column name **`tau_effective_seconds`**, and state **ratio prerequisites** for **`R_tau_FM_over_tau_dip`** (governance narrative **`R_age`**) without performing extraction, ratio calculation, or code changes.

**In scope:** Domain map, required sidecar fields, writer/consumer obligations, ratio pairing rules, open items, status keys.  
**Out of scope:** Switching, Relaxation, Maintenance/INFRA, MT, physics interpretation, script edits, multipath lane promotion.

---

## Source basis

| Layer | Artifacts |
|--------|-----------|
| Tau metadata gate | `reports/aging/aging_tau_metadata_gate_01.md`, `tables/aging/aging_tau_metadata_gate_01_*.csv` |
| Wait-time inventory | `reports/aging/aging_dip_fm_tw_inventory_01.md`, `tables/aging/aging_dip_fm_tw_inventory_01_tau_readiness.csv` |
| Old fit/summary audit | `reports/aging/aging_old_fit_summary_method_audit_01.md`, `tables/aging/aging_old_fit_summary_method_audit_01_status.csv` |
| F7X5 / F7X4 | `reports/aging/aging_F7X5_definition_contract_draft.md` (sec. 16 tau gate), `tables/aging/aging_F7X5_required_metadata_schema.csv`, `tables/aging/aging_F7X5_forbidden_or_qualified_terms.csv`, `tables/aging/aging_F7X4_tau_effective_seconds_resolution.csv` |
| Code anchors (read-only) | `Aging/analysis/aging_timescale_extraction.m`, `Aging/analysis/aging_fm_timescale_analysis.m`, `Aging/analysis/aging_clock_ratio_analysis.m` |

---

## What B-003 was

**B-003** is the **dual-builder disclosure** problem: **`tau_effective_seconds`** is written by **two different effective builders** — **`buildConsensusTau`** (dip, `tau_vs_Tp.csv`) and **`buildEffectiveFmTau`** (FM, `tau_FM_vs_Tp.csv`) — so the **column name alone does not identify domain, method, or input object**. Authoritative use requires **`tau_domain`**, **method/consensus disclosure**, **producer**, **artifact path**, **lineage**, and related fields per F7X4/F7X5. This closure **names** the two baseline domains and **lists** mandatory sidecar fields; it does **not** assert that all writers already emit them in full.

---

## Dip tau domain closure

| Item | Contract |
|------|-----------|
| **Producer** | `Aging/analysis/aging_timescale_extraction.m` |
| **Output artifact** | `tau_vs_Tp.csv` (run-scoped `tables/`) |
| **Input object** | **`Dip_depth` vs `tw`** per **`Tp`** from Track B consolidation |
| **Input artifact** | `aging_observable_dataset.csv` (path from run / `AGING_OBSERVABLE_DATASET_PATH`) |
| **Effective builder** | **`buildConsensusTau`** |
| **Required domain label** | **`DIP_DEPTH_CURVEFIT`** (canonical for this closure); logical display **`tau_Dip_depth_curvefit`**; prior gate inventory used **`DIP_MEMORY_CURVEFIT`** — map when joining legacy tables (see `aging_baseline_tau_disclosure_closure_01_domain_map.csv`). |

---

## FM tau domain closure

| Item | Contract |
|------|-----------|
| **Producer** | `Aging/analysis/aging_fm_timescale_analysis.m` |
| **Output artifact** | `tau_FM_vs_Tp.csv` |
| **Input object** | **`FM_abs` vs `tw`** per **`Tp`** |
| **Input artifact** | Same consolidation plus dip **`tau_vs_Tp.csv`** and cfg dip-branch diagnostics as configured |
| **Effective builder** | **`buildEffectiveFmTau`** (half-range primary when valid, else log-median consensus pattern) |
| **Required domain label** | **`FM_ABS_CURVEFIT`**; logical display **`tau_FM_abs_curvefit`** |
| **Required disclosure** | **`FM_abs` is `ABS_ONLY`** (magnitude collapsed; not signed FM dynamics) |

---

## Shared field policy: `tau_effective_seconds`

**`tau_effective_seconds` is allowed only with accompanying metadata** that resolves **B-003 ambiguity**. Minimum concepts (machine-facing detail in `aging_baseline_tau_disclosure_closure_01_required_sidecar_schema.csv`):

- **`tau_domain`**, **`tau_method`**, **`tau_input_object`**, **`producer_script`**, **`source_artifact`**, **`source_run` or `lineage_status`**, **`grain`**, **`units`**, **`builder_rule`**
- **`trusted_component_tau_fields`** or **`consensus_methods`** (companion to effective tau per F7X4)
- Where relevant: **`pairing_key`**, **`source_dataset_id`**, **`grid_disclosure`**, **`sign_or_magnitude_disclosure`**

Standalone use of **`tau_effective_seconds`** without this bundle remains **contract-forbidden** per F7X5 forbidden terms for that column.

---

## Writer / sidecar requirements

See **`tables/aging/aging_baseline_tau_disclosure_closure_01_writer_requirements.csv`**.

Summary:

- **Dip and FM producers** must plan to **write** a sidecar or manifest with the bundle **alongside** each tau CSV (policy requirement; implementation status tracked under open items).
- **`aging_clock_ratio_analysis.m`** must only combine tau inputs when **paired paths**, **`Tp`** pairing, and **lineage** are recorded.
- **Future display consumers** must **refuse** or **mask** **`tau_effective_seconds`** when mandatory fields are absent.

---

## Ratio prerequisites

See **`tables/aging/aging_baseline_tau_disclosure_closure_01_ratio_prerequisites.csv`**.

**`R_tau_FM_over_tau_dip`** (and governance **`R_age`** aligned to that combinator) is allowed only after:

- **`tau_vs_Tp.csv`** and **`tau_FM_vs_Tp.csv`** are **paired** from a **consistent** `aging_observable_dataset` build (or mismatch explicitly documented).
- **Pairing key** is **`Tp`** (script merges on `Tp`).
- **Both tau domains** are **disclosed** (sidecar/metadata).
- **`tau_effective_seconds`** ambiguity is **resolved** via sidecar, not column name alone.
- **Missing `tw=3` at Tp 30/34** is **disclosed** or handled by a **defined scope/narrowing policy** for symmetric short-time claims.

---

## What remains blocked

- **Authoritative ratio re-entry** remains **PARTIAL** until paired manifests, **`source_dataset_id`** discipline, and optional **bridge** gates from multipath status are satisfied outside this artifact.
- **Symmetric multi-Tp tau comparison** at **Tp 30/34** remains **PARTIAL** until **`tw=3`** gap is addressed or scope restricted (inventory).
- **Track A** **`AFM_like` / `FM_like`** remain **not substitutable** for baseline tau inputs without **bridge** (old-fit audit).

---

## Recommended next action

Implement **machine-readable sidecar/manifest emission** in **`aging_timescale_extraction.m`** and **`aging_fm_timescale_analysis.m`** per **`aging_baseline_tau_disclosure_closure_01_writer_requirements.csv`**, then execute baseline tau extraction **only** under repository MATLAB wrapper policy when permitted, with **`READY_FOR_BASELINE_TAU_EXTRACTION = YES_WITH_SIDECAR`** until writers catch up.

---

## Machine-readable outputs (this task)

| File | Role |
|------|------|
| `reports/aging/aging_baseline_tau_disclosure_closure_01.md` | This report |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_domain_map.csv` | Dip vs FM domain map |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_required_sidecar_schema.csv` | Required metadata fields |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_writer_requirements.csv` | Producer/consumer rules |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_ratio_prerequisites.csv` | Ratio pairing prerequisites |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_open_items.csv` | Remaining blockers |
| `tables/aging/aging_baseline_tau_disclosure_closure_01_status.csv` | Status keys |

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT files were modified in this task.
