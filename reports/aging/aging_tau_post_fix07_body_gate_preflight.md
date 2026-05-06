# AGING-TAU-POST-FIX07-BODY-GATE-AND-RATIO-COMPARISON-PREFLIGHT

## 1. Scope and exclusions

- Scope: baseline Dip/FM curve-fit tau body-level canonicalization preflight only.
- Exclusions: no MATLAB/Python/Node/replay; no tau compute/refit; no ratio computation; no comparison runner; no figures; no scientific ratio interpretation.

## 2. Executive summary

Committed governance metadata remains coherent (FIX-05/06/07), but baseline Dip/FM tau row-body artifacts are still referenced as run-local files under `results/aging/runs/...` and are not committed as canonical repository evidence. PRB03 baseline pathways remain `WARN_LINEAGE_PARTIAL` with `rows_comparison_eligible_now=0`. Therefore body-level canonicalization does not close in this preflight and any ratio/comparison execution remains blocked.

## 3. FIX-07 contract summary

FIX-07 requires `BODY_LEVEL_CANONICALIZATION_GATE=PASS` before any execution and keeps ratio/comparison work design or preflight only. It also requires baseline-only scope and explicit exclusion of collapse optimizer, old-fit forensic replay, and non-baseline tau.

## 4. Body-level evidence inventory

- PRB02B ledger binds baseline rows to run-local artifacts (`tau_vs_Tp.csv`, `tau_FM_vs_Tp.csv`) with stable row identity/co-registration keys.
- `git ls-files` shows no tracked baseline body artifacts in `results/aging/runs/*/tables/`.
- Local path existence checks show these files can exist locally, but local presence is not canonical committed evidence.

## 5. Comparison eligibility audit

- PRB03 pathway summary shows baseline Dip and FM each with `rows_comparison_eligible_now=0`.
- PRB03 status continues to report `RATIO_REENTRY_ALLOWED_NOW=NO` and `COMPARISON_RUNNER_READY_TO_IMPLEMENT=NO`.
- Eligibility remains policy-blocked until body promotion/canonicalization and policy upgrade are completed.

## 6. Body-level blocker decision

Decision: `BODY_LEVEL_CANONICALIZATION_CLOSED=NO`.

Rationale: required body-level artifacts are run-local references rather than committed canonical evidence, and comparison-eligible rows are still zero in committed PRB03 summary.

## 7. Remaining blockers

- Run-local-only body artifact references for baseline Dip/FM tau rows.
- PRB03 baseline WARN posture and zero comparison-eligible rows.
- No committed body-level canonical promotion package tying row bodies to FIX-05 co-registration keys as canonical execution inputs.

## 8. Allowed next task

Allowed now: `AGING-TAU-POST-FIX07-BODY-PROMOTION-AND-CANONICALIZATION-PACKAGE` (governance packaging task) to promote or immutably register baseline Dip/FM body artifacts and produce a committed body-canonicalization manifest plus eligibility update evidence.

## 9. Forbidden tasks

- Ratio execution.
- Comparison runner execution.
- Any collapse optimizer pathway usage.
- Any old-fit forensic replay usage.
- Any non-baseline tau expansion.

## 10. Final verdicts

- Body-level canonicalization closed: NO.
- Safe to run ratios after this gate: NO.
- Safe to run comparison runner after this gate: NO.
- Next body-promotion task required: YES.
