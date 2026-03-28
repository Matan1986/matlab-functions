# kappa2 opening test (strict identification)

## Canonical inputs
- kappa1: `C:/Dev/matlab-functions/results/switching/runs/_extract_run_2026_03_24_220314_residual_decomposition/run_2026_03_24_220314_residual_decomposition/tables/kappa_vs_T.csv`
- kappa2: `C:/Dev/matlab-functions/tables/closure_metrics_per_temperature.csv`
- PT matrix: `C:/Dev/matlab-functions/results/switching/runs/run_2026_03_24_212033_switching_barrier_distribution_from_map/tables/PT_matrix.csv`

## STEP 0: Data sanity
- n_aligned = **12**
- std(kappa2) = **0.0713032**
- fraction of variance explained by mean model (LOOCV R2) = **-0.190083**
- trivial variance regime flag = **NO** (threshold std < 0.02)

## STEP 1: Base models (LOOCV)
```text
<strong>model_id</strong>                    <strong>n</strong>     <strong>loocv_rmse</strong>    <strong>R2_loocv</strong>    <strong>pearson_y_yhat</strong>    <strong>spearman_y_yhat</strong>    <strong>rmse_improvement_pct_vs_mean</strong>
    <strong>________________________________________</strong>    <strong>__</strong>    <strong>__________</strong>    <strong>________</strong>    <strong>______________</strong>    <strong>_______________</strong>    <strong>____________________________</strong>

    "kappa2 ~ mean"                             12     0.074474     -0.19008             -1                 -1                       0           
    "kappa2 ~ PT"                               12      0.18606       -6.428       -0.12005          -0.062937                 -149.83           
    "kappa2 ~ kappa1"                           12     0.047947      0.50671        0.72063            0.72028                  35.618           
    "kappa2 ~ PT + kappa1"                      12      0.15127      -3.9102      -0.035153          -0.041958                 -103.12           
    "kappa2 ~ PT + kappa1 + small_nonlinear"    12      0.20304      -7.8456       -0.12914          -0.076923                 -172.63
```

## STEP 2: Explained variance decomposition
```text
<strong>n_aligned</strong>    <strong>kappa2_std</strong>    <strong>R2_mean_model</strong>    <strong>R2_PT</strong>     <strong>R2_kappa1</strong>    <strong>R2_PT_plus_kappa1</strong>    <strong>Delta_R2_PTk1_vs_best_single</strong>
    <strong>_________</strong>    <strong>__________</strong>    <strong>_____________</strong>    <strong>______</strong>    <strong>_________</strong>    <strong>_________________</strong>    <strong>____________________________</strong>

       12         0.071303       -0.19008       -6.428     0.50671          -3.9102                   -4.4169
```
- Delta R2 = R2(PT+kappa1) - max(R2_PT, R2_kappa1) = **-4.41692**

## STEP 3: Residual structure (best of PT+kappa1 / nonlinear)
- best model used for residual test: `kappa2 ~ PT + kappa1`
- residual variance fraction var(r)/var(kappa2) = **4.91019**
- corr(r, T): Pearson = **-0.0597216**, Spearman = **0.132867**
- corr(r, kappa1): Pearson = **-0.0643914**, Spearman = **-0.125874**
- corr(r, PT width q90-q10) = **0.184215**
- corr(r, PT asymmetry) = **0.278592**
- corr(r, PT std I) = **0.332702**
- corr(r, PT width q75-q25) = **0.248016**

## STEP 4: Transition localization
- RMS residual inside 22-24K = **0.226145**
- RMS residual outside 22-24K = **0.131272**
- transition ratio (inside/outside) = **1.72272**

## STEP 5: Low-dimensionality test (residual trajectory)
- SVD mode-1 energy fraction = **0.755585**
- SVD mode-(1+2) energy fraction = **0.954672**
- residual lag-1 correlation = **-0.404343**
- residual mode type = **STRUCTURED_LOW_DIMENSIONAL**

## STEP 6: Strict decision logic
- geometric criterion: R2_PT >= 0.2 OR RMSE improvement of PT+kappa1 over mean >= 10%%
  values: R2_PT = -6.42799, RMSE improvement = -103.124%
  => KAPPA2_HAS_GEOMETRIC_COMPONENT = **NO**
- closed criterion: R2_PT+kappa1 >= 0.7 AND residual variance <= 0.30
  values: R2_PT+kappa1 = -3.91021, residual variance fraction = 4.91019
  => KAPPA2_IS_CLOSED = **NO**
- reorganization criterion: residual variance >= 0.40 OR |corr(r,T)| >= 0.45 OR transition ratio >= 1.5
  values: residual variance fraction = 4.91019, |corr(r,T)| = 0.0597216, transition ratio = 1.72272
  => KAPPA2_HAS_REORGANIZATION_RESIDUAL = **YES**
- KAPPA2_PARTIALLY_OPENED (geometric YES and residual YES) = **NO**

## Final answers (required)
1. Explained by PT + kappa1: R2_PT+kappa1 = **-3.91021**, DeltaR2 over best single = **-4.41692**.
2. Remaining part structured or noise: residual variance fraction = **4.91019**; residual mode = **STRUCTURED_LOW_DIMENSIONAL**.
3. Residual localized near transition: transition ratio = **1.72272** (22-24K vs outside).
4. Is kappa2 closed: **NO**.
