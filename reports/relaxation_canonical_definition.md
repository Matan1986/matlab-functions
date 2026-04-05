# Relaxation Canonical Definition (Physical)

Date: 2026-03-30 (Asia/Jerusalem)

## Scope and intent
This document defines a physically valid canonical relaxation measurement for continuous measurements where no explicit experimental delay is provided.

Given one trace with sorted samples `(t_i, H_i, M_i)` for `i=1..N`, define one and only one canonical observable `R_relax_canonical(T)`.

## 1. Physical t0 definition
### 1.1 Transient score
Use derivatives on the measured time axis:
- `Hdot_i = dH/dt`
- `Mddot_i = d2M/dt2`

Define tail set `I_tail` as the last `ceil(0.2*N)` points and robust scales:
- `sigma_Hdot = 1.4826 * MAD(Hdot on I_tail)`
- `sigma_Mddot = 1.4826 * MAD(Mddot on I_tail)`

Define normalized transient score:
- `Q_i = max( |Hdot_i|/(sigma_Hdot + eps), |Mddot_i|/(sigma_Mddot + eps) )`

### 1.2 Onset rule
Let `w = max(5, ceil(0.05*N))`.

Define physical onset `t0` as:
- `t0 = min t_i` such that both conditions hold on `i..i+w-1`:
1. `median(Q_i..Q_{i+w-1}) <= 3`
2. `sign(dM/dt)` is constant (single-direction relaxation)

Interpretation: `t0` is the first sustained point where field-switch and settling transients have statistically disappeared.

## 2. Physical window definition
Define `tau_i = t_i - t0` for all `t_i > t0`.

### 2.1 Start rule
Define
- `tau_min = median(diff(t_j))` using the first `w` post-`t0` points.
- `t_start = t0 + tau_min`

This avoids the log singularity at `tau=0` while staying tied to physical onset.

### 2.2 End rule
Compute local relaxation rate on post-`t0` points:
- `R_i = -dM/dln(tau)` (local robust slope on moving window `w`).

Define tail noise in rate space:
- `sigma_R_tail = 1.4826 * MAD(R_i on last 20% of post-t0 points)`.

Define window end:
- `t_end = max t_i` such that
1. `|median(R_{i-w+1}..R_i)| >= 3 * sigma_R_tail`
2. `sign(R_{i-w+1}..R_i) = sign(median(R_post_t0))`

Interpretation: keep only the segment where relaxation signal is above tail noise and sign-coherent.

## 3. Canonical observable (single observable)
### Definition
For `tau_i in [tau_min, t_end - t0]`, fit
- `M_i = b0 + b1*ln(tau_i)`
using robust Huber regression.

Define
- `R_relax_canonical(T) = -b1`

Units: magnetization units per natural log time decade.

### Why this observable
- It is directly the mean magnetic viscosity (`-dM/dln(tau)`) in the physical relaxation regime.
- It avoids mixed model families (no simultaneous `tau`/`n` vs `S` ambiguity).
- Robust fitting reduces sensitivity to isolated spikes and light preprocessing differences.

## 4. Consistency and reproducibility
This definition is self-consistent because:
- `t0`, window, and observable all use the same physical clock `tau = t - t0`.
- Start and end are signal-defined (not arbitrary index cuts).
- Thresholding is noise-normalized (`MAD`) and uses a standard significance criterion (`3-sigma`) instead of absolute fixed magnitudes.
- The same rule can be applied temperature-by-temperature without retuning absolute constants.

## 5. Expected failure modes
1. No clean low-transient regime
- If field ramp artifacts persist through most of the trace, `t0` may be undefined or too late.

2. Too few post-`t0` points
- Sparse sampling can make local derivative estimates unstable.

3. Strong non-monotonic physics inside relaxation interval
- If relaxation genuinely changes sign or contains multiple competing regimes, single-slope `R_relax_canonical` is not sufficient.

4. Noise floor not stationary
- If late-time noise is nonstationary, `sigma_R_tail` may misestimate end-of-window.

5. Missing or unreliable field channel
- When `H(t)` is unavailable, onset confidence decreases because field-settling evidence is reduced.

## Required verdicts
- T0_DEFINITION_PHYSICAL = YES
- WINDOW_DEFINITION_PHYSICAL = YES
- OBSERVABLE_WELL_DEFINED = YES
- OBSERVABLE_PHYSICAL = YES
- DEFINITION_SELF_CONSISTENT = YES
- READY_FOR_IMPLEMENTATION = YES
