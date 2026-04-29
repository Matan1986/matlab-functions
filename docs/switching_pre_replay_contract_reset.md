# Switching pre-replay contract reset (assistive layer)

**Scope:** Switching only. **Purpose:** Assist agents before replaying old analyses into the canonicalized module — **not** physics, **not** replay execution.

**Phase 1 status:** Design + seed tables. See `reports/switching_pre_replay_contract_reset_phase1.md` and `tables/switching_pre_replay_contract_reset_status.csv`.

## Principles

1. **Assistive-first:** Prefer allowed values, templates, warnings, and classification fields over hard failures.
2. **Hard fails are narrow:** Reserve **HARD_FAIL** for attempts to **write** or **claim** canonical/authoritative outputs from **forbidden sources**, **unknown namespaces**, or **diagnostic-only** artifacts mislabeled as manuscript backbone.
3. **Do not collapse families:** `legacy_old`, corrected-old / `CORRECTED_CANONICAL_OLD_ANALYSIS`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, `canonical_replay`, `diagnostic`, and **experimental** remain distinct — see `docs/switching_artifact_policy.md` and `tables/switching_analysis_namespace_clean_map.csv`.
4. **Cross-module:** Do not infer Relaxation/Aging readiness from Switching docs alone.

## Existing anchors (do not duplicate semantics)

- Narrative + backbone map: `docs/switching_analysis_map.md`
- Namespace machine map: `tables/switching_analysis_namespace_clean_map.csv`
- Claim boundaries: `tables/switching_analysis_claim_boundary_map.csv`
- Allowed evidence by use case: `tables/switching_allowed_evidence_by_use_case.csv`
- Corrected-old authoritative index: `tables/switching_corrected_old_authoritative_artifact_index.csv`
- Stale row interpretation: `reports/switching_stale_governance_supersession.md`, `tables/switching_stale_governance_supersession.csv`
- Agent header template: `docs/templates/switching_analysis_namespace_header.md`

## Phase 1 design artifacts (this folder/table set)

| File | Role |
|------|------|
| `tables/switching_pre_replay_registry_contract.csv` | Seed registry rows linking items to family, lineage expectation, maturity |
| `tables/switching_pre_replay_namespace_contract.csv` | Namespace/family rules, prefixes, enforcement mode |
| `tables/switching_pre_replay_writer_contract_template.csv` | Required fields per writer class |
| `tables/switching_pre_replay_contract_reset_status.csv` | Phase completion + audit flags |

**Phase 2** may expand CSV rows, add optional validators, and wire CI — **without** modifying scientific algorithms or retroactively re-labeling tracked outputs without a governed task.

## Enforcement vocabulary

| Mode | Agent-facing behavior |
|------|------------------------|
| WARN | Surface gap; do not block exploratory work |
| SUGGEST | Offer template snippet or pointer |
| SOFT_FAIL | Fail only in explicit gated maintenance pipelines |
| HARD_FAIL | Block authoritative promotion / forbidden write paths |

## Helpers

- Copy `docs/templates/switching_analysis_namespace_header.md` into new reports/scripts.
- Before claiming manuscript backbone, check `tables/switching_forbidden_ambiguous_phrases.csv` and `tables/switching_misleading_or_dangerous_artifacts.csv` where applicable.
