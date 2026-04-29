# Aging — Agent-assistive enforcement (F6T)

**Version:** F6T-1.0  
**Goal:** Help agents produce **correct** Aging outputs **mechanically** through schemas, resolvers, validation modes, and fix hints. **Enforcement is assistive, not agent-blocking** in the default operating posture: diagnostic and legacy work must remain possible.

The goal is to **prevent unsafe scientific claims**, not to **prevent diagnostic work**.

## Design principles

1. **Default path:** `audit_only` or `migration` for day-to-day work; **strict** is opt-in and gated on helpers + templates.  
2. **Explicit beats implicit:** Unresolved namespace is a field value + warning, not a silent best guess.  
3. **Legacy remains readable:** Quarantine is a **label and routing rule**, not file deletion.  
4. **Every failure is actionable:** Same four-part message (what / why / fix / quarantine option) as in `aging_contract_validation_rules.md`.

## Proposed helper catalog

See `tables/aging/aging_F6T_agent_helper_templates.csv` for:

- `make_aging_sidecar_template`  
- `write_aging_observable_sidecar`  
- `resolve_aging_observable_namespace`  
- `validate_aging_observable_table`  
- `quarantine_aging_legacy_artifact`  
- `assert_aging_tau_inputs_resolved`  
- `assert_aging_cross_run_identity_match`  

## Example sidecar templates (illustrative JSON)

### 1) Structured export (single run, wide matrix)

```json
{
  "sidecar_schema_version": "F6T-1.0",
  "writer_id": "Aging/analysis/aging_structured_results_export.m#TBD_HASH",
  "writer_path": "Aging/analysis/aging_structured_results_export.m",
  "writer_role": "structured_export",
  "output_file": "observable_matrix.csv",
  "namespace": "current_export",
  "registry_id": "UNRESOLVED_USE_REGISTRY",
  "observable_name": ["Dip_depth", "Dip_depth_S4A", "FM_step_mag"],
  "formula_id": {
    "Dip_depth": "UNRESOLVED",
    "Dip_depth_S4A": "AGING-OBS-DIP-S4A-EXAMPLE",
    "FM_step_mag": "AGING-OBS-FM-EXAMPLE"
  },
  "source_run_id": "run_YYYY_MM_DD_HHMMSS_label",
  "input_artifacts": ["run_manifest.json", "stage4_output.json"],
  "input_artifact_hashes": [],
  "config_snapshot_or_hash": "UNRESOLVED",
  "code_fingerprint_or_commit": "UNRESOLVED",
  "units": "see per-column map in registry",
  "sign_convention": {"FM_step_mag": "leftMinusRight_EXAMPLE"},
  "allowed_downstream_uses": ["structured_audit", "plot_source"],
  "forbidden_downstream_uses": ["tau_R_without_column_bridge"],
  "legacy_quarantine_status": "none",
  "canonical_promotion_status": "not_canonical",
  "unresolved_fields": ["registry_id", "code_fingerprint_or_commit"],
  "suggested_next_fix": "Map each exported column to aging_F6S_registry_entries; fill formula_id and hashes."
}
```

### 2) Tau / R table (tau_Dip or R ratio)

```json
{
  "sidecar_schema_version": "F6T-1.0",
  "writer_id": "Aging/analysis/aging_timescale_extraction.m#TBD_HASH",
  "writer_path": "Aging/analysis/aging_timescale_extraction.m",
  "writer_role": "tau_extraction",
  "output_file": "tau_vs_Tp.csv",
  "namespace": "current_export",
  "registry_id": "AGING-TAU-DIP-EXAMPLE",
  "observable_name": "tau_effective_seconds",
  "formula_id": "TAU_FROM_DIP_CURVE_CONSENSUS_EXAMPLE",
  "formula_description": "Consensus fit on dip-decorrelated time series; method column in table",
  "source_run_id": "run_YYYY_MM_DD_HHMMSS_label",
  "input_artifacts": ["observables.csv", "observable_matrix.csv"],
  "tau_input_observable_identities": {
    "dip_scalar_registry_id": "AGING-OBS-DIP-S4B-001",
    "dip_namespace": "stage4_S4B",
    "dip_column_in_export": "Dip_depth"
  },
  "units": "seconds",
  "allowed_downstream_uses": ["tau_vs_Tp_plot", "R_if_numerator_identity_matches"],
  "forbidden_downstream_uses": ["compare_to_run_with_unmatched_dip_identity"],
  "legacy_quarantine_status": "none",
  "canonical_promotion_status": "not_canonical",
  "unresolved_fields": [],
  "suggested_next_fix": "If Dip column ambiguous, re-export structured results with Dip_depth_S4A/S4B tags per contract."
}
```

For `R_tau_FM_over_Dip`, add:

```json
  "ratio_numerator_identity": { "registry_id": "...", "namespace": "..." },
  "ratio_denominator_identity": { "registry_id": "...", "namespace": "..." }
```

## Compatibility loader (agents)

When opening a legacy CSV **without** sidecar:

1. Label artifact `legacy_quarantine` in the **session / validation log**, not by editing the CSV.  
2. Continue read for evidence and plots per `audit_only`.  
3. Do not promote to canonical inputs until sidecar + registry linkage exists.

## Escalation path

- **Phase A:** Warnings only (`audit_only`).  
- **Phase B:** Block **high-risk** paths (`migration`): tau/R from unresolved Dip; S4A/S4B merge; compare without identity.  
- **Phase C:** **Strict** blocks missing sidecars for **canonical_promotion_status == candidate|canonical** outputs.

See `tables/aging/aging_F6T_compatibility_strategy.csv` and `tables/aging/aging_F6T_implementation_phase_plan.csv`.
