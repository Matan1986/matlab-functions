# Real Data Verification Setup Guide

## Overview

The robust baseline implementation verification requires **REAL Aging measurement data** (actual .dat files), not synthetic data. This guide explains how to set up your measurement data for verification.

## 1. Data Requirements

### Required Format
- **File type**: `.dat` measurement files from Aging experiments
- **Structure**: Standard PPMS/MPMS output format or processed aging measurement format
- **Content**: Temperature-dependent magnetization data (ΔM vs T) for multiple pause times

### Expected Data Organization
```
[dataRoot]/
└── MG 119/
    └── MG 119 M2 out of plane Aging no field/
        └── high res 60min wait/          # or 6min wait, etc.
            ├── scan_Tp_4.0K_t_wait_1_60min.dat
            ├── scan_Tp_6.0K_t_wait_1_60min.dat
            ├── scan_Tp_8.0K_t_wait_1_60min.dat
            ├── scan_Tp_4.0K_t_wait_2_60min.dat
            └── ... (multiple pause temperatures and wait times)
```

### What Each File Should Contain
Each `.dat` file contains measurements at a specific pause temperature and wait time:
- **Column 1**: Temperature (K)
- **Column 2**: Magnetization or ΔM (arbitrary units)
- Multiple rows for each temperature point during the T-sweep

### Key quantities (extracted by pipeline)
- **Tp** (pause temperature in K): Extracted from filename (e.g., "Tp_4.0K")
- **t_wait** (pause duration): Extracted from filename (e.g., "60min")
- **T_scan** (actual scan temperatures): Read from measurement file
- **ΔM(T)**: The measured response curve

## 2. Configuration Setup

### Step 1: Create `localPaths.m`

If not already present, create `runs/localPaths.m` on your system:

```matlab
function paths = localPaths()
% LOCALPATHS - Machine-specific path configuration
% 
% Copy this from localPaths_example.m and customize for your system

% Set dataRoot to your measurement data location:
paths.dataRoot = 'L:\Your\Data\Path';  % e.g., 'C:\Data' or network drive

% Output folder for results:
paths.outputRoot = fullfile('C:\Dev\matlab-functions', 'outputs');

end
```

### Step 2: Point to Your Data

Edit `runs/localPaths.m` to set `dataRoot` to where your real Aging data is stored.

**Examples:**
- Windows local drive: `'C:\Data'`
- Network drive: `'L:\Shared\Measurements'`
- Home directory: `'~/measurements'`

The full data path will be constructed as:
```
[dataRoot]/MG 119/MG 119 M2 out of plane Aging no field/high res 60min wait/
```

### Step 3: Verify Data Exists

```matlab
>> cfg = agingConfig('MG119_60min');
>> cfg.dataDir

% Should output: 
% L:\Your\Data\Path\MG 119\MG 119 M2 out of plane Aging no field\high res 60min wait\

>> dir(cfg.dataDir)  % Should list .dat files
```

If you see `.dat` files listed, you're ready to verify!

## 3. Running the Real Data Verification

### Option A: Automatic Discovery (Recommended)

```matlab
cd c:\Dev\matlab-functions\Aging
verifyOnRealData()
```

This will:
1. Search standard data locations automatically
2. Load real .dat files via the Main_Aging pipeline
3. Extract diagnostics from all pause runs
4. Run physics checks (dip location, plateau separation, aging growth, baseline stability)
5. Compute baseline drift correlation (new metric)
6. Generate plots and save reports

### Option B: Manual Configuration

```matlab
cd c:\Dev\matlab-functions
cfg = agingConfig('MG119_60min');
cfg.dataDir = 'C:\Path\To\Your\Data';  % Override if needed
cfg.useRobustBaseline = true;
cfg.dip_margin_K = 2;
cfg.plateau_nPoints = 6;

% Run pipeline
state = Main_Aging(cfg);

% Then verify
verifyOnRealData()
```

### Option C: Direct Pipeline Call

