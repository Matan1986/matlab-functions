# Documentation (private research notebook)

This file is for me.
It is not public-facing documentation.
It is a practical map for running analyses quickly and repeatably.

This repository holds MATLAB workflows for quantum materials measurements.
Each major experiment type has a versioned folder and a "main" script.
The code is optimized for real lab data turnaround, not for polished APIs.

When I return after weeks/months, this page should let me restart fast:
what each folder does, how I run it, how I name files, and how I avoid
breaking older workflows.

---

## 1) What this repo is for

This is a private MATLAB research repository for day-to-day analysis.
I use it to import, clean, fit, and plot data from several measurement types
(magnetization, transport, susceptibility, relaxation, etc.).

The structure is workflow-first.
Instead of one unified package, each module has independent scripts,
usually centered on one entry-point file (`*_main.m` or similar).
That separation is intentional: experiment pipelines evolve at different speeds.

The goal is reliability for personal use.
I prefer clear rerunnable scripts over abstract architecture.
Versioned folders (`ver1`, `ver2`, ... ) preserve older behavior so I can
reproduce past figures and avoid accidental regressions.

---

## 2) Folder/module map

### Aging
- Purpose: aging-memory analysis, AFM/FM decomposition, and current-dependent coexistence model.
- Typical entry: `Main_Aging.m`.
- Use when comparing pause vs no-pause runs, ΔM(T) analysis, and switching amplitude reconstruction.

### HC ver1
- Purpose: heat-capacity data import, cleaning, and plotting.
- Typical entry: `HC_main.m`.
- Use for C(T) style datasets from HC runs.

### MT ver2
- Purpose: magnetization vs temperature processing and segment routines.
- Typical entry: `MT_main.m`.
- Includes heating/cooling segmentation and plotting utilities.

### MH ver1
- Purpose: magnetization vs field workflows.
- Typical entry: `MH_main.m`.
- Use for loop processing and field-dependent magnetic analysis.

### PS ver4
- Purpose: planar Hall / angle-dependent transport workflow.
- Typical entry: `PS_main.m`.
- Includes filtering, smoothing, normalization, and channel handling.

### Relaxation ver3
- Purpose: TRM/IRM relaxation fitting and parameter summaries.
- Typical entry: `main_relexation.m`.
- Includes stretched-exponential utilities and fit overlays.

### Resistivity ver6
- Purpose: resistivity vs temperature routines.
- Typical entry: `Resistivity_main.m`.
- Use for standard ρ(T) or R(T) processing and plots.

### Susceptibility ver1
- Purpose: AC susceptibility import/fix/plot pipeline.
- Typical entry: `main_Susceptibility.m`.
- Use when processing χ′/χ″ style datasets.

### FieldSweep ver3
- Purpose: field-sweep transport processing.
- Typical entry: `FieldSweep_main.m`.
- Use for batch-style field sweep datasets and derived outputs.

### zfAMR ver11
- Purpose: zero-field AMR processing and helper tables.
- Typical entry: `main/zfAMR_main.m`.
- Includes utility and table builders under `utils/` and `tables/`.

### AC HC MagLab ver8
- Purpose: MagLab-specific AC/HC workflow.
- Typical entry: `ACHC_main.m`.
- Use for instrument-specific formats from MagLab runs.

### Resistivity MagLab ver1
- Purpose: MagLab-specific RH/resistivity workflow.
- Typical entry: `ACHC_RH_main.m`.
- Use for MagLab RH-style files and plotting path.

### General ver2
- Purpose: shared helper functions reused across modules.
- Keep this stable; changes here can affect multiple pipelines.

### Tools ver1
- Purpose: general utilities and one-off helper scripts.
- Use for common convenience tasks not tied to one module.

### GUIs
- Purpose: plotting/formatting GUI tools and tests.
- Includes figure formatting interfaces and validation scripts.

---

## 3) Typical personal MATLAB workflow

### A. Start clean
1. Open MATLAB.
2. `cd` to repository root.
3. Optional but usually useful: add recursive paths.

```matlab
cd('/workspace/matlab-functions')
addpath(genpath(pwd))
```

If the session is messy, do:

```matlab
clear; close all; clc
```

### B. Choose one module per session focus
I normally work in one experiment family at a time.
I run only that module's main script, then iterate options/filters.

