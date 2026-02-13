# MATLAB Functions Library - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Dependencies Matrix](#dependencies-matrix)
3. [Module Documentation](#module-documentation)
4. [Function Call Hierarchies](#function-call-hierarchies)
5. [File Format Specifications](#file-format-specifications)
6. [Parameter Reference](#parameter-reference)
7. [Quick-Start Examples](#quick-start-examples)

---

## Overview

This library contains 20+ specialized MATLAB modules for analyzing magnetic and transport properties of materials, primarily from MPMS, VSM, PPMS, and MagLab measurement systems. The modules are organized by measurement type and include comprehensive data import, filtering, analysis, and visualization capabilities.

### Core Architecture
- **Analysis Modules**: 14 specialized measurement analysis tools
- **Shared Utilities**: `General ver2/` (75+ functions) - core data processing and formatting
- **Tools**: `Tools ver1/` (11 functions) - codebase maintenance utilities
- **Interactive GUIs**: Figure formatting, colormap control, reference line tools

---

## Dependencies Matrix

### MATLAB Version Requirements
- **Minimum**: MATLAB R2023b (v9.15) or later recommended
- **Tested**: R2023b, R2024a, R2024b
- **Core Requirements**: MATLAB v5.3 compatibility for file format

### Toolbox Dependencies by Module

| Module | Signal Processing | Curve Fitting | Statistics | Image Processing | Optimization |
|--------|-------------------|---------------|------------|------------------|--------------|
| **Aging ver2** | ✓ (SG filter) | ✓ (Gaussian fit) | ✓ (Z-score) | - | ✓ (lsqcurvefit) |
| **AC HC MagLab ver8** | ✓ (findpeaks, SG) | ✓ (FFT analysis) | ✓ (quality metrics) | - | ✓ (fitting) |
| **FieldSweep ver3** | ✓ (median, SG) | - | - | - | - |
| **MT ver2** | ✓ (Hampel, median, SG) | - | ✓ (outlier detection) | - | - |
| **Switching ver12** | ✓ (Hampel, median, SG) | - | ✓ (outlier detection) | - | - |
| **zfAMR ver11** | ✓ (FFT, harmonics) | ✓ (polynomial) | - | - | - |
| **Relaxation ver3** | - | ✓ (exponential decay) | - | - | ✓ (weighted fit) |
| **Resistivity ver6** | ✓ (SG filter) | - | - | - | - |
| **MH ver1** | ✓ (filtering) | - | - | - | - |
| **PS ver4** | ✓ (median, SG) | - | - | - | - |
| **HC ver1** | ✓ (peak finding) | ✓ (polynomial) | - | - | - |
| **Susceptibility ver1** | - | - | - | - | - |

### Custom Function Dependencies

All modules depend on `General ver2/` utilities:

**Critical Dependencies (used by 5+ modules):**
- `read_data.m` - Core data import (9+ modules)
- `loadAllColormaps.m` - Colormap management (14+ modules)
- `formatAllFigures.m` - Figure formatting (8+ modules)
- `save_figs.m` family - Figure export (all modules)
- `build_channels.m` - Channel construction (5+ modules)
- `extract_growth_FIB.m` - Metadata extraction (10+ modules)

**Module-Specific Helpers:**
- Aging: `importFiles_aging.m`, `computeDeltaM.m`, `analyzeAFM_FM_components.m`
- FieldSweep: `apply_median_and_smooth_per_sweep.m`, `resolve_preset.m`
- Switching: `processFilesSwitching.m`, `analyzeSwitchingStability.m`
- zfAMR: 60+ specialized functions for angle/field/temperature analysis

---

## Module Documentation

### 1. Aging ver2 - Spin-Glass Aging Memory Analysis

**Purpose**: Analyze aging memory effects in spin glasses by comparing magnetization curves with and without aging pause.

**Main Script**: `Main_Aging.m`

**Typical Workflow**:
```
Input: MPMS .dat files → 
Import & Parse (pause vs no-pause) → 
Unit Conversion (emu/g → µB/Co) → 
Compute ΔM = M(pause) - M(no-pause) → 
AFM/FM Component Decomposition → 
Fit FM step + Gaussian dip → 
Output: Memory strength plots + metrics table
```

**Input Requirements**:
- **Format**: MPMS `.dat` files (tab-delimited)
- **Columns**: Temperature (K), Moment (emu), Mass (g), Field (Oe)
- **Organization**: Separate folders for "pause" vs "no-pause" measurements
- **Naming**: Must include pause temperature (Tp) in filename or path

**Key Parameters**:
```matlab
normalizeByMass = true;      % Normalize by sample mass
Bohar_units = true;          % Convert to µB/Co (requires Co content)
color_scheme = 'cmocean';    % Colormap for Tp encoding
dip_window_K = 15;           % Temperature window around dip (K)
smoothWindow_K = 5;          % Smoothing window width (K)
FM_plateau_K = [60, 80];     % FM plateau temperature range (K)
doFilterDeltaM = true;       % Apply Savitzky-Golay filtering
filterMethod = 'sgolay';     % 'sgolay' or 'movmean'
sgolayOrder = 3;             % SG polynomial order
sgolayFrame = 31;            % SG frame length (odd integer)
```

**Outputs**:
- 2-panel figure: AFM vs FM memory strength (color-coded by Tp)
- Summary table: Tp, FM_step_amplitude, Dip_area, Dip_sigma, Dip_center
- Optional: Robustness analysis plots (Z-scores vs parameter sweep)
- File export: .fig, .xlsx

**Dependencies**:
- `importFiles_aging.m` - Data import
- `computeDeltaM.m` - ΔM calculation with interpolation
- `analyzeAFM_FM_components.m` - Component decomposition
- `fitFMstep_plus_GaussianDip.m` - Curve fitting
- `plotAgingMemory.m` - Visualization
- `convertToMuBperCo.m` - Unit conversion
- `cmocean` colormap package

---

### 2. FieldSweep ver3 - Transport Field Sweep Analysis

**Purpose**: Analyze resistivity/resistance vs magnetic field sweeps at multiple temperatures.

**Main Script**: `FieldSweep_main.m`

**Typical Workflow**:
```
Input: Field sweep .dat files → 
Extract metadata (growth, FIB, current, preset) → 
Load 4-channel lock-in data (Field, Temp, LI1-4) → 
Build channels (apply scaling, preset mapping) → 
Apply median filter + Savitzky-Golay smoothing per sweep → 
Group by temperature → 
Output: Multi-temperature field sweep plots
```

**Input Requirements**:
- **Format**: `.dat` or `.mat` files from transport measurements
- **Columns**: Field (T), Temperature (K), Lock-in channels (LI1_X, LI1_Y, LI2_X, LI2_Y, LI3_X, LI3_Y, LI4_X, LI4_Y), Angle (deg)
- **Metadata**: Growth number, FIB number, current (µA or A), preset name in filename/path
- **Example filename**: `MG123_FIB4_100uA_FS_0to9T_4K.dat`

**Key Parameters**:
```matlab
Resistivity = true;          % Plot resistivity (Ω·cm) vs resistance (mΩ)
force_manual_preset = false; % Override auto-detected preset
manual_preset_name = '';     % Manual preset selection
Unfiltered = false;          % true=raw data, false=filtered
DoMedianFilter = true;       % Enable median filter
MedianWindow = 3;            % Median filter window size
DoSmoothing = true;          % Enable Savitzky-Golay smoothing
SmoothMethod = 'sgolay';     % Smoothing method
SmoothWindow = 11;           % SG smoothing window (odd integer)
center_graphs = false;       % Center data around zero
vertical_shift = false;      % Apply vertical offset between curves
symmetrization = false;      % Average +/- field sweeps
```

**Outputs**:
- Multi-figure set (one per channel: Rxx, Rxy, etc.)
- Each figure contains multiple temperature curves (color-coded)
- X-axis: Magnetic field (T)
- Y-axis: Resistivity (Ω·cm) or Resistance (mΩ)
- Auto-scaling and smart tick placement

**Dependencies**:
- `read_data.m` - Data import
- `build_channels.m` - Channel construction from lock-in data
- `apply_median_and_smooth_per_sweep.m` - Per-sweep filtering
- `resolve_preset.m`, `select_preset.m` - Channel mapping
- `extract_growth_FIB.m`, `extract_current_I.m`, `getScalingFactor.m` - Metadata
- `formatAllFigures.m` - Plot formatting

---

### 3. AC HC MagLab ver8 - Heat Capacity Symmetry Analysis

**Purpose**: Analyze alternating heat capacity measurements with sample/reference channels and automatic folding detection.

**Main Script**: `ACHC_main.m`

**Typical Workflow**:
```
Input: Tab-delimited AC HC files → 
Import sample and reference heat capacity (Cs, Cr) → 
Sort by slow/fast variable (Temperature, Angle, Field) → 
Plot Cs, Cr, Cdiff vs chosen variable → 
Optional: Apply shift/mirror transformation → 
Auto-analysis: Fold detection + Q-quality metric → 
Output: Overlay plots + Q(n,T) heatmap
```

**Input Requirements**:
- **Format**: Tab-delimited `.txt` or `.dat` files
- **Columns**: 
  - `Ts` - Sample temperature (K)
  - `Tr` - Reference temperature (K)
  - `Cs` - Sample heat capacity (J/mol·K)
  - `Cr` - Reference heat capacity (J/mol·K)
  - `Angle` - Measurement angle (deg)
  - `Field` - Magnetic field (T)
- **File Pattern**: Files numbered sequentially (`*_1`, `*_2`, etc.)

**Key Parameters**:
```matlab
Cs_Cr_plotMode = 'both';         % 'sample', 'reference', or 'both'
CsCr_plotLayout = 'overlay';     % 'overlay' or 'separate'
C_or_CoverT_plotType = 'raw';    % 'raw', 'norm' (C/T), or 'both'
includeDiff = true;              % Include Cs-Cr difference plot
xVar = 'Temp';                   % X-axis variable: 'Temp', 'Angle', 'Field'
slowVar = 'Temp';                % Slow scan variable
fastVar = 'Angle';               % Fast scan variable
applyShift = false;              % Apply vertical shift
Mirror = false;                  % Mirror data across reference point
foldMode = 'auto';               % 'auto' or 'manual' folding detection
foldSignal = 'Cs';               % Signal for fold detection: 'Cs', 'Cr', 'Diff'
Qmode = 'stdev';                 % Quality metric: 'stdev' or 'range'
```

**Outputs**:
- Overlay/separate plots: Cs, Cr, Cdiff vs temperature/angle/field
- Optional mirror-transformed plots
- Q(n,T) folding quality matrix (imagesc heatmap)
- FFT-based fold detection results

**Dependencies**:
- `importFilesACHC.m` - Multi-file import
- `PlotsACHC.m` - Plotting utilities
- `ACHC_runAuto.m` - Automatic fold detection and fitting
- `mirrorAcross.m` - Data reflection
- `formatAllFigures.m` - Figure formatting

---

### 4. MT ver2 - Magnetization vs Temperature Analysis

**Purpose**: Analyze magnetic moment vs temperature curves from MPMS/VSM with advanced cleaning and segmentation.

**Main Script**: `MT_main.m`

**Typical Workflow**:
```
Input: MPMS/VSM .dat files → 
Auto-detect system type (MPMS vs VSM) → 
Import moment vs temperature at multiple fields → 
Clean data (Hampel outlier removal, median, SG filter) → 
Segment into ZFC/FC/increasing/decreasing branches → 
Normalize by mass → Convert to µB/Co → 
Output: Individual and combined M(T) plots
```

**Input Requirements**:
- **Format**: MPMS or VSM `.dat` files (auto-detected)
- **MPMS Columns**: Time (sec), Temperature (K), Moment (emu), Field (Oe)
- **VSM Columns**: Temperature (K), Moment (emu), Field (Oe)
- **Multi-file**: One file per field value, auto-sorted

**Key Parameters**:
```matlab
unitsMode = 'per_Co';           % 'raw' (emu), 'per_mass' (emu/g), 'per_Co' (µB/Co)
plotQuantity = 'M';             % 'M' (moment) or 'M_over_H' (susceptibility)
figureMode = 'paper';           % 'paper' or 'regular' sizing
Unfiltered = false;             % true=raw, false=cleaned
plotAllCurvesOnOneFigure = true; % Combine all fields
useAutoYScale = true;           % Auto Y-axis limits
legendMode = 'internal';        % 'internal', 'external', or 'none'

% Cleaning parameters
tempJump_K = 0.2;               % Max temperature jump for continuity (K)
magJump_sigma = 5;              % Moment jump threshold (std devs)
hampelWindow = 5;               % Hampel filter window
hampelSigma = 3;                % Hampel threshold (std devs)
sgOrder = 3;                    % Savitzky-Golay polynomial order
sgFrame = 11;                   % SG frame length (odd integer)
max_interp_gap = 5;             % Max interpolation gap (points)
```

**Outputs**:
- Individual M(T) plots per field value
- Combined multi-field overlay plot
- Color-coded ZFC/FC/increasing/decreasing segments
- Optional external legend with field values

**Dependencies**:
- `getFileList_MT.m` - File discovery
- `detect_MT_file_type.m` - System auto-detection
- `importFiles_MT.m` - Data import
- `clean_MT_data.m` - Hampel + median + SG filtering
- `find_increasing_temperature_segments_MT.m`, `find_decreasing_temperature_segments_MT.m` - Segmentation
- `Plots_MT.m`, `Plots_MT_combined.m` - Visualization
- `compute_unitsRatio_MT.m`, `convertToMuBperCo.m` - Unit conversion

---

### 5. Switching ver12 - Magnetic Switching Stability Analysis

**Purpose**: Analyze pulse-driven magnetic switching with comprehensive stability metrics and drift analysis.

**Main Script**: `Switching_main.m`

**Typical Workflow**:
```
Input: Switching event .dat files → 
Detect measurement type (Amp-Temp map, Temp-Dep, Config) → 
Extract pulse scheme (length, delay, pulses/block) → 
Import binary switching traces (4 channels) → 
Pre-process: outlier removal, Hampel, median, SG filtering → 
Extract pulse plateaus + compute peak-to-peak (P2P) → 
Stability analysis: state detection, drift, settling times → 
Output: Switching traces, P2P maps, stability metrics
```

**Input Requirements**:
- **Format**: Binary switching trace `.dat` files
- **Columns**: Time, Field/Temp/Amplitude (dependent variable), 4 lock-in channels
- **Metadata**: Pulse length (ns), delay (ns), pulses per block in folder name
- **Example folder**: `Switching_100ns_10ns_100pulses/`

**Key Parameters**:
```matlab
% Preset selection
force_manual_preset = false;
manual_preset_name = '';

% Stability analysis options (struct)
stbOpts.debug = false;              % Show debug panels
stbOpts.state_definition = 'mean';  % 'mean' or 'median' state level
stbOpts.plateau_fit = 'robust';     % 'robust' or 'standard' fitting
stbOpts.skip_first_n = 2;           % Skip first N blocks

% Outlier handling
RemovePulseOutliers = true;         % Local outlier removal
PulseOutlierPercent = 3;            % Outlier threshold (%)

% Global filtering
hample_filter_window_size = 5;      % Hampel window
HampelGlobalPercent = 3;            % Hampel threshold (%)
med_filter_window_size = 3;         % Median filter window
SG_filter_poly_order = 3;           % SG polynomial order
SG_filter_frame_size = 11;          % SG frame (odd integer)

% Visualization
plot_std = true;                    % Show std dev shading
NegP2P_mode = false;                % Flip P2P sign
Resistivity = true;                 % Plot resistivity vs resistance
```

**Outputs**:
- Switching trace plots (time domain) for each file
- P2P amplitude vs dependent variable (color map)
- Stability metrics: drift rate, settling time, state fidelity
- Debug panels: trace, plateau, states, drift, slope comparison
- Optional: Excel export of P2P values

**Dependencies**:
- `getFileListSwitching.m` - File discovery and grouping
- `extractPulseSchemeFromFolder.m` - Parse pulse parameters
- `resolve_preset.m`, `select_preset.m` - Channel mapping
- `processFilesSwitching.m` - Core data processing pipeline
- `analyzeSwitchingStability.m` - Stability metrics computation
- `createSwitchingStabilityFigure.m` - Debug visualization
- `createPlotsSwitching.m` - Switching traces
- `createP2PSwitching.m` - P2P maps

---

### 6. Relaxation ver3 - Magnetic Relaxation Time Analysis

**Purpose**: Fit magnetic relaxation curves (TRM/IRM) with stretched exponential model.

**Main Script**: `main_relexation.m`

**Typical Workflow**:
```
Input: Relaxation .dat files → 
Import moment vs time at different T/H → 
Normalize by initial moment → 
Fit stretched exponential: M(t) = M0 * exp(-(t/τ)^β) → 
Extract relaxation time (τ) and stretching parameter (β) → 
Output: Fitted curves + τ(T), β(T) plots
```

**Input Requirements**:
- **Format**: `.txt` or `.dat` files organized by temperature/field
- **Columns**: Time (sec), Moment (emu), Temperature (K), Field (Oe)
- **Types**: TRM (Thermoremanent) or IRM (Isothermal Remanent Magnetization)

**Key Parameters**:
```matlab
betaBoost = 1.0;                % Initial β guess multiplier
tauBoost = 1.0;                 % Initial τ guess multiplier
timeWeight = 'log';             % Weighting: 'log', 'linear', or 'none'
absThreshold = 0.01;            % Minimum absolute moment threshold
slopeThreshold = -0.001;        % Minimum slope for valid data
fitWindowPercent = [5, 95];     % Fit window as % of time range
```

**Outputs**:
- Relaxation curves with fitted overlay (M/M0 vs time)
- τ vs Temperature plot
- β vs Temperature plot
- R² goodness-of-fit table

**Dependencies**:
- `importFiles_relaxation.m` - Data import
- `fitStretchedExponential.m` - Nonlinear fitting
- `convertToMuBperCo.m` - Optional unit conversion

---

### 7. zfAMR ver11 - Zero-Field AMR Analysis

**Purpose**: Analyze angle-dependent magnetoresistance with Fourier harmonic decomposition.

**Main Script**: `zfAMR_main.m`

**Typical Workflow**:
```
Input: Angle scan .dat files → 
Segment by angle/field/temperature → 
Build resistance channels from lock-in data → 
Normalize by reference channel → 
Fourier analysis: extract harmonics (cos(nθ), sin(nθ)) → 
Output: Angle-scan maps, AMR deviation plots, Fourier spectra
```

**Input Requirements**:
- **Format**: `.dat` files with 4 lock-in channels
- **Columns**: Angle (deg), Field (T), Temperature (K), LI1-4 channels
- **Scan type**: Angle sweeps at fixed T and H

**Key Parameters**:
```matlab
angleThreshold = 0.5;           % Angle segment threshold (deg)
fieldThreshold = 0.01;          % Field segment threshold (T)
tempThreshold = 0.1;            % Temperature segment threshold (K)
harmonicOrder = 12;             % Maximum Fourier harmonic order
```

**Outputs**:
- Angle-scan resistance maps (R vs angle, color-coded by T or H)
- AMR/PHE deviation plots
- Fourier harmonic spectra (amplitude vs harmonic number)
- Resistivity vs field/temperature tables

**Dependencies**:
- 60+ specialized functions for segmentation, Fourier analysis, and visualization
- `read_data.m`, `build_channels.m` - Data import and processing

---

### 8. Additional Modules (Brief)

#### MH ver1 - Magnetization-Field Hysteresis
- **Input**: MPMS/PPMS M-H curves
- **Output**: Hysteresis loops per temperature
- **Key Feature**: Temperature grouping, field cycling analysis

#### Resistivity ver6 - Temperature-Dependent Resistivity
- **Input**: Transport .dat files
- **Output**: ρ vs T curves with Tc detection, RRR calculation
- **Key Feature**: Critical temperature identification via derivative

#### PS ver4 - Phase Space AMR
- **Input**: Multi-variable transport data
- **Output**: ρ(T,H) phase space maps per angle
- **Key Feature**: Multi-dimensional parameter visualization

#### HC ver1 - Heat Capacity Field Dependence
- **Input**: Heat capacity .txt files
- **Output**: Cp vs T/H curves with peak analysis
- **Key Feature**: Polynomial peak fitting

#### Susceptibility ver1 - AC Susceptibility
- **Input**: AC susceptibility .txt files
- **Output**: χ'/χ" vs T per frequency
- **Key Feature**: Frequency-dependent analysis with phase correction

#### Resistivity MagLab ver1 - High-Field Resistivity
- **Input**: MagLab transport data
- **Output**: High-field resistivity analysis
- **Key Feature**: Extended field range support

---

## Function Call Hierarchies

### Universal Pipeline Pattern
All analysis modules follow this general hierarchy:

```
Main Script
├── Path Setup & addpath(genpath(baseFolder))
├── User Parameters
├── Metadata Extraction
│   ├── extract_growth_FIB(path)
│   ├── extract_current_I(filename)
│   └── getScalingFactor(growth, FIB)
├── Data Import
│   ├── read_data(filename)              [Universal]
│   ├── importFiles_<module>(dir)        [Module-specific]
│   └── detect_<module>_file_type(file)  [Optional]
├── Data Processing
│   ├── build_channels(data, preset)
│   ├── filter_channels(data, params)
│   └── <module>_analysis(data, params)
├── Visualization
│   ├── plot_<module>(data, options)
│   ├── loadAllColormaps()
│   └── formatAllFigures(figs, preset)
└── Export
    └── save_figs(figs, format, path)
```

### Module-Specific Hierarchies

#### Aging ver2
```
Main_Aging.m
├── extract_growth_FIB()
├── importFiles_aging()
│   ├── getFileList_aging()
│   └── read_data()
├── convertToMuBperCo()
├── computeDeltaM()
│   ├── alignTemperatures()
│   └── interpolate1()
├── analyzeAFM_FM_components()
│   ├── apply_sgolay_or_movmean()
│   └── findPlateau()
├── fitFMstep_plus_GaussianDip()
│   └── lsqcurvefit()
├── plotAgingMemory()
│   ├── cmocean()
│   └── scatter()
└── save_figs()
```

#### FieldSweep ver3
```
FieldSweep_main.m
├── extract_growth_FIB()
├── extract_current_I()
├── getScalingFactor()
├── parse_TB_from_FS_filename()
├── read_data()
├── resolve_preset() / select_preset()
├── build_channels()
│   └── apply_channel_signs_by_preset()
├── apply_median_and_smooth_per_sweep()
│   ├── medfilt1()
│   └── sgolayfilt()
├── Plot per channel
│   ├── plot()
│   ├── Tiks()  [Auto tick selection]
│   └── xlabel/ylabel with LaTeX
└── formatAllFigures()
    └── save_figs()
```

#### Switching ver12
```
Switching_main.m
├── extract_dep_type_from_folder()
├── getFileListSwitching()
├── extractPulseSchemeFromFolder()
├── extract_growth_FIB()
├── extract_current_I()
├── getScalingFactor()
├── resolve_preset() / select_preset()
├── processFilesSwitching()
│   ├── read_data()
│   ├── build_channels()
│   ├── removePulseOutliers()  [Local]
│   ├── hampel()               [Global]
│   ├── medfilt1()
│   ├── sgolayfilt()
│   └── extractPulsePlateaus()
├── analyzeSwitchingStability()
│   ├── detectSwitchingStates()
│   ├── computeDriftMetrics()
│   └── computeSettlingTime()
├── createPlotsSwitching()
│   └── plot switching traces
├── createP2PSwitching()
│   └── imagesc P2P map
└── createSwitchingStabilityFigure()
    └── subplot debug panels
```

#### MT ver2
```
MT_main.m
├── detect_MT_file_type()
├── getFileList_MT()
├── importFiles_MT()
│   └── read_data()
├── clean_MT_data()
│   ├── hampel()
│   ├── medfilt1()
│   └── sgolayfilt()
├── find_increasing_temperature_segments_MT()
├── find_decreasing_temperature_segments_MT()
├── compute_unitsRatio_MT()
├── convertToMuBperCo()
├── Plots_MT()
│   └── plot per field
├── Plots_MT_combined()
│   └── overlay all fields
└── add_MT_legend()
```

#### AC HC MagLab ver8
```
ACHC_main.m
├── importFilesACHC()
│   └── read ACHC data files
├── Sort by slow/fast variables
├── PlotsACHC()
│   ├── plot Cs, Cr, Cdiff
│   └── apply layout (overlay/separate)
├── mirrorAcross()  [Optional]
└── ACHC_runAuto()
    ├── FFT_detect_fold()
    ├── fitACHC_curve()
    ├── compute_Q_metric()
    └── imagesc Q(n,T) heatmap
```

---

## File Format Specifications

### Common MPMS/VSM Data Format (.dat)
**Tab-delimited ASCII files**

#### MPMS Format:
```
Time (sec)    Temperature (K)    Moment (emu)    Field (Oe)
0.0           300.0              1.234e-4        1000.0
1.0           299.5              1.235e-4        1000.0
...
```

#### VSM Format:
```
Temperature (K)    Moment (emu)    Field (Oe)
300.0              1.234e-4        1000.0
299.5              1.235e-4        1000.0
...
```

**Detection**: Use `detect_MT_file_type()` to auto-identify format.

---

### Transport/Lock-In Data Format (.dat)
**12-column tab-delimited format**

```
Column  | Name          | Units | Description
--------|---------------|-------|----------------------------------
1       | Time          | sec   | Measurement timestamp
2       | Field         | T     | Magnetic field
3       | Temperature   | K     | Sample temperature
4       | Angle         | deg   | Rotation angle
5       | LI1_X         | V     | Lock-in 1, X component
6       | LI1_Y         | V     | Lock-in 1, Y component
7       | LI2_X         | V     | Lock-in 2, X component
8       | LI2_Y         | V     | Lock-in 2, Y component
9       | LI3_X         | V     | Lock-in 3, X component
10      | LI3_Y         | V     | Lock-in 3, Y component
11      | LI4_X         | V     | Lock-in 4, X component
12      | LI4_Y         | V     | Lock-in 4, Y component
```

**Used by**: FieldSweep, Switching, zfAMR, PS, Resistivity

**Reading**: `read_data(filename)` → struct with fields: `Field`, `Temp`, `Angle`, `LI1`, `LI2`, `LI3`, `LI4`

---

### AC Heat Capacity Format (.txt/.dat)
**Tab-delimited with header**

```
Column  | Name          | Units      | Description
--------|---------------|------------|----------------------------------
1       | Ts            | K          | Sample temperature
2       | Tr            | K          | Reference temperature
3       | Cs            | J/mol·K    | Sample heat capacity
4       | Cr            | J/mol·K    | Reference heat capacity
5       | Angle         | deg        | Measurement angle
6       | Field         | T          | Magnetic field
```

**Used by**: AC HC MagLab ver8

**Reading**: `importFilesACHC(dir)` → struct array with fields: `Ts`, `Tr`, `Cs`, `Cr`, `Angle`, `Field`

---

### Relaxation Data Format (.txt)
**Two-column format**

```
Time (sec)    Moment (emu)
0.0           1.234e-4
10.0          1.180e-4
100.0         1.050e-4
...
```

**Used by**: Relaxation ver3

**Reading**: `importFiles_relaxation(file)` → struct with `Time`, `Moment`, `Temp`, `Field`

---

### Filename Conventions

**Growth and FIB Encoding**:
- `MG123` or `Growth_123` → Growth number: 123
- `FIB4` or `FIB_4` → FIB number: 4

**Current Encoding**:
- `100uA`, `100µA` → 100 µA
- `1mA`, `1.5mA` → 1.0, 1.5 mA
- `2A`, `2.5A` → 2.0, 2.5 A

**Field Sweep Ranges**:
- `FS_0to9T` → 0 to 9 Tesla
- `FS_-1to1T` → -1 to 1 Tesla

**Temperature Ranges**:
- `4K`, `300K` → Single temperature
- `4to300K` → Temperature range

**Presets**:
- `preset_Standard`, `preset_Hall` → Channel mapping preset name

**Example Full Filename**:
`MG123_FIB4_100uA_preset_Standard_FS_0to9T_4to300K.dat`

---

## Parameter Reference

### Filtering Parameters

#### Hampel Filter (Outlier Detection)
```matlab
hampelWindow = 5;          % Window size (data points)
hampelSigma = 3;           % Threshold (standard deviations)
```
**Purpose**: Robust outlier detection using median absolute deviation.
**Recommendation**: Use window=5-11, sigma=3-5 for most applications.
**Used by**: MT, Switching, zfAMR

---

#### Median Filter (Noise Reduction)
```matlab
MedianWindow = 3;          % Window size (data points, odd integer)
```
**Purpose**: Remove high-frequency noise while preserving edges.
**Recommendation**: Use window=3-5 for noisy data, avoid for smooth data.
**Used by**: FieldSweep, Switching, PS, AC HC MagLab

---

#### Savitzky-Golay Filter (Smoothing + Derivatives)
```matlab
sgolayOrder = 3;           % Polynomial order (2-5 typical)
sgolayFrame = 11;          % Frame length (odd integer, > order)
```
**Purpose**: Polynomial smoothing that preserves peak shapes and derivatives.
**Recommendation**: 
- Order 2-3 for most data
- Frame 11-51 depending on noise level
- Must be odd: Frame > Order
**Used by**: All modules with smoothing needs

---

### Unit Conversion Parameters

#### Mass Normalization
```matlab
normalizeByMass = true;    % Divide by sample mass (g)
```
**Purpose**: Convert absolute moment (emu) to specific magnetization (emu/g).
**Requirement**: Sample mass must be in data file or filename.

---

#### Bohr Magneton per Cobalt
```matlab
Bohar_units = true;        % Convert to µB/Co
```
**Purpose**: Express magnetization in µB per Co atom (assumes Co content = 1/3 formula).
**Formula**: `M_µB/Co = (M_emu/g × MW_g/mol) / (N_A × 1/3 × µB_emu)`
**Used by**: Aging, MT, MH, Relaxation

---

### Segmentation Parameters

#### Temperature Grouping
```matlab
delta_T = 0.2;             % Temperature tolerance (K)
```
**Purpose**: Group data points with similar temperatures into segments.
**Recommendation**: 0.1-0.5 K depending on temperature stability.
**Used by**: MH, Resistivity, PS

---

#### Field Grouping
```matlab
FIELD_TOL = 0.05;          % Field tolerance (T)
```
**Purpose**: Group data points with similar magnetic fields.
**Recommendation**: 0.01-0.1 T depending on field precision.
**Used by**: PS, zfAMR

---

### Visualization Parameters

#### Font Sizes
```matlab
fontsize = 16;             % General text size
```
**Recommendation**: 
- Presentations: 16-20
- Publications: 12-14
- Screen viewing: 10-12

---

#### Line Width
```matlab
lineWidth = 2;             % Plot line thickness
```
**Recommendation**:
- Presentations: 2-3
- Publications: 1-1.5

---

#### Color Schemes
```matlab
color_scheme = 'cmocean';  % Colormap choice
```
**Options**:
- `'parula'` (MATLAB default)
- `'lines'` (distinct lines for overlays)
- `'cmocean'` (perceptually uniform scientific colormaps)
- `'turbo'`, `'jet'`, `'hsv'` (legacy)

**Recommendation**: Use `'cmocean'` for heatmaps, `'lines'` for multi-line plots.

---

## Quick-Start Examples

### Example 1: Analyze Aging Memory Data

```matlab
%% Setup
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% User Settings
dir = 'C:\Data\Aging\Sample_MG123_FIB4';
normalizeByMass = true;
Bohar_units = true;
dip_window_K = 15;
smoothWindow_K = 5;

%% Run Analysis
cd(fullfile(baseFolder, 'Aging ver2'));
Main_Aging;

%% Output
% Figures: AFM vs FM memory strength
% Table: Tp, FM_step_A, Dip_area, Dip_sigma
```

---

### Example 2: Field Sweep Analysis

```matlab
%% Setup
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% User Settings
filename = 'MG123_FIB4_100uA_FS_0to9T_4K.dat';
dataDir = 'C:\Data\FieldSweep';
Resistivity = true;
Unfiltered = false;
DoMedianFilter = true;
MedianWindow = 3;
DoSmoothing = true;

%% Run Analysis
cd(fullfile(baseFolder, 'FieldSweep ver3'));
FieldSweep_main;

%% Output
% Multi-figure: Rxx, Rxy, Ryy vs Field at multiple T
```

---

### Example 3: MT Analysis (Magnetization vs Temperature)

```matlab
%% Setup
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% User Settings
dataDir = 'C:\Data\MT\Sample_MG456';
unitsMode = 'per_Co';
plotQuantity = 'M';
Unfiltered = false;
plotAllCurvesOnOneFigure = true;

%% Run Analysis
cd(fullfile(baseFolder, 'MT ver2'));
MT_main;

%% Output
% Individual M(T) plots per field
% Combined multi-field overlay
% Color-coded ZFC/FC branches
```

---

### Example 4: Switching Stability Analysis

```matlab
%% Setup
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% User Settings
dataDir = 'C:\Data\Switching\MG789_TempDep';
RemovePulseOutliers = true;
PulseOutlierPercent = 3;
plot_std = true;

% Stability options
stbOpts.debug = true;
stbOpts.state_definition = 'mean';
stbOpts.plateau_fit = 'robust';

%% Run Analysis
cd(fullfile(baseFolder, 'Switching ver12', 'main'));
Switching_main;

%% Output
% Switching traces vs time
% P2P amplitude maps
% Stability metrics (drift, settling time)
```

---

### Example 5: AC Heat Capacity Auto-Analysis

```matlab
%% Setup
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% User Settings
dataDir = 'C:\Data\ACHC\Angle_Scans';
Cs_Cr_plotMode = 'both';
xVar = 'Angle';
slowVar = 'Temp';
fastVar = 'Angle';
foldMode = 'auto';
foldSignal = 'Cs';

%% Run Analysis
cd(fullfile(baseFolder, 'AC HC MagLab ver8'));
ACHC_main;

%% Output
% Cs, Cr, Cdiff vs Angle
% Q(n,T) folding quality heatmap
```

---

## Troubleshooting

### Common Issues

**1. "Undefined function or variable"**
- **Cause**: Shared utilities not on path
- **Solution**: Ensure `addpath(genpath(baseFolder))` is called with correct base path

**2. "Index exceeds array dimensions"**
- **Cause**: Unexpected data format or missing columns
- **Solution**: Verify file format matches expected column layout (see File Format Specifications)

**3. "Curve fitting failed to converge"**
- **Cause**: Poor initial guess or noisy data
- **Solution**: Increase filtering (higher median/SG window), adjust fit parameters

**4. "No data files found"**
- **Cause**: Incorrect `dir` or `dataDir` path
- **Solution**: Verify path exists and contains expected file pattern

**5. Figures appear blank or cut off**
- **Cause**: Auto-scaling issue or figure window size
- **Solution**: Use `useAutoYScale = true`, call `formatAllFigures()` manually

---

## Best Practices

### Data Organization
1. Organize data by experiment type in separate folders
2. Include metadata (growth, FIB, current) in filenames or folder names
3. Keep raw data separate from processed outputs
4. Use consistent naming conventions

### Script Workflow
1. Set `baseFolder` at top of script
2. Define all user parameters in clearly marked section
3. Test with single file before batch processing
4. Save figures to dedicated output folder
5. Export summary tables to Excel for record-keeping

### Performance Optimization
1. Use `Unfiltered = true` for quick preview, then enable filtering
2. Disable `plot_std` and debug options for faster batch runs
3. Close unnecessary figures with `close all` before batch processing
4. Use `parallel_enabled = false` for debugging, enable for production

---

## Additional Resources

### Colormap Library
- **Location**: `github_repo/cmocean/`
- **Documentation**: See `github_repo/cmocean/README.md`
- **Usage**: Loaded automatically via `loadAllColormaps()`

### Figure Formatting GUI
- **Location**: `GUIs/FinalFigureFormatterUI.m`
- **Purpose**: Interactive figure sizing, font adjustment, export
- **Launch**: Run `FinalFigureFormatterUI` from MATLAB command window

### Colormap Control GUI
- **Location**: `General ver2/CtrlGUI/CtrlGUI.m`
- **Purpose**: Real-time colormap preview and application
- **Launch**: Run `CtrlGUI` from MATLAB command window

---

## Version Information

**Library Version**: 2024.2
**Last Updated**: 2024-11-15
**MATLAB Compatibility**: R2023b or later (tested through R2024b)
**Maintainer**: Matan1986

---

## License

This library is provided for research and educational purposes.
See individual module folders for specific licensing information.