```matlab
cd c:\Dev\matlab-functions\Aging\verification
verifyRobustBaseline_RealData_Main()
```

## 4. Expected Output

### Console Output
The verification script will print:

```
╔════════════════════════════════════════════════════════════════╗
║  ROBUST BASELINE VERIFICATION - REAL AGING DATA               ║
╚════════════════════════════════════════════════════════════════╝

SETUP: Locating real Aging data directory
───────────────────────────────────────────────────────────────
✓ Found data directory: L:\My Drive\...\high res 60min wait\
  Contains 48 .dat files

STEP 1: Configuring pipeline for robust baseline
───────────────────────────────────────────────────────────────
...

STEP 4: Extracting diagnostics from pauseRuns
───────────────────────────────────────────────────────────────
Diagnostics table (48 total runs):
  RunID    Tp  WaitTime   Tmin  DipArea   FM_step  BaselineSlope  Status
    1      4.0    60       4.05   1.23e-3   5.6e-5    0.0012       ok
    2      4.0   120       4.12   1.45e-3   5.2e-5    0.0008       ok
...

STEP 5: Physics sanity checks on REAL pauseRuns
───────────────────────────────────────────────────────────────

5a) DIP LOCATION (|Tmin - Tp| < 2 K):
    ✓ 100.0% within tolerance

5b) PLATEAU SEPARATION (no overlap with dip):
    ✓ 100.0% properly separated

5c) AGING GROWTH (Spearman correlation per Tp):
    Computing correlation(wait_time, Dip_area) for each pause temperature...

    Tp=4.0 K: ρ = 0.842 (p=0.0001, n=6) ✓
    Tp=6.0 K: ρ = 0.753 (p=0.0023, n=6) ✓
    ...

5d) FM BASELINE STABILITY (relative variation per Tp):
    Tp=4.0 K: mean=5.4e-5, std=2.2e-6, rel_var=4.1% ✓
    Tp=6.0 K: mean=5.1e-5, std=3.1e-6, rel_var=6.1% ✓
    ...

5e) BASELINE DRIFT (correlation between wait_time and baseline_slope):
    Tp=4.0 K: ρ(wait_time, slope) = 0.123 (p=0.78, n=6) ✓ STABLE
    Tp=6.0 K: ρ(wait_time, slope) = 0.034 (p=0.95, n=6) ✓ STABLE
    ...

STEP 6: Summary statistics
───────────────────────────────────────────────────────────────
✓ Valid runs (status="ok"): 48/48 (100.0%)
  NaN in FM_step: 0/48
  NaN in Dip_area: 0/48

STEP 7: Plateau temperature ranges (by Tp)
───────────────────────────────────────────────────────────────

STEP 8: Generating diagnostic plots
───────────────────────────────────────────────────────────────
  Plotting Tp=4.0 K...
    ✓ Saved: RealData_Verification_Tp_4.0K.png
  Plotting Tp=6.0 K...
    ✓ Saved: RealData_Verification_Tp_6.0K.png

╔════════════════════════════════════════════════════════════════╗
║  FINAL VERIFICATION REPORT                                    ║
╚════════════════════════════════════════════════════════════════╝

✓✓✓ ROBUST BASELINE STABLE - NO ISSUES DETECTED ✓✓✓

Test complete. Generated 2 figures.
Report saved: REAL_DATA_VERIFICATION_REPORT.txt
```

### Generated Files
- `REAL_DATA_VERIFICATION_REPORT.txt` — Detailed diagnostics table and statistics
- `RealData_Verification_Tp_4.0K.png` — ΔM(T) curves for Tp=4.0 K
- `RealData_Verification_Tp_6.0K.png` — ΔM(T) curves for Tp=6.0 K
- (more figures for other Tp values)

## 5. Interpreting Results

### Success Criteria

✅ **Robust baseline is working correctly if:**