```matlab
run(fullfile('MT ver2','MT_main.m'))
```

### C. Validate quickly
- Check figure shapes first (obvious anomalies).
- Check key derived values/tables in workspace.
- If something looks wrong, verify filename parsing assumptions.

### D. Iterate, don't over-edit
I prefer reruns with minimal edits.
If a fix is reusable, keep it.
If it is one-off for a single dataset, keep notes externally.

### E. Save outputs in organized subfolders
For heavy sessions, keep generated artifacts under per-dataset folders:
- `processed/`
- `figures/`
- `tables/`

---

## 4) Practical data naming conventions

Many scripts infer metadata from filenames.
Consistent names prevent silent parsing mistakes.

### Recommended pattern

`SampleID_YYYYMMDD_Mode_TxxK_BxxT_Anglexxdeg_RunN.dat`

Example:

`CTS_20260203_PS_T15K_B9T_AngleSweep_Run2.dat`

### Rules I follow
- Use `_` delimiters consistently.
- Keep temperature explicit with `K` (e.g., `T12K`).
- Keep magnetic field explicit with `T` (e.g., `B14T`).
- Keep angle explicit with `deg` for angular scans.
- Put run index at the end (`Run1`, `Run2`, ...).
- Do not rename files mid-analysis unless absolutely necessary.

### Anti-patterns to avoid
- Random spaces in filenames.
- Mixing units style (`T14` in one file, `14T` in another).
- Missing run index when repeats exist.
- Reusing filenames for different processing stages.

---

## 5) Quick usage examples

### Example 1: aging-memory pass

```matlab
cd('/workspace/matlab-functions')
run(fullfile('Aging','Main_Aging.m'))
```

Use this when checking pause/no-pause memory behavior and ΔM(T) comparisons.

### Example 2: planar Hall angle workflow

```matlab
cd('/workspace/matlab-functions')
run(fullfile('PS ver4','PS_main.m'))
```

Use this for angle-sweep cleanup (filtering + smoothing + normalization).

### Example 3: relaxation fitting session

```matlab
cd('/workspace/matlab-functions')
run(fullfile('Relaxation ver3','main_relexation.m'))
```

Use this for stretched-exponential fitting and temperature trend summaries.

---

## 6) Philosophy of versioning (`verN` folders)

`verN` folders are history checkpoints, not cosmetic labels.

- New version when behavior meaningfully changes.
- Keep old version runnable for reproducibility.
- Avoid rewriting old results by silently changing old scripts.
- Prefer copy-forward (`verN` -> `verN+1`) before major edits.

Practical rule:
If I would worry about reproducing last month's figure after a change,
make a new `verN` folder first.

---

## 7) Personal stability rules

- Do not mix unrelated fixes in one editing session.
- Keep shared helper changes minimal and tested on at least two modules.
- Preserve old parsing behavior unless there is a strong reason to break it.
- Avoid hard-coded absolute paths in committed scripts.
- Keep input assumptions explicit near import logic.
- Prefer deterministic filters over interactive/manual tweaks.
- Run one known reference dataset after nontrivial edits.
- If output changes unexpectedly, diff intermediate tables before plotting.
- Do not delete old versions during active projects.
- Keep comments short and operational.

---

## 8) Personal maintenance checklist

When creating a new workflow version:
1. Copy previous module folder to new `verN`.
2. Keep previous version untouched.
3. Edit only new version until validated.
4. Run at least one known-good dataset.
5. Compare key outputs against previous trusted run.
6. Note breaking changes in a short header comment (if any).

When restarting after a long gap:
1. Read this file first.
2. Open target module main script.
3. Confirm filename pattern for current dataset.
4. Run one quick smoke test file.
5. Then batch-run full dataset.

When debugging unexpected output:
1. Confirm MATLAB path (`addpath(genpath(...))`).
2. Clear workspace and rerun from clean state.
3. Verify parsed metadata from filenames.
4. Check units and column mapping assumptions.
5. Inspect pre- and post-filter arrays before fitting.
6. Only then adjust fit/plot settings.

When wrapping a session:
1. Save key figures.
2. Export important tables.
3. Record short notes in lab notebook.
4. Commit only reusable changes.

---

End of personal documentation.
If this file becomes bloated, shorten it again.
Keep it useful for fast restart, not comprehensive theory.

---
