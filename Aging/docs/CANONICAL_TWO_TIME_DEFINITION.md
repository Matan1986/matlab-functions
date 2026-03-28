# Aging Module: Canonical Two-Time Clock Definition Layer

## Executive Summary

This document describes the **canonical two-time definition layer** hardening for the Aging module. The changes prepare the module for robustness audits by centralizing two-time observable extraction into a symmetric, audit-ready framework.

### Key Goals Accomplished

1. **Centralized Selector Logic** - Single abstraction for clock extraction applies to both dip and FM
2. **Symmetric Treatment** - Dip and FM clocks use the same family of selector modes
3. **Sign Preservation** - Sign information retained longer for directional analysis
4. **Explicit Config** - Crossing rules, selector modes, and support conditions are configurable
5. **Audit-Ready Outputs** - All intermediate values, status flags, and selector choices preserved

## Architecture

### New Component: `construct_canonical_clock.m`

**Location**: `Aging/utils/construct_canonical_clock.m`

**Purpose**: Provides a canonical abstraction for two-time clock extraction. Centralizes selector logic that previously was implemented asymmetrically for dip vs FM.

**Design Principle**: A single helper function that treats both clock families symmetrically, with explicit config-driven selector selection.

**Inputs**:
- `T` - Temperature array (nx1)
- `observable_raw` - Unsigned observable values
- `observable_signed` - Signed observable values (preserves direction)
- `cfg` - Configuration struct with selector modes

**Key Config Fields**:
- `selector_mode` : 'half_range_primary' | 'symmetric_consensus' | 'model_based' | 'direct_only' | 'unresolved_flag'
- `support_mode` : 'resolved' | 'censored_ok' | 'minimal' | 'strict'
- `crossing_rule` : 'first_point' | 'second_point' | 'robust_percentile' | 'zero_crossing'
- `sign_handling` : 'preserve' | 'absolute'
- `percentile_target` : (for robust_percentile, default 0.5)
- `min_valid_points` : minimum data points required (default 3)

**Outputs** (struct):
- `.value` - Canonical extracted value
- `.signed_value` - Explicit signed version
- `.absolute_value` - Explicit absolute version
- `.support_status` - 'resolved' | 'censored' | 'extrapolated' | 'unsupported' | 'unstable'
- `.origin` - Which selector method produced the value
- `.n_valid_points` - Count of finite data points
- `.data_range` - [min, max] of observable
- `.crossing_rule_used` - Which crossing/start rule applied
- `.selector_mode_used` - Which selector mode active
- `.config_snapshot` - Config used for audit trail

### Integration Point: `stage4_analyzeAFM_FM.m` - Canonical Layer Section

**Location**: Lines 206-287 (new canonical section)

**Behavior**:
- Activates when `cfg.useCanonicalClocks = true` (expert mode)
- Applies canonical clock extraction to BOTH dip and FM clocks
- Preserves all existing legacy outputs unchanged
- Adds new canonical outputs with `tau_*_canonical` naming

**Dip Clock Extraction** (lines 213-242):
```
- Window: dip_window region [Tp-hw, Tp+hw]
- Observable: -DeltaM in window (signed: negative=memory)
- Selector: configured via cfg.dip_selector_mode (dip_support_mode, dip_crossing_rule)
- Outputs added: tau_dip_canonical, tau_dip_signed, tau_dip_absolute,
                 tau_dip_support_status, tau_dip_selector_mode, tau_dip_crossing_mode,
                 tau_dip_n_valid_points, tau_dip_range, tau_dip_clock_struct
```

**FM Clock Extraction** (lines 245-277):
```
- Observable: FM_step_raw (scalar, signed: positive=drop)
- Selector: configured via cfg.fm_selector_mode (fm_support_mode, fm_crossing_rule)
- Outputs added: tau_fm_canonical, tau_fm_signed, tau_fm_absolute,
                 tau_fm_support_status, tau_fm_selector_mode, tau_fm_crossing_mode,
                 tau_fm_n_valid_points, tau_fm_range, tau_fm_clock_struct
```

## New Configuration Fields

All fields are **optional**. If omitted, sensible defaults apply.

### Canonical Clock Enable Flag
```
cfg.useCanonicalClocks = true;   % Default: false (backward compatible)
```

### Dip Clock Selectors
```
cfg.dip_selector_mode = 'half_range_primary';     % see construct_canonical_clock.m
cfg.dip_support_mode = 'resolved';                 % see construct_canonical_clock.m
cfg.dip_crossing_rule = 'first_point';             % see construct_canonical_clock.m
cfg.dip_percentile_target = 0.50;                  % for robust_percentile mode
```

### FM Clock Selectors
```
cfg.fm_selector_mode = 'half_range_primary';      % see construct_canonical_clock.m
cfg.fm_support_mode = 'resolved';                  % see construct_canonical_clock.m
cfg.fm_crossing_rule = 'first_point';              % see construct_canonical_clock.m
cfg.fm_percentile_target = 0.50;                   % for robust_percentile mode
```

## New Output Fields (Per Pause Run)

