# Phi1 Audit (Canonical Enforcement + Classification)

## Scope
- Mode: NARROW (audit + classification + safe normalization)
- Logic changes: none
- MATLAB rerun: none
- Evidence basis: existing repository artifacts only

## Classification Rules Applied
- CANONICAL: Phi1 usage tied to strict LOTO/no-leakage canonical residual decomposition and reconstruction success evidence.
- NON_CANONICAL: derived, subset/intersection, proxy, or bridge usage not satisfying canonical construction conditions.
- MISLABELED: uses "non_canonical_phi1" naming target for non-canonical artifacts; normalized in safe-rename recommendations.

## High-Confidence Evidence
- Canonical enforcement evidence:
  - reports/canonical_reconstruction.md (LOTO protocol; PHI1_IMPROVES_RECONSTRUCTION = YES; 14/14 improvement)
  - tables/canonical_reconstruction_status.csv (mean_RMSE_PT=0.06957 -> mean_RMSE_FULL=0.01937; improve=14/14)
  - Switching/analysis/switching_residual_decomposition_analysis.m (canonical interpretation window T<=30 K)
- Mixed usage evidence:
  - reports/phi1_instability_analysis.md (explicitly states two non-equivalent Phi1 pipelines)
  - reports/switching_pipeline_stability.md (conflict canonical YES vs local NO -> PHI1_STABLE=NO)
- Non-canonical/local mismatch evidence:
  - tables/phi1_bridge_metrics_v2.csv (cosine_local_vs_legacy=0.6961; explained_variance_local_phi1=0.4169; sign_consistency=0.75)
  - reports/reconstruction_v1.md (LOCAL_IMPROVES_OVER_PT=NO; PT_PLUS_LOCAL worse than PT_ONLY)

## Safe Naming Normalization (Metadata/Report Only)
The following naming normalization is applied as recommendations in the audit table only:
- "non_canonical_phi1" is the required label for non-canonical variants.

Examples in tables/phi1_audit.csv:
- reports/kappa1_phi1_local_v2_20260329_234420.md -> reports/non_canonical_phi1_v2_20260329_234420.md
- tables/kappa1_phi1_local_v2_20260329_234420.csv -> tables/kappa1_non_canonical_phi1_v2_20260329_234420.csv
- tables/phi1_local_shape_v2_20260329_234420.csv -> tables/non_canonical_phi1_shape_v2_20260329_234420.csv

No numerical logic, executable behavior, or source algorithms were changed.

## Final Verdicts (Mandatory)
- TOTAL_PHI1_INSTANCES = 45
- CANONICAL_COUNT = 12
- NON_CANONICAL_COUNT = 24
- MISLABELED_COUNT = 9
- PHI1_MIXING_DETECTED = YES
- CANONICAL_PHI1_ENFORCED = YES

## Output Artifacts
- tables/phi1_audit.csv
- tables/phi1_audit_status.csv
- reports/phi1_audit.md
