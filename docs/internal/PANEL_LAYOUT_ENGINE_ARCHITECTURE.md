# SmartFigureEngine: Journal Panel Layout Engine

## Executive Summary

**SmartFigureEngine is NOT a generic MATLAB figure formatter.**  
**It is a JOURNAL PANEL LAYOUT ENGINE for publication-ready scientific figures.**

This document explains the core conceptual architecture that differentiates this system from typical figure formatting tools.

---

## Core Identity: Panel-First Architecture

### Conceptual Hierarchy

```
Paper → Panels → Subpanels → Data
```

- **One MATLAB `figure()` = ONE paper panel** (e.g., Figure 1A, Figure 2B)
- **Subplots (nx×ny) = Internal subdivisions WITHIN that single panel**
- **NOT independent figures** that will be combined later into a multi-panel layout

### Example

**Correct interpretation:**
- Figure window with 2×2 subplot grid = **ONE panel** with four internal views
- Published as "Figure 2A" with four internal subplots

**WRONG interpretation** (typical formatters):
- Figure window with 2×2 grid = four separate panels A, B, C, D
- Will be "split" later into separate figures

---

## Three Architectural Pillars

### 1. Panel Intent (Editorial Decision)

**Problem:** Geometry alone cannot determine editorial meaning.

A figure with `nx=2, ny=2` subplots could be:
1. **Atomic:** ONE panel with four related views (stay together)
2. **Composite:** PREVIEW of four future panels (will be split)

Same geometry → Different editorial intent → Different typography

#### Atomic Panel Mode (`panelIntent = 'atomic'`)

- Figure represents **single journal panel** with internal subdivisions
- Subplots are related views within one conceptual unit
- **Typography:** Slightly reduced fonts for subplot clarity (0.92× scale)
- **Margins:** Shared margins optimized for unified panel
- **Labels:** Shared X/Y labels when appropriate
- **Legends:** Unified legend logic across subplots
- **Export:** Figure exported as-is as one panel

**Example:**  
Figure 2A showing `[time series | filtered | FFT]` as three horizontal subplots

#### Composite Panel Mode (`panelIntent = 'composite'`)

- Figure is **PREVIEW** of what will become multiple separate panels
- Each subplot represents a future independent journal panel
- **Typography:** FULL-SIZE fonts per subplot (NO reduction)
- **Margins:** Each subplot treated independently
- **Labels:** Independent labels per subplot
- **Legends:** Independent legend treatment
- **Export:** Figure will be split, each subplot becomes separate panel

**Example:**  
2×2 comparison grid exploring 4 samples side-by-side, later split into Figure 2A, 2B, 2C, 2D in final paper

#### Why This Matters

Without explicit `panelIntent`, the engine cannot distinguish:
- A 2×2 grid meant as **ONE integrated panel** (atomic) → reduce fonts
- A 2×2 grid meant as **FOUR future panels** (composite) → full fonts

**This is editorial intent, not a geometric property to be inferred.**

---

### 2. Page-Aware Layout (Physical Size Scaling)

**Problem:** Font size must match **actual printed panel size on journal page**, not MATLAB window size or subplot count.

#### Wrong Approach (Heuristic, Subplot-Aware)

```
"You have nx=2, ny=2 subplots, so reduce fonts by some heuristic factor"
```
- Ignores actual printed size
- Same subplot count looks different at different scales
- No connection to journal page layout

#### Correct Approach (Page-Aware)

