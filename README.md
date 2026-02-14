# matlab-functions

Private MATLAB workflows for day-to-day analysis of quantum materials measurements.

This repo is organized as versioned analysis pipelines (for example `Aging ver2`, `PS ver4`, `zfAMR ver11`) plus shared utilities.

## Quick start

1. Open MATLAB.
2. Set current folder to the repository root.
3. Run the main script for the workflow you need.

```matlab
run(fullfile('Aging ver2','Main_Aging.m'))
run(fullfile('PS ver4','PS_main.m'))
run(fullfile('Relaxation ver3','main_relexation.m'))
```

## Module list (main entry points)

- `Aging ver2/Main_Aging.m` — aging-memory and AFM/FM decomposition workflows.
- `HC ver1/HC_main.m` — heat-capacity processing.
- `MT ver2/MT_main.m` — magnetization vs temperature workflows.
- `MH ver1/MH_main.m` — M(H) loops and related analysis.
- `PS ver4/PS_main.m` — planar Hall / angle-sweep transport analysis.
- `Relaxation ver3/main_relexation.m` — TRM/IRM relaxation fitting.
- `Resistivity ver6/Resistivity_main.m` — resistivity vs temperature.
- `Susceptibility ver1/main_Susceptibility.m` — AC susceptibility workflows.
- `zfAMR ver11/main/zfAMR_main.m` — zero-field AMR processing.
- `FieldSweep ver3/FieldSweep_main.m` — field-sweep transport workflow.
- `Resistivity MagLab ver1/ACHC_RH_main.m` and `AC HC MagLab ver8/ACHC_main.m` — MagLab pipelines.

For personal notes, conventions, and routine workflow, see `DOCUMENTATION.md`.

## Testing

A minimal smoke test suite is available in `tests/` to verify all main entry scripts are structurally valid.

```matlab
% Run all smoke tests
tests/run_all_smoke_tests

% Or run individual tests
addpath('tests')
test_smoke_PS
```

See `tests/README.md` for details. These tests verify file existence and basic syntax, but do not require data files or execute full workflows.
