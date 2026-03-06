# Robust Baseline Implementation - Quick Reference

## 🎯 What This Does

Provides a **robust, scan-temperature-based baseline estimation** for Aging memory measurements.

**Key advantage**: Selects baseline windows based on actual measurement temperatures (T) rather than pause-temperature offsets, ensuring baseline points are always within the measurement range and don't overlap with the dip region.

---

## 🚀 Quick Start

### Option A: Auto-Discovery (Recommended)
```matlab
cd c:\Dev\matlab-functions\Aging
verifyOnRealData()   % Automatically finds data and runs verification
```

### Option B: Manual Setup
```matlab
% Setup configuration
cfg = agingConfig('MG119_60min');
cfg.dataDir = 'C:\Your\Data\Path';
cfg.useRobustBaseline = true;       % Enable robust baseline

% Run pipeline
state = Main_Aging(cfg);

% View results
open('REAL_DATA_VERIFICATION_REPORT.txt')
```

---

## 📊 What Gets Computed

For each pause run:
1. **Dip location** (Tmin) - where the magnetization dips
2. **Plateau windows** - left and right regions away from the dip
3. **Baseline values** - median of plateau points
4. **Baseline slope** - linear fit between plateaus
5. **Diagnostics** - stored in `pauseRuns(i)` struct

### Output Fields in pauseRuns(i)
```
.FM_step_mag          - Plateau step (baseR - baseL)
.baseline_slope       - Slope of linear baseline (response/K)
.baseline_TL          - Temperature of left plateau
.baseline_TR          - Temperature of right plateau
.baseline_status      - 'ok' or error code
```

---

## ✅ How to Verify It Works

### Run Real Data Verification
```matlab
verifyOnRealData()
```

**Look for console output**:
```
STEP 5a) DIP LOCATION: ✓ 100.0% within tolerance
STEP 5b) PLATEAU SEPARATION: ✓ 100.0% properly separated
STEP 5c) AGING GROWTH: Tp=4.0 K: ρ = 0.842 (p=0.0001, n=6) ✓
STEP 5d) FM STABILITY: Tp=4.0 K: rel_var=4.1% ✓
STEP 5e) BASELINE DRIFT: Tp=4.0 K: ρ = 0.123 (p=0.78, n=6) ✓ STABLE

✓✓✓ ROBUST BASELINE STABLE - NO ISSUES DETECTED ✓✓✓
```

**Success = All checks marked ✓**

---

## 🛠️ Configuration Options

```matlab
cfg.useRobustBaseline = true/false    % Enable/disable feature

% Tuning (if needed):
cfg.dip_margin_K = 2                  % Gap around dip (default: 2 K)
cfg.plateau_nPoints = 6               % Points per plateau (default: 6)
cfg.dropLowestN = 1                   % Drop edge points (default: 1)
```

---

## 📈 Expected Results

On real data, expect:
- ✓ **Dip location**: |Tmin - Tp| < 2 K (typically < 1 K)
- ✓ **Aging correlations**: ρ > 0.6-0.8 (positive growth)
- ✓ **FM stability**: <30% relative variation (typically 5-15%)
- ✓ **Baseline drift**: |ρ| < 0.5 (stable, no instrumental drift)

---

## ⚠️ Warning Signs

| Warning | Meaning | Fix |
|---------|---------|-----|
| Dip location > 2 K | Poor fit/data quality | Check data quality |
| Plateau overlap | Dip margin too small | Increase `dip_margin_K` |
| Baseline drift ρ > 0.7 | Instrumental temperature drift | Investigate temperature calibration |
| >10% NaN values | Not enough plateau points | Reduce `plateau_nPoints` or increase `dip_margin_K` |

---

## 📂 Files Generated

After running `verifyOnRealData()`:

```
REAL_DATA_VERIFICATION_REPORT.txt         - Detailed diagnostics table
RealData_Verification_Tp_4.0K.png         - ΔM plots for Tp=4.0 K
RealData_Verification_Tp_6.0K.png         - ΔM plots for Tp=6.0 K
... (more for other Tp values)
```

---

## 🔍 Understanding the New Metric: Baseline Drift

**What it checks**: Does the baseline systematically change during the measurement series?

**How**: Computes Spearman correlation between `wait_time` and `baseline_slope`

**Interpretation**:
- **|ρ| < 0.3**: ✓ Stable baseline (good)
- **0.3 < |ρ| < 0.5**: ⚠ Mild drift (acceptable)
- **|ρ| > 0.7**: ⚠⚠ Strong drift (investigate)

**Why it matters**: Strong baseline drift could mask or mimic aging growth

---

## 💾 Integration with Main_Aging

The robust baseline is **seamlessly integrated**:

1. Enable in config: `cfg.useRobustBaseline = true`
2. Pipeline automatically uses it in Stage 4
3. Results stored in `pauseRuns(i)` struct
4. Backward compatible (old method still available)

---

## 🎯 Deployment Steps

1. **Setup Data** → Edit `runs/localPaths.m` to point to your data
2. **Verify** → Run `verifyOnRealData()` and check results
3. **Review** → Look at generated `.txt` and `.png` files
4. **Deploy** → Set `cfg.useRobustBaseline = true` in production configs

---

## 📞 Help

**Error message: "No real Aging data found"**
```matlab
% Edit runs/localPaths.m and set:
paths.dataRoot = 'C:\Your\Measurement\Data'
```

**Error message: "Insufficient plateau points"**
```matlab
% Adjust configuration:
cfg.dip_margin_K = 3          % Increase from 2
cfg.plateau_nPoints = 4       % Reduce from 6
```

**Error message: "Plateau overlap dip"**
```matlab
% Increase dip margin:
cfg.dip_margin_K = 3
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| `REAL_DATA_SETUP_GUIDE.md` | Setup & troubleshooting |
| `ROBUST_BASELINE_IMPLEMENTATION_SUMMARY.md` | Full overview |
| `DEPLOYMENT_CHECKLIST.md` | Deployment steps |
| This file | Quick reference |

---

## ✨ Key Features

✓ **Scan-based selection** - Uses actual T values, not offsets  
✓ **Always in range** - Guaranteed [min(T), max(T)]  
✓ **No dip overlap** - Configurable margin prevents collision  
✓ **Robust aggregation** - Median handles outliers  
✓ **Backward compatible** - Old method still available  
✓ **Unified code** - Debug & production use same algorithm  
✓ **Full diagnostics** - Baseline slope, ranges, point counts  
✓ **Drift detection** - New metric for instrumental stability  

---

**Status**: ✅ READY TO USE  
**Next**: Run `verifyOnRealData()` on your measurement data
