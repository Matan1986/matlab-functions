# Knowledge System Architecture (High-Level Map)
## What layers exist
This repo’s knowledge architecture is best understood as a set of layers that map between three domains:
1. **Semantic vocabulary** (modules, observables, claim statements)
2. **Evidence payloads** (run manifests/config snapshots + run-local/global reports)
3. **Control-plane indices** (broad “what exists” indexes plus deterministic “how to navigate” graphs)

### Layer A: Semantic registries (static definitions)
- `docs/system_registry.json` (module classification)
- `docs/repo_state.json` + `docs/model/repo_state_description.json` (+ full description)
- `docs/observables/observable_registry.md` and `docs/observable_naming.md`
- `claims/*.json` (explicit claim statements + status/confidence; evidence links exist in practice)

### Layer B: Run-ground-truth evidence store (dynamic per run)
- `results/<experiment>/runs/run_<timestamp>_<label>/run_manifest.json`
- `results/<experiment>/runs/run_<timestamp>_<label>/config_snapshot.m`
- `results/<experiment>/runs/run_<timestamp>_<label>/run_notes.txt`
- optional: `results/<experiment>/runs/run_<timestamp>_<label>/observables.csv` (run-root observable index)
- run-local narrative: `results/<experiment>/runs/run_*/reports/*.md`
- global narrative: `reports/*.md`

### Layer B.5: Evidence run registry & query helpers (run_id -> evidence paths)
- Evidence registry: `analysis/knowledge/run_registry.csv`
- Evidence loader: `analysis/knowledge/load_run_evidence.m`
- Fallback list: `analysis/knowledge/unresolved_runs.csv`
- Query entrypoints: `analysis/query/query_system.m`, `analysis/query/list_all_runs.m`, `analysis/query/start_query.m`

### Layer C: Context/bundle handoff (compact semantic capsule)
- `docs/context_bundle.json` (minimal)
- `docs/context_bundle_full.json` (extended)
- Producer: `scripts/update_context.ps1`

### Layer D: Survey/review synthesis (human+agent-readable “what’s pending/approved”)
- Survey registry: `surveys/registry.json`
- Rolling surveys: `surveys/*/rolling_survey.md`
- Generator: `tools/survey_builder/build_rolling_surveys.m`
- Intended review state: `results/**/run_review.json` (generator exists, but run review manifests are not present in this workspace)

### Layer E: Snapshot smart layer (deterministic control plane above runs)
- `snapshot_scientific_v3/00_entrypoints/*` (entry-point maps)
- `snapshot_scientific_v3/30_runs_evidence/run_index.json` (run_id → source_run_path + runpack_path + code bundle)
- `snapshot_scientific_v3/40_analysis_catalog/*` (analysis registry + status evaluation rules + observable/analysis relations)
- `snapshot_scientific_v3/50_reports_knowledge/report_index.json` (report_id → report path)
- `snapshot_scientific_v3/60_claims_surveys/*` (claim indices + provenance/status maps + survey index)
- `snapshot_scientific_v3/70_evidence_index/*` (evidence edges and resolution rules)
- `snapshot_scientific_v3/80_question_packs/*` (rules for generating question packs)

### Layer F: Transport snapshots (ZIP packaging)
- `scripts/run_snapshot.ps1` creates `snapshot_repo.zip` (external artifact)
- design specs: `docs/snapshot_system_design.md`, `docs/snapshot_system_map.md`
- shareable organization specs: `docs/snapshot_shareable_design*.md`

## What depends on what
### Semantic registries → Context bundles
- `scripts/update_context.ps1` composes:
  - `docs/repo_state.json`
  - `docs/model/repo_state_description.json` (+ full description for extended)
  - reduced claims fields from `claims/*.json`
→ emits `docs/context_bundle*.json`.

### Claims + run artifacts → Surveys and snapshot indices
- Surveys are generated from:
  - `surveys/registry.json`
  - `claims/*.json`
  - intended: run review manifests (`results/**/run_review.json`)
  - actual: in this workspace, `surveys/*/rolling_survey.md` exists but `results/**/run_review.json` was not found.
- `snapshot_scientific_v3` encodes deterministic mappings using:
  - claim indices (`snapshot_scientific_v3/60_claims_surveys/claim_index.json`)
  - claim→run and claim→report edges (`snapshot_scientific_v3/70_evidence_index/*.jsonl`)
  - run evidence index (`snapshot_scientific_v3/30_runs_evidence/run_index.json`)
  - report index (`snapshot_scientific_v3/50_reports_knowledge/report_index.json`)

