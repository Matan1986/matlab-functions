# ✅ FEATURE: Paper Layout Width Calculator

## Overview
Added a simple, focused width calculator to specify how many paper figures go across the article width and automatically compute the figure window width for exact journal column fit.

## Implementation Details

### UI Addition
**New Panel: "Paper Layout Width Calculator"** (Row 3)
- **Column mode dropdown:** Single column / Double column
- **Figures across field:** 1-5 (numeric field with limits)
- **Apply Paper Width button:** Triggers calculation

### Location
Inserted as Row 3 (between Figure Size and Axes Size panels)
- Figure Size: Row 2
- **Paper Layout Width: Row 3** ← NEW
- Axes Size: Row 4 (was Row 3)
- Appearance: Row 5 (was Row 4)
- Typography: Row 7 (was Row 6)
- Advanced: Row 8 (was Row 7)

### Calculation Logic
```
targetColumnWidth = singleColWidth (3.375 in) or doubleColWidth (7.0 in)
figureWidthInches = targetColumnWidth / figuresAcross
figureWidthPixels = figureWidthInches × screenDPI
Update hFigWidth.Value = round(figureWidthPixels)
Height Unchanged
```

**Key Points:**
- Width ONLY — height stays manual (user controlled)
- NOT subplot logic — for final exported paper figures
- Uses APS/PRL standard widths
- Automatic DPI conversion via `get(0, 'ScreenPixelsPerInch')`

### Function Implementation
**applyPaperWidth()** callback:
1. Gets column mode (Single/Double)
2. Gets figures across (1-5)
3. Selects column width (3.375" or 7.0")
4. Divides by figures across
5. Converts to pixels using screen DPI
6. Updates hFigWidth.Value
7. Prints feedback

### Preferences Integration
**Saves:**
- `PaperColMode` — Column mode selection
- `PaperFigsAcross` — Number of figures

**Loads:**
- Restores previous settings on UI startup
- Falls back to defaults if missing

**Defaults:**
- Column mode: 'Single column'
- Figures across: 1
- (Restored in Reset All button)

## Usage Example

**Scenario:** User wants to fit 2 paper figures across a double-column journal article

1. Launch FinalFigureFormatterUI
2. In "Paper Layout Width Calculator" section:
   - Column mode: Select "Double column"
   - Figures across: Enter "2"
   - Click "Apply Paper Width"
3. Result:
   - Figure Width updated to: 336 px (3.5 inches)
   - Height unchanged (user sets separately)
4. User still controls:
   - Axes position/size (normalized)
   - Fonts, colors, line styles
   - Height (separate from width calculator)
5. Export figure → Exact journal column fit

## Test Results

All calculation tests pass:

```
TEST 1: Single column, 1 fig:    3.375 in = 324 px     ✓
TEST 2: Single column, 2 figs:   1.688 in = 162 px     ✓
TEST 3: Double column, 1 fig:    7.000 in = 672 px     ✓
TEST 4: Double column, 2 figs:   3.500 in = 336 px     ✓
TEST 5: Double column, 3 figs:   2.333 in = 224 px     ✓
```

## Technical Notes

1. **No SmartFigureEngine involvement** — Pure calculation only
2. **No automatic layout logic** — Just width, NOT height or geometry
3. **No global state changes** — Self-contained feature
4. **Clean separation** — Paper layout ≠ subplot layout
5. **Backward compatible** — Existing functionality unchanged

## Code Quality

- ✅ No syntax errors
- ✅ All variables properly defined
- ✅ Defensive range clamping (1-5 figures)
- ✅ Screen DPI awareness
- ✅ Clear user feedback (fprintf output)
- ✅ Preferences integrated
- ✅ Reset/defaults work properly

## Files Modified

1. **FinalFigureFormatterUI.m**
   - Added Paper Layout Width panel (Row 3)
   - Added UI controls: hColMode, hFigsAcross, btnPaperWidth
   - Added applyPaperWidth() function
   - Updated panel row numbers (3→4, 4→5, 6→7, 7→8)
   - Updated preferences save/load
   - Updated restore defaults

2. **test_paper_width_calculator.m** (new)
   - Validates all calculation scenarios
   - Tests math correctness
   - Verifies DPI conversion

## Design Philosophy

**"Explicit, focused, minimal"**
- One clear purpose: calculate width for journal columns
- Doesn't touch anything else
- User still controls height, axes, fonts, colors
- No hidden logic, no smart behavior
- Just a helper for a common workflow

---

**Status**: ✅ Ready for use

This feature integrates seamlessly with the pure manual mode architecture and provides a useful shortcut for users publishing in physics journals with standard column widths.
