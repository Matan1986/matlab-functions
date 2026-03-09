% switching_observable_stability_survey
% Stability survey for core switching observables extracted from S(T,I):
%   S_peak(T), I_peak(T), width_I(T)
%
% This script keeps the switching signal definition fixed:
%   metricType = "P2P_percent"
%
% It varies only extraction-level choices:
%   - smoothing level
%   - ridge detection method
%   - current-window selection
%   - width threshold definition

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'observable_stability_survey';
run = createRunContext('switching', cfgRun); %#ok<NASGU>
baseOutDir = getResultsDir('switching', 'alignment_audit');
surveyOutDir = getResultsDir('switching', 'alignment_audit', 'stability_survey');
if ~exist(baseOutDir, 'dir')
    mkdir(baseOutDir);
end
if ~exist(surveyOutDir, 'dir')
    mkdir(surveyOutDir);
end
fprintf('switching stability survey directory:\n%s\n', surveyOutDir);

% Keep metric fixed by task definition.
metricType = "P2P_percent";
channelMode = "switchCh";
decompositionMode = "svd";

run(fullfile(repoRoot, 'Switching', 'analysis', 'switching_alignment_audit.m'));

rawCsv = fullfile(baseOutDir, 'switching_alignment_samples.csv');
assert(isfile(rawCsv), 'Missing raw samples CSV: %s', rawCsv);
rawTbl = readtable(rawCsv);

[tempsRaw, currents, SmapRaw] = buildSwitchingMap(rawTbl);
[temps, Smap] = cleanupTemperatureAxis(tempsRaw, SmapRaw);

baselineOpts = struct();
baselineOpts.smoothWin = 1;          % map smoothing window
baselineOpts.rowSmoothWin = 1;       % additional row smoothing for ridge finding
baselineOpts.ridgeMethod = "raw_max";% "raw_max" | "smooth_max" | "interp_peak"
baselineOpts.windowMode = "full";    % "full" | "edge_trim" | "ridge_band"
baselineOpts.widthFrac = 0.5;        % width threshold as fraction of local max
baselineOpts.bandHalfWidth = 10;     % mA (used by ridge_band only)
baselineOpts.baselineIpeak = NaN(size(temps));

baseRes = extractCoreObservables(Smap, temps, currents, baselineOpts);
baselineIpeak = baseRes.I_peak;

% ---- Category sweeps ----
smoothingCases = repmat(struct('name',"",'opts',baselineOpts), 3, 1);
smoothingCases(1).name = "no_smoothing";
smoothingCases(1).opts = baselineOpts;
smoothingCases(2).name = "weak_smoothing";
smoothingCases(2).opts = baselineOpts;
smoothingCases(2).opts.smoothWin = 3;
smoothingCases(3).name = "moderate_smoothing";
smoothingCases(3).opts = baselineOpts;
smoothingCases(3).opts.smoothWin = 5;

ridgeCases = repmat(struct('name',"",'opts',baselineOpts), 3, 1);
ridgeCases(1).name = "raw_max";
ridgeCases(1).opts = baselineOpts;
ridgeCases(2).name = "smooth_max";
ridgeCases(2).opts = baselineOpts;
ridgeCases(2).opts.ridgeMethod = "smooth_max";
ridgeCases(2).opts.rowSmoothWin = 3;
ridgeCases(3).name = "interp_peak";
ridgeCases(3).opts = baselineOpts;
ridgeCases(3).opts.ridgeMethod = "interp_peak";

windowCases = repmat(struct('name',"",'opts',baselineOpts), 3, 1);
windowCases(1).name = "full_range";
windowCases(1).opts = baselineOpts;
windowCases(2).name = "edge_trim";
windowCases(2).opts = baselineOpts;
windowCases(2).opts.windowMode = "edge_trim";
windowCases(3).name = "ridge_band_pm10mA";
windowCases(3).opts = baselineOpts;
windowCases(3).opts.windowMode = "ridge_band";
windowCases(3).opts.baselineIpeak = baselineIpeak;
windowCases(3).opts.bandHalfWidth = 10;

widthCases = repmat(struct('name',"",'opts',baselineOpts), 3, 1);
widthCases(1).name = "half_max_0p50";
widthCases(1).opts = baselineOpts;
widthCases(2).name = "threshold_0p40";
widthCases(2).opts = baselineOpts;
widthCases(2).opts.widthFrac = 0.4;
widthCases(3).name = "threshold_0p60";
widthCases(3).opts = baselineOpts;
widthCases(3).opts.widthFrac = 0.6;

smoothRes = runCaseSet(Smap, temps, currents, smoothingCases);
ridgeRes = runCaseSet(Smap, temps, currents, ridgeCases);
windowRes = runCaseSet(Smap, temps, currents, windowCases);
widthRes = runCaseSet(Smap, temps, currents, widthCases);

