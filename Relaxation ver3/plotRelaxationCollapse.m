function plotRelaxationCollapse(allFits, Time_table, Moment_table, sample_name, fileList, plotLevel)

%% Handle plotLevel parameter (gating for plotting)
if nargin < 6 || isempty(plotLevel)
    plotLevel = 'summary';
end
if strcmpi(plotLevel, 'none')
    return;
end
% plotRelaxationCollapse
% Core physics plot: stretched-exponential scaling collapse
%
% x = ((t - t0)/tau)^beta
% y = (M - Minf)/dM

if nargin < 5
    fileList = {};
end

if isempty(allFits)
    warning('plotRelaxationCollapse:NoFits', 'No fits available for collapse plot.');
    return;
end

nCurves = height(allFits);
colors = parula(max(nCurves,1));

figName = sprintf('%s - Relaxation collapse', sample_name);
figure('Name', figName, 'Color', 'w'); hold on;

if ismember('model_type', allFits.Properties.VariableNames)
    allModels = lower(string(allFits.model_type));
    hasAnyKww = any(allModels == "kww");
    if ~hasAnyKww
        warning('plotRelaxationCollapse:NoKWW', 'No KWW fits available for collapse plot.');
        return;
    end
end

for i = 1:nCurves
    if ismember('model_type', allFits.Properties.VariableNames)
        modelType = lower(string(allFits.model_type(i)));
        if modelType ~= "kww"
            continue;
        end
    end

    idx = allFits.data_idx(i);
    if idx < 1 || idx > numel(Time_table)
        continue;
    end

    t = Time_table{idx};
    m = Moment_table{idx};
    if isempty(t) || isempty(m)
        continue;
    end

    t0 = allFits.t_start(i);
    t1 = allFits.t_end(i);
    tau = allFits.tau(i);
    beta = allFits.n(i);
    Minf = allFits.Minf(i);
    dM = allFits.dM(i);

    if ~isfinite(tau) || tau <= 0 || ~isfinite(beta) || beta <= 0 || abs(dM) < eps
        continue;
    end

    mask = (t >= t0) & (t <= t1) & isfinite(t) & isfinite(m);
    if ~any(mask)
        continue;
    end

    tSel = t(mask);
    mSel = m(mask);

    x = ((max(0, tSel - t0)) ./ tau) .^ beta;
    y = (mSel - Minf) ./ dM;

    label = sprintf('%.2f K', allFits.Temp_K(i));
    if ~isempty(fileList) && idx <= numel(fileList)
        if contains(lower(fileList{idx}), 'trm')
            label = ['TRM - ' label];
        elseif contains(lower(fileList{idx}), 'irm')
            label = ['IRM - ' label];
        end
    end

    plot(x, y, 'o', 'MarkerSize', 4, 'LineWidth', 1.1, ...
        'Color', colors(i,:), 'DisplayName', label);
end

xline(1, '--k', 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel('((t - t_0)/\tau)^\beta');
ylabel('(M - M_\infty) / \DeltaM');
title(figName, 'FontWeight', 'bold');
grid on; box on;
legend('Location', 'eastoutside');
set(gca, 'FontSize', 12);

end
