# Robust Baseline Integration - Data Flow & Architecture

## 🏗️ Overall Pipeline Architecture

```
Main_Aging.m (Entry point)
    ↓
[ Stage 0: Config & Paths ]
    ↓
[ Stage 1: Load .dat files ]  ← Real measurement data
    ↓
[ Stage 2: Preprocess ] (filter, align)
    ↓
[ Stage 3: Compute ΔM(T) ]
    ↓
┌─────────────────────────────────────────────────────────────────┐
│ [ Stage 4: Analyze AFM/FM Components ]                          │
│                                                                   │
│   if cfg.useRobustBaseline == true                               │
│   ├─→ estimateRobustBaseline() ← NEW ROBUST METHOD              │
│   │     • Auto-select plateau windows                           │
│   │     • Compute baseline from scan T                          │
│   │     • Return: slope, TL, TR, status                        │
│   │     • Store: baseline_* fields in pauseRuns(i)             │
│   └─→ FM_step_mag = baseline_plateau_step                      │
│   else                                                           │
│   └─→ Original Tp-dependent method (backward compat)           │
│       • Use fixed offset from Tp                               │
│       • Legacy behavior preserved                              │
└─────────────────────────────────────────────────────────────────┘
    ↓
[ Stage 5: Fit FM Gaussian ] (dip fitting)
    ↓
[ Stage 6: Extract Metrics ] (aging growth, etc.)
    ↓
[ Stage 7: Plots & Export ]
    ↓
Output: state.pauseRuns output files & plots
```

---

## 🔍 Robust Baseline Workflow (Detailed)

```
estimateRobustBaseline()
    ↓
INPUT: T (scan temps), Y (ΔM), Tmin (dip location), cfg
    ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 1: Define Dip Window                              │
│                                                         │
│  dipL = Tmin - dip_halfwidth     (e.g., 4.0 K)        │
│  dipR = Tmin + dip_halfwidth     (e.g., 6.0 K)        │
│  dip_window = [dipL, dipR]                            │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 2: Create Plateau Masks (Boolean)                 │
│                                                         │
│  plateauL_mask = T <= (dipL - margin)                 │
│  plateauR_mask = T >= (dipR + margin)                 │
│                                                         │
│  Example (Tp=5K, margin=2K):                          │
│  dipL=3K, dipR=7K                                     │
│  plateauL_mask = T <= 1K                              │
│  plateauR_mask = T >= 9K                              │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 3: Extract Plateau Points with Edge Handling      │
│                                                         │
│  idxL_all = find(plateauL_mask)                        │
│  idxL_trimmed = idxL_all(dropLowestN+1:end)          │
│  idxL = idxL_trimmed(end-N+1:end)  [last N points]   │
│                                                         │
│  idxR_all = find(plateauR_mask)                        │
│  idxR_trimmed = idxR_all(1:end-dropHighestN)         │
│  idxR = idxR_trimmed(1:N)  [first N points]          │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 4: Aggregate with Median (Robust)                 │
│                                                         │
│  baseL = median(Y(idxL))   ← Robust to outliers       │
│  baseR = median(Y(idxR))                               │
│  TL = mean(T(idxL))   ← Center of left plateau        │
│  TR = mean(T(idxR))   ← Center of right plateau       │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 5: Compute Linear Baseline                         │
│                                                         │
│  slope = (baseR - baseL) / (TR - TL)                   │
│  baseline = baseL + slope * (T - TL)                   │
│                                                         │
│  Output: Linear baseline vector covering all T         │
└─────────────────────────────────────────────────────────┘
    ↓
OUTPUT: Struct with baseline, slope, diagnostics, status
```

---

## 📊 Data Flow: Input → Output

