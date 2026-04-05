# ver12 canonical audit

## Scope (strict)
Audited code under `Switching ver12/`, with focus on:
- `main/`
- `parsing/`
- core functions: `processFilesSwitching`, `getFileListSwitching`, `analyzeSwitchingStability`

Evidence-based only; no assumptions.

## Full data flow

### Core switching path
1. File discovery and sorting: `getFileListSwitching` lists `*.dat` and parses sweep values from filenames/folder name.
   - `C:\Dev\matlab-functions\Switching ver12\getFileListSwitching.m:3`
   - `C:\Dev\matlab-functions\Switching ver12\getFileListSwitching.m:17`
   - `C:\Dev\matlab-functions\Switching ver12\getFileListSwitching.m:82`
2. Raw import: `processFilesSwitching` loads each `.dat` file via `importdata`.
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:50`
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:51`
3. Signal processing and metrics: unfiltered/filt/centered traces, plateau means, P2P stats, percent change.
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:99`
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:107`
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:374`
4. Stability analysis over processed traces and plateau means.
   - `C:\Dev\matlab-functions\Switching ver12\main\analyzeSwitchingStability.m:156`
   - `C:\Dev\matlab-functions\Switching ver12\main\analyzeSwitchingStability.m:173`

### Alternate branch reachable from main (non-raw)
`Switching_main` exits early into amp-temp map mode when folder pattern matches.
- `C:\Dev\matlab-functions\Switching ver12\main\Switching_main.m:15`
- `C:\Dev\matlab-functions\Switching ver12\main\Switching_main.m:24`

That branch reads precomputed run outputs from `results/switching/runs/.../tables/switching_full_scaling_parameters.csv`.
- `C:\Dev\matlab-functions\Switching ver12\plots\plotAmpTempSwitchingMap_switchCh.m:704`
- `C:\Dev\matlab-functions\Switching ver12\plots\plotAmpTempSwitchingMap_switchCh.m:745`

## Data sources detected

| Source type | Location | Raw or precomputed |
|---|---|---|
| `.dat` raw files (`importdata`) | `processFilesSwitching` line 51 | Raw |
| Folder/file-name metadata parsing (`dir`, `regexp`) | `getFileListSwitching`, `parsing/*.m` | Raw metadata heuristics |
| `.csv` table (`readtable`) from `results/switching/runs/...` | `plotAmpTempSwitchingMap_switchCh` line 745 | Precomputed |
| `.mat` colormap (`load`) | `plotAmpTempSwitchingMap_switchCh` line 309 | External asset (not raw measurement) |
| `.csv` table (`readtable`) from run tables | `plotSwitchingPanelF` line 30 | Precomputed |

No `readmatrix` usage found in `Switching ver12`.

## All preprocessing steps (with control and physics impact)

| Preprocessing step | Where | Explicit in code | Configurable | Affects physics output |
|---|---|---|---|---|
| LI→R scaling (`/I * Scaling_factor`) | `processFilesSwitching:101-104` | YES | Partly (`I`, `Scaling_factor` upstream) | YES |
| Hampel filter | `processFilesSwitching:115` | YES | YES (window, threshold) | YES |
| SG filter | `processFilesSwitching:127` | YES | YES (poly, frame) | YES |
| Median filter | `processFilesSwitching:138` | YES | YES (window) | YES |
| Boundary overwrite (`x(1)=x(2)`, `x(end)=x(end-1)`) | `processFilesSwitching:118-121`, `132-135`, `139-142` | YES | NO | YES |
| Global outlier replacement to median (`8*sigma`) | `processFilesSwitching:164-171` | YES | NO (always applied; constant 8 fixed) | YES |
| Pulse-near outlier cleaning | `processFilesSwitching:194-252` | YES | YES (flag, threshold, margins) | YES |
| Plateau averaging window excluding pulse margins | `processFilesSwitching:257-287` | YES | Partly (margin percent configurable, formula fixed) | YES |
| Baseline centering excluding first/last plateau | `processFilesSwitching:288-297` | YES | NO | YES |
| Conditioning-step skip (`skipFirstSteps = 1`) in P2P | `processFilesSwitching:406-411` | YES | NO | YES |
| Robust P2P rejection threshold (`4*1.4826*MAD`) | `processFilesSwitching:414-420` | YES | NO | YES |
| Sign choice from 3rd pulse with fallbacks | `processFilesSwitching:447-467` | YES | NO | YES |
| Stability skip-first/skip-last plateaus | `analyzeSwitchingStability:224-231` | YES | YES (`opts`) | YES |
| State classification by kmeans (cluster mode) | `analyzeSwitchingStability:268-276` | YES | Partly (`stateMethod` selectable, RNG control absent) | YES |
| Within-plateau linear fit + settle-time thresholding | `analyzeSwitchingStability:441-472` | YES | YES (`minPtsFit`, `settleFrac`) | YES |
| Parsing normalization/fallback defaults (`dep_type`, pulses, timing) | `parsing/*.m` | YES | Mostly NO | YES (changes grouping/timing/state model) |

## Hidden assumptions (strict)
1. Measurement channel columns are hardcoded to data columns 5/7/9/11.
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:56-59`
2. Pulse scheme is inferred from folder-name text (`contains("repeated")`), otherwise forced to alternating.
   - `C:\Dev\matlab-functions\Switching ver12\parsing\extractPulseSchemeFromFolder.m:14-18`
3. `dep_type` defaults to `Temperature` when detection fails.
   - `C:\Dev\matlab-functions\Switching ver12\parsing\extract_dep_type_from_folder.m:47-49`
4. First P2P step is always excluded (`skipFirstSteps = 1`) with no interface control.
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:406`
5. Global outlier clamp is always active and fixed at `8 * sigma`.
   - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:164-171`

## External dependency checks

### Aging / Relaxation
- No direct `Relaxation` logic calls found in core functions.
- A non-core plotting utility explicitly injects Aging path:
  - `C:\Dev\matlab-functions\Switching ver12\plots\plotSwitchingPanelF.m:18`

### External pipeline / cross-module dependencies
- `Switching_main` loads whole repo path and calls multiple functions outside `Switching ver12`.
  - `C:\Dev\matlab-functions\Switching ver12\main\Switching_main.m:7`
- `processFilesSwitching` directly calls `resolve_norm_indices` (implemented in `General ver2`).
  - `C:\Dev\matlab-functions\Switching ver12\main\processFilesSwitching.m:393`

## Determinism assessment
1. `processFilesSwitching` is deterministic for fixed inputs/parameters.
2. `analyzeSwitchingStability` is not strictly deterministic in `stateMethod="cluster"` because `kmeans` uses random initialization without fixed RNG seed.
   - `C:\Dev\matlab-functions\Switching ver12\main\analyzeSwitchingStability.m:268`
3. Main amp-temp branch can depend on latest run discovery from filesystem state (`run_*` timestamp ordering), so output can change without raw input changes.
   - `C:\Dev\matlab-functions\Switching ver12\plots\plotAmpTempSwitchingMap_switchCh.m:723-735`

## Risks to physical validity
1. Multiple fixed denoising/outlier rules can suppress or reshape real switching edges and amplitudes.
2. Conditioning exclusion and robust clipping are partly hardcoded, so reported P2P amplitude is method-dependent.
3. Folder-name parsing drives pulse geometry and state mode; misnamed folders can produce physically wrong timing/state interpretation.

## Final verdict
`CAN_BE_CANONICAL_ENGINE = NO`

### Exact blocking issues
1. Precomputed-data dependency is reachable from main flow (amp-temp map branch reads `results/.../tables/*.csv`).
2. Physics-affecting preprocessing is not fully controlled or externally parameterized (`skipFirstSteps=1`, fixed global clamp, fixed robust thresholds, hardcoded baseline handling).
3. Determinism is not guaranteed in all supported modes (`cluster` mode uses non-seeded `kmeans`; latest-run selection depends on mutable run folders).
4. Engine is not self-contained within `Switching ver12` (cross-module calls into `General ver2`; additional ver12 utilities hook Aging/results pipelines).
