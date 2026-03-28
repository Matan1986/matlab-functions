function cfg = relaxation_config_helper(userCfg)
% relaxation_config_helper - Centralized config for Relaxation v3 audit readiness
%
% Exposes 9 key parameter choices needed for robustness audits:
%   1. time_origin_mode      - which time point is t=0
%   2. fit_window_mode       - how to select fit interval
%   3. baseline_mode         - how to handle baseline/offset
%   4. interpolation_mode    - data interpolation strategy
%   5. smoothing_mode        - field/moment smoothing
%   6. derivative_mode       - use of derivative in window fallback
%   7. model_family          - log vs kww vs compare
%   8. model_selection_criterion - AIC (when mode='compare')
%   9. no_relax_threshold_mode - how to detect non-relaxing curves
%
% Usage:
%   cfg = relaxation_config_helper()                 % defaults
%   cfg = relaxation_config_helper(struct('model_family','kww'))  % override one
%
% Returns: struct with all fields documented and explicit
%
% Preserve backward-compatible DEFAULTS unless user overrides.

if nargin < 1 || isempty(userCfg)
    userCfg = struct();
end

%% ===== DEFAULT CONFIG (AUDIT SNAPSHOT) =====

cfg = struct();

%% 1. TIME_ORIGIN_MODE
% How time=0 is defined relative to data file start/measurement
%   'first_sample'      - t=0 at first data point (standard)
%   'derivative_minimum' - t=0 at dM/dt minimum (fallback location)
cfg.time_origin_mode = 'first_sample';
if isfield(userCfg, 'time_origin_mode') && ~isempty(userCfg.time_origin_mode)
    cfg.time_origin_mode = userCfg.time_origin_mode;
end

%% 2. FIT_WINDOW_MODE
% How the fit interval [t_start, t_end] is selected
%   'field_threshold'   - where |H| < Hthresh (primary)
%   'derivative_fallback' - used if field-based fails (fallback)
%   'both_available'    - both modes used, derivative is fallback
cfg.fit_window_mode = 'both_available';
if isfield(userCfg, 'fit_window_mode') && ~isempty(userCfg.fit_window_mode)
    cfg.fit_window_mode = userCfg.fit_window_mode;
end

%% 3. BASELINE_MODE
% How baseline (offset, M_inf) is handled
%   'fit_offset'     - baseline is free parameter in fit (standard)
%   'fixed_to_final' - M_inf locked to last M value
cfg.baseline_mode = 'fit_offset';
if isfield(userCfg, 'baseline_mode') && ~isempty(userCfg.baseline_mode)
    cfg.baseline_mode = userCfg.baseline_mode;
end

%% 4. INTERPOLATION_MODE
% Interpolation/resampling of data before fit
%   'none'         - use data as-is (standard)
%   'linear'       - interpolate to regular grid
cfg.interpolation_mode = 'none';
if isfield(userCfg, 'interpolation_mode') && ~isempty(userCfg.interpolation_mode)
    cfg.interpolation_mode = userCfg.interpolation_mode;
end

%% 5. SMOOTHING_MODE
% Smoothing of field and/or moment data
%   'none'              - no smoothing (standard)
%   'field_only'        - smooth H for window detection only
%   'field_and_moment'  - smooth both H and M before fit
cfg.smoothing_mode = 'field_only';
if isfield(userCfg, 'smoothing_mode') && ~isempty(userCfg.smoothing_mode)
    cfg.smoothing_mode = userCfg.smoothing_mode;
end

%% 6. DERIVATIVE_MODE
% Use of derivative in fallback and diagnostics
%   'dMdt_minimum'   - fallback uses dM/dt minimum location (standard)
%   'none'           - no derivative-based fallback (fail if field unavail)
cfg.derivative_mode = 'dMdt_minimum';
if isfield(userCfg, 'derivative_mode') && ~isempty(userCfg.derivative_mode)
    cfg.derivative_mode = userCfg.derivative_mode;
end

%% 7. MODEL_FAMILY
% Which relaxation model(s) to use
%   'log'    - logarithmic only
%   'kww'    - stretched exponential (Kohlrausch-Williams-Watts)
%   'compare' - fit both, choose by criterion
cfg.model_family = 'log';
if isfield(userCfg, 'model_family') && ~isempty(userCfg.model_family)
    cfg.model_family = userCfg.model_family;
