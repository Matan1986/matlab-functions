# FigureControlStudio System Overview (Internal)

This document describes current behavior of FigureControlStudio (FCS) as implemented in the repository.
It is based on static code survey, not intended behavior.

Primary files:
- `GUIs/FigureControlStudio.m`
- `GUIs/FCS_export.m`
- `GUIs/FCS_normalizeTexStrings.m`
- `GUIs/FCS_resolveTargets.m`
- `GUIs/FCS_applyTypography.m`
- `GUIs/FCS_applyAxisPolicy.m`

## A. High-Level Architecture

- `FigureControlStudio` is a single `uifigure` controller with nested callbacks and local helper functions.
- It orchestrates operations on external figure handles selected via scope resolution (`FCS_resolveTargets`).
- Major runtime state is held in GUI-local variables:
  - `explicitHandleCache`: ordered explicit target list.
  - `lastComposedFigure`: last compose output, reused by composed-only export.
  - `axesBasePositions`: map of baseline axis positions for manual transform.
  - `manualLegendPositions`: persisted manual legend positions.
- Subsystems used by GUI:
  - Typography and axis policy: `FCS_applyTypography`, `FCS_applyAxisPolicy`.
  - Export adapter: `FCS_export` (used in general export path only).
  - Tex normalization: `FCS_normalizeTexStrings` (used in typography and Illustrator-safe export).

Data flow at runtime:
- UI controls -> `scopeSpec` (`buildScopeSpecFromUI`) -> figure list (`FCS_resolveTargets`).
- Figure list -> stage-specific mutation logic:
  - Layout callbacks mutate selected figures in place.
  - Compose builds a new figure and appends it to explicit list.
  - Export either mutates existing figures and writes files, or exports composed figure directly.
- UI persistence writes/reads `FCS_ui_state.mat` from `userpath` (fallback `pwd`).

## B. Pipeline Explanation (Critical)

### 1) Figure enters the system

- Entry point is target resolution:
  - `FigureControlStudio.buildScopeSpecFromUI`
  - `FCS_resolveTargets`
- Resolution modes: current, all open, by tag, by name, explicit list.
- Exclusion of known GUI figures is applied in resolver, including deterministic marker `FCS_Root` appdata/tag.

### 2) What Layout does (in-place mutations)

Layout controls mutate source figures directly.

- Workspace sizing (`onApplyWorkspaceSize`):
  - Sets figure `Units='centimeters'` and writes figure `Position`.
  - Calls `relinkColorbars` afterward.
- Equalize/center (`onEqualizeCenterAxesGroup`):
  - Computes normalized axis positions for primary axes.
  - Rewrites `ax.Position` per figure.
  - Calls `relinkColorbars`.
  - Captures baseline positions.
- Manual transform sliders (`onAxesTransformChanged` + `i_applyManualAxesTransform`):
  - Applies scale/offset to baseline positions.
  - Rewrites axis `Position`.
  - Calls `relinkColorbars`.
- Colorbar relinking (`relinkColorbars`):
  - Forces colorbar manual placement (`Location='manual'` when supported).
  - Rewrites colorbar positions relative to host axis.

Important: layout stage is not copy-based. It mutates the original figures.

### 3) What Compose expects vs what it receives

Compose entry:
- `onCompose` -> `i_buildComposedFigureFromCurrentSelection` -> `i_buildComposedFigure`.

Current compose behavior:
- Creates a new figure and uses `tiledlayout` only to resolve tile boxes.
- Scans each source figure for candidate axes and applies compose filtering.
- Copies selected axes to the composed figure (`newFig`) and maps source normalized positions into each resolved tile box.
- Deletes the temporary tiledlayout container after tile-box resolution.
- Freezes copied axes (`Units='normalized'`, fixed `Position`, `ActivePositionProperty='position'`) after `drawnow`.
- Runs `relinkColorbars(newFig)` after placement to keep colorbars aligned with final axes positions.

