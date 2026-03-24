# SYSTEM STRESS TEST REPORT

## 1. Overall Verdict
PARTIAL

The index layer is mostly deterministic, but canonical payload resolution is not executable end-to-end because referenced snapshot payload bundles are missing and edge coverage is incomplete.

## 2. Determinism Score
5/10

## 3. Usability Score
3/10

## 4. Navigation Complexity
Average steps per task: 5.4

Per task:
- Test 1 (claim validation): 8 steps
- Test 2 (analysis loading): 5 steps
- Test 3 (run debug): 5 steps
- Test 4 (partial extraction): 6 steps
- Test 5 (reverse navigation): 3 steps

## 5. Critical Issues
- `30_runs_evidence/runpacks/` is empty while `run_index.json` references 10 runpack ZIPs (10/10 missing).
- `20_code_workflow/` is empty while all runs reference `20_code_workflow/code_core_dynamics.zip`.
- `10_context_state/` is empty while `quick_start.json` requires `10_context_state/context_bundle_full.zip`.
- Claim evidence graph coverage is partial: only 2 of 7 claims appear in `evidence_edges_claim_to_run.jsonl` and `evidence_edges_claim_to_report.jsonl`.
- Analysis-to-run edges are incomplete: `analysis_r_x_reconciliation` exists in `analysis_registry.json` but has no entry in `evidence_edges_analysis_to_run.jsonl`.
- Evidence drift exists between `claims/*.json` and `70_evidence_index/evidence_summary.json` (6 claims with run-list mismatch, 2 with status mismatch).

## 6. Minor Frictions
- `analysis__<id>.manifest.json` includes `report_ids` but not report paths, forcing extra hop to `report_index.json`.
- Reverse navigation has no direct `run_id -> claim_ids` index; user must join via analyses.
- Claims use report paths, while index graph uses report IDs, adding conversion overhead.

## 7. Redundancy Risks
- Claim-level evidence duplicated across:
  - `claims/*.json` (`evidence.runs`, `evidence.reports`)
  - `70_evidence_index/evidence_summary.json` (`primary_runs`, `key_reports`)
  - `70_evidence_index/evidence_edges_*.jsonl`
- `60_claims_surveys/claims_evidence_map.json` duplicates claim-evidence mapping but is mostly empty for 5/7 claims.
- Drift risk is active, not hypothetical (mismatched runs/status already present).

## 8. Naming Issues
- Claim IDs: consistent (`X_*`).
- Analysis IDs: consistent (`analysis_*`).
- Observable IDs in catalog: consistent (`X`, `A`, `R`).
- Aliasing risk in raw run names outside snapshot index: mixed lowercase/uppercase tokens (`x_*`, `R_X_*`, `AX_*`) can confuse manual lookup.

## 9. Reverse Navigation Quality
partial

Why:
- Works deterministically via `run_index.json -> analysis_registry.json -> claim_index.json`.
- No direct reverse edge/index from run to claims.
- Edge-based reverse route is incomplete because `analysis_r_x_reconciliation` is missing from `evidence_edges_analysis_to_run.jsonl`.

## 10. Minimal Bundle Capability
partial

Why:
- Index-only minimal extraction works.
- Snapshot-contained payload extraction fails because runpacks and code bundle are not materialized.
- Practical workaround exists via `source_run_path` in the full repository, but that breaks the intended shareable-snapshot contract.

## 11. Recommendations (NON-DESTRUCTIVE ONLY)
- Populate the already-referenced files only (no structural redesign):
  - `30_runs_evidence/runpacks/*.zip`
  - `20_code_workflow/code_core_dynamics.zip`
  - `10_context_state/context_bundle_full.zip`
- Synchronize `evidence_summary.json` from one canonical evidence source to eliminate run/status drift.
- Complete missing edge coverage for existing entities only:
  - add missing claim edges for current claim IDs
  - add missing analysis edge rows for `analysis_r_x_reconciliation`
- Add one small derived shortcut index `run_id -> claim_ids` to remove reverse-navigation joins.
- Normalize claim/report reference style by adding path<->report_id mapping in one authoritative index file.

---

## Test-by-Test Execution

### TEST 1 — CLAIM VALIDATION FLOW
Query: `prove X_scaling_relation`

Expected path: `claim_index -> evidence_summary -> evidence_edges -> run_index -> runpack -> report`

