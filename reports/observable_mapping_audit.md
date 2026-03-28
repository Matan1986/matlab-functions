# Observable Mapping Audit (Model Variables -> Measurements)

## Scope / method
This audit uses existing repository evidence only (no recomputation, no new PT reconstruction):
- `tables/latent_to_observable_replacement_table.csv` for descriptor-level mapping and replacement quality categories
- `tables/observable_replacement_model_tests.csv` for LOOCV RMSE tests of observable proxies (kappa1, kappa2)
- `tables/agent24h_correlations.csv` for single-observable Pearson/Spearman associations (kappa1, kappa2)
- `docs/observable_human_dictionary.md` for consistent interpretation of what counts as “mapping” versus “proxy”

## Variable-by-variable classification

### P_T
Classification: `DIRECTLY OBSERVED (PT_backbone object)`
Best observable mapping: PT backbone/descriptor set (quantile ladder q50/q75/q90; `spread90_50`; `std_threshold`; mean/median).
Evidence: `tables/latent_to_observable_replacement_table.csv` row `PT_backbone` (replacement quality: PARTIAL; single-proxy sufficient: no) plus the dictionary’s PT backbone object language.
Mapping interpretation: P_T is not treated as a single scalar observable; instead it is recovered as an object/descriptor vector from the barrier/threshold distribution family.

### kappa1
Classification: `WELL MAPPED`
Best observable proxy (observable-only predictors): `tail_width_q90_q50_PT + S_peak_mA` (joint proxy).
LOOCV proxy quality: `k1_fit_01` LOOCV_RMSE = `0.0184738729675384` on `n_loocv = 12`.
LOOCV comparison baseline in the stored test: single-observable `q90_I` is materially worse than the joint `tail_width_q90_q50_PT + S_peak_mA` proxy.
Single-observable correlation support: Pearson(`kappa1`, `S_peak`) = `0.970628407015015` on `n = 14`; Spearman = NaN in the stored correlation table.
Evidence: `tables/observable_replacement_model_tests.csv` (`k1_fit_01`); `tables/agent24h_correlations.csv`.
Conclusion: kappa1 is “closed” in the sense that a simple observable proxy set strongly matches kappa1 in LOOCV replacement tests.

### kappa2
Classification: `PARTIAL / UNCLEAR`
Best observable proxy candidate: `I_peak_mA` (ridge peak current).
LOOCV proxy quality: `k2_fit_01` LOOCV_RMSE = `0.113456194057352` on `n_loocv = 11` (best proxy within the stored comparison).
Single-observable correlation support: Pearson(`kappa2`, `I_peak_mA`) = `0.481827910038027` on `n = 14`; Spearman = NaN.
Evidence: `tables/observable_replacement_model_tests.csv` (`k2_fit_01`); `tables/agent24h_correlations.csv`.
Conclusion: kappa2 is only partially mapped; it does not meet the “closed” bar set by kappa1.

### Phi1
Classification: `NOT MAPPED AS A SINGLE NUMERIC PROXY`
Interpretation: Phi1 is a retained mode/shape field. Existing evidence supports only prose-level qualitative substitution (not a stable single measurement defining the mode field).
Evidence: `tables/latent_to_observable_replacement_table.csv` (`Phi1` row: CAN_BE_USED_AS_PROXY_WITH_CAVEATS; single-proxy sufficient: no; numeric replacement is not treated as defining).

### Phi2
Classification: `NOT MAPPED AS A SINGLE NUMERIC PROXY`
Interpretation: Phi2 mapping is treated as shape/structure metrics rather than a single stable observable. Replacement stability for “single-number” proxy is explicitly constrained.
Evidence: `tables/latent_to_observable_replacement_table.csv` (`Phi2` row: CAN_REPLACE_IN_PAPER_LANGUAGE_ONLY; numeric stability caveats; single-proxy sufficient: no).

## Required sign-off flags
OBSERVABLE_MAPPING_COMPLETE: PARTIAL
KAPPA1_OBSERVABLE_CLOSED: YES
KAPPA2_OBSERVABLE_CLOSED: NO
PHI_MODES_OBSERVABLE_DEFINED: NO

