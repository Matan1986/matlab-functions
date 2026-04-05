# Switching canonical robustness contract

## Reconciled canonical robustness definition

This contract reconciles pre-canonical robustness intent with the current canonical Switching definition using repository evidence only.

A. Allowed temperature set
- Candidate temperatures must be sourced from the selected TRUSTED_CANONICAL run table (`switching_canonical_S_long.csv`).
- Contract baseline is therefore canonical-run grounded, not legacy alignment-run grounded.

B. Explicit exclusions near transition and boundary
- Boundary exclusions preserved from historical robustness evidence:
1. Exclude `T_K=4` from acceptance metrics.
2. Exclude `T_K=30` from acceptance metrics.
- High-temperature admissibility rule preserved from historical filtered-collapse logic:
1. Force-remove `T_K=34`.
2. For `T_K>=30`, exclude rows with `width_missing` and (`peak_at_lowest_current` OR `low_amplitude`).
- Transition handling (22-24 K): mandatory stratified reporting band, not automatic exclusion.

C. Allowed parameter perturbations
- Acceptance perturbations are canonical-equivalent only:
1. `I_peak`: `max_sample`, `max_parabolic_local`
2. `width`: `fwhm_linear`, `fwhm_nearest`, `fwhm_fine_interp`
3. `S_peak`: `max_sample`, `max_parabolic_local`
- Rejected for acceptance: `com`, `dsdi_peak`, `halfmax_mid`, `rms`, `iqr`, `asymmetric`, `local_avg`, `local_median`, variant-specific x-scaling.

D. Canonical data source requirements
- Inputs must come from `tables/switching_run_trust_classification.csv` rows with `classification=TRUSTED_CANONICAL`.
- Inputs from `tables_old`, root-level tables, or untrusted legacy runs are forbidden for execution.

E. Fixed coordinate and normalization requirements
- Primary canonical acceptance is function-space based and must not depend on coordinate-collapse perturbation.
- If auxiliary collapse diagnostics are reported for continuity with prior work, coordinate/normalization must be fixed (not swept) across variants.

F. Stability metrics and acceptance criteria
- Required metrics bundle:
1. `corr_vs_canonical`, `rmse_abs`, `median_rel_dev`, `worst_rel_dev`
2. Stage1B forensic diagnostics (coarse-grid/undersampling and kappa sensitivity decomposition)
- Acceptance thresholds (canonical policy):
1. `I_peak >= 0.90`
2. `width >= 0.85`
3. `S_peak >= 0.90`
4. `kappa1 >= 0.80`
5. collapse ratio within `[0.67, 1.50]`
- Acceptance is valid only with canonical-input confirmation and execution signaling validity.

## Mismatch resolution decisions

For the recovered mismatches, decisions are:
1. Temperature boundary/transition gap: `PRESERVE_OLD_BEHAVIOR` for boundary exclusions and high-T admissibility; `REPLACE_WITH_CANONICAL_EQUIVALENT` for transition-band handling.
2. Parameter filtering removed: `PRESERVE_OLD_BEHAVIOR` (canonical-equivalent perturbations only).
3. Canonical input trust mismatch: `REPLACE_WITH_CANONICAL_EQUIVALENT` (TRUSTED_CANONICAL lock).
4. Fixed-coordinate mismatch: `REPLACE_WITH_CANONICAL_EQUIVALENT` (no coordinate sweep in primary acceptance; fixed auxiliary diagnostics only).
5. Metric mismatch: `REPLACE_WITH_CANONICAL_EQUIVALENT` (restore variant-vs-canonical and forensic bundle).
6. Measurement-robustness metrics inside parameter contract: `REMOVE_AS_NONCANONICAL` (separate contract).

## Which old filters survive

Survive in contract:
1. Boundary-aware exclusions (`4 K`, `30 K`) for acceptance.
2. High-T regime exclusion logic (`34 K` forced removal plus `T>=30` admissibility conditions).
3. Canonical-equivalent-only perturbation class.
4. Variant-vs-canonical metric framing and forensic interpretation.

## Which old behaviors are rejected

Rejected from canonical parameter-robustness acceptance:
1. Non-equivalent perturbation families (observable redefinitions and variant-specific coordinate scaling).
2. Measurement-definition robustness metrics as a substitute for parameter-robustness acceptance.
3. Legacy run-ID locking to non-trusted input roots.

## Transferability of old conclusions

`TRANSFERABILITY=PARTIALLY_TRANSFERABLE`

Rationale:
1. Old conclusions on estimator fragility and boundary sensitivity remain meaningful when restricted to canonical-equivalent perturbations and boundary-aware admissibility.
2. Conclusions derived from non-equivalent perturbations are not transferable as canonical acceptance claims.

## Exact blockers to rerun

Current blockers (evidence-backed):
1. Wrapper executes `tools/temp_runner.m` instead of the requested target script path.
2. Current robustness script input is hardcoded to a legacy run ID, not TRUSTED_CANONICAL lock.
3. No trust-class enforcement step before loading inputs.
4. Boundary/high-T exclusion rules are not implemented in current canonical robustness script flow.
5. Canonical-equivalent parameter filtering is not enforced (script includes non-equivalent methods).
6. Variant-specific coordinate scaling is still swept.
7. Stage1B forensic metric bundle is not fully included in current canonical robustness outputs.
8. Required robustness artifact/status naming contract is not aligned with requested canonical run contract.

## Rerun allowance

`ROBUSTNESS_RERUN_READY=NO`

A rerun is not allowed under this contract until all blocker conditions are satisfied.
