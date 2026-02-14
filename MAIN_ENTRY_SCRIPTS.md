# Main Entry Scripts

This document lists all main entry scripts and GUI entry points detected in the repository.

## Main Analysis Scripts

1. **AC HC MagLab ver8/ACHC_main.m**
   - Purpose: MagLab AC/HC pipeline

2. **Aging ver2/Main_Aging.m**
   - Purpose: Aging-memory and AFM/FM decomposition workflows

3. **FieldSweep ver3/FieldSweep_main.m**
   - Purpose: Field-sweep transport workflow

4. **HC ver1/HC_main.m**
   - Purpose: Heat-capacity processing

5. **MH ver1/MH_main.m**
   - Purpose: M(H) loops and related analysis

6. **MT ver2/MT_main.m**
   - Purpose: Magnetization vs temperature workflows

7. **PS ver4/PS_main.m**
   - Purpose: Planar Hall / angle-sweep transport analysis

8. **Relaxation ver3/main_relexation.m**
   - Purpose: TRM/IRM relaxation fitting

9. **Resistivity MagLab ver1/ACHC_RH_main.m**
   - Purpose: MagLab resistivity pipeline

10. **Resistivity ver6/Resistivity_main.m**
    - Purpose: Resistivity vs temperature

11. **Susceptibility ver1/main_Susceptibility.m**
    - Purpose: AC susceptibility workflows

12. **Switching ver12/main/Switching_main.m**
    - Purpose: Switching stability analysis

13. **zfAMR ver11/main/zfAMR_main.m**
    - Purpose: Zero-field AMR processing

## GUI Entry Points

1. **GUIs/FinalFigureFormatterUI.m**
   - Purpose: Final figure formatting and export UI

2. **GUIs/SmartFigureEngine.m**
   - Purpose: Figure layout and formatting engine

## Smoke Test Coverage

Each of these entry points has a corresponding smoke test in the `tests/` directory:
- Verifies file exists
- Checks for basic syntax validity
- Confirms expected MATLAB constructs

Run all tests with: `tests/run_all_smoke_tests`
