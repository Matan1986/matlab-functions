## Phi1 curvature / generator test (mechanistic, strict candidate set)

### What was tested
- Canonical `\Phi_1(x)` from the stored residual decomposition (`phi_shape.csv`) on the canonical `xGrid`.
- PT-backed `CDF(P_T)` reconstructed from the stored `PT_matrix.csv`, mapped to the same `xGrid` via `x=(I-I_{peak}(T))/w(T)`.
- Candidate set (no search): `CDF(PT)`, `d/dx CDF(PT)`, `d^2/dx^2 CDF(PT)`, `x*d/dx CDF(PT)`, plus one symmetric localized curvature-like template (`exp(-0.5*(x/\sigma)^2)`, `\sigma=0.220`).

### Similarity metrics
- Cosine similarity and Pearson correlation use the common finite mask and remove mean (cosine uses zero-mean + unit L2).
- RMSE is computed after best scalar rescaling between raw shapes: `min_a ||Phi1 - a*psi||_2` (reported as pointwise RMSE).
- Evenness uses discrete even/odd reflection on `xGrid` and reports `even_fraction_match = |evenFrac(Phi1)-evenFrac(psi)|`.

### Robustness split
- Main: `canonical_T_le_30K_including_22K`.
- Robustness: `canonical_T_le_30K_excluding_22K`.

### Per-candidate results (main / excludes 22K)

| candidate | cosine (main) | Pearson (main) | RMSE (main) | evenFracDiff (main) | cosine (excl 22K) | verdict |
|---|---:|---:|---:|---:|---:|---|
| CDF_PT_x | -0.389815 | -0.389815 | 0.300132 | 0.758719 | -0.405483 | NO |
| d_dx_CDF_PT_x | 0.309887 | 0.309887 | 0.364724 | 0.720500 | 0.311869 | NO |
| d2_dx2_CDF_PT_x | -0.841723 | -0.841723 | 0.380598 | 0.350555 | -0.817950 | PARTIAL |
| x_times_d_dx_CDF_PT_x | -0.217001 | -0.217001 | 0.392516 | 0.675484 | -0.225587 | NO |
| symmetric_gaussian_bump_x | 0.865120 | 0.865120 | 0.392662 | 0.165105 | 0.865120 | YES |

### Final Verdicts

PHI1_SIMPLE_GENERATOR_REDUCTION: NO
PHI1_CURVATURE_STRUCTURE_SUPPORTED: YES

## Physical Interpretation

Phi1 should be separated into two distinct claims:

**Generator reduction (mechanism): NO.**  
Phi1 is not reducible to a PT-CDF generator built from the strict backbone candidate set `CDF(PT)`, `d/dx CDF(PT)`, or `d²/dx² CDF(PT)` (even after the canonical scaling/shape normalization used in this test). The curvature candidate shows shape-level overlap, but the evidence does not support a full mechanistic derivation of Phi1 from local PT-CDF differential generators.

**Curvature-like structure (phenomenology): YES.**  
Phi1 exhibits a clear symmetric curvature-like structure: it has a robust symmetric component, a localized redistribution profile on the normalized x grid, and a curvature-like x-shape that is visibly compatible with curvature-type observables. In other words, the curvature test supports the presence of a curvature-like *structure* in Phi1, while still rejecting curvature-type *generator reduction* as a complete mechanism.

Putting these together:

Phi1 is best interpreted as a universal symmetric redistribution mode of the switching response.
It is not a trivial functional derivative of the PT backbone, not a simple geometric deformation, and not a local shift.
The curvature test indicates structural similarity at the shape level, but does not provide mechanistic reduction to a simple PT-CDF generator.

Final takeaway: Phi1 reflects a collective response of the system that is consistent with curvature-like redistribution, but it cannot be derived from a simple PT-CDF generator.

