# Physical Origin of kappa(T)

## Inputs Used
- `docs/repo_state.json`
- `results/cross_experiment/runs/run_2026_03_25_180406_kappa_from_pt_agent14/reports/kappa_from_PT_report.md`
- `results/cross_experiment/runs/run_2026_03_25_041304_pt_to_phi_prediction/tables/kappa_prediction_models.csv`
- `results/cross_experiment/runs/run_2026_03_25_041304_pt_to_phi_prediction/tables/kappa_loocv_bestPT2_predictions.csv`

## 1) Feature attribution: best predictor

Best PT-only pair: `q90_I_mA | pt_svd_score2`
- LOOCV RMSE = 0.0183, Spearman = 0.9727 (n=11), stable for `T<=24K` and `exclude_22K`.
- This pair clearly outperforms PT single features and almost matches the strongest non-PT baseline.

Interpretation of the two predictors:
- `q90_I_mA`: upper-tail threshold scale (where the high-threshold population sits).
- `pt_svd_score2`: second orthogonal shape mode of P(T), capturing redistribution/curvature beyond simple location shift.

Evidence the pair is physically structured (not arbitrary):
- `q90_I_mA` alone is weak (`RMSE ~0.0467`), and `pt_svd_score2` alone is weak (`RMSE ~0.0505`), but together they become strong (`RMSE 0.0183`).
- This indicates kappa depends on both a tail-position coordinate and an independent shape/deformation coordinate.

## 2) Physical mapping to hypothesis dimensions

### Tail population
Support: strong.
- Best predictor includes `q90_I_mA`, not median-only or low-quantile-only descriptors.
- Good models repeatedly involve high-quantile/shape combinations.
- kappa tracks upper-threshold structure, consistent with tail-controlled activation physics.

### Threshold crowding / proximity to instability
Support: partial.
- Around 22-24K, kappa changes abruptly while PT shape coordinates also move non-monotonically.
- This is consistent with entering/leaving a crowded-threshold regime, but no direct instability order parameter is shown.
- Therefore: instability-like behavior is plausible but not uniquely identified.

### Variance structure / heterogeneity
Support: moderate.
- `pt_svd_score2` in the best pair implies sensitivity to distribution-shape heterogeneity.
- However, classic "broadness only" descriptors (e.g., some simple mass/tail-ratio proxies) are not consistently top-ranked.
- So heterogeneity matters as a coupled correction, not as the dominant standalone driver.

### Cooperative susceptibility
Support: weak-to-moderate (indirect only).
- PT descriptors strongly predict kappa, but direct cooperative observables are not part of the winning minimal model.
- Cooperative response may be encoded implicitly in PT shape, but this dataset does not isolate it as the primary interpretation.

## 3) Regime analysis (22-24K)

Observed from per-T table:
- kappa drops strongly from 20K to 22K (about -0.0515), then rebounds from 22K to 24K (about +0.0317).
- Over the same interval, `q90_I_mA` keeps decreasing, while `pt_svd_score2` reverses trend and increases sharply from 22K to 24K.

Physical reading:
- A one-coordinate "tail position only" picture cannot explain the rebound, because `q90_I_mA` continues to move in the same direction.
- The rebound requires the second shape mode contribution (`pt_svd_score2`), consistent with a reorganization in threshold occupancy/curvature near 22-24K.
- Thus, the 22-24K behavior is best viewed as a crossover where tail level and shape deformation compete.

## 4) Hypothesis comparison

Scoring against data:
- Tail weight/control: best match (strong direct support from predictor identity + model ranking).
- Instability proximity: compatible, but not uniquely proven (needs direct instability metric).
- Landscape heterogeneity: present as secondary orthogonal effect (via `pt_svd_score2`).
- Cooperative susceptibility: plausible latent contributor, but not directly resolved here.

## FINAL VERDICT

KAPPA_MEANING: **TAIL_CONTROLLED**

CONFIDENCE: **MEDIUM**

Interpretation:
- `kappa(T)` is best interpreted as an effective amplitude/response coefficient set primarily by the high-threshold tail occupancy of the PT landscape, with a necessary correction from an orthogonal PT shape mode (`pt_svd_score2`) that becomes especially important near the 22-24K crossover.
- In practical terms: kappa is not a pure instability scalar; it is a tail-dominated landscape-response parameter with regime-dependent shape renormalization.

