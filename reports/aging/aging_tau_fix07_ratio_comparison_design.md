# AGING-TAU-FIX-07-RATIO-COMPARISON-DESIGN

## 1. Scope and exclusions

- Scope: design a guarded, future baseline Dip/FM tau ratio-comparison task derived from FIX-06 decisions.
- Exclusions: no MATLAB/Python/Node/replay execution; no tau compute/refit; no ratios; no comparison runner; no figures; no scientific interpretation.

## 2. Executive summary

After FIX-06, only design/planning is allowed for baseline Dip/FM ratio/comparison work. Execution remains blocked by run-local body dependence and PRB03 policy posture (`WARN_LINEAGE_PARTIAL`, `rows_comparison_eligible_now=0`). This design defines a strict pre-execution body-level canonicalization gate, allowed/forbidden inputs, stop conditions, and wording constraints to prevent scientific overclaim.

## 3. FIX-06 decision summary

- Governance gate closed for baseline Dip/FM lane at documentation level.
- Scientific-canonical tau use remains NO.
- Ratio readiness is PARTIAL (design-only).
- Comparison runner readiness remains NO.
- Collapse optimizer, old-fit forensic replay, and non-baseline tau remain excluded.

## 4. Allowed next task

Allowed next task name: `AGING-TAU-POST-FIX07-BODY-GATE-AND-RATIO-COMPARISON-PREFLIGHT`.

Task type: pre-execution validation and body-level canonicalization gate only.  
It may define execution prerequisites and produce readiness status artifacts, but must not compute ratios or run runner logic.

## 5. Forbidden tasks and inputs

- Forbidden tasks now: ratio computation, runner implementation/execution, scientific publication claims, cross-pathway expansion beyond baseline Dip/FM.
- Forbidden inputs for execution decisions: unregistered forensic rows, collapse optimizer products, non-baseline tau lanes, alias labels as pathway identifiers.

## 6. Pre-execution checks required

Before any future ratio execution task is allowed, all must be true:
- baseline Dip/FM pathway scope locked to `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1` and `AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`;
- row identity/co-registration keys pass (`ID_TAU_VS_TP_ROW`, shared `Tp`, shared `co_registered_group_id`);
- finite overlap domain remains exactly baseline knot set `{14,18,22,26,30,34}` unless a separately approved gate updates scope;
- PRB03 pathway policy status upgraded from WARN posture for execution context, or a formally approved guarded exception contract exists;
- body-level tau tables/sidecars are canonicalized into committed evidence or signed immutable manifests with hash-anchored provenance.

## 7. Body-level canonicalization requirement

Required gate: `BODY_LEVEL_CANONICALIZATION_GATE = PASS` before any ratio computation or runner usage.  
Minimum acceptance for PASS:
- committed or immutably registered row-body artifacts for Dip/FM baseline tau tables and sidecars;
- per-row 1:1 Dip/FM join attestations across baseline Tp domain;
- no missing/duplicate/unmatched rows in execution input set;
- explicit declaration that outputs are still governance-only unless scientific gate is separately passed.

## 8. Future task contract

Future guarded task must emit contract/status tables proving:
- input allow-list used exactly;
- excluded pathways were not touched;
- no computations performed (if preflight task) or, for later execution task, explicit authorization token exists;
- no scientific-canonical claim language unless scientific gate field is YES.

## 9. Stop conditions

Immediate stop if any of the following occur:
- any run-local-only tau body is used as canonical without canonicalization gate PASS;
- pathway scope expands beyond baseline Dip/FM;
- PRB03 comparison eligibility remains blocked and no approved exception contract exists;
- request attempts ratio or runner execution during a design/preflight-only task;
- forbidden path contamination in staged set.

## 10. Wording constraints / no-overclaim rules

Use only constrained phrasing until scientific gate passes:
- allowed: "governance-ready baseline metadata", "design-only", "pre-execution", "not scientific canonical evidence";
- forbidden: "canonical scientific tau established", "ratio validated", "runner-ready" without explicit gate PASS fields.

## 11. Final verdicts

- Ratio/comparison design task after FIX-06: YES.
- Ratio computation now: NO.
- Comparison runner now: NO.
- Required immediate next step: body-level canonicalization/pre-execution gate task, then a separate guarded execution authorization decision.
