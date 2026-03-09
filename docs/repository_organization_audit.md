# Repository Organization Audit

Audit date: March 9, 2026
Repository: `matlab-functions`

## Scope

This audit covers the repository layout, the experiment modules currently in use, the run-based results system, and the output locations used by Aging, Relaxation, and Switching analyses.

## Step 1: Repository Scan

### Current top-level structure

The repository currently contains a mix of active experiment modules, legacy versions, shared infrastructure, and older domain-specific MATLAB packages.

#### Active experiment areas

- `Aging/`
- `Relaxation ver3/`
- `Switching/`

#### Legacy or overlapping experiment areas

- `Aging old/`
- `Switching ver12/`

#### Shared organization layers already present

- `analysis/` for cross-experiment analysis scripts
- `results/` for generated outputs
- `runs/` for entry points and local path adapters
- `tests/` for top-level test placement
- `tools/` for shared utilities around runs and observables
- `docs/` for repository documentation

#### Additional historical packages at the repo root

Examples include `AC HC MagLab ver8/`, `FieldSweep ver3/`, `Fitting ver1/`, `General ver2/`, `zfAMR ver11/`, and other versioned MATLAB folders. These are not part of the Aging/Relaxation/Switching standardization effort, but they make the current root layout visually crowded.

### Structural map by module

| Module | Current analysis scripts | Current diagnostic scripts | Current output locations | Current run metadata |
| --- | --- | --- | --- | --- |
| Aging | `Aging/analysis/`, `Aging/pipeline/`, `Aging/models/`, `Aging/plots/`, some root-level scripts in `Aging/` | `Aging/diagnostics/`, `Aging/verification/`, debug helpers in `Aging/utils/` | `results/aging/...`, `results/cross_analysis/...`, `Aging/results/`, `Aging/diagnostics/results/`, `Aging/tests/switching_stability/results/` | Run metadata exists under `results/aging/runs/run_<timestamp>_<label>/` via `Aging/utils/createRunContext.m` |
| Relaxation | Main scripts live in `Relaxation ver3/` root | `Relaxation ver3/diagnostics/` | `results/relaxation/<analysis>/...` flat folders only | No `results/relaxation/runs/` folder found; no run metadata files found |
| Switching | `Switching/analysis/` for safe/new analysis; legacy pipeline remains in `Switching ver12/` | No dedicated `Switching/diagnostics/` folder yet; diagnostics are mixed into `Switching/analysis/` and legacy `Switching ver12/` | `results/switching/<analysis>/...`, `results/switching/runs/...`, legacy debug output in `Switching ver12/main/Debug/` | Partial run metadata only. Newest run has full metadata; earlier Switching runs do not |

### Shared infrastructure map

| Area | Current contents | Audit note |
| --- | --- | --- |
| `analysis/` | `cross_experiment_observables.m`, `switching_observable_summary.m` | Cross-experiment analysis already exists outside module folders |
| `runs/` | `run_aging.m`, `localPaths.m`, `localPaths_example.m` | Correct place for launch wrappers, but only Aging currently uses it clearly |
| `tests/` | top-level `tests/switching_stability/` exists but is empty | Top-level tests area is underused; most tests still live inside modules |
| `tools/` | run and observable helpers such as `list_runs.m`, `load_run_manifest.m`, `export_observables.m` | Good shared-utility location |
| `docs/` | structure docs, run docs, observable docs, experiment notes | Good home for standards; needs consolidation around the new naming |

### Shadow output folders outside the main results tree

The following extra output folders currently exist and break the single-output-root model:

- `Aging/results/`
- `Aging/diagnostics/results/`
- `Aging/tests/switching_stability/results/`
- `Switching ver12/main/Debug/`
- `GUIs/reports/`

## Step 2: Results System Audit

### Expected standard

Target pattern under audit:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Required metadata files per run:

- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`

### Aging results-system status

Current Aging run folders:

- `results/aging/runs/run_2026_03_09_014130_MG119_3sec/`
- `results/aging/runs/run_2026_03_09_124648_geometry_visualization/`
- `results/aging/runs/run_2026_03_09_130918_geometry_visualization/`
- `results/aging/runs/run_2026_03_09_140848_geometry_visualization/`
- `results/aging/runs/run_2026_03_09_141328_geometry_visualization/`

Audit result:

- All five Aging run roots contain the four required metadata files.
- Four of the five Aging runs contain a ZIP archive.
- One Aging run, `run_2026_03_09_014130_MG119_3sec`, has figures and a report but no ZIP archive.
- Aging run outputs are not organized into standard subfolders such as `figures/`, `reports/`, `csv/`, or `archives/`; files are written directly under analysis-specific directories such as `geometry_visualization/`.
- `debug_runs/` is being created inside the run root, which makes debug outputs look like nested run folders even though they are not run roots.
- Many Aging diagnostics still write to flat legacy folders when no active run context is present because `getResultsDir` intentionally falls back to `results/aging/<analysis>/...`.

### Switching results-system status

Current Switching run folders:

- `results/switching/runs/run_2026_03_09_132236_switching_alignment_audit/`
- `results/switching/runs/run_2026_03_09_141041_switching_alignment_audit/`
- `results/switching/runs/run_2026_03_09_145524_switching_alignment_audit/`

Audit result:

- Only the newest Switching run, `run_2026_03_09_145524_switching_alignment_audit`, contains all four required metadata files.
- The earlier runs `run_2026_03_09_132236_switching_alignment_audit` and `run_2026_03_09_141041_switching_alignment_audit` contain `observables.csv` and review ZIPs but no manifest, config snapshot, log, or notes file.
- Primary Switching analysis outputs are still being written to flat folders such as `results/switching/alignment_audit/`, `results/switching/mechanism_survey/`, and `results/switching/shape_rank_analysis/`.
- Run folders currently hold only a subset of Switching artifacts, mostly observable exports and preservation audits.
- Switching ZIP creation is common, but ZIPs are split between top-level `results/switching/*.zip`, analysis folders, and run folders.

### Relaxation results-system status

Audit result:

- No `results/relaxation/runs/` directory exists.
- No Relaxation run manifests, config snapshots, logs, or notes files were found.
- All Relaxation outputs are written directly to flat folders such as `results/relaxation/derivative_smoothing/` and `results/relaxation/corrected_geometry/`.
- Relaxation therefore has no active run-based reproducibility layer yet.

### ZIP consistency

Current ZIP behavior is inconsistent across experiments:

- Aging run-based geometry visualizations usually generate `aging_geometry_review.zip`, but not always.
- Relaxation diagnostics often generate ZIP archives, but only in flat output folders, not inside run folders.
- Switching generates many ZIP archives, but they are spread across experiment root, analysis folders, and run folders.

### Figure-folder consistency

Current figure storage is inconsistent:

- Aging places figures directly in analysis-specific folders under either a run root or a flat experiment folder.
- Relaxation places figures directly in each flat analysis folder.
- Switching places figures directly in each flat analysis folder and sometimes mirrors a small subset into run folders.
- No experiment consistently uses dedicated `figures/`, `csv/`, `reports/`, or `archives/` subfolders inside each run.

### CSV naming consistency

CSV naming is only partially consistent:

- Switching uses a mix of `observables.csv` and analysis-specific names such as `switching_alignment_observables_vs_T.csv`.
- Aging mostly uses analysis-specific CSV names such as `svd_summary.csv`, `FM_baseline_test.csv`, and `decomposition_stability_raw.csv`.
- Relaxation uses descriptive CSV names, but there is no shared naming convention between diagnostics.
- Only the observable-layer export currently uses a repository-wide standard filename, `observables.csv`.

## Step 3: Output Inventory

### Aging output inventory

| Artifact type | Current location(s) | Notes |
| --- | --- | --- |
| Geometry heatmaps and slice plots | `results/aging/runs/.../geometry_visualization/` | Files include `aging_map_heatmap.png`, `aging_temperature_slices.png`, `aging_waittime_slices.png`, `aging_centered_temperature_slices.png` |
| Derivative heatmaps | `results/aging/runs/.../geometry_visualization/` | Newer runs include `aging_dMdT_heatmap.png` |
| Geometry report text | `results/aging/runs/.../geometry_visualization/aging_geometry_report.txt` | Report is not placed in a dedicated reports folder |
| Review ZIPs | `results/aging/runs/.../geometry_visualization/aging_geometry_review.zip` | Missing from one audited run |
| Baseline-test figures and CSVs | `results/aging/baseline_tests/` and `results/aging/baseline_tests/baseline_subtracted_FM/` | Flat legacy layout |
| Decomposition diagnostics | `results/aging/decomposition/...` | Includes audit plots and CSV summaries |
| Decomposition stability outputs | `results/aging/decomposition_stability/` | Flat legacy layout |
| Separability outputs | `results/aging/separability/` | Mix of PNG, CSV, and TXT |
| SVD/PCA outputs | `results/aging/svd_pca/` | Mix of PNG, CSV, and TXT |
| Debug outputs | `results/aging/debug_runs/<timestamp>/` and run-local `results/aging/runs/<run>/debug_runs/` | Duplicate debug concepts exist |
| Phase C outputs | `results/aging/diagnostics_misc/phaseC/...` and related legacy folders | Flat legacy layout |

### Relaxation output inventory

| Artifact type | Current location(s) | Notes |
| --- | --- | --- |
| Corrected geometry maps and cuts | `results/relaxation/corrected_geometry/` | Includes maps, cuts, CSV summaries, and a ZIP |
| Derivative smoothing maps, cuts, tables, and report | `results/relaxation/derivative_smoothing/` | Includes PNG, CSV, MD, and ZIP |
| Geometry maps | `results/relaxation/geometry_maps/` | Flat folder with plots and a dataset summary CSV |
| Relax-band maps | `results/relaxation/geometry_maps_relaxband/` | Flat folder with plots, CSVs, and ZIP |
| Relax-band validation outputs | `results/relaxation/geometry_maps_relaxband_validation/` | Flat folder with plots, CSVs, and ZIP |
| Observable survey tables and figures | `results/relaxation/observable_survey/` | Flat folder with recommended observables CSV |
| Model placeholders | `results/relaxation/kww_model/` and `results/relaxation/log_model/` | Folder structure exists but is currently empty |

### Switching output inventory

| Artifact type | Current location(s) | Notes |
| --- | --- | --- |
| Alignment heatmaps, ridge plots, susceptibility maps, decomposition plots | `results/switching/alignment_audit/` | Largest current output area; flat layout |
| Alignment observables CSVs | `results/switching/alignment_audit/` | Includes `switching_alignment_observables_vs_T.csv`, `switching_alignment_samples.csv`, and derived CSVs |
| Stability survey outputs | `results/switching/alignment_audit/stability_survey/` | Nested under one analysis folder |
| Observable-layer export | `results/switching/runs/run_.../observables.csv` | This is the one consistent standardized CSV |
| Mechanism survey outputs | `results/switching/mechanism_survey/` | PNG, CSV, MD, and ZIP |
| Mechanism follow-up outputs | `results/switching/mechanism_followup/` | PNG, CSV, MD, and ZIP |
| Mode-2/3 analysis outputs | `results/switching/mode23_analysis/` | PNG, CSV, and MD |
| Basis-test outputs | `results/switching/observable_basis_test/` | PNG, CSV, MD, and ZIP |
| Second-observable search outputs | `results/switching/second_observable_search/` | PNG, CSV, MD, and ZIP |
| Second-coordinate duel outputs | `results/switching/second_coordinate_duel/` | PNG, CSV, MD, and ZIP |
| Shape-rank outputs | `results/switching/shape_rank_analysis/` | PNG, CSV, MD, and ZIP |
| XI-Xshape outputs | `results/switching/XI_Xshape_analysis/` | PNG, CSV, and MD |
| Top-level ZIP bundles | `results/switching/*.zip` | Extra root-level ZIPs duplicate analysis-level bundles |
| Legacy debug outputs | `Switching ver12/main/Debug/` | Outside standardized results tree |

## Step 4: Structural Problems

### 1. The run system is only partially adopted

- Aging has a functioning run helper and complete metadata for current runs.
- Switching only partially uses the helper, so some run folders look valid but are missing required metadata.
- Relaxation does not use the run system at all.

### 2. `getResultsDir` still allows flat legacy output paths

The helper falls back to `results/<experiment>/<analysis>/...` whenever no run context is active. That preserved backward compatibility, but it also means scripts can silently bypass the run system.

### 3. Outputs are scattered across multiple roots

Examples:

- `results/aging/...`
- `Aging/results/`
- `Aging/diagnostics/results/`
- `Aging/tests/switching_stability/results/`
- `Switching ver12/main/Debug/`

This makes cleanup, reproducibility, and agent behavior harder.

### 4. Active and legacy modules overlap at the repo root

The root contains both `Switching/` and `Switching ver12/`, plus `Aging/` and `Aging old/`. That makes it unclear which folder is authoritative for new work.

### 5. Diagnostics placement is inconsistent

- Aging has a dedicated `diagnostics/` folder.
- Relaxation has diagnostics under `Relaxation ver3/diagnostics/` but not a clearer module-level organization.
- Switching diagnostics are currently mixed into `Switching/analysis/`.

### 6. Output folders are named by analysis topic instead of by run first

Flat locations such as `results/switching/alignment_audit/` and `results/relaxation/derivative_smoothing/` group by analysis name, not by execution run. This weakens provenance.

### 7. Run-internal output layout is not standardized

Current runs do not consistently contain subfolders such as:

- `figures/`
- `csv/`
- `reports/`
- `archives/`
- `logs/`

As a result, output browsing is inconsistent even when a run exists.

### 8. ZIP archive generation is not enforced

- Aging: one audited run missing ZIP output
- Relaxation: ZIPs exist but only in flat folders
- Switching: ZIPs exist in several places, often duplicating content

### 9. Top-level `tests/` is not the single source of truth for tests

Tests are spread across:

- `tests/`
- `Aging/tests/`
- `GUIs/tests/`

This makes discovery inconsistent.

### 10. Cross-experiment analyses are present but not part of the stated standard

The repository already contains shared analysis under `analysis/` and shared outputs under `results/cross_experiment/` and `results/cross_analysis/`, but the existing structure docs do not fully incorporate this layer.

## Step 5: Proposed Standardized Structure

This is the recommended target structure for future work. It does not require an immediate filesystem migration in this audit, but it should become the authoritative standard for new scripts and for gradual refactors.

```text
<repo root>/
    modules/
        Aging/
            analysis/
            diagnostics/
            pipeline/
            models/
            plots/
            utils/
            tests/
            docs/
        Relaxation/
            analysis/
            diagnostics/
            pipeline/
            models/
            plots/
            utils/
            tests/
            docs/
        Switching/
            analysis/
            diagnostics/
            pipeline/
            models/
            plots/
            utils/
            tests/
            docs/
    analysis/
        cross_experiment/
    results/
        aging/
            runs/
        relaxation/
            runs/
        switching/
            runs/
        cross_experiment/
            runs/
        repository_audit/
    runs/
    tests/
    tools/
    docs/
```

### Directory roles

| Directory | Role |
| --- | --- |
| `modules/<Experiment>/analysis/` | Analysis scripts intended to generate scientific outputs |
| `modules/<Experiment>/diagnostics/` | Debugging, validation, audit, and interpretability scripts |
| `modules/<Experiment>/pipeline/` | End-to-end orchestration and staged execution entry points |
| `modules/<Experiment>/models/` | Model fitting and decomposition logic |
| `modules/<Experiment>/plots/` | Shared plotting helpers |
| `modules/<Experiment>/utils/` | Shared internal helpers, path logic, and run helpers |
| `modules/<Experiment>/tests/` | Experiment-specific tests |
| `analysis/cross_experiment/` | Analyses that combine outputs from multiple experiments |
| `results/<experiment>/runs/` | Canonical result storage for all experiment runs |
| `results/cross_experiment/runs/` | Canonical result storage for cross-experiment runs |
| `runs/` | Human-facing launch scripts and local path adapters |
| `tests/` | Repository-level test harnesses and integration tests |
| `tools/` | Shared read-only utilities, loaders, exporters, and run inspection tools |
| `docs/` | Repository-wide standards and documentation |

## Step 6: Output Rules for All Agents and Scripts

These rules should be treated as repository policy.

### Required rules

1. All analysis and diagnostic outputs must be written to a run directory.

Canonical path:

`results/<experiment>/runs/run_<timestamp>_<label>/`

2. Every run must create these metadata files at the run root:

- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`

3. Every run must organize generated outputs into standard subfolders:

- `figures/`
- `csv/`
- `reports/`
- `archives/`
- `artifacts/` for `.mat` or other binary data when needed

4. No script may write directly to `results/<experiment>/` without first creating or reusing a run folder.

5. Diagnostic scripts must use the same run system as primary analyses.

6. Every run should generate a ZIP archive under `archives/` that contains the main figures, CSVs, and report files needed for review.

7. If a script exports observables, the canonical machine-readable file name must be `observables.csv` and it should live under the run root or the run's `csv/` subfolder.

8. Analysis-specific CSVs should use descriptive names, but they must still live under the run's `csv/` subfolder.

9. All scripts must print the resolved run directory to the console at startup.

10. Legacy output folders inside modules are read-only historical locations. New outputs must not be written there.

11. Cross-experiment analyses must use `results/cross_experiment/runs/run_<timestamp>_<label>/`.

12. Tests must not create ad hoc output folders inside source directories. Test artifacts should go under a test run folder in `results/tests/` or an experiment run folder when the test exercises a real pipeline.

## Recommended migration order

1. Make `createRunContext` and `getResultsDir` shared infrastructure, not Aging-only infrastructure.
2. Add `results/relaxation/runs/` and migrate Relaxation diagnostics first.
3. Remove Switching fallback run creation that produces run folders without metadata.
4. Move Switching diagnostic-style scripts into a dedicated `Switching/diagnostics/` folder.
5. Stop creating new outputs under `Aging/results/`, `Aging/diagnostics/results/`, and `Switching ver12/main/Debug/`.
6. Introduce standard run subfolders so figures, CSVs, reports, and ZIPs are predictable across all experiments.

## Documentation files updated by this audit

- `docs/repository_structure.md`
- `docs/results_system.md`
- `docs/repository_organization_audit.md`
