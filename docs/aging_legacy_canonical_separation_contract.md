# Aging legacy/canonical semantic separation contract

## Purpose

This contract prevents semantic contamination between old/noncanonical Aging artifacts and canonical/replay Aging artifacts.

Scope:

- Aging only.
- Governance/documentation only.
- No producer modifications implied.
- No new physics claims.
- Cross-module claims are out of scope.

## Required namespaces

All old/new comparison or replay artifacts MUST use the following names (or strict supersets with equivalent suffixing):

- `DeltaM_old`
- `DeltaM_canon_map`
- `AFM_like_old`
- `AFM_like_replay_TrackA`
- `Dip_depth_direct_TrackB`
- `FM_like_old`
- `FM_like_replay_TrackA`
- `FM_E_old`
- `FM_E_replay_TrackA`
- `FM_abs_old_or_mixed`
- `FM_abs_direct_TrackB`
- `tau_old_physical_or_unclear`
- `tau_physical_canon_replay`
- `tau_proxy_canon`
- `normalized_endpoint_gain_proxy_canon`
- `SVD_observable_Q006S0`
- `SVD_map_native_Q006S3`
- `mode_old_generic`
- `mode_obs_Q006S0`
- `mode_map_Q006S3`

No ambiguous bare names (`AFM`, `FM`, `tau`, `mode`, `SVD`, `DeltaM`) are allowed in mixed-layer comparison outputs.

## Layer rules

### `OLD_HISTORICAL`
- **Allowed:** historical context, definition inspiration.
- **Forbidden:** canonical evidence, mechanism closure, direct numeric comparison to canonical values.
- **Evidence status:** noncanonical.
- **Namespace:** `_old` family.

### `CANONICAL_TRACK_A_REPLAY`
- **Allowed:** descriptive replay, replay diagnostics, replay-gated comparison scaffolding.
- **Forbidden:** direct physical truth claims without gate/replay adjudication.
- **Evidence status:** canonical replay/support.
- **Namespace:** `_replay_TrackA`.

### `CANONICAL_TRACK_B_DIRECT`
- **Allowed:** direct canonical evidence under domain gates.
- **Forbidden:** treated as universal replacement for Track A semantics.
- **Evidence status:** canonical direct contract.
- **Namespace:** `_direct_TrackB`.

### `CANONICAL_MAP_NATIVE`
- **Allowed:** map-native inputs/exports and gated evidence paths.
- **Forbidden:** implicit merge with observable-layer feature semantics.
- **Evidence status:** canonical map object.
- **Namespace:** `_canon_map`.

### `DIAGNOSTIC_PROXY`
- **Allowed:** diagnostic-only screening and sanity audits.
- **Forbidden:** promotion to physical tau or mechanism evidence.
- **Evidence status:** non-mechanism proxy.
- **Namespace:** `_proxy_canon`.

### `OBSERVABLE_LAYER_SVD`
- **Allowed:** layer-specific descriptive/mechanism-prerequisite support under gates.
- **Forbidden:** direct equivalence with map-native SVD modes.
- **Evidence status:** canonical but layer-limited.
- **Namespace:** `SVD_observable_Q006S0`, `mode_obs_Q006S0`.

### `MAP_NATIVE_SVD`
- **Allowed:** layer-specific descriptive/mechanism-prerequisite support under gates.
- **Forbidden:** direct equivalence with observable-layer SVD modes.
- **Evidence status:** canonical but layer-limited.
- **Namespace:** `SVD_map_native_Q006S3`, `mode_map_Q006S3`.

### `GATE_STATUS`
- **Allowed:** readiness and prohibition enforcement.
- **Forbidden:** reinterpretation as physics signal.
- **Evidence status:** governance authority.
- **Namespace:** gate/status fields unchanged, but comparison outputs must reference gate fields explicitly.

## Hard prohibitions

The following are forbidden:

1. Using old values as canonical evidence.
2. Treating Track A as direct physical truth.
3. Treating Track B as replacement for Track A without adjudication.
4. Treating tau-like proxy as physical tau.
5. Comparing old decomposition directly to `Q006-S3` map-native modes.
6. Merging `Q006-S0` observable SVD with `Q006-S3` map-native SVD.
7. Using `Tp=34` as core evidence.
8. Using low-T descriptive/unstable rows as Q006 core evidence.
9. Importing old AFM/FM mechanism claims as canonical closure.
10. Using quarantined artifacts as evidence for claims.

## Replay rules

Old-to-new comparison is allowed only through canonical replay:

- replay variable name MUST include `_replay`
- canonical source artifact MUST be listed
- old values MUST NOT be copied as canonical values
- old correlations MUST NOT be reused as canonical evidence
- valid domain MUST be listed
- usage category MUST be listed: `descriptive` / `diagnostic` / `mechanism-prerequisite` / `forbidden`

## Quarantine handling

High-risk artifacts and allowed handling are defined in `tables/aging/aging_quarantine_registry.csv`.

Minimum quarantined set:

- `Aging/analysis/aging_observable_mode_correlation.m`
- `docs/AGING_DECOMPOSITION_STATUS.md`
- `Aging/analysis/aging_structured_results_export.m`
- `Aging/analysis/run_aging_FM_tau_feasibility_and_definition_rescue.m`
- `Aging/analysis/run_aging_lowT_6_10_fm_fit_vs_direct_diagnostic.m`

## Future-agent guardrail block (copy-paste)

Use this exact block in future Aging prompts that involve old/new comparison, replay, tau, AFM/FM, SVD, or mechanism claims:

```text
AGING SEMANTIC SAFETY GUARDRAILS (MANDATORY)

1) Treat OLD_HISTORICAL artifacts as noncanonical context only.
2) Never use old values as canonical evidence.
3) Use explicit namespaces:
   - *_old, *_replay_TrackA, *_direct_TrackB, *_canon_map, *_proxy_canon
   - SVD_observable_Q006S0 vs SVD_map_native_Q006S3
   - mode_obs_Q006S0 vs mode_map_Q006S3
4) Do not merge Q006-S0 and Q006-S3 mode semantics.
5) Do not treat tau_proxy_canon (including normalized_endpoint_gain_proxy_canon) as physical tau.
6) Do not use Tp=34 or low-T unstable rows as Q006 core evidence.
7) Old-to-new comparison is allowed only through canonical replay with:
   - explicit _replay variable names
   - listed canonical source artifacts
   - listed valid domain/regime
   - listed usage class (descriptive/diagnostic/mechanism-prerequisite/forbidden)
8) Quarantined artifacts are invalid for claims unless replay-rescued per registry.
9) Cross-module claims are out of scope.
```

## Contract verdicts

- `AGING_SEPARATION_CONTRACT_CREATED = YES`
- `NAMESPACE_RULES_DEFINED = YES`
- `LAYER_USAGE_RULES_DEFINED = YES`
- `HARD_PROHIBITIONS_DEFINED = YES`
- `QUARANTINE_REGISTRY_CREATED = YES`
- `FUTURE_AGENT_GUARDRAILS_CREATED = YES`
- `OLD_VALUES_ALLOWED_AS_CANONICAL_EVIDENCE = NO`
- `Q006S0_Q006S3_MERGE_ALLOWED = NO`
- `TAU_PROXY_AS_PHYSICAL_TAU_ALLOWED = NO`
- `TRACK_A_AS_DIRECT_TRUTH_ALLOWED = NO`
- `READY_FOR_SAFE_AGING_REPLAY_OR_COMPARISON = YES`
