# Aging semantic naming taxonomy (draft, F6V)

**Stable reference (F6W):** Use `docs/aging/aging_semantic_naming_taxonomy.md` for agent-facing terminology; this draft remains historical context from discovery.

**Status:** draft — separate **provenance** from **observable definition**. Do not treat this file as enforced registry text until F6W governance.

## Provenance / status (non-measurement)

| Label | Role |
|-------|------|
| `legacy_old` | Pre-contract runs; implicit formulas allowed only with bridge metadata |
| `current_export` | Active writer outputs; needs sidecar for identity |
| `canonical_candidate` | Parity/review passed; not yet ratified |
| `canonical` | Registry-ratified row only with governance metadata |
| `diagnostic` | Smoke / audit; unstable definitions |
| `deprecated` | Superseded; migration only |
| `unknown` | Explicit gap |
| `legacy_quarantine` | Session routing for artifacts without sidecars (read as evidence) |

## Observable definitions (measurement-scoped)

### Dip family (examples)

| Draft semantic name | Intended meaning | Notes |
|-----------------------|------------------|-------|
| `Dip_depth_afm_amp_residual_height` | Scalar from `Dip_depth_source=afm_amp_residual` | Align with **stage4_S4A** namespace when sources match |
| `Dip_depth_raw_deltam_window_max_noncanonical` | `max(DeltaM_observable)` in dip window; `Dip_depth_source=raw_deltam_window_metric_noncanonical` | Align with **stage4_S4B** |
| `dip_signed_residual` | `DeltaM_signed - DeltaM_smooth` decomposition path | Not the same as exported plain `Dip_depth` unless bridged |

When evidence is incomplete, prefer **`Dip_depth_definition_A_UNRESOLVED`** / **`Dip_depth_definition_B_UNRESOLVED`** placeholders over invented physics names.

### Tau / ratio family

| Draft label | Meaning |
|-------------|---------|
| `tau_eff_seconds_from_<dip_definition_id>` | Any fitted tau tied to a resolved dip scalar |
| `tau_eff_FM_<convention_id>` | FM timescale with signed/abs convention explicit |
| `R_age_tau_FM_over_tau_dip` | Scalar aging ratio; **not** Relaxation `R_relax` |

### Summary / alias (Track A style)

| Label | Role |
|-------|------|
| `AFM_like` | Parity summary mirror of dip-area family — alias policy, not raw AFM_amp |
| `FM_like` | Parity summary mirror of FM_E family — alias policy, not raw FM_step_mag |

## Cross-reference

- Namespace binding: `docs/aging/aging_namespace_contract.md`
- Observable registry: `docs/aging/aging_observable_registry_contract.md`
