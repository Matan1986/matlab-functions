# Run Context Diagnosis

## Scope
Inspected only:
- Aging/utils/createRunContext.m
- Direct helper functions defined/called from that file

## RUN_BASE_PATH
- Logical base root: `<repoRoot>/results/<experiment>/runs`
- Resolved in code at line 54:
  `runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');`
- `repoRoot` is derived at line 26 from the location of `createRunContext.m`:
  `repoRoot = fileparts(agingDir);`

## EXPECTED_RUN_DIR_STRUCTURE
From the implementation, expected directory structure is:
- `<repoRoot>/results/`
- `<repoRoot>/results/<experiment>/`
- `<repoRoot>/results/<experiment>/runs/`
- `<repoRoot>/results/<experiment>/runs/<run_id>/`

Expected run files under `<run_id>/` are set in lines 87-91:
- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`
- `run_status.csv`

## POINT_OF_FAILURE
### 1) run_dir creation failure mode
Exact lines where `run_dir` should be created:
- New-run path: lines 62-63
  - `if ~exist(runDir, 'dir')`
  - `mkdir(runDir);`
- Reuse path: lines 42-43
  - `if ~exist(run.run_dir, 'dir')`
  - `mkdir(run.run_dir);`

Why run_dir can remain missing:
- `mkdir(...)` return status is never checked in either branch (lines 43, 56, 63).
- If `mkdir` fails (bad path, permissions, unavailable/misaligned root), code continues instead of stopping immediately with a clear directory-creation error.
- This makes the observable failure appear later (for example at first file write), while root cause is unchecked directory creation.

### 2) Missing run_dir_pointer.txt
Exact failure finding:
- There is no write path for `run_dir_pointer.txt` anywhere in `createRunContext.m`.
- The function ends by storing the context in appdata only (lines 50 and 83; helper at line 407):
  - `setRunContextAppdata(run);`

Why pointer is missing:
- The file is never created by this function or any directly called helper in scope.
- Therefore `run_dir_pointer.txt` missing is deterministic from current implementation, not incidental.

## Minimal Fix Suggestion (No Implementation)
1. Immediately validate `mkdir` outcomes for `runsRoot` and `runDir` (and reuse branch `run.run_dir`), and hard-fail with a descriptive error if creation fails.
2. Add explicit pointer emission (`run_dir_pointer.txt`) after `run.run_dir` is finalized, in a single canonical location in `createRunContext`.
3. Keep appdata setting as secondary signaling; do not rely on appdata when file-based run identity is required by wrappers/audits.
