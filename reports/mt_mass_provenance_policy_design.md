# MT Stage 5.2 - Mass/provenance policy design for normalization-dependent observables

## Purpose and scope

This Stage 5.2 artifact defines the policy boundary that must be satisfied before normalization-dependent observables are allowed for interpretation. This is design-only and does not implement computation.

Covered normalized quantities:

- `M_norm_emu_per_g`
- `chi_mass_emu_per_g_per_Oe`

## Accepted provenance source classes

Mass provenance source classes are ordered by trust level:

1. **Accepted-primary:** explicit sample metadata table keyed by sample identity.
2. **Accepted-primary:** manually curated sample registry with audited sample mapping.
3. **Accepted-provisional:** instrument header-derived mass, allowed only as provisional evidence and must be flagged as provisional in provenance fields.
4. **Forbidden by default:** filename-derived mass.
   - Filename-derived mass is allowed only after explicit audit artifact approval and recorded waiver.

## Identity attachment policy

Mass identity attachment must prefer stable sample-level keys:

1. Preferred key: `sample_id`.
2. Allowed fallback: curated `file_id -> sample_id` mapping table when direct `sample_id` is unavailable.
3. Run-level (`run_id`) may scope audit batches but must not be the sole identity key for assigning mass.
4. Row-level `sample_mass_g` is allowed only as propagated metadata from sample/file mapping and is not an independent per-row measurement.

## Consistency and validity requirements

Mass provenance must satisfy all checks before normalized observables can move beyond blocked state:

1. `sample_mass_g` finite.
2. `sample_mass_g > 0`.
3. Unit explicitly recorded as `g`.
4. Provenance source class recorded and accepted.
5. No silent default mass (for example implicit 1 g).
6. Mass internally consistent for all files mapped to the same sample under tolerance policy.
7. Replicated row-level mass values must match mapped sample/file mass and not drift within a file.

## Missing mass behavior policy

When mass provenance is missing or rejected:

1. `M_norm_emu_per_g` must be `NaN` or hard-blocked.
2. `chi_mass_emu_per_g_per_Oe` must be `NaN` or hard-blocked.
3. Any observables using normalized columns must remain `BLOCKED_PENDING_PROVENANCE`.
4. No fallback conversion may reinterpret raw `M_emu` or `M/H` as normalized output.

## Allowed normalized outputs and interpretation limits

Allowed normalized outputs are descriptive proxies only:

- `M_norm_emu_per_g`
- `chi_mass_emu_per_g_per_Oe`

These outputs are not sufficient for absolute-material claims unless additional composition, demagnetization, and calibration policy gates are introduced in future stages.

## Forbidden claims boundary

The following claims are forbidden at Stage 5.2:

- spin-only moment per Co
- `muB/Co`
- stoichiometric magnetization
- absolute susceptibility
- demagnetization-corrected susceptibility
- direct comparison to theoretical moments
- sample homogeneity claims based on normalized outputs alone

## Readiness gates (policy intent)

Mass/provenance policy requires all of the following:

- point-table gates pass;
- accepted provenance source class;
- valid sample/file mapping;
- finite positive mass;
- cross-file consistency for same sample;
- explicit grams unit;
- no filename-derived mass without audit waiver;
- normalized outputs blocked when mass missing;
- `chi_mass` additionally guarded by nonzero field.

## Readiness impact

Stage 5.2 defines policy and gates but does not unlock implementation or advanced analysis.

- `MT_READY_FOR_MASS_PROVENANCE_IMPLEMENTATION=NO`
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO`
- `MT_NORMALIZATION_OBSERVABLES_BLOCKED_WITHOUT_MASS=YES` remains required.

## Artifact map

- `tables/mt_mass_provenance_policy_rules.csv`
- `tables/mt_mass_provenance_quality_gates.csv`
- `tables/mt_mass_provenance_forbidden_claims.csv`
- `status/mt_mass_provenance_policy_status.txt`
