# Aging lineage sidecar helper (F7A) usage

**Scope:** Aging lineage metadata helpers only. This file explains how to call `Aging/utils/aging_lineage_sidecar_utils.m`. It does **not** change scientific calculations, writers, or promote artifacts to canonical.

## Purpose

The helper provides a small, shared API to:

- Build a one-row **sidecar** table with **all required fields** filled (no silent blanks).
- **Normalize** missing input to `UNKNOWN` and optional fields to `NOT_APPLICABLE`.
- Assemble **identity blocks** (observable, writer, source run, formula/scalarization, tau/R numerator-denominator).
- **Validate** conservatively and return structured issues (no hard throw by default).
- **Write** sidecar CSV and optional JSON plus a **compact manifest** row for a primary output table.

Future high-priority writer families (`WO_STRUCTURED_EXPORT`, `WO_TAU_EXTRACTION`, `WO_CLOCK_RATIO`, `WO_CONSOLIDATION`) can call the same API so sidecars stay aligned with `docs/aging/aging_lineage_sidecar_schema.md` and the writer output contract, without ad hoc field names per script.

## Required metadata fields

The helper enforces the flat field set returned by `u.required_metadata_fields()` (see `aging_lineage_sidecar_utils.m`). They include, at minimum:

- **Versioning / mode:** `schema_version`, `validation_mode`
- **Artifact:** `artifact_path`, `artifact_class`
- **Writer identity:** `writer_family_id`, `writer_id`, `formula_id`
- **Registry / namespace / observable:** `registry_id`, `namespace`, `observable_definition_id`, `observable_semantic_name`
- **Source / inputs:** `source_run_id`, `source_dataset_id`, `input_signal_id`
- **Conventions:** `sign_convention`, `unit_status`, `preprocessing_recipe_id`, `scalarization_recipe_id`, `provenance_status`
- **Governance:** `model_readiness`, `canonical_status`, `legacy_quarantine_allowed`, `diagnostic_use_allowed`, `model_use_allowed`, `canonical_use_allowed`
- **Tau / R ratio identity:** `tau_or_R_flag`, `numerator_observable_id`, `denominator_observable_id`, `authoritative_flag_field`
- **Free text:** `notes`

If a value is not known, use `UNKNOWN` (the helper will insert it when you omit or pass empty values). If a value is not applicable to the artifact (for example, ratio identity on a non-ratio export), set the field to `NOT_APPLICABLE` or list the field name in `opts.na_fields` so normalization forces `NOT_APPLICABLE`.

## Default conservative statuses

Unless you override them in the input `meta` or `opts`, normalization uses:

- `schema_version` default: `F6T-1.0` (aligns with schema docs; override per project policy).
- `validation_mode` default: `audit_only` (from `opts.validation_mode`).
- `model_readiness` default: `diagnostic_only`.
- `canonical_status` default: `not_canonical`.
- Unknown scalars: `UNKNOWN` (never a blank string).

The helper does **not** mark outputs as model-ready, canonical, or registry-authoritative. Warnings are emitted if `model_readiness` or `canonical_status` look like premium states, to remind callers that **governance**, not the helper, grants those labels.

## How future writers should call it

1. `addpath` to `Aging/utils` (or rely on your existing path setup).
2. `u = aging_lineage_sidecar_utils();`
3. Build a `meta` struct with every field you know; omit the rest.
4. `opts = u.ensure_opts(struct('validation_mode', 'audit_only', 'strict_mode', false));`
5. `[T, issues] = u.build_default_sidecar(meta, opts);`
6. Inspect `issues` (table). In `audit_only` mode, `blocks_execution` is always `false` for every row.
7. `u.write_sidecar_csv(path, T);` and optionally `u.write_sidecar_json(path, T);`
8. `u.write_compact_table_manifest(manifestPath, tablePath, summaryStruct, opts);` with `summaryStruct` including at least `schema_version`, `validation_mode`, `writer_id`, and optional `table_row_count` / `table_column_count`.

For ratio or tau tables, build blocks and merge:

- `obs = u.observable_identity_block(...);`
- `w = u.writer_identity_block(...);`
- `src = u.source_run_identity_block(...);`
- `form = u.formula_scalarization_block(...);`
- `tr = u.tau_r_numerator_denominator_blocks('R' or 'tau' or 'none', numId, denId, authField);`
- `side = u.merge_blocks_into_sidecar(meta, struct('observable', obs, 'writer', w, 'source_run', src, 'formula_scalarization', form, 'tau_r', tr), opts);`
- `T = u.struct_to_one_row_table(side);` then `issues = u.validate_sidecar(T, opts);`

## Unresolved metadata

- Use the literal token **`UNKNOWN`** for any unresolved identity, namespace detail, or flag you cannot assert.
- Do not leave required fields empty: the validator flags blank strings; normalization is the supported way to avoid blanks.

## Not-applicable metadata

- Use **`NOT_APPLICABLE`** when a field has no meaning for the artifact (for example, `numerator_observable_id` on a table that is not a ratio).
- Alternatively, pass `opts.na_fields` as a cell array of field names; normalization sets those to `NOT_APPLICABLE`.

## Tau / R numerator and denominator identity

- Set `tau_or_R_flag` to `none`, `tau`, or `R` (or a project-defined token) when you know the role; otherwise `UNKNOWN`.
- `numerator_observable_id` and `denominator_observable_id` should hold **registry- or definition-level** ids for the tau or observable families used in the ratio, not Relaxation `R_relax`.
- `authoritative_flag_field` should name the column or sidecar field that records the authoritative canonical/diagnostic flag when policy requires it (for example, linkage to `tau_dip_canonical` naming). If unresolved, use `UNKNOWN` and expect a **WARNING** when notes or semantic names reference `tau_dip_canonical` without a resolved authority field.

## Plain `Dip_depth`

If `observable_semantic_name` is the bare column name `Dip_depth`, the helper emits a **WARNING** (`F7A_PLAIN_DIP_DEPTH_UNRESOLVED`): lineage for tau/R requires a resolved dip definition (for example S4A/S4B-tagged semantics per contract). This does not block execution in `audit_only`.

## Why helper scaffolding does not make artifacts canonical

Canonical promotion is a **governance** decision (registry, evidence, and promotion rules). The helper only formats metadata, applies conservative defaults (`not_canonical`, `diagnostic_only`), and surfaces warnings if callers request elevated statuses. It never upgrades `canonical_status` or `model_readiness` on its own.

## Why strict mode remains deferred

`strict` validation would allow `blocks_execution` to be true for some issue classes. Writers and registry coverage are not yet standardized on this helper across all paths, so **strict mode is not enabled** in F7A. The API accepts `opts.strict_mode` and `validation_mode = 'strict'` for future wiring; until then, keep `audit_only` as the default operational mode.

## Smoke check

Run `Aging/validation/run_aging_lineage_sidecar_utils_smoke.m` (via `tools/run_matlab_safe.bat` on automated hosts). It writes diagnostic CSV/Markdown samples under `tables/aging/` and `reports/aging/` without performing scientific analysis.

## References

- `docs/aging/aging_lineage_sidecar_schema.md`
- `docs/aging/aging_writer_output_contract.md`
- `docs/aging/aging_contract_validation_rules.md`
- `docs/aging/aging_tau_R_lineage_naming_policy.md`