Compose assumptions:
- Source figure has primary plot axes discoverable by compose filter.
- Source axes positions are already meaningful for panel geometry and should be preserved.

Assumption mismatch to note:
- Prior mismatch between layout-stage manual geometry and tiledlayout-managed compose has been reduced by manual post-copy positioning.

### 4) What happens during export

There are two active export paths.

- Composed-only PDF branch inside GUI (`onApplyExport`):
  - Uses existing `lastComposedFigure` or builds one on demand.
  - Optional Illustrator-safe mode: runs tex normalization first on current text content, then forces interpreters to `tex`, and restores interpreters via `onCleanup`.
  - Uses shared export-prep helper to apply temporary export-time normalization/guards and restore state after export.
  - Exports with `exportgraphics(...,'ContentType','vector')`.

- General export branch (`onApplyExport` -> `FCS_export`):
  - Passes selected figures and export options to `FCS_export`.
  - `FCS_export` handles pdf/png/fig writing.
  - Shared export-prep helper is applied before each export operation and restored afterward.
  - Paper sync now enforces WYSIWYG-centric settings (`PaperSize`, `PaperPosition`, `PaperPositionMode='auto'`, `InvertHardcopy='off'`).
  - `drawnow` stabilization is run immediately before export/save calls.

State modifications during export are temporary and restored (interpreter restoration in Illustrator-safe mode, and export-prep state restoration for font/paper/inset guards).

### 5) Text/Typography normalization ordering (runtime safety)

- Active typography flow now pre-normalizes LaTeX-like strings before typography property writes.
- This prevents invalid `tex` interpreter syntax warnings from stale strings such as `$\mathrm{...}$` during live updates.
- `FCS_normalizeTexStrings` still mutates objects in place, and now records modified string entries in its returned report even when debug printing is off.
- Compose path applies the same protection on source figures before axis copy, so copied text objects do not carry invalid `tex` strings into composed figures.

## C. Axes Handling Model

There is no single global definition of "primary axes". It differs by module.

- `FigureControlStudio.i_isPrimaryPlotAxes`:
  - Excludes manual legend axes and tags containing `legend` or `colorbar`.
  - Otherwise returns true.
- Compose filter in `i_buildComposedFigure`:
  - Excludes by class (`ColorBar`, `Legend`), tags (`legend/colorbar/inset/helper`), visibility, degeneracy threshold, and non-plot axes.
  - Requires children containing selected plot primitive classes.
- `FCS_export.classifyAxes`:
  - Uses visibility + plottable-child heuristic + tile membership.
  - Classification categories: primary, manualLegend, auxiliary.
- `FCS_setColormapOnly.getDataAxes`:
  - Excludes legend/colorbar by tag and by class checks.

Known pitfalls:
- Raw `findall(...,'Type','axes')` appears in many places with different post-filters.
- Some pipelines include helper/inset axes unless explicitly filtered.
- Colorbar/legend exclusion is not uniformly type-based everywhere.

## D. Export System

### Difference between single export and composed export

- Single/general export:
  - Uses `FCS_export`.
  - Supports formats pdf/png/fig and pdf mode selection.
  - Applies paper-size sync and optional font normalization.

- Composed-only export:
  - Uses inline GUI branch for pdf.
  - Performs its own diagnostics and font normalization loops.
  - Uses vector `exportgraphics` directly.

### Shared logic vs duplicated logic

Shared concept but duplicated implementation exists for:
- export diagnostics
- font normalization on axes/colorbars/text
- export font fallback resolution

Also present:
- dormant scene-rebuild helper stack in `FCS_export` (`discoverScene`, `rebuild*`) that is currently defined but not called by `FCS_export`.

### What each path modifies

- Both paths can mutate source figure font properties.
- `FCS_export` path additionally mutates paper properties (`PaperUnits`, `PaperSize`, `PaperPosition`).
- Illustrator-safe flow mutates interpreter fields, then restores them via recorded state.

## E. Side Effects & State Mutations (Very Important)

