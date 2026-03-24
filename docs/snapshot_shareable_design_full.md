# Complete Shareable Snapshot Design (Final Precision Pass)

## 0) What Was Added in This Pass
This pass does not redesign the system. It adds deterministic usability and rigor layers to the existing `snapshot_scientific_v3` structure.

Implemented files:
- `snapshot_scientific_v3/00_entrypoints/canonical_resolution_path.json`
- `snapshot_scientific_v3/00_entrypoints/quick_start.json`
- `snapshot_scientific_v3/00_entrypoints/navigation_shortcuts.json`
- `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`
- `snapshot_scientific_v3/40_analysis_catalog/status_evaluation_rules.json`
- `snapshot_scientific_v3/80_question_packs/question_pack_generation_rule.json`
- plus supporting indices/manifests/edges required for deterministic resolution.

## 1) Official Canonical Resolution Path (Single Path)
Official path:

`claim_id -> evidence -> run_ids -> runpack -> code`

Authoritative implementation file:
- `snapshot_scientific_v3/00_entrypoints/canonical_resolution_path.json`

Deterministic steps and files:
1. Resolve claim metadata:
- `snapshot_scientific_v3/60_claims_surveys/claim_index.json`

2. Resolve claim evidence links (runs + reports):
- `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl`
- `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_report.jsonl`
- optional high-level view:
  - `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`

3. Resolve run IDs to runpacks:
- `snapshot_scientific_v3/30_runs_evidence/run_index.json`

4. Load run evidence payload:
- `snapshot_scientific_v3/30_runs_evidence/runpacks/runpack__<experiment>__<run_id>__v<snapshot_version>.zip`

5. Resolve matching code bundle:
- `snapshot_scientific_v3/30_runs_evidence/run_index.json` (`code_bundle` field)
- typically:
  - `snapshot_scientific_v3/20_code_workflow/code_core_dynamics.zip`

No alternative official path is defined.

## 2) Quick Start (Minimal Usability Layer)
Authoritative file:
- `snapshot_scientific_v3/00_entrypoints/quick_start.json`

It defines minimal file sets for:
- project understanding
- claim validation
- run debugging
- analysis loading

## 3) Evidence Summary Layer (Human + AI)
Authoritative file:
- `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`

Per claim includes:
- `primary_runs`
- `key_reports`
- `status`
- `short_explanation`

Concrete claims present:
- `X_canonical_coordinate`
- `X_scaling_relation`
- `X_peak_alignment`
- `X_pareto_nondominated`
- `X_broad_basin`
- `X_adversarial_robustness`
- `X_not_temperature_reparameterization`

## 4) Status Evaluation Rules (Rigor)
Authoritative file:
- `snapshot_scientific_v3/40_analysis_catalog/status_evaluation_rules.json`

Strict criteria implemented for:
- `exploratory`
- `robust`
- `canonical`

Each level includes:
- minimum evidence requirements
- cross-run consistency requirements
- cross-experiment requirements

## 5) Question Pack Generation Rule
Authoritative file:
- `snapshot_scientific_v3/80_question_packs/question_pack_generation_rule.json`

Enforced rule set:
- question packs generated only from indices/edges
- no manual duplication allowed
- update propagation defined from run/analysis/claim index changes

## 6) Simplified Navigation View
Authoritative file:
- `snapshot_scientific_v3/00_entrypoints/navigation_shortcuts.json`

Shortcuts implemented for:
- claim -> where to go
- analysis -> where to go
- run -> where to go
- observable -> where to go

## 7) Consistency Check (Mandatory)
Consistency output file:
- `snapshot_scientific_v3/00_entrypoints/consistency_check.json`

Checked and passed:
- example run IDs exist in `run_index.json`: `10/10`
- report paths in `report_index.json` exist on disk: `13/13`
- claim IDs in `claim_index.json` exist in `claims/*.json`: `7/7`
- evidence edge resolution:
  - claim->run edges resolved: `5/5`
  - claim->report edges resolved: `5/5`
  - observable->analysis edges resolved: `5/5`
  - analysis->run edges resolved: `5/5`
  - question->claim edges resolved: `3/3`

Inconsistencies found:
- none (`issues: []`)

## 8) Minimal Workflow Validation (Deterministic)

