# Debug Infrastructure Guide - Aging MATLAB Pipeline

## Overview

The Aging pipeline now includes a structured debug infrastructure to control console output, figure creation, and diagnostic collection. This system allows the pipeline to run efficiently without console spam or excessive figure windows while maintaining full diagnostic capability.

## Core Components

### 1. **dbg() — Structured Logging**

**Purpose:** Replace `fprintf()` and `disp()` with verbosity-controlled logging.

**Location:** `Aging/utils/dbg.m`

**Usage:**
```matlab
% Log at different verbosity levels
dbg(cfg, "summary", "Found %d pause runs", nPause);
dbg(cfg, "full", "Processing pause Tp=%.1f K", Tp);
dbg(cfg, "quiet", "This is suppressed in summary mode");
```

**Verbosity Levels:** `quiet < summary < full`
- **quiet:** Silent (only use for debug spew)
- **summary:** Key pipeline milestones (default)
- **full:** Detailed diagnostics

**Configuration:**
```matlab
cfg.debug.level = "summary";      % Minimum level to display
cfg.debug.logToFile = true;       % Append to log file
cfg.debug.logFile = 'path/to/log.txt';
```

### 2. **dbgFigure() — Controlled Figure Creation**

**Purpose:** Create figures only when appropriate based on debug settings.

**Location:** `Aging/utils/dbgFigure.m`

**Usage:**
```matlab
h = dbgFigure(cfg, "DeltaM_overview");
if ~isempty(h)
    figure(h); clf;
    plot(...);
    dbgSaveFig(cfg, h, "DeltaM_overview.png");
end
```

**Figure Modes:**
- `cfg.debug.plots = "none"` — No figures created
- `cfg.debug.plots = "key"` — Only approved tags (controlled)
- `cfg.debug.plots = "all"` — All figures (legacy behavior)

**Approved Tags (default):**
```
DeltaM_overview
AFM_FM_channels
Rsw_vs_T
global_J_fit
reconstruction_fit
aging_memory_summary
```

**Additional Controls:**
```matlab
cfg.debug.plotVisible = "off";    % Hidden (saves memory)
cfg.debug.maxFigures = 8;         % Limit simultaneous figures
cfg.debug.keyPlotTags = [...];    % Custom approved tags
```

### 3. **dbgSaveFig() — Automatic Diagnostic Saves**

**Purpose:** Save figures to organized diagnostic folder.

**Location:** `Aging/utils/dbgSaveFig.m`

**Usage:**
```matlab
dbgSaveFig(cfg, h, "plot_name.png");
```

**Output Structure:**
```
outputFolder/
  diagnostics/
    DeltaM_overview.png
    AFM_FM_channels.png
    ...
    diagnostic_log.txt
```

### 4. **dbgInitDiagnostics() — Setup**

**Purpose:** Initialize diagnostics directory and log file at pipeline start.

**Location:** `Aging/utils/dbgInitDiagnostics.m`

**Usage:**
```matlab
% In Main_Aging.m, after config
dbgInitDiagnostics(cfg);
```

### 5. **dbgSummaryTable() — Results Summary**

**Purpose:** Write key metrics to a summary file.

**Location:** `Aging/utils/dbgSummaryTable.m`

**Usage:**
```matlab
dbgSummaryTable(cfg, ...
    'pause_runs', nPause, ...
    'fit_R2', fit_r2, ...
    'stage_times', timing);
```

## Configuration Example

All debug settings are defined in `agingConfig.m`:

```matlab
% === Debug Infrastructure ===
cfg.debug.level = "summary";           % Verbosity level
cfg.debug.plots = "key";               % Figure mode
cfg.debug.keyPlotTags = [
    "DeltaM_overview"
    "AFM_FM_channels"
    "Rsw_vs_T"
    "global_J_fit"
];
cfg.debug.plotVisible = "off";         % Hidden figures
cfg.debug.maxFigures = 8;              % Max simultaneous figures
cfg.debug.logFile = fullfile(cfg.outputFolder, 'diagnostic_log.txt');
cfg.debug.useTimestamp = false;        % Timestamped subdirs
```

## Migration Guide - Converting from fprintf to dbg

### Before (Verbose):
```matlab
fprintf('DEBUG: Processing pause %d of %d\n', i, nPause);
fprintf('        Tp=%.1f K\n', Tp);
fprintf('        Mean ΔM = %.3e\n', mean_DM);
```