In-place figure/axes mutations:
- Layout size/position updates (`onApplyWorkspaceSize`, `onEqualizeCenterAxesGroup`, `i_applyManualAxesTransform`).
- Colorbar manual repositioning (`relinkColorbars`).
- Typography application sets font/interpreter fields on many objects.
- Export font normalization writes font fields on axes, colorbars, text.
- `FCS_export.i_syncPaperSize` writes paper properties on source figures.

Callback overwrites:
- `WindowButtonMotionFcn`/`WindowButtonUpFcn` are temporarily overwritten during manual legend drag, then restored to previous callbacks.
- Style numeric field `KeyPressFcn` is set directly.
- GUI window `WindowKeyPressFcn` is set directly.

State persistence and environment dependency:
- UI state file path depends on `userpath`; fallback is `pwd`.
- ComposeSpec save/load writes user-selected `.mat` files.

Intentional vs risky:
- Intentional:
  - Layout and appearance are mutation-based by design.
  - Interpreter restoration in Illustrator-safe mode is explicitly scoped.
- Risky:
  - Export prep/restoration is best-effort; failures in unsupported properties can still leave partial state drift.
  - Callback coordination across external tools remains sensitive even with restoration.
  - Multiple axis-detection models can produce different object sets across stages.

## F. Known Fragile Areas

- Layout vs Compose interaction:
  - Layout edits source axis geometry; compose uses tiledlayout and recomputes geometry in new figure.
  - Assumptions about preserving layout-stage position edits do not hold reliably.
- Export duplication:
  - Two active export implementations increase divergence risk in behavior and side effects.
- Axis filtering inconsistencies:
  - Different "primary axes" criteria in layout, compose, export, and utilities.
- Callback overwrite safety:
  - Manual legend drag callback logic can clobber existing figure callbacks.
- Path/state dependencies:
  - UI state persistence path is environment-dependent (`userpath` vs `pwd`).
  - Baseline/manual-legend maps rely on keying schemes that can collide under reused figure identity patterns.

## G. Safe Development Guidelines

- Do not add new raw `findall(...,'Type','axes')` usage without explicitly selecting a shared axis-filtering rule for that path.
- When changing compose:
  - Preserve the current order: source-axis normalization -> copy -> drawnow -> freeze copied primary axes.
  - Keep colorbar handling separate from primary-axis handling.
- When changing export:
  - Verify behavior in both active paths (composed-only branch and `FCS_export` path).
  - Track which properties are intentionally mutated and whether restoration is required.
- When changing callbacks:
  - Treat existing figure callbacks as external state; do not assume exclusive ownership.
- When changing UI state persistence:
  - Maintain backward compatibility with existing `uiState` fields and partial/corrupt-file fallback behavior.
- Before changing axis classification logic:
  - Check all locations where primary axes are detected (layout, compose, export, colormap utilities) to avoid cross-stage mismatch.

## H. Quick Start for Developers

Bug tracing entry points:
- Layout bugs: start at `onApplyWorkspaceSize`, `onEqualizeCenterAxesGroup`, `i_applyManualAxesTransform`, `relinkColorbars`.
- Compose bugs: start at `i_buildComposedFigure` and its primary-axis filter.
- Export bugs:
  - Composed-only export: `onApplyExport` composed branch.
  - General export: `FCS_export` plus option parsing and `i_syncPaperSize`.
- Tex/label bugs: `i_applyIllustratorSafeMode` and `FCS_normalizeTexStrings`.

Minimal trace workflow:
- Identify which stage wrote the last mutation to figure/axes properties.
- Confirm which target-resolution mode selected the figures.
- Confirm which axis classifier was active in that path.
- Check whether callback/state restoration exists for the mutated properties.

## I. Stability Improvements

Recent internal hardening was intentionally scoped to safety and consistency without changing compose/layout geometry behavior.

