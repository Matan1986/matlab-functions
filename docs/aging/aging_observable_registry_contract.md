# Aging — Observable registry contract (binding)

**Version:** F6S-1.0  
**Scope:** Aging module.

## Fundamental rule

```text
Same column name alone is never sufficient observable identity.
```

Two numeric series may share **`Dip_depth`** (or any plain name) and still be **different observables**. Identity requires the **full tuple** in §2.

---

## Identity fields (required for every exported/scientific use)

| Field | Description |
|--------|-------------|
| **observable_name** | Human-readable token (e.g. `Dip_depth`) — **not** unique. |
| **namespace** | One of the namespaces in `aging_namespace_contract.md`. |
| **registry_id** | Stable machine id (e.g. `AGING-OBS-DIP-S4A-001`) from `aging_F6S_registry_entries.csv`. |
| **formula_id** | Frozen formula tag (e.g. `DIP_S4A_AFM_AMP_V1`, `DIP_S4B_RAW_MAX_V1`). |
| **writer_id** | Writer script/function + version (e.g. `aging_structured_results_export@hash`). |
| **source_run_id** | Run directory / manifest id for the producing run. |
| **input_artifact_ids** | Hashes or paths of **inputs** (e.g. raw traces, `DeltaM_map` hash). |
| **config_hash** or **config snapshot** | Immutable description of `agingConfig` + relevant stage flags. |
| **code_commit** or **code fingerprint** | Repo state for **stage4** + **analyzeAFM_FM_*** + export script. |
| **units** | SI or documented project units. |
| **sign_convention** | e.g. `non_negative_scalar`, `signed_step`, `abs_from_signed`. |
| **preprocessing_contract** | Stage1–3 flags (filter, align, sgolay on trace, etc.). |
| **component_extraction_contract** | `agingMetricMode`, `AFM_metric_main`, robust baseline flags. |
| **scalarization_contract** | How a curve becomes one number (`Dip_depth_source`, window bounds). |

---

## Registry

Authoritative tabular form: **`tables/aging/aging_F6S_registry_entries.csv`**.  
This file is the **single source of truth** for **registry_id** and **formula_id** bindings until superseded by a semver bump.

---

## Dip_depth special case

- Use **`Dip_depth_S4A`** and **`Dip_depth_S4B`** as **logical names** in registry and tau/R metadata even if CSV columns remain `Dip_depth` until code emits separate columns (future).

```text
Plain `Dip_depth` is not allowed as a canonical or tau/R input unless resolved to a namespace.
```

Resolution means: **`registry_id`** + **`namespace`** + **`formula_id`** present in sidecar or joined metadata.

---

## FM observables

Signed vs absolute: see **`aging_writer_output_contract.md`** FM section.

---

## Related

- `docs/aging/aging_namespace_contract.md`
- `docs/aging/aging_writer_output_contract.md`
