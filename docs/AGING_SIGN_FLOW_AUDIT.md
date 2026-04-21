# Aging Sign Flow Audit

Scope: `Aging/**/*.m`  
Focus: operations that modify, ignore, or replace sign for `DeltaM`, `step`, `dip/AFM`, or `FM`.

## Exact Sign-Operation Table

| file_path | line_number | code_snippet | variable_affected | operation_type | stage | IS_SIGN_DESTROYED | PURPOSE | CLASSIFICATION |
|---|---:|---|---|---|---|---|---|---|
| `Aging/analyzeAgingMemory.m` | 32 | `dM = M_no_i - M_pa_i;` | DeltaM | definition branch | stage3 source | NO | Signed DeltaM option (`noMinusPause`) | METRIC DEFINITION (IMPORTANT) |
| `Aging/analyzeAgingMemory.m` | 36 | `dM = M_pa_i - M_no_i;` | DeltaM | definition branch | stage3 source | NO | Signed DeltaM option (`pauseMinusNo`) | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/analyzeAFM_FM_components.m` | 170 | `dM_sharp = dM - dM_smooth;` | dip/AFM channel (`DeltaM_sharp`) | residual decomposition | model/stage4 | NO | Preserve signed dip residual | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/analyzeAFM_FM_components.m` | 203 | `y = max(0, dM_sharp);` | AFM area integrand | half-wave rectification | model/stage4 | YES | Convert AFM area metric to positive-only contribution | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/analyzeAFM_FM_components.m` | 294 | `pauseRuns(i).FM_step_raw = computeFMFromBases(baselineOut.baseL, baselineOut.baseR, fmConvention);` | FM | convention mapping | model/stage4 | NO | Keep FM signed using configured orientation | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/analyzeAFM_FM_components.m` | 520 | `pauseRuns(i).FM_step_raw = computeFMFromBases(FM_low, FM_high, fmConvention);` | FM | convention mapping | model/stage4 | NO | Keep FM signed using configured orientation | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/analyzeAFM_FM_derivative.m` | 106 | `result.FM_step_raw = computeFMFromBases(baseL, baseR, cfg.FMConvention);` | FM | convention mapping | derivative model/stage4 | NO | Signed FM from `baseL/baseR` under selected convention | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/stage4_analyzeAFM_FM.m` | 112 | `run.FM_abs = abs(run.FM_signed);` | FM | abs | stage4 | YES | Export/store FM magnitude observable alongside signed FM | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/stage6_extractMetrics.m` | 102 | `AFMvec(i) = abs(state.pauseRuns(i).AFM_extrema_smoothed);` | AFM | abs | stage6 | YES | Build magnitude-only AFM vector for extrema-smoothed path | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/stage6_extractMetrics.m` | 132 | `Y_AFM(i) = abs(state.pauseRuns(i).AFM_extrema_smoothed);` | AFM | abs | stage6 | YES | Plot/export AFM as magnitude in extrema-smoothed summary | VISUALIZATION ONLY |
| `Aging/analysis/debugAgingStage4.m` | 323 | `y = max(0, -dMwin);` | dip/AFM diagnostic | negate + rectification | diagnostics | YES | Compute positive dip area in debug diagnostics | VISUALIZATION ONLY |
| `Aging/models/fitFMstep_plus_GaussianDip.m` | 137 | `Adip  = abs(p(5));` | AFM dip amplitude | abs parameterization | fit model/stage5 | YES | Force dip amplitude non-negative; dip sign encoded separately by leading minus in model | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/fitFMstep_plus_GaussianDip.m` | 144 | `dip  = -Adip*exp(...)` | dip | forced negative model sign | fit model/stage5 | YES | Enforce dip as negative contribution in model function | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/fitFMstep_plus_GaussianDip.m` | 157 | `pauseRuns(i).FM_E = sqrt(mean(stepAC.^2,'omitnan'));` | FM | RMS magnitude | fit model/stage5 | YES | Magnitude-only FM energy metric | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/fitFMstep_plus_GaussianDip.m` | 158 | `pauseRuns(i).Dip_E = sqrt(mean(dipWin.^2,'omitnan'));` | AFM/dip | RMS magnitude | fit model/stage5 | YES | Magnitude-only dip energy metric | METRIC DEFINITION (IMPORTANT) |
| `Aging/fitAFM_FM_MeanField_and_DipLorentzian.m` | 158 | `Ad0 = abs(ymin);` | AFM dip amplitude | abs initialization | fit model | YES | Seed dip depth as positive magnitude for constrained dip model | PURELY TECHNICAL (OK) |
| `Aging/diagnostics/diagnose_FM_sign_stability.m` | 61 | `FM_abs = abs(FM_signed);` | FM | abs | diagnostics | YES | Compare signed vs magnitude FM stability in diagnostics output | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/reconstructSwitchingAmplitude.m` | 101 | `dip_mag = abs(dip_signal);` | dip/AFM | abs | stage7 reconstruction | YES | Convert dip signal to magnitude for AFM reconstruction metric | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/reconstructSwitchingAmplitude.m` | 130 | `F_raw_mag = abs(F_raw_signed);` | FM | abs | stage7 reconstruction | YES | Build FM magnitude metric from signed FM | METRIC DEFINITION (IMPORTANT) |
| `Aging/models/reconstructSwitchingAmplitude.m` | 150 | `F_raw_mag = abs(F_raw_signed);` | FM | abs | stage7 reconstruction | YES | Same as above in alternate FM source branch | METRIC DEFINITION (IMPORTANT) |
| `Aging/analysis/aging_shape_collapse_analysis.m` | 140 | `amplitudes = max(abs(DeltaM), [], 1);` | DeltaM | abs + max normalization | analysis | YES | Shape-collapse normalization intentionally removes global sign/amplitude | METRIC DEFINITION (IMPORTANT) |
| `Aging/plots/plotAgingMemory_AFM_vs_FM.m` | 73 | `AFM_norm = max(abs(AFM_val(validAFM)));` | AFM | abs normalization | plotting | YES | Normalize AFM curves by magnitude for overlay comparability | VISUALIZATION ONLY |
| `Aging/plots/plotAgingMemory_AFM_vs_FM.m` | 81 | `FM_norm = max(abs(FM_step(validFM)));` | FM | abs normalization | plotting | YES | Normalize FM curves by magnitude for overlay comparability | VISUALIZATION ONLY |
| `Aging/utils/construct_canonical_clock.m` | 188 | `clock.absolute_value = abs(half_val);` | dip/FM clock outputs | abs | canonical-clock utility | YES | Store absolute companion clock value | METRIC DEFINITION (IMPORTANT) |
| `Aging/utils/construct_canonical_clock.m` | 208 | `clock.absolute_value = abs(consensus_val);` | dip/FM clock outputs | abs | canonical-clock utility | YES | Store absolute companion clock value | METRIC DEFINITION (IMPORTANT) |
| `Aging/utils/construct_canonical_clock.m` | 229 | `clock.absolute_value = abs(direct_val);` | dip/FM clock outputs | abs | canonical-clock utility | YES | Store absolute companion clock value | METRIC DEFINITION (IMPORTANT) |
| `Aging/utils/construct_canonical_clock.m` | 246 | `clock.value = abs(clock.value);` | dip/FM clock outputs | abs (mode switch) | canonical-clock utility | YES | Explicit sign removal when `sign_handling='absolute'` | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/stage7_reconstructSwitching.m` | 173 | `safeCorr(Rsw_loc, abs(dA));` | AFM-like switching amplitude (`dA`) | abs | stage7 | YES | Correlation vs magnitude of coefficient change | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/stage7_reconstructSwitching.m` | 174 | `safeCorr(Rsw_loc, abs(dB));` | FM-like switching amplitude (`dB`) | abs | stage7 | YES | Correlation vs magnitude of coefficient change | METRIC DEFINITION (IMPORTANT) |
| `Aging/pipeline/agingConfig.m` | 192 | `cfg.Rsw_15mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |
| `Aging/pipeline/agingConfig.m` | 210 | `cfg.Rsw_20mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |
| `Aging/pipeline/agingConfig.m` | 228 | `cfg.Rsw_25mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |
| `Aging/pipeline/agingConfig.m` | 246 | `cfg.Rsw_30mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |
| `Aging/pipeline/agingConfig.m` | 264 | `cfg.Rsw_35mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |
| `Aging/pipeline/agingConfig.m` | 282 | `cfg.Rsw_45mA = abs([ ... ])` | switching reference `Rsw` | abs | config | YES | Hard-code positive-magnitude switching references | POTENTIAL BUG |

