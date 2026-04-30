# Switching Phase 4A corrected-old reconstruction readiness and scope lock

Phase 4A is a planning/readiness checkpoint only. This stage does not execute corrected-old replay and does not modify scientific scripts.

## What was checked

- Current anchor is `35ccc92` and present on `HEAD`.
- Switching Phase 3 semantic preflight commit `0a9e0a1` is present in history and treated as committed prerequisite.
- Reconstruction policy markers are present in `reports/switching_corrected_canonical_reconstruction_program.md`:
  - Visualization and inspection requirements section
  - Lessons learned section
  - Readiness rule for machine-readable outputs plus human-inspection material
- Semantic family separation remains mandatory per Switching semantic contract stack.
- Phase 4 replay has not been executed in this stage.

## Why broad Phase 4 replay remains blocked

Broad corrected-old replay is intentionally blocked in Phase 4A. The objective here is scope lock and risk containment, not replay throughput. Governance constraints remain:

- `SAFE_TO_RUN_BROAD_REPLAY=NO`
- `SAFE_TO_RENAME=NO`
- `SAFE_TO_COMPARE_TO_RELAXATION=NO`

These constraints avoid re-introducing mixed-family confusion before a narrow slice is reviewed.

## Recommended first slice

Recommended candidate: `P4A_C01` (Single X-like panel replot with orientation lock).

Why this slice first:

- It is narrow (single panel family, bounded inputs).
- It directly tests common confusion vectors (orientation, axis/range, naming/semantic labeling).
- It can be reviewed with one inspection artifact and one machine-readable output without opening broad replay.

## Required outputs for the next slice (Phase 4B candidate)

For the approved first narrow slice, require:

1. One machine-readable output table documenting exact source artifacts and semantic family labels.
2. One QA PNG inspection panel with explicit:
   - source family
   - semantic family / variant
   - orientation choice
   - axis and range limits
   - display-only transform note (if any)
3. One short report fragment tying panel and table to governance constraints.

## Figure and inspection requirements carried forward

- PNG is default for inspection.
- MATLAB `.fig` is not default and only opt-in if explicitly requested.
- Figures are QA/inspection artifacts first, not manuscript claims.
- Do not silently mix old/corrected-old/canonical residual/geocanon/replay/diagnostic experimental families.
- If a panel looks wrong, check source family, orientation, axis/range, and display transform before interpreting physics.

## Explicit forbidden actions for Phase 4B

- Do not open broad replay in the first slice.
- Do not rename artifacts from alias/rename plan.
- Do not compare to Relaxation as a scope expansion.
- Do not treat diagnostic/experimental PTCDF outputs as corrected-old authority.
- Do not promote QA figures to manuscript-authoritative evidence without separate gate approval.

## Phase 4A verdict

- Scope lock complete.
- First narrow slice can be opened under constrained outputs and inspection requirements.
- Broad replay remains blocked pending Phase 4B execution and review outcomes.
