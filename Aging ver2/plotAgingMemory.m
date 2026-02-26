function plotAgingMemory(T_no, M_no, pauseRuns, color_scheme, fontsize, ...
    linewidth, sample_name, Bohar_units, offsetMode, offsetPercent, ...
    dip_window_K, colorRange, useAutoYScale)

% plotAgingMemory — Draws M(T) and ΔM(T) for all runs
% SAFE, paper-grade version:
% • No legacy autoScaleYAxis
% • Data scaling (not ticks)
% • Global order-of-magnitude scaling with ylabel reporting
% • Offsets remain physical

% ---------------- DEFAULTS ----------------
if nargin < 12 || isempty(colorRange)
    colorRange = [0 1];
end
if nargin < 13 || isempty(useAutoYScale)
    useAutoYScale = false;
end
if nargin < 9  || isempty(offsetMode)
    offsetMode = 'none';
end
if nargin < 10 || isempty(offsetPercent)
    offsetPercent = 0;
end
if nargin < 11
    dip_window_K = [];
end

% ---------------- USER CONTROL ----------------
SHOW_PAUSES_K = [10 14 18 22 26];   % pauses to mark in ΔM(T)
% ---------------------------------------------

% ---------------- COLORS ----------------
cols_full = pickColors(numel(pauseRuns), color_scheme);

n = size(cols_full,1);
i1 = max(1, round(colorRange(1) * n));
i2 = min(n, round(colorRange(2) * n));
idx = round(linspace(i1, i2, n));
cols = cols_full(idx,:);

lw_ref = linewidth + 1.0;
lw_run = linewidth + 0.2;

% ---------------- UNITS ----------------
if Bohar_units
    unitStr = '\mu_B / Co';
else
    unitStr = 'emu/g';
end

% ============================================================
% AUTO SCALE — M
% ============================================================
scaleFactor_M = 1;
scalePower_M  = 0;

if useAutoYScale
    yProbe = M_no(:);
    for i = 1:numel(pauseRuns)
        yProbe = [yProbe; pauseRuns(i).M(:)]; %#ok<AGROW>
    end
    scalePower_M  = chooseAutoScalePower(yProbe);
    scaleFactor_M = 10^scalePower_M;
end

% ============================================================
% M(T)
% ============================================================
figure('Color','w','Name',[sample_name ', Aging Memory, M(T)']); hold on;

plot(T_no, M_no * scaleFactor_M, '-o', ...
    'Color','k', ...
    'LineWidth', lw_ref + 0.6, ...
    'MarkerSize',4, ...
    'MarkerFaceColor','none', ...
    'DisplayName','No pause');

for i = 1:numel(pauseRuns)
    T = pauseRuns(i).T;
    M = pauseRuns(i).M;

    plot(T, M * scaleFactor_M, '-', ...
        'Color', cols(i,:), ...
        'LineWidth', lw_run, ...
        'DisplayName', sprintf('%.0f K Pause', pauseRuns(i).waitK));

    if ismember(pauseRuns(i).waitK, SHOW_PAUSES_K)
        xline(pauseRuns(i).waitK,'--', ...
            'Color', cols(i,:), ...
            'LineWidth',1.8, ...
            'HandleVisibility','off');
    end
end

xlabel('Temperature (K)');

if useAutoYScale && scalePower_M ~= 0
    ylabel(sprintf('M (10^{-%d} %s)', scalePower_M, unitStr), ...
        'Interpreter','tex');
else
    ylabel(['M (' unitStr ')'], 'Interpreter','tex');
end

title([sample_name ', Aging Memory, M(T)'],'FontWeight','bold');

xlim([0 45]); xticks(0:5:45);
legend('show','Location','bestoutside');
box on;
set(gca,'FontSize',fontsize);

% ============================================================
% AUTO SCALE — ΔM
% ============================================================
scaleFactor_dM = 1;
scalePower_dM  = 0;

