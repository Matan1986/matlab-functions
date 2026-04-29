% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — collapse sub-range diagnostics (family ids vary by inputs)
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_collapse_subrange_analysis';
    cfg.dataset = 'canonical_collapse_subrange_t_le_30';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(runFigures, 'dir') ~= 7, mkdir(runFigures); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    errPath = fullfile(repoRoot, 'tables', 'switching_collapse_error_vs_T.csv');
    localPath = fullfile(repoRoot, 'tables', 'switching_collapse_local_breakdown.csv');
    if exist(errPath, 'file') ~= 2 || exist(localPath, 'file') ~= 2
        error('run_switching_collapse_subrange_analysis:MissingInput', ...
            'Missing input tables switching_collapse_error_vs_T.csv and/or switching_collapse_local_breakdown.csv');
    end

    errTbl = readtable(errPath);
    localTbl = readtable(localPath);
    reqErr = {'T_K','collapse_error_metric'};
    reqLocal = {'T_K','total_error','center_error','tail_error'};
    for i = 1:numel(reqErr)
        if ~ismember(reqErr{i}, errTbl.Properties.VariableNames)
            error('run_switching_collapse_subrange_analysis:BadErrSchema', ...
                'switching_collapse_error_vs_T.csv missing %s', reqErr{i});
        end
    end
    for i = 1:numel(reqLocal)
        if ~ismember(reqLocal{i}, localTbl.Properties.VariableNames)
            error('run_switching_collapse_subrange_analysis:BadLocalSchema', ...
                'switching_collapse_local_breakdown.csv missing %s', reqLocal{i});
        end
    end

    errSub = errTbl(double(errTbl.T_K) <= 30, :);
    localSub = localTbl(double(localTbl.T_K) <= 30, :);
    [T, iaE, iaL] = intersect(double(errSub.T_K), double(localSub.T_K), 'stable');
    if isempty(T)
        error('run_switching_collapse_subrange_analysis:NoOverlap', 'No overlapping temperatures <=30K between error and local tables.');
    end
    e = double(errSub.collapse_error_metric(iaE));
    center = double(localSub.center_error(iaL));
    tail = double(localSub.tail_error(iaL));

    bin = strings(numel(T),1);
    bin(T <= 22) = "low";
    bin(T > 22 & T <= 26) = "mid";
    bin(T > 26 & T <= 30) = "high_pre_transition";

    bins = ["low";"mid";"high_pre_transition"];
    rows = repmat(struct('bin_label',"",'n_temperatures',0,'mean_collapse_error',NaN,'std_collapse_error',NaN, ...
        'median_collapse_error',NaN,'mean_center_error',NaN,'mean_tail_error',NaN,'tail_to_center_ratio',NaN), 3,1);
    for i = 1:3
        m = bin == bins(i);
        rows(i).bin_label = bins(i);
        rows(i).n_temperatures = sum(m);
        if any(m)
            rows(i).mean_collapse_error = mean(e(m), 'omitnan');
            rows(i).std_collapse_error = std(e(m), 'omitnan');
            rows(i).median_collapse_error = median(e(m), 'omitnan');
            rows(i).mean_center_error = mean(center(m), 'omitnan');
            rows(i).mean_tail_error = mean(tail(m), 'omitnan');
            rows(i).tail_to_center_ratio = rows(i).mean_tail_error / max(rows(i).mean_center_error, eps);
        end
    end
    summaryTbl = struct2table(rows);

    lowMean = summaryTbl.mean_collapse_error(summaryTbl.bin_label=="low");
    midMean = summaryTbl.mean_collapse_error(summaryTbl.bin_label=="mid");
    highMean = summaryTbl.mean_collapse_error(summaryTbl.bin_label=="high_pre_transition");
    degradation_mid = midMean / max(lowMean, eps);
    degradation_high = highMean / max(lowMean, eps);

    degTbl = table(degradation_mid, degradation_high, ...
        'VariableNames', {'degradation_mid','degradation_high'});

    % Figures
    fig1 = fullfile(runFigures, 'switching_collapse_error_vs_T_le30.png');
    h1 = figure('Visible','off','Color','w','Position',[100 100 1100 600]);
    plot(T, e, '-o', 'LineWidth', 1.8);
    grid on; xlabel('T (K)'); ylabel('collapse error');
    title('Collapse Error vs Temperature (T <= 30 K)');
    xline(22, '--', '22K');
    xline(26, '--', '26K');
    exportgraphics(h1, fig1, 'Resolution', 300); close(h1);

    fig2 = fullfile(runFigures, 'switching_collapse_error_boxplot_by_bin.png');
    h2 = figure('Visible','off','Color','w','Position',[100 100 900 600]);
    boxplot(e, cellstr(bin));
    grid on; ylabel('collapse error'); title('Collapse Error Distribution by Bin (T <= 30 K)');
    exportgraphics(h2, fig2, 'Resolution', 300); close(h2);

    fig3 = fullfile(runFigures, 'switching_center_tail_error_vs_T_le30.png');
    h3 = figure('Visible','off','Color','w','Position',[100 100 1100 600]);
    plot(T, center, '-o', 'LineWidth', 1.8); hold on;
    plot(T, tail, '-s', 'LineWidth', 1.8);
    grid on; xlabel('T (K)'); ylabel('local collapse error');
    title('Center vs Tail Collapse Error (T <= 30 K)');
    legend({'center_error','tail_error'}, 'Location', 'best');
    exportgraphics(h3, fig3, 'Resolution', 300); close(h3);

    goodLow = lowMean < 0.10;
    degrades = degradation_mid > 1.15 || degradation_high > 1.25;
    breaksBefore315 = highMean > 1.5 * max(lowMean, eps);
    tailDominates = mean(summaryTbl.tail_to_center_ratio, 'omitnan') > 1.15;
    consistentLegacyLow = "PARTIAL";
    if goodLow && ~degrades
        consistentLegacyLow = "YES";
    elseif ~goodLow
        consistentLegacyLow = "NO";
    end

    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        numel(T), ...
        degradation_mid, ...
        degradation_high, ...
        string(strjoin(string({fig1, fig2, fig3}), '; ')), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures_used','degradation_mid','degradation_high','figures_written'});

    report = {};
    report{end+1} = '# Canonical Collapse Sub-Range Analysis (T <= 30 K)';
    report{end+1} = '';
    report{end+1} = '## Scope';
    report{end+1} = '- Reused existing collapse artifacts only; no collapse recomputation.';
    report{end+1} = '- Analysis restricted to T <= 30 K.';
    report{end+1} = '';
    report{end+1} = '## Bin Summary';
    report{end+1} = sprintf('- low mean error: %.6g', lowMean);
    report{end+1} = sprintf('- mid mean error: %.6g', midMean);
    report{end+1} = sprintf('- high_pre_transition mean error: %.6g', highMean);
    report{end+1} = sprintf('- degradation_mid = %.6g', degradation_mid);
    report{end+1} = sprintf('- degradation_high = %.6g', degradation_high);
    report{end+1} = '';
    report{end+1} = '## Spatial Breakdown';
    report{end+1} = sprintf('- mean center error (all bins avg) = %.6g', mean(summaryTbl.mean_center_error, 'omitnan'));
    report{end+1} = sprintf('- mean tail error (all bins avg) = %.6g', mean(summaryTbl.mean_tail_error, 'omitnan'));
    report{end+1} = sprintf('- mean tail/center ratio = %.6g', mean(summaryTbl.tail_to_center_ratio, 'omitnan'));
    report{end+1} = '';
    report{end+1} = '## Figures';
    report{end+1} = sprintf('- `%s`', fig1);
    report{end+1} = sprintf('- `%s`', fig2);
    report{end+1} = sprintf('- `%s`', fig3);
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- COLLAPSE_GOOD_IN_LOW_T = %s', yesno(goodLow));
    report{end+1} = sprintf('- COLLAPSE_DEGRADES_TOWARD_TRANSITION = %s', yesno(degrades));
    report{end+1} = sprintf('- COLLAPSE_BREAKS_BEFORE_31_5 = %s', yesno(breaksBefore315));
    report{end+1} = sprintf('- DEGRADATION_DOMINATED_BY_TAILS = %s', yesno(tailDominates));
    report{end+1} = sprintf('- CANONICAL_COLLAPSE_CONSISTENT_WITH_LEGACY_LOW_T = %s', consistentLegacyLow);

    writeBoth(summaryTbl, repoRoot, runTables, 'switching_collapse_subrange_summary.csv');
    writeBoth(degTbl, repoRoot, runTables, 'switching_collapse_subrange_degradation.csv');
    writeBoth(statusTbl, repoRoot, runTables, 'switching_collapse_subrange_status.csv');
    writeLines(fullfile(runReports, 'switching_collapse_subrange_analysis.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_collapse_subrange_analysis.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, numel(T), {'switching collapse subrange analysis completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_collapse_subrange_analysis_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), string('NO'), 0, NaN, NaN, string(''), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures_used','degradation_mid','degradation_high','figures_written'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_collapse_subrange_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_collapse_subrange_status.csv'));
    lines = {};
    lines{end+1} = '# Canonical Collapse Sub-Range Analysis FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_collapse_subrange_analysis.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_collapse_subrange_analysis.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching collapse subrange analysis failed'}, true);
    rethrow(ME);
end

function s = yesno(tf)
s = 'NO';
if tf, s = 'YES'; end
end

function writeBoth(tbl, repoRoot, runTables, name)
writetable(tbl, fullfile(runTables, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_collapse_subrange_analysis:WriteFail', 'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
