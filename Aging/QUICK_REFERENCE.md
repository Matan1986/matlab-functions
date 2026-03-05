# Debug Infrastructure - Quick Reference

## Configuration Presets

### Default (Production - Recommended)
```matlab
cfg = agingConfig();
% Automatically configured as:
%   debug.level = "summary"
%   debug.plots = "key"  
%   debug.plotVisible = "off"
%   debug.maxFigures = 8

state = Main_Aging(cfg);
% Result: Clean output, 3-8 key plots saved, all diagnostics logged
```

### Full Diagnostics (Debug Mode)
```matlab
cfg = agingConfig();
cfg.debug.level = "full";
cfg.debug.plots = "all";
cfg.debug.plotVisible = "on";

state = Main_Aging(cfg);
% Result: Verbose output, all plots visible, comprehensive logging
```

### Silent Mode (Batch/Server)
```matlab
cfg = agingConfig();
cfg.debug.level = "quiet";
cfg.debug.plots = "none";

state = Main_Aging(cfg);
% Result: Minimal console spam, diagnostics still saved
```

---

## Logging Cheat Sheet

### Summary Level (Default)
```matlab
% Show key milestones
dbg(cfg, "summary", "Stage X started");
dbg(cfg, "summary", "Loaded %d files", n);
dbg(cfg, "summary", "Result: R² = %.3f", R2);
```

### Full Level (Verbose)
```matlab
% Show detailed diagnostics
dbg(cfg, "full", "Intermediate value: %d", val);
dbg(cfg, "full", "Array shape: [%d x %d]", m, n);
```

### Quiet Level (Never)
```matlab
% Debug spam that's never shown
dbg(cfg, "quiet", "This is loop iteration %d", i);
```

---

## Figure Management Cheat Sheet

### Create and Plot
```matlab
h = dbgFigure(cfg, "plot_tag_name");
if ~isempty(h)
    figure(h); clf;
    plot(x, y);
    xlabel('X'); ylabel('Y');
    dbgSaveFig(cfg, h, "plot_tag_name.png");
end
```

### Approved Tags (Default)
```
"DeltaM_overview"
"AFM_FM_channels"
"Rsw_vs_T"
"global_J_fit"
"reconstruction_fit"
"aging_memory_summary"
```

### Custom Tags
```matlab
cfg.debug.keyPlotTags = [
    "DeltaM_overview"
    "my_custom_plot"
    "another_diagnostic"
];
```

---

## Configuration Cheat Sheet

| Setting | Default | Range | Purpose |
|---------|---------|-------|---------|
| `level` | "summary" | quiet/summary/full | Verbosity control |
| `plots` | "key" | none/key/all | Figure creation mode |
| `plotVisible` | "off" | on/off | Figure visibility |
| `maxFigures` | 8 | 1-100 | Simultaneous figure limit |
| `logToFile` | true | true/false | Write to log file |
| `useTimestamp` | false | true/false | Timestamped subdirs |

---

## File Locations

| Component | File |
|-----------|------|
| Logger | `Aging/utils/dbg.m` |
| Figure control | `Aging/utils/dbgFigure.m` |
| Figure saving | `Aging/utils/dbgSaveFig.m` |
| Diagnostics init | `Aging/utils/dbgInitDiagnostics.m` |
| Summary table | `Aging/utils/dbgSummaryTable.m` |
| Config | `Aging/pipeline/agingConfig.m` |
| Main pipeline | `Aging/Main_Aging.m` |
| Example: Stage 7 | `Aging/pipeline/stage7_reconstructSwitching.m` |
| Example: Stage 8 | `Aging/pipeline/stage8_plotting.m` |

---

## Output Structure

```
outputFolder/
  diagnostics/
    diagnostic_log.txt          ← All messages (timestamped)
    diagnostic_summary.txt      ← Key metrics
    DeltaM_overview.png         ← Key plot 1
    AFM_FM_channels.png         ← Key plot 2
    Rsw_vs_T.png                ← Key plot 3
    ...
```

---

## Common Scenarios

### Scenario 1: Production Run
```matlab
cfg = agingConfig();
cfg.dataDir = '/path/to/data';
cfg.outputFolder = '/path/to/output';
state = Main_Aging(cfg);
% Console: 10-15 key messages
% Figures: 3-8 plots saved to PNG
% Time: ~5-10 seconds
```