end

%% 8. MODEL_SELECTION_CRITERION
% How to choose between models when mode='compare'
%   'AIC'  - Akaike Information Criterion (standard)
%   'BIC'  - Bayesian Information Criterion
%   'AICc' - small-sample AIC
% NOTE: Only used when model_family='compare'
cfg.model_selection_criterion = 'AIC';
if isfield(userCfg, 'model_selection_criterion') && ~isempty(userCfg.model_selection_criterion)
    cfg.model_selection_criterion = userCfg.model_selection_criterion;
end

%% 9. NO_RELAX_THRESHOLD_MODE
% How to detect and handle non-relaxing curves
%   'deltaM_threshold'  - use |dM|/mean(M) threshold (standard)
%   'slope_threshold'   - use dM/dt slope threshold
%   'both'              - either condition triggers non-relax
cfg.no_relax_threshold_mode = 'deltaM_threshold';
if isfield(userCfg, 'no_relax_threshold_mode') && ~isempty(userCfg.no_relax_threshold_mode)
    cfg.no_relax_threshold_mode = userCfg.no_relax_threshold_mode;
end

%% ===== SUPPLEMENTARY NUMERIC PARAMETERS (audit-tracked but not primary) =====

cfg.field_threshold_Oe = 1.0;
if isfield(userCfg, 'field_threshold_Oe') && ~isempty(userCfg.field_threshold_Oe)
    cfg.field_threshold_Oe = userCfg.field_threshold_Oe;
end

cfg.derivative_fallback_fraction = 0.2;
if isfield(userCfg, 'derivative_fallback_fraction') && ~isempty(userCfg.derivative_fallback_fraction)
    cfg.derivative_fallback_fraction = userCfg.derivative_fallback_fraction;
end

cfg.abs_threshold = 3e-5;
if isfield(userCfg, 'abs_threshold') && ~isempty(userCfg.abs_threshold)
    cfg.abs_threshold = userCfg.abs_threshold;
end

cfg.slope_threshold = 1e-8;
if isfield(userCfg, 'slope_threshold') && ~isempty(userCfg.slope_threshold)
    cfg.slope_threshold = userCfg.slope_threshold;
end

%% ===== PHYSICS LOGIC TOGGLES (not primary audit targets, preserved for completeness) =====

cfg.use_bohar_units = true;
if isfield(userCfg, 'use_bohar_units') && ~isempty(userCfg.use_bohar_units)
    cfg.use_bohar_units = userCfg.use_bohar_units;
end

cfg.normalize_by_mass = true;
if isfield(userCfg, 'normalize_by_mass') && ~isempty(userCfg.normalize_by_mass)
    cfg.normalize_by_mass = userCfg.normalize_by_mass;
end

cfg.trim_to_fit_window = true;
if isfield(userCfg, 'trim_to_fit_window') && ~isempty(userCfg.trim_to_fit_window)
    cfg.trim_to_fit_window = userCfg.trim_to_fit_window;
end

%% ===== FITTING CONTROL (from fitParams legacy) =====

cfg.beta_boost = false;
if isfield(userCfg, 'beta_boost') && ~isempty(userCfg.beta_boost)
    cfg.beta_boost = userCfg.beta_boost;
end

cfg.tau_boost = false;
if isfield(userCfg, 'tau_boost') && ~isempty(userCfg.tau_boost)
    cfg.tau_boost = userCfg.tau_boost;
end

cfg.time_weight = true;
if isfield(userCfg, 'time_weight') && ~isempty(userCfg.time_weight)
    cfg.time_weight = userCfg.time_weight;
end

cfg.time_weight_factor = 0.725;
if isfield(userCfg, 'time_weight_factor') && ~isempty(userCfg.time_weight_factor)
    cfg.time_weight_factor = userCfg.time_weight_factor;
end

%% ===== PLOTTING CONTROL =====

cfg.plot_level = 'summary';
if isfield(userCfg, 'plot_level') && ~isempty(userCfg.plot_level)
    cfg.plot_level = userCfg.plot_level;
end

cfg.color_scheme = 'parula';
if isfield(userCfg, 'color_scheme') && ~isempty(userCfg.color_scheme)
    cfg.color_scheme = userCfg.color_scheme;
end

end
