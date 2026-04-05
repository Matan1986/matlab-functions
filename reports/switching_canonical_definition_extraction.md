# switching_canonical_definition_extraction

## Scope and sources used
- Code only:
  - `Switching/analysis/run_switching_canonical.m`
  - Directly called helpers used for implemented quantities:
    - `Switching ver12/main/processFilesSwitching.m`
    - `Switching ver12/getFileListSwitching.m`
    - `Switching ver12/parsing/extract_delay_between_pulses_from_name.m`
    - `Switching ver12/parsing/extractPulseSchemeFromFolder.m`
    - `Switching ver12/main/analyzeSwitchingStability.m`
- Canonical run artifacts only:
  - `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv`
  - `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_phi1.csv`
  - `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_observables.csv`
  - `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_validation.csv`
  - Other switching canonical runs with same artifact hashes and `WRITE_SUCCESS=YES`:
    - `run_2026_04_02_234844_switching_canonical`
    - `run_2026_04_03_000008_switching_canonical`
    - `run_2026_04_03_091018_switching_canonical`

## 1) Collapse (implemented)
- `SHIFT = NONE`
  - No implemented transformation of current axis of the form `(I - I0)` in canonical outputs.
  - Code: `run_switching_canonical.m:246,261-263,481-484`.
- `SCALE_I = NONE`
  - Canonical output axis uses `current_mA` from folder metadata directly (`rowsCurrent = meta.Current_mA`).
  - Code: `run_switching_canonical.m:191,246,261-263,481-484`.
- `SCALE_S = S_percent := change_pct`
  - `Svec = metricTbl(:,4)` and `rawTbl.S_percent = rowsS`, then `Smap` is mean on `(T,current)` bins.
  - Code: `run_switching_canonical.m:225-227,261-263,273-291`.
  - `metricTbl(:,4)` is `change_pct` from `processFilesSwitching` row template:
    - alternating mode: `change_pct(k) = (avg_p2p(k)/refBase(k))*100`
    - repeated mode: `change_pct(k) = (blockJumpMetric(k)/refBase(k))*100`
  - Code: `processFilesSwitching.m:493-499,552-560`.
- `WIDTH_USED = NO`
  - Pulse width is parsed as metadata (`meta.PulseWidth_ms`) but not used in canonical `Smap/PT/Phi1/kappa1/reconstruction` equations.
  - Code parse only: `getFileListSwitching.m:14-15,23-24`.
  - No width column in canonical artifacts (`S_long`, `phi1`, `observables`, `validation`).

## 2) Phi1 (exact implementation)
- `DeltaS := residual := Smap - Scdf`
  - Code: `run_switching_canonical.m:355`.
- Fill non-finite before SVD:
  - `Rfill = residual; Rfill(~isfinite(Rfill)) = 0`
  - Code: `run_switching_canonical.m:356-357`.
- SVD definitions:
  - If any nonzero in `Rfill`:
    - `[U,Sigma,V] = svd(Rfill,'econ')`
    - `phi1 = V(:,1)`
    - `kappa1 = U(:,1)*Sigma(1,1)`
  - Else: zeros.
  - Code: `run_switching_canonical.m:358-365`.
- Normalization/sign:
  - `phiScale = max(abs(phi1))`
  - if `phiScale>0`: `phi1 = phi1/phiScale`, `kappa1 = kappa1*phiScale`
  - `signCorr = corr(Speak,kappa1,'Type','Spearman')`
  - if `signCorr<0`: multiply both by `-1`.
  - Code: `run_switching_canonical.m:367-376`.
- Averaging over `T`:
  - No explicit averaging operator over `T` is implemented for `phi1`; decomposition is a single SVD over full `Rfill(T,I)`.

Artifact verification:
- `switching_canonical_phi1.csv` has `max(abs(Phi1)) = 1` (matches `phiScale` normalization).

## 3) kappa1 (exact implementation)
- Primary formula:
  - `kappa1 = U(:,1)*Sigma(1,1)` from `svd(Rfill,'econ')`.
  - Code: `run_switching_canonical.m:359-361`.
- Coupled normalization:
  - multiplied by `phiScale` when `phi1` is normalized.
  - Code: `run_switching_canonical.m:367-371`.
- Coupled sign choice:
  - sign flipped jointly with `phi1` if `Spearman(Speak,kappa1) < 0`.
  - Code: `run_switching_canonical.m:372-376`.
- Dependence on `S_peak`:
  - direct magnitude formula does not include `S_peak`.
  - `Speak` is only used for sign orientation check.

## 4) Reconstruction (exact implementation)
- `S_CDF` (`Scdf`) per temperature row:
  - `cdfRaw = svalid / Speak`
  - clamp to `[0,1]`
  - enforce monotone nondecreasing via forward pass
  - normalize by `cdfRaw(end)` if positive
  - `p = gradient(cdfRaw, Ivalid)`, non-finite -> 0, clamp `p>=0`, normalize by `trapz(Ivalid,p)` if area>0 else zeros
  - `cdfPt = cumtrapz(Ivalid,p)`, normalize by `cdfPt(end)` if positive, clamp to `[0,1]`
  - `Scdf = Speak * cdfPt`
  - Code: `run_switching_canonical.m:323-353`.
- Full model:
  - `Sfull = Scdf + kappa1*phi1'`
  - Code: `run_switching_canonical.m:378`.
- Validation comparisons:
  - row RMSEs: `rmse_pt_row`, `rmse_full_row`
  - global RMSEs: `RMSE_PT`, `RMSE_FULL`
  - pass flag: `RECONSTRUCTION_IMPROVES = (RMSE_FULL < RMSE_PT)`
  - Code: `run_switching_canonical.m:380-402,439-442,486-504`.

Artifact verification from canonical run:
- `max|residual_percent - (S_percent - S_model_pt_percent)| = 9.71445146547012E-16`
- `max|S_model_full_percent - (S_model_pt_percent + kappa1(T)*Phi1(I))| = 1.02695629777827E-15`
- `RMSE_PT` recomputed from finite rows in `S_long` equals validation `RMSE_PT` within `1.38777878078145E-17`.
- `RMSE_FULL` recomputed from finite rows in `S_long` equals validation `RMSE_FULL` within `2.42861286636753E-17`.

## Final verdict
- `CANONICAL_DEFINITION_EXTRACTED = YES`
- `EVIDENCE_SUFFICIENT = YES`
