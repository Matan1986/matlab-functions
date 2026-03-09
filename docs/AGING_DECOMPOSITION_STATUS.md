# Aging AFM/FM Decomposition Status

## Purpose

This document records the current status and validation results of the AFM/FM decomposition used in the Aging experiment analysis.

It exists so that future development sessions and AI agents understand the validated behavior of the current decomposition pipeline.

---

## Aging Observable

The Aging signal is defined as:

DeltaM(T) = M_pause(T) - M_no_pause(T)

The curves are analyzed using a decomposition:

DeltaM(T) ~ AFM(T) + FM(T)

Where:

AFM-like component:
localized memory dip centered near the pause temperature Tp.

FM-like component:
broad background / step-like contribution.

---

## Decomposition Pipeline

The decomposition is implemented in the Aging pipeline stages:

stage3_computeDeltaM
stage4_analyzeAFM_FM
stage5_fitFMGaussian

Key functions involved include:

Aging/models/analyzeAFM_FM_components.m  
Aging/models/fitFMstep_plus_GaussianDip.m

Metrics extracted include:

AFM metrics:
- Dip_area
- Dip_depth
- Dip_sigma
- Dip_T0
- Tmin

FM metrics:
- FM_E
- FM_abs
- FM_step_mag

---

## Stability Audit

A systematic robustness audit was performed using:

Aging/diagnostics/auditDecompositionStability.m

The audit varied multiple analysis parameters, including:

- smoothing window
- plateau window size
- plateau buffer size
- baseline mode
- right plateau selection
- low-temperature exclusion
- Stage3 filter frame
- fit vs direct metric extraction

The audit was run across all datasets:

3 s
36 s
6 min
60 min

and all pause temperatures Tp.

Outputs were written to:

results/aging/decomposition_stability/

---

## Main Results

The audit produced approximately 450 runs across parameter variations.

Key conclusions:

1. AFM dip metrics are extremely stable.

Dip_area and related AFM metrics show essentially zero variation across parameter settings.

This confirms that the memory dip extraction is robust.

2. FM background is mostly stable.

FM metrics remain stable for most pause temperatures.

3. Known problematic regions:

- Around Tp ~ 18 K the FM component becomes less stable due to overlap between dip and background.
- At very low Tp the FM plateau window may become invalid because the dip approaches the low-temperature boundary.

These cases are automatically flagged by the pipeline diagnostics.

---

## Current Interpretation

The Aging signal is well described by two components:

AFM:
localized memory dip associated with the pause temperature.

FM:
broad background response of the system.

The AFM component is extremely robust.

The FM component is mostly stable but requires care in regions where the dip overlaps with plateau windows.

---

## Implication for Further Work

The AFM/FM decomposition is now considered validated and stable.

Future development can therefore focus on:

- extracting robust Aging observables
- analyzing Switching experiment structure
- testing whether Aging and Switching share common underlying modes.

This document should be updated if the decomposition algorithm or its validation results change.