## Classification Notes

- **PURELY TECHNICAL (OK)**: optimization seeds or numeric helper transforms that do not define exported physical sign by themselves (example: `Ad0 = abs(ymin)` initialization).
- **METRIC DEFINITION (IMPORTANT)**: operations defining stored observables (e.g., `FM_abs`, `AFMvec = abs(...)`, RMS energies, collapse amplitudes).
- **VISUALIZATION ONLY**: operations only used for plotting overlays or debug figures.
- **POTENTIAL BUG**: sign removal in configuration/source constants where scientific sign may be physically meaningful and not explicitly justified by convention docs.

## Sign Flow Trace By Variable

### DeltaM

- **Defined** in `Aging/analyzeAgingMemory.m` by `cfg.subtractOrder` branch:
  - `M_noPause - M_pause` or `M_pause - M_noPause`.
- **Preserved** through `stage3_computeDeltaM` and decomposition inputs (`run.DeltaM`).
- **Sign removed/replaced** in analysis-normalization paths:
  - `aging_shape_collapse_analysis.m` uses `max(abs(DeltaM))` for amplitude normalization.
- **Conclusion**: signed DeltaM is preserved in core pipeline; some downstream analysis modules intentionally convert to magnitude-normalized form.

### step_component

- **Defined** from left/right baselines in stage4 models (`analyzeAFM_FM_components`, `analyzeAFM_FM_derivative`) and stored as smooth/FM background.
- **Preserved** as signed baseline/background channel.
- **Sign removed/replaced**: not directly; derived FM magnitudes (`FM_abs`, `FM_E`) remove sign in later stages.