```
Raw .dat File
    ↓
[ Load in Stage 1 ]
    ├─ T_common: [4.0, 4.2, 4.4, ..., 34.0] K
    ├─ DeltaM: [0.001, 0.0015, ..., 0.002]
    ├─ Tp: 5.0 K (pause temperature)
    └─ wait_time_min: 60 (pause duration)
    ↓
[ Preprocess: Filter & Align ]
    ↓
[ Compute ΔM(T) ]
    ↓
[ Stage 4: ROBUST BASELINE (if cfg.useRobustBaseline==true) ]
    ├─ Call: estimateRobustBaseline(T_common, ΔM, Tp, cfg)
    ├─ Input: T=[4.0, 4.2, ..., 34.0], Tmin≈5.0
    ├─ Select plateaus: T<3 and T>7 (with margin)
    ├─ Get plateau points: idxL=[10,11,12], idxR=[95,96,97]
    ├─ Compute: baseL=0.0012, baseR=0.0018, slope=0.00006
    └─ Output: baseline_vector, baseline_slope=0.00006
    ↓
[ Continue Stages: Fit FM Gaussian, Extract Metrics ]
    ↓
Store in pauseRuns(i):
    ├─ FM_step_mag = 0.0006
    ├─ baseline_slope = 0.00006
    ├─ baseline_TL = 2.5 K
    ├─ baseline_TR = 9.5 K
    ├─ baseline_status = 'ok'
    └─ ... (other fields)
    ↓
[ Verification: Compute Statistics ]
    ├─ Dip location check: |Tmin - Tp| = 0.05 K ✓
    ├─ Plateau separation check: OK ✓
    ├─ Aging growth: ρ = 0.85 ✓
    ├─ FM stability: 12% ✓
    └─ Baseline drift: ρ = 0.12 ✓
    ↓
Output: pauseRuns(i) with all diagnostics
```

---

## 🔀 Path Selection in Production

```
Main_Aging → Stage 4 (analyzeAFM_FM_components.m)
    ↓
Is cfg.useRobustBaseline == true?
    ├─ YES
    │   ├─ Call estimateRobustBaseline()
    │   ├─ Store: baseline_slope, baseline_TL, baseline_TR, baseline_status
    │   └─ Use: FM_step_mag from plateau step
    │
    └─ NO (default)
        ├─ Use original Tp-dependent method
        ├─ Store: FM_plateau_valid, FM_plateau_reason
        └─ Legacy behavior (unchanged)
```

---

## 📈 Plateau Selection Illustration

```
Temperature Scan (example, Tp=5.0K, dip_margin=2K):

ΔM(T)  │
  0.008├─────────
       │    ╱╲      ← DWELL at Tp (pause point)
  0.006├───╱  ╲    ╱─────
       │      ╲  ╱
  0.004├  ●  ●╱╲●  ●   ← Selected points (● shown)
       │        ╲
  0.002├  ●  ●  ╱╲●  ●
       │      ╱
  0.000├────
       └────┬────┬────┬────┬────┬────┬─────→ T (K)
         0  2    3    4    5    6    7    8  10

  Left Plateau (idxL):   T ≤ 3K (margin=2)     ← Selected 6 pts
  Dip Window:           T ∈ [3K, 7K]          ← EXCLUDED
  Right Plateau (idxR): T ≥ 7K (margin=2)     ← Selected 6 pts

  Baseline = baseL + slope * (T - TL)
           = 0.0020 + 0.00006 * (T - 2.5)
```

---

## 🛡️ Error Handling Flow

```
estimateRobustBaseline()
    ↓
Does config exist?
├─ No → Use defaults (dip_margin_K=2, plateau_nPoints=6, ...)
└─ Yes → Extract cfg.dip_margin_K, etc.
    ↓
Are T, Y, Tmin valid?
├─ No → status = 'invalid_input_dimensions' → RETURN
└─ Yes → Continue
    ↓
Can we find left plateau points?
├─ No → status = 'insufficient_left_points' → RETURN
└─ Yes → Continue
    ↓
Can we find right plateau points?
├─ No → status = 'insufficient_right_points' → RETURN
└─ Yes → Continue
    ↓
Do plateaus overlap with dip?
├─ Yes → status = 'plateau_overlap_dip' → RETURN
└─ No → Continue
    ↓
Are plateau values valid (finite)?
├─ No → status = 'aggregation_failed' → RETURN
└─ Yes → Continue
    ↓
Is plateau order valid (TL < TR)?
├─ No → status = 'invalid_plateau_order' → RETURN
└─ Yes → Continue
    ↓
Compute baseline and diagnostics
status = 'ok' ✓
RETURN with full diagnostics
```

---

## 🔗 Integration Points

### In analyzeAFM_FM_components.m (lines 227-284)

```matlab
if cfg.useRobustBaseline
    baselineOut = estimateRobustBaseline(T, dM, Tp, cfg_baseline);
    if status == 'ok'
        pauseRuns(i).FM_step_mag = baselineOut.baseR - baselineOut.baseL;
        pauseRuns(i).baseline_slope = baselineOut.slope;
        % ... store other diagnostics
    else
        pauseRuns(i).FM_step_mag = NaN;  % Failed, set to NaN
        pauseRuns(i).baseline_status = baselineOut.status;
    end
else
    % Original method (preserved for backward compatibility)
    ... (old code)
end
```

### In debugAgingStage4.m (lines 168-263)

