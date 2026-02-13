# MATLAB Project Structure Documentation

## Overview

This document describes the organization of the MATLAB project after reorganization.

## Directory Structure

```
matlab-functions/
│
├── Modules/                          # All analysis modules (organized)
│   ├── Aging_ver2/                   # Aging memory analysis
│   │   ├── Main_Aging.m
│   │   ├── importFiles_aging.m
│   │   └── ... (module-specific functions)
│   │
│   ├── FieldSweep_ver3/              # Field sweep transport measurements
│   │   ├── FieldSweep_main.m
│   │   └── ... (module-specific functions)
│   │
│   ├── AC_HC_MagLab_ver8/            # AC Hall coefficient measurements
│   ├── HC_ver1/                      # Hall coefficient
│   ├── MH_ver1/                      # M(H) magnetization loops
│   ├── MT_ver2/                      # M(T) temperature sweeps
│   ├── PS_ver4/                      # Power spectroscopy
│   ├── Relaxation_ver3/              # Relaxation measurements
│   ├── Resistivity_ver6/             # Resistivity measurements
│   ├── Resistivity_MagLab_ver1/      # MagLab resistivity
│   ├── Susceptibility_ver1/          # Magnetic susceptibility
│   ├── Switching_ver12/              # Magnetic switching analysis
│   │   ├── main/
│   │   ├── plots/
│   │   ├── utils/
│   │   ├── tables/
│   │   └── parsing/
│   │
│   └── zfAMR_ver11/                  # Zero-field AMR analysis
│       ├── main/
│       ├── plots/
│       ├── utils/
│       ├── tables/
│       ├── parsing/
│       └── analysis/
│
├── Shared/                           # Shared utilities (all modules use)
│   ├── General_ver2/                 # General utilities
│   │   ├── build_channels.m
│   │   ├── extract_growth_FIB.m
│   │   ├── close_all_except_ui_figures.m
│   │   ├── appearanceControl/
│   │   └── figureSaving/
│   │
│   └── Tools_ver1/                   # Project management tools
│       ├── detect_dead_functions.m
│       ├── organize_*_files.m
│       └── ... (development tools)
│
├── Tests/                            # Comprehensive test suite
│   ├── run_test.m                    # Test execution utility
│   ├── generate_test_report.m        # Report generation
│   ├── run_all_tests.m               # Main test orchestrator
│   │
│   ├── verify_project_structure.m    # Group 1: Structure tests
│   ├── test_path_setup.m
│   ├── test_old_paths_still_work.m
│   │
│   ├── test_module_imports.m         # Group 2: Module tests
│   ├── test_helper_functions.m
│   ├── test_main_scripts_syntax.m
│   │
│   ├── test_complete_aging_pipeline.m     # Group 3: Pipeline tests
│   ├── test_complete_mt_pipeline.m
│   ├── test_complete_fieldsweep_pipeline.m
│   ├── test_complete_relaxation_pipeline.m
│   ├── test_complete_hc_pipeline.m
│   │
│   ├── test_google_drive_paths.m     # Group 4: Cloud storage
│   ├── test_network_paths.m
│   │
│   └── test_gui_launch.m             # Group 5: GUI tests
│
├── Documentation/                    # Project documentation
│   ├── MIGRATION_GUIDE.md           # How to migrate
│   └── PROJECT_STRUCTURE.md         # This file
│
├── GUIs/                            # Original GUI folder (preserved)
│   ├── CtrlGUI.m
│   ├── refLineGUI.m
│   ├── FinalFigureFormatterUI.m
│   └── ...
│
├── GUIs_Organized/                  # Organized GUIs (future)
│   ├── CtrlGUI/
│   ├── refLineGUI/
│   ├── FinalFigureFormatterUI/
│   └── CommonFormatting/
│
├── github_repo/                     # Third-party dependencies
│   ├── cmocean/                     # Colormap utilities
│   └── ScientificColourMaps8/
│
├── setup_project_paths.m            # Intelligent path setup
├── path_config.m                    # Path configuration
├── autotest_after_reorganization.m  # Main test entry point
├── verify_old_structure_still_works.m  # Backward compatibility check
│
└── [Old Structure - Preserved]      # Original folders (backward compatibility)
    ├── Aging ver2/
    ├── FieldSweep ver3/
    ├── General ver2/
    ├── Tools ver1/
    └── ... (all original folders)
```

## Module Organization

### Analysis Modules (`/Modules/`)

Each module typically contains:
- **Main script**: `*_main.m` or `Main_*.m` - Entry point
- **Import functions**: `importFiles_*.m`, `getFileList_*.m` - Data loading
- **Analysis functions**: Module-specific analysis routines
- **Plotting functions**: Visualization utilities
- **Helper functions**: Module-specific utilities

