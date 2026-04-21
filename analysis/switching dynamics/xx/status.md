BLOCK: dynamics_xx
LAYER: exploration

STATE:
- canonical_ready: NO
- best_current:
    - cm_drift_abs
    - slopeRMS
    - sw_drift_abs

VALIDATION:
- common-mode and difference-like observables are distinct ✔
- no single observable dominates ✔
- decisive test inconclusive ✔

KEY_RESULT:
- XX dynamics is multi-component

LIMITATIONS:
- no scalar observable captures dynamics fully
- observables partially overlap but are not redundant

NEXT:
- test 2D observable (CM + difference)
- investigate state-resolved dynamics

LAST_UPDATE: 2026-04