plotObservableGroupComparison(temps, smoothRes, ...
    fullfile(surveyOutDir, 'switching_stability_smoothing.png'), ...
    'Stability Survey: Smoothing');
plotObservableGroupComparison(temps, ridgeRes, ...
    fullfile(surveyOutDir, 'switching_stability_ridge_method.png'), ...
    'Stability Survey: Ridge Method');
plotObservableGroupComparison(temps, windowRes, ...
    fullfile(surveyOutDir, 'switching_stability_current_window.png'), ...
    'Stability Survey: Current Window');
plotObservableGroupComparison(temps, widthRes, ...
    fullfile(surveyOutDir, 'switching_stability_width_definition.png'), ...
    'Stability Survey: Width Definition');

summaryTbl = compareAgainstBaseline(baseRes, smoothRes, "smoothing");
summaryTbl = [summaryTbl; compareAgainstBaseline(baseRes, ridgeRes, "ridge_method")]; %#ok<AGROW>
summaryTbl = [summaryTbl; compareAgainstBaseline(baseRes, windowRes, "current_window")]; %#ok<AGROW>
summaryTbl = [summaryTbl; compareAgainstBaseline(baseRes, widthRes, "width_definition")]; %#ok<AGROW>

summaryCsv = fullfile(surveyOutDir, 'switching_observable_stability_summary.csv');
writetable(summaryTbl, summaryCsv);

baselineTbl = table(temps, baseRes.S_peak, baseRes.I_peak, baseRes.width_I, ...
    'VariableNames', {'T_K','S_peak','I_peak','width_I'});
baselineCsv = fullfile(surveyOutDir, 'switching_observable_stability_baseline.csv');
writetable(baselineTbl, baselineCsv);

fprintf('Stability survey done.\n');
fprintf('Metric fixed: %s\n', metricType);
fprintf('Survey outputs: %s\n', surveyOutDir);
fprintf('Summary CSV: %s\n', summaryCsv);


function results = runCaseSet(Smap, temps, currents, cases)
results = repmat(struct('name',"",'S_peak',[],'I_peak',[],'width_I',[]), numel(cases), 1);
for i = 1:numel(cases)
    r = extractCoreObservables(Smap, temps, currents, cases(i).opts);
    results(i).name = cases(i).name;
    results(i).S_peak = r.S_peak;
    results(i).I_peak = r.I_peak;
    results(i).width_I = r.width_I;
end
end


function [temps, currents, Smap] = buildSwitchingMap(rawTbl)
temps = unique(rawTbl.T_K(isfinite(rawTbl.T_K)));
currents = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
temps = sort(temps(:));
currents = sort(currents(:));
Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = abs(rawTbl.T_K - temps(it)) < 1e-9 & abs(rawTbl.current_mA - currents(ii)) < 1e-9;
        if any(m)
            Smap(it, ii) = mean(rawTbl.S_percent(m), 'omitnan');
        end
    end
end
end


function [tempsClean, SmapClean] = cleanupTemperatureAxis(temps, Smap)
Tclean = round(temps(:));
[Tuniq, ~, idx] = unique(Tclean, 'sorted');
SmapClean = NaN(numel(Tuniq), size(Smap,2));
for k = 1:numel(Tuniq)
    mk = idx == k;
    SmapClean(k,:) = mean(Smap(mk,:), 1, 'omitnan');
end
tempsClean = Tuniq(:);
end


function res = extractCoreObservables(SmapIn, temps, currents, opts)
Smap = SmapIn;
if opts.smoothWin > 1
    Smap = smoothMapFinite(Smap, opts.smoothWin);
end

Ipeak = NaN(size(temps));
Speak = NaN(size(temps));
widthI = NaN(size(temps));

for it = 1:numel(temps)
    row = Smap(it,:);
    valid = isfinite(row);
    if ~any(valid)
        continue;
    end

    valid = valid(:)' & currentWindowMask(currents, opts, it);
    if nnz(valid) < 2
        continue;
    end

    rowUse = row(valid);
    curUse = currents(valid(:));
    rowRidge = rowUse;
    if opts.ridgeMethod == "smooth_max" && opts.rowSmoothWin > 1
        rowRidge = smoothVectorFinite(rowUse, opts.rowSmoothWin);
    end

    [sMaxRaw, idxMax] = max(rowRidge);
    iPeak = curUse(idxMax);
    sPeak = rowUse(idxMax);

    if opts.ridgeMethod == "interp_peak" && idxMax > 1 && idxMax < numel(curUse)
        x3 = curUse(idxMax-1:idxMax+1);
        y3 = rowUse(idxMax-1:idxMax+1);
        if all(isfinite(x3)) && all(isfinite(y3))
            p = polyfit(x3, y3, 2);
            if isfinite(p(1)) && abs(p(1)) > eps
                xv = -p(2) / (2*p(1));
                if xv >= min(x3) && xv <= max(x3)
                    yv = polyval(p, xv);
                    if isfinite(yv)
                        iPeak = xv;
                        sPeak = yv;
                    end
                end
            end
        end
    end

    Ipeak(it) = iPeak;
    Speak(it) = sPeak;

    localMax = max(rowUse, [], 'omitnan');
    if ~isfinite(localMax) || localMax < eps
        continue;
    end
    thr = opts.widthFrac * localMax;
    mHalf = rowUse >= thr;
    if nnz(mHalf) >= 2
        widthI(it) = max(curUse(mHalf)) - min(curUse(mHalf));
    end

    if ~isfinite(sMaxRaw) && ~isfinite(Speak(it))
        Speak(it) = NaN;
    end
