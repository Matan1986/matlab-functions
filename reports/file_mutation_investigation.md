# File Mutation Investigation

Date: 2026-03-26  
Repo: `C:\Dev\matlab-functions`  
Target file: `Switching/analysis/run_phi2_shape_physics_test.m`

## 1) MUTATION_CONFIRMED

**NO** (within observed window)

- Marker appended: `% INVESTIGATION_MARKER_123`
- Observation window: 2 minutes (poll every 3 seconds, 40 polls)
- Changes detected after append: **0**
- Final hash unchanged from post-append hash
- Marker remained present in last lines of file

## 2) MUTATION_PATTERN

- In 2-minute watch window: **none observed**
- Classification from this run: **not immediate**, **not short-delay (<=2 min)**, **periodic unknown**
- Recorded file-change stats during watch:
  - change count: `0`
  - change timestamps: `none`
  - inter-change interval: `N/A`

## 3) SUSPECTED SOURCE

Most relevant findings:

1. **Scheduler candidate found (high relevance)**
   - Task: `Snapshot_Auto_Update`
   - Trigger: repeating every 1 hour (`PT1H`)
   - Action: `powershell.exe -ExecutionPolicy Bypass -File C:\Dev\matlab-functions\scripts\run_snapshot.ps1`
   - State at inspection time: `Running`
   - Last/next run: `2026-03-26T20:30:30+02:00` / `2026-03-26T21:30:30+02:00`

2. **Running process candidate found (high relevance)**
   - Active process command line includes:
     - `powershell.exe ... C:\Dev\matlab-functions\scripts\run_snapshot.ps1`

3. **MATLAB automation process chain present (medium relevance)**
   - Active commands include:
     - `tools\run_matlab_safe.bat ... run_phi1_phi2_observable_closure_test.m`
     - `matlab -batch "run('...matlab_runner_10841.m')"`
   - These can execute scripts that may write files, depending on script behavior.

4. **Repo-level script audit (medium relevance)**
   - Script files found: multiple `.ps1` + one `.bat`.
   - `scripts/run_snapshot.ps1` performs extensive `Copy-Item`/archive operations and then invokes `scripts/update_context.ps1`.
   - `scripts/update_context.ps1` writes:
     - `docs/context_bundle.json`
     - `docs/context_bundle_full.json`
   - No direct write to `Switching/analysis/run_phi2_shape_physics_test.m` found in these scripts.

5. **Sync service context (low/medium relevance)**
   - Repo path is **not** under OneDrive/Dropbox/Google Drive sync roots.
   - OneDrive tasks exist on system, but repo location itself is outside sync folder.

## 4) MOST LIKELY CAUSE

A periodic automation path exists (hourly `Snapshot_Auto_Update` + active MATLAB/batch runners), but this investigation did **not** capture direct overwrite of the target `.m` file in the 2-minute window.

## 5) RECOMMENDED ACTION

1. **Stop process (diagnostic isolation)**  
   Temporarily stop the active snapshot PowerShell run and re-test mutation on the same target file.

2. **Disable task (diagnostic isolation)**  
   Temporarily disable `Snapshot_Auto_Update`, then repeat the marker test across at least one full hourly boundary.

3. **Process isolation pass**  
   Ensure no `matlab -batch` / `run_matlab_safe.bat` jobs are active during re-test.

4. **Extended watch**  
   Monitor file hash through at least 70 minutes to include hourly trigger boundaries.

5. **Move repo (only if needed)**  
   Not currently indicated for cloud-sync reasons (repo not in sync root), but can be used as a hard isolation fallback.