Files accessed (in order):
1. `snapshot_scientific_v3/60_claims_surveys/claim_index.json`
2. `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`
3. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl`
4. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_report.jsonl`
5. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
6. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`
7. `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/reports/AX_functional_relation_analysis.md`
8. `snapshot_scientific_v3/30_runs_evidence/runpacks/runpack__cross_experiment__run_2026_03_13_115401_AX_functional_relation_analysis__v2026_03_23.zip` (missing)

Step count: 8

Ambiguity/branching:
- Branch required after step 8 because runpack is missing; user must fallback to `source_run_path`.
- `evidence_summary` vs claim JSON disagree on status granularity (`supported` vs `strong`).

Unnecessary files:
- `evidence_summary.json` is optional for strict provenance proof (edges + indices suffice), but needed for quick interpretation.

Result:
- Deterministic for this specific claim ID, but canonical payload step fails.

### TEST 2 — ANALYSIS LOADING
Query: `load analysis_ax_scaling`

Expected path: `analysis_registry -> analysis_manifest -> evidence_edges_analysis_to_run -> run_index -> reports`

Files accessed (in order):
1. `snapshot_scientific_v3/40_analysis_catalog/analysis_registry.json`
2. `snapshot_scientific_v3/30_runs_evidence/analysis_views/analysis__analysis_ax_scaling.manifest.json`
3. `snapshot_scientific_v3/70_evidence_index/evidence_edges_analysis_to_run.jsonl`
4. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
5. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`

Step count: 5

Determinism:
- Deterministic for `analysis_ax_scaling`.

Missing links:
- None for this analysis.
- Global inconsistency still exists (another analysis missing edge rows).

Manifest sufficiency:
- Not sufficient alone; requires `report_index.json` to resolve report IDs into file paths.

### TEST 3 — RUN DEBUG
Query: `inspect run_2026_03_12_234016_switching_full_scaling_collapse`

Expected path: `run_index -> runpack -> report -> code_bundle`

Files accessed (in order):
1. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
2. `snapshot_scientific_v3/30_runs_evidence/runpacks/runpack__switching__run_2026_03_12_234016_switching_full_scaling_collapse__v2026_03_23.zip` (missing)
3. `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/run_manifest.json` (fallback path)
4. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`
5. `snapshot_scientific_v3/20_code_workflow/code_core_dynamics.zip` (missing)

Step count: 5

Checks:
- `run_index` is a sufficient entrypoint for locating references.
- Runpack completeness cannot be verified because file is absent.
- Code bundle mapping exists in index but payload is absent.

Missing/redundant references:
- Presence of both `runpack_path` and `source_run_path` creates branch behavior when runpack is missing.

### TEST 4 — PARTIAL KNOWLEDGE EXTRACTION
Query: `extract minimal bundle for X_scaling_relation`

Minimal required files:
1. `snapshot_scientific_v3/60_claims_surveys/claim_index.json`
2. `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`
3. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl`
4. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_report.jsonl`
5. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
6. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`
7. Referenced report files (at minimum: run-local + global evidence files)

Step count: 6

Unrelated files required:
- None.

Partial-sharing quality:
- Clean at index layer.
- Not clean for portable payload sharing because runpacks are absent.

### TEST 5 — REVERSE NAVIGATION
Start: `run_id` only

Path tested:
1. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
2. `snapshot_scientific_v3/40_analysis_catalog/analysis_registry.json`
3. `snapshot_scientific_v3/60_claims_surveys/claim_index.json`

Step count: 3

Difficulty:
- Medium (requires one join operation through `analysis_ids`).

Asymmetry:
- Yes. Forward claim path is explicit; reverse path is implicit and join-based.

### TEST 6 — ZERO-THINKING TEST
Cognitive load and decision points:
- Test 1: Medium-high, 4 decision points
- Test 2: Medium, 2 decision points
- Test 3: High, 4 decision points
- Test 4: Medium-high, 3 decision points
- Test 5: Medium, 2 decision points

Conclusion:
- Near-zero decision navigation target is not met.

### TEST 7 — REDUNDANCY + DRIFT
Detected:
- Run evidence mismatch between claim files and summary for 6 claims:
  - `X_adversarial_robustness`
  - `X_broad_basin`
  - `X_canonical_coordinate`
  - `X_not_temperature_reparameterization`
  - `X_pareto_nondominated`
  - `X_peak_alignment`
- Status mismatch between claim index and summary for 2 claims:
  - `X_canonical_coordinate` (`supported` vs `strong`)
  - `X_scaling_relation` (`supported` vs `strong`)
- Claim/report mapping mismatch: 5 claims reference report paths not represented in `report_index.json`.

### TEST 8 — NAMING CONSISTENCY
Checks:
- Claim IDs: pass
- Analysis IDs: pass
- Observable IDs in catalog: pass
- Alias risk: present in external run naming conventions (`x_*` vs `X`-centric catalog)

### TEST 9 — EVIDENCE SUMMARY QUALITY
Per-claim summary fields (`primary_runs`, `key_reports`, `status`, explanation) are present for all 7 claims.

Sufficiency verdict:
- High-level orientation: sufficient.
- Basic deterministic proof without raw edges: partial.
- Strict provenance validation: still requires edges, and edge coverage exists only for 2 claims.
