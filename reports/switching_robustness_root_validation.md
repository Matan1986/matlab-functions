# Switching robustness root validation

## Which components survive

The following critical components remain fundamental in the canonical robustness contract:
1. `temperature_filter` -> `PHYSICALLY_REQUIRED`
2. `parameter_filter` -> `PHYSICALLY_REQUIRED`

Evidence basis from existing artifacts:
- recovery mismatch table marks both as critical gaps.
- canonical contract keeps both as required-for-rerun controls.

## Which are replaced by canonical system

The following critical components are preserved in intent but implemented through canonical definitions:
1. `data_selection_trust` -> `CANONICAL_REPLACED`
- old run-id lock is replaced by TRUSTED_CANONICAL trust-class lock.
2. `coordinate_definition` -> `CANONICAL_REPLACED`
- old fixed collapse-coordinate rule is replaced by canonical function-space invariance for primary acceptance.

## Which are artifacts

No critical focus component is classified as `LEGACY_ARTIFACT`.

## Minimal physically valid robustness definition

A minimal physically valid canonical robustness definition (critical layer only) requires all four critical components in their validated forms:
1. Temperature admissibility filtering (boundary and high-T exclusion rules).
2. Canonical-equivalent parameter perturbation filtering.
3. Canonical trust-locked data selection (TRUSTED_CANONICAL only).
4. Canonical coordinate control (function-space primary acceptance; no coordinate sweep).

Result:
- `MINIMAL_ROBUSTNESS_DEFINED=YES`
