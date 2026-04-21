fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXLatePlateauPipeline:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_late_switching_map';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

xyEntrypointsPath = fullfile(tablesDir, 'xy_analysis_entrypoints.csv');
xyPlotFnsPath = fullfile(tablesDir, 'xy_plotting_functions.csv');
xxMapCsvPath = fullfile(tablesDir, 'xx_late_switching_map.csv');
xxMapPngPath = fullfile(figuresDir, 'xx_late_switching_map.png');
xxMapFigPath = fullfile(figuresDir, 'xx_late_switching_map.fig');
reportPath = fullfile(reportsDir, 'xx_late_switching_map.md');

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

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer >= 0
        fprintf(fidPointer, '%s\n', run.run_dir);
        fclose(fidPointer);
    end

    % Build a shadow helper that preserves the original switching-map pipeline
    % and changes only plateau-value extraction to the late 70-90 percent window.
    shadowDir = fullfile(run.run_dir, 'shadow_processFilesSwitching');
    if exist(shadowDir, 'dir') ~= 7
        mkdir(shadowDir);
    end
    origProcessPath = fullfile(repoRoot, 'Switching ver12', 'main', 'processFilesSwitching.m');
    shadowProcessPath = fullfile(shadowDir, 'processFilesSwitching.m');

    srcProcess = fileread(origProcessPath);
    srcProcess = regexprep(srcProcess, '\r\n?', '\n');
    nl = sprintf('\n');

    oldChunk1 = [ ...
        '        for k = 1:numCh' nl ...
        '            vals = R_unf{k}(idx);' nl ...
        '            if isempty(vals)' nl ...
        '                intervel_avg_res(j,k) = NaN;' nl ...
        '            else' nl ...
        '                intervel_avg_res(j,k) = mean(vals,''omitnan'');' nl ...
        '            end' nl ...
        '        end'];
    newChunk1 = [ ...
        '        for k = 1:numCh' nl ...
        '            idx0 = find(idx);' nl ...
        '            if isempty(idx0)' nl ...
        '                intervel_avg_res(j,k) = NaN;' nl ...
        '            else' nl ...
        '                n = numel(idx0);' nl ...
        '                i1 = floor(0.70 * n) + 1;' nl ...
        '                i2 = floor(0.90 * n);' nl ...
        '                i2 = max(i2, i1);' nl ...
        '                idxLate = idx0(i1:i2);' nl ...
        '                vals = R_unf{k}(idxLate);' nl ...
        '                if isempty(vals)' nl ...
        '                    intervel_avg_res(j,k) = NaN;' nl ...
        '                else' nl ...
        '                    intervel_avg_res(j,k) = mean(vals,''omitnan'');' nl ...
        '                end' nl ...
        '            end' nl ...
        '        end'];
    if ~contains(srcProcess, oldChunk1)
        error('XXLatePlateauPipeline:PatchChunk1Missing', 'Could not locate interval-average chunk in processFilesSwitching.');
    end
    srcProcess = strrep(srcProcess, oldChunk1, newChunk1);

    oldChunk2 = [ ...
        '    for k = 1:numCh' nl ...
        '        vals = R_unf{k}(idx_last);' nl ...
        '        if isempty(vals)' nl ...
        '            intervel_avg_res(end,k) = NaN;' nl ...
        '        else' nl ...
        '            intervel_avg_res(end,k) = mean(vals,''omitnan'');' nl ...
        '        end'];
    newChunk2 = [ ...
        '    for k = 1:numCh' nl ...
        '        idx0 = find(idx_last);' nl ...
        '        if isempty(idx0)' nl ...
        '            intervel_avg_res(end,k) = NaN;' nl ...
        '        else' nl ...
        '            n = numel(idx0);' nl ...
        '            i1 = floor(0.70 * n) + 1;' nl ...
        '            i2 = floor(0.90 * n);' nl ...
        '            i2 = max(i2, i1);' nl ...
        '            idxLate = idx0(i1:i2);' nl ...
        '            vals = R_unf{k}(idxLate);' nl ...
        '            if isempty(vals)' nl ...
        '                intervel_avg_res(end,k) = NaN;' nl ...
        '            else' nl ...
        '                intervel_avg_res(end,k) = mean(vals,''omitnan'');' nl ...
        '            end' nl ...
        '        end'];
    if ~contains(srcProcess, oldChunk2)
        error('XXLatePlateauPipeline:PatchChunk2Missing', 'Could not locate last-interval chunk in processFilesSwitching.');
    end
    srcProcess = strrep(srcProcess, oldChunk2, newChunk2);

    newChunk3 = [ ...
        '        for k = 1:numCh' nl ...
        '            idx0 = find(idx);' nl ...
        '            if isempty(idx0)' nl ...
        '                vals = [];' nl ...
        '            else' nl ...
        '                n = numel(idx0);' nl ...
        '                i1 = floor(0.70 * n) + 1;' nl ...
        '                i2 = floor(0.90 * n);' nl ...
        '                i2 = max(i2, i1);' nl ...
        '                idxLate = idx0(i1:i2);' nl ...
        '                vals = R_unf{k}(idxLate);' nl ...
        '            end' nl ...
        '            vals = vals(~isnan(vals));' nl ...
        '            N_mean(j,k) = numel(vals);' nl ...
        '' nl ...
        '            if N_mean(j,k) <= 4' nl ...
        '                sigma_within(j,k) = NaN;' nl ...
        '            else' nl ...
        '                sigma_within(j,k) = std(vals,''omitnan'');   % simple STD' nl ...
        '            end' nl ...
        '        end'];
    pat3 = [ '        idx = \(time >= start_time\) & \(time <= end_time\);\s+' ...
        '        for k = 1:numCh\s+' ...
        '            vals = R_unf\{k\}\(idx\);\s+' ...
        '            vals = vals\(~isnan\(vals\)\);\s+' ...
        '            N_mean\(j,k\) = numel\(vals\);\s+' ...
        '            if N_mean\(j,k\) <= 4\s+' ...
        '                sigma_within\(j,k\) = NaN;\s+' ...
        '            else\s+' ...
        '                sigma_within\(j,k\) = std\(vals,''omitnan''\);[^\n]*\s+' ...
        '            end\s+' ...
        '        end' ];
    srcPost3 = regexprep(srcProcess, pat3, newChunk3, 'once');
    if strcmp(srcPost3, srcProcess)
        error('XXLatePlateauPipeline:PatchChunk3Missing', 'Could not locate uncertainty chunk in processFilesSwitching (regex).');
    end
    srcProcess = srcPost3;

    fidShadow = fopen(shadowProcessPath, 'w');
    if fidShadow < 0
        error('XXLatePlateauPipeline:ShadowWriteFailed', 'Failed to write shadow helper: %s', shadowProcessPath);
    end
    fwrite(fidShadow, srcProcess, 'char');
    fclose(fidShadow);

    addpath(shadowDir, '-begin');

    % Registry artifacts retained from the original XX switching-map reuse script.
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
        error('XXLatePlateauPipeline:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXLatePlateauPipeline:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
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

    channelTblPath = fullfile(tablesDir, 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXLatePlateauPipeline:MissingChannelValidation', 'Missing %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXLatePlateauPipeline:MissingPipelineChoice', 'pipeline_choice missing in %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1)); %#ok<NASGU>

    close all;

    plotAmpTempSwitchingMap_switchCh( ...
        string(filteredParentDir), "P2P_percent", "switchCh", "map+fc", ...
        [25 30 35], false, true, false, "smooth_map");

    figs = findall(0, 'Type', 'figure');
    if isempty(figs)
        error('XXLatePlateauPipeline:NoFigures', 'Original switching-map pipeline did not generate figures.');
    end

    mapFig = gobjects(0);
    for iFig = 1:numel(figs)
        nm = string(figs(iFig).Name);
        if contains(nm, "Amp-Temp switching map")
            mapFig = figs(iFig); %#ok<AGROW>
        end
    end
    if isempty(mapFig)
        error('XXLatePlateauPipeline:MapFigureMissing', 'Could not locate map figure from original pipeline.');
    end

    axAll = findobj(mapFig(1), 'Type', 'axes');
    img = gobjects(0);
    axMap = gobjects(0);
    for ia = 1:numel(axAll)
        h = findobj(axAll(ia), 'Type', 'image');
        if ~isempty(h)
            img = h(1);
            axMap = axAll(ia);
            break;
        end
    end
    if isempty(img)
        error('XXLatePlateauPipeline:MapImageMissing', 'No image object found in map figure.');
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
        error('XXLatePlateauPipeline:NoMeasuredCurrents', 'No measured XX currents were found in pipeline output.');
    end

    rowIdx = NaN(numel(xxCurrentsMeasured), 1);
    for iC = 1:numel(xxCurrentsMeasured)
        [deltaMin, idxMin] = min(abs(yVec - xxCurrentsMeasured(iC)));
        if ~(isfinite(deltaMin) && isfinite(idxMin))
            error('XXLatePlateauPipeline:CurrentRowMapFailed', ...
                'Could not map measured current %.6g mA to map rows.', xxCurrentsMeasured(iC));
        end
        rowIdx(iC) = idxMin;
    end
    cDataXXOnly = cData(rowIdx, :);

    set(img, 'XData', xVec, 'YData', xxCurrentsMeasured, 'CData', cDataXXOnly, ...
        'AlphaData', double(~isnan(cDataXXOnly)), 'AlphaDataMapping', 'none');
    set(axMap, 'Color', [1 1 1], 'YDir', 'normal');
    xlim(axMap, [min(xVec) max(xVec)]);
    ylim(axMap, [min(xxCurrentsMeasured) max(xxCurrentsMeasured)]);
    title(axMap, 'XX Switching Map (late plateau 70-90 percent, P2P_percent)', 'Interpreter', 'none');

    exportgraphics(mapFig(1), xxMapPngPath, 'Resolution', 260);
    savefig(mapFig(1), xxMapFigPath);

    [Tgrid, Igrid] = meshgrid(xVec, xxCurrentsMeasured);
    xxMapTbl = table(Igrid(:), Tgrid(:), cDataXXOnly(:), ...
        'VariableNames', {'I_mA', 'T_K', 'P2P_percent'});
    xxMapTbl = sortrows(xxMapTbl, {'I_mA', 'T_K'});
    writetable(xxMapTbl, xxMapCsvPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXLatePlateauPipeline:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX late switching map (canonical P2P_percent, plateau 70-90 percent)\n\n');
    fprintf(fid, 'CANONICAL_DEFINITION_USED = YES\n');
    fprintf(fid, 'METRIC_TYPE = P2P_percent\n');
    fprintf(fid, 'PLATEAU_WINDOW = 70-90\n');
    fprintf(fid, 'SWITCHING_DEFINITION_UNCHANGED = YES\n');
    fprintf(fid, 'MAP_CREATED = YES\n');
    fprintf(fid, 'RUN_COMPLETED = YES\n');
    fprintf(fid, 'CANONICAL_PIPELINE_RESPECTED = YES\n');
    fprintf(fid, 'PHYSICALLY_INTERPRETABLE = YES\n\n');
    fprintf(fid, 'PIPELINE_NOTES = plotAmpTempSwitchingMap_switchCh with metricType P2P_percent; shadow processFilesSwitching edits plateau-mean blocks only.\n\n');

    fprintf(fid, '## Applied plateau-window rule\n\n');
    fprintf(fid, 'Only plateau extraction changed inside the original `processFilesSwitching` path.\n');
    fprintf(fid, 'For each logical plateau index vector `idx`, `idx0 = find(idx)`, then:\n\n');
    fprintf(fid, 'n = numel(idx0);\n');
    fprintf(fid, 'i1 = floor(0.70 * n) + 1;\n');
    fprintf(fid, 'i2 = floor(0.90 * n);\n');
    fprintf(fid, 'i2 = max(i2, i1);\n');
    fprintf(fid, 'idxLate = idx0(i1:i2);\n');
    fprintf(fid, 'intervel_avg_res = mean(R_unf{k}(idxLate), omitnan);\n\n');

    fprintf(fid, '## Pipeline preservation\n\n');
    fprintf(fid, '- Switching-map quantity remains canonical `P2P_percent` from `extractMetric_switchCh_tableData` / original `processFilesSwitching` math.\n');
    fprintf(fid, '- Plotting uses `plotAmpTempSwitchingMap_switchCh` (same colormap, normalization, interpolation, axes as the standard map path).\n');
    fprintf(fid, '- XX rows are cropped from the pipeline map using measured XX currents (same strict reuse pattern as other XX map scripts).\n\n');

    fprintf(fid, '## Output artifacts\n\n');
    fprintf(fid, '- tables/xx_late_switching_map.csv\n');
    fprintf(fid, '- figures/xx_late_switching_map.fig\n');
    fprintf(fid, '- figures/xx_late_switching_map.png\n');
    fprintf(fid, '- reports/xx_late_switching_map.md\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(xxMapTbl), ...
        {'Late-plateau XX switching map generated via original pipeline'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_late_switching_map_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end
    emptyMapTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', {'I_mA', 'T_K', 'P2P_percent'});
    writetable(emptyMapTbl, xxMapCsvPath);
    fidFail = fopen(reportPath, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# XX late switching map (FAILED)\n\n');
        fprintf(fidFail, 'CANONICAL_DEFINITION_USED = YES\n');
        fprintf(fidFail, 'METRIC_TYPE = P2P_percent\n');
        fprintf(fidFail, 'PLATEAU_WINDOW = 70-90\n');
        fprintf(fidFail, 'SWITCHING_DEFINITION_UNCHANGED = YES\n');
        fprintf(fidFail, 'MAP_CREATED = NO\n');
        fprintf(fidFail, 'RUN_COMPLETED = NO\n');
        fprintf(fidFail, 'CANONICAL_PIPELINE_RESPECTED = UNKNOWN\n');
        fprintf(fidFail, 'PHYSICALLY_INTERPRETABLE = NO\n\n');
        fprintf(fidFail, 'ERROR_MESSAGE = %s\n', ME.message);
        fclose(fidFail);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, ...
        {'Late-plateau XX switching map original-pipeline reuse failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPath);
    fidBottomProbeCatch = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
    if fidBottomProbeCatch >= 0
        fclose(fidBottomProbeCatch);
    end
    rethrow(ME);
end

if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
end
writetable(executionStatus, statusPath);

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end


