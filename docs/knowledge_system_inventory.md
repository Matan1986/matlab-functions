# Documentation / Knowledge Systems Inventory (Read-Only Audit)
## Executive summary
This repository already contains multiple overlapping “knowledge/context” layers intended to help humans and agents navigate results, runs, and scientific conclusions. The most important systems are:
1. **State + module/observable registries**: `docs/repo_state.json`, `docs/system_registry.json`, `docs/observables/observable_registry.md`, and `docs/observable_naming.md`. These define the project-level vocabulary and module boundaries that later layers reference.
2. **Context bundles**: `docs/context_bundle.json` and `docs/context_bundle_full.json`, produced by `scripts/update_context.ps1`, providing a machine-readable handoff for agents/humans.
3. **Claims + review/survey layer**: `claims/*.json` plus `surveys/*/rolling_survey.md` generated via `tools/survey_builder/build_rolling_surveys.m`, with orchestration around run manifests and (intended) `run_review.json`.
4. **Run metadata layer**: `results/<experiment>/runs/run_<timestamp>_<label>/run_manifest.json`, `config_snapshot.m`, `run_notes.txt`, and optionally `observables.csv` at run root. The run system is the ground truth evidence store.
5. **Snapshot “smart layer”**: `snapshot_scientific_v3/` is an index/edge system that provides deterministic navigation across **claim → evidence → runs → reports → code** using lightweight control-plane JSON files.

The snapshot smart layer is largely present as indices/edges, but some payload artifacts referenced by the design (notably runpacks ZIPs) are not present in this workspace. Separately, `docs/run_system.md` describes `results/<experiment>/run_index.csv` and `latest_run.txt`, but those files are not present on disk right now; run discovery currently relies on manifest-per-run + filesystem scanning (`tools/list_runs.m`).

## Systems discovered
### 1) Module classification registry (system registry)
- **Name**: System Registry (authoritative module classification)
- **Path(s)**: `docs/system_registry.json`
- **Purpose**: Provides `unified_stack`, `independent_experimental_pipelines`, `infrastructure`, and the authoritative `active_modules` set used for safe repository-wide reasoning.
- **How it is supposed to be used**: Repository rules treat this as the source of truth for “what counts as active” modules and where work should be aligned.
- **Relationship to runs/results/snapshots**: Implicit dependency: downstream generators (and human navigation) reference module identity when reasoning about runs and observables.
- **Status**: **Active (authoritative spec)**; contents exist and are used by documented policies (`docs/AGENT_RULES.md` references it indirectly via the “authoritative source” rule).

### 2) Project state model (repo state + model semantics)
- **Name**: Repo State Model
- **Path(s)**:
  - `docs/repo_state.json`
  - `docs/model/repo_state_description.json`
  - `docs/model/repo_state_full_description.json`
  - Helpers: `repo_state_generator.m`, `repo_state_validator.m`
- **Purpose**: Encodes project-level “state” including modules, known runs (sample-based), observable definitions, and cross-experiment physics abstractions.
- **How it is supposed to be used**:
  - As a baseline knowledge substrate for context bundles.
  - As a validator target for consistent module/run/observable wiring.
- **Relationship to runs/results/snapshots**:
  - Context bundles embed the full state.
  - State references “known runs” as concrete anchor points (but the list is not exhaustive).
- **Status**: **Active (spec + validator/generator exist)**.

### 3) Observable registry + naming policy (knowledge vocabulary)
- **Name**: Observable Registry & Naming Policy
- **Path(s)**:
  - `docs/observables/observable_registry.md`
  - `docs/observable_naming.md`
  - `docs/observables/switching_observables.md`
  - Documentation-only rename tool: `analysis/observable_naming_update.m`
- **Purpose**:
  - Provides a dictionary of observables/roles/units/descriptions.
  - Defines a canonical physical name mapping (`χ_amp(T)` is the physical/report name; legacy MATLAB/CSV remains `a1`).
- **How it is supposed to be used**:
  - Agents/humans should use physical names in reports and documentation and keep legacy code variables unchanged.
  - Generators and audits can rely on consistent names.
- **Relationship to runs/results/snapshots**:
  - Context bundle and state model refer to observable semantics.
  - Run-level exported tables may still carry legacy columns, so consistent naming is essential for joining across outputs.
- **Status**: **Active** (documents and mapping scripts exist).

