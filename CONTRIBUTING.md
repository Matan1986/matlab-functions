# Contributing

## Repository philosophy

- Modules contain analysis code.
- `runs/` contains pipeline launch scripts.
- `tests/` contains test code only.
- `results/` contains all generated outputs.

## Repository rules

- Analysis code must not write files outside `results/`.
- Module diagnostics belong inside the module (for example `Aging/diagnostics`).
- `runs/` is for pipeline entry scripts only.
- `runs/localPaths.m` is machine-specific configuration.

## Run-system rules

- Runs must be initialized only in `stage0_setupPaths`.
- Run context must be created by `createRunContext`.
- Active run context must be stored in MATLAB root appdata.
- Output paths must use `getResultsDir(experiment, analysis, ...)`.
- Do not add direct writes to `results/<experiment>`.
- Changes to run-system behavior require updates to [docs/run_system.md](docs/run_system.md).

### Run Context Safety

- Functions must never create run contexts themselves.
- Run contexts may only be created in `stage0_setupPaths -> createRunContext`.
- If a function requires an active run context and none exists, it must throw a clear error.

Example:

```matlab
ctx = getappdata(0,'runContext');
if isempty(ctx)
    error('No active run context. Run stage0_setupPaths first.');
end
```

## Module maturity model

Current architecture maturity:

- `Aging/` - fully structured and documented. This is the reference architecture.
- `Relaxation ver3/` - partially structured.
- `Switching ver12/` - early-stage / evolving.

Future refactoring should align other modules with the Aging architecture.

## Canonical documentation

- Repository structure: [docs/repository_structure.md](docs/repository_structure.md)
- Run system: [docs/run_system.md](docs/run_system.md)
- Results layout: [results/README.md](results/README.md)
- Aging architecture: [Aging/ARCHITECTURE.md](Aging/ARCHITECTURE.md)
- Repository overview: [README.md](README.md)

## Contributor guidance

When adding or updating analysis code:

1. Keep module logic in the module directory.
2. Keep diagnostics scripts in the module diagnostics directory.
3. Route generated artifacts into `results/` using module path helpers.
4. Keep tests under `tests/` and do not store generated outputs there.

This repository is being standardized incrementally. Prefer small, non-breaking improvements that move modules toward the Aging structure.
