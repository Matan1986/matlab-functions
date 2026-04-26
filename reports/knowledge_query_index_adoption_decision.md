# Query / Index Adoption Decision

Date: 2026-04-26

## Flags
- `QUERY_INDEX_ADOPTION_DECISION_RECORDED = YES`
- `QUERY_INDEX_UPDATE_DEFERRED = YES`
- `HUMAN_READABLE_CONTEXT_ACTIVE_SOURCE = YES`
- `SNAPSHOT_SCIENTIFIC_V3_NOT_CURRENT_TRUTH = YES`
- `FUTURE_UPDATE_REQUIRES_PLAN_FIRST = YES`

## Decision
For current canonical Switching work, the active source of truth remains the human-readable canonical context layer together with the human-readable canonical snapshot layer.

This means:
- `docs/switching_canonical_reality.md`
- `reports/switching_canonical_current_truth_freeze.md`
- `reports/canonical_state_snapshot.md`

remain the operative interpretation layer for the current canonical Switching state.

## Boundary
`snapshot_scientific_v3` and the related query/index layer are real repository systems and are partially consumed by code and documentation. However, they are stale relative to the current canonical Switching state and must not be treated as current canonical truth.

In particular:
- `snapshot_scientific_v3` is not the authoritative canonical Switching state source at this stage.
- query/index artifacts are not to be updated or activated for this canonical Switching interpretation step.
- claims about current canonical Switching status must continue to preserve canonical/noncanonical separation.
- the full-closure caveat remains mandatory: rank-2 is the leading-order interpretable canonical model, not full closure.
- rank-3 remains documented only as an open weak structured residual, not a promoted physical mode.

## Adoption Rule
Do not update the query/index layer now.

Any future query/index or `snapshot_scientific_v3` adoption/update must begin with a separate canonical-safe update plan, not direct execution. That plan must explicitly address:
- canonical vs historical/noncanonical separation
- canonical Switching source-of-truth routing
- preservation of the non-full-closure caveat
- safe handling of open rank-3 residual status

## Practical Guidance
Until a dedicated adoption pass is opened:
- use the human-readable canonical context and snapshot documents for current Switching interpretation
- treat `snapshot_scientific_v3` as a stale-but-live control plane
- treat query outputs as non-authoritative for canonical-current Switching interpretation unless later re-aligned by plan