### 4) Context bundle layer (machine-readable handoff)
- **Name**: Context Bundle (minimal + extended)
- **Path(s)**:
  - `docs/context_bundle.json`
  - `docs/context_bundle_full.json`
  - Producer: `scripts/update_context.ps1`
  - Readme hints: `docs/repository_structure.md` / `docs/repository_map.md` / `docs/AGENT_RULES.md`
- **Purpose**: Provide a structured JSON snapshot combining:
  - reduced claims fields (only `claim_id`, `statement`, `status`, `role`, `confidence`)
  - complete `docs/repo_state.json` state
  - `model.core` for the minimal bundle; `model.extended` additionally for the full bundle
- **How it is supposed to be used**:
  - Agent workflow gate is explicitly documented: **RUN → SNAPSHOT → CONTEXT → TASK**.
  - Bundles are intended for external tools/ChatGPT ingestion without traversing the entire repository.
- **Relationship to runs/results/snapshots**:
  - Context bundle is derived from state + claim summaries; it does *not* contain evidence-level run/report traceability.
  - Snapshot system audit notes that this reduces direct traceability (“bundles are lossy summaries”).
- **Status**: **Active** (exists as JSON; producer script exists; audit indicates snapshot generation involved it).

### 5) Claims registry (explicit scientific statements)
- **Name**: Claims Registry
- **Path(s)**:
  - `claims/*.json` (including `claims/X_canonical_coordinate.json`, etc.)
- **Purpose**: Store explicit claim statements with status/role/confidence and (in practice) links to evidence artifacts.
- **How it is supposed to be used**:
  - As the canonical “what is claimed” store.
  - As input to survey/rolling status and snapshot smart indexing.
- **Relationship to runs/results/snapshots**:
  - Claims link to runs and reports via evidence sections in claim schema (and via snapshot_scientific_v3 edges).
  - Context bundles include only a reduced subset of claim fields.
- **Status**: **Active** (claims folder exists; snapshot smart layer indexes claim IDs).

### 6) Run output + run metadata layer (ground truth evidence)
- **Name**: Run System Metadata Layer
- **Path(s)**:
  - `docs/run_system.md` (spec)
  - `docs/results_system.md` and `docs/output_artifacts.md` (spec)
  - Tools: `tools/list_runs.m`, `tools/load_run_manifest.m`, `tools/getLatestRun.m`, `tools/openLatestRun.m`
  - Run-root artifacts (per `docs/results_system.md`):
    - `run_manifest.json`
    - `config_snapshot.m`
    - `log.txt`
    - `run_notes.txt`
    - optional `observables.csv` at run root
- **Purpose**:
  - `run_manifest.json` captures run identity.
  - `config_snapshot.m` preserves input configuration.
  - `observables.csv` optionally provides the standardized run-level index.
- **How it is supposed to be used**:
  - Used for reproducibility and evidence traceability.
  - Listing/loading of runs is handled by dedicated `tools/` utilities.
- **Relationship to runs/results/snapshots**:
  - This is the evidence source that the context/snapshot layers reference.
- **Status**: **Active** (actual `run_manifest.json` + `config_snapshot.m` exist in `results/.../runs/` and tooling to load them exists).

### 7) Run discovery “registries” (manifest-driven; run_index missing)
- **Name**: Run Discovery Registry (manifest + filesystem scan)
- **Path(s)**:
  - `tools/list_runs.m`
  - `tools/load_run_manifest.m`
  - `tools/getLatestRun.m`
  - `docs/run_system.md` describes additional registries (`run_index.csv`, `latest_run.txt`)
- **Purpose**:
  - Provide programmatic listing and metadata extraction for runs.
- **Observed reality**:
  - `results/**/run_index.csv` and `results/**/latest_run.txt` were not found in this workspace.
  - `list_runs.m` and `getLatestRun.m` fall back to filesystem parsing of run folders and `run_manifest.json`.
- **Relationship to runs/results/snapshots**:
  - Snapshot smart layer uses its own index (`snapshot_scientific_v3/30_runs_evidence/run_index.json`) and does not rely on `run_index.csv`.
- **Status**: **Partially active / partially implemented** (the spec mentions run_index.csv/latest_run.txt but the concrete files are absent).

