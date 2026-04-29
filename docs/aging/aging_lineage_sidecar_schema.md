# Aging — Lineage sidecar schema (F6T design)

**Version:** F6T-1.0  
**Status:** Design / not yet implemented in code  
**Scope:** Sidecar files accompanying Aging writer outputs (per F6S writer output contract).  
**Principle:** Sidecars must make **incomplete legacy artifacts** representable by **explicit unresolved fields** instead of silent omission.

## File naming and placement (convention)

- **Per-table sidecar (preferred for canonical exports):** adjacent to the primary CSV, same basename with suffix `.lineage.json` or `.lineage.csv` (implementation choice in F6U+).
- **Per-run manifest:** `aging_lineage_manifest.json` or `.csv` at `run_dir` root (see `aging_writer_output_contract.md`).

## Required schema version

Every sidecar **must** include `sidecar_schema_version` (e.g. `F6T-1.0`) so validators can evolve without breaking readers.

## Field dictionary

| Field | Type (conceptual) | Required | Notes |
|--------|-------------------|----------|--------|
| `sidecar_schema_version` | string | YES | e.g. `F6T-1.0` |
| `writer_id` | string | YES | Stable id; prefer `repo_rel_path#hash_or_semver` |
| `writer_path` | string | YES | Repository-relative path to the writer script or function entry |
| `writer_role` | string | YES | e.g. `structured_export`, `tau_extraction`, `R_table`, `consolidation` |
| `output_file` | string | YES | Basename or path of the table this sidecar describes |
| `namespace` | string | YES* | *Or `unresolved` with `unresolved_fields` listing `namespace` |
| `registry_id` | string | YES* | *Per logical observable family; may repeat in array for wide tables |
| `observable_name` | string or array | PARTIAL | Column name(s) in the table; for wide exports use array or child rows |
| `formula_id` | string or map | YES* | Map column -> formula_id when multiple observables per file |
| `formula_description` | string or map | RECOMMENDED | Human-readable; may be `unresolved` for legacy |
| `source_run_id` | string | YES* | Run id or pointer to `run_manifest.json` |
| `input_artifacts` | array of strings | YES* | Paths or logical ids; may be empty with explicit `unresolved` |
| `input_artifact_hashes` | array of strings | OPTIONAL | Aligned with `input_artifacts` when available |
| `config_snapshot_or_hash` | string | RECOMMENDED | Config struct hash or embedded snapshot id |
| `code_fingerprint_or_commit` | string | RECOMMENDED | Git commit, file hash bundle, or `unresolved` |
| `units` | string or map | YES* | Per-observable or global default with column map |
| `sign_convention` | string or map | CONDITIONAL | Required when FM or signed dip observables present |
| `preprocessing_contract` | string | OPTIONAL | High-level: stage4 path, detrend, window |
| `component_extraction_contract` | string | OPTIONAL | S4A vs S4B path, basis, mode selection |
| `scalarization_contract` | string | OPTIONAL | How scalars are reduced from curves/maps |
| `allowed_downstream_uses` | string or list | YES | e.g. `audit_only`, `tau_Dip_if_resolved` |
| `forbidden_downstream_uses` | string or list | YES | e.g. `cross_run_compare_without_identity` |
| `legacy_quarantine_status` | enum | YES | `none`, `legacy_quarantine`, `evidence_readonly` |
| `canonical_promotion_status` | enum | YES | `not_canonical`, `candidate`, `canonical` |
| `validation_mode_used` | string | OPTIONAL | Set by validator: `audit_only`, `migration`, `strict` |
| `unresolved_fields` | array of strings | CONDITIONAL | **Must** list any required field not known (e.g. `namespace`, `registry_id`) |
| `suggested_next_fix` | string | RECOMMENDED | Single next action for agents (add registry row, re-export, etc.) |

## Multi-column (wide) tables

For `observable_matrix.csv`, the sidecar may use:

- `observable_name` as a list, and
- `formula_id` / `registry_id` as **JSON-style maps** from column name to id, **or**
- a companion **`aging_observable_column_map.csv`** (implementation option) referenced by `input_artifacts`.

Validators must accept **one row per file** with embedded maps, or **exploded** one-row-per-column sidecars.

## Legacy and incomplete metadata

- Any missing mandatory semantic must appear in `unresolved_fields` and **must** set `legacy_quarantine_status` to `legacy_quarantine` or `evidence_readonly` when appropriate.
- **Never** leave mandatory identity ambiguous without listing it in `unresolved_fields`.

## Examples

See `docs/aging/aging_agent_assistive_enforcement.md` for JSON templates (structured export and tau/R).

## References

- `docs/aging/aging_namespace_contract.md`
- `docs/aging/aging_observable_registry_contract.md`
- `docs/aging/aging_writer_output_contract.md`
