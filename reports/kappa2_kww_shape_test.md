# kappa2 kww shape test

## data sources
- Relaxation dataset: C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv
- Kappa table: C:/Dev/matlab-functions/tables/aging_kappa2_master_table.csv
- PT observables: C:/Dev/matlab-functions/tables/kappa1_from_PT.csv

## alignment summary
- Alignment method: manual nearest matching on T_K (no innerjoin)
- Matched temperature count: 19
- Matched T list (kappa side): 6 6 6 8 10 12 14 16 18 20 22 24 26 26 26 26 26 26 26
- Total points across all T: 6840
- Fit points across all T: 6802

## kww fit setup
- Normalization: Per-temperature min-max normalization on M(T,t), then orientation fixed to decay from ~1 to ~0.
- Transform: x = log(t), y = log(-log(R_relax_norm))
- Regression: manual slope/intercept, beta = slope, tau = exp(-intercept/beta)
- Invalid values excluded: R_relax_norm <= 0 or >= 1

## beta(T) and tau(T)
|T_relax_K|T_kappa_K|N_fit|beta|tau_s|RMSE_KWW|RMSE_EXP|RMSE_LOG|
|---:|---:|---:|---:|---:|---:|---:|---:|
|3|6|358|1.69058|13.9489|0.0475532|0.103105|0.0524773|
|5|6|358|1.86052|13.924|0.0608956|0.111419|0.0529835|
|7|6|358|1.85929|14.031|0.0588773|0.107716|0.054552|
|9|8|358|1.78868|14.0532|0.0548606|0.103695|0.0533344|
|11|10|358|2.02655|14.2059|0.0707376|0.105603|0.0567825|
|13|12|358|2.04379|14.5552|0.0702095|0.105987|0.0606458|
|15|14|358|1.84705|15.0937|0.0528436|0.10268|0.0640364|
|17|16|358|1.87649|15.1173|0.0523103|0.113506|0.0675719|
|19|18|358|1.86414|15.3041|0.0489158|0.113676|0.0698853|
|21|20|358|2.04034|15.1644|0.0603801|0.1164|0.0716472|
|23|22|358|1.92472|15.1493|0.0508825|0.119684|0.071066|
|25|24|358|1.92925|14.9641|0.0512964|0.120244|0.0697602|
|27|26|358|1.90811|14.7149|0.0511536|0.118131|0.0669736|
|29|26|358|1.96024|14.5117|0.0555668|0.118951|0.0654063|
|31|26|358|1.94653|14.1455|0.0574888|0.118569|0.0609683|
|33|26|358|2.56666|14.1117|0.0974434|0.115214|0.0612707|
|35|26|358|2.82857|13.8669|0.110455|0.12818|0.0614229|
|37|26|358|1.34026|16.5451|0.0787944|0.0828973|0.0862389|
|39|26|358|0.326178|31.6587|0.171598|0.277502|0.167821|

## fit quality
- Mean RMSE KWW: 0.0685401
- Mean RMSE exponential (beta=1): 0.120166
- Mean RMSE logarithmic: 0.0692023
- RMSE vs T available in output CSV columns rmse_kww/rmse_exp/rmse_log.

## correlations
- beta vs kappa2: Pearson=0.071581 Spearman=0.257752 n=19
- beta vs kappa1: Pearson=-0.0111326 Spearman=-0.295603 n=19
- beta vs tail_width_q90_q50: Pearson=-0.0323898 Spearman=-0.349193 n=19
- beta vs extreme_tail_q95_q75: Pearson=-0.0310441 Spearman=0.199796 n=19

## robustness checks
- Mean |beta(remove early) - beta(remove late)|: 0.745041
- Variance beta(T): 0.221736

## final verdict block
- KWW_GOOD_DESCRIPTION: PARTIAL
- BETA_CORRELATED_WITH_KAPPA2: NO
- BETA_CORRELATED_WITH_KAPPA1: NO
- BETA_CONTROLLED_BY_PT: NO
- KAPPA2_CONTROLS_RELAXATION_SHAPE: NO

## short physical interpretation
If beta tracks kappa2 more strongly than kappa1 and KWW fits are good, this supports a shape-control role for kappa2 in relaxation broadening.
