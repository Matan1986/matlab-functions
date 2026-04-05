# Phase 5G - Lean Formal Contracts (Switching Canonical Only)

## Scope

This document formalizes existing behavior only for:

- `Switching/analysis/run_switching_canonical.m`
- `Aging/utils/createRunContext.m`
- `Switching/utils/createSwitchingRunContext.m`
- `Switching/utils/writeSwitchingExecutionStatus.m`
- `Switching/utils/writeRunValidityClassification.m`
- Existing manifest/fingerprint outputs
- Phase 5F validated runtime behavior

No new mechanism, enforcement path, or runtime flow is introduced.

---

## 1) Execution Contract

EXECUTION_CONTRACT = COMPLETE

For every canonical Switching run, the following must exist in the active `run_dir`:

1. `run_dir` allocated through `createSwitchingRunContext(...)` -> `createRunContext('switching', ...)`.
2. `execution_status.csv` written by `writeSwitchingExecutionStatus(...)`.
3. `run_manifest.json` created by `createRunContext`.
4. Fingerprint fields embedded in manifest (`git_commit`, `script_path`, `script_hash`, `matlab_version`, `host`, `user`).
5. Failure handling path that still allocates canonical `run_dir` and writes final `FAILED` status.

Current enforced behavior:

- Checkpoint writes are `PARTIAL` only (`isFinal=false`).
- Final write is `SUCCESS` or `FAILED` only (`isFinal=true`).
- Final `SUCCESS` requires empty `ERROR_MESSAGE`; final `FAILED` requires non-empty error text (placeholder is inserted when empty).
- Manifest is immutable per run directory (no silent overwrite).

---

## 2) Artifact Contract

Allowed canonical outputs (contract set):

1. `run_dir/tables/*`
2. `run_dir/reports/*`
3. `run_dir/execution_status.csv`
4. `run_dir/run_manifest.json` (includes fingerprint fields)

Valid artifact definition:

- A file is valid under this contract when it is written inside the active canonical `run_dir` and belongs to the canonical output set above.

Forbidden artifact rule:

- Canonical outputs must not be written outside the active `run_dir`.

Current-system note:

- Phase 5F removed marker fallback writes outside `run_dir`; marker writes are run-scoped only when `run_dir` is resolvable.

---

## 3) Detection Contract

Run classification is detection-only (`run_validity.txt`), never execution-gating.

Classification states and signals:

1. `CANONICAL`
- `execution_status.csv` exists
- `createRunContext` resolves to `<repo>/Aging/utils/createRunContext.m`
- switching-isolated signal is true
- `enforcement_checked` is true
- module-enforcement consistency holds for provided `modules_used`

2. `NON_CANONICAL`
- `execution_status.csv` exists
- one or more canonical signals above are missing
- reason text lists failing signal(s)

3. `INVALID`
- run directory exists
- `execution_status.csv` missing

Operational constraints:

- `writeRunValidityClassification` never throws by design.
- Classification never changes `execution_status.csv` and never changes pipeline flow.

---

## 4) Entrypoint Contract

Formal rule:

- Canonical status is defined by execution through designated canonical entrypoint(s), not by file location alone and not by naming alone.

Current canonical switching entrypoint(s):

1. `Switching/analysis/run_switching_canonical.m`

---

## 5) Minimal Onboarding Contract (new canonical module)

This is the minimal required structure only.

1. Entrypoint structure
- single canonical entrypoint script for the module
- allocate run context at top before artifact writes

2. Run context usage
- call `createRunContext('<module_experiment>', cfg)` (or module wrapper equivalent)
- ensure outputs are written under `run.run_dir`

3. Required outputs
- `run_dir/tables/*` (module tables)
- `run_dir/reports/*` (module report)
- `run_dir/execution_status.csv`
- `run_dir/run_manifest.json` containing fingerprint fields

4. Execution status writing
- write checkpoint(s) as `PARTIAL` only if used
- write exactly one final status: `SUCCESS` or `FAILED`

5. run_validity classification
- call module validity writer after status write as detection-only annotation
- validity must not block execution and must not mutate final status

This onboarding contract is minimal and excludes optional/advanced features.

---

## 6) Consistency Validation Against Current System

Consistency result: PASS

- No contract item contradicts current Switching canonical behavior.
- No contract item requires runtime behavior not already present in referenced files.
- Contracts are extracted from existing execution/status/manifest/validity behavior.

CONTRACT_SYSTEM_DEFINED = YES
