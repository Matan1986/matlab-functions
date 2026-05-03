# Aging F7V — Fit-vs-direct decomposition alignment charter

## Purpose

Read-only **alignment charter** that defines **which fit-based (Track A) and direct/non-fit (stage4 / consolidation Track B–style) decomposition outputs may be compared**, under what **semantic contracts**, and what **bridges** are required **before** multipath clock-ratio robustness work. This document **does not** execute ratios, extract tau, rerun decomposition, implement bridges, rank branches, or interpret physics.

## Anchors

- **F7U** survey: `a18efb7` — Survey Aging F7U decomposition tau paths  
- **Governance:** `docs/aging_measurement_definition_freeze.md`, `reports/aging/aging_F7J_observable_definition_scope_map.md`  
- **Baseline ratio charter:** F7T (`c702cea`)

## Executive conclusions

1. **Identity equivalence** between Track A summary names (`AFM_like`, `FM_like`, `Dip_area_selected`, `FM_E`) and consolidation columns (`Dip_depth`, `FM_abs`) is **forbidden** per the measurement freeze — not **DIRECTLY_COMPARABLE**.

2. **Legal alignment** for scientific comparison requires **`COMPARABLE_AFTER_BRIDGE`**: explicit bridges that preserve lineage, sign visibility, and grid semantics (see `tables/aging/aging_F7V_required_bridge_contract.csv`).

3. **Baseline F7T-style ratio** on hardened **`tau_FM_vs_Tp`** + explicit **`tau_vs_Tp`** remains **technically allowed** as a **narrow bookkeeping lane** (`YES_BASELINE_ONLY`); it does **not** satisfy the **multipath robustness goal** until bridges and paired tau paths exist.

4. **Multipath ratio robustness execution** is **not ready now**; **partially** feasible **after** bridge implementation and tau-path closure (`tables/aging/aging_F7V_status.csv`).

## Component semantics

Authoritative rows: `tables/aging/aging_F7V_component_semantic_contracts.csv`.

## Fit–direct pair decisions

Authoritative rows: `tables/aging/aging_F7V_fit_direct_pair_comparability.csv`.

## Forbidden substitutions

Authoritative rows: `tables/aging/aging_F7V_forbidden_substitutions.csv` (echoes freeze).

## Tau readiness

Per-component tau path assessment: `tables/aging/aging_F7V_tau_readiness_by_component_path.csv`.

## Candidate ratio routes (declarative)

`tables/aging/aging_F7V_candidate_ratio_route_readiness.csv` — **no numerics**.

## Next-step options

See `tables/aging/aging_F7V_next_step_decision.csv`. Recommended ordering: **resolve semantic/export bridges (E/A)** before treating multipath ratio execution as scientifically grounded.

## Machine-readable verdicts

`tables/aging/aging_F7V_status.csv`.
