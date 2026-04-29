# Switching governance persistence manifest

This manifest is the durable anti-confusion source for old-vs-new Switching canonical governance.

## Non-negotiable governance facts

1. `run_switching_canonical.m` is a mixed producer.
2. `S_percent` is `CANON_GEN_SOURCE` and remains valid as canonical `S` input.
3. `I_peak`, `S_peak`, `W`/`width` are `CANONICAL_EFFECTIVE_OBSERVABLE` only if validated.
4. `S_model_pt_percent`, `PT_pdf`, and `CDF_pt` are `EXPERIMENTAL_PTCDF_DIAGNOSTIC`.
5. `residual_percent`, `S_model_full_percent`, `switching_canonical_phi1.csv`, and canonical `kappa1` are `DIAGNOSTIC_MODE_ANALYSIS` and are forbidden as `CORRECTED_CANONICAL_OLD_ANALYSIS` manuscript evidence.
6. Authoritative `CORRECTED_CANONICAL_OLD_ANALYSIS` artifacts do not yet exist.
7. Corrected-old build is blocked until recipe/provenance verification and authorized generation.
8. Existing attempted `corrected_old` outputs/figures are quarantined unless proven authoritative.

## Durable source-of-truth pointers

- Namespace contract and claim boundaries: `docs/switching_analysis_map.md`
- Namespace declaration template: `docs/templates/switching_analysis_namespace_header.md`
- Old-vs-new source-of-truth map: `tables/switching_old_new_namespace_source_of_truth_map.csv`
- Classification verdict status: `tables/switching_analysis_classification_status.csv`
- Old recipe verification status: `tables/switching_old_recipe_verification_status.csv`
- Persistence hardening plan: `reports/switching_anti_confusion_persistence_hardening_plan.md`
- Persistence hardening plan matrix: `tables/switching_anti_confusion_persistence_hardening_plan.csv`

## Scope lock

- `PHYSICS_LOGIC_CHANGED=NO`
- `FILES_DELETED=NO`
