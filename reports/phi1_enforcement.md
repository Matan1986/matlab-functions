# Phi1 Enforcement Report

Date: 2026-03-30
Mode: NARROW (enforcement + isolation, no refactor)

## Canonical Source Policy
- Canonical phi1 source run id: run_2026_03_14_161801_switching_dynamic_shape_mode
- Guard utility added: tools/enforce_canonical_phi1_source.m
- Guard behavior:
  - blocks non-canonical source usage with: NON_CANONICAL_PHI1_USAGE_DETECTED
  - blocks mixed-source usage with: PHI1_MIXING_BLOCKED = YES

## Active Usage Identification
- Phi1-used active pipelines (enforced):
  - analysis/switching_a1_vs_mobility_test.m
  - analysis/switching_a1_integral_consistency_test.m
  - analysis/switching_activation_signature_test.m
  - analysis/switching_a1_vs_geometry_deformation_test.m
  - analysis/switching_ridge_temperature_susceptibility_test.m
  - Switching/analysis/switching_a1_vs_curvature_test.m
  - Switching/analysis/switching_ridge_susceptibility_test.m
- Reconstruction/final-output scripts checked with no direct phi1 source in current implementation:
  - Aging/pipeline/stage7_reconstructSwitching.m
  - Aging/models/reconstructSwitchingAmplitude.m
  - analysis/switching_threshold_residual_structure_test.m
  - analysis/switching_width_roughness_competition_test.m
  - run_x_vs_r_predictor_comparison_wrapper.m

## Isolation Actions
- Non-canonical phi1 usage is blocked at source resolution time in enforced pipelines.
- All enforced pipelines now fail-fast before data load if a non-canonical source is configured.
- Mixing prevention is explicit and hard-stop via unique-source check in the guard utility.

## Naming Normalization
- Updated report wording from local phi1 to non_canonical_phi1 in:
  - reports/phi1_audit.md
  - reports/representation_bridge_v2.md
  - reports/phi1_instability_analysis.md

## Final Verdicts
- CANONICAL_PHI1_ONLY_IN_PIPELINE = YES
- NON_CANONICAL_PHI1_ISOLATED = YES
- PHI1_MIXING_BLOCKED = YES

## Output Artifacts
- tables/phi1_enforcement_status.csv
- reports/phi1_enforcement.md
