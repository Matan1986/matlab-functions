# Switching Physics Audit Spec

## Purpose

Define a deterministic audit layer on top of existing switching signal products, so we can classify outcomes as:

- `PHYSICS_ROBUST`
- `BASELINE_DRIVEN`
- `NORMALIZATION_SENSITIVE`
- `SEQUENCE_UNSTABLE`
- `SIGN_UNSTABLE`

and decide `artifact vs physics` from audits alone.

## Canonical Physics Model

This spec follows the canonical switching decomposition:

`S(I,T) ~ S_peak(T)*CDF(P_T)(I) + kappa(T)*Phi(x)`

with

`x = (I - I_peak(T)) / w(T)`.

Interpretation:

- `CDF(P_T)` sector = baseline/barrier sector.
- `kappa*Phi` sector = contrast/deformation sector.

## Signal Product Input Contract

| Product | Required fields |
| --- | --- |
| Legacy switching table rows (`processFilesSwitching`) | `sortedValue`, `avg_p2p`, `avg_resall`, `change_pct`, `std_p2p`, `p2p_uncert`, `refBase` |
| Pulse-resolved plateaus (`stored_data{i,6}`) | plateau means per pulse and channel |
| Stability summary (`analyzeSwitchingStability`) | `stateSeparationD`, `stateGapAbs`, `withinRMS`, `driftPerPulseRelToGap`, `driftRangeRelToGap`, `flipErrorRate`, `settleTimeMean`, `stabilityIndex`, `switchAmpMedian` |
| Switching map audit outputs | `switching_alignment_samples.csv`, `switching_alignment_observables_vs_T.csv` |
| Channel identity | first `xy` channel and first `xx` channel from preset labels (`select_preset` / channel labels) |

## Common Constants

| Symbol | Value | Notes |
| --- | --- | --- |
| `DPRIME_MIN` | `3.0` | matches switching channel detection rule |
| `GAP_SIGMA_MIN` | `3.0` | matches switching channel detection rule |
| `STABILITY_INDEX_MIN` | `5.0` | from stability module default |
| `NEAR_DEGENERATE_PEAK_MAX` | `0.05` | from 22K artifact note: `(Smax-S2)/Smax` |
| `SIGN_CONSISTENCY_MIN` | `0.80` | robust majority sign rule |
| `SEQ_CHANNEL_CONSISTENCY_MIN` | `0.80` | sequence reproducibility floor |

## Audit 1: Settling-Aware Window

### Inputs

- `settleTimeMean`, `slopeRMS`, `stateGapAbs`, `stabilityIndex`
- `delay_between_pulses_ms`, `safety_margin_percent`

### Metrics and thresholds

| Metric | Formula | Pass threshold |
| --- | --- | --- |
| `plateau_window_ms` | `delay_between_pulses_ms*(1-2*safety_margin_percent/100)` | computed |
| `settle_ratio` | `median(settleTimeMean/plateau_window_ms)` | `<= 0.35` |
| `post_settle_slope_ratio` | `median((slopeRMS*plateau_window_ms)/max(stateGapAbs,eps))` | `<= 0.10` |
| `stable_plateau_fraction` | `mean(stabilityIndex >= STABILITY_INDEX_MIN)` | `>= 0.80` |

### Verdict contribution

- If any threshold fails: mark `A1_FAIL = 1` (feeds `SEQUENCE_UNSTABLE`).

## Audit 2: Sequence Stability

### Inputs

- Stability summaries for `skipFirstPlateaus in {0,1,2}`
- `switchAmpMedian`, `driftPerPulseRelToGap`, `flipErrorRate`
- switching-channel decision per skip

### Metrics and thresholds

| Metric | Formula | Pass threshold |
| --- | --- | --- |
| `amp_cv_skip` | CV of `switchAmpMedian` across skip settings (matched dep/channel) | `<= 0.25` |
| `channel_consistency` | fraction of dep points where switching channel agrees across skip settings | `>= SEQ_CHANNEL_CONSISTENCY_MIN` |
| `drift_rel_med` | `median(driftPerPulseRelToGap)` | `<= 0.10` |
| `flip_error_med` | `median(flipErrorRate)` | `<= 0.10` |

### Verdict contribution

- If any threshold fails: `A2_FAIL = 1` and emit `SEQUENCE_UNSTABLE`.

## Audit 3: Baseline vs Contrast

### Inputs

- `avg_p2p`, `avg_resall`, `change_pct`, `p2p_uncert`, `refBase`
- optional near-degenerate peak table from peak-jump audit

### Metrics and thresholds

| Metric | Formula | Pass threshold |
| --- | --- | --- |
| `contrast_snr` | `median(abs(avg_p2p)/max(p2p_uncert,eps))` | `>= 3.0` |
| `baseline_dominance` | `std(avg_resall)/max(std(avg_p2p),eps)` | `<= 3.0` |
| `normalization_leverage` | `abs(corr(change_pct, refBase))` | `<= 0.70` |
| `near_degenerate_peak_fraction` | fraction with `(Smax-S2)/Smax < NEAR_DEGENERATE_PEAK_MAX` | `<= 0.20` |

