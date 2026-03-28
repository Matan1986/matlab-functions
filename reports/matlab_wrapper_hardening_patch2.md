# MATLAB Wrapper Hardening Patch 2 (2026-03-27)

## Scope
- Modified only: `tools/run_matlab_safe.bat`
- Infrastructure/debug only
- No scientific analysis executed

## Targeted fixes applied
1. Artifact gate enforced by default:
- REQUIRED_OUTPUTS collected from arg2 and `MATLAB_REQUIRED_OUTPUTS`.
- If empty, wrapper now fails with exit code 6.
- Artifact verification now always runs and enforces: exists + non-empty.

2. Status file is mandatory:
- If status marker file is missing after MATLAB returns, wrapper now fails with exit code 7.

3. Stdout safety-net error detection:
- Wrapper scans MATLAB stdout log for `Error` (case-insensitive).
- If found, wrapper now fails with exit code 8.

4. Authoritative final exit:
- Wrapper now exits with `endlocal & exit /b %FINAL_EXIT_CODE%`.
- `%ERRORLEVEL%` is not used for final return.

5. Existing hardening preserved:
- Exit propagation kept.
- SCRIPT_FAILED forced nonzero behavior kept.
- Run-scoped logging kept.
- Existing validation flow kept.

## Explicit test results
- No REQUIRED_OUTPUTS -> FAIL: `EXIT_CODE=6`
- Missing STATUS_FILE -> FAIL: `EXIT_CODE=7`
- `Error` in stdout -> FAIL: `EXIT_CODE=8`
- Missing artifact -> FAIL: `EXIT_CODE=5`
- Valid run -> SUCCESS: `EXIT_CODE=0`

## Verdicts
WRAPPER_EXIT_PROPAGATION_FIXED=YES
SCRIPT_FAILED_FORCES_NONZERO=YES
RUN_SCOPED_LOGGING_ADDED=YES
POSTRUN_ARTIFACT_GATE_ADDED=YES
ARTIFACT_GATE_ENFORCED_BY_DEFAULT=YES
STATUS_FILE_REQUIRED=YES
STDOUT_ERROR_DETECTION=YES
