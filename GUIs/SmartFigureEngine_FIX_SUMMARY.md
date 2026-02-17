# SmartFigureEngine Conceptual Model Correction - Fix Summary

**Date:** 2025-01-XX  
**Status:** ✅ All tests passing

## Problem Identified

SmartFigureEngine was treating the MATLAB figure window as representing the **entire article canvas** (all panels side-by-side), when it should represent **ONE PANEL** in the final article regardless of the number of subplots (nx/ny).

This caused:
1. Figure windows being resized to massive sizes (e.g., 7×2.6 inches for 2×1 layouts)
2. Incorrect margin calculations (margins scaled by nx/ny factors)
3. Label overflow calculations giving wrong values (150+ pixels instead of normalized)

## Corrected Conceptual Model

```
MATLAB Figure Window = ONE PANEL in final article
├─ nx × ny subplots fit WITHIN this single panel
├─ Figure.PaperSize = single panel dimensions (e.g., 3.5×2.6 inches)
├─ Figure window size is NEVER changed during UI formatting
└─ Only axes positions are adjusted to fit content
```

## Fixes Applied

### 1. getAxisLabelOverflow (Lines ~2835-2882)
**Issue:** Returned pixel values (150+) instead of normalized coordinates  
**Fix:** 
- Changed label Units to `'normalized'` before measuring Extent
- Converted axes-normalized coordinates to figure-normalized space
- Formula: `figCoord = axPos(i) + extent(i) * axDim(i)`

### 2. solveLabelOverflow (Lines ~2719-2833)
**Issue:** Applied nx/ny scaling to margins (treating figure as article)  
**Fix:**
- Removed all `* nx` and `* ny` scaling factors
- Direct mapping: `requiredLeftMargin = baseMargin + overflow + pad`
- Changed from 20-iteration solver to deterministic single-pass

### 3. applyFigureGeometry (Lines ~186-209)
**Issue:** Changed `fig.Units='inches'` causing window to resize  
**Fix:**
- Removed `fig.Units` modification (keeps pixels)
- Only sets paper properties: `PaperSize`, `PaperPosition`
- Added explicit comment: "NEVER resize figure window during UI formatting"

### 4. applyDeterministicGridGeometry (Lines ~1651-1668)
**Issue:** Divided margins by nx/ny (e.g., `leftMargin/nx`)  
**Fix:**
- Removed division: `leftMargin = style.leftMargin` (no `/nx`)
- Margins apply directly to the single-panel figure

### 5. getDataAxes (Lines ~1351-1425)
**Issue:** Manual legends were counted as data axes  
**Fix:**
- Enhanced tag-based filtering
- ANY tagged axis is excluded (including `Tag='manual'`)
- Only axes with empty `Tag` property are included

## Validation Results

✅ **Test 1:** Single panel with long labels  
   - No label clipping (overflow solver works)
   - Window size unchanged during formatting
   
✅ **Test 2:** Multi-panel layouts (2×1)  
   - Paper size = 3.5×2.6 inches (NOT 7×2.6)
   - Window size unchanged
   - Both panels fit within single panel dimensions
   
✅ **Test 3:** Manual legends  
   - Correctly excluded from geometry calculations
   - No corruption of axis positioning

## Architecture Notes

**Two-stage model:**
1. **UI Formatting Stage** (SmartFigureEngine)
   - Figure = one panel
   - Window size preserved (stays in pixels)
   - Only axes positions adjusted
   - Paper properties set for export

2. **Export/Save Stage** (future work)
   - Combine multiple figures into article layout
   - Expansion to nx×ny panels happens here, not in UI

**Key principle:** The figure window is a **preview** of what one panel will look like in the final article. Subplots within that figure are arranged to fit within that single panel's dimensions.

## Related Files
- `SmartFigureEngine.m` (3465 lines) - Main formatting engine
- `FinalFigureFormatterUI.m` (2172 lines) - GUI wrapper
- No changes needed to UI file

## Breaking Changes
None - behavior now matches user expectations. Previous behavior (resizing windows) was the bug.