### After (Controlled):
```matlab
% summary level (visible by default)
dbg(cfg, "summary", "Processing pause %d of %d at Tp=%.1f K", i, nPause, Tp);

% full level (only if cfg.debug.level == "full")
dbg(cfg, "full", "Mean ΔM = %.3e", mean_DM);
```

### Benefits:
1. Controlled verbosity by default
2. Full diagnostics retained (just suppressed)
3. Automatic file logging with timestamps
4. Users can dial verbosity up/down easily

## Pipeline Integration Examples

### Stage 1: Data Loading
```matlab
dbg(cfg, "summary", "Loading data from: %s", cfg.dataDir);
state = stage1_loadData(cfg);
dbg(cfg, "summary", "Loaded %d pause runs + 1 no-pause reference", ...
    numel(state.pauseRuns));
```

### Stage 7: Reconstruction
```matlab
dbg(cfg, "summary", "Switching reconstruction: mode=%s", mode);
[result, state] = stage7_reconstructSwitching(state, cfg);
dbg(cfg, "summary", "FM cross-check: corr(RMS B(Tp), FM_step_A) = %.3f", R_FM);
```

### Stage 8: Plotting (with figures)
```matlab
dbg(cfg, "summary", "Reconstruction fit results:");
dbg(cfg, "summary", "  λ = %.3f, a = %.3f, b = %.3f, R² = %.3f", ...
    result.lambda, result.a, result.b, result.R2);

h = dbgFigure(cfg, "Rsw_vs_T");
if ~isempty(h)
    figure(h); clf;
    plot(...);
    dbgSaveFig(cfg, h, "Rsw_vs_T.png");
end
```

## Usage Patterns

### Pattern 1: Key Milestone (Always Show)
```matlab
dbg(cfg, "summary", "Stage completed: %s", stageName);
```

### Pattern 2: Diagnostic Detail (Show if Verbose)
```matlab
dbg(cfg, "full", "Intermediate value: x=%.3f, y=%.3f", x, y);
```

### Pattern 3: Quiet Debug (Never Show)
```matlab
dbg(cfg, "quiet", "This is debug spam that nobody needs to see");
```

## Recommended Default Behavior

By default, with `cfg.debug.level = "summary"` and `cfg.debug.plots = "key"`:

1. **Console:** Only shows key milestones (clean output)
2. **Figures:** Only creates ~3-8 key plots (no freezing)
3. **Diagnostics:** All saved to `diagnostics/` folder
4. **Log File:** Every message logged with timestamp

## Advanced: Custom Tags and Verbosity

Users can customize for their workflow:

```matlab
% Minimal output (clean runs)
cfg.debug.level = "quiet";
cfg.debug.plots = "none";

% Diagnostic output (debug mode)
cfg.debug.level = "full";
cfg.debug.plots = "all";
cfg.debug.plotVisible = "on";

% Custom tag list (show only these plots)
cfg.debug.keyPlotTags = ["DeltaM_overview", "global_J_fit"];
```

## Benefits Achieved

✓ **No Console Spam** — Only key milestones printed
✓ **No Figure Spam** — MATLAB doesn't freeze with 20+ windows
✓ **Full Diagnostics Retained** — All detail available via logging and saved plots
✓ **Easy to Control** — Single config struct to manage everything
✓ **Backward Compatible** — Doesn't change pipeline logic or state structure
✓ **Automatic Saves** — Plots and logs saved without manual intervention

## Testing the System

```matlab
% Test with minimal output
cfg = agingConfig();
cfg.debug.level = "summary";
cfg.debug.plots = "key";
state = Main_Aging(cfg);
% Expected: Clean console, 3-8 plots, all diagnostics in diagnostics/ folder

% Test with full diagnostics
cfg.debug.level = "full";
cfg.debug.plots = "all";
cfg.debug.plotVisible = "on";
state = Main_Aging(cfg);
% Expected: Detailed console, all plots visible, full logging
```

## Summary

The debug infrastructure provides **production-grade pipeline control** without changing any physics or state structures. Use it to:

1. Keep pipeline runs clean and focused
2. Collect comprehensive diagnostics for analysis
3. Debug quickly when needed
4. Share clean, reproducible outputs with others