### Verdict contribution

- Fail if at least 2 metrics fail.
- If fail: emit `BASELINE_DRIVEN`.

## Audit 4: XY vs XX Coupling

### Inputs

- Matched `xy` and `xx` channel switching amplitudes vs dep value (same metric family as Audit 3)
- LOOCV linear fits

### Metrics and thresholds

| Metric | Formula | XX-drives condition |
| --- | --- | --- |
| `corr_xy_xx` | `corr(S_xy, S_xx)` | `abs(corr_xy_xx) >= 0.75` |
| `delta_rmse_xx` | `1 - RMSE_LOOCV(xy~xx)/RMSE_LOOCV(xy~const)` | `>= 0.35` |
| `xx_slope_sign_consistency` | majority sign consistency of LOOCV slope | `>= SIGN_CONSISTENCY_MIN` |

### Verdict contribution

- Set `XX_DRIVES = 1` if all three conditions are true.
- If `XX_DRIVES = 1` and Audit 3 failed, strengthen `BASELINE_DRIVEN` classification.

## Audit 5: Normalization Impact

### Inputs

- Recomputed observables using:
  - `metricType = P2P_percent`
  - `metricType = meanP2P`
  - `metricType = medianAbs`
- Audit outcomes per normalization mode

### Metrics and thresholds

| Metric | Formula | Pass threshold |
| --- | --- | --- |
| `ipeak_agreement` | fraction of T where `I_peak` bin matches between `P2P_percent` and `meanP2P` | `>= 0.85` |
| `speak_profile_corr` | `corr(S_peak_percent, S_peak_raw)` | `>= 0.90` |
| `verdict_agreement` | fraction of identical mode-level decisions for sequence/baseline/sign | `= 1.00` |

### Verdict contribution

- If any threshold fails: emit `NORMALIZATION_SENSITIVE`.

## Audit 6: Sign Stability

### Inputs

- Pulse-to-pulse `p2p_raw = diff(intervel_avg_res)` per dep/channel
- Legacy sign rule (third pulse delta sign)
- `avg_p2p`, `p2p_uncert`

### Metrics and thresholds

| Metric | Formula | Pass threshold |
| --- | --- | --- |
| `rule_agreement` | modal agreement among sign rules: third-pulse, median-all, block-jump/late-minus-early | `>= SIGN_CONSISTENCY_MIN` |
| `sign_margin` | `median(abs(avg_p2p)/max(p2p_uncert,eps))` | `>= 2.0` |
| `sign_flip_rate_dep` | fraction of adjacent dep points with sign flip | `<= 0.20` |

### Verdict contribution

- If any threshold fails: emit `SIGN_UNSTABLE`.

## Verdict Logic

## Step 1: Compute boolean fails

- `A1_FAIL` from Audit 1
- `A2_FAIL` from Audit 2
- `A3_FAIL` from Audit 3
- `A5_FAIL` from Audit 5
- `A6_FAIL` from Audit 6

## Step 2: Emit required non-robust verdicts

- If `A1_FAIL || A2_FAIL`: emit `SEQUENCE_UNSTABLE`
- If `A6_FAIL`: emit `SIGN_UNSTABLE`
- If `A5_FAIL`: emit `NORMALIZATION_SENSITIVE`
- If `A3_FAIL`: emit `BASELINE_DRIVEN`
- If `XX_DRIVES && A3_FAIL`: keep `BASELINE_DRIVEN` (higher confidence tag in report body)

## Step 3: Emit robust verdict

- Emit `PHYSICS_ROBUST` only if none of the non-robust verdicts were emitted.

Equivalent rule:

`PHYSICS_ROBUST <=> not(SEQUENCE_UNSTABLE or SIGN_UNSTABLE or NORMALIZATION_SENSITIVE or BASELINE_DRIVEN)`

## Artifact vs Physics Decision

| Final emitted verdict set | Decision |
| --- | --- |
| `{PHYSICS_ROBUST}` | `PHYSICS` |
| Any set containing `SEQUENCE_UNSTABLE` or `SIGN_UNSTABLE` or `NORMALIZATION_SENSITIVE` or `BASELINE_DRIVEN` | `ARTIFACT` |

## Missing Data Handling (Fail-Safe)

To keep decisions deterministic:

- Missing sequence/settling inputs -> treat as sequence fail (`SEQUENCE_UNSTABLE`)
- Missing baseline/contrast inputs -> treat as baseline fail (`BASELINE_DRIVEN`)
- Missing normalization comparison inputs -> treat as normalization fail (`NORMALIZATION_SENSITIVE`)
- Missing sign inputs -> treat as sign fail (`SIGN_UNSTABLE`)

Therefore `PHYSICS_ROBUST` is only reachable when all six audits are evaluable and passing.
