# Estimator Design Proposal (Isolated Local Computation)

## Scope and Input Lock
- locked run: run_2026_03_10_112659_alignment_audit
- locked input: C:\Dev\matlab-functions\results\switching\runs\run_2026_03_10_112659_alignment_audit\alignment_audit\switching_alignment_samples.csv

## Exact New Width Estimator Definition
- compute S_peak on native sampled I grid
- define half level h = 0.5 * S_peak
- find nearest left bracket with S(j-1) < h <= S(j)
- find nearest right bracket with S(j) >= h > S(j+1)
- linearly interpolate each crossing inside its bracket
- set width_new = I_right_half - I_left_half
- if either bracket is missing, retry once with minimal smoothing: moving median window 3

## Optional kappa1 Definition
- kappa1 = slope of normalized profile y_norm = S/S_peak vs x_norm = (I-I_peak)/w over |x_norm| <= 1
- old kappa1: old width + discrete peak
- new kappa1: new width + parabolic local peak
- sensitivity probes included: width-only change, I_peak-only change

## Comparison Summary
- width correlation old vs new: 0.752354777236323
- width RMSE old vs new (mA): 8.14248851366259
- width stability old: 0
- width stability new: 0.0411622932522884
- kappa1 correlation old vs new: -0.0699410914440527
- kappa1 RMSE old vs new: 0.279588505638232
- kappa1 stability old: 1.20633496924577
- kappa1 stability new: 0.252142939929274

## Stability Improvement Assessment
- width valid temperatures old/new: 13/15
- kappa1 valid temperatures old/new: 8/14
- thresholds used for verdicts:
  width improved if valid coverage does not drop and stability improves by >=10%
  kappa1 improved if valid coverage does not drop and stability improves by >=10%
  new estimator stable if width stability <0.30 and kappa1 stability <0.60 (or kappa1 unavailable)

## Limitations
- interpolation reduces discretization artifact but cannot recover information outside sampled current grid
- smoothing fallback is minimal but can bias very sharp transitions
- kappa1 remains partly definition-sensitive because both width and peak normalization enter the estimator

## Verdicts
- WIDTH_ESTIMATOR_IMPROVED = NO
- KAPPA1_ESTIMATOR_IMPROVED = YES
- NEW_ESTIMATOR_STABLE = YES
- SAFE_TO_ADOPT = NO

## Output Files
- C:\Dev\matlab-functions\tables\estimator_design_width_comparison_local_20260329_222628.csv
- C:\Dev\matlab-functions\tables\estimator_design_kappa1_comparison_local_20260329_222628.csv
- C:\Dev\matlab-functions\reports\estimator_design_proposal_local_20260329_222628.md