### 8) Run review + survey layer (review state + rolling synthesis)
- **Name**: Run Review Manifests + Rolling Surveys
- **Path(s)**:
  - Review generator: `tools/run_review/generate_run_review_manifests.m`
  - Review auditor: `tools/survey_audit/audit_run_reviews.m` and `reports/run_review_audit.md`
  - Survey registry: `surveys/registry.json`
  - Survey builder: `tools/survey_builder/build_rolling_surveys.m`
  - Surveys: `surveys/*/rolling_survey.md`
- **Purpose**:
  - Convert run-level review/approval status into rolling, claim-aware “what is pending/approved” markdown docs.
- **Observed reality**:
  - `results/**/run_review.json` files were not found in this workspace, but many `surveys/*/rolling_survey.md` files exist and include pending runs with “report found” status.
  - Survey builder explicitly requires `run_review.json` to regenerate content.
- **Relationship to runs/results/snapshots**:
  - Surveys synthesize run review status and are intended as input to context/snapshot knowledge flows.
  - Snapshot_scientific_v3 includes its own survey/claims provenance index (`snapshot_scientific_v3/60_claims_surveys/survey_index.json`).
- **Status**: **Partially active / frozen artifacts** (survey markdown exists; regenerating may currently fail without `run_review.json` manifests).

### 9) Reporting layer (narrative evidence and synthesis)
- **Name**: Run-local reports + top-level reports
- **Path(s)**:
  - Run-local: `results/<experiment>/runs/<run_id>/reports/*.md`
  - Review bundles: `results/<experiment>/runs/<run_id>/review/*.zip`
  - Global: `reports/*.md`
  - Legacy docs reports: `docs/reports/*`
- **Purpose**:
  - Provide human-readable evidence and synthesis narratives that claims and snapshot indices point to.
- **Relationship to runs/results/snapshots**:
  - Snapshot_scientific_v3 includes a `report_index.json` mapping `report_id` to `path` and `scope`.
- **Status**: **Active** (reports exist; snapshot smart layer has report index).

### 10) Snapshot packaging layer (transport/sharing)
- **Name**: Snapshot Packaging & Context Handoff for Sharing
- **Path(s)**:
  - Design docs: `docs/snapshot_system_design.md`, `docs/snapshot_system_map.md`
  - Sharing design: `docs/snapshot_shareable_design.md`, `docs/snapshot_shareable_design_full.md`
  - Scripts:
    - `scripts/run_snapshot.ps1`
    - `scripts/build_snapshot_simple.ps1`
    - also uses `scripts/update_context.ps1`
- **Purpose**:
  - Create shareable ZIP archives (module zips + META manifest).
  - Include context bundles and (optionally) selected results.
- **Relationship to runs/results/snapshots**:
  - Snapshot packaging is a *transport layer*; it packages run evidence directories and documentation so external agents can reason offline.
- **Status**: **Active (scripts exist)** but payload zips are not version-controlled inside this repo.

### 11) Snapshot smart layer (deterministic evidence navigation index)
- **Name**: snapshot_scientific_v3 (frozen/minimal evidence index)
- **Path(s)**:
  - `snapshot_scientific_v3/00_entrypoints/*`
  - `snapshot_scientific_v3/30_runs_evidence/*`
  - `snapshot_scientific_v3/40_analysis_catalog/*`
  - `snapshot_scientific_v3/50_reports_knowledge/*`
  - `snapshot_scientific_v3/60_claims_surveys/*`
  - `snapshot_scientific_v3/70_evidence_index/*`
  - `snapshot_scientific_v3/80_question_packs/*`
- **Purpose**:
  - Provide a deterministic navigation graph and indexes:
    - **Claim → Evidence → Runs → Run evidence + Report paths + Code bundle entrypoints**
  - Supplies control-plane JSON files for external tools/agents.
- **Observed reality**:
  - Payload “runpacks” ZIPs referenced by the design are not present inside this workspace.
  - However, the indexes include `source_run_path` and report `path` entries that point to actual locations in `results/` and top-level `reports/`, so a receiver can likely use those paths.
- **Relationship to runs/results/snapshots**:
  - This is the “smart layer above runs” that maps knowledge objects (claims/analyses/questions/observables) to evidence objects (runs/reports).
- **Status**: **Partially implemented / frozen minimal layer** (indices exist and pass a consistency check, but payload zips and a complete universe of claims/analyses may be missing).

### 12) Observable index exchange utilities (cross-run metadata)
- **Name**: Standardized observables.csv exchange layer
- **Path(s)**:
  - `tools/export_observables.m`
  - `tools/load_observables.m`
  - Related run helper: `tools/list_runs.m` and `tools/load_run_manifest.m`
