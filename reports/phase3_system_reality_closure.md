# Phase 3 — System Reality Closure (Switching canonical)

Read-only lock step. No code changes. Scope: **Switching** canonical execution chain only. This document is the Phase 3 source of truth for what the system **actually** does today, aligned with `tables/system_blind_spot_audit.csv`, `tables/system_blind_spot_status.csv`, and `reports/system_blind_spot_audit.md`.

---

## 1. Actual system behavior (ground truth)

### Run directory root

- **Documented absolute run root (this workspace):** `C:\Dev\matlab-functions\results\switching\runs`
- **Implementation:** `createRunContext('Switching', cfg)` allocates `run_dir` as `fullfile(repoRoot, 'results', 'Switching', 'runs', <run_id>)` (see `Aging/utils/createRunContext.m`). On Windows, the same directory may appear with different segment casing; string identity for paths can differ from manifest canonical normalization (finding BS-01).

### Verified execution chain

`tools/run_matlab_safe.bat` → **`pre_execution_guard.ps1`** (filesystem check; invalid script → exit 2, MATLAB not launched) → **`matlab -batch "run('<ABSOLUTE_PATH_TO_SCRIPT.m>');"`** → **`Switching/analysis/run_switching_canonical.m`** → **`createRunContext`** → **`run_dir`** → **artifacts**.

### Where artifacts are written

| Artifact / area | Location |
|-----------------|----------|
| **execution_status.csv** | `<run_dir>/execution_status.csv` |
| **run_manifest.json** (embeds fingerprint fields) | `<run_dir>/run_manifest.json` |
| **config_snapshot.m, log.txt, run_notes.txt** | `<run_dir>/` |
| **Tables** (e.g. `switching_canonical_*.csv`, implementation status) | `<run_dir>/tables/` |
| **Reports** (e.g. `run_switching_canonical_report.md`) | `<run_dir>/reports/` |
| **Auxiliary probes** (`execution_probe_top.txt`, `execution_probe*.csv`) | `<run_dir>/` |
| **runtime_execution_markers.txt** | `<run_dir>/` when run context resolves; else possible repo-level fallback per `tools/write_execution_marker.m` (BS-06) |

**Fingerprint:** There is no separate fingerprint file in this chain; fingerprint content is **embedded in `run_manifest.json`** (script hash, git commit, host, user, MATLAB version, script path).

### Authoritative execution signal

- **Only authoritative signal:** **`execution_status.csv`**, column **`EXECUTION_STATUS`**, in the **final written state** of the file after the run completes.
- The script overwrites this file multiple times during execution (PARTIAL → PARTIAL → SUCCESS or FAILED); each write is typically a **single-row** table — **last write wins**. Interpreting a copy taken **mid-run** is not valid for final outcome (BS-02).

---

## 2. System contract (as-is, not ideal)

This is how the Switching canonical run behaves **today**, not a target architecture.

1. **`run_dir`** is allocated under **`results/Switching/runs`** (via experiment name **`Switching`** in `createRunContext`), not under a single globally enforced run root shared identically by all modules.
2. **`execution_status.csv`** is the **authoritative** execution outcome; MATLAB exit code and console output are **not** validity indicators for automated judgment (see `docs/repo_execution_rules.md` signaling section and script comments).
3. **`run_manifest.json`** plus embedded fingerprint fields define **run identity and environment** for that run (not purely a deterministic “build” fingerprint — BS-08).
4. **Pipeline / “validator” outputs** (e.g. `switching_canonical_validation.csv`, `CANONICAL_PIPELINE_CONFIRMED`, implementation status tables) are **diagnostic and governance-oriented**; they **do not** override **`execution_status.csv`** (BS-07).
5. **Guard** (`pre_execution_guard.ps1`) **controls whether MATLAB starts** (path must exist and be a `.m` file); it is not a second MATLAB invocation.
6. **Optional** `validate_matlab_runnable.ps1` is **not** invoked by the batch wrapper; preflight validation remains non-blocking at the wrapper level (`docs/repo_execution_rules.md`).

---

## 3. Non-canonical aspects (explicit)

### (A) Run directory root not globally enforced

