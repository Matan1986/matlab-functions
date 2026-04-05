# Switching execution signaling contract (Phase 4.4)

## Summary

Switching runs expose **one** machine-readable execution outcome: `execution_status.csv` at the run directory (or the directory passed to the writer, for scripts that scope status under a `tables/` subfolder). All semantics are enforced in **`Switching/utils/writeSwitchingExecutionStatus.m`**.

## Authoritative signal

- **Source of truth:** `execution_status.csv` only.
- **Not** used as contract signals: log text, presence of other artifacts, MATLAB exit code, or console output.

## File schema

Exactly five columns, in this order:

1. `EXECUTION_STATUS`
2. `INPUT_FOUND`
3. `ERROR_MESSAGE`
4. `N_T`
5. `MAIN_RESULT_SUMMARY`

## `EXECUTION_STATUS` values

Allowed values only:

- `PARTIAL` — checkpoint during execution; may be overwritten multiple times; must not be the final state.
- `SUCCESS` — final success; requires empty `ERROR_MESSAGE`.
- `FAILED` — final failure; requires non-empty `ERROR_MESSAGE` (the writer supplies a minimal placeholder if the message would otherwise be empty).

## Write semantics

- **Checkpoints (`isFinal = false`):** only `PARTIAL` is accepted; each call **overwrites** the file.
- **Final (`isFinal = true`):** only `SUCCESS` or `FAILED`; written **atomically** (temp CSV then move/replace) so consumers never see a half-written file.

## Single writer

All Switching code paths that emit `execution_status.csv` call `writeSwitchingExecutionStatus`. No direct `writetable(..., 'execution_status.csv')` remains in the Switching tree.

## Machine-readable status

See `tables/signaling_status.csv` for `SIGNALING_ENFORCED` and component flags (`SINGLE_SIGNAL_SOURCE`, `SCHEMA_FIXED`, etc.).
