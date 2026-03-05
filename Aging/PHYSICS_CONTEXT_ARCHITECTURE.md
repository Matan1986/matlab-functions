# Architecture: Physics Context Integration

## System Overview

```
Main_Aging.m
    │
    ├─► Stage 1-6: Data preparation
    │
    ├─► Stage 7: Reconstruction
    │   └─► result struct with R², λ, a, b
    │
    ├─► [NEW] Extract Physics Context ◄──────┐
    │   │                                     │
    │   ├─► cfg (config)     ─────────────────┤
    │   ├─► result (stage7)  ─────────────────┼─► dbgExtractPhysicsContext()
    │   └─► state (pipeline) ─────────────────┤
    │                                         │
    │                        physicsContext ◄─┘
    │
    ├─► [NEW] Format Physics Summary
    │   │
    │   └─► dbgSummaryPhysics(cfg, physicsContext, result, state)
    │       └─► diagnostics/physics_context.txt (human-readable)
    │
    ├─► [UPDATED] Compile Metrics Table
    │   │
    │   └─► dbgSummaryTable() with physics context
    │       └─► diagnostics/diagnostic_summary.txt (structured)
    │
    └─► Stage 8-9: Plotting and finalization
```

---

## Data Flow

### Input Sources

**1. Configuration** (`cfg` struct)
```matlab
cfg.current_mA = 35;                % Reference current
cfg.Tsw = [4:2:34];                % Temperature grid
cfg.switchParams.fitTmin = 10;      % Fit window
cfg.switchParams.fitTmax = 32;
cfg.switchParams.metric = 'lambda'; % Metric type
cfg.AFM = 'area';                  % Extraction method
```

**2. Pause Runs** (`state.pauseRuns` array)
```matlab
state.pauseRuns(i).waitK = 6, 10, 14, 18, ...  % Pause temperatures
state.pauseRuns(i).baseline                    % Baseline data
```

**3. Reconstruction Result** (`result` struct from stage7)
```matlab
result.Rsw_fit     % Fitted switching amplitude
result.R_squared   % Fit quality
result.lambda      % Coexistence parameter
result.a_basis     % AFM basis function
result.b_basis     % FM basis function
result.coeff_a     % Amplitude scaling
result.coeff_b     % Offset correction
```

**4. Multi-Current Data** (optional)
```matlab
cfg.Rsw_15mA  % Switching at 15 mA
cfg.Rsw_20mA  % Switching at 20 mA
cfg.Rsw_25mA  % Switching at 25 mA
...
cfg.Rsw_45mA  % Switching at 45 mA
```

---

## Extraction Logic

### dbgExtractPhysicsContext.m

**Input:** `cfg`, `result`, `state`

**Processing:**
```
┌─ Basic Metadata
│  ├─ Sample name (from config)
│  └─ Dataset name (from config)
│
├─ Experimental Setup
│  ├─ Reference current: cfg.current_mA
│  ├─ Available currents: scan cfg for Rsw_*mA fields
│  ├─ Pause count: numel(state.pauseRuns)
│  └─ Pause temperatures: [state.pauseRuns.waitK]
│
├─ Temperature Grid
│  ├─ Min: cfg.Tsw(1)
│  ├─ Max: cfg.Tsw(end)
│  ├─ Range: max - min
│  └─ Points: numel(cfg.Tsw)
│
├─ Fitting Configuration
│  ├─ Window min: cfg.switchParams.fitTmin
│  ├─ Window max: cfg.switchParams.fitTmax
│  └─ Mode: cfg.switchingMetricMode
│
└─ Reconstruction Results
   ├─ R²: result.R_squared
   ├─ λ: result.lambda
   ├─ a: result.coeff_a
   ├─ b: result.coeff_b
   └─ Basis functions: A(T), B(T)
```

**Output:** `physicsContext` struct with 20+ fields

---

## Integration Points

### 1. Main_Aging.m (Lines ~130-180)

**After stage7_reconstructSwitching completes:**
```matlab
% Extract physics context
physicsContext = dbgExtractPhysicsContext(cfg, result, state);

% Save formatted physics summary
dbgSummaryPhysics(cfg, physicsContext, result, state);

% Compile comprehensive metrics table
dbgSummaryTable(cfg, ...
    '=== SAMPLE & DATASET ===', '', ...
    'sample_name', physicsContext.sample_name, ...
    'dataset_name', physicsContext.dataset_name, ...
    '', '', ...
    '=== EXPERIMENTAL SETUP ===', '', ...
    'reference_current_mA', physicsContext.reference_current_mA, ...
    'available_currents_mA', mat2str(physicsContext.available_currents_mA), ...
    'pause_temperatures_K', mat2str(physicsContext.pause_temperatures_K), ...
    'n_pause_runs', physicsContext.n_pause_runs, ...
    ... etc
);
```

