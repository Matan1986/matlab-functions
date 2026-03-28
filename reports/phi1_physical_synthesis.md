# Phi1 Physical and Observable Synthesis (Canonical, repo-first)

## Scope and constraints used

- Repo-first synthesis from existing reports/tables/scripts; no new decomposition/PT extraction pipelines were run.
- Focus is strictly on **Phi1** (dominant residual mode) and its observable interpretation.
- Phi2/kappa2 are used only as contrast when needed to test Phi1 necessity/stability.

## Part 1 - Evidence collection (Phi1-focused)

### 1) Universality across temperature

- `kappa1*Phi1` remains the dominant correction across the canonical low-T strip:
  - `tables/closure_metrics.csv`: RMSE `0.04692 -> 0.0089249` from PT-only to PT+rank1.
  - `tables/full_prediction_trajectory.csv` (aggregate row): RMSE `0.053518 -> 0.011018` (79.4% improvement).
- Per-temperature rank-1 correlation is generally high but not uniform:
  - `tables/deformation_closure_metrics.csv`: `corr_A` is mostly ~0.99 in 4-20 K, dips at 22 K (`0.7469`) and weakens at 30 K (`0.7997`).
- Interpretation: Phi1 is robustly dominant, with a known boundary anomaly band rather than global failure.

### 2) Symmetry / evenness

- No dedicated stored table with **Phi1 even/odd energy fractions** was found in root canonical tables.
- Multiple existing synthesis artifacts consistently describe Phi1 as a **broad symmetric correction**:
  - `tables/latent_to_observable_replacement_table.csv`
  - `tables/paper_safe_observable_dictionary.csv`
  - `reports/experimental_observable_replacement_report.md`
- Interpretation: symmetry evidence is consistent but mostly qualitative in currently stored canonical artifacts.

### 3) Rank structure and dominance

- `tables/rank2_metrics.csv`:
  - `sigma1/sigma2 = 6.263467`
  - `variance_mode1 = 0.959794`
  - `variance_mode1_plus_2 = 0.984259`
- `reports/closure_report.md`: rank-1 already captures most of the predictive structure; rank-2 gives smaller extra gain.
- Interpretation: residual structure is strongly rank-1 dominated, directly supporting Phi1 as the principal physical correction mode.

### 4) Geometric artifact tests

- Local shift hypothesis fails:
  - `reports/local_shift_report.md`: `RESIDUAL_IS_LOCAL_SHIFT = NO`, median corr tangent model = `-0.4760`.
- Pure low-order nonlinear backbone response fails:
  - `reports/nonlinear_response_report.md`: nonlinear Scdf model RMSE `0.031210` vs rank-1 `0.008913`.
- Interpretation: Phi1 is not a trivial coordinate/shift/scaling artifact of the PT backbone.

### 5) PT deformation and restricted-kernel interpretation

- Deformation language captures part of subleading structure but does not replace rank language:
  - `reports/deformation_closure_report.md`: deformation 3-term mean RMSE `0.00656` vs rank-2 `0.00567` and rank-1 `0.00891`.
- For Phi1 specifically, this supports that a stable dominant base mode exists and cannot be collapsed to a single simple deformation scalar.

### 6) Kernel comparisons and collapse-failure structure

- Existing kernel tests show simple families are insufficient as replacements for Phi1-driven correction:
  - shift-only and nonlinear-only fail materially vs rank-1.
- Boundary/collapse structure is concentrated near 22-24 K:
  - `reports/deformation_closure_report.md`: 22 K row is anomalous for rank-1.
  - `reports/alpha_decomposition_report.md`: residual concentration near 22 K (used as crossover consistency context).

## Part 2 - Evidence table output

- Created: `tables/phi1_evidence_summary.csv`

## Part 3 - Observable mapping audit (critical)

### What was compared in existing artifacts

- **Correlation with Phi1 amplitude** (kappa1): `S_peak`, `q90_I`, `tail_width`, tail mass.
- **Projection/reconstruction relevance**: rank-1 strip reconstruction (`kappa1*Phi1`) vs PT-only.
- **Kernel reconstruction alternatives**: local shift tangent model, nonlinear Scdf model.
- **Symmetry/map-language matching**: semantic consistency across replacement dictionary + map-language report.

### Key quantitative mapping outcomes

