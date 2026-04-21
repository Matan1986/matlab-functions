BLOCK: switching_xx
LAYER: working

STATE:
- canonical_ready: PARTIAL
- observable: P2P_percent
- entrypoint: run_xx_switching_map_xy_reuse_strict.m

VALIDATION:
- produces stable switching maps ✔
- consistent with XY structure ✔

LIMITATIONS:
- implementation uses reuse/strict pipeline
- not fully isolated as independent canonical path

NEXT:
- validate independence from XY reuse
- clean entrypoint

LAST_UPDATE: 2026-04