### 2. dbgExtractPhysicsContext.m

**Called with:** `(cfg, result, state)`

**Returns:** `physicsContext` struct

**Key extractions:**

```matlab
% Get reference current
physicsContext.reference_current_mA = cfg.current_mA;

% Find all available currents
available_I = [];
for J = [15, 20, 25, 30, 35, 45]
    if isfield(cfg, sprintf('Rsw_%dmA', J)) && ~isempty(cfg.(sprintf('Rsw_%dmA', J)))
        available_I = [available_I, J];
    end
end
physicsContext.available_currents_mA = available_I;

% Extract temperature grid
physicsContext.temperature_min_K = cfg.Tsw(1);
physicsContext.temperature_max_K = cfg.Tsw(end);
physicsContext.n_temperature_points = numel(cfg.Tsw);

% Get pause information
physicsContext.pause_temperatures_K = [state.pauseRuns.waitK];
physicsContext.n_pause_runs = numel(state.pauseRuns);

% Get fitting window
physicsContext.fit_window_min_K = cfg.switchParams.fitTmin;
physicsContext.fit_window_max_K = cfg.switchParams.fitTmax;

% Extract reconstruction results
physicsContext.fit_quality_R2 = result.R_squared;
physicsContext.coexistence_parameter_lambda = result.lambda;
physicsContext.reconstruction_coeff_a = result.coeff_a;
physicsContext.reconstruction_coeff_b = result.coeff_b;
```

### 3. dbgSummaryPhysics.m

**Called with:** `(cfg, physicsContext, result, state)`

**Creates:** `diagnostics/physics_context.txt`

**Process:**
1. Build header (box drawing)
2. Write metadata section
3. Write experimental setup
4. Write temperature grid
5. Write reconstruction results
6. Write basis function explanation
7. Write measurement technique
8. Write interpretation guide
9. Close box

**Example section:**
```
╔═══════════════════════════════════════════╗
║      RECONSTRUCTION RESULTS              ║
╠═══════════════════════════════════════════╣
  
Model: R_sw(T) ≈ a·C(T) + b

where C(T) = 1 - |A(T) - B(T)|

Parameters:
  a (amplitude)      : 1.2456
  b (offset)         : -0.0123
  λ (mixing)         : 0.6234
  
Quality of Fit:
  R² (variance explained) : 0.9876
    → Excellent fit (98.76%)
```

### 4. dbgSummaryTable.m (Updated)

**Changed:** Now supports section headers (lines starting with "===")

**Old behavior:** Fixed key-value pairs only
```
key1 = value1
key2 = value2
```

**New behavior:** Section headers + formatted values
```
=== SECTION 1 ===
─────────────────
  key1 = value1
  key2 = value2

=== SECTION 2 ===
─────────────────
  key3 = value3
```

---

## Output Files

### physics_context.txt

**Location:** `diagnostics/physics_context.txt`

**Content:** Human-readable physics summary with:
- Sample identification
- Experimental parameters
- Temperature grid details
- Reconstruction parameters
- Fit quality interpretation
- Basis function explanation
- Physical meaning of each parameter

**Format:** ASCII, plain text, no MATLAB required

**Typical size:** 200-300 lines

**Intended reader:** Any physicist or collaborator

### diagnostic_summary.txt

**Location:** `diagnostics/diagnostic_summary.txt`

**Content:** Structured metrics table with:
- All physics context fields
- Numeric values with appropriate precision
- Sections for organization
- Aligned columns for readability

**Format:** Structured text (spreadsheet-like)

**Typical size:** 100-150 lines

**Intended reader:** Physicist or data analyst comparing across experiments

### diagnostic_log.txt

**Location:** `diagnostics/diagnostic_log.txt`

**Content:** Complete execution log with:
- All console output
- Debug messages
- Warnings and errors
- Timestamps
- Diagnostic details

**Format:** Plain text, chronological

**Typical size:** 500-1000+ lines

**Intended reader:** Developer or troubleshooter

---

## Physical Parameters Explained

### Temperature Grid Specification

**cfg.Tsw = [4:2:34]**
- Start: 4 K (minimum spin-glass temperature)
- Step: 2 K (resolution)
- End: 34 K (below transition)
- Result: [4 6 8 10 ... 32 34] (16 points)

