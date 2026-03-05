function physicsContext = dbgExtractPhysicsContext(cfg, result, state)
% =========================================================
% dbgExtractPhysicsContext — Extract physical reconstruction context
% =========================================================
%
% PURPOSE:
%   Extract metadata about the reconstruction for comprehensive diagnostics.
%   Allows physicists to understand the measurement without opening MATLAB.
%
% INPUTS:
%   cfg    - configuration struct with switchParams and current info
%   result - stage7 reconstruction output struct
%   state  - pipeline state struct
%
% OUTPUT:
%   physicsContext - struct with fields:
%     • reference_current_mA
%     • available_currents_mA
%     • n_pause_runs
%     • temperature_min_K
%     • temperature_max_K
%     • n_temperature_points
%     • fit_window_min_K
%     • fit_window_max_K
%     • reconstruction_mode
%
% =========================================================

physicsContext = struct();

% =========================================================
% 1. Reference current (primary measurement)
% =========================================================
if isfield(cfg, 'current_mA')
    physicsContext.reference_current_mA = cfg.current_mA;
else
    physicsContext.reference_current_mA = NaN;
end

% =========================================================
% 2. Available currents for multi-current analysis
% =========================================================
availableCurrents = [];

% Check all known current fields
currentFields = {'Rsw_15mA', 'Rsw_20mA', 'Rsw_25mA', 'Rsw_30mA', 'Rsw_35mA', 'Rsw_45mA'};
currentValues = [15, 20, 25, 30, 35, 45];

for i = 1:numel(currentFields)
    if isfield(cfg, currentFields{i}) && ~isempty(cfg.(currentFields{i}))
        availableCurrents = [availableCurrents, currentValues(i)];
    end
end

if ~isempty(availableCurrents)
    physicsContext.available_currents_mA = sort(availableCurrents);
else
    physicsContext.available_currents_mA = physicsContext.reference_current_mA;
end

% =========================================================
% 3. Pause run information
% =========================================================
if isfield(state, 'pauseRuns')
    physicsContext.n_pause_runs = numel(state.pauseRuns);
    
    % Extract pause temperatures
    pauseTempK = [state.pauseRuns.waitK];
    physicsContext.pause_temperatures_K = sort(unique(pauseTempK(:)));
else
    physicsContext.n_pause_runs = NaN;
    physicsContext.pause_temperatures_K = [];
end

% =========================================================
% 4. Temperature grid for reconstruction
% =========================================================
if isfield(cfg, 'Tsw') && ~isempty(cfg.Tsw)
    Tsw = cfg.Tsw(:);
    physicsContext.temperature_min_K = min(Tsw);
    physicsContext.temperature_max_K = max(Tsw);
    physicsContext.n_temperature_points = numel(Tsw);
    physicsContext.temperature_range_K = max(Tsw) - min(Tsw);
    physicsContext.temperature_grid_K = Tsw(:).';
else
    physicsContext.temperature_min_K = NaN;
    physicsContext.temperature_max_K = NaN;
    physicsContext.n_temperature_points = 0;
    physicsContext.temperature_range_K = NaN;
end

% =========================================================
% 5. Fitting window
% =========================================================
if isfield(cfg, 'switchParams')
    params = cfg.switchParams;
    if isfield(params, 'fitTmin')
        physicsContext.fit_window_min_K = params.fitTmin;
    else
        physicsContext.fit_window_min_K = NaN;
    end
    if isfield(params, 'fitTmax')
        physicsContext.fit_window_max_K = params.fitTmax;
    else
        physicsContext.fit_window_max_K = NaN;
    end
else
    physicsContext.fit_window_min_K = NaN;
    physicsContext.fit_window_max_K = NaN;
end

% =========================================================
% 6. Reconstruction mode
% =========================================================
if isfield(cfg, 'switchingMetricMode')
    physicsContext.reconstruction_mode = cfg.switchingMetricMode;
else
    physicsContext.reconstruction_mode = 'unknown';
end

% =========================================================
% 7. Reconstruction results (if available)
% =========================================================
if isfield(result, 'R2') && ~isnan(result.R2)
    physicsContext.fit_quality_R2 = result.R2;
else
    physicsContext.fit_quality_R2 = NaN;
end

if isfield(result, 'lambda') && ~isnan(result.lambda)
    physicsContext.coexistence_parameter_lambda = result.lambda;
else
    physicsContext.coexistence_parameter_lambda = NaN;
end

if isfield(result, 'a') && ~isnan(result.a)
    physicsContext.reconstruction_coeff_a = result.a;
else
    physicsContext.reconstruction_coeff_a = NaN;
end

if isfield(result, 'b') && ~isnan(result.b)
    physicsContext.reconstruction_coeff_b = result.b;
else
    physicsContext.reconstruction_coeff_b = NaN;
end

% =========================================================
% 8. Sample and dataset info
% =========================================================
if isfield(cfg, 'datasetName')
    physicsContext.dataset_name = cfg.datasetName;
else
    physicsContext.dataset_name = 'unknown';
end

if isfield(cfg, 'sample_name')
    physicsContext.sample_name = cfg.sample_name;
else
    physicsContext.sample_name = 'MG119';
end

end
