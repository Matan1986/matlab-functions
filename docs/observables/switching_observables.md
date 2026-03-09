# Switching Observables

## Overview

The Switching experiment measures:

`S(T,I) = ΔR/R`

as a function of temperature `T` and pulse current `I`.

Current analysis indicates that the switching map is well described by three dominant coordinates.

## Coordinates

### S_peak

Definition:

`S_peak(T) = max_I S(T,I)`

Physical meaning:

Represents the overall strength of switching at temperature `T`.

Units:

percent (`%`)

### I_peak

Definition:

`I_peak(T) = argmax_I S(T,I)`

Physical meaning:

Characteristic current scale of switching.

Interpretation:

Often related to switching threshold or effective torque strength.

Units:

mA

### halfwidth_diff_norm

Definition:

Let:

`w_L = I_peak - I_left`

`w_R = I_right - I_peak`

Then:

`halfwidth_diff_norm = (w_R - w_L) / (w_R + w_L)`

Physical meaning:

Measures asymmetry of the switching peak around `I_peak`.

Interpretation:

- `0` -> symmetric peak
- positive -> broader high-current side
- negative -> broader low-current side

Units:

dimensionless

## Observables

Observables include the coordinates above plus additional physical descriptors.

### width_I

Definition:

`width_I = w_L + w_R`

Physical meaning:

Represents the spread of switching currents.

Interpretation:

May reflect the distribution of local switching thresholds or energy barriers.

Units:

mA

Role in analysis:

`width_I` is retained as an observable even though it is not a primary coordinate of the switching map.

### asym

Definition:

`asym(T) = area_right / area_left`

where left/right areas are integrated around `I_peak` on the low-current and high-current sides of the switching profile.

Physical meaning:

Area-based peak asymmetry proxy around `I_peak`.

Units:

unitless

## SVD Decomposition and Observable Relations

Switching analysis also stores SVD diagnostics for:

`S(T,I) = U Σ V^T`

including singular values, temperature modes (`U`), and current modes (`V`).

Observable-mode relationship diagnostics are generated in the Switching safe-layer outputs (for example mode-observable correlation plots and mode-coefficient trend plots).

Primary output location:

`results/switching/alignment_audit/`

Run-scoped observable export location:

`results/switching/runs/<run_id>/observables.csv`
