# Draft: Minimal Knowledge-System Quickstart (Uses Existing Systems Only)

This is a *future* quickstart draft that exposes the shortest workable path using only what already exists in the repo (no new architecture).

## For Humans: “What’s going on, and where is the evidence?”

1. Start with project overview (semantic vocabulary)
   - `docs/context_bundle_full.json` (or `docs/context_bundle.json` if you want a smaller file)
2. For a specific scientific claim, open the claim file
   - `claims/<claim_id>.json`
   - Read `statement`, `status`, and `confidence`
   - Use `evidence.reports` and `evidence.runs` as the navigation pointers
3. Open the canonical run artifact layout (so you know where to look once you have a run folder)
   - `results/README.md`
4. Find run folders and latest artifacts
   - Use `tools/list_runs.m` (per experiment) and/or `tools/openLatestRun.m`
   - In a run folder, inspect:
     - `run_manifest.json`, `config_snapshot.m`, `run_notes.txt`
     - `reports/*.md` for the human narrative evidence
     - `observables.csv` at the run root when present
5. For “what’s supported vs pending” in rolling form
   - Browse surveys in `surveys/*/rolling_survey.md` (starting from `surveys/registry.json`)

## For Internal Agents: “How do I use the knowledge layer to answer tasks?”

1. Follow the agent gate
   - Read `docs/context_bundle.json` before tasks (agent rules)
   - Optionally use `docs/context_bundle_full.json` for deeper semantic context
2. Choose a claim/question target
   - Claim IDs come from `docs/context_bundle*.json` and/or by inspecting `claims/`
3. Resolve evidence pointers from the claim file
   - Open `claims/<claim_id>.json`
   - Collect:
     - report paths from `evidence.reports`
     - run IDs from `evidence.runs`
4. Locate the run folders (current repo workflow)
   - There is no single `run_id -> (experiment, run_path)` resolver in the tooling today.
   - Use one of:
     - Guess the experiment from the run label/name, then use `tools/list_runs.m` for that experiment and match the folder name to the `run_id`
     - Or manually browse under `results/*/runs/` for the folder named exactly `run_id`
5. Load/inspect evidence artifacts
   - If you have a run directory path, use:
     - `tools/load_run_manifest.m` to validate identity/provenance
   - Then read:
     - `reports/*.md`
     - `observables.csv` (run root) if you need numeric summaries
6. For cross-run knowledge extraction
   - Use `tools/load_observables.m` to aggregate observables.csv across runs

## Sharing outside the repo (human/agent handoff)

1. Regenerate/refresh context bundles (optional but recommended)
   - `scripts/update_context.ps1` (updates `docs/context_bundle*.json`)
2. Build a shareable snapshot
   - `scripts/run_snapshot.ps1` to create `snapshot_repo.zip`
   - Optionally use `scripts/build_snapshot_simple.ps1` for smaller `snapshot_*` bundles
3. Receiver-side usage
   - Start from `docs/context_bundle*.json` and `claims/*.json`
   - Follow `evidence` pointers into `reports/` and `results/*/runs/*/`

