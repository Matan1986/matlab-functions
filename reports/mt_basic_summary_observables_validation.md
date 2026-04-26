# MT Basic Summary Observables Validation (Stage 5.6)

- Source commit: `7aeddfc` (`Add MT guarded basic summary observables`)
- Source run id: `run_2026_04_26_134754_mt_real_data_diagnostic`
- Source run path: `results/mt/runs/run_2026_04_26_134754_mt_real_data_diagnostic`
- Execution status: `SUCCESS`
- Input found: `YES`
- N_T: `11`

## Validation scope

This validation documents Stage 5.5 guarded basic diagnostic summary observables only. It is a documentation/audit confirmation step and does not change executable MATLAB logic.

## Allowed observable groups emitted

Observed `observable_name` groups in `mt_observables.csv`:

- `row_count`
- `T_K_summary`
- `H_Oe_summary`
- `M_emu_clean_summary`
- `M_over_H_emu_per_Oe_summary`

## Observable row counts by name

- `row_count`: `11`
- `T_K_summary`: `33`
- `H_Oe_summary`: `44`
- `M_emu_clean_summary`: `33`
- `M_over_H_emu_per_Oe_summary`: `33`
- Total observable rows: `154`

## M/H nonzero-field guard

`M_over_H_emu_per_Oe_summary` rows are documented with a nonzero-field guard note using `H_ABS_GT_EPS_Oe`, and Stage 5.5 policy requires finite `M_over_H_emu_per_Oe` with `abs(H_Oe) > H_ABS_GT_EPS_Oe` for guarded M/H summary computation.

## Forbidden observable groups and claims (confirmed absent)

- Derivative / transition candidate observables: absent
- Mass-normalized observables: absent
- Segment comparison and `ZFC`/`FCC`/`FCW` comparison observables: absent
- `Tc` inference and phase/critical/cross-module claims: absent

## Gate summary

- `G01-G11`: `PASS`
- Gate failures table: `0` rows (header-only)

## Readiness interpretation

- `FULL_CANONICAL_DATA_PRODUCT=PARTIAL` (unchanged)
- `MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=NO` (unchanged)
- `MT_READY_FOR_ADVANCED_ANALYSIS=NO` (unchanged)
- `MT_BASIC_SUMMARY_OBSERVABLES_WRITTEN=YES`
- `MT_FORBIDDEN_OBSERVABLE_GROUPS_EMITTED=NO`
- `MT_BASIC_SUMMARY_OBSERVABLES_GATE_SUMMARY=PASS`

## Conclusion

Stage 5.5 successfully produced guarded basic diagnostic summary observables, emitted only allowed observable groups, kept forbidden groups absent, and preserved blocked production/advanced readiness.