- Best indirect observable mapping is via **kappa1 amplitude**, not direct Phi1 field replacement:
  - kappa1 model: `tail_width + S_peak`, LOOCV RMSE `0.0184739`.
  - strip prediction remains Phi1-field dependent: rank-1 residual RMSE `0.011018` vs PT-only `0.053518`.
- Single-scalar direct proxy for Phi1: not supported in canonical tables/reports.

- Created: `tables/phi1_observable_mapping.csv`

## Part 4 - Candidate interpretation tests

### A) Phi1 is a collective response mode of the switching system

- Supporting evidence:
  - Rank-1 dominance (`variance_mode1 ~ 0.96`, large PT-only -> rank-1 RMSE drop).
  - Robust low-T predictive role in holdout/LOOCV reports.
- Contradictory evidence:
  - Boundary weakening near 22-24 K indicates non-uniformity.
- Verdict: **SUPPORTED**.

### B) Phi1 is a symmetric redistribution / susceptibility kernel around the switching ridge

- Supporting evidence:
  - Consistent map-language and dictionary classification as broad symmetric ridge correction.
  - Strong operational link of amplitude to ridge/landscape observables (`S_peak`, upper spread family).
- Contradictory evidence:
  - No dedicated stored Phi1 parity table (even/odd fraction) in canonical root outputs.
- Verdict: **PARTIAL** (physically plausible and consistent, but symmetry quantification is presently qualitative in stored artifacts).

### C) Phi1 is a deformation mode internal to PT space

- Supporting evidence:
  - Deformation coordinates can capture part of residual behavior.
- Contradictory evidence:
  - Shift-only/nonlinear-only deformation families fail.
  - Phi1-driven rank-1 term remains uniquely necessary for major error collapse.
- Verdict: **PARTIAL** (deformation contributes to language, but does not subsume Phi1).

### D) Phi1 is a purely phenomenological correction with no stable physics

- Supporting evidence:
  - Boundary anomalies show nontrivial regime dependence.
- Contradictory evidence:
  - Strong rank-1 universality, high explained variance, and stable predictive gain across independent analyses.
- Verdict: **NOT_SUPPORTED**.

## Part 5 - Final physical synthesis (plain language)

Phi1 is the dominant **shape correction** to the PT-CDF switching backbone: after barrier-distribution structure is accounted for, the largest remaining map mismatch is a broad, mostly symmetric ridge-centered redistribution. Physically, this behaves like a collective response channel of the switching strip, with temperature-dependent strength `kappa1(T)`.

Phi1 is **not**:
- a pure local shift of the backbone,
- a pure low-order nonlinear response of Scdf,
- or a one-number observable directly read off from the map.

Action on switching map:
- In `S(I,T)`, Phi1 adds the leading structured correction `kappa1(T)*Phi1(x)` to the PT backbone and removes most residual error.
- Relative to `P_T`, Phi1 captures organized response structure not encoded by barrier shape alone, although its amplitude is strongly constrained by barrier spread + map scale observables.

## Part 6 - Observable conclusions

PHI1_HAS_DIRECT_OBSERVABLE_PROXY: PARTIAL
PHI1_HAS_OBSERVABLE_SIGNATURE: YES

For the PARTIAL proxy status:
- Observable **family** exists (upper-threshold spread, map scale, ridge geometry) that predicts Phi1 amplitude well.
- A direct single-scalar proxy for the full Phi1 field is not supported.
- The robust signature is a **broad symmetric ridge correction vs PT backbone** seen on the measured map.

## Part 7 - Role in minimal model

In

`S(I,T) ≈ S_peak·CDF(P_T) + κ1·Φ1`

Phi1 is required because:
- PT backbone alone leaves a large structured residual.
- Adding `κ1·Φ1` gives the dominant error collapse (~80% relative in canonical aggregate tests).

Physical effect beyond `P_T`:
- `P_T` sets barrier occupancy/geometry backbone.
- `Φ1` captures collective redistribution of switching response along the normalized ridge coordinate that is not reducible to one PT scalar.

Why it cannot be absorbed into PT or simple geometric kernels:
- PT-only and tested simple kernel surrogates (shift-only, low-order nonlinear Scdf) underperform strongly.
- Observable-side features predict **κ1**, but the **shape field Φ1** is still needed for reconstruction.

## Final verdicts (required format)

PHI1_HAS_STABLE_PHYSICAL_INTERPRETATION: YES
PHI1_BEST_INTERPRETATION: Dominant collective ridge-redistribution mode beyond PT backbone
