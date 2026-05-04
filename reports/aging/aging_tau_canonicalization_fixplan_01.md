# AGING-TAU-CANONICALIZATION-FIXPLAN-01

## 1. Scope and exclusions
- Fix-plan only for baseline Dip/FM tau canonicalization lane.
- No code changes, no MATLAB/Python/Node/replay execution, no new tau/refit/ratios/figures.
- No canonicalization work for collapse-optimizer tau, old-fit forensic tau, or ratio-derived tau.

## 2. Executive summary
Baseline Dip/FM tau pathways are structurally well-defined but remain blocked by lineage-closure tokens, FM convention/policy gating, and partial row-identity/co-registration readiness. The minimal plan is a six-task sequence: close shared dataset lineage, close Dip branch, close FM branch, harden sidecars/naming guards, close row-identity co-registration layer, and run an audit-only canonical readiness gate.

## 3. Baseline tau lane being targeted
- `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`
- `AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`

Lane definition:
consolidated aging signal -> Dip/FM component extraction -> component observable vs wait time -> curve-fit tau -> tau sidecar / row identity / canonical eligibility.

## 4. Excluded non-canonical tau lanes
- `AGN_WF_CONSOL_DS_DIP_DEPTH_COLLAPSE_OPTIMIZER_V0` (collapse-optimizer tau lane)
- `AGN_WF_FORENSIC_OLD_FIT_REPLAY_F6_V0` (forensic old-fit/replay lane)
- Any ratio-derived tau lane
- Any new tau candidate not already in baseline Dip/FM registry lane

## 5. Current readiness state
- Dip canonical readiness now: PARTIAL
- FM canonical readiness now: PARTIAL
- Tau canonical set ready now: NO
- PRB03 pathway summaries remain WARN lineage partial for both baseline pathways.

## 6. Shared blockers
Shared blockers include canonical source dataset identity closure, decomposition provenance hardening, partial-grid component-row policy, partial row-identity bridge, partial co-registration eligibility, and policy statuses still at WARN lineage partial.

## 7. Dip-specific blockers
Dip blockers are concentrated in unresolved dataset-path plus Dip-branch lineage token (`REQUIRES_DATASET_PATH_AND_DIP_BRANCH_RESOLUTION`), non-canonical artifact status token, and missing canonical closure semantics for Dip branch/component-definition.

## 8. FM-specific blockers
FM blockers are concentrated in pending policy hardening token (`LINEAGE_METADATA_HARDENED_PENDING_F7S`), unresolved FM convention closure (`FM_abs` magnitude/signed-source semantics), and downstream conservative policy flags that keep FM rows non-canonical.

## 9. Sidecar / row identity / policy blockers
Both baseline sidecars have required fields but not canonical-complete lineage tokens. PRB02B identity layer is still PARTIAL (`ID_BRIDGE_CO_REGISTERED_SATISFIED=PARTIAL`). PRB03 status remains conservative (`BASELINE_*_BUNDLE_STATUS=WARN_LINEAGE_PARTIAL`), preventing canonical evidence promotion.

## 10. Minimal ordered fix sequence
1. `AGING-TAU-FIX-01-SHARED-DATASET-LINEAGE`
2. `AGING-TAU-FIX-02-DIP-COMPONENT-BRANCH`
3. `AGING-TAU-FIX-03-FM-COMPONENT-BRANCH`
4. `AGING-TAU-FIX-04-SIDECAR-HARDENING`
5. `AGING-TAU-FIX-05-ROW-IDENTITY-COREGISTRATION`
6. `AGING-TAU-FIX-06-CANONICAL-READINESS-GATE`

This sequence is intentionally serial for governance safety.

## 11. Dependency graph
See `tables/aging/aging_tau_canonicalization_fixplan_01_dependency_graph.csv`. Every downstream task has a hard dependency on preceding lineage/metadata closure tasks.

## 12. Readiness targets
See `tables/aging/aging_tau_canonicalization_fixplan_01_readiness_targets.csv`. Targets define pass/fail closure for Dip, FM, and joint tau-set readiness, while keeping ratio and comparison-runner readiness out of scope.

## 13. What remains forbidden after this fix plan
Even after this plan artifact is complete, the following remain forbidden until future explicit clearance tasks: tau recomputation, tau refits, replay execution, ratio execution, and comparison-runner execution.

## 14. Final verdicts
A minimal and evidence-anchored fix plan exists for canonicalizing only the baseline Dip/FM tau lane. The blockers are explicit, classified, and mapped to six ordered tasks with hard dependencies. Current state remains non-canonical for evidence use and unsafe for ratios/comparison runner until the proposed tasks are executed and the final readiness gate passes.
