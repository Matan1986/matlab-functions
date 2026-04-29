# Switching Phase 2.5 — Sidecar, run manifest, and helper-layer contract design

This document **materializes contract definitions only** (CSV templates, helper API expectations, Phase 3 integration plan, and status keys). It does **not** implement MATLAB helpers, modify analysis scripts, or execute replay.

## Anchor and hygiene

| Check | Result |
|--------|--------|
| Current `HEAD` | **`f170bb2`** — Add Aging taxonomy draft docs |
| Phase 2 semantic materialization in history | **`e5e55d7`** — Materialize Switching semantic contract tables (ancestor of `HEAD`) |
| Staged at task start | **None** (`git diff --cached` empty) |

## Artifacts written

| Artifact | Purpose |
|----------|---------|
| `tables/switching_semantic_sidecar_template.csv` | Field dictionary for **per-artifact** sidecars (semantic, governance, provenance, validation). |
| `tables/switching_semantic_run_manifest_template.csv` | Field dictionary for **per-run** manifests (inputs, outputs, safety flags, timing). |
| `tables/switching_semantic_helper_contract.csv` | Design-only API contract for future helpers (inputs, outputs, must-not-do, failure behavior, Phase 4 gating). |
| `tables/switching_semantic_phase3_preflight_integration_plan.csv` | How Phase 3 preflight should consume Phase 2 tables plus Phase 2.5 schemas. |
| `tables/switching_semantic_phase25_status.csv` | Gate keys for Phase 2.5 completion and downstream safety. |
| This report | Narrative for Phase 3 integration and Phase 4 replay readiness. |

## Sidecar schema (summary)

The sidecar template covers **path and type**, **semantic family and alias**, **namespace**, **lineage** (source artifact, commit/run, script, column class), **claim and use policy** (claim_level, allowed_use, forbidden_use), **safety flags** (quarantine, manuscript, replay, canonical), **lifecycle** (stale/superseded, supersession reference, lineage_id, run_id), **provenance** (hashes, timestamps, creator), and **validation/lint** status plus **notes**. Full definitions and validation hints are in the CSV columns `validation_rule` and `allowed_values_or_source`.

## Run manifest schema (summary)

The manifest template adds **run identity** (`run_id`, `module`, `analysis_family`), **semantic and namespace** alignment with Phase 2, **execution context** (`source_commit`, `working_tree_state`, `executing_script`, `execution_wrapper`, `matlab_or_tool_version`), **artifact collections** (inputs, outputs, sidecars, figures, diagnostics, status_table, report_path), **policy mirrors** (claim_level, allowed/forbidden use, quarantine and safety flags), **aggregate validation/lint/error** status, **timing**, and **notes**. Provenance for reproducibility is explicit via commit, tree state, paths, and optional duration.

## Helper layer contract (design only)

Eight helpers are specified in `tables/switching_semantic_helper_contract.csv`:

| Helper | Role |
|--------|------|
| `createSwitchingSemanticSidecar` | Emit a conforming sidecar for one artifact. |
| `createSwitchingRunManifest` | Emit a conforming manifest for one run. |
| `validateSwitchingSidecar` | Validate instance vs sidecar template + cross-checks. |
| `validateSwitchingRunManifest` | Validate manifest vs template + optional sidecar linkage. |
| `loadSwitchingSemanticRegistry` | Read-only load of materialized registry. |
| `resolveSwitchingSemanticFamily` | Resolve family and alias from paths/scripts/column class. |
| `applySwitchingLintRules` | Apply `switching_semantic_lint_rules.csv` with WARN-first default. |
| `writeSwitchingContractStatus` | Status CSV updates for gates (does not replace full Phase 3 runner). |

Each row documents **required inputs and outputs**, **must-not-do** constraints (no mutation of analysis artifacts, no rename/replay from validators), **failure behavior**, and whether the helper is **required before Phase 4 corrected-old replay** vs **optional for diagnostics**.

## Phase 3 lint/preflight integration

Phase 3 should consume the following **in combination**:

1. **`tables/switching_semantic_materialized_artifact_registry.csv`** — Register artifacts and producers; drive semantic_family resolution.
2. **`tables/switching_semantic_allowed_use_matrix.csv`** — Authoritative grid for claim strength vs use case; compare to sidecar/manifest **claim_level**, **allowed_use**, **forbidden_use**, and **canonical_safe** / **replay_safe** flags.
3. **`tables/switching_semantic_writer_contract.csv`** — Required metadata and roles for writers; preflight checks declared outputs for missing contract fields when outputs are claimed.
4. **`tables/switching_semantic_lint_rules.csv`** (with **`tables/switching_semantic_forbidden_terms.csv`**) — Lint catalog; default **WARN** for violations.
5. **`tables/switching_semantic_sidecar_template.csv`** — Schema for validating each sidecar instance; escalate invalid sidecars that still assert **replay_safe** or **canonical_safe**.
6. **`tables/switching_semantic_run_manifest_template.csv`** — Schema for validating each run manifest; pair with **working_tree_state** and notes when **dirty**.
7. **`tables/switching_semantic_helper_contract.csv`** — Stable API surface for implementation and testing (no code in Phase 2.5).

**Severity policy:** **WARN-first** for schema drift, missing optional metadata, dirty tree without explanation, unknown family with waiver, and matrix **WARN/CONDITIONAL** paths. **HARD_FAIL** is reserved for **unsafe canonical or authoritative promotion** when the allowed-use matrix or **HARD_FAIL** lint rules (e.g. unsafe promotion class such as **SW_LINT_019** per Phase 2 materialization) forbid the asserted posture—in particular when **canonical_safe** or equivalent promotion would contradict policy.

## Phase 4 corrected-old replay readiness gate

Before **broad** or **production** corrected-old replay:

| Gate | Requirement |
|------|-------------|
| Materialized registry | Committed Phase 2 **`switching_semantic_materialized_artifact_registry.csv`** available and loadable. |
| Sidecar schema | Phase 2.5 sidecar template committed and validators specified. |
| Manifest schema | Phase 2.5 manifest template committed and validators specified. |
| Helper contract | Phase 2.5 helper CSV committed; **implementations** complete per policy (future phase). |
| Lint/preflight | Phase **3** implemented: consumes Phase 2 + Phase 2.5 contracts; **passing** for the intended replay scope (no unaddressed HARD_FAIL on promotion paths). |
| No broad old replay until gates pass | **`BROAD_OLD_ANALYSIS_REPLAY_ALLOWED_NOW`** remains **NO** until governance explicitly changes; **`SAFE_TO_PROCEED_TO_PHASE4_CORRECTED_OLD_REPLAY`** stays **NO** until Phase 3 is implemented and passes for the replay lane. |

Narrow, read-only diagnostic runs may omit some artifacts only where **`switching_semantic_helper_contract.csv`** marks helpers optional for diagnostics—without lifting promotion or broad replay policy.

## References

- Phase 2 narrative: `reports/switching_semantic_contract_materialization.md`
- Phase 2 status: `tables/switching_semantic_materialization_status.csv`
- Phase 2.5 status: `tables/switching_semantic_phase25_status.csv`