```matlab
function [baseL, baseR, dip, fmPlateauL, fmPlateauR, baselineOut] = buildDebugWindows(T, Y, Tp, cfg)
    % Now calls estimateRobustBaseline directly (production logic)
    baselineOut = estimateRobustBaseline(T, Y, Tp, cfg_baseline);
    % Returns unified baseline for both debug & production
end
```

---

## 📊 What Gets Stored in pauseRuns

### Before (Old Method)
```matlab
pauseRuns(i).FM_step_mag         ← From fixed plateau window
pauseRuns(i).FM_plateau_valid    ← Boolean
pauseRuns(i).FM_plateau_reason   ← Error message
```

### After (New Method, if useRobustBaseline=true)
```matlab
pauseRuns(i).FM_step_mag         ← From robust baseline step
pauseRuns(i).baseline_slope      ← NEW: Slope of baseline line
pauseRuns(i).baseline_TL         ← NEW: Left plateau temperature
pauseRuns(i).baseline_TR         ← NEW: Right plateau temperature
pauseRuns(i).baseline_status     ← NEW: 'ok' or error code
pauseRuns(i).FM_plateau_valid    ← true if status='ok'
pauseRuns(i).FM_plateau_reason   ← '' if ok, or status string
```

---

## ✅ Verification Workflow

```
Real Data Available?
    ├─ Yes → Run verifyOnRealData()
    └─ No → See REAL_DATA_SETUP_GUIDE.md

verifyOnRealData()
    ├─ Step 1: Discover data directory
    ├─ Step 2: Run Main_Aging with cfg.useRobustBaseline=true
    ├─ Step 3: Extract diagnostics from pauseRuns
    ├─ Step 4: Run physics checks:
    │   ├─ 5a) Dip location
    │   ├─ 5b) Plateau separation
    │   ├─ 5c) Aging growth correlation
    │   ├─ 5d) FM stability
    │   └─ 5e) Baseline drift correlation
    ├─ Step 5: Summary statistics
    ├─ Step 6: Plateau ranges per Tp
    ├─ Step 7: Generate plots
    └─ Output:
        ├─ Console: Diagnostics table & correlations
        ├─ File: REAL_DATA_VERIFICATION_REPORT.txt
        └─ Plots: RealData_Verification_Tp_*.png

Review Results:
    ├─ Check console for ✓ marks
    ├─ Check report file for details
    ├─ Review plots for data quality
    └─ Decide: PASS ✓ or FAIL? → Adjust cfg if needed
```

---

## 🎯 Key Design Principles

| Principle | Benefit | Implementation |
|-----------|---------|----------------|
| **Scan-based** | Points always within measurement range | Use actual T values, not Tp offsets |
| **Separation** | No dip/plateau overlap | Configurable margin creates gap |
| **Robustness** | Handles outliers & noise | Use median aggregation + drop edges |
| **Backward Compat** | Existing code unchanged | Old method preserved in else block |
| **Unified Code** | Same logic everywhere | Debug calls production code |
| **Full Diagnostics** | Enables diagnosis & monitoring | Store slope, ranges, status, counts |
| **Drift Detection** | Identify instrumental issues | Correlate baseline_slope with wait_time |

---

## 📍 File Locations Summary

```
c:\Dev\matlab-functions\Aging\
├── utils/
│   └── estimateRobustBaseline.m          ← CORE HELPER
├── models/
│   └── analyzeAFM_FM_components.m        ← INTEGRATION (modified)
├── analysis/
│   └── debugAgingStage4.m                ← DEBUG (refactored)
├── tests/
│   └── testDipBaselinePR.m               ← REGRESSION TEST
├── verification/
│   ├── verifyOnRealData.m                ← MAIN VERIFICATION
│   ├── verifyRobustBaseline_Simple.m     ← SYNTHETIC CHECK
│   ├── verifyRobustBaseline_WithLogging.m ← SYNTHETIC + LOG
│   └── VERIFICATION_REPORT.md            ← SYNTHETIC RESULTS
├── REAL_DATA_SETUP_GUIDE.md              ← SETUP HELP
├── ROBUST_BASELINE_IMPLEMENTATION_SUMMARY.md ← OVERVIEW
├── DEPLOYMENT_CHECKLIST.md               ← DEPLOYMENT
├── QUICK_START.md                        ← QUICK REF
├── DELIVERY_SUMMARY.md                   ← THIS DELIVERY
└── ARCHITECTURE.md                       ← THIS FILE
```

---

**Architecture Summary**: Robust baseline implementation provides scan-based, margin-protected baseline estimation with full diagnostics, seamlessly integrated into Main_Aging pipeline with backward compatibility and unified debug/production code paths.