### Dip Clock Outputs
```
run.tau_dip_canonical           [scalar]  Canonical dip value
run.tau_dip_signed              [scalar]  Signed version (negative=deepens)
run.tau_dip_absolute            [scalar]  Absolute magnitude
run.tau_dip_selector_mode       [char]    'half_range_primary' etc
run.tau_dip_crossing_mode       [char]    'first_point' etc
run.tau_dip_support_status      [char]    'resolved'|'censored'|'unstable'|...
run.tau_dip_n_valid_points      [int]     Count of valid dip measurements
run.tau_dip_range               [1x2]     [min, max] of dip observable
run.tau_dip_clock_struct        [struct]  Full canonical clock output (advanced)
```

### FM Clock Outputs
```
run.tau_fm_canonical            [scalar]  Canonical FM value
run.tau_fm_signed               [scalar]  Signed version (positive=drop)
run.tau_fm_absolute             [scalar]  Absolute magnitude
run.tau_fm_selector_mode        [char]    'half_range_primary' etc
run.tau_fm_crossing_mode        [char]    'first_point' etc
run.tau_fm_support_status       [char]    'resolved'|'censored'|'unstable'|...
run.tau_fm_n_valid_points       [int]     Count valid (typically 2 for plateaus)
run.tau_fm_range                [1x2]     [min, max] of FM observable
run.tau_fm_clock_struct         [struct]  Full canonical clock output (advanced)
```

## Backward Compatibility

**All existing outputs remain unchanged:**
- `Dip_depth`, `Dip_area`, `AFM_amp`, `AFM_area` - unchanged
- `FM_step_raw`, `FM_step_mag`, `FM_abs`, `FM_step_err` - unchanged
- `baseline_*`, `FM_plateau_*` diagnostics - unchanged

**Canonical fields are additive only:**
- New fields have distinct `tau_*_canonical` naming
- Existing scripts ignoring new fields will work unchanged
- New fields created only when `cfg.useCanonicalClocks = true`

**Migration Path:**
1. Keep existing analysis scripts unchanged (backward compatible)
2. Enable canonical layer in test runs: `cfg.useCanonicalClocks = true`
3. Validate canonical outputs against legacy outputs
4. Gradually migrate analysis to use canonical fields where beneficial

## Design Symmetries

### Problem: Previous Asymmetries

| Aspect | Dip (AFM) | FM (Background) | Issue |
|--------|-----------|-----------------|-------|
| **Selector Logic** | Two sources (direct + fit) | Single hard path | FM has no fallback |
| **Sign Handling** | Lost early (always abs) | Preserved as `FM_step_raw` | Inconsistent |
| **Window Definition** | Exclusive bounds `(T > lo) & (T < hi)` | Inclusive `T >= lo & T <= hi` | Inconsistent |
| **Component Source** | Mix of smooth + sharp | Only smooth plateaus | Different bases |

### Solution: Canonical Symmetry

**Both clocks now use**:
1. Explicit selector mode (configurable, same family)
2. Sign preservation (stored separately from absolute value)
3. Consistent boundary treatment (both in construct_canonical_clock)
4. Full status tracking (resolved | censored | unstable | etc.)

### Selector Modes Available to Both

1. **`half_range_primary`** - Uses 50th percentile (default, robust)
2. **`symmetric_consensus`** - Average of first, median, last values
3. **`model_based`** - Fit parameters (placeholder for future)
4. **`direct_only`** - Direct median of observable
5. **`unresolved_flag`** - Explicitly mark unresolved (for missing data)

## Robustness Features

### Support Status Tracking

Each clock provides explicit support status:
- **`resolved`** - Fully determined by data and config
- **`censored`** - Partial/edge data but valid extraction
- **`extrapolated`** - Outside measurement range, quality reduced
- **`unsupported`** - Failed validation, no fallback
- **`unstable`** - Range too small or other quality flag

### Sign Preservation for Directionality

- **Dip signed**: negative = memory deepens, positive = reverses (unusual)
- **FM signed**: positive = drop in step, negative = rise (directional info)

This allows downstream analysis to detect and flag directional anomalies.

### Full Clock Struct for Advanced Audits

Each pause run stores `tau_*_clock_struct` with all intermediate values:
- `start_point_value`, `end_point_value`, `range_traversed`
- `data_range` [min, max]
- `config_snapshot` (config used)
- `origin` (which selector method)

## Example Configuration for Test/Production Runs

### Conservative (Legacy-Compatible)
```
cfg.useCanonicalClocks = false;  % Default, no canonical outputs
```

### Audit-Ready (Recommended for Future Robustness Tests)
```
cfg.useCanonicalClocks = true;
cfg.dip_selector_mode = 'half_range_primary';
cfg.dip_support_mode = 'resolved';
cfg.dip_crossing_rule = 'first_point';
cfg.fm_selector_mode = 'half_range_primary';
cfg.fm_support_mode = 'resolved';
cfg.fm_crossing_rule = 'first_point';
```