- Export-path unification (shared helper, behavior-preserving):
  - Added `GUIs/FCS_prepareExportFigure.m` and `GUIs/FCS_restoreExportFigureState.m`.
  - Both export paths now call the same shared export-prep logic for:
    - diagnostics logging
    - optional export-time font normalization
    - optional paper sync (only where already used in `FCS_export`)
  - Branching remains unchanged:
    - composed-only PDF branch in `FigureControlStudio` still exists
    - general export via `FCS_export` still exists

- Export side-effect reduction:
  - Export-time font and paper mutations are now captured and restored after each export operation.
  - This reduces persistent mutation of source figures while preserving export output behavior.

- Callback safety for manual legend drag:
  - `WindowButtonMotionFcn` and `WindowButtonUpFcn` are now captured before drag begins.
  - On drag stop/cancel, previous callbacks are restored instead of being cleared.
  - Warnings were added for callback-restore failures.

- Shared axes wrapper (consistency aid):
  - Added `GUIs/FCS_getPrimaryAxes.m`.
  - `mode='primary'` matches existing FigureControlStudio tag-based primary-axes filtering.
  - `mode='all'` preserves raw `findall(...,'Type','axes')` behavior.
  - Compose helper usage was switched to this wrapper without changing selection semantics.

- Dead-code cleanup:
  - Removed `restorePaperProps` nested helper in `FigureControlStudio` (unreferenced).

Intentionally unchanged:
- Layout and compose geometry mechanics (including tiledlayout behavior and stage order).
- UI semantics and control flow.
- Illustrator-safe interpreter forcing + normalization sequence.
- Existing primary-axes rules in modules that intentionally use different classifiers (`FCS_export.classifyAxes` vs compose-specific filtering).

## J. Compose System (Updated)

- `i_buildComposedFigure` now uses `tiledlayout` as a tile-box resolver, not as the final axes geometry controller.
- Axes are copied to the composed figure and manually positioned using source normalized geometry mapped into each resolved panel box.
- Final positions are frozen after `drawnow`, then colorbars are relinked on the composed figure.
- Result: composed figure geometry tracks layout-adjusted source geometry more closely and avoids tiledlayout reflow of final axes positions.

## K. Export System (Updated)

- Export prep is centralized through `FCS_prepareExportFigure` and restored via `FCS_restoreExportFigureState`.
- WYSIWYG paper alignment is applied during prep:
  - `PaperSize` and `PaperPosition` synchronized to on-screen figure size
  - `PaperPositionMode='auto'`
  - `InvertHardcopy='off'`
- Clipping guard is applied temporarily by raising `LooseInset` to at least `TightInset` for axes where needed.
- `drawnow` is executed immediately before export/save calls to stabilize final geometry.
- Exportgraphics behavior is normalized through dedicated wrappers for vector PDF, image PDF, and PNG paths.

## L. Axis Selection Unification (New)

Low-risk replacements to `FCS_getPrimaryAxes` were applied only where intent was explicitly primary plot axes and existing logic was simple.

Applied:
- `FigureControlStudio.i_applyLegendReverseExistingOnly` now uses `FCS_getPrimaryAxes(fig, struct('mode','primary'))`.
- `FigureControlStudio.onEqualizeCenterAxesGroup` now uses `FCS_getPrimaryAxes(fig, struct('mode','primary'))`.

Intentionally skipped:
- Locations with additional custom filtering (`i_isTiledLayoutManagedAxes`, manual-legend handling, tag/class exclusions, export diagnostics).
- Complex compose/export internals and dynamic GUI logic where semantic drift risk is higher.

## M. GUI Safety Validation

Validation performed in this pass was conservative and static (no GUI runtime available in this environment):

- Confirmed compose/export button callbacks remain bound:
  - `btnCompose -> onCompose`
  - `btnApplyExport -> onApplyExport`
- Confirmed manual legend drag callback chain remains intact:
  - button-down hook on manual legend axes
  - drag motion/up handlers assignment
  - restoration of previous figure window callbacks on drag stop
- No callback removals were introduced in this cleanup patch.
