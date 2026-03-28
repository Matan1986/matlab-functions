# Knowledge System Usability Audit (Read-Only)

## Executive summary
The repo already has a multi-layer knowledge system built around: (1) a project state vocabulary (`docs/repo_state.json` + semantic model docs), (2) machine-readable context bundles (`docs/context_bundle*.json`), (3) explicit scientific claims (`claims/*.json`) and (4) run-scoped evidence/narratives (`results/<experiment>/runs/...`, plus `reports/`). For sharing and “handoff,” there are snapshot packaging scripts (`scripts/run_snapshot.ps1`, `scripts/build_snapshot_simple.ps1`) and a frozen “smart layer” index (`snapshot_scientific_v3/`) meant to provide deterministic navigation across claim → runs → reports.

In practice, usability friction is mostly about *entry points*: there is no single, human-friendly “start here” page for the knowledge system, and the agent experience is blocked by missing/partial normalized indices that would otherwise resolve `claim_id -> run folder path` (or `run_id -> experiment/results path`) without manual work. Additionally, the run-review layer (`results/**/run_review.json`) is currently absent, which makes the survey regeneration workflow fragile.

This audit focuses on *what exists today*, and how a human or internal agent can use it without getting lost.

## Current user workflows (humans)

### 1. “What is the project right now?” (baseline understanding)
Start from one of:
1. `docs/context_bundle_full.json` (most complete, includes extended semantic model)
2. `docs/context_bundle.json` (smaller; includes claim summaries + core state)
3. `docs/repo_state.json` (ground truth baseline state, used by bundle generation)

How to use:
1. Read `docs/context_bundle*.json` to learn the vocabulary (`X`, `R`, `A`, roles/meaning) and the active module boundaries.
2. For scientific assertions, consult `claims/<claim_id>.json`.
3. For “what’s pending/eligible,” browse surveys in `surveys/*/rolling_survey.md` (these are human-readable, but may be stale because run-review manifests are missing).

### 2. “What evidence supports claim X?” (claim → reports/runs)
Entry point:
1. `claims/<claim_id>.json`

How to use:
1. Open the claim file and read `statement`, `status`, `confidence`, then the `evidence` section.
2. For each evidence report path listed under `evidence.reports`, open the Markdown in `reports/` or the referenced run-local report paths (as stored in the JSON).
3. For each evidence run id listed under `evidence.runs`, locate the run folder under `results/<experiment>/runs/<run_id>/` by manual browsing (or by using `tools/list_runs.m` once you guess the experiment).

What a human typically finds confusing:
1. Context bundles are “lossy” with respect to evidence traceability: they summarize claims but do not provide the evidence chain.
2. There is no single in-repo tool that resolves `run_id -> results/<experiment>/runs/<run_id>` automatically.

### 3. “Where do I look for the latest run artifacts?” (filesystem browsing)
Entry points:
1. `tools/list_runs.m` (lists run folders for a specific experiment and reads `run_manifest.json` when present)
2. `tools/getLatestRun.m` + `tools/openLatestRun.m` (opens the newest folder by name pattern)

How to use:
1. Run `list_runs('<experiment>')` to see available run folders and their manifest metadata.
2. Use `openLatestRun('<experiment>')` to jump to the latest run directory.
3. Inside a run folder, read:
   - `run_manifest.json`, `config_snapshot.m`, `run_notes.txt`, `log.txt`
   - `reports/*.md` for narrative summaries
   - optional `observables.csv` at the run root (when present)

Current limitation for “latest reliable state”:
`openLatestRun` selects by newest folder name, not by review/approval status (because run-review manifests are currently absent).

### 4. “How do I share project context with another agent outside the repo?”
Entry points:
1. `scripts/run_snapshot.ps1` (creates a large, shareable `snapshot_repo.zip`)
2. `scripts/build_snapshot_simple.ps1` (creates smaller snapshot bundles + copies context bundles)

How to use:
1. Run `scripts/run_snapshot.ps1` and take the produced `snapshot_repo.zip` from the configured output directory.
2. On the receiving side, open `docs/context_bundle*.json` and the claim/reports/run evidence inside the snapshot.

What’s confusing:
1. There are multiple “snapshot designs” (system design docs, shareable snapshot design docs, and snapshot_scientific_v3 indices), but only some of them are fully produced by the current scripts.
2. The large snapshot payload can include noise (e.g. `.git`/local pref-like folders), which makes it harder for a receiver to focus.

## Current agent workflows (internal coding agents)

### 1. Agent gate (required read)
The repo explicitly instructs agents to read:
1. `docs/context_bundle.json` before starting (source-of-truth gate)
2. Optionally `docs/context_bundle_full.json` for deeper semantic/ChatGPT use
3. Also: `docs/AGENT_RULES.md` for run/output safety constraints

Entry points:
1. `docs/AGENT_ENTRYPOINT.md` (short instruction)
2. `docs/AGENT_RULES.md` (formal behavior rules; includes “RUN → SNAPSHOT → CONTEXT → TASK”)

