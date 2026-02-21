function plotAgingMemory_AFM_vs_FM(pauseRuns, fontsize, showErrors, normalizeAFM_FM)
% plotAgingMemory_AFM_vs_FM
% ------------------------------------------------------------
% Panel-style analysis figure:
%   (top)    AFM memory metric vs pause temperature
%   (bottom) FM background step magnitude vs pause temperature
%
% AFM metric (height / area) is determined automatically from
% pauseRuns(i).dipMetric as set in analyzeAFM_FM_components.
% ------------------------------------------------------------

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

%% ---------------- Extract pause temperatures ----------------
Tp = [pauseRuns.waitK];

%% ---------------- Determine AFM dip metric ----------------
if isfield(pauseRuns,'dipMetric')
    dipMetric = lower(string(pauseRuns(1).dipMetric));
else
    dipMetric = "height";   % fallback for legacy runs
end

switch dipMetric
    case "height"
        AFM_val     = [pauseRuns.AFM_amp];
        AFM_val_err = [pauseRuns.AFM_amp_err];
        AFM_label   = 'AFM dip height';
    case "area"
        AFM_val     = [pauseRuns.AFM_area];
        AFM_val_err = [pauseRuns.AFM_area_err];
        AFM_label   = 'AFM dip area';
    otherwise
        error('Unknown dipMetric: %s', dipMetric);
end

%% ---------------- FM data ----------------
FM_step = [pauseRuns.FM_step_mag];

FM_err = NaN(size(FM_step));
if isfield(pauseRuns,'FM_step_err')
    FM_err = [pauseRuns.FM_step_err];
end

%% ---------------- Valid masks ----------------
validAFM = isfinite(Tp) & isfinite(AFM_val);
validFM  = isfinite(Tp) & isfinite(FM_step);

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
    ylabel('FM step (norm.)');
else
    ylabel('FM step');
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
