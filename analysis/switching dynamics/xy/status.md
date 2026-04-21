BLOCK: dynamics_xy
LAYER: working

STATE:
- canonical_ready: PARTIAL
- observable: slopeRMS
- entrypoint: run_xy_drift_map.m

VALIDATION:
- produces coherent drift maps ✔
- stable across temperatures ✔
- clear structure in maps ✔

LIMITATIONS:
- not yet formally promoted to canonical
- no decisive test vs alternative observables

NEXT:
- validate robustness across datasets
- test against alternative definitions

LAST_UPDATE: 2026-04