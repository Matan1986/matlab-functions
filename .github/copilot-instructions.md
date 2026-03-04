# Copilot instructions for Matlab functions repo

## Big-picture structure
- This repo is a collection of MATLAB analysis pipelines, grouped by experiment type and versioned folders (e.g. `Aging/`, `FieldSweep ver3/`, `AC HC MagLab ver8/`).
- Each module is typically driven by a top-level script named `*_main.m` or `Main_*.m` (e.g. `Aging/Main_Aging.m`, `FieldSweep ver3/FieldSweep_main.m`, `AC HC MagLab ver8/ACHC_main.m`). These scripts set user options, choose data paths, call import helpers, then plot/fit.
- Shared utilities live in `General ver2/` and `Tools ver1/`; module-specific helpers stay in the module folder (e.g. `importFilesACHC.m`, `getFileList_aging.m`).

## Data flow and patterns (MATLAB)
- Scripts usually define a `dir`/`dataDir` pointing to a local data folder, then call `getFileList_*` → `importFiles_*` → analysis functions → plotting. Preserve that pipeline style.
- Path setup is done at the top with `baseFolder = '...Matlab functions'` and `addpath(genpath(baseFolder));` — new scripts should keep this pattern so shared helpers are found.
- Many scripts assume Windows-style absolute paths in `dir`/`dataDir`; keep those as configurable user settings rather than hard-coded in helpers.
- Plotting conventions: scripts set `fontsize`, `linewidth`, and use helpers like `formatAllFigures` or `close_all_except_ui_figures` when available.

## Key integration points
- Channel building and filtering for transport workflows use `build_channels` and `apply_median_and_smooth_per_sweep` (see `FieldSweep ver3/FieldSweep_main.m`).
- Aging-memory analysis relies on `computeDeltaM`, `analyzeAFM_FM_components`, and fit helpers like `fitFMstep_plus_GaussianDip` (see `Aging/Main_Aging.m`).
- Colormap utilities are vendored under `github_repo/cmocean` and can be added to the MATLAB path when needed.

## Developer workflow (verified from repo)
- There is no build system or tests discovered in the repo; scripts are run directly in MATLAB.
- When adding new analysis scripts, follow the structure: user settings → path setup → data import → analysis → plots.
- Prefer adding new module helpers next to their script folder, and shared generic utilities in `General ver2/` or `Tools ver1/`.
