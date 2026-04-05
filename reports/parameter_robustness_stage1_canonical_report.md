# Parameter Robustness Stage 1: Canonical Observable Class

## Step 1 - Canonical input lock
- CANONICAL_SOURCE_LOCKED = YES
- source_file = `C:\Dev\matlab-functions\results\switching\runs\run_2026_03_10_112659_alignment_audit\alignment_audit\switching_alignment_samples.csv`
- run_id = `run_2026_03_10_112659_alignment_audit`
- observable = `S_percent`
- normalization = `y_norm = S / S_peak (fixed logic)`
- collapse_coordinate = `x_c = (I - I_peak_canonical) / width_canonical (fixed for all variants)`
- map_construction = `Switching/utils/buildSwitchingMapRounded.m`
- N_T = 16
- N_I = 7

## Step 2 - Included canonical-equivalent variants
- See `tables/parameter_robustness_stage1_canonical_methods.csv` (rows with INCLUDED=YES).

## Step 3 - Robustness metrics
- I_peak|min_corr_noncanon=0.985389|worst_rel_noncanon=0.081461
- width|min_corr_noncanon=0.752355|worst_rel_noncanon=0.714435
- S_peak|min_corr_noncanon=0.999747|worst_rel_noncanon=0.103263
- kappa1|min_corr_noncanon=0.674119|worst_rel_noncanon=59.852100
- collapse|min_corr_noncanon=1.000000|worst_rel_noncanon=0.000000

## Step 4 - Explicit exclusions
- See `tables/parameter_robustness_stage1_canonical_methods.csv` (rows with INCLUDED=NO).

## Step 5 - Final verdicts
- IPEAK_CANONICAL_ROBUST = NO
- WIDTH_CANONICAL_ROBUST = NO
- SPEAK_CANONICAL_ROBUST = NO
- KAPPA1_CANONICAL_ROBUST = NO
- COLLAPSE_CANONICAL_ROBUST = YES
- PARAMETER_CANONICAL_ROBUST = NO
- overall_interpretation = fragile even within canonical class
