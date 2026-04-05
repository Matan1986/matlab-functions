# switching_collapse_interpretation

## Verdict
- `COLLAPSE_DEFINED = YES`
- `COLLAPSE_TYPE = IMPLICIT`

## 1) Explicit-normalization checks

### I normalization
- No explicit normalization of `I` for collapse is implemented.
- `current_mA` is carried directly into the canonical grid and artifacts.
- Evidence:
  - `run_switching_canonical.m:246` (`rowsCurrent = meta.Current_mA`)
  - `run_switching_canonical.m:265-268,290-291` (`currents` from raw values)
  - `run_switching_canonical.m:481-484` (`S_long` written on `T_K,current_mA` grid)

### S normalization beyond `change_pct`
- Upstream canonical `S_percent` is `change_pct` (from `metricTbl(:,4)`), not an added collapse normalization.
- Evidence:
  - `run_switching_canonical.m:225-227,260-263`
  - `processFilesSwitching.m:552-557` (column 4 is `change_pct`)
  - `processFilesSwitching.m:493-499` (`change_pct` formula)

- Additional normalization appears only inside the CDF-model construction step:
  - `cdfRaw = svalid / Speak(it)`
  - `cdfRaw = cdfRaw / cdfRaw(end)` when `cdfRaw(end)>0`
- Evidence:
  - `run_switching_canonical.m:323,330-332`

### Explicit alignment operation
- No explicit collapse alignment operator is implemented (no `I` shift, no `I` scale, no optimization of alignment parameters across `T`).
- Implemented operations are decomposition steps on the original grid.
- Evidence:
  - `run_switching_canonical.m:273-291,311-378`

## 2) Role of `Scdf`, residual `DeltaS`, and SVD (`Phi1`)

### Role of `Scdf`
- `Scdf` is the CDF-based model component written as `S_model_pt_percent`.
- Constructed per temperature row from `cdfPt` and `Speak`:
  - `Scdf(it,valid) = Speak(it) .* cdfPt`
- Evidence:
  - `run_switching_canonical.m:311-353`
  - Artifact columns: `switching_canonical_S_long.csv` -> `S_model_pt_percent`, `CDF_pt`, `PT_pdf`

### Role of residual `DeltaS`
- Residual is defined exactly as:
  - `residual = Smap - Scdf`
- Evidence:
  - `run_switching_canonical.m:355`
  - Artifact column: `switching_canonical_S_long.csv` -> `residual_percent`

### Role of SVD and `Phi1`
- Residual is decomposed by rank-1 SVD on `Rfill`:
  - `phi1 = V(:,1)` (current-axis mode)
  - `kappa1 = U(:,1) * Sigma(1,1)` (temperature amplitude)
- Then:
  - `phi1` normalized by max-abs; `kappa1` rescaled accordingly
  - joint sign orientation by Spearman correlation with `Speak`
- Evidence:
  - `run_switching_canonical.m:356-376`
  - Artifacts:
    - `switching_canonical_phi1.csv` (`Phi1`)
    - `switching_canonical_observables.csv` (`kappa1`)

## 3) Mechanism of collapse (implicit)

- Implemented representation is:
  - `Sfull(T,I) = Scdf(T,I) + kappa1(T)*phi1(I)`
- Evidence:
  - `run_switching_canonical.m:378`
  - Artifact columns in `switching_canonical_S_long.csv`:
    - `S_model_pt_percent` (`Scdf`)
    - `S_model_full_percent` (`Sfull`)

### What quantities are being aligned
- `Smap(T,I)` is represented in two aligned components on a shared `(T,I)` grid:
  - CDF component: `Scdf(T,I)`
  - Rank-1 residual component: `kappa1(T)*phi1(I)`

### How collapse is achieved through decomposition
- Collapse is achieved by projecting the residual structure onto a single current mode (`Phi1`) with temperature amplitude (`kappa1`), rather than by explicit axis normalization.

### Effective collapse space
- Effective collapse space is the decomposition space spanned by:
  - `Scdf(T,I)` from CDF construction
  - `phi1(I)` with coefficient `kappa1(T)`
- This is an implicit low-dimensional representation of `Smap(T,I)` on the native current grid.
