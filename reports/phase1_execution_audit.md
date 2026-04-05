# Phase-1 Execution Audit

## Exact commands executed
1. `if (Test-Path -LiteralPath 'C:\Dev\matlab-functions\execution_probe_top.txt') { Remove-Item -LiteralPath 'C:\Dev\matlab-functions\execution_probe_top.txt' -Force }`
2. `tools\run_matlab_safe.bat "C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m"`
3. `tools\run_matlab_safe.bat "C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m"`

## Console output (full)
### Run 1
```
SCRIPT_PATH_RESOLVED=C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m
SCRIPT_EXISTS=YES
RUNNER_FILE_CREATED=YES
RUNNER_PATH=C:\Dev\matlab-functions\tools\temp_runner.m
RUNNER_ABS_PATH=C:\Dev\matlab-functions\tools\temp_runner.m
MATLAB_COMMAND_FULL=matlab -batch "run('C:/Dev/matlab-functions/tools/temp_runner.m')"
MATLAB_WHERE_START
C:\Program Files\MATLAB\R2023b\bin\matlab.exe
MATLAB_WHERE_END
BEFORE_MATLAB_CALL
Matlab functions path added: C:\Dev\matlab-functions
RUNNER_ENTERED
AFTER_MATLAB_CALL
```

### Run 2
```
SCRIPT_PATH_RESOLVED=C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m
SCRIPT_EXISTS=YES
RUNNER_FILE_CREATED=YES
RUNNER_PATH=C:\Dev\matlab-functions\tools\temp_runner.m
RUNNER_ABS_PATH=C:\Dev\matlab-functions\tools\temp_runner.m
MATLAB_COMMAND_FULL=matlab -batch "run('C:/Dev/matlab-functions/tools/temp_runner.m')"
MATLAB_WHERE_START
C:\Program Files\MATLAB\R2023b\bin\matlab.exe
MATLAB_WHERE_END
BEFORE_MATLAB_CALL
Matlab functions path added: C:\Dev\matlab-functions
RUNNER_ENTERED
AFTER_MATLAB_CALL
```

## File paths
- Probe: `C:\Dev\matlab-functions\execution_probe_top.txt`
- Run dir: `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical`
- Status file: `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical\execution_status.csv`
- Tables:
  - `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical\execution_status.csv`
  - `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical\minimal_data.csv`
  - `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical\run_status.csv`
- Reports:
  - `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_02_213133_minimal_canonical\minimal_report.md`

## Key findings
- `execution_probe_top.txt` was not created in either run.
- `execution_status.csv` exists and content is:
  - `EXECUTION_STATUS,INPUT_FOUND,ERROR_MESSAGE,N_T,MAIN_RESULT_SUMMARY`
  - `SUCCESS,YES,,3,minimal canonical end-to-end proof`
- Fields `EXECUTION_STARTED`, `RUN_DIR_CREATED`, `WRITE_SUCCESS`, and `ERROR` are absent/empty in the status CSV.
- Rerun consistency is satisfied (probe existence, status existence, and extracted key fields remained unchanged).

## Final verdict
- `INFRA_STABLE = NO`
