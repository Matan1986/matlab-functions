# Repository Structure

Last updated: March 9, 2026

This document defines the repository layout standard for `matlab-functions`. It also records the current transitional state so contributors and agents can tell the difference between the current filesystem and the target organization.

## Current repository zones

### Active experiment modules

- `Aging/`
- `Relaxation ver3/`
- `Switching/`

### Legacy or overlapping experiment folders

- `Aging old/`
- `Switching ver12/`

### Shared repository layers

- `analysis/` for cross-experiment analyses
- `results/` for generated outputs
- `runs/` for launch wrappers and local path adapters
- `tests/` for repository-level tests
- `tools/` for shared utilities
- `docs/` for repository-wide documentation

### Historical root-level MATLAB packages

The root also contains older versioned MATLAB folders such as `AC HC MagLab ver8/`, `FieldSweep ver3/`, `General ver2/`, and `zfAMR ver11/`. They are not part of the Aging/Relaxation/Switching standard, but they remain in the repository and should not be treated as target examples for new organization.

## Current module map

| Area | What lives there now |
| --- | --- |
| `Aging/analysis/` | Aging analysis and visualization scripts |
| `Aging/diagnostics/` | Aging diagnostics and audit scripts |
| `Aging/pipeline/` | Aging staged pipeline |
| `Aging/models/` | Aging model-fitting code |
| `Aging/plots/` | Aging plotting helpers |
| `Aging/utils/` | Aging utilities including the run helper |
| `Aging/tests/` | Aging tests |
| `Relaxation ver3/` | Main Relaxation scripts live directly in the module root |
| `Relaxation ver3/diagnostics/` | Relaxation diagnostics |
| `Switching/analysis/` | New Switching analyses and diagnostic-style scripts |
| `Switching ver12/` | Legacy Switching pipeline and legacy debug output |
| `analysis/` | Cross-experiment analyses |
| `results/` | Shared output root |
| `runs/` | Entry points such as `run_aging.m` and local path setup |
| `tests/` | Repository-level test area, currently sparse |
| `tools/` | Run inspection and observable utilities |

## Target standard

New work should follow this structure.

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

## Directory roles

| Path | Role |
| --- | --- |
| `modules/<Experiment>/analysis/` | Production analysis scripts that generate scientific outputs |
| `modules/<Experiment>/diagnostics/` | Validation, debug, interpretability, and audit scripts |
| `modules/<Experiment>/pipeline/` | Full workflows and staged execution logic |
| `modules/<Experiment>/models/` | Model-fitting and decomposition logic |
| `modules/<Experiment>/plots/` | Plotting helpers and layout utilities |
| `modules/<Experiment>/utils/` | Shared internal helpers, run creation, and path utilities |
| `modules/<Experiment>/tests/` | Experiment-specific tests and smoke tests |
| `analysis/cross_experiment/` | Analyses that intentionally consume outputs from more than one experiment |
| `results/<experiment>/runs/` | Canonical result storage for experiment runs |
| `results/cross_experiment/runs/` | Canonical storage for cross-experiment analysis runs |
| `runs/` | Human-facing launchers and local environment setup |
| `tests/` | Repository-level integration and harness tests |
| `tools/` | Shared utilities such as run listing, manifest loading, and observable export |
| `docs/` | Repository standards, conventions, and high-level documentation |

## Current exceptions to clean up over time

These locations exist today but are not part of the target standard for new outputs:

- `Aging/results/`
- `Aging/diagnostics/results/`
- `Aging/tests/switching_stability/results/`
- `Switching ver12/main/Debug/`
- flat output folders like `results/relaxation/derivative_smoothing/` and `results/switching/alignment_audit/`

## Placement rules

1. Analysis scripts belong in the experiment module's `analysis/` folder.
2. Diagnostic and validation scripts belong in the experiment module's `diagnostics/` folder.
3. Launch wrappers belong in `runs/`.
4. Shared helpers belong in `tools/` or in the experiment module's `utils/` folder.
5. Tests belong in either `modules/<Experiment>/tests/` or top-level `tests/`, but not in ad hoc locations.
6. Generated outputs belong under `results/`, never inside source folders.
7. New cross-experiment outputs belong under `results/cross_experiment/runs/`.

## Canonical experiment names for results paths

Use lowercase experiment names in `results/`:

- `aging`
- `relaxation`
- `switching`
- `cross_experiment`

## Related documents

- `docs/results_system.md`
- `docs/repository_organization_audit.md`