### Strict Validation (for Robustness Audits)
```
cfg.useCanonicalClocks = true;
cfg.dip_selector_mode = 'half_range_primary';
cfg.dip_support_mode = 'strict';      % Only resolved values
cfg.dip_crossing_rule = 'robust_percentile';
cfg.dip_percentile_target = 0.50;
cfg.fm_selector_mode = 'half_range_primary';
cfg.fm_support_mode = 'strict';
cfg.fm_crossing_rule = 'robust_percentile';
cfg.fm_percentile_target = 0.50;
```

## Files Modified

### New Files Created
1. `Aging/utils/construct_canonical_clock.m` - Central clock constructor (180 lines)
2. `Aging/docs/canonical_clock_config_template.m` - Config documentation (120 lines)
3. `Aging/docs/CANONICAL_TWO_TIME_DEFINITION.md` - This design document

### Files Modified
1. `Aging/pipeline/stage4_analyzeAFM_FM.m` - Added canonical layer (lines 206-287, ~80 lines added)

## Scope of Changes

- **Lines Added**: ~380 total (helper + integration + docs)
- **Lines Modified**: ~80 in stage4 orchestrator
- **Files Changed**: 1 existing (stage4), 2 helper/doc files created
- **Lines Deleted**: 0 (additive only, backward compatible)

## Robustness Impact

### Before (Asymmetric)
- Dip and FM extracted with different logic
- Sign information lost early for dip
- No explicit status tracking
- Difficult to audit selector choices

### After (Canonical)
- Both clocks use symmetric, configurable selectors
- Sign preserved for both, separated from absolute value
- Explicit support status for each clock
- Selector mode and crossing rule stored in output
- Full clock struct available for advanced audits
- Ready for perturbation tests and robustness sweeps

## Future Extensions

### Placeholder: Model-Based Extraction
`selector_mode = 'model_based'` is reserved but not fully implemented. Future work could add:
- Gaussian fit amplitude as alternative dip selector
- Stretched exponential parameters for aging rate

### Placeholder: Zero-Crossing Rule
`crossing_rule = 'zero_crossing'` defined but not implemented. Could enable:
- Finding sign-change points in noisy data
- Detection of reversal in memory direction

These are mentioned in construct_canonical_clock.m to enable future expansion without refactoring.

## Validation & Testing

### Backward Compatibility Check
```
% Legacy script (unchanged)
cfg.useCanonicalClocks = false;
state = stage4_analyzeAFM_FM(state, cfg);
% All existing outputs present and unchanged
```

### Canonical Layer Check
```
% New script
cfg.useCanonicalClocks = true;
cfg.dip_selector_mode = 'half_range_primary';
state = stage4_analyzeAFM_FM(state, cfg);
% New tau_*_canonical fields populated
% Legacy fields still present
assert(all(isfield(state.pauseRuns, 'Dip_depth')))  % Still exists
assert(all(isfield(state.pauseRuns, 'tau_dip_canonical')))  % Now also exists
```

### Symmetry Check
```
% Both clocks use same logic
assert(strcmp(cfg.dip_selector_mode, cfg.fm_selector_mode))
assert(strcmp(cfg.dip_crossing_rule, cfg.fm_crossing_rule))
% Status fields structured identically
assert(isfield(run, 'tau_dip_support_status'))
assert(isfield(run, 'tau_fm_support_status'))
```

## Known Limitations

1. **FM Clock Data Limitation**: FM is extracted at scalar level (plateau average), not as array. Synthetic T=[0;1] used in construct_canonical_clock for consistency, but all FM observations always have same value.
   - Mitigation: Full FM_plateau_* diagnostics still available for detailed analysis

2. **Model-Based Selector Not Yet Implemented**: Placeholder present, requires future fit integration.
   - Mitigation: 'half_range_primary' and 'symmetric_consensus' provide practical alternatives

3. **Zero-Crossing Rule Not Yet Implemented**: Placeholder present.
   - Mitigation: 'robust_percentile' provides explicit start point selection

## References

- **Main Aging Pipeline**: `Aging/Main_Aging.m`
- **Stage 4 Orchestrator**: `Aging/pipeline/stage4_analyzeAFM_FM.m`
- **AFM/FM Components**: `Aging/models/analyzeAFM_FM_components.m`
- **Stage 5 (Fitting)**: `Aging/pipeline/stage5_fitFMGaussian.m`
- **Survey Results**: docs/repo_execution_rules.md (source of requirements)

## Verdicts

- **AGING_TWO_TIME_LAYER_CENTRALIZED** = YES (construct_canonical_clock.m + stage4 integration)
- **AGING_DIP_FM_SELECTOR_SYMMETRIZED** = YES (same selector family applies to both)
- **AGING_SIGN_PRESERVED_LONGER** = YES (tau_dip_signed, tau_fm_signed separate fields)
- **AGING_STATUS_OUTPUTS_EXPLICIT** = YES (tau_*_support_status, crossing_rule_used, selector_mode_used)
- **AGING_AUDIT_READY_IMPROVED** = YES (full clock_struct stored, config snapshot included)

---

**Document**: CANONICAL_TWO_TIME_DEFINITION.md  
**Created**: 2026-03-28  
**Scope**: Aging Module Hardening for Robustness Audits  
**Status**: Ready for Audit-Driven Robustness Testing
