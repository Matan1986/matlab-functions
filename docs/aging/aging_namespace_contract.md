# Aging — Namespace contract (binding)

**Version:** F6S-1.0  
**Scope:** Aging module observables only.  
**Status:** Contract documentation; enforcement via future writers/validators.

This contract defines **namespaces** for observable identifiers. A **full observable identity** is always **`namespace` + `registry_id` + formula/writer lineage** per `aging_observable_registry_contract.md`.

---

## Namespace table

| Namespace | Meaning | Allowed use | Forbidden use | Allowed in tau/R | Allowed in cross-run comparison | Promotion requirements | Required metadata |
|-----------|---------|-------------|---------------|------------------|--------------------------------|------------------------|-------------------|
| **legacy_old** | Observables from runs/schemas **before** this contract; formulas often implicit | Read-only replay; documented bridges | Canonical promotion without migration audit | Only if **explicit** bridge row maps to resolved registry IDs | **NO** unless bridge + parity proof | Migration script + F6-style parity | `legacy_run_id`; `approx_formula`; `bridge_registry_id` |
| **stage4_S4A** | Dip-related scalars from **stage4** path **S4A**: `Dip_depth_source = afm_amp_residual` (typically **`AFM_amp`** / height-style mean of sharp residual in dip window) | Structured export columns tagged S4A; replay parity tests | Mixing with **stage4_S4B** under same column label `Dip_depth` | **YES** for `tau_Dip` **only** when `tau_input_registry_id` references S4A | **YES** vs other S4A with matching identity | Registry lock + replay hashes | `formula_id=DIP_S4A_*`; `Dip_depth_source`; `AFM_metric_main`; `agingMetricMode` |
| **stage4_S4B** | Dip-related scalars from **stage4** path **S4B**: `Dip_depth_source = raw_deltam_window_metric_noncanonical` (max raw **ΔM** in dip window) | Same as S4A but **never** merged without tag | Passing as “the” Dip without tag | **YES** for `tau_Dip` when reference is S4B | **YES** vs other S4B with matching identity | Same | `formula_id=DIP_S4B_*`; window definition; `Tp`/`dip_window_K` |
| **current_export** | Observables emitted by **present** `aging_structured_results_export`-family writers **with** sidecar (once implemented) | Active pipelines; interim canonical candidate feed | Declaring “final canonical” without promotion gate | **PARTIAL** until `registry_id` + namespaces frozen | **PARTIAL** — must match sidecar | Sidecar complete per writer contract | Full lineage sidecar |
| **canonical_candidate** | Observables that **passed** replay parity and review but **not** yet ratified | Staging for tau/R experiments labeled candidate | Production claims without drop of “candidate” | **YES** with explicit `candidate` flag in tau tables | **YES** within candidate cohort | Parity vs locked inputs + doc sign-off | All identity fields + reviewer id |
| **canonical** | Ratified registry rows only | Published comparisons; policy tau/R | Mixing with legacy without bridge | **YES** when row cites canonical `registry_id` | **YES** when identities match | Governance sign-off per repo policy | Full manifest + version stamp |
| **diagnostic** | Audits, smoke tests, ad-hoc plots — **not** guaranteed stable definitions | Internal QA; **not** downstream without upgrade | Feeding tau/R or “official” R without promotion | **NO** default | **NO** default | Promotion = new registry row + writer change | `diagnostic=true` |
| **deprecated** | Superseded names/formulas; kept for history | Migration tooling; warnings | New writes | **NO** | **NO** | N/A | `replaced_by_registry_id` |
| **unknown** | Namespace not established | **Do not use** for new work | Any tau/R or cross-run claim | **NO** | **NO** | Resolve to one of above | — |

---

## Cross-namespace rules

1. **Plain column name alone** is never sufficient for identity (see identity contract).
2. **stage4_S4A** and **stage4_S4B** values **must not** be compared or ratioed **without** explicit bridge validation (F6Q).
3. **legacy_old** may connect to **stage4_S4A** or **S4B** only through a **documented bridge** row in the registry or a migration table.

---

## Related documents

- `docs/aging/aging_observable_registry_contract.md`
- `docs/aging/aging_writer_output_contract.md`
- `tables/aging/aging_F6S_namespace_policy.csv`
