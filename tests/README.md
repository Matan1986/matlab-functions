# Smoke Tests

Minimal reliability layer for the MATLAB functions repository.

## Purpose

These smoke tests verify that all main entry scripts can be:
1. Located (file exists)
2. Read and parsed (no syntax errors)
3. Contains expected MATLAB constructs (basic sanity check)

**NOTE:** These are NOT full functional tests. They do not execute the scripts or require data files. They only verify the scripts are structurally valid.

## Running Tests

### Run all tests:
```matlab
cd /path/to/matlab-functions
tests/run_all_smoke_tests
```

### Run individual test:
```matlab
cd /path/to/matlab-functions
addpath('tests')
test_smoke_PS
```

## Test Coverage

### Main Analysis Scripts (13 tests)
- `test_smoke_ACHC.m` → `AC HC MagLab ver8/ACHC_main.m`
- `test_smoke_ACHC_RH.m` → `Resistivity MagLab ver1/ACHC_RH_main.m`
- `test_smoke_Aging.m` → `Aging ver2/Main_Aging.m`
- `test_smoke_FieldSweep.m` → `FieldSweep ver3/FieldSweep_main.m`
- `test_smoke_HC.m` → `HC ver1/HC_main.m`
- `test_smoke_MH.m` → `MH ver1/MH_main.m`
- `test_smoke_MT.m` → `MT ver2/MT_main.m`
- `test_smoke_PS.m` → `PS ver4/PS_main.m`
- `test_smoke_Relaxation.m` → `Relaxation ver3/main_relexation.m`
- `test_smoke_Resistivity.m` → `Resistivity ver6/Resistivity_main.m`
- `test_smoke_Susceptibility.m` → `Susceptibility ver1/main_Susceptibility.m`
- `test_smoke_Switching.m` → `Switching ver12/main/Switching_main.m`
- `test_smoke_zfAMR.m` → `zfAMR ver11/main/zfAMR_main.m`

### GUI Entry Points (2 tests)
- `test_smoke_FinalFigureFormatterUI.m` → `GUIs/FinalFigureFormatterUI.m`
- `test_smoke_SmartFigureEngine.m` → `GUIs/SmartFigureEngine.m`

## Test Structure

Each smoke test follows this pattern:
1. Check file exists
2. Read file content (verifies no read errors)
3. Verify content contains expected patterns (e.g., path setup for main scripts, function definitions for GUIs)

## Maintenance

When adding new main entry scripts:
1. Create a corresponding `test_smoke_<name>.m` file
2. Add the test to the list in `run_all_smoke_tests.m`

This keeps the reliability layer minimal and maintainable.
