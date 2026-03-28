## MATLAB execution layer hard fix

### Old execution method
- Wrapper used `matlab -r` with a forwarded command string and quote stripping.
- Typical payload pattern relied on `eval(fileread(...))`, which is sensitive to shell quoting/parsing.

### New execution method
- Wrapper now runs scripts using:
  - `matlab -batch "run('%~1')"`
- This uses an absolute script path argument passed as `%~1`.
- Wrapper now also logs:
  - the exact command before execution
  - the process exit code after execution

### Test script added
- `test_run_wrapper.m` writes:
  - `wrapper_test.txt` with `OK`
  - `wrapper_pwd.txt` with `pwd`

### Test execution attempted
- Command used:
  - `.\tools\run_matlab_safe.bat "C:/Dev/matlab-functions/test_run_wrapper.m"`
- Wrapper log line observed:
  - `[run_matlab_safe] Running: matlab -batch "run('C:/Dev/matlab-functions/test_run_wrapper.m')"`

### Verification status
- In this environment, MATLAB batch invocation does not return (same behavior also observed with direct `matlab -batch "disp('...')"` probe).
- As a result, `wrapper_test.txt` and `wrapper_pwd.txt` were not created during this run.
- No `Invalid use of operator` message appeared in the captured wrapper output.

### Infrastructure conclusion
- The execution layer is now correctly refactored to deterministic absolute-path `run(...)` batch execution and no longer uses `eval(fileread(...))`.
- Runtime validation is currently blocked by local MATLAB startup/execution behavior in this session.
