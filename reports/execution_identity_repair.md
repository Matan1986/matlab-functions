# Phase 2.1B — Execution identity repair (Switching canonical)

## 1. Identity source audit

**Where `script_path` and `script_hash` are set**

- `Aging/utils/createRunContext.m`, nested function `computeRunFingerprint` assigns:
  - `fingerprint.script_path`
  - `fingerprint.script_hash` via `computeFileSha256(fingerprint.script_path)`
- `writeManifest` copies those fields into `run_manifest.json` (`manifest.script_path`, `manifest.script_hash`).

**Why `createRunContext.m` appeared before**

- `resolveCallingScriptPath()` walks `dbstack('-completenames')` and returns the first frame whose file is not `createRunContext.m`, else it falls back to `mfilename('fullpath')` inside that helper (i.e. `createRunContext.m`).
- For a **script** executed with `run('...')`, the **calling script often does not appear on `dbstack`**, so the fallback incorrectly identified the helper file as the “calling script.”

## 2. Minimal fix design

1. **Optional override:** `cfg.fingerprint_script_path` — when set and the path resolves to an existing file, use it for `script_path` and hashing.
2. **Entry script:** `Switching/analysis/run_switching_canonical.m` sets  
   `cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);`  
   so the path always points at the registered canonical `.m` file (also fixes cases where `mfilename('fullpath')` omits the `.m` extension under `run()`, which previously yielded an empty hash).
3. **Shared normalization:** After resolving the path (override or `resolveCallingScriptPath`), if the file is still not found, append `.m` once and re-check before `normalizeAbsolutePath` + hash.

No changes to Switching ver12 math, validators, or scientific logic.

## 3. Implementation

| File | Change |
| --- | --- |
| `Aging/utils/createRunContext.m` | Pass `cfg` into `computeRunFingerprint`; implement `cfg.fingerprint_script_path` and `.m` fallback before hashing. |
| `Switching/analysis/run_switching_canonical.m` | Set `cfg.fingerprint_script_path` to the canonical entry `.m` path as above. |

## 4. Verification

**Run:** `run_2026_04_04_141426_switching_canonical` (via `tools/run_matlab_safe.bat` with absolute path to `run_switching_canonical.m`).

- **`execution_status.csv`:** `EXECUTION_STATUS=SUCCESS`, `N_T=16`.
- **`run_manifest.json`:**
  - `"script_path"` ends with `Switching\analysis\run_switching_canonical.m` (matches `tables/switching_canonical_entrypoint.csv`).
  - `"script_hash"` is a 64-character hex SHA-256.
- **Cross-check:** PowerShell `Get-FileHash -Algorithm SHA256` on `Switching\analysis\run_switching_canonical.m` matches `script_hash` exactly.

## 5. Verdict

| Field | Value |
| --- | --- |
| IDENTITY_MATCHES_ENTRYPOINT | **YES** |
| EXECUTION_STILL_WORKS | **YES** |
| MANIFEST_CORRECT | **YES** |
| EXECUTION_TRUSTED | **YES** |

---

**Deliverables:** `tables/execution_identity_repair.csv`, `tables/execution_identity_status.csv`, this report.