- **Purpose**:
  - Enforce a standardized schema for `observables.csv` and provide aggregation across runs.
- **Inputs**:
  - a table with columns: `experiment, sample, temperature, observable, value, units` (and optional `role`, `source_run`)
- **Outputs**:
  - `observables.csv` at run root; plus aggregated multi-run observable tables via `load_observables`.
- **Relationship to runs/results/snapshots**:
  - Acts as a bridge for building knowledge summaries and matching observables across experiments.
- **Status**: **Active** (tooling exists and documents a schema).

### 13) Reusable metadata generation runs (observable catalogs)
- **Name**: Observable catalog generation/completion
- **Path(s)**:
  - `analysis/effective_observables_catalog_run.m`
  - `analysis/observable_catalog_completion.m`
- **Purpose**:
  - Produce reusable, standardized metadata artifacts:
    - `tables/effective_observables_catalog.csv` / `reports/effective_observables_catalog.md`
    - `observable_catalog.csv`, `observable_summary.csv`, `observable_catalog_report.md` (from completion)
  - Export/update a run-root observable index (`export_observables` in some scripts).
- **Relationship to context/snapshot**:
  - Supplies additional vocabulary/metadata that can be referenced by higher-level knowledge systems.
- **Status**: **Active as “run-generators”** (implementations exist; actual catalog outputs are run-dependent).

### 14) Documentation navigation indices and private notebook
- **Name**: Repository map + inventory docs (+ internal notebook)
- **Path(s)**:
  - `docs/repository_map.md`
  - `docs/root_inventory_table.md`
  - `docs/internal/DOCUMENTATION.md` (private personal notebook)
- **Purpose**:
  - Human navigation and a “what to include in snapshots” inventory table.
  - Private workflow notes; not part of the shareable knowledge layer.
- **Status**: `docs/repository_map.md` and `docs/root_inventory_table.md` are **Active** (exist as index docs). `docs/internal/DOCUMENTATION.md` is **Private** and should not be treated as an external knowledge interface.

### 15) Evidence Run Registry (run_id -> evidence paths)
- **Name**: Evidence Run Registry (CSV evidence index)
- **Path(s)**:
  - `analysis/knowledge/run_registry.csv`
  - Evidence loader: `analysis/knowledge/load_run_evidence.m`
  - Completeness/fallback list: `analysis/knowledge/unresolved_runs.csv`
- **Purpose**:
  - Normalize the “for run X, what evidence artifacts exist” mapping into a single table (tables CSV paths, report markdown paths, plus snapshot linkage metadata).
- **How it is supposed to be used**:
  - Use `analysis/knowledge/load_run_evidence.m` to resolve an evidence struct for a given `run_id`.
  - Use `analysis/query/list_all_runs.m` to enumerate known run IDs present in this evidence registry.
- **Relationship to runs/results/snapshots**:
  - Evidence path columns point into `results/<experiment>/runs/...` and `reports/` (where populated).
  - Snapshot linkage columns (`snapshot_*`) connect registry entries to the snapshot smart layer (`snapshot_scientific_v3`) so agents can align evidence with claims/analyses.
- **Status**:
  - **Active** (loader and query entrypoints directly read this CSV in this workspace).

### 16) Evidence Query / Evidence Resolution Entry Points (run ranking)
- **Name**: Query System (lightweight, non-recomputing evidence queries)
- **Path(s)**:
  - `analysis/query/query_system.m`
  - `analysis/query/list_all_runs.m`
  - `analysis/query/start_query.m`
- **Purpose**:
  - Provide simple human/agent queries over existing run evidence by:
    - seeding candidate runs from `snapshot_scientific_v3` claim->run edges, and
    - ranking candidates using numeric metrics parsed from existing evidence tables (no recomputation).
- **Inputs**:
  - `query_name` (e.g., `coordinate_selection`, `residual_validity`, `pt_vs_relaxation`, `list_all_runs`)
- **Outputs**:
  - a MATLAB `struct` including `seed_claim_ids`, `seed_run_ids`, and `found_runs` (ranked run table with evidence paths + selected metrics).
- **Relationship to runs/results/snapshots**:
  - Uses `docs/context_bundle_full.json` for claim intent text.
  - Uses `snapshot_scientific_v3` indexes/edges for deterministic seeding.
  - Resolves local evidence via `analysis/knowledge/load_run_evidence.m` and `analysis/knowledge/run_registry.csv`.
