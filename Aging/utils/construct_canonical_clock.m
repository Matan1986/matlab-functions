function clock = construct_canonical_clock(T, observable_raw, observable_signed, cfg)
% =========================================================
% construct_canonical_clock
%
% PURPOSE:
%   Define a canonical, symmetric, audit-ready two-time clock observable
%   from raw measurements. Centralizes selector logic for both AFM (dip) 
%   and FM (background) clocks.
%
% SYNTAX:
%   clock = construct_canonical_clock(T, observable_raw, observable_signed, cfg)
%
% INPUTS:
%   T                    - Temperature vector [K] (nx1)
%   observable_raw       - Raw observable values (nx1), can be unsigned
%   observable_signed    - Signed version of observable (nx1), preserves sign
%   cfg                  - Config struct with selector settings (see below)
%
% CFG OPTIONS (all optional; defaults provided):
%
%   selector_mode        - Clock extraction selector family
%                          Allowed: 'half_range_primary' (default),
%                                   'symmetric_consensus', 'model_based',
%                                   'direct_only', 'unresolved_flag'
%
%   support_mode         - Data completeness/validity requirement
%                          Allowed: 'resolved' (default), 'censored_ok',
%                                   'minimal', 'strict'
%
%   crossing_rule        - Start/crossing point definition
%                          Allowed: 'first_point' (default), 'second_point',
%                                   'robust_percentile', 'zero_crossing'
%
%   percentile_target    - For robust_percentile crossing_rule
%                          Default: 0.50 (half-range)
%
%   sign_handling        - 'preserve' (default) or 'absolute'
%
%   min_valid_points     - Minimum points required. Default: 3
%
% OUTPUTS:
%   clock - struct with fields:
%
%   (Primary extracted value)
%     .value              - Canonical observable value (signed if preserve, abs if absolute)
%     .origin             - Source of value ('raw', 'signed_source', 'model', etc.)
%     .signed_value       - Signed version (always included for audit)
%     .absolute_value     - Absolute value (always included for audit)
%
%   (Status/support flags)
%     .support_status     - 'resolved' | 'censored' | 'extrapolated' | 'unsupported' | 'unstable'
%     .n_valid_points     - Count of finite values in observable
%     .data_range         - [min, max] of observable values
%     .is_defined         - Logical, true if value is finite
%
%   (Crossing/window information)
%     .crossing_rule_used - Which crossing rule was applied
%     .start_point_value  - Value at start point (first_point or second_point)
%     .end_point_value    - Value at end point
%     .range_traversed    - (end - start) or other span measure
%
%   (Configuration used for audit trail)
%     .selector_mode_used - Which selector was actually active
%     .config_snapshot    - Sanitized config used
%
% REMARKS:
%   - This function is a CANONICAL ABSTRACTION for two-time clock extraction
%   - It is symmetric in design: same logic applies to both dip and FM clocks
%   - Sign preservation allows downstream analysis to distinguish drop vs rise
%   - All intermediate values are stored for robustness audits
%
% =========================================================

%% -------- Default Config --------
if nargin < 4 || ~isstruct(cfg)
    cfg = struct();
end

selector_mode = getConfigField(cfg, 'selector_mode', 'half_range_primary');
support_mode  = getConfigField(cfg, 'support_mode', 'resolved');
crossing_rule = getConfigField(cfg, 'crossing_rule', 'first_point');
percentile_target = getConfigField(cfg, 'percentile_target', 0.50);
sign_handling = getConfigField(cfg, 'sign_handling', 'preserve');
min_valid_points = getConfigField(cfg, 'min_valid_points', 3);

% Normalize string inputs
selector_mode = lower(string(selector_mode));
support_mode = lower(string(support_mode));
crossing_rule = lower(string(crossing_rule));
sign_handling = lower(string(sign_handling));

%% -------- Initialize Output --------
clock = struct();
clock.selector_mode_used = char(selector_mode);
clock.support_mode_used = char(support_mode);
clock.crossing_rule_used = char(crossing_rule);
clock.origin = 'undefined';
clock.value = NaN;
clock.signed_value = NaN;
clock.absolute_value = NaN;
clock.support_status = 'unresolved';
clock.n_valid_points = 0;
clock.data_range = [NaN NaN];
clock.is_defined = false;
clock.start_point_value = NaN;
clock.end_point_value = NaN;
clock.range_traversed = NaN;
clock.min_valid_points_required = min_valid_points;
clock.config_snapshot = cfg;

%% -------- Validate Input --------
T = T(:);
observable_raw = observable_raw(:);
observable_signed = observable_signed(:);

if numel(T) ~= numel(observable_raw) || numel(T) ~= numel(observable_signed)
    clock.support_status = 'unsupported';
    return;
end

% Count valid points
valid_mask = isfinite(T) & isfinite(observable_signed) & isfinite(observable_raw);
n_valid = nnz(valid_mask);
clock.n_valid_points = n_valid;

if n_valid < min_valid_points
    clock.support_status = 'insufficient_data';
    return;
end

