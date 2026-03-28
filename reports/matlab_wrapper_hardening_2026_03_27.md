# MATLAB Wrapper Hardening Report (2026-03-27)

## Scope
- File audited: `tools/run_matlab_safe.bat`
- Task type: infrastructure/debug only
- No scientific MATLAB analysis runs were executed

## Audit of Previous Behavior
- Wrapper printed MATLAB `%ERRORLEVEL%` but did not explicitly exit with it, so failures could be reported as success.
- Wrapper emitted `SCRIPT_FAILED` marker from MATLAB `catch`, but did not enforce nonzero exit on that marker.
- Wrapper used one shared log path: `C:/Dev/matlab-functions/matlab_error.log` (race/overwrite risk across runs).
- No post-run artifact existence/size gate existed.

## Hardening Changes Applied
1. Exit-code propagation hardened:
- Captures MATLAB process exit code into `MATLAB_EXIT_CODE`.
- Computes `FINAL_EXIT_CODE` and returns it with `endlocal & exit /b %EXIT_CODE%`.

2. Marker-driven failure enforcement:
- Adds run status marker file (`matlab_status_<runid>_<rand>.log`) written as `SCRIPT_SUCCESS` or `SCRIPT_FAILED`.
- Scans status marker and MATLAB stdout log for markers.
- Forces nonzero exit code when `SCRIPT_FAILED` is detected, even if MATLAB exited 0.
- Fails with nonzero if success marker is missing while exit code is 0.

3. Run-scoped unique logging:
- Replaces shared `matlab_error.log` with unique per-run error logs under `logs/`.
- Adds unique per-run MATLAB stdout logs under `logs/`.
- Uses run ID timestamp + random suffix to avoid collisions.

4. Post-run artifact verification hook:
- Adds optional required-output gate using semicolon-separated paths from:
  - argument 2 (`%~2`), and/or
  - env var `MATLAB_REQUIRED_OUTPUTS`
- Each required output must exist and be non-empty (`size > 0`), else run fails with nonzero.
- Relative artifact paths are resolved against repo root.

## Remaining Risks
- Wrapper still invokes MATLAB with `-batch`; repository docs currently state `-batch` is forbidden. This hardening task did not alter invocation mode to keep changes minimal/localized.
- If callers do not provide required outputs (`%~2`/`MATLAB_REQUIRED_OUTPUTS`), artifact gating is not applied (hook is present but opt-in).
- Wrapper/validator contract mismatch risk remains in parts of repo that invoke wrapper with command strings instead of absolute `.m` script paths.
- Validator behavior is external to this patch and can still block execution independently.

## Verdicts
WRAPPER_EXIT_PROPAGATION_FIXED=YES
SCRIPT_FAILED_FORCES_NONZERO=YES
RUN_SCOPED_LOGGING_ADDED=YES
POSTRUN_ARTIFACT_GATE_ADDED=YES
