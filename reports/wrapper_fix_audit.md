# Wrapper Fix Audit

## Exact root cause
`tools/run_matlab_safe.bat` built `MATLAB_COMMAND` from `RUNNER_ABS_PATH_MATLAB`, so MATLAB executed `tools/temp_runner.m` instead of the requested script path.

## Exact lines changed
File: `tools/run_matlab_safe.bat`
- Line 29 changed:
  - Before: `set "MATLAB_COMMAND=run('%RUNNER_ABS_PATH_MATLAB%')"`
  - After:  `set "MATLAB_COMMAND=run('%SCRIPT_PATH_MATLAB%')"`

No other wrapper logic was changed.

## Confirmation that SCRIPT_PATH is now used
Validation command executed:
- `tools/run_matlab_safe.bat "test_execution_probe.m"`

Observed wrapper output:
- `SCRIPT_PATH_RESOLVED=C:\Dev\matlab-functions\test_execution_probe.m`
- `MATLAB_COMMAND_FULL=matlab -batch "run('C:/Dev/matlab-functions/test_execution_probe.m')"`
- Actual call line remains `matlab -batch "%MATLAB_COMMAND%"`, therefore executed command matches printed command.

## Validation output (probe success)
Observed MATLAB/script signals:
- MATLAB launch confirmed (`where matlab` resolved and MATLAB produced runtime output).
- `SCRIPT_START` observed.
- `PROBE_FORCE_RUN_v2` observed.
- `MATLAB_EXECUTION_PROBE_START` observed.
- `MATLAB_EXECUTION_PROBE_END` observed.

Artifact verification:
- `execution_probe_top.txt` exists after run.
- File content includes `SCRIPT_START`.

Conclusion:
- Wrapper now executes requested script path (`SCRIPT_PATH_MATLAB`) instead of temp runner.
- MATLAB command echo and actual command are consistent.