1. **✓ Dip location**: 100% of runs have |Tmin - Tp| < 2 K
2. **✓ Plateau separation**: 100% have proper separation from dip
3. **✓ Aging growth**: Positive Spearman correlations (ρ > 0.6) between wait_time and Dip_area per Tp
4. **✓ FM stability**: Relative variation < 30% (typical: 5-15%)
5. **✓ Baseline stability**: Low correlation (|ρ| < 0.5) between wait_time and baseline_slope
6. **✓ All/most runs status="ok"**: >95% of pauseRuns have baseline_status='ok'

### Warning Signals

⚠️ **Investigate if you see:**

- Dip location errors (|Tmin - Tp| > 2 K) → May indicate poor fit or data quality
- Plateau overlap → Check dip_margin_K configuration
- Negative aging correlation → Unexpected inverse Dip behavior
- Large FM variation (>30%) → Noise or baseline artifacts
- **Strong baseline drift** (|ρ| > 0.7) → Potential instrumental drift or scaling issue
- >10% NaN in diagnostics → May need parameter tuning

### Configuration Adjustments

If you see warnings, adjust these parameters in `verifyOnRealData()`:

```matlab
cfg.dip_margin_K = 2;          % Default. Try 1.5–3.0 if plateaus overlap
cfg.plateau_nPoints = 6;       % Default. Reduce if few points in plateaus
cfg.dropLowestN = 1;           % Default. Increase if edge noise is high
```

## 6. Troubleshooting

### Problem: "No real Aging data found"

**Solution:**
1. Check that `localPaths.m` exists in `runs/` folder
2. Verify `paths.dataRoot` points to your measurement data location
3. Ensure the data folder structure matches expected format:
   ```
   [dataRoot]/MG 119/MG 119 M2 out of plane Aging no field/high res 60min wait/
   ```

### Problem: "Stage 1 load failed" or "No .dat files found"

**Solution:**
1. Verify .dat files exist in data directory
2. Check filename format: should include `Tp_*_K` and `t_wait_*_60min` patterns
3. Run: `dir(cfg.dataDir)` to list files

### Problem: "All NaN in baseline diagnostics"

**Solution:**
1. Check that robust baseline is enabled: `cfg.useRobustBaseline = true`
2. Verify baseline_status field exists in pauseRuns
3. Check dip_margin_K isn't too large (limit: < 10 K)

### Problem: "Not enough points in plateaus"

**Solution:**
1. Increase temperature scan resolution in measurement protocol
2. Or reduce `cfg.plateau_nPoints` (minimum: 3)
3. Check `cfg.dip_window_K` isn't excluding valid plateau region

## 7. Advanced: Understanding the New Baseline Drift Check

The verification now includes **Step 5e: Baseline Drift**, which is a NEW diagnostic not previously validated:

**Purpose**: Detect whether baseline selection is changing systematically during the aging measurement series.

**What it measures**:
- Spearman correlation between `wait_time` (pause duration) and `baseline_slope` (slope of baseline line)
- Per pause temperature (to check for Tp-dependent drift)

**Interpretation**:
- **|ρ| < 0.3**: ✓ No drift — baseline stable across measurement time
- **0.3 < |ρ| < 0.5**: ⚠ Mild drift — may warrant investigation but usually OK
- **|ρ| > 0.7**: ⚠⚠ Strong drift — suggests instrumental temperature calibration drift or systematic baseline shift

**Physical meaning**:
- If drift is strong, it could indicate:
  - Temperature sensor calibration changing over measurement
  - Cryostat temperature control drift
  - Baseline shift masquerading as aging growth

## 8. Next Steps After Verification

Once the real data verification passes:

1. **Deploy to production**: Set `cfg.useRobustBaseline = true` as default
2. **Re-run all analyses**: With robust baseline on historical data
3. **Compare results**: Check how aging metrics change vs old method
4. **Update documentation**: Record baseline configuration in analysis notes

---

## Contact & Support

For questions about data format or verification procedure:
- Check `Main_Aging.m` for stage-by-stage debug output
- Enable verbose diagnostics: `cfg.debug.verbose = true`
- Check generated `REAL_DATA_VERIFICATION_REPORT.txt` for detailed diagnostics
