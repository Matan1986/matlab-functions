# Phase 2.2 — Failure path audit (Switching canonical execution system)

**Scope:** Switching canonical system only — execution stack for `Switching/analysis/run_switching_canonical.m` (registry: `tables/switching_canonical_entrypoint.csv`).  
**Method:** Read-only inspection of `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1`, `tools/validate_matlab_runnable.ps1` (not modified, not executed), `Switching/analysis/run_switching_canonical.m`, `tools/write_execution_marker.m`, `Aging/utils/createRunContext.m`, and normative docs (`docs/repo_execution_rules.md`, `docs/run_system.md`, `docs/infrastructure_laws.md`, `docs/execution_failure_classification.md`).  
**MATLAB:** Not run. **Wrapper:** Not invoked.

---

## 1. Pre-execution blocking audit

### 1.1 Wrapper / guard blocks (`tools/pre_execution_guard.ps1`)

| Mechanism | Effect |
| --- | --- |
| Empty script path | Logged `PRE_EXECUTION_INVALID_SCRIPT`; exit code **2**; MATLAB **not** launched. |
| Path not a leaf file | Same (includes wrong directory, missing file). |
| Path not ending in `.m` | Same. |
| Path resolution exception | Same (`path_resolution_failed`). |

Missing or invalid argument resolution in `run_matlab_safe.bat` (no `%1` → current directory) leads to the guard failing because the cwd is not a `.m` file.

### 1.2 Validator (`tools/validate_matlab_runnable.ps1`)

- The **batch wrapper does not invoke** the validator (`docs/repo_execution_rules.md`).
- When run manually, failed checks call `FailValidation`, which **exits 0** (NOT_PASS) — it does **not** return a nonzero exit code to block CI by default; blocking is **human/procedural** if the operator chooses to abort.
- No `docs/repo_state.md` was found in-repo; validator defaults `VALIDATOR_STATE` to **canonical** per script logic.

### 1.3 Conditions where execution never starts

- Pre-guard failure (above).
- `matlab` not on PATH / MATLAB not installed → process fails before user script.
- Operator policy stops (ASCII check, manual validation abort) without calling the wrapper.

---

## 2. Silent failure audit (relative to signaling contract)

Normative contract (`docs/repo_execution_rules.md`): valid run requires **execution_probe_top.txt**, **execution_status.csv**, and **run_dir**. MATLAB exit code and wrapper completion are **explicitly not** valid indicators.

### 2.1 MATLAB runs but script not meaningfully entered

- **Parse / load failure** before `run()` body: no `try/catch` in script runs → no `execution_status.csv` from `run_switching_canonical.m`.
- **Failure before `try`** (lines 1–17): top-level errors skip the `catch ME` path that writes FAILED status (rare: `addpath` / bootstrap failures).

### 2.2 Script runs but no outputs (or no contract outputs)

- **Early `try` failure** before `run_dir` and status paths are set: catch may synthesize a failure `run_dir` (sometimes **without** full `createRunContext` manifest path — see partial audit).
- **`write_execution_marker`**: errors swallowed internally → missing markers without raising.

### 2.3 Ordering gap (PARTIAL vs probe)

`execution_status.csv` is written with **PARTIAL** before **`execution_probe_top.txt`** is created. A crash in that narrow window yields **PARTIAL status + run_dir** but **no** probe file — inconsistent with the documented signaling list order.

---

## 3. Partial execution audit

| Scenario | Symptoms |
| --- | --- |
| Intentional PARTIAL checkpoints | `EXECUTION_STATUS=PARTIAL` in `execution_status.csv` before SUCCESS. |
| Kill/crash mid-pipeline | PARTIAL or incomplete tables; missing final SUCCESS row or missing `switching_canonical_*.csv` / reports. |
| Failure path without `createRunContext` in catch | Fallback `mkdir` run directory may lack **`run_manifest.json`** vs success path (`createRunContext` writes manifest). |

---

## 4. Artifact inconsistency audit

| Pattern | Classification |
| --- | --- |
| Artifacts without going through `tools/run_matlab_safe.bat` | **INCONSISTENT_STATE** (policy violation; provenance mismatch). |
| `tables/runtime_execution_markers_fallback.txt` updated without run-scoped `runtime_execution_markers.txt` | **INCONSISTENT_STATE** (global fallback vs run tree). |
| `execution_status` / outputs mismatch (manual edits, stale dirs) | **INCONSISTENT_STATE** |

---

## 5. Failure taxonomy (applied)

Each row in `tables/failure_path_audit.csv` uses one of:

- **BLOCKING_PRE_EXECUTION** — MATLAB not launched or blocked before user script.
- **SILENT_FAILURE** — Failure not reliably surfaced via the signaling contract or exit-code interpretation.
- **PARTIAL_EXECUTION** — Checkpoints, incomplete artifacts, or missing manifest/secondary outputs after some progress.
- **INCONSISTENT_STATE** — Artifacts or status disagree with actual execution or policy.

---

## 6. Infrastructure note (debug vs implementation)

`tools/run_matlab_safe.bat` creates a temporary `temp_runner_*.m` with `RUNNER_ENTERED` / `pause(1)` but the **invoked** `-batch` command is `run('<USER_SCRIPT>')` only. Do not treat the temp runner as evidence of layer 2 in the current wrapper without reading the batch file.

---

## Deliverables

| File | Role |
| --- | --- |
| `tables/failure_path_audit.csv` | Enumerated failure paths with taxonomy. |
| `tables/failure_path_status.csv` | Single STATUS row (risk flags). |
| `reports/failure_path_audit.md` | This narrative audit. |