if useAutoYScale
    yProbe = [];
    for i = 1:numel(pauseRuns)
        if isfield(pauseRuns(i),'DeltaM') && ~isempty(pauseRuns(i).DeltaM)
            yProbe = [yProbe; pauseRuns(i).DeltaM(:)]; %#ok<AGROW>
        end
    end
    scalePower_dM  = chooseAutoScalePower(yProbe);
    scaleFactor_dM = 10^scalePower_dM;
end

% ============================================================
% ΔM(T)
% ============================================================
% global amplitude (for offsets)
allAmp = [];
for i = 1:numel(pauseRuns)
    if ~isempty(pauseRuns(i).DeltaM)
        allAmp(end+1) = max(pauseRuns(i).DeltaM) - min(pauseRuns(i).DeltaM); %#ok<AGROW>
    end
end
if isempty(allAmp)
    warning('No ΔM data to plot.');
    return;
end
globalAmp = max(allAmp);

figure('Color','w','Name',[sample_name ', Aging Memory, ΔM(T)']); hold on;

for i = 1:numel(pauseRuns)

    if ~isfield(pauseRuns(i),'T_common') || isempty(pauseRuns(i).T_common)
        continue;
    end

    T = pauseRuns(i).T_common;

    if isfield(pauseRuns(i),'DeltaM_aligned') && ~isempty(pauseRuns(i).DeltaM_aligned)
        dM = pauseRuns(i).DeltaM_aligned;
    else
        dM = pauseRuns(i).DeltaM;
    end

    % offsets (physical, BEFORE scaling)
    switch lower(offsetMode)
        case 'vertical'
            dM = dM + (i-1)*(offsetPercent/100)*globalAmp;
        case 'horizontal'
            Tspan = max(T) - min(T);
            T = T + (i-1)*(offsetPercent/100)*Tspan;
    end

    plot(T, dM * scaleFactor_dM, '-', ...
        'Color', cols(i,:), ...
        'LineWidth', linewidth, ...
        'DisplayName', sprintf('%.0f K Pause', pauseRuns(i).waitK));

    if ismember(pauseRuns(i).waitK, SHOW_PAUSES_K)
        xline(pauseRuns(i).waitK,'--', ...
            'Color', cols(i,:), ...
            'LineWidth',2.0, ...
            'HandleVisibility','off');
    end
end

xlabel('Temperature (K)');

if useAutoYScale && scalePower_dM ~= 0
    ylabel(sprintf('\\Delta M (10^{-%d} %s)', scalePower_dM, unitStr), ...
        'Interpreter','tex');
else
    ylabel(['\Delta M (' unitStr ')'], 'Interpreter','tex');
end

title([sample_name ', Aging Memory, \DeltaM(T)'],'FontWeight','bold');

xlim([0 45]); xticks(0:5:45);
legend('show','Location','bestoutside');
box on;
set(gca,'FontSize',fontsize);

% ============================================================
% TEXT SUMMARY
% ============================================================
fprintf('\n=== Aging ΔM Summary (%s) ===\n', sample_name);
fprintf('Pause[K]   ΔMatPause      ΔM_localMin\n');
fprintf('-----------------------------------\n');
for i = 1:numel(pauseRuns)
    fprintf('%7.2f   %12.4g   %12.4g\n', ...
        pauseRuns(i).waitK, ...
        pauseRuns(i).DeltaM_atPause, ...
        pauseRuns(i).DeltaM_localMin);
end

end

% ============================================================
% COLOR HELPER
% ============================================================
function cols = pickColors(n, scheme)

n = max(n,3);

switch lower(scheme)
    case 'parula'
        cols = parula(n);
    case 'jet'
        cols = jet(n);
    case 'lines'
        cols = lines(n);
    case 'thermal'
        try
            cols = cmocean('thermal', n);
        catch
            cols = parula(n);
        end
    otherwise
        cols = parula(n);
end
end
