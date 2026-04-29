# Aging — Writer output and lineage sidecar enforcement plan (F6T)

**Version:** F6T-1.0  
**Depends on:** F6S observable registry and namespace contract (frozen).  
**Purpose:** Turn F6S policy into an **agent-assistive** implementation roadmap: sidecars, validation modes, checks, helpers, and phased rollout **without** changing analysis logic in F6T.

## Executive summary

- **Writers inventoried:** See `tables/aging/aging_F6T_writer_sidecar_inventory.csv` (representative catalog of scripts/functions that emit observables, matrices, tau/R, pooled tables, diagnostics). The repo should **re-run inventory grep** when adding validators (`writetable`, `save_run_table`, export helpers).  
- **Sidecar schema:** Defined in `docs/aging/aging_lineage_sidecar_schema.md` and field-by-field in `tables/aging/aging_F6T_sidecar_schema_fields.csv`.  
- **Validation modes:** `audit_only`, `migration`, `strict` — detail in `tables/aging/aging_F6T_validation_modes.csv`.  
- **Strict mode:** Deferred until helpers/templates and migration paths exist (per F6S).  
- **Next F6U task:** `F6U_AUDIT_ONLY_AGING_CONTRACT_VALIDATOR` — see `tables/aging/aging_F6T_next_task_decision.csv`.

## Inventory method (how the table was built)

1. Search under `Aging/` for `writetable(` and `save_run_table(`.  
2. Include root-level `run_aging_*.m` that write under `results/` or `tables/aging/`.  
3. **Exclude** by scope: Switching-only scripts that mention Aging paths (not Aging writers).  
4. Classify **writer_role** by primary artifact type.

## Output classes and rules

See `tables/aging/aging_F6T_output_class_rules.csv` for per-class requirements (sidecar, registry, namespace, warnings, strict behavior, audit-only pass).

## Validation checks

See `tables/aging/aging_F6T_validation_checks.csv`. Mandatory F6T checks include plain `Dip_depth` rejection for tau/R inputs, S4A/S4B merge bridge, cross-run identity, pooled sidecars, tau/R namespace guards, FM sign warning, legacy quarantine, canonical promotion, and full ratio identity for `R_tau_FM_over_Dip`.

## Agent helpers

See `docs/aging/aging_agent_assistive_enforcement.md` and `tables/aging/aging_F6T_agent_helper_templates.csv`.

## Compatibility

See `tables/aging/aging_F6T_compatibility_strategy.csv`.

## Implementation phases

See `tables/aging/aging_F6T_implementation_phase_plan.csv` (Phases 0 through 7).

## Related documents

| Document | Role |
|----------|------|
| `docs/aging/aging_namespace_contract.md` | Namespace binding |
| `docs/aging/aging_observable_registry_contract.md` | Identity fields |
| `docs/aging/aging_writer_output_contract.md` | Writer obligations |
| `docs/aging/aging_lineage_sidecar_schema.md` | Sidecar fields |
| `docs/aging/aging_contract_validation_rules.md` | Validator message contract |
| `reports/aging/aging_F6T_writer_output_lineage_sidecar_enforcement_plan.md` | Report |

## Code changes in F6T

**None.** Documentation and planning tables only.
