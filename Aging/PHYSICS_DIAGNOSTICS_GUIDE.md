# Physics Context Diagnostics - User Guide

## Overview

The Aging pipeline now automatically generates comprehensive physics context summaries that allow any physicist to understand the reconstruction **without opening MATLAB**.

Three diagnostic files are automatically created:

1. **`physics_context.txt`** — Human-readable physics summary
2. **`diagnostic_summary.txt`** — Structured metrics table
3. **`diagnostic_log.txt`** — Complete execution log

---

## Example: physics_context.txt

```
╔════════════════════════════════════════════════════════════════╗
║         AGING SPIN-GLASS RECONSTRUCTION EXPERIMENTAL LOG        ║
╠════════════════════════════════════════════════════════════════╣

Generated: 2026-03-04 14:32:15

┌─ SAMPLE INFORMATION ────────────────────────────────────────────┐
  Sample:          MG119
  Dataset:         MG119_60min
└────────────────────────────────────────────────────────────────┘

┌─ EXPERIMENTAL CONFIGURATION ────────────────────────────────────┐
  Primary Current:         35.0 mA
  Available Currents:      [15, 20, 25, 30, 35, 45] mA
  Pause Runs:              8
  Pause Temperatures:      [6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0] K
└────────────────────────────────────────────────────────────────┘

┌─ RECONSTRUCTION TEMPERATURE GRID ───────────────────────────────┐
  Temperature Range:       4.00 – 34.00 K
  Total Range:             30.00 K
  Grid Points:             16
  Fit Window:              10.00 – 32.00 K
  Metric Mode:             direct
└────────────────────────────────────────────────────────────────┘

┌─ RECONSTRUCTION RESULTS ────────────────────────────────────────┐
  Coexistence Parameter λ:  0.6234
    → Governs mixing between AFM and FM
    → Lower λ: AFM-dominated, Higher λ: FM-dominated

  Reconstruction Coeff. a:  1.2456
    → Amplitude scaling for reconstruction

  Reconstruction Coeff. b: -0.0123
    → Offset correction in reconstruction

  Fit Quality (R²):         0.9876
    → Excellent fit (98.76% variance explained)
└────────────────────────────────────────────────────────────────┘

┌─ DECOMPOSITION BASIS FUNCTIONS ─────────────────────────────────┐
  The reconstruction decomposes Rsw(T) as:
  
    Rsw(T,J) ≈ a · C(T) + b
    
  where C(T) is the coexistence functional:
    
    C(T) = 1 - |A(T) - B(T)|
    
  Components:
    A(T) = AFM basis  (low-manifold dip, 0→1)
    B(T) = FM basis   (high-manifold step, 0→1)
  
  Alternative mechanisms compared:
    • Overlap:      M_overlap = A(T) × B(T)
    • Coexistence:  M_coex    = 1 - |A(T) - B(T)|
    • Dominance:    M_dom     = 1 - A(T)
└────────────────────────────────────────────────────────────────┘

┌─ MEASUREMENT CONFIGURATION ─────────────────────────────────────┐
  AFM metric:      Area of ΔM(T) dip (direct extraction)
  FM metric:       Plateau step in ΔM(T) (high-T magnitude)
  Switching Data:  Measured R(T) at applied current
  Aging Memory:    Analyzed via ΔM = M(pause) - M(no-pause)
└────────────────────────────────────────────────────────────────┘

╚════════════════════════════════════════════════════════════════╝
```

---

## Example: diagnostic_summary.txt

