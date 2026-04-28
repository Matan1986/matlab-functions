# tables/switching/ README

## Purpose
`tables/switching/` is the durable Switching table namespace for promoted structured outputs and governance-approved indexes. It is not a transient run dump location.

## Durable Table Contract
Every new durable Switching index table should include these columns:
- `table_name`
- `family`
- `producer_script`
- `source_run`
- `canonicality_status`
- `diagnostic_status`
- `lineage_link`
- `do_not_mix_with`

## Family and Lineage Rules
- Preserve separate family labeling for `legacy_old`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, and `canonical_replay`.
- Do not publish mixed-family canonical claims in a single durable table without explicit separation fields.
- Every durable row should retain run/script lineage links.

## Canonical vs Diagnostic Handling
- Canonical tables must be marked as canonical and tied to source run lineage.
- Diagnostic tables remain diagnostic unless explicitly promoted with policy approval.
- Replay tables remain replay-scoped and cannot be reclassified as canonical geometric/residual by naming alone.

## Ignore / Force-Add Guidance
Ignored tables may be force-added only when they are:
- approved durable governance outputs, or
- approved durable Switching tables under this contract.

Force-add is not permitted for transient or ad hoc run spillover artifacts.