### dip_component

- **Defined** as residual `dM - dM_smooth` (`DeltaM_sharp`) in `analyzeAFM_FM_components.m`.
- **Preserved** as signed channel in decomposition.
- **Sign removed/replaced**:
  - AFM area uses `max(0, dM_sharp)` (drops negative side).
  - fit-model parameterization uses nonnegative amplitude + explicit negative dip model term.
  - RMS/absolute diagnostics convert dip to magnitude metrics (`Dip_E`, `dip_mag`, etc.).

### FM

- **Defined** signed via configured convention (`leftMinusRight` or `rightMinusLeft`) in both stage4 computation paths.
- **Preserved** in `FM_step_raw`, `FM_signed`.
- **Sign removed/replaced**:
  - `FM_abs = abs(FM_signed)` in stage4.
  - magnitude usage in stage6/analysis/diagnostics (`FM_abs`, RMS, normalization).
- **Conclusion**: FM sign exists and is preserved in signed fields, but many exported/analysis observables intentionally use magnitude.

### AFM

- **Defined** via dip residual/channel and dip metrics.
- **Preserved** in signed channels (`DeltaM_sharp`, signed dip windows).
- **Sign removed/replaced** in several AFM metrics:
  - `max(0, dM_sharp)` area metric.
  - `abs(AFM_extrema_smoothed)` in stage6 extrema-smoothed summaries.
  - `Dip_E = sqrt(mean(dipWin.^2))`, `dip_mag = abs(dip_signal)` in reconstruction/fit workflows.

## Exact Answers

1. **AFM sign is preserved** in decomposition channels (`DeltaM_sharp`) through stage4 computation, and **converted to magnitude** in AFM area/RMS/extrema-magnitude paths (stage4 metric extraction, stage6 extrema-smoothed summary, stage5/7 fit-reconstruction metrics).
2. **FM sign is not preserved everywhere**: it is preserved in `FM_step_raw`/`FM_signed`, and explicitly converted to magnitude in `FM_abs` and other magnitude-only analyses.
3. **DeltaM sign is preserved end-to-end in core pipeline**, but some downstream analysis modules intentionally normalize by `abs(DeltaM)` (shape-collapse workflows).
4. **The places where sign is removed are exactly the rows with `IS_SIGN_DESTROYED = YES` in the table above.**

## Sign-Flow Statement

Sign of AFM/FM is physically meaningful in stage3/stage4 signed channels and convention-aware FM computation, and intentionally removed in stage4 magnitude companions, stage6 extrema-smoothed summaries, and downstream analysis/reconstruction modules that use magnitude-only observables.
