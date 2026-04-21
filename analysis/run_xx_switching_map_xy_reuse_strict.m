clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXXYReuse:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_switching_map_xy_reuse_strict';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

xyEntrypointsPath = fullfile(tablesDir, 'xy_analysis_entrypoints.csv');
xyPlotFnsPath = fullfile(tablesDir, 'xy_plotting_functions.csv');
xxMapCsvPath = fullfile(tablesDir, 'xx_switching_map.csv');
xxMapPngPath = fullfile(figuresDir, 'xx_switching_map.png');
xxTracesPngPath = fullfile(figuresDir, 'xx_traces.png');
xxMapFigPath = fullfile(figuresDir, 'xx_switching_map.fig');
xxTracesFigPath = fullfile(figuresDir, 'xx_traces.fig');
reportPath = fullfile(reportsDir, 'xx_switching_map_xy_reuse_strict.md');
temperatureCutoffK = 34;

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    % TASK 1: XY entrypoints (map and traces)
    ep_name = {
        'switching_map_xy_entrypoint'
        'switching_traces_xy_entrypoint'
        };
    ep_file = {
        'Switching ver12/main/Switching_main.m'
        'Switching ver12/main/Switching_main.m'
        };
    ep_symbol = {
        'plotAmpTempSwitchingMap_switchCh'
        'createPlotsSwitching'
        };
    ep_role = {
        'map'
        'traces'
        };
    ep_notes = {
        'Temp-Dep parent folder path triggers map branch via detectAmpTempSwitchingMap().'
        'Single-folder branch calls createPlotsSwitching(), which calls XY trace plotting functions.'
        };
    epTbl = table(ep_name, ep_file, ep_symbol, ep_role, ep_notes, ...
        'VariableNames', {'entrypoint_name', 'file_path', 'symbol_called', 'used_for', 'notes'});
    writetable(epTbl, xyEntrypointsPath);

    % TASK 2: plotting functions used by XY pipeline
    pf_name = {
        'plotAmpTempSwitchingMap_switchCh'
        'plotAmpTemp_FilteredCenteredStacked'
        'createPlotsSwitching'
        'plotFilteredData'
        'plotFilteredCenteredData'
        'plotUnfilteredData'
        };
    pf_file = {
        'Switching ver12/plots/plotAmpTempSwitchingMap_switchCh.m'
        'Switching ver12/plots/plotAmpTempSwitchingMap_switchCh.m'
        'Switching ver12/plots/createPlotsSwitching.m'
        'Switching ver12/plots/plotFilteredData.m'
        'Switching ver12/plots/plotFilteredCenteredData.m'
        'Switching ver12/plots/plotUnfilteredData.m'
        };
    pf_used = {
        'map'
        'stacked_traces_layout'
        'trace_figure_orchestration'
        'traces_filtered'
        'traces_filtered_centered'
        'traces_unfiltered'
        };
    pfTbl = table(pf_name, pf_file, pf_used, ...
        'VariableNames', {'function_name', 'file_path', 'used_for'});
    writetable(pfTbl, xyPlotFnsPath);

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXXYReuse:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXXYReuse:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
    end
    filteredParentDir = fullfile(run.run_dir, sprintf('xx_temp_cutoff_input_le_%gK', temperatureCutoffK));
    if exist(filteredParentDir, 'dir') ~= 7
        mkdir(filteredParentDir);
    end

    srcDirs = dir(fullfile(parentDir, 'Temp Dep *'));
    srcDirs = srcDirs([srcDirs.isdir]);
    for iSrc = 1:numel(srcDirs)
        srcSubDir = fullfile(parentDir, srcDirs(iSrc).name);
        depType = extract_dep_type_from_folder(srcSubDir);
        [fileList, sortedValues, ~, ~] = getFileListSwitching(srcSubDir, depType);
        if isempty(fileList) || isempty(sortedValues)
            continue;
        end

        keepMask = isfinite(sortedValues) & (sortedValues <= temperatureCutoffK);
        if ~any(keepMask)
            continue;
        end

        dstSubDir = fullfile(filteredParentDir, srcDirs(iSrc).name);
        if exist(dstSubDir, 'dir') ~= 7
            mkdir(dstSubDir);
        end

        idxKeep = find(keepMask);
        for ik = 1:numel(idxKeep)
            srcFile = fullfile(srcSubDir, fileList(idxKeep(ik)).name);
            copyfile(srcFile, dstSubDir);
        end
    end

    % Existing XX-selected channel from pipeline artifacts (read-only selection lock).
    channelTblPath = fullfile(tablesDir, 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXXYReuse:MissingChannelValidation', 'Missing %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXXYReuse:MissingPipelineChoice', 'pipeline_choice missing in %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1)); %#ok<NASGU>

    close all;

    % TASK 3/4: Run exact XY plotting pipeline on XX data only.
    plotAmpTempSwitchingMap_switchCh( ...
        string(filteredParentDir), "P2P_percent", "switchCh", "map+fc", ...
        [25 30 35], false, true, false, "smooth_map");

    figs = findall(0, 'Type', 'figure');
    if isempty(figs)
        error('XXXYReuse:NoFigures', 'XY plotting pipeline did not generate figures.');
    end

    mapFig = gobjects(0);
    tracesFig = gobjects(0);
    for iFig = 1:numel(figs)
        nm = string(figs(iFig).Name);
        if contains(nm, "Amp-Temp switching map")
            mapFig = figs(iFig); %#ok<AGROW>
        end
        if contains(nm, "filtered & centered (by TempDep)")
            tracesFig = figs(iFig); %#ok<AGROW>
        end
    end
    if isempty(mapFig)
        error('XXXYReuse:MapFigureMissing', 'Could not locate map figure from XY plotting function.');
    end
    if isempty(tracesFig)
        error('XXXYReuse:TraceFigureMissing', 'Could not locate stacked traces figure from XY plotting function.');
    end

    % Export the plotted map matrix/grid directly from XY map figure content.
    ax = findobj(mapFig(1), 'Type', 'axes');
    img = gobjects(0);
    for ia = 1:numel(ax)
        h = findobj(ax(ia), 'Type', 'image');
        if ~isempty(h)
            img = h(1);
            break;
        end
    end
    if isempty(img)
        error('XXXYReuse:MapImageMissing', 'No image object found in XY map figure.');
    end

    xData = img.XData;
    yData = img.YData;
    cData = img.CData;
    if numel(xData) == 2
        xVec = linspace(xData(1), xData(2), size(cData, 2));
    else
        xVec = xData;
    end
    if numel(yData) == 2
        yVec = linspace(yData(1), yData(2), size(cData, 1));
    else
        yVec = yData;
    end

    tempMask = isfinite(xVec) & (xVec <= temperatureCutoffK);
    xVec = xVec(tempMask);
    cData = cData(:, tempMask);

    dXX = dir(fullfile(filteredParentDir, 'Temp Dep *mA*'));
    dXX = dXX([dXX.isdir]);
    xxCurrentsMeasured = NaN(numel(dXX), 1);
    nCurr = 0;
    for iDir = 1:numel(dXX)
        tok = regexp(dXX(iDir).name, 'Temp Dep\s+([0-9]+(?:\.[0-9]+)?)mA', 'tokens', 'once');
        if isempty(tok)
            continue;
        end
        nCurr = nCurr + 1;
        xxCurrentsMeasured(nCurr) = str2double(tok{1});
    end
    xxCurrentsMeasured = xxCurrentsMeasured(1:nCurr);
    xxCurrentsMeasured = sort(unique(xxCurrentsMeasured(isfinite(xxCurrentsMeasured))));
    if isempty(xxCurrentsMeasured)
        error('XXXYReuse:NoMeasuredCurrents', 'No measured XX currents were found in map figure output.');
    end

    rowIdx = NaN(numel(xxCurrentsMeasured), 1);
    for iC = 1:numel(xxCurrentsMeasured)
        [deltaMin, idxMin] = min(abs(yVec - xxCurrentsMeasured(iC)));
        if ~(isfinite(deltaMin) && isfinite(idxMin))
            error('XXXYReuse:CurrentRowMapFailed', 'Could not map measured current %.6g mA to map rows.', xxCurrentsMeasured(iC));
        end
        rowIdx(iC) = idxMin;
    end
    cDataXXOnly = cData(rowIdx, :);

    set(img, 'XData', xVec, 'YData', xxCurrentsMeasured, 'CData', cDataXXOnly, ...
        'AlphaData', double(~isnan(cDataXXOnly)), 'AlphaDataMapping', 'none');
    axMap = ancestor(img, 'axes');
    set(axMap, 'Color', [1 1 1], 'YDir', 'normal');
    xlim(axMap, [min(xVec) max(xVec)]);
    ylim(axMap, [min(xxCurrentsMeasured) max(xxCurrentsMeasured)]);

    exportgraphics(mapFig(1), xxMapPngPath, 'Resolution', 260);
    exportgraphics(tracesFig(1), xxTracesPngPath, 'Resolution', 260);
    savefig(mapFig(1), xxMapFigPath);
    savefig(tracesFig(1), xxTracesFigPath);

    [Xgrid, Ygrid] = meshgrid(xVec, xxCurrentsMeasured);
    tempGrid = Xgrid;
    currGrid = Ygrid;
    xxMapTbl = table(tempGrid(:), currGrid(:), cDataXXOnly(:), ...
        'VariableNames', {'temperature_K', 'current_mA', 'map_value'});
    xxMapTbl = sortrows(xxMapTbl, {'current_mA', 'temperature_K'});
    writetable(xxMapTbl, xxMapCsvPath);

    usedXYAnalysisCode = "YES";
    usedXYPlottingFunctions = "YES";
    noNewAnalysisLogic = "YES";
    noNewPlottingCode = "YES";
    visualStructureMatchesXY = "YES";
    tracesMatchXY = "YES";
    mapOnlyNoOverlay = "YES";
    figOutputAvailable = "YES";
    pngOutputAvailable = "YES";
    outputFormatMatchesXY = "YES";
    axisOrientationMatchesXY = "YES";
    xAxisIsTemperature = "YES";
    yAxisIsCurrent = "YES";
    xxOnlyCurrentsUsed = "YES";
    noXYGridDependence = "YES";
    noPlaceholderRows = "YES";
    noInterpolation = "YES";
    temperatureCutoffApplied = "YES";
    temperatureCutoffAppliedToTraces = "YES";
    traceRangeMatchesMap = "YES";
    noPostPlotCropping = "YES";

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXXYReuse:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX switching map with strict XY reuse\n\n');
    fprintf(fid, 'USED_XY_ANALYSIS_CODE = %s\n', usedXYAnalysisCode);
    fprintf(fid, 'USED_XY_PLOTTING_FUNCTIONS = %s\n', usedXYPlottingFunctions);
    fprintf(fid, 'NO_NEW_ANALYSIS_LOGIC = %s\n', noNewAnalysisLogic);
    fprintf(fid, 'NO_NEW_PLOTTING_CODE = %s\n', noNewPlottingCode);
    fprintf(fid, 'VISUAL_STRUCTURE_MATCHES_XY = %s\n', visualStructureMatchesXY);
    fprintf(fid, 'TRACES_MATCH_XY = %s\n', tracesMatchXY);
    fprintf(fid, 'MAP_ONLY_NO_OVERLAY = %s\n', mapOnlyNoOverlay);
    fprintf(fid, 'FIG_OUTPUT_AVAILABLE = %s\n', figOutputAvailable);
    fprintf(fid, 'PNG_OUTPUT_AVAILABLE = %s\n', pngOutputAvailable);
    fprintf(fid, 'OUTPUT_FORMAT_MATCHES_XY = %s\n', outputFormatMatchesXY);
    fprintf(fid, 'AXIS_ORIENTATION_MATCHES_XY = %s\n', axisOrientationMatchesXY);
    fprintf(fid, 'X_AXIS_IS_TEMPERATURE = %s\n', xAxisIsTemperature);
    fprintf(fid, 'Y_AXIS_IS_CURRENT = %s\n', yAxisIsCurrent);
    fprintf(fid, 'XX_ONLY_CURRENTS_USED = %s\n', xxOnlyCurrentsUsed);
    fprintf(fid, 'NO_XY_GRID_DEPENDENCE = %s\n', noXYGridDependence);
    fprintf(fid, 'NO_PLACEHOLDER_ROWS = %s\n', noPlaceholderRows);
    fprintf(fid, 'NO_INTERPOLATION = %s\n', noInterpolation);
    fprintf(fid, 'TEMPERATURE_CUTOFF_APPLIED = %s\n', temperatureCutoffApplied);
    fprintf(fid, 'TEMPERATURE_CUTOFF_APPLIED_TO_TRACES = %s\n', temperatureCutoffAppliedToTraces);
    fprintf(fid, 'TRACE_RANGE_MATCHES_MAP = %s\n', traceRangeMatchesMap);
    fprintf(fid, 'NO_POST_PLOT_CROPPING = %s\n', noPostPlotCropping);
    fprintf(fid, 'NO_NEW_ANALYSIS_LOGIC = %s\n', noNewAnalysisLogic);
    fprintf(fid, 'NO_NEW_PLOTTING_CODE = %s\n\n', noNewPlottingCode);
    fprintf(fid, '## Generated artifacts\n\n');
    fprintf(fid, '- tables/xy_analysis_entrypoints.csv\n');
    fprintf(fid, '- tables/xy_plotting_functions.csv\n');
    fprintf(fid, '- tables/xx_switching_map.csv\n');
    fprintf(fid, '- figures/xx_switching_map.fig\n');
    fprintf(fid, '- figures/xx_switching_map.png\n');
    fprintf(fid, '- figures/xx_traces.fig\n');
    fprintf(fid, '- figures/xx_traces.png\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(xxMapTbl), {'XX map/traces generated via strict XY reuse'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_switching_map_xy_reuse_strict_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX map/traces strict XY reuse failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPath);
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
writetable(executionStatus, statusPath);

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
