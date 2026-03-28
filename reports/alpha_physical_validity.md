# Alpha physical validity test

Script: `C:/Dev/matlab-functions/Switching/analysis/run_alpha_physical_validity_test.m`
Alpha input: `C:/Dev/matlab-functions/tables/alpha_structure.csv`
R input: `C:/Dev/matlab-functions/results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv`

## Step 1: alpha vs kappa2
- Pearson(alpha, kappa2) = 0.961536
- Spearman(alpha, kappa2) = 0.951648
- CV(alpha) = 59.9998, CV(kappa2) = 19.0481

## Step 2: leave-one-point-out alpha recomputation
- median relative change = 0.512291
- p95 relative change = 6.27826

## Step 3: noise sensitivity (1% kappa1 noise)
- median relative alpha change = 0.0068614
- p95 relative alpha change = 0.0075114

## Step 5: LOOCV predictive power
- n_pred = 4
- baseline RMSE (constant) = 51.5008
- RMSE: R ~ kappa1 + kappa2 = 43.4869 | Pearson=-0.0045229 | Spearman=0
- RMSE: R ~ kappa1 + alpha  = 63.7431 | Pearson=0.286706 | Spearman=0

## Verdicts
- ALPHA_STABLE: `NO`
- ALPHA_PHYSICAL: `NO`
- KAPPA2_SUPERIOR_TO_ALPHA: `YES`

Summary: nT=14 | rho(alpha,k2)=0.9615 | median LOO rel=0.5123 | median noise rel=0.006861 | rmse(k1+k2)=43.49 vs rmse(k1+alpha)=63.74