| Field | Value |
|--------|--------|
| **CATEGORY** | PATH |
| **CURRENT_BEHAVIOR** | `run_dir` is created under `results/Switching/runs` (experiment-specific) and depends on implementation and `createRunContext`, not on a single globally enforced canonical run root for the whole repository. |
| **CANONICAL_EXPECTATION** | Single globally enforced run root independent of module. |
| **IMPACT** | Run identity is path- and module-convention-dependent. |
| **REQUIRES_PHASE4_FIX** | **YES** |

### (B) Failure path not canonical

| Field | Value |
|--------|--------|
| **CATEGORY** | FAILURE |
| **CURRENT_BEHAVIOR** | On early failure before `run_dir` is set, the catch path may use `createRunContext(..., 'switching_canonical_failure')` or create `results/Switching/runs/run_failure_<timestamp>` **without** the same manifest lifecycle as the primary success path (BS-05). |
| **CANONICAL_EXPECTATION** | Failure runs follow the same manifest + fingerprint + `run_dir` contract as success runs. |
| **IMPACT** | Partial break of execution identity and provenance consistency on some failure paths. |
| **REQUIRES_PHASE4_FIX** | **YES** |

### (C) External raw data dependency (intentional policy)

| Field | Value |
|--------|--------|
| **CATEGORY** | DATA |
| **CURRENT_BEHAVIOR** | Raw data path is parsed from legacy `Switching_main.m` and may point **outside** the repository (environment-dependent) (BS-04). |
| **INTENT** | Intentional: avoid repository bloat. |
| **CANONICAL_EXPECTATION** | Data remain outside the repo but should be governed by a formal contract: defined data root, deterministic resolution rule, stable identity (version / location). |
| **IMPACT** | Reproducibility depends on environment configuration unless that contract exists. |
| **REQUIRES_PHASE4_FIX** | **YES** (formalization only, **not** relocation) |

### (D) execution_status.csv multi-write behavior

| Field | Value |
|--------|--------|
| **CATEGORY** | SIGNAL |
| **CURRENT_BEHAVIOR** | `execution_status.csv` is **overwritten** multiple times (PARTIAL → … → SUCCESS or FAILED) (BS-02). |
| **CANONICAL_EXPECTATION** | Clear final-state semantics: single authoritative final state (operators must read after completion or treat mid-run copies as non-final). |
| **IMPACT** | Time-dependent interpretation if the file is read mid-run. |
| **REQUIRES_PHASE4_FIX** | **OPTIONAL** (contract clarification) |

---

## 4. What is canonical and stable (confirmations)

These flags describe **understood, trusted behavior** of the documented Switching chain, not an assertion that the whole system is idealized.

| Flag | Value |
|------|--------|
| **EXECUTION_TRUSTED** | **YES** |
| **SYSTEM_DETERMINISTIC** | **YES** (given fixed repo state, script inputs, and external raw tree; run IDs use local clock — BS-15) |
| **SIGNALING_UNIFIED** | **YES** (single declared authority: `execution_status.csv`) |
| **NO_FALLBACK_DURING_SUCCESS_PATH** | **YES** (catch fallback applies when establishing failure status if `run_dir` was not set) |
| **MANIFEST_VALID** | **YES** on normal success path (`run_manifest.json` written by `createRunContext`) |
| **FINGERPRINT_VALID** | **YES** on normal success path (embedded in manifest) |

---

## 5. Phase 3 closure verdict

| Flag | Value |
|------|--------|
| **PHASE_3_CLOSED** | **YES** |
| **SYSTEM_UNDERSTOOD** | **YES** |
| **EXECUTION_TRUSTED** | **YES** |
| **DETERMINISTIC** | **YES** |
| **FULLY_CANONICAL** | **NO** |

Machine-readable copy: `tables/phase3_closure_status.csv`.

---

## Final note

This step **reflects reality**, **does not** prescribe fixes, and **does not** refactor code. It is the **lock** record for Phase 4 planning. Inputs: `tables/system_blind_spot_audit.csv`, `tables/system_blind_spot_status.csv`, `reports/system_blind_spot_audit.md`.
