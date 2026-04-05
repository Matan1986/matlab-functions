# ver12 Step 2.1A - canonical overlay dependency removal

## Scope
Patched only the canonical overlay toggle in:
- `Switching ver12/main/Switching_main.m`

No preprocessing logic changed.
No determinism/kmeans logic changed.
No unrelated plotting cleanup performed.

## Before (proven reachable chain)
Canonical amp-temp branch contained:
- `Switching_main.m:22` -> `showOverlay = true`
- `Switching_main.m:24` -> call `plotAmpTempSwitchingMap_switchCh(...)`
- `plotAmpTempSwitchingMap_switchCh.m:361` -> `if showOverlay` enters loader
- `plotAmpTempSwitchingMap_switchCh.m:362` -> `loadCollapseOverlayObservables(...)`
- loader reads prior run artifacts:
  - `...:704` (`results/switching/runs`)
  - `...:714` (`tables/...csv` candidate)
  - `...:732` (`tables/...csv` candidate)
  - `...:745` (`readtable` on CSV)

## Patch applied
Single-line canonical-path change:
- `Switching ver12/main/Switching_main.m:22`
  - from: `showOverlay = true;`
  - to:   `showOverlay = false;  % Canonical path: disable overlay loading from prior runs/results`

## After (re-trace proof)
- Canonical amp-temp branch still calls `plotAmpTempSwitchingMap_switchCh(...)`.
- But passed `showOverlay=false`.
- Therefore guard at `plotAmpTempSwitchingMap_switchCh.m:361` is false.
- Therefore `loadCollapseOverlayObservables(...)` is not called in canonical path.
- Therefore overlay-side reads of `results/`, `tables/`, and CSV (`readtable`) are not reachable in canonical execution.

## Outputs
- `tables/ver12_overlay_dependency_before.csv`
- `tables/ver12_overlay_dependency_after.csv`
- `tables/ver12_step21a_status.csv`

## Final verdicts
- `OVERLAY_RESULTS_DEPENDENCY_FOUND_BEFORE = YES`
- `OVERLAY_RESULTS_DEPENDENCY_REACHABLE_AFTER = NO`
- `CANONICAL_PATH_RAW_ONLY_FOR_OVERLAY_LAYER = YES`
