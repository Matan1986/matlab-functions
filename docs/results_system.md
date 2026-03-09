# Results System

Last updated: March 9, 2026

This document is the authoritative specification for how `matlab-functions` analyses and diagnostics must create outputs.

## Core rule

Every analysis, diagnostic, validation script, and agent-generated workflow must write outputs to a run folder.

Canonical path:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Examples:

- `results/aging/runs/run_2026_03_09_141328_geometry_visualization/`
- `results/relaxation/runs/run_2026_03_09_153000_derivative_smoothing/`
- `results/switching/runs/run_2026_03_09_160500_alignment_audit/`
- `results/cross_experiment/runs/run_2026_03_09_170000_observable_comparison/`

## Required run-root files

Every run root must contain these files:

- `run_manifest.json`
- `config_snapshot.m`
- `log.txt`
- `run_notes.txt`

### Purpose of each file

| File | Purpose |
| --- | --- |
| `run_manifest.json` | Machine-readable run metadata such as experiment name, run id, timestamp, dataset, user, host, and git commit |
| `config_snapshot.m` | Reconstructable snapshot of the MATLAB configuration used for the run |
| `log.txt` | Human-readable execution log |
| `run_notes.txt` | Free-form notes, interpretation, or follow-up observations |

## Required run subfolders

Every run should use the same internal layout.

```text
results/<experiment>/runs/run_<timestamp>_<label>/
    run_manifest.json
    config_snapshot.m
    log.txt
    run_notes.txt
    figures/
    tables/
    reports/
    review/
```

### Subfolder roles

| Subfolder | Contents |
| --- | --- |
| `figures/` | PNG, PDF, FIG, and other figure files |
| `tables/` | CSV tables and other machine-readable numeric outputs other than the run-level `observables.csv` index |
| `reports/` | Markdown, TXT, and other written summaries |
| `review/` | ZIP bundles prepared for human inspection or handoff |

## Observable Index Policy

When a run exports the standardized observable layer, `observables.csv` acts as a run-level summary/index rather than an analysis-specific table.

Policy:

- `observables.csv` belongs at the run root: `results/<experiment>/runs/run_<timestamp>_<label>/observables.csv`
- it should remain at the run root
- artifact helpers should not move it into `tables/`
- analysis-specific CSV exports should still use `tables/`

This distinction is intentional: `observables.csv` is the canonical machine-readable index for the whole run, while `tables/` stores analysis-specific tabular artifacts.

## Repository Content Policy

Generated run outputs are local working artifacts and must not be committed to git.

- Generated figures must not be committed.
- ZIP archives must not be committed.
- Run outputs must remain in local `results/` folders.
- The only tracked content under `results/` should be documentation placeholders such as `results/README.md`.

## Run naming

### Format

`run_<yyyy>_<mm>_<dd>_<HHMMSS>_<label>`

### Label rules

- Use lowercase or readable ASCII tokens when possible.
- Replace spaces with underscores.
- Keep labels concise and analysis-specific.
- Good examples: `geometry_visualization`, `alignment_audit`, `observable_survey`.

## Output rules

1. No script may write directly to `results/<experiment>/` without creating or reusing a run folder.
2. No script may write new outputs inside source directories such as `Aging/results/` or `Switching ver12/main/Debug/`.
3. Diagnostic scripts must use the same run system as primary analyses.
4. Cross-experiment analyses must use `results/cross_experiment/runs/`.
5. Tests that produce artifacts must use either `results/tests/` or an experiment run folder.
6. Every script must print the resolved run directory to the console at startup.
7. Every run should create at least one ZIP archive in `review/` containing the main review files.
8. If observables are exported, the canonical machine-readable filename is `observables.csv`.
9. `observables.csv` is a run-level summary/index and should remain at the run root, not inside `tables/`.
10. Artifact helpers such as `save_run_table` must not be used to move `observables.csv` into `tables/`.
11. Analysis-specific CSV names other than `observables.csv` should live under `tables/`.
12. Reports should live under `reports/`, not next to figures.
13. Agents must not invent alternative artifact directories such as `plots/`, `figs/`, `analysis_outputs/`, or `archives/`.

## Backward-compatibility policy

Older flat output locations exist today, especially in Aging, Relaxation, and Switching. They are historical only.

Accepted historical examples:

- `results/aging/decomposition/`
- `results/relaxation/derivative_smoothing/`
- `results/switching/alignment_audit/`

Policy going forward:

- Existing historical outputs may remain in place until migration work is performed.
- New runs must not add files to these flat folders.
- Migration work should gradually move those analyses to run-scoped paths.

## Current repository status

### Aging

- Uses a real run helper and currently creates complete run metadata.
- New outputs belong in run folders under `results/aging/runs/`.
- Remaining work is helper hardening and standard subfolder adoption.

### Relaxation

- Legacy outputs have been migrated into `run_legacy_*` folders under `results/relaxation/runs/`.
- New outputs belong in run folders under `results/relaxation/runs/`.

### Switching

- Legacy outputs have been migrated into `run_legacy_*` folders under `results/switching/runs/`.
- Existing run folders now carry the required root metadata files.
- New outputs belong in run folders under `results/switching/runs/`.

## Implementation guidance

### Recommended helper flow

1. Create or reuse a run context at script startup.
2. Resolve all output paths from that run context.
3. Write metadata files immediately.
4. Write figures, tables, reports, and review bundles into their standard subfolders.
5. Print the final run path and key artifact paths to the console.

### Shared utilities already present

Useful shared files currently in the repository:

- `Aging/utils/createRunContext.m`
- `Aging/utils/getResultsDir.m`
- `tools/list_runs.m`
- `tools/load_run_manifest.m`
- `tools/export_observables.m`
- `tools/load_observables.m`

## Migration priorities

1. Promote the current Aging run helper into shared infrastructure usable by all experiments.
2. Add standard `figures/`, `tables/`, `reports/`, and `review/` subfolder creation to the helper.
3. Migrate legacy artifacts into the standardized run-internal layout.
4. Replace non-standard artifact directories with the documented structure in all new scripts.

## Related documents

- `docs/output_artifacts.md`
- `docs/repository_structure.md`
- `docs/repository_organization_audit.md`
- `results/README.md`
