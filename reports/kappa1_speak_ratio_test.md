# kappa1 vs S_peak ratio test

## Data source (canonical only)
- kappa1: C:/Dev/matlab-functions/results/switching/runs/_extract_run_2026_03_24_220314_residual_decomposition/run_2026_03_24_220314_residual_decomposition/tables/kappa_vs_T.csv
- S_peak: C:/Dev/matlab-functions/results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv
- Overlap used: n = 14 temperatures (T=4..30 K step 2 K).

## Ratio table artifact
- Output CSV: C:/Dev/matlab-functions/tables/kappa1_speak_ratio_test.csv

## 1) Is kappa1/S_peak approximately constant?
- mean = 0.654519
- std = 0.111967
- coefficient of variation = 0.171
- min/max = 0.451476 / 0.874818
- IQR = 0.159643; MAD = 0.096230

## 2) Temperature dependence tests for ratio
- Pearson(ratio, T) = 0.3890
- Spearman(ratio, T) = 0.4154
- Linear fit ratio = a + b*T: a=0.566019, b=0.005206 1/K
- LOOCV RMSE (constant ratio model) = 0.116194
- LOOCV RMSE (linear-in-T ratio model) = 0.118957

## 3) 22-24 K transition-window contrast
- Window mean (22-24 K) = 0.601679
- Outside mean = 0.663325
- Deviation (window - outside) = -0.061647
- Deviation in outside-std units = -0.61 sigma
- Interpretation: deviation larger than background scatter if |z| > 1.

## 4) Amplitude scheme comparison (existing compatible scalar metric)
Using canonical aligned amplitudes, compare how well each scheme reproduces measured kappa1(T) (RMSE and LOOCV-RMSE in kappa space).

| Model | Definition | RMSE(kappa) | LOOCV RMSE(kappa) | Pearson with kappa |
|---|---|---:|---:|---:|
| A | measured kappa1 | 0.000000 | 0.000000 | 1.0000 |
| B | kappa1 <- S_peak (c=1) | 0.082060 | 0.082060 | 0.9706 |
| C | kappa1 <- c*S_peak (global fit c=0.6086) | 0.015348 | 0.017500 | 0.9706 |

## Final verdicts
KAPPA1_EQUALS_SPEAK: PARTIAL
KAPPA1_OVER_SPEAK_CONSTANT: PARTIAL
EXTRA_c_PARAMETER_NEEDED: YES

## Plain-language interpretation
- kappa1 mostly tracks S_peak, but not as a strict one-to-one copy.
- kappa1/S_peak is moderately stable but still shows temperature-linked drift.
- A global multiplicative c materially improves amplitude matching vs fixed c=1; keep c.
