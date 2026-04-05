# Phase 3.0 — System Reality Audit (Switching canonical)

**Scope:** Switching canonical execution only (`tables/switching_canonical_entrypoint.csv` → `Switching/analysis/run_switching_canonical.m`).  
**Method:** Read-only inspection of tooling and script code, plus **existing** run artifacts under `results/switching/runs/` (no new MATLAB runs).  
**Date:** 2026-04-04.

---

## 1. Full execution flow (actual, not assumed)

```
[Operator / automation]
        |
        v
tools/run_matlab_safe.bat "<ABS>\Switching\analysis\run_switching_canonical.m>"
        |
        |  (1) Resolve path; set MATLAB_COMMAND = run('.../run_switching_canonical.m')
        v
tools/pre_execution_guard.ps1  (PowerShell -File)
        |  exit 2  => MATLAB NOT launched; log to tables/pre_execution_failure_log.csv
        |  exit 0  => OK
        v
matlab.exe -batch "run('<ABS>/run_switching_canonical.m')"
        |
        |  NOTE: batch file creates temp_runner_*.m with disp/pause but does NOT pass it
        |        to MATLAB (dead artifact; see risks).
        v
MATLAB loads run_switching_canonical.m as a **script** (not a function) via `run()`.
        |
        |  Top of script (before try): clear; clc; addpath tools; write_execution_marker('ENTRY')
        |  (may hit repo-level fallback marker file until run context exists)
        v
try
  restoredefaultpath; repopulate paths; strict which('createRunContext') check
        |
        v
cfg.fingerprint_script_path = <run_switching_canonical.m absolute path>
ctx = createRunContext('Switching', cfg)
        |  => results/Switching/runs/<run_id>/  + run_manifest.json + fingerprint + logs
        v
Probe I/O: execution_status.csv PARTIAL rows; execution_probe*.csv; execution_probe_top.txt
        |
        v
Legacy pipeline loop over "Temp Dep*" under raw parent dir from Switching_main.m string:
  getFileListSwitching -> processFilesSwitching -> analyzeSwitchingStability -> aggregate S(T,I)
        |
        v
Analysis: peaks, PT/CDF maps, SVD (phi1, kappa1), validation flags, writetable outputs
        |
        v
write_execution_marker STAGE_* / COMPLETED; execution_status.csv SUCCESS
catch
  write failure execution_status + implementation stubs; write_execution_marker FAILED; rethrow
```

**Validator:** `tools/validate_matlab_runnable.ps1` is **not** invoked by `run_matlab_safe.bat`. It is optional/manual per `docs/repo_execution_rules.md`. It does **not** gate launch.

---

## 2. Script entry behavior (MATLAB reality)

| Question | Finding |
|----------|---------|
| How does MATLAB enter the canonical script? | `matlab -batch "run('<ABS>/run_switching_canonical.m')"` — the batch engine executes the file as a script. |
| `run()` vs “open file and F5”? | Automated path uses **`run()`** only. Direct/F5 was not tested; behavior should match script semantics. |
| Does `dbstack` expose the entry script? | `createRunContext` / `computeRunFingerprint` documents that `run()` may omit the true caller from `dbstack`. **Reality in current code:** `run_switching_canonical.m` sets `cfg.fingerprint_script_path` to its own path, so `computeRunFingerprint` uses that file for `script_path` / `script_hash` (verified in sample `run_manifest.json`). |
| Hidden entry indirection? | None beyond normal `run()`. No `eval(fileread(...))` in the wrapper (per policy). |

---

## 3. Artifact lineage (summary)

| Artifact | Writer | Where | Writes / determinism |
|----------|--------|-------|----------------------|
| `execution_status.csv` | `run_switching_canonical.m` | `writetable` to `run_dir` | **3** overwrites on success (PARTIAL → PARTIAL → SUCCESS); deterministic order. |
| `execution_probe.csv` | same | single-row probe table | **1** write. |
| `execution_probe_top.txt` | same | `fopen`/`fclose` empty file | **1** (existence proof). |
| `switching_canonical_*.csv` | same | `writetable` under `run_dir/tables/` | **1** each on success. |
| `run_switching_canonical_report.md` | same | `fprintf` under `run_dir/reports/` | **1** on success. |
| `run_manifest.json` | `createRunContext.m` → `writeManifest` | New run only | **1**; **skipped** if manifest already exists (warning). |
| Fingerprint | `computeRunFingerprint` in `createRunContext.m` | Embedded into manifest JSON | Assigned when context is created. |
| `runtime_execution_markers.txt` | `write_execution_marker.m` | Append under `run_dir` | Many lines; **append**. Early `ENTRY` may also append to `tables/runtime_execution_markers_fallback.txt`. |

Full row-level detail: `tables/artifact_lineage_map.csv`.

---

## 4. Source-of-truth summary

| Concept | SoT |
|---------|-----|
| **S(I,T)** | Built in `run_switching_canonical.m` as `Smap` from aggregated raw rows; exported as `switching_canonical_S_long.csv` and used for models. |
| **Phi1** | First **right** singular vector from `svd(Rfill)` after scaling/sign flip; exported `switching_canonical_phi1.csv`. |
| **kappa1** | First **left** singular vector times `Sigma(1,1)`; aligned with Phi1 scaling; column in observables table. |
| **Observables** | `writetable(ObsTbl, ...)` — single final table for peaks and kappa. |
| **Manifest** | `writeManifest` in `Aging/utils/createRunContext.m` — single JSON per new run directory. |
| **Fingerprint** | `computeRunFingerprint` — same file; `script_path`/`script_hash` from `cfg.fingerprint_script_path` when set. |

