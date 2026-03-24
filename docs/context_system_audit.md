# Context System Audit

## 1) System Overview (All Layers)
This repository currently represents project knowledge across seven connected layers:

1. Snapshot packaging layer
- Canonical artifact: `L:\My Drive\For agents\snapshot\auto\snapshot_repo.zip` (generated `2026-03-22T14:55:21+02:00`)
- Contains 4 module ZIPs + `META/manifest.json` + `META/snapshot_info.json`

2. State model layer
- `docs/repo_state.json` (state baseline)
- `docs/model/repo_state_description.json` (core model semantics)
- `docs/model/repo_state_full_description.json` (extended model semantics)

3. Context bundle layer
- `docs/context_bundle.json` (minimal)
- `docs/context_bundle_full.json` (extended)
- Produced by `scripts/update_context.ps1`

4. Claims layer
- `claims/*.json` (X-centric scientific claims with evidence links)

5. Run output layer
- `results/<experiment>/runs/run_<timestamp>_<label>/...`
- Experiment roots currently: `aging`, `switching`, `relaxation`, `cross_experiment`, plus auxiliary roots (`cross_analysis`, `repository_audit`, etc.)

6. Run review / survey layer
- Per-run review manifests: `run_review.json`
- Per-run review artifacts: `.../review/` (often ZIP bundles)
- Rolling surveys: `surveys/*/rolling_survey.md`, `surveys/registry.json`

7. Report layer
- Run-local reports: `results/*/runs/*/reports/`
- Run-local review artifacts: `results/*/runs/*/review/`
- Aggregated/top-level reports: `reports/`
- Legacy/meta docs reports: `docs/reports/`

## 2) Tree-Like Structure of Each Layer

### A) Snapshot system
```text
snapshot_repo.zip
├─ core_infra.zip (~681.8 MB)
├─ unified_stack.zip (~1.3 MB)
├─ experimental_pipelines.zip (~0.21 MB)
├─ visualization_stack.zip (~68.5 MB)
└─ META/
   ├─ manifest.json
   └─ snapshot_info.json
```

`core_infra.zip` (dominant payload) includes:
```text
results/{aging,cross_experiment,switching,relaxation,...}/runs/...
docs/... 
reports/...
tools/...
.git/...
tmp/... and prefs
```

`unified_stack.zip` includes analysis code:
```text
Aging/{analysis,pipeline,diagnostics,tests,utils,...}
Switching/{analysis,utils}
Relaxation ver3/{diagnostics,...}
analysis/{cross-experiment synthesis scripts}
```

`experimental_pipelines.zip` includes experiment-specific code:
```text
AC HC MagLab ver8/
ARPES ver1/
FieldSweep ver3/
MH ver1/
MT ver2/
PS ver4/
Resistivity*/
Susceptibility ver1/
zfAMR ver11/{analysis,parsing,plots,tables,utils}
```

`visualization_stack.zip` includes UI/formatting assets:
```text
GUIs/{tests,reports,...}
General ver2/{appearanceControl,figureSaving,...}
github_repo/{ScientificColourMaps8,cmocean}
```

### B) Context bundles + state model
```text
docs/
├─ repo_state.json
├─ context_bundle.json
├─ context_bundle_full.json
└─ model/
   ├─ repo_state_description.json
   └─ repo_state_full_description.json
```

Bundle build rule (`scripts/update_context.ps1`):
- Both bundles include:
  - `claims` (reduced fields only)
  - `state` = full `docs/repo_state.json`
  - `model.core` = `docs/model/repo_state_description.json`
- Only full bundle adds:
  - `model.extended` = `docs/model/repo_state_full_description.json`

### C) Claims system
```text
claims/
├─ README.md
├─ X_canonical_coordinate.json
├─ X_scaling_relation.json
├─ X_peak_alignment.json
├─ X_pareto_nondominated.json
├─ X_broad_basin.json
├─ X_adversarial_robustness.json
└─ X_not_temperature_reparameterization.json
```

Common claim schema in practice:
- `claim_id`, `statement`, `status`, `role`, `confidence`
- optional: `constraints`, `source_runs`, `related_surveys`, `notes`
- `evidence`: `{ reports: [...], runs: [...] }`