## A) Validate claim `X_scaling_relation`
Exact files used:
1. `snapshot_scientific_v3/60_claims_surveys/claim_index.json`
2. `snapshot_scientific_v3/70_evidence_index/evidence_summary.json`
3. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl`
4. `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_report.jsonl`
5. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
6. Physical evidence reports (resolved via `report_index.json`), including:
- `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/reports/AX_functional_relation_analysis.md`
- `reports/functional_form_scan_report.md`

Deterministic navigation steps:
1. Locate claim in `claim_index.json`.
2. Read `primary_runs` + `key_reports` from `evidence_summary.json`.
3. Verify edges in claim->run and claim->report files.
4. Resolve runpack paths via `run_index.json`.
5. Open mapped reports/runpacks and then mapped code bundle.

## B) Load analysis: AX scaling (`analysis_ax_scaling`)
Exact files used:
1. `snapshot_scientific_v3/40_analysis_catalog/analysis_registry.json`
2. `snapshot_scientific_v3/30_runs_evidence/analysis_views/analysis__analysis_ax_scaling.manifest.json`
3. `snapshot_scientific_v3/70_evidence_index/evidence_edges_analysis_to_run.jsonl`
4. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
5. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`

Deterministic navigation steps:
1. Resolve `analysis_ax_scaling` in `analysis_registry.json`.
2. Confirm status/observables/question from analysis manifest.
3. Resolve participating runs via `evidence_edges_analysis_to_run.jsonl`.
4. Resolve runpacks through `run_index.json`.
5. Resolve reports through `report_index.json`.

Real runs in this analysis:
- `run_2026_03_13_115401_AX_functional_relation_analysis`
- `run_2026_03_13_123230_AX_scaling_temperature_robustness`
- `run_2026_03_13_082753_switching_relaxation_bridge_robustness_a`

## C) Debug run `run_2026_03_12_234016_switching_full_scaling_collapse`
Exact files used:
1. `snapshot_scientific_v3/30_runs_evidence/run_index.json`
2. `snapshot_scientific_v3/30_runs_evidence/runpacks/runpack__switching__run_2026_03_12_234016_switching_full_scaling_collapse__v2026_03_23.zip` (resolved path)
3. `snapshot_scientific_v3/50_reports_knowledge/report_index.json`
4. `snapshot_scientific_v3/20_code_workflow/code_core_dynamics.zip`

Deterministic navigation steps:
1. Locate run row in `run_index.json`.
2. Open runpack path from that row.
3. Open run-local report via `report_id` mapping:
- `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/reports/switching_full_scaling_collapse.md`
4. Open code bundle from `code_bundle` field.

## 9) Canonical Authority and Precedence (Unambiguous)
Scope-based authority:
1. run-level conclusion -> run-local report in runpack
2. cross-run conclusion -> global synthesis report
3. claim statement -> claim JSON
4. survey conclusion -> rolling survey

Conflict precedence (numerical rigor):
1. raw run tables/metrics
2. run-local report
3. global report
4. claim summary
5. survey summary

Implementation reference:
- `snapshot_scientific_v3/50_reports_knowledge/report_authority_map.json`

## 10) Lightweight Usage Guarantee
The system is complete but lightweight because common tasks are index-first:
- claim task: `claim_index + evidence_summary + claim edges + run_index`
- analysis task: `analysis_registry + analysis manifest + analysis edges`
- run task: `run_index + one runpack`

No full snapshot scan is required for normal operations.

## 11) Real Repository Grounding (Examples Used)
Real claim IDs:
- `X_scaling_relation`
- `X_canonical_coordinate`

Real run IDs:
- `run_2026_03_12_234016_switching_full_scaling_collapse`
- `run_2026_03_13_115401_AX_functional_relation_analysis`
- `run_2026_03_16_080603_relaxation_temperature_scaling_test`

Real report paths:
- `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/reports/AX_functional_relation_analysis.md`
- `results/relaxation/runs/run_2026_03_16_080603_relaxation_temperature_scaling_test/reports/relaxation_temperature_scaling_report.md`
- `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/reports/switching_full_scaling_collapse.md`
- `reports/observable_search_report.md`

This precision pass finalizes the design into a deterministic, directly usable scientific knowledge system with one canonical navigation path.
