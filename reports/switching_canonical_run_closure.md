# Switching canonical run closure

- **SOURCE_OF_TRUTH (CANONICAL_RUN_ID):** `run_2026_04_04_100107_switching_canonical`
- **Selection:** Among runs with `EXECUTION_STATUS=SUCCESS` plus full artifacts and ENTRY→COMPLETED markers when present; if none qualify, falls back to SUCCESS+artifacts, then legacy-success+artifacts. Most recent `run_id` wins.

## Candidate filter

| run_id | EXECUTION_STATUS SUCCESS | artifact_ok | core triple CSVs | ENTRY+COMPLETED markers | candidate |
| --- | --- | --- | --- | --- | --- |
| `run_2026_04_02_234844_switching_canonical` | NO | YES | YES | NO | NO |
| `run_2026_04_03_000008_switching_canonical` | NO | YES | YES | NO | NO |
| `run_2026_04_03_000147_switching_canonical` | NO | YES | YES | NO | NO |
| `run_2026_04_03_091018_switching_canonical` | NO | YES | YES | NO | NO |
| `run_2026_04_04_095928_switching_canonical` | NO | YES | NO | NO | NO |
| `run_2026_04_04_100107_switching_canonical` | YES | YES | YES | YES | YES |

## Equivalence vs SOURCE (three CSVs)

| run_b | phi1_rmse | observables_rmse | validation_rmse | max_rmse | exact_all |
| --- | --- | --- | --- | --- | --- |
| `run_2026_04_02_234844_switching_canonical` | 0 | 0 | 0 | 0 | YES |
| `run_2026_04_03_000008_switching_canonical` | 0 | 0 | 0 | 0 | YES |
| `run_2026_04_03_000147_switching_canonical` | 0 | 0 | 0 | 0 | YES |
| `run_2026_04_03_091018_switching_canonical` | 0 | 0 | 0 | 0 | YES |
| `run_2026_04_04_095928_switching_canonical` | NA | NA | NA | NA | NO |

  - note: missing_tables

## Drift analysis

- **Drift detected:** at least one run differs from SOURCE on the compared tables or is missing required CSVs.

## Counts

- **DUPLICATE_COUNT:** 4
- **DRIFT_COUNT:** 1
- **SYSTEM_FULLY_LOCKED:** NO