Current usability:
High for “don’t violate repo rules” and medium for “how to find evidence fast.”

### 2. Claim/observable → evidence navigation (agent)
Entry points:
1. `docs/context_bundle*.json` (claim summaries + shared vocabulary)
2. `claims/<claim_id>.json` (full claim schema + `evidence.reports` and `evidence.runs`)
3. `tools/load_run_manifest.m` and the run root artifact layout (`docs/results_system.md`)

How to use:
1. From `context_bundle`, pick `claim_id`s (e.g. `X_scaling_relation`, `X_canonical_coordinate`).
2. Open `claims/<claim_id>.json` and read `evidence.reports` and `evidence.runs`.
3. For each `evidence.run` id, locate the run directory under `results/` (manual browsing or experiment guessing).
4. Use `tools/load_run_manifest.m` to extract metadata; then open `reports/*.md` and optional `observables.csv` in the run root.

Where this breaks for agents:
1. The “run_id -> run folder path” resolution is not automated.
2. Run-review manifests (`run_review.json`) are absent, so there is no reliable, machine-checkable “approved vs pending” gating.
3. `surveys/*/rolling_survey.md` exists, but regenerating it may require missing `results/**/run_review.json`.

### 3. Aggregated observables usage (agent)
Entry points:
1. `tools/load_observables.m` (aggregate `observables.csv` across run roots)
2. `tools/export_observables.m` (standardize schema when creating new `observables.csv`)

How to use:
1. If you need a cross-run observable table, call `load_observables()` (optionally with a results root).
2. Use `export_observables` when generating new run-level summary indexes.

Current usability:
High, because this layer is standardized and uses consistent run-root exchange semantics.

## Snapshot and context-sharing workflows

### 1. Context bundle generation (in-repo)
Entry point:
1. `scripts/update_context.ps1`

What it does:
1. Reads `docs/repo_state.json`
2. Reads `docs/model/repo_state_description.json` and `docs/model/repo_state_full_description.json`
3. Reads `claims/*.json` and extracts a reduced claim summary
4. Writes:
   - `docs/context_bundle.json`
   - `docs/context_bundle_full.json`

Implication:
If the bundle feels stale, re-run `scripts/update_context.ps1`.

### 2. Full snapshot packaging for sharing with external agents
Entry point:
1. `scripts/run_snapshot.ps1`

What it does (observed from script structure):
1. Creates `snapshot_repo.zip` under the configured `L:\My Drive\For agents\snapshot\auto\...` output path
2. Builds a “snapshot_simple” set by running `scripts/build_snapshot_simple.ps1`
3. Updates context bundles by running `scripts/update_context.ps1`

How receivers use it:
1. Inside the snapshot ZIP, read `docs/context_bundle*.json` and `claims/*.json`
2. Follow claim evidence into `reports/` and `results/*/runs/*/`

### 3. Snapshot_simple (smaller bundles)
Entry point:
1. `scripts/build_snapshot_simple.ps1`

What it does:
1. Builds:
   - `snapshot_core.zip` (contains `docs/repo_state.json`)
   - `snapshot_<experiment>.zip` for `aging`, `switching`, `relaxation` (contains the corresponding `results/<experiment>/` subtree)
   - `snapshot_cross.zip` and `snapshot_code.zip` for cross-experiment reports and analysis code
2. Copies `docs/context_bundle*.json` into the output directory as loose files

Trade-off:
Simpler for humans/agents to handle (smaller payload), but less “smart-layer” friendly than the planned shareable snapshot tree.

## Friction points (what breaks in practice)

### A) Discovery and entry points are fragmented
There are many relevant docs/scripts, but no single “knowledge system quickstart” for humans and agents in the current repo root. Humans must infer where to start: `results/README.md`, `docs/repository_map.md`, `docs/context_bundle*.json`, `claims/`, `surveys/`, `tools/list_runs.m`, etc.

### B) Evidence navigation requires manual resolution steps
Even though claims contain evidence pointers, agents/humans still must resolve:
1. `evidence.run_id -> which results/<experiment>/runs/<run_id> folder`
2. run-local report paths inside run folders

There is no single tool/index that resolves the above, so evidence traversal can become guess-and-check.

### C) Run-review / survey regeneration is unreliable
`tools/run_review/generate_run_review_manifests.m` exists, but `results/**/run_review.json` files are not present in this workspace right now. That makes `tools/survey_builder/build_rolling_surveys.m` require regeneration steps that may not be possible without creating those manifests for all runs.

### D) Specs mention run registries that do not exist here
`docs/run_system.md` describes `results/<experiment>/run_index.csv` and `latest_run.txt`, but those files are not found on disk. Current discovery relies on filesystem scanning + `run_manifest.json` parsing (`tools/list_runs.m`, `tools/getLatestRun.m`).

### E) “Smart layer” indices reference payload zips that are missing here
`snapshot_scientific_v3/` contains control-plane indices and edges, but referenced “runpacks” ZIPs are not present in the workspace. That means the deterministic navigation protocol can be incomplete unless payloads are supplied by a snapshot builder that is not currently reproducing those runpacks.