### Scenario 2: Interactive Debugging
```matlab
cfg = agingConfig();
cfg.debug.level = "full";       % See everything
cfg.debug.plots = "all";        % All plots visible
cfg.debug.plotVisible = "on";
state = Main_Aging(cfg);
% Console: 50+ messages
% Figures: 10+ plots visible
% Can inspect plots interactively
```

### Scenario 3: Batch Processing
```matlab
cfg = agingConfig();
cfg.debug.level = "quiet";      % Silent
cfg.debug.plots = "none";       % No figures
for dataSet = 1:100
    cfg.dataDir = getDataPath(dataSet);
    state = Main_Aging(cfg);
    % No console spam
    % No figures (faster)
    % All results logged
end
```

### Scenario 4: Parameter Sweep
```matlab
cfg = agingConfig();
cfg.debug.level = "summary";    % Minimal output
cfg.debug.plots = "none";       % No figures (faster)
cfg.debug.logToFile = true;

for param_val = [0.1, 0.5, 1.0, 2.0]
    cfg.switchParams.lambda = param_val;
    state = Main_Aging(cfg);
    % Results logged, diagnostics saved
end
```

---

## Troubleshooting

### Problem: Too much console output
**Solution:** 
```matlab
cfg.debug.level = "quiet";
```

### Problem: Too many figures open
**Solution:**
```matlab
cfg.debug.plots = "none";
% or
cfg.debug.maxFigures = 4;
```

### Problem: Can't see plots
**Solution:**
```matlab
cfg.debug.plotVisible = "on";
```

### Problem: Diagnostics not being saved
**Solution:**
```matlab
cfg.debug.logToFile = true;
cfg.debug.logFile = fullfile(cfg.outputFolder, 'diagnostic_log.txt');
```

### Problem: Each run overwrites diagnostics
**Solution:**
```matlab
cfg.debug.useTimestamp = true;
% Creates: diagnostics/20250304_143210/
```

---

## Integration Checklist

When adding debug infrastructure to a new stage:

- [ ] Import config in stage function call
- [ ] Add `dbg(cfg, "summary", ...)` for key milestones
- [ ] Replace all `fprintf()` with `dbg()` calls
- [ ] Replace all `disp()` with `dbg()` calls
- [ ] Replace `figure()` calls with `h = dbgFigure(cfg, "tag_name")`
- [ ] Wrap plot commands in `if ~isempty(h)` block
- [ ] Add `dbgSaveFig(cfg, h, "tag_name.png")` before `end`
- [ ] Define new tags in `cfg.debug.keyPlotTags` if needed
- [ ] Test with different debug levels

---

## One-Line Configuration Changes

```matlab
% Default (clean production run)
cfg = agingConfig();

% Full diagnostics
cfg.debug.level = "full"; cfg.debug.plots = "all"; cfg.debug.plotVisible = "on";

% Silent mode
cfg.debug.level = "quiet"; cfg.debug.plots = "none";

% Minimal output, save everything
cfg.debug.level = "quiet"; cfg.debug.plots = "none"; cfg.debug.logToFile = true;

% See everything, no figures
cfg.debug.level = "full"; cfg.debug.plots = "none";
```

---

## Performance Tips

| Task | Recommendation |
|------|-----------------|
| Production run | `plots="none"` for speed |
| Interactive debug | `level="full"` + `plots="all"` + `plotVisible="on"` |
| Batch processing | `level="quiet"` to reduce I/O |
| Parameter sweep | `plots="none"` + `level="summary"` |
| Publication | `level="summary"` + `plots="key"` + `plotVisible="off"` |

---

## Reference

**Verbosity precedence:** `quiet` < `summary` < `full`

**Figure modes:**
- `none`: No figures
- `key`: Only tagged plots
- `all`: Create everything

**Visibility modes:**
- `on`: Normal figures
- `off`: Efficient (hidden/saved only)

**Default folder structure:** `outputFolder/diagnostics/`

---

**Last Updated:** March 4, 2025  
**Status:** Production Ready  
**Compatibility:** MATLAB R2019b+
