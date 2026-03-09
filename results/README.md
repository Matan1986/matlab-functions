# Results Directory Layout

This repository uses a run-based local results system.

## Canonical layout

All new analysis and diagnostic outputs must be written under:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Each run root is expected to contain metadata and output subfolders such as:

- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`
- `figures/`
- `csv/`
- `reports/`
- `archives/`
- `artifacts/`

## Experiments

Current experiment result roots are:

- `results/aging/runs/`
- `results/relaxation/runs/`
- `results/switching/runs/`
- `results/cross_experiment/runs/`

## Repository content policy

The `results/` tree is for local working outputs.

- Run outputs stay local and must not be committed to git.
- Generated figures, CSV exports, MAT files, and ZIP archives must not be committed.
- The only file under `results/` that should remain tracked is this documentation placeholder, `results/README.md`.

## Historical flat folders

Older flat folders may still exist from earlier work, for example under:

- `results/aging/`
- `results/relaxation/`
- `results/switching/`
- `results/cross_analysis/`

These are historical artifacts only. New outputs should not be added there.

## Related documentation

- `docs/results_system.md`
- `docs/repository_structure.md`
- `CONTRIBUTING.md`