**Why this range:**
- Below 4 K: Spin glass too slow to measure
- Above 34 K: Approaching magnetic transition for MgBr₂·2H₂O
- 2 K steps: Balance resolution with measurement time

### Fitting Window

**fitTmin = 10 K, fitTmax = 32 K**

Why exclude edges?
- Below 10 K: Too close to measurement noise
- Above 32 K: Approaching transition effects
- 10-32 K: Clean region for AFM/FM decomposition

### Coexistence Model

The model reconstructs $R_{sw}(T)$ as:

$$R_{sw}(T) \approx a \cdot C(T) + b$$

where
- $C(T) = 1 - |A(T) - B(T)|$ — Coexistence functional
- $A(T)$ — AFM (low-manifold) component (0 ≤ A ≤ 1)
- $B(T)$ — FM (high-manifold) component (0 ≤ B ≤ 1)
- $a$ — Amplitude scaling
- $b$ — Offset correction

**Interpretation:**
- $C(T) = 1$ when $A = B$ (phases coexist)
- $C(T) = 0$ when $|A - B| = 1$ (phases separate)

### Coexistence Parameter λ

Controls mixing strength in coexistence formula:

**λ < 0.3:** AFM-dominated
- Memory component dominates
- Sharp dip in ΔM(T)
- Example: Low-disorder spin glass

**0.3 < λ < 0.7:** Mixed regime
- Significant contributions from both
- Both dip and step visible
- Example: Typical MgBr₂

**λ > 0.7:** FM-dominated
- Ferromagnetic response dominates
- Broad step in ΔM(T)
- Example: High disorder or large field

---

## Integration Checklist

**Before running Main_Aging:**
- [x] physics_context.txt output directory will be created
- [x] diagnostic_summary.txt will include physics fields
- [x] No additional configuration needed
- [x] Works with existing cfg structure

**After running Main_Aging:**
- [x] Check `diagnostics/physics_context.txt` for physics summary
- [x] Check `diagnostics/diagnostic_summary.txt` for metrics
- [x] Check `diagnostics/diagnostic_log.txt` for execution details

---

## Backward Compatibility

✓ All additions are **additive** — no breaking changes
✓ Existing pipeline logic **preserved**
✓ Optional physics extraction — graceful degradation if fields missing
✓ dbgSummaryTable still works with old-style key-value calls
✓ No changes to cfg.switchingMetricMode or reconstruction algorithm

---

## For Developers

### Adding New Physics Fields

**In dbgExtractPhysicsContext.m:**
```matlab
function physicsContext = dbgExtractPhysicsContext(cfg, result, state)
    % Existing fields...
    
    % Add new field
    if isfield(cfg, 'mynewparam')
        physicsContext.mynewparam = cfg.mynewparam;
    else
        physicsContext.mynewparam = NaN;  % Handle missing
    end
end
```

**In dbgSummaryPhysics.m:**
```matlab
% Add section explaining the field
fprintf(fid, '\n  My New Parameter:  %.4f\n', physicsContext.mynewparam);
fprintf(fid, '    → Physical interpretation here\n');
```

**In Main_Aging.m:**
```matlab
dbgSummaryTable(cfg, ...
    '=== MY SECTION ===', '', ...
    'my_new_param', physicsContext.mynewparam, ...
);
```

---

## Troubleshooting Integration

**Problem:** physics_context.txt not created

**Solution:**
1. Check `dbgInitDiagnostics` is called in Main_Aging
2. Verify `diagnostics/` folder exists and is writable
3. Check cfg.outputFolder is valid

**Problem:** Fields show "N/A" or NaN

**Solution:**
1. Verify cfg contains required fields (Tsw, switchParams, current_mA)
2. Check state.pauseRuns is populated
3. Verify result.R_squared etc are not NaN

**Problem:** Metrics don't match expected values

**Solution:**
1. Check cfg.switchingMetricMode matches analysis
2. Verify temperature grid cfg.Tsw is as expected
3. Confirm result is from stage7 (not intermediate)

---

## Summary

The physics context integration adds **three new functions** that automatically extract and format physical metadata from the reconstruction pipeline, enabling human-readable diagnostics accessible without MATLAB.

**Data flow:**
```
cfg → dbgExtractPhysicsContext() → physicsContext
↓                                      ↓
result                        dbgSummaryPhysics() → physics_context.txt
↓                                      ↓
state ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┴─ ─ ─ ─ → diagnostic_summary.txt
```

**Result:** Complete physical context in plain text files for archival, collaboration, and publication.

