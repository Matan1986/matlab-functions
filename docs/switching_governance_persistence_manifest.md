# Switching governance persistence manifest

This manifest is the durable anti-confusion source for old-vs-new Switching canonical governance.

## Non-negotiable governance facts

1. `run_switching_canonical.m` is a mixed producer.
2. `S_percent` is `CANON_GEN_SOURCE` and remains valid as canonical `S` input.
3. `I_peak`, `S_peak`, `W`/`width` are `CANONICAL_EFFECTIVE_OBSERVABLE` only if validated.
4. `S_model_pt_percent`, `PT_pdf`, and `CDF_pt` are `EXPERIMENTAL_PTCDF_DIAGNOSTIC`.
5. `residual_percent`, `S_model_full_percent`, `switching_canonical_phi1.csv`, and canonical `kappa1` are `DIAGNOSTIC_MODE_ANALYSIS` and are forbidden as `CORRECTED_CANONICAL_OLD_ANALYSIS` manuscript evidence.
6. Authoritative `CORRECTED_CANONICAL_OLD_ANALYSIS` **tables for the gated builder run** exist and are indexed under `tables/switching_corrected_old_authoritative_artifact_index.csv` with gate record `tables/switching_corrected_old_authoritative_builder_status.csv`. *(Supersedes earlier wording that stated none existed; see `reports/switching_stale_governance_supersession.md`.)*
7. **Additional** corrected-old rebuilds or replays remain subject to explicit authorization and `tables/switching_corrected_old_replay_input_contract.csv` — the **recorded** full builder run completed successfully **as reflected in** `tables/switching_corrected_old_authoritative_builder_status.csv`. *(Supersedes blanket “build blocked” language referring to pre-authoritative state.)*
8. **Non-authoritative** attempted `corrected_old` outputs/figures remain **quarantined** per `tables/switching_misleading_or_dangerous_artifacts.csv` and `reports/switching_quarantine_index.md` — **authoritative** tables do **not** clear quarantined diagnostic flows or misleading PNGs.

## Durable source-of-truth pointers

- **Current-state entry (read first):** `reports/switching_corrected_canonical_current_state.md`
- Authoritative corrected-old index: `tables/switching_corrected_old_authoritative_artifact_index.csv`
- Stale snapshot supersession: `reports/switching_stale_governance_supersession.md`
- Namespace contract and claim boundaries: `docs/switching_analysis_map.md`
- Namespace declaration template: `docs/templates/switching_analysis_namespace_header.md`
- Old-vs-new source-of-truth map: `tables/switching_old_new_namespace_source_of_truth_map.csv`
- Classification verdict status: `tables/switching_analysis_classification_status.csv`
- Old recipe verification status: `tables/switching_old_recipe_verification_status.csv`
- Persistence hardening plan: `reports/switching_anti_confusion_persistence_hardening_plan.md`
- Persistence hardening plan matrix: `tables/switching_anti_confusion_persistence_hardening_plan.csv`

## Scope lock

- `PHYSICS_LOGIC_CHANGED=NO`
- `FILES_DELETED=NO`
