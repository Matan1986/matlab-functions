# Results directory

Local run outputs for this repository. **Canonical rules** live in **`docs/results_system.md`** (run locations, metadata files, policies). **Artifact subfolders inside each run** are defined in **`docs/output_artifacts.md`** (`figures/`, `tables/`, `reports/`, `review/`). For overlapping topics, see documentation precedence in **`docs/AGENT_RULES.md`**.

## Where new outputs go

All new analysis, diagnostic, and agent workflows write under:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Use lowercase experiment names: `aging`, `relaxation`, `switching`, `cross_experiment`. Cross-experiment analyses must use **`results/cross_experiment/runs/`** (not alternate spellings or ad-hoc roots).

## Inside each run (summary)

Run root should include the metadata files listed in **`docs/results_system.md`** (`run_manifest.json`, `config_snapshot.m`, `log.txt`, `run_notes.txt`).

Standard artifact directories (same names as **`docs/output_artifacts.md`**):

- **`figures/`** — figure exports (e.g. PNG, PDF, FIG)
- **`tables/`** — analysis-specific CSV and other tabular outputs
- **`reports/`** — markdown, text, and other written summaries
- **`review/`** — ZIP bundles for inspection or handoff

If a run exports the standardized observable index, **`observables.csv`** stays at the **run root** (not under `tables/`). Details: **`docs/results_system.md`** (Observable Index Policy) and **`docs/output_artifacts.md`**.

## Result roots (quick reference)

- `results/aging/runs/`
- `results/relaxation/runs/`
- `results/switching/runs/`
- `results/cross_experiment/runs/`

Tests that emit artifacts may use **`results/tests/`** or an experiment run folder (see **`docs/results_system.md`**).

## Repository content policy

- Run outputs are local working artifacts; do not commit generated figures, ZIP archives, MAT files, or other run products.
- The only tracked file under `results/` should remain this **`results/README.md`** placeholder.

## Historical flat folders

Older flat paths may still exist (for example under `results/aging/`, `results/relaxation/`, or `results/switching/`). **Do not add new files there**; new runs belong under the corresponding `.../runs/` trees. See backward-compatibility policy in **`docs/results_system.md`**.

## Related documentation

- `docs/results_system.md`
- `docs/output_artifacts.md`
- `docs/repository_structure.md`
- `CONTRIBUTING.md`
