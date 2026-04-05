# Switching robustness execution trace

## Run summary
- Wrapper invocation was executed once via `tools/run_matlab_safe.bat` for `Switching/analysis/run_parameter_robustness_switching_canonical.m`.
- MATLAB launched and completed with wrapper exit code 0.
- Wrapper command shows MATLAB executed `tools/temp_runner.m`, not the target robustness script.

## Stage trace
1. Wrapper stage: reached.
- Evidence: `SCRIPT_PATH_RESOLVED`, `SCRIPT_EXISTS=YES`, `BEFORE_MATLAB_CALL`, `AFTER_MATLAB_CALL`, and `RUNNER_ENTERED` present.
- `MATLAB_COMMAND_FULL` points to `run('.../tools/temp_runner.m')`.
- `VALIDATOR_STATE` and `CHECK_*` diagnostics were not emitted in current wrapper output.

2. Entry stage: not reached.
- Evidence: top marker did not execute (`execution_probe_top.txt` not created).

3. Context stage: not reached.
- Evidence: no `run_*_switching_parameter_robustness_canonical` directory created; `execution_status.csv` not updated by this run.

4. Artifact stage: not reached.
- Evidence: no required robustness artifacts were created.

## Failure classification
`NO_SCRIPT_ENTRY`

Reason: MATLAB process launched, but the target script did not enter; wrapper executed temporary runner instead.
