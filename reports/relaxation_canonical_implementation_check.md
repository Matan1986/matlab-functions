# Relaxation Canonical Implementation Check

## 1) Subset used
- script: C:\Dev\matlab-functions\run_relaxation_canonical_implementation_check.m
- dataDir: L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM
- total traces loaded: 19, finite-valid candidates: 19, selected subset: 5
- selection rule: nearest traces to temperature quantiles q = [0.05, 0.30, 0.50, 0.70, 0.95] with uniqueness preservation
  - MG_119_14p31mg_relaxation_5K_afterFC1T.dat | T=5.000 K
  - MG_119_14p31mg_relaxation_13K_afterFC1T.dat | T=13.000 K
  - MG_119_14p31mg_relaxation_21K_afterFC1T.dat | T=21.000 K
  - MG_119_14p31mg_relaxation_29K_afterFC1T.dat | T=29.000 K
  - MG_119_14p31mg_relaxation_37K_afterFC1T.dat | T=37.000 K

## 2) Exact implementation of canonical rules
- transient score Q_i: max(|dH/dt|/(sigma_Hdot+eps), |d2M/dt2|/(sigma_Mddot+eps)), with sigma values from 1.4826*MAD on last 20% points
- t0 rule: first index i with median(Q_i..Q_{i+w-1}) <= 3 and sign(dM/dt) not mixed in i..i+w-1; w=max(5,ceil(0.05*N))
- start rule: tau_min = median(diff(first w post-t0 points)); t_start = t0 + tau_min
- end rule: compute local R_i = -dM/dln(tau) using rolling Huber robust linear slope over size w in M vs ln(tau);
  then t_end is max index with |median(last up-to-w R)| >= 3*sigma_R_tail and sign coherence with median(R_post_t0)
- observable: R_relax_canonical = -b1 from Huber fit M = b0 + b1*ln(tau) on tau in [tau_min, t_end - t0]

### Explicit ambiguities documented
- Sign constancy in t0 rule interpreted as no sign mixture (+/-) within persistence window; zeros allowed.
- When fewer than w local-rate points are available for the end rule median, the available prefix is used and flagged as limited_support.

## 3) Successful traces (examples)
- none (no trace reached full canonical support)

## 4) Problematic traces (examples)
- MG_119_14p31mg_relaxation_5K_afterFC1T.dat | T=5.000 K | status=FAILED | cutoff=NO_T0_FOUND | note=no sustained low-transient sign-coherent window
- MG_119_14p31mg_relaxation_13K_afterFC1T.dat | T=13.000 K | status=FAILED | cutoff=NO_T0_FOUND | note=no sustained low-transient sign-coherent window
- MG_119_14p31mg_relaxation_21K_afterFC1T.dat | T=21.000 K | status=FAILED | cutoff=NO_T0_FOUND | note=no sustained low-transient sign-coherent window

## 5) Physics matching check
- t0 qualitative check: encoded per trace as t0_after_transient in notes
- early-transient avoidance check: encoded per trace as window_avoids_early
- end near noise-floor check: encoded per trace as end_near_noise_floor and snr_end
- observable smoothness in retained window: encoded per trace as observable_smooth

## 6) Failure mode checks
- noisy derivative/curvature estimates: 0 traces flagged
- unstable t0 detection: 5 traces flagged
- ambiguous SNR threshold crossing: 0 traces flagged
- empty/too-short windows: 0 traces flagged
- large boundary variability indicators: 0 traces flagged

## Verdicts
- CANONICAL_DEFINITION_IMPLEMENTABLE = false
- T0_DETECTION_STABLE = false
- WINDOW_DETECTION_STABLE = false
- OBSERVABLE_IMPLEMENTATION_STABLE = false
- SMALL_REFINEMENT_REQUIRED = true
- SAFE_FOR_BROADER_ROLLOUT = false

## Rollout safety judgment
- Broader rollout is not yet safe without small implementation clarifications documented above.
