%% Configuration: Canonical Two-Time Clock Extraction
%
% This document defines the new config flags for audit-ready two-time
% clock extraction in the Aging module (stage 4, canonical layer).
%
% All flags are OPTIONAL and provide sensible defaults if omitted.
% Backward compatibility: existing scripts will work unchanged.
% Audit readiness: new fields populated only when explicitly enabled.
%
% =========================================================

% Enable canonical two-time clock extraction (expert mode)
cfg.useCanonicalClocks = true;

% ====== DIP (AFM) CLOCK CONFIGURATION ======
%
% Selector mode for dip clock extraction:
%   'half_range_primary' (default) - half of observed range
%   'symmetric_consensus'           - consensus of multiple estimates
%   'model_based'                   - fit-parameter based (future)
%   'direct_only'                   - direct median
%   'unresolved_flag'               - explicitly unresolved
%
cfg.dip_selector_mode = 'half_range_primary';

% Support/validity requirement for dip clock:
%   'resolved' (default)   - must be fully resolved
%   'censored_ok'          - accept censored/partial data
%   'minimal'              - accept any finite value
%   'strict'               - reject unless explicitly resolved
%
cfg.dip_support_mode = 'resolved';

% Crossing/start-point definition for dip:
%   'first_point' (default)      - use first measurement
%   'second_point'               - use second measurement (skip first)
%   'robust_percentile'          - percentile-based start (see dip_percentile_target)
%   'zero_crossing'              - find sign change point
%
cfg.dip_crossing_rule = 'first_point';

% Percentile target for robust_percentile crossing rule
% Default: 0.50 (half-range)
%
cfg.dip_percentile_target = 0.50;

% ====== FM (BACKGROUND) CLOCK CONFIGURATION ======
%
% Selector mode for FM clock extraction (same options as dip):
%
cfg.fm_selector_mode = 'half_range_primary';

% Support/validity requirement for FM clock:
%
cfg.fm_support_mode = 'resolved';

% Crossing/start-point definition for FM:
%
cfg.fm_crossing_rule = 'first_point';

% Percentile target for FM robust_percentile mode:
%
cfg.fm_percentile_target = 0.50;

% ========================================================
% OUTPUT FIELDS ADDED BY CANONICAL LAYER
% ========================================================
%
% For each pause run, the following NEW fields are populated:
%
% DIP CLOCK OUTPUTS:
%   .tau_dip_canonical           - Canonical dip value (signed if preserve mode)
%   .tau_dip_signed              - Explicit signed version (memory depth)
%   .tau_dip_absolute            - Explicit absolute value
%   .tau_dip_selector_mode       - Which selector mode was actually used
%   .tau_dip_crossing_mode       - Which crossing rule was used
%   .tau_dip_support_status      - 'resolved'|'censored'|'extrapolated'|'unsupported'|'unstable'
%   .tau_dip_n_valid_points      - Count of valid dip measurements
%   .tau_dip_range               - [min, max] of dip values
%   .tau_dip_clock_struct        - Full canonical clock struct (for advanced audits)
%
% FM CLOCK OUTPUTS:
%   .tau_fm_canonical            - Canonical FM value (signed if preserve mode)
%   .tau_fm_signed               - Explicit signed version (drop vs rise)
%   .tau_fm_absolute             - Explicit absolute value
%   .tau_fm_selector_mode        - Which selector mode was actually used
%   .tau_fm_crossing_mode        - Which crossing rule was used
%   .tau_fm_support_status       - 'resolved'|'censored'|'extrapolated'|'unsupported'|'unstable'
%   .tau_fm_n_valid_points       - Count of valid FM measurements (typically 2 for plateaus)
%   .tau_fm_range                - [min, max] of FM values
%   .tau_fm_clock_struct         - Full canonical clock struct (for advanced audits)
%
% ========================================================
% BACKWARD COMPATIBILITY
% ========================================================
%
% Existing output fields remain UNCHANGED:
%   .Dip_depth        - Original (abs) dip amplitude
%   .Dip_area         - Original dip area (direct or fit)
%   .AFM_amp          - Original AFM amplitude
%   .FM_step_raw      - Original FM step (signed)
%   .FM_step_mag      - Original FM magnitude
%   .FM_abs           - Original FM absolute value
%   .baseline_*       - Original baseline diagnostics
%
% New canonical fields are ADDITIVE and do NOT override legacy fields.
% Scripts ignoring canonical fields will continue to work unchanged.
%
% ========================================================
% EXAMPLE USAGE IN ANALYSIS SCRIPTS
% ========================================================
%
% To use canonical clocks in downstream analysis:
%
%   % Load aging dataset with canonical clocks
%   dataTbl = readtable(csvPath);
%   
%   % Access canonical dip clock with status
%   valid_dip = strcmp(dataTbl.tau_dip_support_status, 'resolved');
%   tau_dip = dataTbl.tau_dip_canonical(valid_dip);
%   
%   % Use sign-preserved version for directional analysis
%   dip_sign = sign(dataTbl.tau_dip_signed);  % +1 = memory deepens, -1 = reverses
%   
%   % Access FM clock with selector transparency
%   fm_selector_used = dataTbl.tau_fm_selector_mode;
%   tau_fm = dataTbl.tau_fm_canonical;
%
