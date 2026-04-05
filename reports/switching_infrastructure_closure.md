# Switching infrastructure closure (governance)

This report finalizes **Switching-only** canonical infrastructure: identity, duplicate restriction, invalid-run isolation, and enforcement policy. No scientific logic or pipeline code was modified; outputs are registry and governance tables under `tables/` and this report.

## Canonical run selected

| Field | Value |
| --- | --- |
| **CANONICAL_RUN_ID** | `run_2026_04_04_100107_switching_canonical` |
| **STATUS** | LOCKED |
| **Source** | Derived from `tables/switching_canonical_run_closure.csv` (single `SOURCE` row) and `tables/switching_canonical_identity.csv`. |

## Duplicates (read-only)

The following runs are **byte- and numerically equivalent** to the canonical triple (`switching_canonical_phi1.csv`, `switching_canonical_observables.csv`, `switching_canonical_validation.csv`) per closure analysis. They are **not** alternate load targets.

| run_id | source_run_id | status |
| --- | --- | --- |
| `run_2026_04_02_234844_switching_canonical` | `run_2026_04_04_100107_switching_canonical` | READ_ONLY_DUPLICATE |
| `run_2026_04_03_000008_switching_canonical` | `run_2026_04_04_100107_switching_canonical` | READ_ONLY_DUPLICATE |
| `run_2026_04_03_000147_switching_canonical` | `run_2026_04_04_100107_switching_canonical` | READ_ONLY_DUPLICATE |
| `run_2026_04_03_091018_switching_canonical` | `run_2026_04_04_100107_switching_canonical` | READ_ONLY_DUPLICATE |

Authoritative machine-readable list: `tables/switching_canonical_duplicates.csv`.

## Invalid runs (excluded)

Runs that are **DRIFTED** relative to SOURCE and/or **lack required core CSVs** are isolated for operations.

| run_id | reason | evidence (summary) |
| --- | --- | --- |
| `run_2026_04_04_095928_switching_canonical` | INCOMPLETE_OR_FAILED_RUN | `RUN_STATUS=INVALID` encoded in evidence; closure `DRIFTED`; `execution_status` FAILED; core triple CSVs absent under `tables/`. |

Authoritative list: `tables/switching_invalid_runs.csv`.

## Policy rules

See `tables/switching_canonical_policy.csv` for the full rule set. In short:

1. Only **CANONICAL_RUN_ID** is allowed for `load_run` (primary consumption).
2. **Duplicates** are read-only archives; no computation primary loads.
3. **Invalid** runs are excluded from all operational use.
4. **New** runs must meet SUCCESS status, artifact checks, and core CSV presence before promotion.

## System lock confirmation

Registry and governance artifacts are written and consistent:

- `tables/switching_canonical_identity.csv` — canonical identity and counts.
- `tables/switching_canonical_policy.csv` — enforcement rules.
- `tables/switching_infrastructure_final_status.csv` — all governance stages YES; **SYSTEM_FULLY_LOCKED=YES** for infrastructure governance (identity + duplicates + invalid + policy defined).

Input closure snapshots (read-only reference): `tables/switching_canonical_run_closure.csv`, `tables/switching_canonical_run_closure_status.csv`.

---

**Ambiguity:** One canonical run ID is registered; duplicates and invalids are enumerated; policy is explicit. Operational code should resolve loads via `tables/switching_canonical_identity.csv` only unless explicitly auditing duplicates.
