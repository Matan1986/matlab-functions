# DeltaM Sign Convention

## Canonical Definition

**SIGN CONVENTION: `DeltaM = M_noPause - M_pause`**

This convention is enforced in the aging pipeline at the raw DeltaM construction point.

## Physical Reasoning

- `M_noPause` is the reference cooling/background branch.
- `M_pause` is the paused-aging branch.
- `DeltaM` therefore measures the reference-minus-paused response directly.
- Positive/negative values are preserved through downstream processing; sign is not silently flipped.

## Expected Sign Behavior

- **AFM-like channel** (`DeltaM_sharp` near `Tp`):
  - extracted from local dip-window behavior in `DeltaM_sharp = DeltaM - DeltaM_smooth`
  - reported with the same sign convention as `DeltaM`
- **FM-like channel**:
  - derivative method uses `FM_step_raw = median(right) - median(left)`
  - FM sign is interpreted directly from baseline ordering around `Tp`

## Pipeline Consistency

- Raw DeltaM computation: `Aging/analyzeAgingMemory.m`
- DeltaM propagation: `Aging/computeDeltaM.m`, `Aging/pipeline/stage3_computeDeltaM.m`
- Smoothing/intermediates: `Aging/models/analyzeAFM_FM_components.m`
- Derivative FM extraction: `Aging/models/analyzeAFM_FM_derivative.m`

The audit table is exported to:

- `tables/aging/deltaM_definition_audit.csv`

## Data Examples (MG119 60min)

From `tables/aging/deltaM_sign_behavior.csv`:

- Mean dip-region DeltaM across `Tp`: `3.9779129489e-08`
- Mean plateau-region DeltaM across `Tp`: `-4.56135496292e-07`
- Mean FM step (`right-left`) across `Tp`: `8.99890656219e-07`

These values are direct outputs of the canonical convention above.

## Fixes Applied

- Canonicalized raw DeltaM definition in `Aging/analyzeAgingMemory.m` to `M_noPause - M_pause`.
- Added inline annotation at definition line:
  - `SIGN CONVENTION: DeltaM = M_noPause - M_pause`
- Set default config convention in `Aging/pipeline/agingConfig.m` to `noMinusPause`.
- Updated aging execution scripts to use `noMinusPause`.
- Removed summary plotting sign hack (`abs(FM)`) from derivative summary script.
- Removed silent sign flips in stage4 canonical clock path.

## Final Confirmation

`SIGN_CONVENTION_UNIFIED = YES`