### Shared Utilities (`/Shared/`)

#### General_ver2
- **Channel building**: `build_channels.m`, `filter_channels.m`
- **Metadata extraction**: `extract_growth_FIB.m`, `extract_current_I.m`
- **Figure management**: `close_all_except_ui_figures.m`
- **Preset handling**: `select_preset.m`, `resolve_preset.m`
- **Appearance control**: Subfolder with formatting utilities
- **Figure saving**: Subfolder with export utilities

#### Tools_ver1
- **Development tools**: Code organization and maintenance
- **Dead code detection**: `detect_dead_functions.m`
- **File organization**: `organize_*_files.m`

## Naming Conventions

### Folders
- **Old**: Spaces in names (e.g., `"Aging ver2"`)
- **New**: Underscores (e.g., `"Aging_ver2"`)
- Version numbers preserved
- Consistent structure across all modules

### Files
- **Main scripts**: `*_main.m` or `Main_*.m`
- **Import functions**: `importFiles_*.m`, `getFileList_*.m`
- **Helper functions**: Descriptive names with action verbs

## How to Add a New Module

1. Create folder in `Modules/`:
   ```
   Modules/NewModule_ver1/
   ```

2. Add main script:
   ```matlab
   % NewModule_main.m
   setup_project_paths();  % Add at the top
   % ... your code
   ```

3. Add to `path_config.m`:
   ```matlab
   config.moduleNames = {
       ...
       'NewModule_ver1'
   };
   ```

4. Create test:
   ```matlab
   % Tests/test_newmodule_pipeline.m
   function test_newmodule_pipeline()
       % Verify module structure
   end
   ```

5. Run tests:
   ```matlab
   autotest_after_reorganization
   ```

## Best Practices

### For Analysis Scripts
1. Start with `setup_project_paths()` or appropriate path setup
2. Set user options at the top
3. Use shared utilities from `Shared/General_ver2/`
4. Keep module-specific code in module folder
5. Document your functions

### For Shared Utilities
1. Place in `Shared/General_ver2/` if used by multiple modules
2. Keep module-specific code in module folder
3. Use clear, descriptive names
4. Add help text and examples

### For Testing
1. Add tests for new modules in `Tests/`
2. Follow existing test patterns
3. Run `autotest_after_reorganization` before committing
4. Ensure backward compatibility

## Path Management

### Automatic (Recommended)
```matlab
setup_project_paths();
% All paths configured automatically
```

### Manual (Old Style - Still Works)
```matlab
baseFolder = 'C:\...\Matlab functions';
addpath(genpath(baseFolder));
```

### Hybrid
```matlab
% Setup new structure
setup_project_paths();

% Add custom paths as needed
addpath(genpath('custom_folder'));
```

## Testing Infrastructure

### Running Tests
```matlab
% Run all tests
autotest_after_reorganization

% Test backward compatibility
verify_old_structure_still_works

% Run specific test group
cd Tests
run_all_tests
```

### Test Output
- **Console**: Colored output (green=pass, red=fail)
- **TEST_RESULTS_SUMMARY.txt**: Text summary
- **test_results.html**: Interactive HTML report
- **test_log.txt**: Detailed log

## Backward Compatibility

The reorganization is **non-destructive**:
- ✅ Old folders preserved
- ✅ Old scripts work unchanged
- ✅ Old paths still valid
- ✅ Gradual migration supported
- ✅ Can revert anytime

## Dependencies

### Required
- MATLAB R2018b or later (recommended)
- No additional toolboxes required for basic functionality

### Optional
- Statistics and Machine Learning Toolbox (for some analyses)
- Curve Fitting Toolbox (for fitting routines)

### Included
- cmocean colormaps (`github_repo/cmocean/`)
- Scientific colour maps (`github_repo/ScientificColourMaps8/`)

## Maintenance

### Regular Tasks
1. Run `autotest_after_reorganization` periodically
2. Keep modules organized (one module = one folder)
3. Update documentation when adding features
4. Test backward compatibility after changes

### Code Organization
1. Use `Tools_ver1/detect_dead_functions.m` to find unused code
2. Keep shared utilities in `Shared/`
3. Module-specific code stays in module folder
4. Document your changes

## Summary

This structure provides:
- 📁 **Clear Organization**: Modules, Shared, Tests, Documentation
- 🔄 **Backward Compatible**: Old structure preserved
- ✅ **Well Tested**: Comprehensive test suite
- 📚 **Well Documented**: Migration guide and structure docs
- 🚀 **Scalable**: Easy to add new modules
- 🔧 **Maintainable**: Professional structure
