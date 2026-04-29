# Aging — Writer output contract (binding)

**Version:** F6S-1.0  
**Scope:** Any MATLAB or automation that **writes** Aging outputs consumed by science or consolidation.

## Covered outputs

- `observables.csv`
- `tables/observable_matrix.csv`
- Tau tables (e.g. `tau_vs_Tp.csv`, `tau_FM_vs_Tp.csv`)
- R / clock-ratio tables (e.g. `table_clock_ratio.csv`)

## Required sidecar (per run or per table)

Sidecar may be **`aging_lineage_manifest.json`**, **`aging_lineage_manifest.csv`**, or **`aging_lineage_manifest.md`** adjacent to the primary table or under `tables/` / run root as agreed by implementation **later**. Minimum fields:

| Field | Requirement |
|--------|----------------|
| **namespace** | Default writer namespace (e.g. `current_export`). |
| **registry_id** | One id per **logical** observable column family produced. |
| **formula_id** | Per observable or per-column mapping. |
| **writer_id** | Script path + content hash or version string. |
| **source_run_id** | Run id / `run_manifest.json` pointer. |
| **input_artifact_list** | List of input files/hashes (raw, intermediate). |
| **config_hash** / **config_snapshot** | Snapshot of relevant config structs. |
| **code_fingerprint** | Hash or commit of **writer + stage4 + components** sources. |
| **units** | Per observable. |
| **sign_convention** | Per observable (especially `FM_step_mag`, `FM_abs`). |
| **allowed_downstream_uses** | e.g. `tau_Dip_allowed=true` only if namespaces resolved. |

## Column naming (interim)

Until code emits **`Dip_depth_S4A`** / **`Dip_depth_S4B`** columns, writers **must** include sidecar mapping:

```text
column Dip_depth -> registry_id=AGING-OBS-DIP-S4B-001  (example — actual id from registry)
```

when that row’s **`Dip_depth_source`** is S4B; similarly for S4A.

## FM sign contract (writer obligations)

| Observable | Contract |
|------------|----------|
| **FM_step_mag** | **Signed** physical step magnitude where applicable; sidecar must state **sign convention** (`leftMinusRight` etc.). |
| **FM_abs** | **`abs(FM_signed)`** when signed path exists; **must not** silently replace **`FM_step_mag`** without documenting. |
| **Stability** | **`FM_abs`** may be **bit-identical** across runs while **`FM_step_mag`** **flips sign** — not an error if convention documented (F6O–F6Q). Sidecar **must** record **both** when exported. |

## Pooled / consolidated tables

Any table merging multiple runs **must** include **per-row** `namespace` + `registry_id` **or** refuse merge.

## Validation

See **`tables/aging/aging_F6S_validation_rules.csv`**.
