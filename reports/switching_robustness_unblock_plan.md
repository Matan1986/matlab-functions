# Switching robustness unblock plan

## Minimal robustness definition

Derived from the canonical contract and recovery artifacts, the minimal executable subset needed for meaningful canonical robustness execution is:
1. execution_entry_precondition
2. canonical_data_source
3. allowed_temperature_set
4. boundary_exclusions
5. high_temperature_exclusion_rule
6. allowed_parameter_perturbations
7. fixed_coordinate_and_normalization
8. stability_metric_bundle
9. acceptance_criteria
10. artifact_contract_precondition

`MINIMAL_ROBUSTNESS_SET_SIZE = 10`

## Root blockers

Severity and blocker-type classification (from repository evidence):
1. B1 wrapper executes temp runner instead of target script.
Type: execution_failure
Severity: HIGH
Depends on: none
Blocks: execution_entry_precondition, artifact_contract_precondition, acceptance_criteria
2. B2 robustness script hardcoded to legacy input run.
Type: input_mismatch
Severity: HIGH
Depends on: none
Blocks: canonical_data_source, allowed_temperature_set, forbidden_input_sources, acceptance_criteria
3. B4 boundary/high-temperature filtering rules missing in canonical robustness flow.
Type: missing_filter
Severity: HIGH
Depends on: none
Blocks: boundary_exclusions, high_temperature_exclusion_rule, transition_band_handling, stability_metric_bundle
4. B5 canonical-equivalent parameter filtering missing.
Type: missing_filter
Severity: HIGH
Depends on: none
Blocks: allowed_parameter_perturbations, rejected_parameter_perturbations, fixed_coordinate_and_normalization, stability_metric_bundle

Dependent blockers:
1. B3 missing trust-class enforcement.
Type: input_mismatch
Severity: HIGH
Depends on: B2
Blocks: forbidden_input_sources, acceptance_criteria
2. B6 variant-specific coordinate scaling still swept.
Type: coordinate_inconsistency
Severity: HIGH
Depends on: B5
Blocks: fixed_coordinate_and_normalization, stability_metric_bundle
3. B7 Stage1B forensic metric bundle missing.
Type: undefined_metric
Severity: MEDIUM
Depends on: B4, B5, B6
Blocks: stability_metric_bundle, acceptance_criteria
4. B8 output/status contract naming mismatch.
Type: execution_failure
Severity: MEDIUM
Depends on: B1
Blocks: artifact_contract_precondition, acceptance_criteria

`ROOT_BLOCKER_COUNT = 4`

## Parallel resolution batches

BLOCKER_BATCH_1 (parallel, independent roots):
1. B1 wrapper execution target mismatch
2. B2 legacy input hardcode mismatch
3. B4 missing boundary/high-T filters
4. B5 missing canonical parameter filter

BLOCKER_BATCH_2 (depends on batch 1 outcomes):
1. B3 trust-class enforcement (after B2)
2. B6 coordinate consistency enforcement (after B5)
3. B8 artifact/status contract alignment (after B1)

BLOCKER_BATCH_3 (depends on batches 1 and 2):
1. B7 Stage1B metric bundle restoration

`NUMBER_OF_BATCHES = 3`
`FIRST_BATCH_BLOCKERS = B1,B2,B4,B5`

## Estimated steps to rerun readiness

1. Resolve BLOCKER_BATCH_1 in parallel.
2. Resolve BLOCKER_BATCH_2 in parallel.
3. Resolve BLOCKER_BATCH_3.
4. Verify all 10 minimal-set components are satisfied.
5. Verify full required-for-rerun contract closure (13 required components).

`ESTIMATED_STEPS_TO_READY = 5`