```
╔══════════════════════════════════════════════════════════════╗
║        AGING PIPELINE DIAGNOSTIC SUMMARY                   ║
╠══════════════════════════════════════════════════════════════╣

Generated: 2026-03-04 14:32:15

=== SAMPLE & DATASET ===
─────────────────────────────────────────────────────────────

  sample_name                              : MG119
  dataset_name                             : MG119_60min

=== EXPERIMENTAL SETUP ===
─────────────────────────────────────────────────────────────

  reference_current_mA                     : 35.0000
  available_currents_mA                    : [15 20 25 30 35 45]
  n_pause_runs                             : 8

=== TEMPERATURE GRID ===
─────────────────────────────────────────────────────────────

  temperature_min_K                        : 4.0000
  temperature_max_K                        : 34.0000
  temperature_range_K                      : 30.0000
  n_temperature_points                     : 16
  fit_window_min_K                         : 10.0000
  fit_window_max_K                         : 32.0000

=== RECONSTRUCTION RESULTS ===
─────────────────────────────────────────────────────────────

  reconstruction_mode                      : direct
  coexistence_parameter_lambda             : 0.6234
  reconstruction_coeff_a                   : 1.2456
  reconstruction_coeff_b                   : -0.0123
  fit_quality_R2                           : 0.9876

=== PIPELINE EXECUTION ===
─────────────────────────────────────────────────────────────

  pause_runs                               : 8
  figures_created                          : 3
  output_folder                            : /results/MG119_60min

╚══════════════════════════════════════════════════════════════╝
```

---

## Field Descriptions

### Sample Information

| Field | Meaning |
|-------|---------|
| **sample_name** | Material identifier (e.g., MG119) |
| **dataset_name** | Experiment identifier with wait time |

### Experimental Configuration

| Field | Meaning | Unit |
|-------|---------|------|
| **reference_current_mA** | Primary measurement current | mA |
| **available_currents_mA** | All measured currents (for multi-J fits) | mA |
| **n_pause_runs** | Number of thermoremanent magnetization cycles | count |
| **pause_temperatures_K** | Temperatures at which aging pauses occurred | K |

### Temperature Grid

| Field | Meaning | Unit |
|-------|---------|------|
| **temperature_min_K** | Lowest temperature measured | K |
| **temperature_max_K** | Highest temperature measured | K |
| **temperature_range_K** | Total temperature span | K |
| **n_temperature_points** | Resolution of reconstruction grid | count |
| **fit_window_min_K** | Lowest temperature used in fit | K |
| **fit_window_max_K** | Highest temperature used in fit | K |

### Reconstruction Results

| Field | Meaning | Range | Interpretation |
|-------|---------|-------|-----------------|
| **reconstruction_mode** | Metric extraction method | direct/model | How AFM/FM extracted from ΔM |
| **coexistence_parameter_λ** | Mixing strength between AFM and FM | 0.0–1.2 | Higher: FM-dominated |
| **reconstruction_coeff_a** | Amplitude scaling | scalar | Converts normalized basis to Rsw |
| **reconstruction_coeff_b** | Offset correction | scalar | Baseline adjustment |
| **fit_quality_R²** | Goodness of fit | 0.0–1.0 | >0.95: Excellent, >0.90: Good |

### Decomposition Basis Functions

The reconstruction model decomposes the measured switching amplitude:

$$R_{sw}(T, J) \approx a \cdot C(T) + b$$

where $C(T)$ is the **coexistence functional**:

$$C(T) = 1 - |A(T) - B(T)|$$

**Components:**
- $A(T)$ = AFM basis (low-manifold dip), normalized to [0,1]
- $B(T)$ = FM basis (high-manifold step), normalized to [0,1]

**Physical Interpretation:**
- When $A \approx B$: Both mechanisms active (coexistent)
- When $A \ll B$: FM-dominated regime
- When $A \gg B$: AFM-dominated regime

---

## Alternative Mechanisms

The reconstruction tests three switching mechanisms:

### 1. Overlap Mechanism
$$M_{overlap}(T) = A(T) \times B(T)$$

**Meaning:** Multiplicative coupling; both must be active  
**Interpretation:** Suggests independent cooperative switching

### 2. Coexistence Mechanism (Default)
$$M_{coex}(T) = 1 - |A(T) - B(T)|$$

**Meaning:** Linear distance metric; measures how well phases align  
**Interpretation:** Competing mechanisms in same material

### 3. Dominance Mechanism
$$M_{dom}(T) = 1 - A(T)$$

**Meaning:** FM preference; AFM acts as inhibition  
**Interpretation:** One phase suppresses the other

---

## Physical Context for Experimentalists

### Aging Memory (ΔM)

