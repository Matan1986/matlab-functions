# matlab-functions

Private MATLAB workflows for day-to-day analysis of quantum materials measurements.

This repo is organized as versioned analysis pipelines (for example `Aging`, `PS ver4`, `zfAMR ver11`) plus shared utilities.

## Quick start

1. Open MATLAB.
2. Set current folder to the repository root.
3. Run the main script for the workflow you need.

```matlab
run(fullfile('runs','run_aging.m'))        % Aging analysis
run(fullfile('PS ver4','PS_main.m'))
run(fullfile('Relaxation ver3','main_relexation.m'))
```

## Modules

### Repository Structure

```text
matlab-functions/
|-- Aging/                      % AFM/FM coexistence and aging analysis
|-- Switching/                  % Switching experiments and current-dependent effects
|-- Relaxation/                 % Magnetic relaxation analysis
|-- FieldSweep/                 % Field-sweep transport workflows
|-- AC HC MagLab/               % High-field MagLab measurements
|-- General/                    % Shared utility functions
|-- Tools/                      % Common analysis tools
|-- runs/                       % Pipeline entry points
|-- github_repo/                % Vendored external code
`-- [other modules]             % Additional analysis pipelines
```

### Active Modules (Main Entry Points)

- `Aging/Main_Aging.m` - AFM/FM decomposition and aging-memory workflows with current-dependent coexistence model.
- `HC ver1/HC_main.m` - heat-capacity processing.
- `MT ver2/MT_main.m` - magnetization vs temperature workflows.
- `MH ver1/MH_main.m` - M(H) loops and related analysis.
- `PS ver4/PS_main.m` - planar Hall / angle-sweep transport analysis.
- `Relaxation ver3/main_relexation.m` - TRM/IRM relaxation fitting.
- `Resistivity ver6/Resistivity_main.m` - resistivity vs temperature.
- `Susceptibility ver1/main_Susceptibility.m` - AC susceptibility workflows.
- `zfAMR ver11/main/zfAMR_main.m` - zero-field AMR processing.
- `FieldSweep ver3/FieldSweep_main.m` - field-sweep transport workflow.
- `AC HC MagLab ver8/ACHC_main.m` - MagLab AC/HC high-field measurements.

### Module Documentation

Each module maintains its own documentation:

- [Aging](./Aging/README.md) - AFM/FM coexistence model and global J-dependent fitting

For repository-level notes, conventions, and workflow documentation, see [DOCUMENTATION.md](./DOCUMENTATION.md).

## Canonical Documentation

- [Repository structure](./docs/repository_structure.md)
- [Results system](./docs/results_system.md)
- [Contributing guide](./CONTRIBUTING.md)
- [Relaxation module README](./Relaxation ver3/README.md)
- [Switching module README](./Switching ver12/README.md)

## Run Isolation

The repository uses a run-based local results system. Analysis and diagnostic outputs belong under:

`results/<experiment>/runs/run_<timestamp>_<label>/`

Run IDs use timestamp-first naming for sortability:

- Preferred: `run_<timestamp>_<label>` (label sanitized for filesystem safety; max 40 chars)
- Fallback: `run_<timestamp>` when no label is provided

Run reproducibility files are created at the run root:

- `run_manifest.json` (`run_id`, `timestamp`, `experiment`, `label`, `git_commit`, `matlab_version`, `host`, `user`)
- `config_snapshot.m` (configuration snapshot at run start)
- `log.txt`
- `run_notes.txt` (empty notes template for manual annotations)

Generated run outputs are local working artifacts. Figures, CSV exports, reports, archives, and other run products should remain under `results/` and should not be committed to git.

You can set a custom label before running:

```matlab
cfg.runLabel = 'MG119_AF_decomp_test';
```

See [Repository structure](./docs/repository_structure.md) and [Results system](./docs/results_system.md) for details.

## Developer Tools

- `tools/list_runs.m` - Lists run folders and key metadata (`run_id`, `timestamp`, `label`, `dataset`, `git_commit`) from `results/<experiment>/runs/`.
- `tools/load_run_manifest.m` - Helper to load and parse `run_manifest.json` for a specific run directory.
- `tools/getLatestRun.m` - Returns the newest run ID by scanning `results/<experiment>/runs/`.
- `tools/openLatestRun.m` - Opens the latest run folder (Windows) or prints the folder path (non-Windows).


