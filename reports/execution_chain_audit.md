# Execution chain audit — Switching canonical (Phase 2.1)

**Scope:** Switching canonical system only (`tables/switching_canonical_entrypoint.csv` → `Switching/analysis/run_switching_canonical.m`).  
**Rules followed:** `docs/repo_execution_rules.md`.  
**Method:** Read-only inspection of wrapper, validator, pre-guard, entry script, and on-disk run artifacts. **No repository files were modified.** **No MATLAB run was executed** for this audit; verification uses existing run directories under `results/switching/runs/`.

## 1. Wrapper and validator entry

### Script path resolution

- **Registry (sole SSOT):** `Switching/analysis/run_switching_canonical.m` (`tables/switching_canonical_entrypoint.csv`).
- **`tools/run_matlab_safe.bat`:** Resolves `%1` to an absolute path (PowerShell `GetFullPath`), sets `MATLAB_COMMAND=run('<forward-slashed path>')`, then invokes `matlab -batch` once with that command.
- **Pre-MATLAB guard:** `tools/pre_execution_guard.ps1` runs before MATLAB. It requires a non-empty path to an existing `.m` file; otherwise exit code **2** and optional append to `tables/pre_execution_failure_log.csv`.
- **Check performed:** Invoked `pre_execution_guard.ps1` with the absolute path to `run_switching_canonical.m`; **exit code 0** (launch would be allowed).

### Validator and blocking

- **`tools/validate_matlab_runnable.ps1` is not called by the batch wrapper** (single MATLAB `-batch` invocation preserved).
- **Check performed:** Ran the validator against `run_switching_canonical.m`. Result: **`CHECK_DRIFT=FAIL`** / **`RESULT = NOT_PASS`** with **`CONTINUE = Validation warnings will not block MATLAB launch`** — i.e. **no pre-MATLAB blocking** from the validator.
- **Cause (static rule):** The script uses `fopen` for `execution_probe_top.txt`; the validator’s drift check treats `.txt` output via `fopen` as unexpected file-type drift.

## 2. Script entry verification

- **Code:** `run_switching_canonical.m` calls `write_execution_marker('ENTRY')` immediately after `addpath(.../tools)`, then `disp('SCRIPT_ENTERED')` after path setup.
- **Primary success run:** `results/switching/runs/run_2026_04_04_100107_switching_canonical/`
  - **`runtime_execution_markers.txt`** contains stages from `ENTRY` through `COMPLETED` (proves the run progressed past early entry and through pipeline stages).
  - **`execution_probe_top.txt`** exists at run root (signaling contract in `docs/repo_execution_rules.md`).
- **Contrast run:** `run_2026_04_04_095928_switching_canonical/` has **`execution_status.csv` = FAILED** with error **`Undefined function 'write_execution_marker'`** — demonstrates **non-silent** failure with status written; this run does **not** show full probe/marker files like the success run.

## 3. Execution artifacts (success run)

Under **`run_2026_04_04_100107_switching_canonical/`**:

| Artifact | Status |
| --- | --- |
| `run_dir` | Present |
| `execution_status.csv` | Present; `EXECUTION_STATUS=SUCCESS`, `N_T=16` |
| Output CSV tables | Present under `tables/` (e.g. `switching_canonical_observables.csv`, `switching_canonical_S_long.csv`, …) |
| Markdown reports | Present under `reports/` (e.g. `run_switching_canonical_report.md`) |

## 4. Manifest and fingerprint

- **`run_manifest.json`:** Present at run root.
- **Fingerprint-related fields:** `git_commit`, `script_hash`, `matlab_version`, `host`, `user`, `repo_root`, `run_dir`, `label` (`switching_canonical`), `dataset` — **present** per `docs/infrastructure_laws.md` (manifest as canonical fingerprint carrier).
- **Linkage issue (entry script identity):** On disk, **`script_path` is `...\Aging\utils\createRunContext.m`**, not the registered canonical entrypoint **`...\Switching\analysis\run_switching_canonical.m`**. The **`script_hash`** corresponds to that `script_path` file. So **run identity and folder are consistent**, but **the manifest does not record the SSOT entry script path/hash** — `computeRunFingerprint` / `resolveCallingScriptPath()` in `createRunContext.m` resolves the wrong stack frame for this use case.
- **`run_status.csv`:** Contains **`CANONICAL`**, consistent with manifest `label` = `switching_canonical`.

## 5. Failure modes

| Mode | Finding |
| --- | --- |
| Silent failure | **Not** observed on the SUCCESS run (status + markers + tables). |
| Partial writes | **Observed** on **095928** (failed early; thinner file set than **100107**). |
| No-run / guard block | Guard **would** block invalid paths (documented); canonical path **passes**. |
| Execution without artifacts | **Not** for **100107** SUCCESS case. |
| Artifacts without execution | **Not** claimed for **100107** (coherent run tree). |

## 6. Determinism (light)

- Two runs on **2026-04-04** share the same **`git_commit`** in `run_manifest.json` but **different outcomes** (095928 FAILED vs 100107 SUCCESS). This is **not** duplicate identical SUCCESS reruns; it shows **outcome sensitivity** to runtime/error path rather than bitwise repeatability of outputs.

## 7. Verdict row (required)

| Field | Value |
| --- | --- |
| EXECUTION_STARTED | **YES** (evidenced by SUCCESS run artifacts and stage markers) |
| SCRIPT_ENTERED | **YES** (markers + `execution_probe_top.txt` + `disp` path in code) |
| OUTPUTS_WRITTEN | **YES** |
| MANIFEST_CREATED | **YES** |
| FINGERPRINT_CREATED | **YES** (manifest fields present; see linkage caveat above) |
| FAILURE_MODE_DETECTED | **YES** (validator NOT_PASS; manifest entry script mismatch; failed earlier run) |
| EXECUTION_TRUSTED | **NO** (end-to-end run and artifacts are real, but **manifest entry script / hash do not identify the registered canonical `.m`**, and the validator reports NOT_PASS — identity and policy checks are not fully trustworthy) |

---

**Deliverables:** `tables/execution_chain_audit.csv`, `tables/execution_chain_status.csv`, this file.