The aging memory is measured as:
$$\Delta M(T) = M_{pause}(T) - M_{no-pause}(T)$$

where:
- $M_{pause}$ = Magnetization after waiting at pause temperature $T_p$
- $M_{no-pause}$ = Reference magnetization without pausing

The dip in ΔM(T) around $T_p$ indicates memory of the thermal history.

### AFM vs FM Extraction

| Aspect | AFM (Dip) | FM (Step) |
|--------|-----------|----------|
| **Temperature** | Local dip near $T_p$ | High-T plateau |
| **Magnitude** | Area under dip | Step height |
| **Normalization** | [0,1] per pause | [0,1] overall |
| **Physical meaning** | Spin-glass memory | Ferromagnetic step |

### Fitting Window

The fit window typically excludes:
- **Low temperatures:** Noise and measurement artifacts
- **High temperatures:** Far from spin-glass transition

Example: 10–32 K for MG119 samples

---

## How to Read the Diagnostics

### For Quick Overview

1. Open `physics_context.txt` in a text editor
2. Check:
   - Sample and dataset name
   - Reference current and temperature range
   - R² value (fit quality)

### For Detailed Analysis

1. Read `diagnostic_summary.txt` for metrics table
2. Check section headers to understand context
3. Compare R² and λ values across measurements

### For Full Debugging

1. Open `diagnostic_log.txt` for complete execution trace
2. Search for "summary" for key milestones
3. Search for "full" for detailed diagnostics

---

## Interpreting R² Values (Fit Quality)

| R² Range | Interpretation | Action |
|----------|-----------------|--------|
| > 0.95   | Excellent fit | Use results with confidence |
| 0.90–0.95 | Good fit | Results valid, minor discrepancies |
| 0.80–0.90 | Fair fit | Check for systematic issues |
| < 0.80   | Poor fit | Investigate reconstruction parameters |

---

## Interpreting λ Values (Coexistence)

| λ Range | Interpretation |
|---------|-----------------|
| < 0.3   | AFM-dominated; FM minimal |
| 0.3–0.7 | Mixed regime; both mechanisms |
| > 0.7   | FM-dominated; AFM secondary |

---

## When Something Seems Wrong

### High R² but unusual λ
- Check temperature range coverage
- Verify pause temperature synchronization
- Examine individual pause curves

### Multiple measurements (multi-J)
- Compare λ across different currents
- Look for current-dependent trends
- Check for systematic offsets

### Low R² (< 0.80)
- Verify data quality and noise levels
- Check for outlier pause points
- Review exclusion criteria (Tp_exclude)

---

## Complete File Structure

```
outputFolder/
  diagnostics/
    ├── physics_context.txt          ← Human-readable summary
    ├── diagnostic_summary.txt       ← Structured metrics
    ├── diagnostic_log.txt           ← Complete execution trace
    ├── *.png                        ← Plots (if enabled)
    └── baseline_resultsLOO.mat      ← Data export (MATLAB)
```

---

## Using This Information

### For Publications
- Copy **physics_context.txt** sections into Methods
- Reference R² and λ values in Results
- Include temperature ranges and pause times

### For Collaboration
- Share all three .txt files with colleagues
- No MATLAB needed to interpret
- Self-contained experimental documentation

### For Archival
- Save diagnostics folder with raw data
- Enables future re-analysis without recomputation
- Serves as permanent experimental log

---

## Next Steps

After reviewing diagnostics:

1. **Look at plots** (if `plotVisible="on"`)
   - Verify dip/step separation in ΔM
   - Check fit quality in main plot
   - Inspect basis functions A(T) and B(T)

2. **Compare with literature**
   - Check λ values against previous measurements
   - Compare R² with literature fits

3. **Adjust if needed**
   - Modify `cfg.switchParams.fitTmin/fitTmax` if fit quality poor
   - Adjust `cfg.debug.keyPlotTags` for different analysis focus

---

## Questions?

Refer to:
- `Aging/DEBUG_INFRASTRUCTURE_GUIDE.md` for system details
- `Aging/QUICK_REFERENCE.md` for configuration options
- Individual function help: `help dbgExtractPhysicsContext`

