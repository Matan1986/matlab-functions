function summaryTbl = diagnose_FM_sign_stability()
% diagnose_FM_sign_stability
% Build FM/AFM signed-metric summary from existing diagnostics outputs.
% This script does not rerun AFM/FM decomposition; it reuses existing results.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

decompRoot = getResultsDir('aging', 'decomposition');
outRoot = getResultsDir('aging', 'decomposition', 'FM_sign_stability');
fmAmpCsv = fullfile(decompRoot, 'FM_construction_audit', 'FM_amplitude_summary.csv');
fitCsv = fullfile(decompRoot, 'fit_vs_derivative_audit', 'fit_vs_derivative_audit_summary.csv');
outCsv = fullfile(outRoot, 'FM_AFM_summary.csv');
outPlotDir = fullfile(outRoot, 'FM_sign_diagnostic');

assert(isfile(fmAmpCsv), 'Missing input CSV: %s', fmAmpCsv);
assert(isfile(fitCsv), 'Missing input CSV: %s', fitCsv);
if ~exist(outPlotDir, 'dir')
    mkdir(outPlotDir);
end

fmTbl = readtable(fmAmpCsv);
fitTbl = readtable(fitCsv);

fmTbl.wait_key = normalizeWaitLabel(fmTbl.wait_time);
fitTbl.wait_key = normalizeWaitLabel(fitTbl.wait_time);

fmTbl.Tp = fmTbl.pause_T;
fitTbl.Tp = fitTbl.pause_Tp_K;

fmTbl.key = compose('%s|%.6f', fmTbl.wait_key, fmTbl.Tp);
fitTbl.key = compose('%s|%.6f', fitTbl.wait_key, fitTbl.Tp);

n = height(fmTbl);
AFM_metric = nan(n,1);
fit_R2 = nan(n,1);

fitMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
for i = 1:height(fitTbl)
    fitMap(char(fitTbl.key(i))) = i;
end

for i = 1:n
    k = char(fmTbl.key(i));
    if isKey(fitMap, k)
        j = fitMap(k);
        if ismember('dip_area', fitTbl.Properties.VariableNames)
            AFM_metric(i) = fitTbl.dip_area(j);
        end
        if ismember('fit_R2', fitTbl.Properties.VariableNames)
            fit_R2(i) = fitTbl.fit_R2(j);
        end
    end
end

FM_signed = fmTbl.FM_step;
FM_abs = abs(FM_signed);

summaryTbl = table( ...
    fmTbl.wait_time, fmTbl.Tp, FM_signed, FM_abs, AFM_metric, fit_R2, ...
    isfinite(AFM_metric) & (AFM_metric > 0), isfinite(FM_signed), ...
    'VariableNames', {'wait_time','Tp','FM_signed','FM_abs','AFM_metric','fit_R2','dip_present','FM_present'});

writetable(summaryTbl, outCsv);
fprintf('Saved %s\n', outCsv);

waitOrder = {'3 s','36 s','6 min','60 min'};
for iw = 1:numel(waitOrder)
    w = waitOrder{iw};
    mask = strcmp(summaryTbl.wait_time, w) & isfinite(summaryTbl.Tp) & isfinite(summaryTbl.FM_signed);
    if ~any(mask)
        continue;
    end

    [Tp_sorted, idx] = sort(summaryTbl.Tp(mask));
    FM_sorted = summaryTbl.FM_signed(mask);
    FM_sorted = FM_sorted(idx);

    figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 880 540]);
    plot(Tp_sorted, FM_sorted, 'o-', 'LineWidth', 1.6, 'MarkerSize', 7, ...
        'Color', [0.00 0.45 0.74], 'DisplayName', 'FM_{signed}');
    hold on;
    yline(0, '--k', 'LineWidth', 1.1, 'DisplayName', 'zero');
    grid on;
    xlabel('T_p (K)');
    ylabel('FM_{signed}');
    title(sprintf('FM signed vs T_p | wait = %s', w));
    legend('Location', 'bestoutside', 'FontSize', 9);

    outPng = fullfile(outPlotDir, sprintf('FM_signed_vs_Tp_%s.png', normalizeWaitLabel(string(w))));
    saveas(figH, outPng);
    close(figH);
    fprintf('Saved %s\n', outPng);
end
end

function out = normalizeWaitLabel(in)
if iscell(in)
    in = string(in);
elseif ischar(in)
    in = string({in});
elseif ~isstring(in)
    in = string(in);
end

out = strings(size(in));
for i = 1:numel(in)
    s = lower(strtrim(in(i)));
    s = replace(s, ' ', '');
    if s == "3s"
        out(i) = "3s";
    elseif s == "36s" || s == "36sec"
        out(i) = "36s";
    elseif s == "6min"
        out(i) = "6min";
    elseif s == "60min"
        out(i) = "60min";
    else
        out(i) = regexprep(s, '[^a-z0-9]', '');
    end
end
end



