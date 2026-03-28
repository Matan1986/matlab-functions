# kappa1 physical simplification

- Input table: `C:/Dev/matlab-functions/tables/kappa1_from_PT_aligned.csv`
- Best single-observable model: `kappa1 ~ S_peak`
- Best single LOOCV RMSE: `0.0166737` (Pearson=`0.9481`, Spearman=`0.9510`, n=12)
- Reference 2-variable model: `kappa1 ~ spread90_50 + S_peak` with LOOCV RMSE=`0.0184739`

## Final section
KAPPA1_SINGLE_OBSERVABLE_SUFFICIENT: YES

## Physical interpretation
- Selected interpretation: **scale effect**
- Justification: Best simplified model is S_peak-driven, indicating kappa1 behaves primarily as an amplitude scale coordinate.

## Model table snapshot
| model | n_used | LOOCV RMSE | Pearson | Spearman |
|---|---:|---:|---:|---:|
| kappa1 ~ S_peak | 12 | 0.0166737 | 0.948086 | 0.951049 |
| kappa1 ~ spread90_50 * S_peak | 12 | 0.0172207 | 0.94456 | 0.944056 |
| kappa1 ~ spread90_50 + S_peak | 12 | 0.0184739 | 0.938721 | 0.944056 |
| kappa1 ~ extreme_tail_q95_q75 + S_peak | 12 | 0.0230836 | 0.916413 | 0.944056 |
| kappa1 ~ spread90_50 / S_peak | 12 | 0.0435055 | 0.695099 | 0.902098 |
| kappa1 ~ spread90_50 | 12 | 0.049813 | 0.493922 | 0.468531 |
| kappa1 ~ extreme_tail_q95_q75 | 12 | 0.0581188 | -0.445701 | -0.41958 |
| kappa1 ~ normalized_tail_q90_q50 | 12 | 0.0606259 | -0.328619 | -0.447552 |
| kappa1 ~ tail_mass_quantile_top12p5 | 12 | 0.0619433 | -0.749905 | -0.818182 |
| kappa1 ~ normalized_tail_q95_q75 | 12 | 0.0658125 | -0.628021 | -0.608392 |
| kappa1 ~ pdf_at_q90 | 12 | 0.0756227 | -0.614375 | -0.979021 |