### Run artifacts → Reporting and evidence narratives
- Both survey synthesis and snapshot indices ultimately point to run-local evidence:
  - run reports in `results/*/runs/*/reports/`
  - global reports in `reports/`

### Evidence registry → Query entrypoints
- `analysis/query/query_system.m` resolves local evidence using:
  - `analysis/knowledge/run_registry.csv` (via `analysis/knowledge/load_run_evidence.m`)
  - and seeds/ranks candidates using `docs/context_bundle_full.json` plus `snapshot_scientific_v3` edges/indexes.

### Control-plane indices → Evidence navigation protocol
- The deterministic “canonical resolution path” is defined by:
  - `snapshot_scientific_v3/00_entrypoints/canonical_resolution_path.json`
  - plus resolution rule files in `snapshot_scientific_v3/70_evidence_index/*resolution*.json`.

## What is redundant (duplication across systems)
1. **Claim knowledge appears in multiple forms**:
   - full claims in `claims/*.json`
   - reduced claims inside `docs/context_bundle*.json`
   - claim status and provenance inside `snapshot_scientific_v3/60_claims_surveys/*`
   - claim conclusions repeated across run reports and surveys.
2. **Evidence narratives repeat**:
   - run-local reports (`results/*/runs/*/reports/`)
   - top-level reports (`reports/`)
   - and packaging artifacts (review ZIPs) where present.
3. **Status/progress signals exist in multiple places**:
   - `surveys/*/rolling_survey.md`
   - snapshot evidence status/provenance maps (`snapshot_scientific_v3/60_claims_surveys/proven_status_map.json`)
   - and (intended) `run_review.json` per run.

## What is promising
1. **Context bundles are compact and stable**:
   - They provide semantic grounding (modules + observable definitions + reduced claims) in a single JSON entrypoint.
2. **snapshot_scientific_v3 is a real control-plane graph**:
   - It defines deterministic navigation with explicit indexes and edges, and includes a consistency check (`snapshot_scientific_v3/00_entrypoints/consistency_check.json` passed).
3. **Observable exchange utilities give schema consistency**:
   - `tools/export_observables.m` and `tools/load_observables.m` establish a standardized “run-root observable index” for aggregation.

## What is confusing (or incomplete)
1. **Two run registry models**:
   - `docs/run_system.md` describes `results/<experiment>/run_index.csv` + `latest_run.txt`.
   - In this workspace, these were not found; run discovery falls back to manifest-based scanning.
   - Separately, a more evidence-oriented registry exists (`analysis/knowledge/run_registry.csv`), so agent evidence resolution can still work even when run_index.csv is missing.
2. **Run review manifests vs existing surveys mismatch**:
   - Survey generator expects `results/**/run_review.json`, but `run_review.json` files are absent here.
   - Existing `surveys/*/rolling_survey.md` suggests the survey layer was generated earlier or from external inputs.
3. **snapshot smart layer payload availability**:
   - `snapshot_scientific_v3` references runpack ZIPs under `30_runs_evidence/runpacks/`, but those ZIP payloads are not present in this workspace.
   - The indexes still contain `source_run_path` and report paths; a receiver must resolve evidence to local filesystem.
4. **Context bundles are intentionally lossy**:
   - They contain semantic state and reduced claim fields, but not evidence chains.
   - Evidence traceability requires combining claims + reports + snapshot edges.

## Recommended “use it now” navigation order
1. **Start with semantics**: `docs/context_bundle_full.json`.
2. **Navigate evidence deterministically (if available)**:
   - `snapshot_scientific_v3/00_entrypoints/quick_start.json` (workflow)
   - claim/analysis/run/report indexes + edges
3. **Resolve to local filesystem evidence**:
   - use `snapshot_scientific_v3/30_runs_evidence/run_index.json` (`source_run_path`)
   - use `snapshot_scientific_v3/50_reports_knowledge/report_index.json` (`path`)
4. **Enumerate / resolve evidence when needed**:
   - prefer `analysis/query/query_system.m` + `analysis/knowledge/load_run_evidence.m` (via `analysis/knowledge/run_registry.csv`)
   - fallback: `tools/list_runs.m` + `tools/load_run_manifest.m`
5. **Use surveys as “what’s pending vs supported”**:
   - `surveys/*/rolling_survey.md`

