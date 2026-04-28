# Switching canonical paper-candidate figures

Figure-generation only pass using closed P0/P1/P2 + recovery inventory outputs.
No scientific logic, recipes, metrics, or claim boundaries were modified.

## Inputs used
- `C:\Dev\matlab-functions\results\switching\runs\run_2026_04_03_000147_switching_canonical\tables\switching_canonical_S_long.csv`
- `C:\Dev\matlab-functions\tables\switching_P0_old_collapse_freeze_metrics.csv`
- `C:\Dev\matlab-functions\tables\switching_P0_effective_observables_values.csv`
- `C:\Dev\matlab-functions\tables\switching_P1_asymmetry_LR_values.csv`
- `C:\Dev\matlab-functions\tables\switching_P2_T22_crossover_metrics.csv`
- `C:\Dev\matlab-functions\tables\switching_P2_T22_crossover_neighbor_contrasts.csv`
- `C:\Dev\matlab-functions\tables\switching_figure_recovery_decision.csv`
- `C:\Dev\matlab-functions\tables\switching_figure_recovery_status.csv`

## Outputs
- `C:\Dev\matlab-functions\results\switching\figures\canonical_paper\switching_main_candidate_map_cuts_collapse.png`
- `C:\Dev\matlab-functions\results\switching\figures\canonical_paper\switching_main_candidate_map_cuts_collapse.pdf`
- `C:\Dev\matlab-functions\results\switching\figures\canonical_paper\switching_supp_Xeff_components.png`
- `C:\Dev\matlab-functions\results\switching\figures\canonical_paper\switching_supp_Xeff_components.pdf`
- `C:\Dev\matlab-functions\tables\switching_canonical_paper_figures_manifest.csv`
- `C:\Dev\matlab-functions\tables\switching_canonical_paper_figures_status.csv`

## Label and boundary controls
- Uses `X_eff` labeling (no `X_canon` claims).
- Uses `W_I` as recovered old-collapse width/gauge width (no unique-`W` claim).
- Collapse panel is labeled primary-domain effective collapse (T_K < 31.5 K).
- 22 K is highlighted as internal crossover/reorganization candidate.
- 32/34 K are diagnostic-only and not mixed into primary collapse claim.
- X_eff panel y-limits are set using finite primary-domain values only; above-31.5K diagnostic points are shown but excluded from axis scaling.

## Execution status
- MATLAB wrapper run success: YES

## Verdicts
- ABOVE_31P5_DIAGNOSTIC_EXCLUDED_FROM_XEFF_AXIS_LIMITS = YES
- ABOVE_31P5_DIAGNOSTIC_ONLY = YES
- CANONICAL_PAPER_FIGURES_GENERATED = YES
- CANONICAL_S_USED = YES
- CROSS_MODULE_SYNTHESIS_PERFORMED = NO
- MAIN_CANDIDATE_FIGURE_WRITTEN = YES
- P0_COLLAPSE_USED = YES
- P0_EFFECTIVE_OBSERVABLES_USED = YES
- P1_ASYMMETRY_USED = YES
- P2_T22_USED = YES
- SAFE_TO_WRITE_SCALING_CLAIM = NO
- SUPPLEMENT_CANDIDATE_FIGURE_WRITTEN = YES
- T22_INCLUDED_IN_PRIMARY_DOMAIN = YES
- UNIQUE_W_CLAIMED = NO
- X_CANON_CLAIMED = NO
- X_EFF_LABEL_USED = YES
- X_EFF_PRIMARY_DOMAIN_AXIS_SCALING = YES