### D) Run review + surveys
```text
results/*/runs/*/
└─ run_review.json

results/*/runs/*/review/
└─ *.zip (review bundles and archives)

surveys/
├─ registry.json
├─ aging_dynamics/rolling_survey.md
├─ switching_dynamics/rolling_survey.md
├─ relaxation_dynamics/rolling_survey.md
├─ cross_experiment/rolling_survey.md
└─ project_synthesis/rolling_survey.md
```

Observed review status distribution (`172` manifests):
- `pending_review`: `77`
- `not_required`: `65`
- `legacy_auto_approved`: `30`

### E) Report system
```text
results/*/runs/*/reports/   (311 files)
results/*/runs/*/review/    (208 files; many ZIP bundles)
reports/                    (20 top-level files)
docs/reports/               (11 files, legacy docs reports)
```

### F) Run outputs system
```text
results/
├─ aging/runs/ (88)
├─ switching/runs/ (97)
├─ relaxation/runs/ (36)
├─ cross_experiment/runs/ (166)
├─ repository_audit/runs/ (5)
├─ cross_analysis/runs/ (1)
├─ phaseC/runs/ (1)
├─ legacy_root/runs/ (1)
└─ review/runs/ (3)
```

Common files in run roots:
- `run_manifest.json` (`387` runs)
- `run_notes.txt` (`385` runs)
- `config_snapshot.m` (`378` runs)
- `run_review.json` (`172` runs)
- `observables.csv` only in `22` runs
- `observable_matrix.csv` only in `11` runs (mostly under `tables/`)

## 3) Layer Roles (What each layer is doing)

### Snapshot layer role
- Export/share transport format.
- Functionally: one large mixed archive (`core_infra`) + smaller code/tooling archives.
- Where results/reports/X-analysis live: mainly `core_infra.zip -> results/...` and `core_infra.zip -> reports/...`.

### Context bundle role
- Machine-readable context handoff for agents/humans.
- `context_bundle.json` = baseline state + core model + claim summaries.
- `context_bundle_full.json` = baseline + core model + extended semantic model.

### Claims role
- Claims are explicit scientific assertions with confidence and linked evidence (run IDs + report paths).
- Coverage is strongly X-focused (canonical coordinate, scaling, Pareto, robustness, non-temperature explanation).

### Survey/review role
- `run_review.json`: per-run review state and eligibility metadata.
- `review/` folders: packaged evidence bundles.
- `surveys/*/rolling_survey.md`: synthesized status of claims and pending reviewed runs.

### Reports role
- `results/*/runs/*/reports/`: run-specific narrative outputs.
- `results/*/runs/*/review/`: packaged review artifacts (often ZIP).
- `reports/`: cross-run synthesis reports (X defense, basin, null tests, etc.).
- `docs/reports/`: legacy documentation reports.

### Run output role
- Ground-truth empirical layer (manifests, notes, figures, tables, archives).
- Practical source for evidence extraction.

## 4) X-Related Knowledge: Where It Is Stored

### A) Claims (explicit scientific statements)
- `claims/X_canonical_coordinate.json`
- `claims/X_scaling_relation.json`
- `claims/X_peak_alignment.json`
- `claims/X_pareto_nondominated.json`
- `claims/X_broad_basin.json`
- `claims/X_adversarial_robustness.json`
- `claims/X_not_temperature_reparameterization.json`

### B) Top-level synthesis reports (cross-run)
- `reports/observable_search_report.md`
- `reports/stability_basin_report.md`
- `reports/dimensionless_constrained_basin_report.md`
- `reports/pareto_x_defense_report.md`
- `reports/adversarial_observable_report.md`
- `reports/speak_vs_x_cross_experiment_report.md`
- `reports/subset_stability_report.md`
- `reports/temperature_null_test_report.md`
- `reports/functional_form_scan_report.md`

### C) Key X-related run IDs and run-local report locations

AX scaling / A~X relation:
- `run_2026_03_13_115401_AX_functional_relation_analysis`
  - `results/cross_experiment/runs/run_2026_03_13_115401_AX_functional_relation_analysis/reports/AX_functional_relation_analysis.md`
- `run_2026_03_13_121414_AX_power_law_exponent_summary`
  - `.../reports/AX_power_law_exponent_summary.md`
- `run_2026_03_13_123230_AX_scaling_temperature_robustness`
  - `.../reports/AX_scaling_temperature_robustness.md`

