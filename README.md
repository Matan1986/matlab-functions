# MATLAB Functions

My MATLAB function library for quantum materials analysis

## 🎉 NEW: Professional Project Reorganization

This project has been reorganized into a professional, maintainable structure with **100% backward compatibility** and comprehensive automated testing!

### Quick Start - Testing the Reorganization

Run ONE command to test everything:

```matlab
cd /path/to/matlab-functions
autotest_after_reorganization
```

This will:
- ✅ Run all 15+ tests
- ✅ Generate colored console output (green=PASS, red=FAIL)
- ✅ Create TEST_RESULTS_SUMMARY.txt
- ✅ Create test_results.html (interactive report)
- ✅ Create test_log.txt
- ✅ Report overall status

### Using the New Structure

#### Option 1: Intelligent Path Setup (Recommended)
```matlab
setup_project_paths();
% All paths configured automatically!
```

#### Option 2: Keep Using Old Paths (Still Works!)
```matlab
% Your old scripts work unchanged
baseFolder = 'C:\...\Matlab functions';
addpath(genpath(baseFolder));
```

### New Directory Structure

```
matlab-functions/
├── Modules/              # All analysis modules (organized)
│   ├── Aging_ver2/
│   ├── FieldSweep_ver3/
│   ├── MT_ver2/
│   └── ... (13 modules total)
├── Shared/               # Shared utilities
│   ├── General_ver2/
│   └── Tools_ver1/
├── Tests/                # Comprehensive test suite
├── Documentation/        # Migration guide & structure docs
└── [Old folders]         # Original structure (preserved!)
```

### Documentation

- 📖 [Migration Guide](Documentation/MIGRATION_GUIDE.md) - How to migrate
- 📋 [Project Structure](Documentation/PROJECT_STRUCTURE.md) - Detailed organization

### Key Features

- ✅ **Non-Destructive**: Original folders stay intact
- ✅ **Backward Compatible**: Old scripts still work
- ✅ **Fully Tested**: 15+ automated tests
- ✅ **Cloud Aware**: Handles Google Drive paths
- ✅ **Well Documented**: Clear migration guide
- ✅ **Reversible**: Can undo anytime

### Verify Backward Compatibility

```matlab
verify_old_structure_still_works
```

### Analysis Modules

- **Aging Memory**: Spin-glass aging memory analysis
- **Field Sweep**: Transport measurements vs field
- **AC Hall Coefficient**: MagLab measurements
- **M(H)**: Magnetization loops
- **M(T)**: Temperature-dependent magnetization
- **Resistivity**: Transport measurements
- **Switching**: Magnetic switching analysis
- **Zero-Field AMR**: AMR measurements
- ...and more!

## License

Private research code
