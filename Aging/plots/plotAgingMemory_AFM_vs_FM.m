function plotAgingMemory_AFM_vs_FM(pauseRuns, fontsize, showErrors, normalizeAFM_FM, cfg)
% ============================================================
% DIAGNOSTIC PLOT - AFM/FM vs Tp
%
% This function provides a simple visualization of AFM and FM
% metrics for debugging and inspection purposes.
%
% ------------------------------------------------------------
% STATUS:
% - NOT the canonical figure for publication
% - NOT the default direct decomposition visualization
%
% The canonical paper-ready figure should be generated using
% a styled plot based on DIRECT observables (AFM_RMS, FM_direct).
%
% ------------------------------------------------------------
% USE CASE:
% - quick inspection
% - debugging
% ============================================================
% =========================================================
% plotAgingMemory_AFM_vs_FM
%
% PURPOSE:
%   Plot AFM and FM metrics vs pause temperature in a two-panel figure.
%
% INPUTS:
%   pauseRuns       - struct array with AFM/FM metrics
%   fontsize        - base font size
%   showErrors      - toggle error bars
%   normalizeAFM_FM - normalize AFM/FM axes if true
%   cfg             - optional config struct (uses existing fields only):
%                     AFM_metric_main, allowSignedFM
%
% OUTPUTS:
%   none (creates figure)
%
% Physics meaning:
%   AFM = dip height/area metric
%   FM  = background step magnitude
%
% =========================================================

%% ---------------- Defaults ----------------
if nargin < 2 || isempty(fontsize)
    fontsize = 16;
end
if nargin < 3 || isempty(showErrors)
    showErrors = false;
end
if nargin < 4 || isempty(normalizeAFM_FM)
    normalizeAFM_FM = false;
end
if nargin < 5 || isempty(cfg)
    cfg = struct();
end

%% ---------------- Extract pause temperatures ----------------
Tp = [pauseRuns.waitK];

%% ---------------- Determine AFM dip metric ----------------
if isfield(cfg, 'AFM_metric_main') && ~isempty(cfg.AFM_metric_main)
    dipMetric = lower(string(cfg.AFM_metric_main));
elseif isfield(pauseRuns,'dipMetric')
    dipMetric = lower(string(pauseRuns(1).dipMetric));
else
    dipMetric = "height";   % fallback for legacy runs
end

switch dipMetric
    case "height"
        AFM_val     = [pauseRuns.AFM_amp];
        if isfield(pauseRuns, 'AFM_amp_err')
            AFM_val_err = [pauseRuns.AFM_amp_err];
        else
            AFM_val_err = NaN(size(AFM_val));
        end
        AFM_label   = 'AFM dip height';
    case "area"
        AFM_val     = [pauseRuns.AFM_area];
        if isfield(pauseRuns, 'AFM_area_err')
            AFM_val_err = [pauseRuns.AFM_area_err];
        else
            AFM_val_err = NaN(size(AFM_val));
        end
        AFM_label   = 'AFM dip area';
    case "rms"
        % RMS: canonical direct AFM observable
        AFM_val     = [pauseRuns.AFM_RMS];
        AFM_val_err = NaN(size(AFM_val));
        AFM_label   = 'AFM dip RMS';
    otherwise
        error('Unknown dipMetric: %s', dipMetric);
end

%% ---------------- FM data ----------------
useSignedFM = true;  % default preserves historical signed FM plotting
if isfield(cfg, 'allowSignedFM') && ~isempty(cfg.allowSignedFM)
    useSignedFM = logical(cfg.allowSignedFM);
end

FM_err = NaN(1, numel(pauseRuns));
if useSignedFM
    if isfield(pauseRuns, 'FM_signed')
        FM_step = [pauseRuns.FM_signed];
    elseif isfield(pauseRuns, 'FM_step_raw')
        FM_step = [pauseRuns.FM_step_raw];
    else
        FM_step = [pauseRuns.FM_step_mag];
    end
    FM_label = 'FM step';
else
    if isfield(pauseRuns, 'FM_abs')
        FM_step = [pauseRuns.FM_abs];
    elseif isfield(pauseRuns, 'FM_step_mag')
        FM_step = abs([pauseRuns.FM_step_mag]);
    else
        FM_step = abs([pauseRuns.FM_step_raw]);
    end
    FM_label = 'FM step magnitude';
end

if isfield(pauseRuns,'FM_step_err')
    FM_err = [pauseRuns.FM_step_err];
end

%% ---------------- Valid masks ----------------
validAFM = isfinite(Tp) & isfinite(AFM_val);
pipelineValidFM = true(size(Tp));
if isfield(pauseRuns, 'FM_plateau_valid')
    pipelineValidFM = logical([pauseRuns.FM_plateau_valid]);
end
validFM  = isfinite(Tp) & isfinite(FM_step) & pipelineValidFM;

%% ---------------- Optional normalization ----------------
if normalizeAFM_FM

    if any(validAFM)
        AFM_norm = max(abs(AFM_val(validAFM)));
        if AFM_norm > 0
            AFM_val     = AFM_val     / AFM_norm;
            AFM_val_err = AFM_val_err / AFM_norm;
        end
    end

    if any(validFM)
        FM_norm = max(abs(FM_step(validFM)));
        if FM_norm > 0
            FM_step = FM_step / FM_norm;
            FM_err  = FM_err  / FM_norm;
        end
    end
end

%% ---------------- Axes limits ----------------
if any(isfinite(Tp))
    xlim_common = [min(Tp(isfinite(Tp))) max(Tp(isfinite(Tp)))];
else
    xlim_common = [0 1];
end

%% ---------------- Figure ----------------
figure('Color','w','Name','AFM vs FM aging memory components');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

%% ==========================================================
% Top: AFM
%% ==========================================================
nexttile; hold on;

if showErrors && any(isfinite(AFM_val_err(validAFM))) && any(AFM_val_err(validAFM) > 0)
    errorbar(Tp(validAFM), AFM_val(validAFM), AFM_val_err(validAFM), ...
        'o-', 'LineWidth',1.6, 'MarkerSize',5, 'CapSize',6);
else
    plot(Tp(validAFM), AFM_val(validAFM), 'o-', ...
        'LineWidth',1.6, 'MarkerSize',5);
end

xlim(xlim_common);

if normalizeAFM_FM
    ylabel([AFM_label ' (norm.)']);
else
    ylabel(AFM_label);
end

box on;

%% ==========================================================
% Bottom: FM
%% ==========================================================
nexttile; hold on;

if showErrors && any(isfinite(FM_err(validFM))) && any(FM_err(validFM) > 0)
    errorbar(Tp(validFM), FM_step(validFM), FM_err(validFM), ...
        'o-', 'LineWidth',1.6, 'MarkerSize',5, 'CapSize',6);
else
    plot(Tp(validFM), FM_step(validFM), 'o-', ...
        'LineWidth',1.6, 'MarkerSize',5);
end

xlim(xlim_common);
xlabel('Pause temperature T_p (K)');

if normalizeAFM_FM
    ylabel([FM_label ' (norm.)']);
else
    ylabel(FM_label);
end

box on;

%% ---------------- Formatting ----------------
ax = gca;
ax.FontName   = 'Times New Roman';
ax.FontSize   = fontsize;
ax.LineWidth  = 1.2;
ax.TickDir    = 'in';     % PRL style
ax.Box        = 'on';
ax.Layer      = 'top';
ax.XMinorTick = 'on';
ax.YMinorTick = 'on';

end
