# execution_status.csv schema (canonical)

**Single schema:** `execution_status.csv` at the run root uses exactly these columns, in order:

1. `EXECUTION_STATUS`
2. `INPUT_FOUND`
3. `ERROR_MESSAGE`
4. `N_T`
5. `MAIN_RESULT_SUMMARY`

Normative definitions: `docs/run_system.md` (section 3). Switching canonical runner: `Switching/analysis/run_switching_canonical.m`.

`EXECUTION_STATUS` may be `SUCCESS`, `FAILED`, or `PARTIAL` (checkpoint before completion).
