# Canonical boundary truth audit — Switching

## Authoritative entrypoint

- `Switching/analysis/run_switching_canonical.m` (per task; aligns with repo policy referencing this script as the Switching canonical runner).

## Dependency closure method

Closure was derived by **reading the entrypoint** and **recursively tracing explicit MATLAB calls** (`createRunContext`, `write_execution_marker`, legacy helpers on `path`, and conditional `exist(...)` branches) through to **leaf project `.m` files**. Built-in/toolbox functions and class methods are not listed as separate files.

**Excluded from closure (not invoked on the default successful path):**

- All files under `Switching/utils/` — `addpath` is performed but **no** `Switching/utils/*.m` symbol is called by the canonical script.
- `General ver2/Plot Metadata API ver1/physLabel.m` — `analyzeSwitchingStability` can call it only when `opts.debugMode` is true; the canonical run sets `stbOpts.debugMode = false`. Moreover, only `General ver2` (non-recursive) is on `path`, so subfolder helpers are **not** automatically visible unless added elsewhere.
- `Switching ver12/main/Switching_main.m` is **not executed**; it is **`fileread`** for a regex extracting `dir = "..."` (raw parent path).

## Full canonical dependency closure (`.m` files)

| FILE | CALLED_BY (immediate) | DEPTH |
|------|------------------------|-------|
| `Switching/analysis/run_switching_canonical.m` | — | 0 |
| `tools/write_execution_marker.m` | `run_switching_canonical.m` | 1 |
| `Aging/utils/createRunContext.m` | `run_switching_canonical.m` (+ catch path) | 1 |
| `Switching ver12/main/Switching_main.m` | `run_switching_canonical.m` (`fileread`) | 1 |
| `Switching ver12/getFileListSwitching.m` | `run_switching_canonical.m` | 1 |
| `Switching ver12/parsing/extract_dep_type_from_folder.m` | `run_switching_canonical.m` | 1 |
| `Switching ver12/parsing/extractPulseSchemeFromFolder.m` | `run_switching_canonical.m` | 1 |
| `Switching ver12/parsing/extract_num_of_pulses_from_name.m` | `extractPulseSchemeFromFolder.m` | 2 |
| `Switching ver12/parsing/extract_delay_between_pulses_from_name.m` | `run_switching_canonical.m` | 1 |
| `General ver2/resolve_preset.m` | `run_switching_canonical.m` (if `exist` both true) | 1 |
| `General ver2/select_preset.m` | `run_switching_canonical.m` (if `exist` both true) | 1 |
| `General ver2/extract_preset_from_filename.m` | `resolve_preset.m` | 2 |
| `Switching ver12/main/processFilesSwitching.m` | `run_switching_canonical.m` | 1 |
| `General ver2/resolve_norm_indices.m` | `processFilesSwitching.m` | 2 |
| `Switching ver12/main/analyzeSwitchingStability.m` | `run_switching_canonical.m` | 1 |
| `Switching ver12/resolveNegP2P.m` | `run_switching_canonical.m` (if `exist` true) | 1 |

Local functions inside `createRunContext.m`, `write_execution_marker.m`, `analyzeSwitchingStability.m`, and nested functions in `select_preset.m` do **not** add additional file identities.

## Definitely inside the canonical boundary

- The **16** `.m` files listed in `tables/canonical_boundary_truth.csv` (transitive closure for the traced call graph).
- **Run-scoped outputs** under `results/Switching/runs/<run_id>/` created by `createRunContext` and the canonical script (including `tables/` and `reports/` **under** `run_dir`).

## Definitely outside the boundary (for this entrypoint)

- **`Switching/utils/*.m`** — on `path` but **not referenced** by the traced call graph.
- **Relaxation / Aging analysis** code paths — not called (only `Aging/utils/createRunContext.m` per policy).
- **Prior run artifacts** under `results/switching/runs/*` — **no** `fileread`/`load`/`readtable` of other runs found in the closure for this entrypoint (string checks only).

## Uncertain components

- **Dynamic MATLAB behavior:** `which` resolution order, shadowing, and toolbox availability (e.g. `kmeans` in `analyzeSwitchingStability` for `"cluster"` mode — not used when `stateMethod` is `"repeated"` as in the canonical call).
- **Conditional helpers:** `resolve_preset` / `select_preset` / `resolveNegP2P` depend on `exist(...,'file')` and typical repo layout.
- **Debug-only code paths** inside `analyzeSwitchingStability.m` (not used when `debugMode` is false).
- **End-to-end runtime** was **not** executed in this audit; closure is **static** from source.

## Forbidden or policy-risk accesses (confirmed / suspected)

See `tables/canonical_boundary_violations_truth.csv`. Highlights:

- **Repo-root `tables/` write** via `tools/write_execution_marker.m` fallback path.
- **Embedded external raw path** sourced from legacy `Switching_main.m` text.

## Indirect / helper risks

- **Legacy `Switching ver12` tree** is fully prepended to `path` (broad surface area even though only a small subset is called).
- **`createRunContext`** runs **`git`** and hashes the **calling script** (external process + reads script file).
- **No read** of repo-root `tables/*` or `reports/*` was found in the traced closure; outputs under `run_dir/tables` and `run_dir/reports` are **run-scoped**, not repo-root tables/reports.

## Enforceability assessment

The boundary is **not fully enforceable from static structure alone** today because:

- Multiple directories are added to `path` (legacy + `General ver2` + `Aging/utils`).
- Raw input location is **injected from a legacy file** string, not a manifest-only contract.
- `write_execution_marker` can write to **repo `tables/`** in a fallback scenario.

Machine-readable summaries: `tables/canonical_boundary_truth_status.csv`, `tables/canonical_boundary_truth.csv`, `tables/canonical_access_audit.csv`.
