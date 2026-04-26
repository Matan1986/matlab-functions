# MT Stage 5.1 - Derivative policy design for candidate transition observables

## Purpose and scope

This artifact defines the derivative-policy contract required by Stage 5.0 before any transition-shape observable can be implemented. It is design-only: no computation, no MATLAB execution, and no physics claims.

## Inputs in scope

The policy is written against existing point-table columns:

- `T_K`
- `time_s`
- `time_rel_s`
- `M_emu_clean`
- `dM_dT_emu_per_K`
- `dM_dt_emu_per_s`
- `dT_dt_K_per_s`
- `segment_id`
- `segment_type`
- `segment_source`

## Independent variable policy

1. Default independent variable for transition-shape candidates is `T_K`.
2. Candidate transition derivatives must be interpreted as `dM/dT`-family quantities only.
3. `dM/dt` is allowed only as a timing diagnostic channel and must not substitute for transition-shape metrics.
4. `time_s` is an imported channel and must not be treated as elapsed time; elapsed semantics require explicit `time_rel_s`.
5. If `T_K` is nonmonotonic inside a derivative scope, derivative outputs are blocked unless policy-approved segment split resolves monotonic subscopes.

## Segment policy

1. Derivative calculations are segment-scoped by `file_id + segment_id` and annotated by `segment_type`.
2. Cross-segment derivative computation is forbidden.
3. `segment_type=UNKNOWN` may be used only for basic diagnostic derivative checks (for example coverage and finite-value rate), not for ZFC/FCC/FCW interpretation.
4. Segment provenance (`segment_source`) must be recorded in observable provenance metadata.

## Windowing and smoothing policy

1. Allowed derivative methods at design stage:
   - local central finite difference in `T_K`;
   - local robust slope fit (for example linear robust fit) over a bounded `T_K` window.
2. Default source channel is `M_emu_clean`.
3. `M_emu_smooth` is exception-only and allowed only when explicitly declared in observable provenance (`source_columns`, method name, and smoothing parameters).
4. Minimum local window is 3 points for central-difference style methods.
5. Minimum local window is 5 points for robust-slope style methods.
6. Minimum total points per derivative segment scope is `N_points >= 7`; otherwise derivative candidates are blocked with `INSUFFICIENT_POINTS`.

## Nonuniform sampling policy

1. Nonuniform `T_K` spacing must be measured and reported per derivative scope.
2. Pause gaps in `time_s` do not by themselves invalidate `dM/dT` if `T_K` ordering and spacing checks pass.
3. Derivative candidates are blocked when `T_K` spacing is degenerate (repeated or near-zero deltas beyond tolerance) or too sparse for the declared method.
4. No silent interpolation is allowed. Interpolation requires a separate approved interpolation policy artifact and explicit provenance declaration.
5. Any method that regrids `T_K` must be treated as interpolation and therefore blocked under Stage 5.1 unless the interpolation policy gate is opened.

## Candidate transition outputs covered by this policy

The policy supports design-time gating for the following candidate-only outputs:

- `dM/dT` peak candidate
- `T` at max `abs(dM/dT)` candidate
- transition width candidate
- transition midpoint candidate

All remain candidate-only and cannot be used to claim phase-transition temperatures or critical behavior.

## Allowed outputs and interpretation boundary

Allowed output language is restricted to:

- algorithm-labeled candidate diagnostics;
- quality-qualified feature descriptors;
- method- and scope-dependent observations.

Forbidden interpretation includes:

- `Tc` claims;
- phase transition temperature claims;
- equilibrium transition assertions;
- critical behavior or universality claims;
- latent heat claims;
- cross-module claims.

## Readiness and gate interaction

Derivative policy compliance is necessary but not sufficient for readiness promotion.

- Stage 5.1 sets derivative policy definition to YES.
- Stage 5.1 keeps implementation readiness NO.
- Stage 5.1 keeps advanced-analysis readiness NO.
- Transition outputs remain candidate-only.

## Artifact map

- `tables/mt_derivative_policy_rules.csv`
- `tables/mt_derivative_policy_quality_gates.csv`
- `tables/mt_derivative_policy_forbidden_claims.csv`
- `status/mt_derivative_policy_design_status.txt`
