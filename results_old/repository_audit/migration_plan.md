# Artifact Migration Plan

Date: 2026-03-09
Repository: `matlab-functions`

## Purpose

This plan prepares the repository for artifact migration without moving any files yet.

The target run-internal layout is:

```text
results/<experiment>/runs/run_<timestamp>_<label>/
    figures/
    tables/
    reports/
    review/
```

## Migration goals

- Move all figure files into `figures/`.
- Move all CSV and similar numeric outputs into `tables/`.
- Move all text summaries into `reports/`.
- Move all ZIP bundles prepared for human inspection into `review/`.
- Create missing required directories in runs that do not yet have them.
- Resolve legacy outputs that still exist outside experiment run directories.

## Planned migration steps

### 1. Create missing required directories

For every run under:

- `results/aging/runs/`
- `results/relaxation/runs/`
- `results/switching/runs/`

create these directories if they do not already exist:

- `figures/`
- `tables/`
- `reports/`
- `review/`

Do not remove old directories during the first pass.

### 2. Move figures into `figures/`

Move these file types into `figures/`:

- `.png`
- `.pdf`
- `.fig`

Rules:

- Preserve filenames.
- Keep paired `.png` and `.fig` files together.
- Prefer moving files rather than renaming unless a collision requires disambiguation.
- If a run contains many analysis-specific folders, move figure files first and leave now-empty folders for cleanup later.

### 3. Move CSV and numeric outputs into `tables/`

Move these file types into `tables/` when they are numeric or machine-readable analysis outputs:

- `.csv`
- other structured table exports if present

Rules:

- Preserve filenames such as `observables.csv`.
- Keep analysis-specific CSV files together in `tables/`.
- Do not mix text summaries into `tables/`.

### 4. Move text summaries into `reports/`

Move human-readable written outputs into `reports/`, including:

- `.md`
- `.txt`

Rules:

- Move only generated summaries, notes, and written analysis outputs.
- Do not move required run-root metadata files such as `log.txt` and `run_notes.txt`.
- Leave `run_manifest.json`, `config_snapshot.m`, `log.txt`, and `run_notes.txt` at run root.

### 5. Move ZIP bundles into `review/`

Move review and handoff ZIP files into `review/`.

Rules:

- Preserve filenames.
- Migrate ZIP files currently stored in run roots, analysis-specific folders, or legacy `archives/` folders.
- Treat `review/` as the only valid destination for new human-inspection ZIP bundles.

### 6. Handle runs with unexpected directories

Many runs currently contain non-standard directories such as:

- `geometry_visualization/`
- `debug_runs/`
- `diagnostics/`
- `archives/`
- analysis-specific folders from legacy imports

Migration approach:

- First move files into the new standard directories.
- Then review whether the old directories are empty.
- Remove or consolidate empty legacy directories only after verifying no artifacts remain inside them.

### 7. Handle runs missing required directories

If a run has no standardized directories yet:

- create `figures/`, `tables/`, `reports/`, and `review/`
- migrate files by type into those directories
- keep root metadata files untouched

### 8. Handle legacy outputs outside runs

Current audit findings include legacy outputs outside experiment run directories, for example:

- `results/cross_analysis/`
- `results/cross_experiment/`
- `results/phaseC/`
- loose files such as `results/baseline_resultsLOO.mat`

Migration approach:

- Decide case by case whether each location should be migrated into a run structure or documented as an approved exception.
- Do not move these locations during the first experiment-run migration pass unless their target structure is explicitly defined.
- Record each decision in a follow-up audit note so the exception set stays explicit.

## Execution order recommendation

1. Reconcile documentation and confirm the authoritative artifact layout.
2. Create missing required directories in all experiment runs.
3. Move figure files into `figures/`.
4. Move numeric outputs into `tables/`.
5. Move written summaries into `reports/`.
6. Move ZIP review bundles into `review/`.
7. Review and clean legacy non-standard directories after file migration is complete.
8. Handle top-level legacy `results/` exceptions in a separate pass.

## Validation checklist

After migration, verify:

- every run has `figures/`, `tables/`, `reports/`, and `review/`
- figures are no longer stored outside `figures/`
- CSV outputs are no longer stored outside `tables/`
- generated text summaries are no longer stored outside `reports/`
- ZIP review bundles are no longer stored outside `review/`
- required run-root metadata files remain at run root
- no new artifact directories were invented

## Notes

This plan does not move files. It prepares the repository for a controlled migration pass.
