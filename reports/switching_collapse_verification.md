# switching_collapse_verification

## Sources used (strict)
- Code:
  - `Switching/analysis/run_switching_canonical.m`
  - Directly called files:
    - `Aging/utils/createRunContext.m`
    - `Switching ver12/parsing/extract_dep_type_from_folder.m`
    - `Switching ver12/getFileListSwitching.m`
    - `Switching ver12/parsing/extractPulseSchemeFromFolder.m`
    - `Switching ver12/parsing/extract_delay_between_pulses_from_name.m`
    - `General ver2/resolve_preset.m`
    - `General ver2/select_preset.m`
    - `Switching ver12/main/processFilesSwitching.m`
    - `Switching ver12/main/analyzeSwitchingStability.m`
    - `Switching ver12/resolveNegP2P.m`
- Canonical artifacts (latest trusted switching canonical runs):
  - `run_2026_04_03_091018_switching_canonical`
  - `run_2026_04_03_000147_switching_canonical`
  - `run_2026_04_03_000008_switching_canonical`
  - `run_2026_04_02_234844_switching_canonical`
- Trust evidence used:
  - all above runs: `execution_status.csv` has `WRITE_SUCCESS=YES`
  - artifact hashes match exactly for `switching_canonical_S_long.csv`, `switching_canonical_phi1.csv`, `switching_canonical_observables.csv`, `switching_canonical_validation.csv`

## 1) Exact collapse implementation (code-backed)
- `Svec` source in canonical script:
  - `run_switching_canonical.m:227` -> `Svec = metricTbl(:, 4);`
- Upstream definition of column 4:
  - `processFilesSwitching.m:552-557` row template uses `change_pct(k)` in column 4
  - `processFilesSwitching.m:495` repeated mode: `change_pct = (blockJumpMetric/refBase)*100`
  - `processFilesSwitching.m:498` alternating mode: `change_pct = (avg_p2p/refBase)*100`
- Canonical decomposition:
  - `run_switching_canonical.m:355` -> `residual = Smap - Scdf`
  - `run_switching_canonical.m:359-361` -> `[U,Sigma,V]=svd(Rfill,'econ'); phi1=V(:,1); kappa1=U(:,1)*Sigma(1,1)`
  - `run_switching_canonical.m:378` -> `Sfull = Scdf + kappa1 * phi1'`

## 2) Hidden normalization check
- I-axis:
  - No code snippet showing `(I-I0)` or `/Iscale` for collapse coordinates in canonical script.
  - Evidence: `run_switching_canonical.m:246,266-268,291,321`
- S-axis beyond `change_pct`:
  - Present inside CDF branch:
    - `run_switching_canonical.m:323` -> `cdfRaw = svalid ./ Speak(it)`
    - `run_switching_canonical.m:331` -> `cdfRaw = cdfRaw ./ cdfRaw(end)`
- Therefore: `SCALE_S_CHANGE_PCT = PARTIAL` in status file (upstream metric is `change_pct`, plus additional CDF normalization step exists).

## 3) Width presence anywhere in canonical path
- Width terms appear in directly called helper code:
  - `getFileListSwitching.m:14` (`PulseWidth_ms` metadata field)
  - `getFileListSwitching.m:23-24` (`ms` parse)
  - `getFileListSwitching.m:41-42` (`case 'Width'` parsing branch)
- Canonical script input folder filter is Temp-only:
  - `run_switching_canonical.m:148-149` (`isTempDep`, then filter)
- Therefore status: `WIDTH_USED_NO = PARTIAL` (width code exists in direct-called path, but canonical script filters to Temp Dep folders).

## 4) Exact Phi1 construction (step-by-step)
1. `residual = Smap - Scdf` (`run_switching_canonical.m:355`)
2. `Rfill = residual; Rfill(~isfinite(Rfill)) = 0` (`356-357`)
3. `[U,Sigma,V] = svd(Rfill,'econ')` (`359`)
4. `phi1 = V(:,1)` (`360`)
5. `phiScale = max(abs(phi1),...); phi1 = phi1./phiScale; kappa1 = kappa1.*phiScale` (`367-370`)
6. `signCorr = corr(Speak,kappa1,...)`; if negative, flip both signs (`372-375`)
- Mean-based Phi1 check:
  - No direct-called file contains assignment of `phi1` from mean over T of normalized residuals.
  - Status: `PHI1_MEAN_BASED = NO`, `PHI1_DEFINITION_UNIQUE = YES`.

## 5) Exact kappa1 computation
- Initial definition:
  - `kappa1 = U(:,1) * Sigma(1,1)` (`run_switching_canonical.m:361`)
- Post-scaling with Phi1 normalization:
  - `kappa1 = kappa1 .* phiScale` (`370`)
- Post sign correction:
  - if `signCorr < 0`, `kappa1 = -kappa1` (`375`)
- No regression/projection equation outside this SVD branch is used for canonical `kappa1` in `run_switching_canonical.m`.

## 6) Mandatory critical checks outcome
- `I_peak` found:
  - `run_switching_canonical.m:486-487` in observables output
- `width` found in direct-called helpers:
  - `getFileListSwitching.m:14,23-24,41-42`
- normalization of I axis found:
  - no explicit coordinate normalization expression found in canonical collapse equations
- division of S beyond `change_pct` found:
  - `run_switching_canonical.m:323,331`
- Per requested rule, status sets:
  - `COLLAPSE_EXPLICIT_COORDINATE = YES`

## Final verdict
- `COLLAPSE_DEFINED = YES`
- `COLLAPSE_TYPE = MIXED`

Basis for `MIXED`:
- Decomposition collapse is present (`Sfull = Scdf + kappa1*phi1'`) and `COLLAPSE_IMPLICIT_DECOMPOSITION = YES`.
- Requested mandatory rule also triggers `COLLAPSE_EXPLICIT_COORDINATE = YES` because required pattern checks found `I_peak`/width presence and S-division beyond `change_pct`.
