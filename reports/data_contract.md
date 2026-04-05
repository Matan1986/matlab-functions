# Switching data contract (Phase 4.3, DRAFT)

This document defines the **external and repo-local data interface** consumed by the Switching scripts in scope. It is descriptive only: **no enforcement**, **no pipeline changes**, and **no data copied into the repo** beyond what already exists as repo files.

**Scope scripts**

- `Switching/analysis/run_switching_canonical.m`
- `Switching/analysis/analyze_phi_kappa_canonical_space.m`
- Loaders invoked from the canonical run: legacy `getFileListSwitching`, `processFilesSwitching`, and helpers on the `Switching ver12` path.

---

## 1. Data flow overview

```text
DATA SOURCE -> FORMAT -> ACCESS -> ASSUMPTIONS -> FAILURE MODES
```

### 1.1 `run_switching_canonical.m`

| Stage | Description |
|-------|-------------|
| **SOURCE** | (a) Repo file `Switching ver12/main/Switching_main.m` supplies a **hardcoded** `dir = "..."` parent path. (b) Under that parent, only subfolders whose names start with **Temp Dep** (case-insensitive) are scanned. (c) Each such folder contributes `*.dat` files. |
| **FORMAT** | Legacy `.dat` files read via `importdata` inside `processFilesSwitching` (numeric matrix `data`; time in column 1; lock-in columns 5/7/9/11 when non-NaN). Folder names supply metadata (e.g. `Current_mA`) via `getFileListSwitching`. |
| **ACCESS** | `repoRoot` from script path -> `fullfile(repoRoot,'Switching ver12',...)`. Parent data path is **not** taken from `cfg` or environment; it is **parsed from the legacy file**. |
| **ASSUMPTIONS** | Parsed parent exists; contains at least one **Temp Dep*** folder with readable `.dat`; metadata and channel pipeline produce finite `T_K` / `S_percent` samples. See `tables/data_contract_assumptions.csv`. |
| **FAILURE MODES** | Missing legacy file, missing parent dir, no Temp Dep folders, no samples, or invalid current/channel -> **errors**. Partial file issues may surface as warnings or downstream errors. See `tables/data_contract_failures.csv`. |

### 1.2 `analyze_phi_kappa_canonical_space.m`

| Stage | Description |
|-------|-------------|
| **SOURCE** | Repo CSVs under `<REPO_ROOT>/tables/`: `phi_kappa_stability_summary.csv` (required for logic). `phi_kappa_stability_status.csv` is read but **not used** in the script body. |
| **FORMAT** | CSV tables; required columns for the summary file include pair metrics and stability columns listed in the assumptions table. |
| **ACCESS** | `baseFolder` / `repoRoot` from `mfilename('fullpath')` (three levels up to repo root), then `fullfile(...,'tables',...)`. |
| **ASSUMPTIONS** | `pair` strings parse as `variant_a vs variant_b`; canonical filter uses `xy_over_xx` and `baseline_aware`. |
| **FAILURE MODES** | Missing CSV -> `readtable` throws (**hard fail**). Schema mismatch -> runtime errors. Unused status file still forces read success. |

---

## 2. Data sources (registry)

Authoritative machine-readable rows: **`tables/data_contract_sources.csv`**.

Summary:

- **SW_LEGACY_MAIN**: configuration carrier (embedded path string).
- **SW_EXTERNAL_RAW_PARENT** / **SW_RAW_DAT**: live measurement tree **outside** the repo (typical case).
- **SW_PHI_KAPPA_***: repo-local **processed** tables feeding the canonical-space recomputation.

---

## 3. Path resolution (Switching-only)

| Consumer | Method |
|----------|--------|
| `run_switching_canonical.m` | `repoRoot` from `fileparts(fileparts(fileparts(mfilename('fullpath'))))` (fixed depth). Legacy `Switching_main.m` path is **deterministic** under that root. **Parent raw path** comes only from **regex** on file contents, not from CLI or `cfg`. |
| `analyze_phi_kappa_canonical_space.m` | Same `repoRoot`-style resolution to `tables/`. |

No Switching helper in this path (`resolve_results_input_dir`, `load_observables`, etc.) is required for these two entrypoints.

---

## 4. Format contract (minimal)

### 4.1 Raw `.dat` (via `processFilesSwitching`)

- **File type**: `.dat`, `importdata`-compatible numeric content.
- **Required shape**: `data` matrix with at least 5 columns if any LI channel is used; column 1 interpreted as time.
- **Channels**: Physical channels 1..4 mapped from columns 5, 7, 9, 11 when those columns contain non-NaN data.
- **Units**: Script scales resistivity using `I_A` (A) and `scaling_factor` (canonical uses `1e3`); reported `S_percent` is derived in downstream tables (see generated run CSVs).

### 4.2 `phi_kappa_stability_summary.csv`

- **File type**: CSV.
- **Required variables** (for current script): `pair`, `phi_shape_corr`, `kappa_corr`, `abs_kappa_corr`, `kappa_sign`, `PHI_PAIR_STABLE`, `KAPPA_PAIR_STABLE`, `KAPPA_SIGN_STATUS`; optional `residual_structure_corr` (if absent, analysis fills NaNs in output).
- **Pair format**: `"<variant_a> vs <variant_b>"` with space-padded ` vs ` as split token in code.

---

## 5. Data-run linkage (manifest / fingerprint)

Runs allocated via `createSwitchingRunContext` -> `createRunContext('switching', cfg)` produce:

- **`run_manifest.json`**: `git_commit`, `script_path`, `script_hash`, `matlab_version`, `host`, `user`, `dataset` (from `cfg.dataset`, e.g. `raw_switching_dat_only`), paths to run_dir.
- **`config_snapshot.m`**: serialized `cfg` (and run metadata append).

**Gap (documentary)**: The **raw measurement root path** and **per-file identities** (hashes, counts, version pins) are **not** recorded in the manifest. The **dataset** field is a **label**, not a content-addressed id of external data. Therefore **`DATA_IDENTITY_TRACKED=partial`** for end-to-end reproducibility of raw bytes.

Details: **`tables/data_contract_status.csv`**.

---

## 6. Mutability and drift risk

| Source | Drift risk | Notes |
|--------|------------|--------|
| SW_EXTERNAL_RAW_PARENT / SW_RAW_DAT | **HIGH** | External tree can change without repo commit; no checksum linkage. |
| SW_LEGACY_MAIN | **MEDIUM** | Editing `dir = "..."` changes upstream without changing canonical MATLAB logic. |
| SW_PHI_KAPPA_* | **MEDIUM** | Repo files can be regenerated or hand-edited; not content-addressed in manifest unless separately pinned. |

---

## 7. Deliverables checklist

| Artifact | Purpose |
|----------|---------|
| `tables/data_contract_sources.csv` | Source IDs, types, locations, loaders |
| `tables/data_contract_assumptions.csv` | Implicit/explicit assumptions |
| `tables/data_contract_failures.csv` | Missing/corrupt/wrong-schema behavior |
| `tables/data_contract_status.csv` | Phase status and linkage summary |
| `reports/data_contract.md` | Human-readable contract (this file) |

---

## 8. Status

**`DATA_CONTRACT_DEFINED=YES`** (definition only; not enforced).
