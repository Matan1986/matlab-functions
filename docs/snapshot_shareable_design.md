# Snapshot Shareable Design

## 1) Final Proposed Structure (Stable, Usage-Oriented)

```text
snapshot_shareable/
├─ 00_index/
│  ├─ snapshot_manifest.json
│  ├─ module_index.json
│  ├─ run_index.json
│  ├─ report_index.json
│  ├─ claim_index.json
│  └─ x_proof_map.json
│
├─ 10_code/
│  ├─ code_unified_core.zip
│  ├─ code_experimental_pipelines.zip
│  └─ code_visualization.zip
│
├─ 20_results_runs/
│  ├─ runpacks/
│  │  ├─ run_<id>.zip
│  │  ├─ run_<id>.zip
│  │  └─ ...
│  └─ runpacks_by_domain/
│     ├─ aging_runs_pack.zip
│     ├─ switching_runs_pack.zip
│     ├─ relaxation_runs_pack.zip
│     └─ cross_experiment_runs_pack.zip
│
├─ 30_reports/
│  ├─ reports_global_synthesis.zip
│  ├─ reports_run_local.zip
│  └─ reports_review_artifacts.zip
│
├─ 40_claims_knowledge/
│  ├─ claims_full.zip
│  ├─ context_bundle_minimal.zip
│  ├─ context_bundle_full.zip
│  └─ surveys_and_review_state.zip
│
└─ 50_topic_packs/
   ├─ topic_X_full.zip
   ├─ topic_claim_<claim_id>.zip
   └─ topic_run_<run_id>_debug.zip
```

## 2) Module Explanations (What + Why)

### `00_index` (mandatory control plane)
- Contains only mapping metadata.
- Purpose: direct navigation and AI entry points before reading heavy payloads.
- Why: answers "where is X proof/evidence/code?" without opening all ZIPs.

### `10_code` (code by usage role, not by file type)
- `code_unified_core.zip`: Aging/Switching/Relaxation/cross-analysis logic.
- `code_experimental_pipelines.zip`: instrument-specific ingestion/preprocessing code.
- `code_visualization.zip`: GUI/formatting/colormap tooling.
- Why: allows sending only executable logic needed for a question.

### `20_results_runs` (run-first sharing)
- `runpacks/run_<id>.zip`: one self-contained run per ZIP (manifest, notes, figures, tables, reports, review subfolder if exists).
- `runpacks_by_domain/*.zip`: optional batched sharing by experiment family.
- Why: supports "send only one run" and reproducible debugging.

### `30_reports` (narrative evidence layer)
- `reports_global_synthesis.zip`: top-level `reports/` and selected `docs/reports/`.
- `reports_run_local.zip`: run-local `reports/` extracted as a navigable bundle.
- `reports_review_artifacts.zip`: `review/` bundles and audit artifacts.
- Why: separates conclusions from raw run payload and avoids forcing full results transfer.

### `40_claims_knowledge` (proof statements + context)
- `claims_full.zip`: complete `claims/*.json` (full evidence fields preserved).
- `context_bundle_minimal.zip` and `context_bundle_full.zip`.
- `surveys_and_review_state.zip`: `surveys/*` + review status summaries.
- Why: claim-level reasoning should be available independently of large result archives.

### `50_topic_packs` (high-value user workflows)
- `topic_X_full.zip`: minimal complete "what is proven about X" package.
- `topic_claim_<claim_id>.zip`: claim-specific evidence package.
- `topic_run_<run_id>_debug.zip`: run + relevant code + minimal indices.
- Why: standard, repeatable partial sharing for common questions.

## 3) Typical Sharing Workflows

### A) Debug a run
Send:
1. `00_index/snapshot_manifest.json`
2. `00_index/run_index.json`
3. `20_results_runs/runpacks/run_<id>.zip`
4. One relevant code ZIP from `10_code` (usually `code_unified_core.zip`)

Result:
- Receiver gets exact run evidence and matching executable logic.

### B) Validate a claim
Send:
1. `00_index/claim_index.json`
2. `00_index/x_proof_map.json` (or claim proof map)
3. `40_claims_knowledge/claims_full.zip`
4. Required runpacks listed by that claim from `20_results_runs/runpacks/`
5. Optional: `30_reports/reports_global_synthesis.zip`

Result:
- Claim statement and full evidence chain are inspectable end-to-end.

### C) Understand X fully
Send minimal "X complete" set:
1. `00_index/*`
2. `40_claims_knowledge/claims_full.zip`
3. `40_claims_knowledge/context_bundle_full.zip`
4. `30_reports/reports_global_synthesis.zip`
5. X-linked runpacks from cross_experiment + supporting switching/aging/relaxation runs
6. `10_code/code_unified_core.zip`

Equivalent shortcut:
- `50_topic_packs/topic_X_full.zip` + `00_index/*`

## 4) Mapping Rules (Deterministic)

### Runs mapping
- Every `results/<experiment>/runs/run_<id>/` maps to exactly one `runpacks/run_<id>.zip`.
- `run_index.json` must include for each run:
  - `run_id`, `experiment`, `zip_path`, `source_path`, `has_reports`, `has_review`, `observables_presence`.

### Reports mapping
- Every run-local report maps to both:
  - its runpack membership
  - `30_reports/reports_run_local.zip` index entry.
- Top-level reports map to `reports_global_synthesis.zip`.
- Review bundles map to `reports_review_artifacts.zip`.

### Claims mapping
- `claim_index.json` stores full claim-to-evidence pointers:
  - `claim_id -> report_paths + run_ids + survey_refs + confidence/status`.
- `x_proof_map.json` stores curated chain for X:
  - canonical claims, required runs, required reports, optional supporting runs.

### Code mapping
- Each run in `run_index.json` has `code_module` tag(s):
  - `unified_core`, `experimental_pipelines`, `visualization`.
- This enables "code + matching results" by rule, not manual search.

## 5) Minimal Core Bundles for Full Understanding

For full project-level understanding (not all raw files), send:
1. `00_index` (all files)
2. `40_claims_knowledge/claims_full.zip`
3. `40_claims_knowledge/context_bundle_full.zip`
4. `30_reports/reports_global_synthesis.zip`
5. `10_code/code_unified_core.zip`
6. Required runpacks referenced by `claim_index.json` for target topics

For full X understanding specifically, minimum should be:
1. `00_index/*`
2. `40_claims_knowledge/claims_full.zip`
3. `40_claims_knowledge/context_bundle_full.zip`
4. `30_reports/reports_global_synthesis.zip`
5. `20_results_runs/runpacks/` entries referenced by:
   - `X_canonical_coordinate`
   - `X_scaling_relation`
   - `X_peak_alignment`
   - `X_pareto_nondominated`
   - `X_broad_basin`
   - `X_adversarial_robustness`
   - `X_not_temperature_reparameterization`
6. `10_code/code_unified_core.zip`

## 6) Why This Is Optimal Against Your Goals

- Easy partial sharing: single-run packs and topic packs are first-class.
- Direct code/results/reports/claims mapping: guaranteed by `00_index` JSON maps.
- Efficient AI ingestion: explicit entry points, no need to crawl monolithic archives.
- Minimal duplication: one canonical runpack per run; report bundles are indexed views, not alternate truth sources.
- Clear X navigation: `x_proof_map.json` + `topic_X_full.zip` answer "what is proven about X?" directly.