**Registry entrypoint (agents):** `tables/switching_canonical_entrypoint.csv` — not overwritten by the run.

**Non-canonical path:** Running `Switching_main.m` or other backends directly is out of scope for this audit; canonical pipeline does **not** execute `Switching_main` as code — only `fileread` for the parent directory string.

---

## 5. Control-flow integrity (hidden branches)

- **Optional General ver2 presets:** `resolve_preset` / `select_preset` only if **both** exist on path (`exist ... == 2`).  
- **Optional polarity:** `resolveNegP2P` flips `Svec` if present.  
- **Try/catch:** On error, failure `execution_status.csv` and implementation CSV/MD; may create a **new** failure run dir via `createRunContext('..._failure')` or `run_failure_<timestamp>`.  
- **Manifest:** Existing `run_manifest.json` is never overwritten.  
- **Environment:** `git rev-parse`, hostname, username, MATLAB `version` feed fingerprint.

---

## 6. Runtime structure (light, from existing artifacts)

**Sample:** `run_2026_04_04_143749_switching_canonical` — `runtime_execution_markers.txt`:

| Interval | ~Duration | Interpretation |
|----------|-------------|----------------|
| ENTRY → STAGE_START_PIPELINE | ~2.3 s | Path setup, `createRunContext`, probes, status writes |
| STAGE_START_PIPELINE → STAGE_AFTER_PROCESSING | ~17.2 s | **Dominant:** raw file processing + stability per folder |
| STAGE_AFTER_PROCESSING → STAGE_BEFORE_OUTPUTS | ~0.5 s | SVD, metrics, validation flags |
| STAGE_BEFORE_OUTPUTS → STAGE_AFTER_OUTPUTS | ~0.3 s | CSV + report writes |
| After STAGE_AFTER_OUTPUTS | <0.1 s | Final SUCCESS status + COMPLETED marker |

**Conclusion:** Most wall time is in the **legacy processing loop** (`processFilesSwitching` / `analyzeSwitchingStability`), not in the rank-1 algebra or CSV export.

---

## 7. IO behavior (audit)

- **Repeated writes:** `execution_status.csv` same path, three logical snapshots.  
- **Repeated reads:** One `fileread` of `Switching_main.m`; many reads inside legacy pipeline for `.dat` data.  
- **Directory scans:** `dir` on raw parent + per-folder listing inside helpers.  
- **Duplication:** Long-format `S_long` vs grid `Smap` — same physics, two representations by design.  
- **Cross-run:** Fallback execution marker file at repo `tables/` accumulates lines from all runs (not run-scoped).

Detail: `tables/io_behavior_map.csv`.

---

## 8. Identity flow verification

```
createRunContext -> run_id, run_dir (unique under results/Switching/runs)
        -> computeRunFingerprint -> manifest.script_path, script_hash, git_commit, ...
        -> writeManifest (once)
run_switching_canonical -> execution_status.csv, probes, tables under run_dir
```

**Linkage:** `run_manifest.json` `run_dir` matches the folder containing `execution_status.csv` in successful runs inspected.  
**Alternate path:** Failure catch may use a **different** `run_dir` than the happy-path `run` struct if context creation fails — documented in code and risk table.

---

## 9. Parallelization (pre-map)

| Area | Class |
|------|-------|
| Single canonical batch run | **SERIAL_REQUIRED** (single process, sequential loop, ordered writes) |
| Independent batch runs on different machines | **SEMI_PARALLEL** (distinct `run_id`; watch repo git/hash consistency) |

Detail: `tables/parallelization_map.csv`.

---

## 10. Risks and ambiguities

See `tables/system_reality_risks.csv`. Highlights:

- Unused **temp runner** in `run_matlab_safe.bat` does not match the documented “single call” mental model for operators reading the file.  
- **Fallback** execution markers mix runs at repo level.  
- **Conditional** preset/negP2P helpers can change numerics when those files exist on path.  
- **`run_status.csv`** is **not** produced by this canonical script; tools that assume it must not treat this run as complete by that file alone.

---

## Deliverables index

| File | Purpose |
|------|---------|
| `tables/system_execution_map.csv` | Step-by-step execution chain |
| `tables/artifact_lineage_map.csv` | Writers and overwrite behavior |
| `tables/source_of_truth_map.csv` | Concept → SoT |
| `tables/runtime_stage_map.csv` | Stages and sample durations |
| `tables/io_behavior_map.csv` | IO classification |
| `tables/parallelization_map.csv` | Parallel safety |
| `tables/system_reality_risks.csv` | Risk register |
| `tables/system_reality_status.csv` | Roll-up status row |

---

## References (read-only)

- `docs/repo_execution_rules.md` — wrapper, guard, validator policy  
- `tables/switching_canonical_entrypoint.csv` — entrypoint registry  
- `Switching/analysis/run_switching_canonical.m` — canonical script  
- `Aging/utils/createRunContext.m` — manifest and fingerprint  
- `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1` — launcher chain  