Adversarial / observable search:
- `run_2026_03_13_071713_switching_composite_observable_scan`
  - `.../reports/switching_composite_observable_scan.md`
- `run_2026_03_22_080529_x_single_observable_residual_test`
  - `.../reports/x_independence_single_observable_report.md`
- `run_2026_03_22_080734_x_single_observable_residual_test_corrected`
  - `.../reports/x_independence_single_observable_report.md`

Subset stability / basin:
- `run_2026_03_13_082753_switching_relaxation_bridge_robustness_a`
  - `.../reports/switching_relaxation_bridge_robustness_audit.md`
- `run_2026_03_22_091808_dimensionless_constrained_basin_scan`
  - `.../reports/dimensionless_constrained_basin_scan.md`

Temperature null / non-triviality:
- `run_2026_03_13_154252_switching_joule_heating_null_test`
  - `.../reports/switching_joule_heating_null_test.md`
- `run_2026_03_13_160239_switching_joule_heating_null_test`
  - `.../reports/switching_joule_heating_null_test.md`

R-X reconciliation / cross-link:
- `run_2026_03_16_173307_R_X_reconciliation_analysis`
  - `.../reports/R_X_reconciliation_analysis.md`

## 5) Problems, Redundancies, and Navigation Friction

1. Knowledge is split across too many report layers
- Same topic appears in run reports, run review ZIPs, top-level `reports/`, and `docs/reports/`.
- Example duplicates: repeated basenames (`aging_observable_summary.md`, `observable_basis_sufficiency_report.md`, many ZIP bundles).

2. Claims in bundles are lossy summaries
- Bundle `claims` include only `{claim_id, statement, status, role, confidence}`.
- Claim evidence (`evidence.reports`, `evidence.runs`, notes, constraints) is not included in bundles.
- This weakens direct traceability from bundle -> proof artifacts.

3. Snapshot module semantics are imbalanced
- Most actionable scientific outputs are concentrated inside `core_infra.zip`.
- Other modules are mostly code/assets.
- `core_infra.zip` also mixes `.git`, tmp, prefs, and infra noise with results.

4. Run-output schema is only partially populated
- `run_manifest.json` is common, but `observables.csv` and `observable_matrix.csv` are sparse relative to run count.
- `run_system` expectations are not consistently met across runs.

5. Review/survey pipeline has high pending volume
- `pending_review` remains high (`77`).
- Surveys (for example `surveys/cross_experiment/rolling_survey.md`) list many pending runs.
- Approved conclusions are not strongly centralized into a compact canonical index.

6. Duplication between review ZIPs and report markdown
- Many runs store both textual reports and separately packaged review bundles with overlapping content.

## 6) Knowledge Flow (Critical)

Current observed flow:

```text
raw data + module scripts
  -> run execution under results/*/runs/run_.../
  -> run-local outputs (manifest/notes/figures/tables/reports)
  -> optional review packaging (review/*.zip + run_review.json)
  -> top-level synthesis reports (reports/*.md)
  -> claims/*.json (explicit statements + evidence links)
  -> rolling surveys (surveys/*/rolling_survey.md)
  -> context bundles (docs/context_bundle*.json)
  -> snapshot package (snapshot_repo.zip)
```

Where knowledge is lost:
- Bundle layer drops detailed claim evidence (runs/reports/notes/constraints).
- Review ZIP contents are not represented in a normalized index.
- Many run conclusions exist only as local report markdown or ZIP artifacts.

Where duplication occurs:
- Same conclusions repeated across run reports, review bundles, top-level reports, and claim notes.
- Multiple runs produce near-identical report filenames for iterative analyses.

Where navigation is hard:
- To answer "what is proven", one must traverse: claims -> reports -> run folders -> review ZIPs.
- No single repository-wide, evidence-complete map ties claim IDs to exact run/report/review artifacts in one place.

## 7) Missing Layer (Descriptive Only)
A single canonical evidence index layer is currently missing.

What is missing (description only):
- A normalized map that links each `claim_id` to:
  - authoritative supporting run IDs,
  - authoritative report paths,
  - review status of contributing runs,
  - recency/version precedence when multiple near-duplicate runs exist.

Current impact:
- Humans and agents can reconstruct truth, but only by cross-referencing multiple layers manually.
- This is the main bottleneck in answering "what has already been proven" quickly and unambiguously.