%% -------- Helper: Get start/end values by crossing rule --------
function [start_val, end_val] = getStartEndByRule(T_v, obs_v)
    n = numel(obs_v);
    switch crossing_rule
        case 'first_point'
            start_val = obs_v(1);
            end_val = obs_v(n);
        case 'second_point'
            if n >= 2
                start_val = obs_v(2);
            else
                start_val = obs_v(1);
            end
            end_val = obs_v(n);
        case 'robust_percentile'
            sorted_obs = sort(obs_v, 'omitnan');
            idx_at_percentile = max(1, round(percentile_target * n));
            start_val = sorted_obs(idx_at_percentile);
            end_val = obs_v(n);
        case 'zero_crossing'
            zero_cross_idx = find(sign(obs_v(1:n-1)) ~= sign(obs_v(2:n)), 1, 'first');
            if ~isempty(zero_cross_idx)
                start_val = obs_v(zero_cross_idx);
            else
                start_val = obs_v(1);
            end
            end_val = obs_v(n);
        otherwise
            start_val = obs_v(1);
            end_val = obs_v(n);
    end
end

%% -------- Extract using selector mode --------
T_v = T(valid_mask);
obs_signed_v = observable_signed(valid_mask);
obs_raw_v = observable_raw(valid_mask);

clock.data_range = [min(obs_signed_v, [], 'omitnan'), max(obs_signed_v, [], 'omitnan')];

[start_val, end_val] = getStartEndByRule(T_v, obs_signed_v);
clock.start_point_value = start_val;
clock.end_point_value = end_val;
clock.range_traversed = end_val - start_val;

% Apply selector logic (symmetric across clock families)
switch selector_mode

    case 'half_range_primary'
        % Primary selector: use half-range of observed values
        % Works equally for dip (memory depth) and FM (step magnitude)
        range_val = max(obs_signed_v, [], 'omitnan') - min(obs_signed_v, [], 'omitnan');
        if isfinite(range_val) && range_val > 0
            half_val = min(obs_signed_v, [], 'omitnan') + 0.5 * range_val;
            clock.value = half_val;
            clock.origin = 'half_range_primary';
            clock.signed_value = half_val;
            clock.absolute_value = abs(half_val);
            clock.support_status = 'resolved';
            clock.is_defined = true;
        else
            clock.support_status = 'unstable';
        end

    case 'symmetric_consensus'
        % Secondary selector: consensus of multiple crossing rules
        % Average of first_point, median, and final values
        candidate_vals = [obs_signed_v(1), ...
                          median(obs_signed_v, 'omitnan'), ...
                          obs_signed_v(end)];
        candidate_vals = candidate_vals(isfinite(candidate_vals));
        
        if ~isempty(candidate_vals)
            consensus_val = mean(candidate_vals, 'omitnan');
            clock.value = consensus_val;
            clock.origin = 'symmetric_consensus';
            clock.signed_value = consensus_val;
            clock.absolute_value = abs(consensus_val);
            clock.support_status = 'resolved';
            clock.is_defined = true;
        else
            clock.support_status = 'unstable';
        end

    case 'model_based'
        % Placeholder for model-based extraction (e.g., fit parameters)
        % Future: use Gaussian amplitude, stretched exponential, etc.
        clock.support_status = 'unresolved';
        % Not implemented; would be filled by fit-based logic

    case 'direct_only'
        % Use raw observable directly (first valid value, last value, or median)
        if n_valid >= 1
            direct_val = median(obs_signed_v, 'omitnan');
            if isfinite(direct_val)
                clock.value = direct_val;
                clock.origin = 'direct_median';
                clock.signed_value = direct_val;
                clock.absolute_value = abs(direct_val);
                clock.support_status = 'resolved';
                clock.is_defined = true;
            end
        end

    case 'unresolved_flag'
        % Mark as explicitly unresolved (for missing data, failed fits)
        clock.support_status = 'unresolved';

    otherwise
        clock.support_status = 'unsupported';
end

%% -------- Apply sign handling --------
if strcmp(sign_handling, 'absolute')
    if isfinite(clock.value)
        clock.value = abs(clock.value);
    end
end

%% -------- Apply support mode --------
switch support_mode
    case 'resolved'
        % Accept only fully resolved values
        if ~strcmp(clock.support_status, 'resolved')
            clock.value = NaN;
            clock.is_defined = false;
        end
    case 'censored_ok'
        % Accept resolved or censored
        clock.is_defined = isfinite(clock.value);
    case 'minimal'
        % Accept all finite values
        clock.is_defined = isfinite(clock.value);
    case 'strict'
        % Accept only if support_status explicitly says resolved, reject otherwise
        if ~strcmp(clock.support_status, 'resolved')
            clock.value = NaN;
            clock.is_defined = false;
        end
end

end

%% ========== HELPER FUNCTIONS ==========

function val = getConfigField(cfg, field, default)
% Safely retrieve config field with default fallback
if isstruct(cfg) && isfield(cfg, field)
    val = cfg.(field);
    if isempty(val)
        val = default;
    end
else
    val = default;
end
end
