# MT Basic Summary Visualization Design (Stage 5.7)

- Scope stage: `5.7`
- Scope type: design/documentation only
- MATLAB execution: not performed in this stage
- Canonical logic changes: none
- Readiness impact: no change (`MT_READY_FOR_ADVANCED_ANALYSIS=NO`)

## Purpose

Define a safe review and visualization design for Stage 5.5 basic diagnostic summaries without transition, Tc, hysteresis, mass-normalized, segment-comparison, or cross-module interpretation.

## Allowed inputs and preconditions

Visualization design is valid only when all of the following are true for the selected canonical run:

- `EXECUTION_STATUS=SUCCESS`
- `INPUT_FOUND=YES`
- Point-table gates `G01-G11` are all `PASS`
- Point-table gate failures table has zero data rows
- `MT_BASIC_SUMMARY_OBSERVABLES_WRITTEN=YES`
- `MT_FORBIDDEN_OBSERVABLE_GROUPS_EMITTED=NO`
- `MT_BASIC_SUMMARY_OBSERVABLES_GATE_SUMMARY=PASS`
- `FULL_CANONICAL_DATA_PRODUCT=PARTIAL` (accepted boundary)

If any precondition fails, visualization is blocked and should be reported as a data-quality/process issue, not a physics result.

## Allowed review tables and plots

Only the following basic summary review artifacts are allowed in Stage 5.7:

1. Row coverage per file (`row_count`)
2. `T_K` min/max/span per file (`T_K_summary`)
3. `H_Oe` nominal/min/max/span per file (`H_Oe_summary`)
4. `M_emu_clean` min/max/span per file (`M_emu_clean_summary`)
5. `M_over_H_emu_per_Oe` min/max/span per file with nonzero-field guard (`M_over_H_emu_per_Oe_summary`)
6. Table-based sanity review of quality flags and provenance fields

Recommended display posture:

- File-level faceted bars/tables for coverage and span diagnostics
- No smoothing/inference overlays
- Explicit legends that state "diagnostic summary only"

## Interpretation constraints (what these views mean)

Allowed meaning:

- Coverage completeness by file and temperature group
- Value-range sanity and scale checks
- Instrument/processing consistency checks within canonical boundaries

Not allowed meaning:

- Transition detection
- Physical mechanism inference
- Order parameter behavior
- Critical scaling behavior
- Thermodynamic path claims

## Explicitly forbidden in Stage 5.7

- `dM/dT` or other derivative plots
- Transition markers or candidate transition annotation
- `Tc` markers or any transition temperature estimate
- Phase transition, criticality, or universality claims
- Mass-normalized plots (including `chi_mass`)
- Segment split/comparison (`ZFC`/`FCC`/`FCW`)
- Hysteresis-like comparison panels
- Cross-module claims or coupling claims

## Guard text requirements for any figure/table

Every Stage 5.7 review output should include all guard statements:

- "Diagnostic summary view only."
- "Not valid for Tc/transition/critical or hysteresis interpretation."
- "Mass-normalized and segment-comparison analyses are out of scope."
- "Readiness remains blocked for advanced analysis."

## Recommended implementation stage (future)

Implement rendering in a later stage (recommended Stage `5.8`) with:

- Deterministic ingestion from `mt_observables.csv` and status flags
- Pre-render gate checks (block rendering when prerequisites fail)
- Auto-applied guard banner text in all outputs
- Fixed registry-driven chart definitions from `tables/mt_basic_summary_visualization_registry.csv`

Stage 5.7 itself is complete when design artifacts exist and status is set to design complete, implementation not ready.
