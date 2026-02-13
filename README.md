# MATLAB Functions Library

A comprehensive collection of MATLAB modules for analyzing magnetic and transport properties of materials from MPMS, VSM, PPMS, and MagLab measurement systems.

## 📚 Documentation

- **[DOCUMENTATION.md](DOCUMENTATION.md)** - Complete technical reference with detailed workflows, parameters, and examples
- **[Module Summary](#modules)** - Quick overview of all analysis modules
- **[Quick Start](#quick-start)** - Get started in minutes
- **[Installation](#installation)** - Setup instructions

---

## 🎯 Quick Start

```matlab
%% 1. Setup paths
baseFolder = 'C:\Users\YourName\Documents\Matlab functions';
addpath(genpath(baseFolder));

%% 2. Navigate to module and set parameters
cd(fullfile(baseFolder, 'MT ver2'));
dataDir = 'C:\Data\MT\Sample_MG123';
unitsMode = 'per_Co';
Unfiltered = false;

%% 3. Run analysis
MT_main;
```

---

## 📦 Installation

### Prerequisites
- **MATLAB**: R2023b or later
- **Required Toolboxes**:
  - Signal Processing Toolbox (filtering, peak detection)
  - Curve Fitting Toolbox (nonlinear fitting)
  - Statistics and Machine Learning Toolbox (outlier detection)
  - Optimization Toolbox (curve fitting)

### Setup Steps

1. **Clone or download** this repository to your local machine

2. **Add to MATLAB path** at the start of each script:
   ```matlab
   baseFolder = 'C:\Path\To\Matlab functions';  % Update this path
   addpath(genpath(baseFolder));
   ```

3. **Verify installation**:
   ```matlab
   which read_data      % Should show path to General ver2/read_data.m
   which loadAllColormaps  % Should show path to General ver2/loadAllColormaps.m
   ```

4. **Optional**: Launch interactive GUIs:
   ```matlab
   FinalFigureFormatterUI   % Figure formatting tool
   CtrlGUI                  % Colormap control
   ```

---

## 📊 Modules

### Magnetometry & Magnetic Properties

| Module | Purpose | Input Format | Main Script |
|--------|---------|--------------|-------------|
| **Aging ver2** | Spin-glass aging memory (pause vs no-pause) | MPMS .dat (T, M, Field) | `Main_Aging.m` |
| **MT ver2** | Magnetization vs Temperature (ZFC/FC analysis) | MPMS/VSM .dat (T, M, Field) | `MT_main.m` |
| **MH ver1** | Magnetization-Field hysteresis loops | MPMS/PPMS .dat (H, M, T) | `MH_main.m` |
| **Relaxation ver3** | TRM/IRM magnetic relaxation time analysis | .txt (Time, M) | `main_relexation.m` |
| **Susceptibility ver1** | AC susceptibility (χ' and χ") | .txt (T, χ', χ", freq) | `main_Susceptibility.m` |

### Transport & Resistivity

| Module | Purpose | Input Format | Main Script |
|--------|---------|--------------|-------------|
| **FieldSweep ver3** | Resistivity vs magnetic field sweeps | 12-col .dat (Field, T, LI1-4) | `FieldSweep_main.m` |
| **Switching ver12** | Pulse-driven switching stability | 12-col .dat (Time, dep_var, LI1-4) | `Switching_main.m` |
| **zfAMR ver11** | Zero-field angle-dependent AMR | 12-col .dat (Angle, Field, T, LI1-4) | `zfAMR_main.m` |
| **Resistivity ver6** | Temperature-dependent resistivity (Tc, RRR) | .dat (T, Vxx, Vxy) | `Resistivity_main.m` |
| **Resistivity MagLab ver1** | High-field resistivity analysis | MagLab .dat format | `ACHC_RH_main.m` |
| **PS ver4** | Phase space AMR mapping | 12-col .dat (T, H, Angle, LI1-4) | `PS_main.m` |

### Heat Capacity

| Module | Purpose | Input Format | Main Script |
|--------|---------|--------------|-------------|
| **AC HC MagLab ver8** | AC heat capacity with auto-folding | Tab-delim (Ts, Tr, Cs, Cr, Angle, Field) | `ACHC_main.m` |
| **HC ver1** | Field-dependent heat capacity | .txt (T, Cp, Field) | `HC_main.m` |

### Utilities & Tools

| Module | Purpose | Contents |
|--------|---------|----------|
| **General ver2** | Core utilities (75+ functions) | Data I/O, plotting, formatting, channel building |
| **Tools ver1** | Codebase maintenance | Dead function detection, file organization |
| **GUIs** | Interactive tools | Figure formatter, colormap control |
| **Fitting ver1** | General curve fitting | Sine, logistic, folding models |

---

## 📁 File Formats

### MPMS/VSM Data (.dat)
**Tab-delimited ASCII**

**MPMS Format:**
```
Time(sec)    Temperature(K)    Moment(emu)    Field(Oe)
```

**VSM Format:**
```
Temperature(K)    Moment(emu)    Field(Oe)
```

### Transport Data (.dat)
**12-column tab-delimited**
```
Time | Field(T) | Temp(K) | Angle(deg) | LI1_X | LI1_Y | LI2_X | LI2_Y | LI3_X | LI3_Y | LI4_X | LI4_Y
```
Used by: FieldSweep, Switching, zfAMR, PS, Resistivity

### AC Heat Capacity (.txt/.dat)
**Tab-delimited with header**
```
Ts(K) | Tr(K) | Cs(J/mol·K) | Cr(J/mol·K) | Angle(deg) | Field(T)
```

---

## 🔧 Common Workflows

### 1. Magnetization vs Temperature (M-T)
```matlab
% Setup
baseFolder = 'C:\Path\To\Matlab functions';
addpath(genpath(baseFolder));

% Parameters
dataDir = 'C:\Data\MT\Sample_MG123';
unitsMode = 'per_Co';           % 'raw', 'per_mass', or 'per_Co'
plotQuantity = 'M';             % 'M' or 'M_over_H'
Unfiltered = false;             % Enable cleaning (Hampel, median, SG)
plotAllCurvesOnOneFigure = true;

% Run
cd(fullfile(baseFolder, 'MT ver2'));
MT_main;
```

### 2. Field Sweep Analysis
```matlab
% Setup
baseFolder = 'C:\Path\To\Matlab functions';
addpath(genpath(baseFolder));

% Parameters
filename = 'MG123_FIB4_100uA_FS_0to9T_4K.dat';
dataDir = 'C:\Data\FieldSweep';
Resistivity = true;             % Plot ρ (Ω·cm) vs R (mΩ)
DoMedianFilter = true;
MedianWindow = 3;
DoSmoothing = true;

% Run
cd(fullfile(baseFolder, 'FieldSweep ver3'));
FieldSweep_main;
```

### 3. Aging Memory Analysis
```matlab
% Setup
baseFolder = 'C:\Path\To\Matlab functions';
addpath(genpath(baseFolder));

% Parameters
dir = 'C:\Data\Aging\Sample_MG123';
normalizeByMass = true;
Bohar_units = true;
dip_window_K = 15;
smoothWindow_K = 5;

% Run
cd(fullfile(baseFolder, 'Aging ver2'));
Main_Aging;
```

### 4. Switching Stability
```matlab
% Setup
baseFolder = 'C:\Path\To\Matlab functions';
addpath(genpath(baseFolder));

% Parameters
dataDir = 'C:\Data\Switching\TempDep';
RemovePulseOutliers = true;
PulseOutlierPercent = 3;
plot_std = true;

stbOpts.debug = true;
stbOpts.state_definition = 'mean';
stbOpts.plateau_fit = 'robust';

% Run
cd(fullfile(baseFolder, 'Switching ver12', 'main'));
Switching_main;
```

---

## 🎨 Visualization Features

- **Colormaps**: Perceptually uniform scientific colormaps via `cmocean` package
- **Figure Formatting**: Publication-ready LaTeX labels, smart tick placement
- **Interactive GUIs**: 
  - `FinalFigureFormatterUI` - Adjust sizing, fonts, export
  - `CtrlGUI` - Real-time colormap preview and application
- **Export Formats**: PNG, PDF, JPEG, PowerPoint

---

## 🔬 Key Features

### Data Cleaning
- **Hampel filter**: Robust outlier detection (median absolute deviation)
- **Median filter**: High-frequency noise removal
- **Savitzky-Golay**: Smoothing that preserves peak shapes

### Unit Conversion
- **Mass normalization**: emu → emu/g
- **Bohr magneton**: emu/g → µB/Co (assumes 1/3 Co content)

### Analysis Tools
- **Segmentation**: Automatic detection of ZFC/FC, increasing/decreasing temperature
- **Curve fitting**: Gaussian, stretched exponential, polynomial models
- **Fourier analysis**: Harmonic decomposition for AMR data
- **Stability metrics**: Drift, settling time, state fidelity for switching

---

## 📖 Detailed Documentation

See **[DOCUMENTATION.md](DOCUMENTATION.md)** for:
- Dependencies matrix (toolboxes, MATLAB version, custom functions)
- Detailed parameter guides with recommended ranges
- Function call hierarchies for each module
- File format specifications with column layouts
- Advanced workflows and troubleshooting

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Undefined function" | Run `addpath(genpath(baseFolder))` with correct path |
| "Index exceeds array" | Verify file format matches expected columns |
| "Curve fitting failed" | Increase filtering windows, adjust fit parameters |
| "No data files found" | Check `dir`/`dataDir` path exists |
| Blank figures | Enable `useAutoYScale = true`, call `formatAllFigures()` |

---

## 📄 License

This library is provided for research and educational purposes.

---

## 👤 Author

**Matan1986**

---

## 🔗 Repository Structure

```
matlab-functions/
├── README.md                      # This file
├── DOCUMENTATION.md               # Detailed technical documentation
├── Aging ver2/                    # Aging memory analysis
├── AC HC MagLab ver8/             # Heat capacity analysis
├── FieldSweep ver3/               # Field sweep transport
├── MT ver2/                       # Magnetization vs temperature
├── Switching ver12/               # Switching stability
├── zfAMR ver11/                   # Zero-field AMR
├── Relaxation ver3/               # Relaxation time analysis
├── Resistivity ver6/              # Temperature-dependent resistivity
├── Resistivity MagLab ver1/       # High-field resistivity
├── MH ver1/                       # M-H hysteresis
├── PS ver4/                       # Phase space AMR
├── HC ver1/                       # Heat capacity
├── Susceptibility ver1/           # AC susceptibility
├── Fitting ver1/                  # General curve fitting
├── General ver2/                  # Shared utilities (75+ functions)
│   ├── CtrlGUI/                   # Colormap control GUI
│   └── CommonFormatting/          # Figure formatting
├── Tools ver1/                    # Codebase maintenance
├── GUIs/                          # Interactive tools
└── github_repo/                   # Third-party packages (cmocean)
```

---

## 🚀 Getting Help

1. Check **[DOCUMENTATION.md](DOCUMENTATION.md)** for detailed guides
2. Review quick-start examples above
3. Examine the main script for your module (e.g., `MT_main.m`)
4. Test with a single data file before batch processing
5. Use `help function_name` in MATLAB for function documentation