- **Status**:
  - **Active but scope-limited**: query set is initially implemented and fallback selection is bounded/pattern-based.

## Active vs frozen systems
### Active / authoritative (usable as today’s knowledge entry points)
- `docs/context_bundle_full.json` and `docs/context_bundle.json`
- `docs/system_registry.json`
- `docs/repo_state.json` (+ model description JSONs)
- `claims/*.json`
- Run metadata layer in `results/*/runs/*/` (`run_manifest.json`, `config_snapshot.m`, `run_notes.txt`, etc.)
- Run discovery via filesystem scanning + manifest parsing (`tools/list_runs.m`, `tools/load_run_manifest.m`)
- Surveys: `surveys/*/rolling_survey.md` and `surveys/registry.json`
- Observable naming/registry docs: `docs/observable_naming.md`, `docs/observables/observable_registry.md`
- Standardized observable exchange utilities: `tools/export_observables.m`, `tools/load_observables.m`
- Evidence run registry + loader: `analysis/knowledge/run_registry.csv`, `analysis/knowledge/load_run_evidence.m`
- Query entrypoints: `analysis/query/query_system.m`, `analysis/query/list_all_runs.m`

### Partially active (spec exists; concrete instances missing or regeneration gates missing)
- `docs/run_system.md` run registries (`results/<experiment>/run_index.csv` and `results/<experiment>/latest_run.txt`) are described but not found in this workspace.
- Run review manifests (`run_review.json`):
  - Review manifest generator exists (`tools/run_review/generate_run_review_manifests.m`)
  - but `results/**/run_review.json` files were not found here.
  - rolling surveys exist, suggesting that the layer was generated earlier or by different processes.

### Frozen / minimal smart layer (indices exist; payload references may be missing here)
- `snapshot_scientific_v3/`:
  - Control-plane indices, edges, and consistency check are present.
  - runpack ZIP payloads referenced by design are not present in this workspace.
  - It is still usable as an evidence navigation map because indexes contain `source_run_path` and report `path` values.

## Snapshot/context infrastructure
### Context bundles
- Entry point: `docs/context_bundle.json` (minimal) and `docs/context_bundle_full.json` (extended)
- Producer: `scripts/update_context.ps1`
- Bundle contents:
  - reduced claim summaries (not evidence)
  - full `docs/repo_state.json` state
  - `model.core` or also `model.extended`

### Snapshot packaging
- Entry point scripts:
  - `scripts/run_snapshot.ps1` (creates `snapshot_repo.zip`, updates context bundles)
  - `scripts/build_snapshot_simple.ps1` (simpler module snapshots)
- Design docs define modular ZIP strategy and exclusion policy:
  - `docs/snapshot_system_design.md`
  - `docs/snapshot_system_map.md`
  - `docs/snapshot_shareable_design.md` / `docs/snapshot_shareable_design_full.md`

### Snapshot smart layer (control plane)
- The deterministic navigation graph is encoded in:
  - `snapshot_scientific_v3/00_entrypoints/quick_start.json`
  - `snapshot_scientific_v3/00_entrypoints/canonical_resolution_path.json`
  - `snapshot_scientific_v3/30_runs_evidence/run_index.json`
  - `snapshot_scientific_v3/40_analysis_catalog/analysis_registry.json`
  - `snapshot_scientific_v3/50_reports_knowledge/report_index.json`
  - `snapshot_scientific_v3/60_claims_surveys/claim_index.json`
  - `snapshot_scientific_v3/70_evidence_index/evidence_edges_*.jsonl`

## Registry / manifest / metadata layers
The repository has several “registry/manifest/metadata” systems with different scopes:
1. **Module registry**: `docs/system_registry.json` (classification scope).
2. **Project state model**: `docs/repo_state.json` (semantic/ontology scope).
3. **Observable vocabulary**: `docs/observables/observable_registry.md` and `docs/observable_naming.md`.
4. **Run manifests**: `run_manifest.json` in each run root (identity and provenance scope).
5. **Run config snapshot**: `config_snapshot.m` (reproducibility scope).
6. **Run-root observable exchange**: `observables.csv` generated by `tools/export_observables.m`.
7. **Evidence path normalization registry**: `analysis/knowledge/run_registry.csv` (run_id -> evidence file paths + snapshot linkage metadata).
8. **Evidence navigation index**: `snapshot_scientific_v3/*index*` + edges (control-plane scope).
9. **Survey registry + rolling synthesis**: `surveys/registry.json` and `surveys/*/rolling_survey.md`.