```
"Journal column is 3.5" wide, 4 panels per row → 0.875" effective width per panel"
```
- Typography scales from **effective physical size** (0.875")
- Same visual result regardless of figure window size
- Matches actual journal layout

#### Key Parameters

| Parameter | Meaning |
|-----------|---------|
| `panelWidth` | Journal column width (NOT final panel size when `panelsPerRow > 1`) |
| `panelHeight` | Journal column height |
| `panelsPerRow` | How many panels horizontally on journal page |
| `panelsPerColumn` | How many panels vertically on journal page |
| `effectivePanelWidth` | **Computed:** `panelWidth / panelsPerRow` |
| `effectivePanelHeight` | **Computed:** `panelHeight / panelsPerColumn` |

Typography scales from **effective physical size**, NOT from subplot count.

#### Examples

**Example 1: Four panels in one row (small fonts)**
```matlab
computeSmartStyle(3.5, 2.6, 1, 1, 'PRL', 'atomic', 4, 1)
```
- Journal column: 3.5" × 2.6"
- Page layout: 4 panels per row, 1 row
- **Effective size: 0.875" × 2.6" per panel**
- Fonts scaled for **0.875" width (SMALL)**
- Result: Readable at actual printed size

**Example 2: Single large panel (large fonts)**
```matlab
computeSmartStyle(3.5, 2.6, 1, 1, 'PRL', 'atomic', 1, 1)
```
- Journal column: 3.5" × 2.6"
- Page layout: 1 panel per row, 1 row
- **Effective size: 3.5" × 2.6" (full column)**
- Fonts scaled for **3.5" width (LARGE)**
- Result: Same readability as Example 1 at printed size

**Example 3: 2×2 panel grid (medium fonts)**
```matlab
computeSmartStyle(7.0, 4.0, 1, 1, 'PRL', 'atomic', 2, 2)
```
- Journal page: 7.0" × 4.0" (double column)
- Page layout: 2 panels per row, 2 rows
- **Effective size: 3.5" × 2.0" per panel**
- Fonts scaled for **3.5" width (MEDIUM)**
- Result: Each panel legible at its physical size

---

### 3. Subplot Count vs Page Layout (Critical Distinction)

**Different concepts, different purposes:**

| Concept | Parameter | Meaning |
|---------|-----------|---------|
| **Internal subplots** | `nx`, `ny` | Subdivisions WITHIN one panel |
| **Page layout** | `panelsPerRow`, `panelsPerColumn` | Panels arranged on JOURNAL PAGE |

#### Example: Distinguishing the Two

**Case A: One panel with 4 subplots**
```matlab
computeSmartStyle(3.5, 2.6, 2, 2, 'PRL', 'atomic', 1, 1)
                         %  ^^^^                    ^^^^
                         %  nx=2, ny=2              panelsPerRow=1
```
- One MATLAB figure = ONE journal panel
- That panel contains 2×2 internal subplots
- Occupies full column width (3.5")
- Fonts scaled for 3.5" width

**Case B: Four separate panels in row**
```matlab
computeSmartStyle(3.5, 2.6, 1, 1, 'PRL', 'composite', 4, 1)
                         %  ^^^^                       ^^^^
                         %  nx=1, ny=1                 panelsPerRow=4
```
- Four separate MATLAB figures = FOUR journal panels
- Each panel is single subplot (no internal subdivisions)
- Each occupies 3.5/4 = 0.875" width
- Fonts scaled for 0.875" width (much smaller)

**Visually similar** (both show 2×2 or 4×1 grid), but **semantically different** → **different typography**.

---

## Typography Hierarchy

Typography flows through this decision chain:

```
1. Page layout (panelsPerRow) 
   ↓ defines effective physical size
   
2. Effective physical size
   ↓ determines base typography scale
   
3. panelIntent (atomic vs composite)
   ↓ modifies subplot fonts
   
4. nx/ny (internal subplots)
   ↓ used ONLY for layout geometry, NEVER font scaling
```

### Font Scaling Rules

1. **Base typography from effective physical size:**
   ```matlab
   effectivePanelWidth = panelWidth / panelsPerRow;
   scalePhysical = f(effectivePanelWidth, effectivePanelHeight);
   baseFontSize = scalePhysical * densityFactor;
   ```

2. **panelIntent modifies subplot fonts:**
   - `atomic`: `textSubplot = baseFontSize * 0.92` (slight reduction for clarity)
   - `composite`: `textSubplot = baseFontSize * 1.0` (full size, each is future panel)

3. **nx/ny geometry NEVER directly scales fonts:**
   - Used only for positioning axes in grid
   - Typography is **page-aware**, not **subplot-aware**

---

## Golden Rules (Non-Negotiable)

### 1. Panels Define the Figure – Figure Never Defines Panels

- The MATLAB figure window represents **ONE PANEL** in the final article
- Multi-panel layouts (nx×ny subplots) fit **WITHIN** this single panel
- Panel dimensions (`panelWidth × panelHeight`) are **SACRED**
- Panels **NEVER shrink** to fit content

### 2. Geometry Adapts to Content – Never Squeeze Content Into Geometry

- If labels overflow, **margins expand** (canvas grows)
- Panel axes size remains constant
- Only axes **POSITION** changes (within expanded margins)
- **DO NOT manipulate** `label.Position` – only modify `axes.Position`

### 3. Overlays Must Never Affect Panel Geometry

- Manual legends (tagged with `'manual'`)
- Textboxes and annotations
- Helper axes for visual effects

→ These are **OVERLAYS**, not data panels  
→ They must **NOT** affect panel counting  
→ They must **NOT** influence grid geometry  
→ They must **NOT** shrink panel area

### 4. Multi-Panel Layout Preserves Single-Panel Dimensions

- Each subplot within nx×ny grid has **identical geometric properties**
- Paper size = single panel dimensions (**NOT multiplied** by nx/ny)
- Figure window size stays constant during UI formatting
- Only axes positions and margins adjust

### 5. Typography Follows Panel Hierarchy, Not Axes Count

- **Panel-first typography:** Fonts sized for the publication panel
- Subplots inherit from panel, with `panelIntent`-driven adjustments
- **NEVER blindly reduce fonts** just because `nx > 1` (that's heuristic)

### 6. Page-Aware Layout – Typography from Physical Size, Not Subplot Count

- Font size **MUST match** the actual printed panel size on journal page
- **NOT derived** from MATLAB figure window size or subplot count
- Journal layout specified via `panelsPerRow`, `panelsPerColumn`
- Typography scales from **effective physical size**

### 7. Deterministic, Single-Pass Geometry

- No iterative solvers
- No heuristic margin adjustments
- Direct extent-to-margin mapping
- One geometry pass, then validation

---

## Usage Examples

### Example 1: Simple Single Panel

```matlab
% Single full-width panel, no subplots
style = SmartFigureEngine.computeSmartStyle(...
    3.5, 2.6, ...      % PRL single column dimensions
    1, 1, ...          % No internal subplots
    'PRL', ...         % Style preset
    'atomic', ...      % Panel intent (doesn't matter for single subplot)
    1, 1);             % Page layout: 1 panel per row/column

SmartFigureEngine.applyFullSmart(fig, style);
```
- **Effective size:** 3.5" × 2.6" (full column)
- **Fonts:** Scaled for 3.5" width
- **Result:** Large, readable labels

### Example 2: Atomic Panel with Subplots

```matlab
% One panel containing 2×2 subplots (time series, FFT, phase, spectrum)
style = SmartFigureEngine.computeSmartStyle(...
    3.5, 2.6, ...      % Panel will be 3.5" × 2.6" in journal
    2, 2, ...          % 2×2 internal subplots WITHIN panel
    'PRL', ...
    'atomic', ...      % All subplots stay together as ONE panel
    1, 1);             % Page layout: occupies one full column

SmartFigureEngine.applyFullSmart(fig, style);
```
- **Effective size:** 3.5" × 2.6" (full column)
- **Fonts:** Scaled for 3.5" width, then 0.92× for subplots (atomic mode)
- **Result:** Integrated panel with slightly reduced subplot fonts

### Example 3: Composite Panel (Future Split)

```matlab
% Preview of 2×2 panels that will be split into Fig 2A-D
style = SmartFigureEngine.computeSmartStyle(...
    3.5, 2.6, ...      % Each future panel will be 3.5" × 2.6"
    2, 2, ...          % Currently 2×2 grid for comparison
    'PRL', ...
    'composite', ...   % Each subplot will become separate panel
    1, 1);             % Page layout: each final panel occupies full column

SmartFigureEngine.applyFullSmart(fig, style);
```
- **Effective size:** 3.5" × 2.6" (full column per future panel)
- **Fonts:** Scaled for 3.5" width, NO reduction (composite mode = 1.0×)
- **Result:** Each subplot has full-size fonts (will be split later)

### Example 4: Four Panels in One Row (Page-Aware)

```matlab
% Four separate figures, each will be 1/4 of column width
style = SmartFigureEngine.computeSmartStyle(...
    3.5, 2.6, ...      % Journal column width
    1, 1, ...          % No internal subplots (each figure is single plot)
    'PRL', ...
    'atomic', ...      
    4, 1);             % PAGE LAYOUT: 4 panels per row on journal page

% Apply to each of the four figures
for i = 1:4
    SmartFigureEngine.applyFullSmart(figs{i}, style);
end
```
- **Effective size:** 0.875" × 2.6" (3.5/4)
- **Fonts:** Scaled for **0.875" width** (small but readable)
- **Result:** Fonts match physical printed size, not window size

### Example 5: 2×2 Page Grid (Page-Aware)

```matlab
% Double-column figure with 2×2 panel layout
style = SmartFigureEngine.computeSmartStyle(...
    7.0, 5.0, ...      % Double-column width
    1, 1, ...          % No internal subplots per panel
    'PRL', ...
    'atomic', ...
    2, 2);             % PAGE LAYOUT: 2 panels per row, 2 per column

% Apply to each of the four panels
for i = 1:4
    SmartFigureEngine.applyFullSmart(figs{i}, style);
end
```
- **Effective size:** 3.5" × 2.5" per panel
- **Fonts:** Scaled for 3.5" width (medium)
- **Result:** Each panel legible at its actual printed size

---

## Common Mistakes and Anti-Patterns

### ❌ WRONG: Using subplot count to scale fonts

```matlab
% DON'T DO THIS (heuristic, ignores physical size):
if nx > 1
    fontSize = baseFontSize * 0.8;  % Arbitrary reduction
end
```

**Problem:**  
- Doesn't account for actual printed panel size
- Same subplot count → same font size regardless of physical dimensions
- Breaks page-aware layout principle

### ❌ WRONG: Treating figure as article canvas

```matlab
% DON'T DO THIS:
figureWidth = panelWidth * nx;  % Multiplying by subplot count
```

**Problem:**  
- One MATLAB figure = ONE panel, not article canvas
- Panel dimensions are for ONE panel, not entire article

### ❌ WRONG: Ignoring panelIntent

```matlab
% DON'T DO THIS (missing editorial context):
style = computeSmartStyle(3.5, 2.6, 2, 2, 'PRL');  % No panelIntent
```

**Problem:**  
- Can't distinguish atomic (stay together) vs composite (will split)
- Same geometry → different editorial meaning → different typography needed

### ❌ WRONG: Confusing subplots with page layout

```matlab
% DON'T DO THIS:
% Trying to format 4 panels in a row by setting nx=4
style = computeSmartStyle(3.5, 2.6, 4, 1, 'PRL', 'atomic', 1, 1);
```

**Problem:**  
- `nx=4` means 4 subplots WITHIN one panel
- Should use `panelsPerRow=4` for page layout instead

### ✅ CORRECT: Page-aware with proper intent

```matlab
% DO THIS:
style = computeSmartStyle(...
    3.5, 2.6, ...      % Journal column dimensions
    1, 1, ...          % Internal subplots (or 2,2 if needed)
    'PRL', ...         % Style preset
    'atomic', ...      % Editorial intent
    4, 1);             % Page layout: 4 panels per row
```

**Why it works:**  
- Clear separation of internal structure (nx/ny) vs page layout (panelsPerRow/Column)
- Editorial intent explicit (atomic)
- Typography scales from actual printed size

---

## UI Controls

The FinalFigureFormatterUI exposes these concepts through the **SMART Paper Layout** panel:

| Control | Purpose | Values |
|---------|---------|--------|
| **Panels across** | Internal subplots horizontally | Integer (nx) |
| **Panels down** | Internal subplots vertically | Integer (ny) |
| **Column mode** | Journal column width | Single/Double |
| **Aspect ratio (H/W)** | Panel height/width ratio | Float (e.g., 0.75) |
| **Panel intent** | Editorial meaning | `atomic` / `composite` |
| **Panels per row (page)** | Page layout: horizontal panels | Integer ≥ 1 |
| **Panels per col (page)** | Page layout: vertical panels | Integer ≥ 1 |

### Workflow

1. Set **column mode** (single vs double column for journal)
2. Set **panels across/down** (internal subplots within ONE figure)
3. Set **aspect ratio** (height/width for panel proportions)
4. Set **panel intent**:
   - `atomic` if figure stays as one panel
   - `composite` if subplots will be split later
5. Set **page layout** (panels per row/column):
   - Default `1, 1` = figure occupies full column
   - `4, 1` = four panels in row (fonts scale accordingly)
6. Click **Apply SMART**

---

## Developer Notes

### Extending the Engine

When adding features:

1. **Respect panel-first architecture**  
   - Never assume figure = article canvas
   - Always think: "What does this mean for ONE panel?"

2. **Maintain page-aware scaling**  
   - Typography must derive from effective physical size
   - Never use nx/ny directly for font scaling

3. **Preserve editorial intent**  
   - Always branch on `panelIntent` for typography decisions
   - Don't infer intent from geometry

4. **Follow hierarchy**  
   ```
   Page layout → Physical size → Base typography → Intent adjustment → Geometry
   ```

### Testing Checklist

- [ ] Test atomic panel with nx=2, ny=2 (fonts should reduce)
- [ ] Test composite panel with nx=2, ny=2 (fonts should NOT reduce)
- [ ] Test panelsPerRow=4 (fonts should be small for physical size)
- [ ] Test panelsPerRow=1 (fonts should be large for full column)
- [ ] Verify same subplot count with different page layouts produces different fonts
- [ ] Verify same page layout with different intents produces different fonts

---

## Summary

**SmartFigureEngine implements a three-pillar architecture:**

1. **Panel Intent:** Editorial meaning (atomic vs composite)
2. **Page-Aware Layout:** Typography from physical journal size
3. **Geometry vs Semantics:** nx/ny for layout, panelsPerRow for fonts

**Core principle:**  
*"Adapt geometry to content, typography to page, and semantics to editorial intent."*

This is NOT a figure resizer. It is a **journal panel layout engine** that respects the conceptual hierarchy of scientific publication design.

