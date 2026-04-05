# Execution Reliability Audit (Execution Layer Only)

Scope applied:
- Wrapper: `tools/run_matlab_safe.bat`
- Validator: `tools/validate_matlab_runnable.ps1`
- Script entry target: `Switching/analysis/run_parameter_robustness_switching_canonical.m`
- No scientific analysis or scientific-logic changes.
- No blocking behavior introduced.

## Root cause of NO_SCRIPT_ENTRY

Primary root cause is in wrapper command construction.

Evidence from `tools/run_matlab_safe.bat`:
- Resolves requested script path (`SCRIPT_PATH_RESOLVED`) at line 13 and computes MATLAB form (`SCRIPT_PATH_MATLAB`) at line 21.
- Creates and targets a temporary runner file at lines 23-29.
- Executes MATLAB with `matlab -batch "%MATLAB_COMMAND%"` at line 42, where `MATLAB_COMMAND` is `run('%RUNNER_ABS_PATH_MATLAB%')`.

Result:
- MATLAB launches successfully.
- Requested script is not executed.
- `SCRIPT_ENTERED` remains NO.
- No run-scoped artifacts from target script (`run_dir`, `execution_status`, tables/reports) are produced.

This exactly matches the observed failure signature: `MATLAB_LAUNCHED=YES`, `SCRIPT_ENTERED=NO`, no artifacts.

## All identified failure paths

1. Wrapper target mismatch (actual observed)
- Requested script path is resolved but not passed to `run()`.
- MATLAB runs only `tools/temp_runner.m`.

2. Path resolution error before useful launch
- Invalid/missing target path is not enforced in wrapper.
- Wrapper can still launch MATLAB and produce misleading "launch success" without target entry.

3. Quoting/path escaping risk
- MATLAB `run('...')` string can break on single-quote characters in path if not escaped.
- Current flow avoids this for target script only because it does not execute target at all.

4. Validator pre-block logic (state-logic level)
- Validator computes block conditions for `CHECK_ASCII`, `CHECK_HEADER`, `CHECK_FUNCTION`, and (in canonical state) `CHECK_RUN_CONTEXT`, `CHECK_DRIFT`, etc.
- `CHECK_DRIFT` is included in canonical blocking logic.

5. Validator effective behavior (runtime)
- `FailValidation` emits WARN/CONTINUE and returns.
- Current validator implementation is effectively non-blocking.
- Therefore, pre-MATLAB blocking is not currently enforced by this script itself.

6. MATLAB `run()` locate failure path
- If/when wrapper is corrected to target script path, bad path quoting, malformed path, or non-file path can cause `run()` locate/parse failure before script body entry.

7. Working directory mismatch path
- Entry probe writes `execution_probe_top.txt` to `pwd` in target script.
- If wrapper and detector disagree on working directory, marker may be missed and classified as NO_SCRIPT_ENTRY even when entered.

## Minimal fix strategy

A. Guaranteed entry marker
- Keep a first-line executable marker in target runnable script (already present).
- Normalize marker target to deterministic run context path (or dual-write to deterministic path + current fallback) for robust detection.

B. Wrapper transparency
- Construct MATLAB command from resolved target script path (`SCRIPT_PATH_MATLAB`), not temp runner path.
- Print both:
  - requested path
  - effective executed path in MATLAB command
- Print exact one-line command string that is executed.

C. Non-blocking validator mode
- Preserve non-blocking behavior (warnings only).
- Keep all `CHECK_*` emissions for traceability.
- Convert any future pre-MATLAB "block" into explicit warning classification, not launch abort.

D. Entry failure detection
- After MATLAB return, check for required entry marker(s).
- If absent, emit explicit `NO_SCRIPT_ENTRY` classification with reason bucket:
  - wrapper_target_mismatch
  - path_resolution_failure
  - matlab_run_locate_failure
  - cwd_marker_mismatch
  - validator_prelaunch_abort (reserved if enforcement reintroduced)

## What must change vs what must stay

Must change:
- Wrapper execution target must switch from temp runner to requested script path.
- Wrapper logs must explicitly show requested-vs-executed target path.
- Add explicit post-run entry-failure classification output.

Should stay:
- Single MATLAB invocation model (no multi-stage orchestrator).
- Non-blocking validator behavior (warn/continue).
- Scientific script logic and scientific computations unchanged.
- Execution-layer-only intervention.