## Human usability assessment
Best human entry points today:
- `docs/context_bundle_full.json` for a single-pass “what is this project” overview.
- `docs/AGENT_RULES.md` + `docs/repository_map.md` for repository navigation and safety/architecture policies.
- `surveys/*/rolling_survey.md` for “what is supported vs pending” in natural markdown form.
- `claims/*.json` for claim semantics.
- `results/*/runs/*/reports/*.md` and `reports/*.md` for evidence narratives.

Usability gaps for humans:
- Evidence navigation is split between claims, surveys, run reports, and run review bundles. `docs/context_system_audit.md` explicitly calls out duplication and navigation friction.

## Agent usability assessment
Best agent entry points:
- `docs/context_bundle_full.json` gives the semantic vocabulary in a compact JSON.
- `snapshot_scientific_v3/00_entrypoints/quick_start.json` + `canonical_resolution_path.json` define an agent navigation protocol across claims/analysis/runs/reports/code.
- `analysis/query/query_system.m` and `analysis/knowledge/load_run_evidence.m` provide a local evidence-resolution route (run_id -> evidence paths) and bounded ranking without recomputation.
- `tools/list_runs.m` and `tools/load_run_manifest.m` allow agents to enumerate runs directly when the agent decides to use local filesystem evidence.
- `tools/export_observables.m` and `tools/load_observables.m` allow agents to build aggregated observable views with consistent schema.

Agent usability gaps:
- Snapshot smart layer references runpacks that are missing here; agents should fall back to `source_run_path` and report `path` in the indexes instead of expecting ZIP payloads.
- Run review manifest regeneration currently appears blocked by the absence of `results/**/run_review.json` manifests.

## Gaps and pain points
1. **Missing/absent run registry files**:
   - `docs/run_system.md` describes `results/<experiment>/run_index.csv` and `latest_run.txt` but they were not found on disk here.
   - In practice, enumeration works via `tools/list_runs.m`, and evidence resolution works via `analysis/knowledge/run_registry.csv` (so the evidence layer is usable even if run_index.csv is missing).
2. **Run review manifests are absent in this workspace**:
   - `tools/run_review/generate_run_review_manifests.m` exists, but `results/**/run_review.json` files are not present right now, limiting regeneration.
3. **Context bundles are lossy with respect to evidence traceability**:
   - `docs/context_system_audit.md` notes bundle claims include only reduced fields; evidence links live elsewhere (claims/reports/run review).
4. **Snapshot smart layer is “minimal and partially payload-free” in this workspace**:
   - Indices exist (run/analysis/report/claim/evidence edges), but runpack ZIP payloads are not present.
5. **No single “fully normalized evidence index” for the complete repository**:
   - snapshot_scientific_v3 provides an index, but it appears to cover a minimal set of claims/analyses/runs rather than all repository artifacts.

## Recommended foundation to build on (shortest path to usability)
Shortest path to make a “usable knowledge system” for agents in this repo:
1. **Use `docs/context_bundle_full.json` as the semantic entry point** (vocabulary + claim summaries + state).
2. **Use `snapshot_scientific_v3` indexes as the deterministic evidence navigation control plane**, but resolve evidence to the local filesystem using:
   - `snapshot_scientific_v3/30_runs_evidence/run_index.json` (`source_run_path`) instead of runpacks ZIPs.
   - `snapshot_scientific_v3/50_reports_knowledge/report_index.json` (`path`) for report evidence.
3. **When an agent needs enumeration and evidence resolution**, prefer:
   - `analysis/query/query_system.m` (bounded query + ranked candidate selection)
   - `analysis/knowledge/load_run_evidence.m` / `analysis/knowledge/run_registry.csv` (run_id -> evidence paths)
   - fallback: `tools/list_runs.m` and `tools/load_run_manifest.m` for raw manifest-based enumeration.
   - Use `tools/export_observables.m` / `tools/load_observables.m` for aggregating `observables.csv`.

This approach avoids dependence on absent `run_index.csv`/`latest_run.txt` and avoids dependence on missing `run_review.json` payloads, while still leveraging the most structured “knowledge navigation” assets already present.