## Important systems: entry points and practical usability

| System | Start file/script | How someone discovers it | How someone invokes it | Current usability | Biggest confusing/missing part |
| --- | --- | --- | --- | --- | --- |
| Project state model | `docs/repo_state.json` (plus `docs/model/*`) | Search for `repo_state` or follow bundle generation references | Read JSON directly; used by context bundle generator | High | It is not a “how to navigate evidence” interface on its own |
| Context bundles | `docs/context_bundle.json` / `docs/context_bundle_full.json` | `docs/AGENT_RULES.md` and `docs/repository_map.md` explicitly say to read it | Read JSON directly; refresh via generator | High to medium | Bundles are semantically rich but lossy for evidence traceability (evidence is in claims/run layers) |
| Context bundle generator | `scripts/update_context.ps1` | Listed in snapshot/context docs and the agent workflow gate | PowerShell: run script to regenerate bundles | High | If you don’t re-run after updates to claims/state, it can silently drift |
| Claims registry | `claims/<claim_id>.json` (and `claims/README.md`) | `docs/context_bundle*.json` surfaces claim IDs; `claims/README.md` documents schema | Open claim JSON and follow `evidence.reports` / `evidence.runs` | High | Agents/humans still need run-folder resolution; there is no “claim -> local run paths” helper |
| Run evidence + summaries | Run folder layout under `results/<experiment>/runs/<run_id>/` (see `results/README.md`) | `results/README.md` and `docs/results_system.md` define where evidence lives | Browse run folders; read `run_manifest.json`, `reports/*.md`, optional `observables.csv` | High | “Latest reliable state” is unclear because run-review/status gating is missing |
| Run discovery + numeric exchange | `tools/list_runs.m`, `tools/openLatestRun.m`, `tools/load_observables.m` | `docs/run_system.md`, `docs/results_system.md`, `results/README.md` link to these helpers | Use MATLAB tools to enumerate and aggregate | High | No cross-experiment `run_id -> run_path` resolver |
| Surveys/review layer | `surveys/registry.json` and `surveys/*/rolling_survey.md` | Surveys appear as rolling markdown indices; survey builder references run-review manifests | Read surveys directly; regenerate via `tools/survey_builder/build_rolling_surveys.m` | Medium (read-only) | Regeneration is fragile because `results/**/run_review.json` is absent here |
| Snapshot packaging + smart indices | `scripts/run_snapshot.ps1`, `scripts/build_snapshot_simple.ps1`, `snapshot_scientific_v3/00_entrypoints/quick_start.json` | `docs/snapshot_system_map.md` and `docs/snapshot_shareable_design*.md` plus scripts folder | Generate `snapshot_repo.zip` or simpler `snapshot_*` zips; read indices inside snapshot/scientific layer | Medium | Multiple “designs” exist; current scripts don’t fully materialize the runpack payloads referenced by `snapshot_scientific_v3` |

## Missing entry points (what a newcomer would wish existed)

1. A single “human knowledge quickstart” doc that says exactly which file to open first and which tool to run next.
2. A single “agent knowledge quickstart” doc (or script) that turns `docs/context_bundle*.json + claim_id` into a concrete list of run folders and report files—without manual run_id → experiment resolution.
3. A reusable `run_id -> run folder path` index/tool (or snapshot_scientific_v3 run index wired to local filesystem resolution).
4. A run-review manifest bootstrap for this workspace (so surveys can be regenerated reliably).
5. A clarity layer for snapshot selection: when to use `snapshot_repo.zip` vs `snapshot_simple` zips vs snapshot_scientific_v3 indices.

## Recommended minimal future interface (no redesign; reuse what exists)

### One main entry point for humans (recommended target)
Recommended doc (to be created later) should *primarily link* to existing systems:
1. `results/README.md` (run artifact layout)
2. `claims/README.md` + `claims/*.json` (what is claimed + evidence pointers)
3. `surveys/registry.json` + `surveys/*/rolling_survey.md` (what is supported/pending)
4. `docs/context_bundle_full.json` (project vocabulary baseline)
5. `tools/list_runs.m` / `tools/openLatestRun.m` (latest browsing)

What it should hide:
1. The deep policy docs (`docs/AGENT_RULES.md`, `docs/results_system.md`) after a single short safety note.

### One main entry point for agents (recommended target)
Recommended agent entrypoint should reuse existing, but add a missing resolution step:
1. Start with `docs/context_bundle.json` (claim list + vocabulary)
2. Resolve evidence through `claims/<claim_id>.json` (evidence.run + evidence.report)
3. Use (or precompute) a normalized local index for `run_id -> (experiment, run_path)` so agents can open run reports without guessing

Reuse suggestions:
1. Use `tools/list_runs.m` as the basis of an index builder
2. Use `tools/load_run_manifest.m` to validate paths
3. Optionally reuse snapshot_scientific_v3 indices as a control plane (when payload zips exist)