end

res = struct('S_peak', Speak, 'I_peak', Ipeak, 'width_I', widthI);
end


function m = currentWindowMask(currents, opts, it)
m = true(1, numel(currents));
switch string(opts.windowMode)
    case "full"
        % no-op
    case "edge_trim"
        if numel(currents) >= 3
            m(1) = false;
            m(end) = false;
        end
    case "ridge_band"
        if isfield(opts, 'baselineIpeak') && numel(opts.baselineIpeak) >= it && isfinite(opts.baselineIpeak(it))
            m = (abs(currents(:)' - opts.baselineIpeak(it)) <= opts.bandHalfWidth);
        end
    otherwise
        % no-op fallback
end
end


function y = smoothVectorFinite(x, w)
y = x;
if w <= 1
    return;
end
valid = isfinite(x);
if nnz(valid) < 2
    return;
end
z = x(valid);
z = smoothdata(z, 'movmean', w);
y(valid) = z;
end


function S = smoothMapFinite(Smap, w)
S = Smap;
for i = 1:size(S,1)
    S(i,:) = smoothVectorFinite(S(i,:), w);
end
for j = 1:size(S,2)
    S(:,j) = smoothVectorFinite(S(:,j), w);
end
end


function plotObservableGroupComparison(temps, results, outPng, figTitle)
fig = figure('Color','w','Visible','off','Position',[100 100 1100 800]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
if exist('turbo', 'file') == 2
    cmap = turbo(max(1, numel(results)));
else
    cmap = parula(max(1, numel(results)));
end

ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on');
for i = 1:numel(results)
    plot(ax1, temps, results(i).S_peak, '-o', 'LineWidth', 1.6, 'Color', cmap(i,:), ...
        'DisplayName', char(results(i).name));
end
xlabel(ax1, 'T (K)'); ylabel(ax1, 'S_{peak}(T)'); title(ax1, [figTitle ' - S_{peak}']);
legend(ax1, 'Location', 'eastoutside');

ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on');
for i = 1:numel(results)
    plot(ax2, temps, results(i).I_peak, '-o', 'LineWidth', 1.6, 'Color', cmap(i,:), ...
        'DisplayName', char(results(i).name));
end
xlabel(ax2, 'T (K)'); ylabel(ax2, 'I_{peak}(T) [mA]'); title(ax2, [figTitle ' - I_{peak}']);

ax3 = nexttile(tl, 3); hold(ax3, 'on'); grid(ax3, 'on');
for i = 1:numel(results)
    plot(ax3, temps, results(i).width_I, '-o', 'LineWidth', 1.6, 'Color', cmap(i,:), ...
        'DisplayName', char(results(i).name));
end
xlabel(ax3, 'T (K)'); ylabel(ax3, 'width_I(T) [mA]'); title(ax3, [figTitle ' - width_I']);

saveas(fig, outPng);
close(fig);
end


function tbl = compareAgainstBaseline(baseRes, results, category)
rows = repmat(initCmpRow(), numel(results), 1);
for i = 1:numel(results)
    rows(i).category = string(category);
    rows(i).case_name = string(results(i).name);
    [rows(i).corr_Speak, rows(i).mae_Speak] = metricPair(baseRes.S_peak, results(i).S_peak);
    [rows(i).corr_Ipeak, rows(i).mae_Ipeak] = metricPair(baseRes.I_peak, results(i).I_peak);
    [rows(i).corr_width, rows(i).mae_width] = metricPair(baseRes.width_I, results(i).width_I);
end
tbl = struct2table(rows);
end


function [r, mae] = metricPair(a, b)
v = isfinite(a) & isfinite(b);
if nnz(v) < 2
    r = NaN;
    mae = NaN;
    return;
end
r = corr(a(v), b(v), 'rows', 'complete');
mae = mean(abs(a(v)-b(v)), 'omitnan');
end


function row = initCmpRow()
row = struct();
row.category = "";
row.case_name = "";
row.corr_Speak = NaN;
row.mae_Speak = NaN;
row.corr_Ipeak = NaN;
row.mae_Ipeak = NaN;
row.corr_width = NaN;
row.mae_width = NaN;
end


