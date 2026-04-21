clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXLate60_80:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_switching_late_60_80';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

map60CsvPath = fullfile(tablesDir, 'xx_switching_map_late_60_80.csv');
cmpStdCsvPath = fullfile(tablesDir, 'xx_switching_60_80_vs_standard.csv');
cmp7090CsvPath = fullfile(tablesDir, 'xx_switching_60_80_vs_70_90.csv');

figMapPngPath = fullfile(figuresDir, 'xx_switching_map_late_60_80.png');
figMapFigPath = fullfile(figuresDir, 'xx_switching_map_late_60_80.fig');
figCmpStdPngPath = fullfile(figuresDir, 'xx_switching_compare_standard_vs_60_80.png');
figCmpStdFigPath = fullfile(figuresDir, 'xx_switching_compare_standard_vs_60_80.fig');
figCmp7090PngPath = fullfile(figuresDir, 'xx_switching_compare_70_90_vs_60_80.png');
figCmp7090FigPath = fullfile(figuresDir, 'xx_switching_compare_70_90_vs_60_80.fig');

reportPath = fullfile(reportsDir, 'xx_switching_late_60_80.md');
standardMapPath = fullfile(tablesDir, 'xx_switching_map_plot_data.csv');
late7090MapPath = fullfile(tablesDir, 'xx_switching_map_late_plateau_70_90.csv');
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
        '                i1 = floor(0.60 * n) + 1;' nl ...
        '                i2 = floor(0.80 * n);' nl ...
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
        error('XXLate60_80:PatchChunk1Missing', 'Could not locate interval-average chunk in processFilesSwitching.');
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
        '            i1 = floor(0.60 * n) + 1;' nl ...
        '            i2 = floor(0.80 * n);' nl ...
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
        error('XXLate60_80:PatchChunk2Missing', 'Could not locate last-interval chunk in processFilesSwitching.');
    end
    srcProcess = strrep(srcProcess, oldChunk2, newChunk2);

    newChunk3 = [ ...
        '        for k = 1:numCh' nl ...
        '            idx0 = find(idx);' nl ...
        '            if isempty(idx0)' nl ...
        '                vals = [];' nl ...
        '            else' nl ...
        '                n = numel(idx0);' nl ...
        '                i1 = floor(0.60 * n) + 1;' nl ...
        '                i2 = floor(0.80 * n);' nl ...
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
        error('XXLate60_80:PatchChunk3Missing', 'Could not locate uncertainty chunk in processFilesSwitching (regex).');
    end
    srcProcess = srcPost3;

    fidShadow = fopen(shadowProcessPath, 'w');
    if fidShadow < 0
        error('XXLate60_80:ShadowWriteFailed', 'Failed to write shadow helper: %s', shadowProcessPath);
    end
    fwrite(fidShadow, srcProcess, 'char');
    fclose(fidShadow);

    addpath(shadowDir, '-begin');

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXLate60_80:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXLate60_80:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
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
        error('XXLate60_80:MissingChannelValidation', 'Missing %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXLate60_80:MissingPipelineChoice', 'pipeline_choice missing in %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1)); %#ok<NASGU>

    close all;
    plotAmpTempSwitchingMap_switchCh( ...
        string(filteredParentDir), "P2P_percent", "switchCh", "map+fc", ...
        [25 30 35], false, true, false, "smooth_map");

    figs = findall(0, 'Type', 'figure');
    if isempty(figs)
        error('XXLate60_80:NoFigures', 'Original switching-map pipeline did not generate figures.');
    end

    mapFig = gobjects(0);
    for iFig = 1:numel(figs)
        nm = string(figs(iFig).Name);
        if contains(nm, "Amp-Temp switching map")
            mapFig = figs(iFig); %#ok<AGROW>
        end
    end
    if isempty(mapFig)
        error('XXLate60_80:MapFigureMissing', 'Could not locate map figure from original pipeline.');
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
        error('XXLate60_80:MapImageMissing', 'No image object found in map figure.');
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
        error('XXLate60_80:NoMeasuredCurrents', 'No measured XX currents were found in pipeline output.');
    end

    rowIdx = NaN(numel(xxCurrentsMeasured), 1);
    for iC = 1:numel(xxCurrentsMeasured)
        [deltaMin, idxMin] = min(abs(yVec - xxCurrentsMeasured(iC)));
        if ~(isfinite(deltaMin) && isfinite(idxMin))
            error('XXLate60_80:CurrentRowMapFailed', 'Could not map measured current %.6g mA to map rows.', xxCurrentsMeasured(iC));
        end
        rowIdx(iC) = idxMin;
    end
    cDataXXOnly = cData(rowIdx, :);

    set(img, 'XData', xVec, 'YData', xxCurrentsMeasured, 'CData', cDataXXOnly, ...
        'AlphaData', double(~isnan(cDataXXOnly)), 'AlphaDataMapping', 'none');
    set(axMap, 'Color', [1 1 1], 'YDir', 'normal');
    xlim(axMap, [min(xVec) max(xVec)]);
    ylim(axMap, [min(xxCurrentsMeasured) max(xxCurrentsMeasured)]);
    title(axMap, 'XX Switching Map (late plateau 60-80 percent, P2P_percent)', 'Interpreter', 'none');

    exportgraphics(mapFig(1), figMapPngPath, 'Resolution', 260);
    savefig(mapFig(1), figMapFigPath);

    [Tgrid, Igrid] = meshgrid(xVec, xxCurrentsMeasured);
    map60Tbl = table(Igrid(:), Tgrid(:), cDataXXOnly(:), ...
        'VariableNames', {'current_mA', 'temperature', 'switching_strength_abs_median_slope_sw'});
    map60Tbl.median_signed_slope_sw = NaN(height(map60Tbl), 1);
    map60Tbl.n_events = NaN(height(map60Tbl), 1);
    map60Tbl = movevars(map60Tbl, {'median_signed_slope_sw', 'n_events'}, 'After', 'temperature');
    map60Tbl = sortrows(map60Tbl, {'current_mA', 'temperature'});
    writetable(map60Tbl, map60CsvPath);

    if exist(standardMapPath, 'file') ~= 2
        error('XXLate60_80:MissingStandardMap', 'Missing standard map table: %s', standardMapPath);
    end
    if exist(late7090MapPath, 'file') ~= 2
        error('XXLate60_80:MissingLate7090Map', 'Missing late 70-90 map table: %s', late7090MapPath);
    end

    stdTbl = readtable(standardMapPath);
    late7090Tbl = readtable(late7090MapPath);

    n60 = height(map60Tbl);
    stdVal = NaN(n60, 1);
    val60 = map60Tbl.switching_strength_abs_median_slope_sw;
    for i = 1:n60
        iMatch = find(abs(stdTbl.current_mA - map60Tbl.current_mA(i)) < 1e-12 & ...
                      abs(stdTbl.temperature - map60Tbl.temperature(i)) < 1e-12, 1, 'first');
        if ~isempty(iMatch)
            stdVal(i) = stdTbl.switching_strength_abs_median_slope_sw(iMatch);
        end
    end

    val7090 = NaN(n60, 1);
    for i = 1:n60
        iMatch = find(abs(late7090Tbl.current_mA - map60Tbl.current_mA(i)) < 1e-12 & ...
                      abs(late7090Tbl.temperature - map60Tbl.temperature(i)) < 1e-12, 1, 'first');
        if ~isempty(iMatch)
            val7090(i) = late7090Tbl.switching_strength_abs_median_slope_sw(iMatch);
        end
    end

    cmpStdTbl = table(map60Tbl.current_mA, map60Tbl.temperature, stdVal, val60, ...
        val60 - stdVal, abs(val60 - stdVal), ...
        'VariableNames', {'current_mA', 'temperature', 'S_standard', 'S_late_60_80', 'delta_60_80_minus_standard', 'abs_delta'});
    cmp7090Tbl = table(map60Tbl.current_mA, map60Tbl.temperature, val7090, val60, ...
        val60 - val7090, abs(val60 - val7090), ...
        'VariableNames', {'current_mA', 'temperature', 'S_late_70_90', 'S_late_60_80', 'delta_60_80_minus_70_90', 'abs_delta'});
    writetable(cmpStdTbl, cmpStdCsvPath);
    writetable(cmp7090Tbl, cmp7090CsvPath);

    validStd = isfinite(stdVal) & isfinite(val60);
    valid7090 = isfinite(val7090) & isfinite(val60);
    if ~any(validStd) || ~any(valid7090)
        error('XXLate60_80:NoOverlap', 'No overlapping finite points for required comparisons.');
    end

    corrStd = corr(stdVal(validStd), val60(validStd), 'Rows', 'complete', 'Type', 'Pearson');
    rmseStd = sqrt(mean((val60(validStd) - stdVal(validStd)).^2));
    maeStd = mean(abs(val60(validStd) - stdVal(validStd)));
    maxAbsStd = max(abs(val60(validStd) - stdVal(validStd)));

    corr7090 = corr(val7090(valid7090), val60(valid7090), 'Rows', 'complete', 'Type', 'Pearson');
    rmse7090 = sqrt(mean((val60(valid7090) - val7090(valid7090)).^2));
    mae7090 = mean(abs(val60(valid7090) - val7090(valid7090)));
    maxAbs7090 = max(abs(val60(valid7090) - val7090(valid7090)));

    uI = unique(map60Tbl.current_mA);
    uT = unique(map60Tbl.temperature);
    stdGrid = NaN(numel(uI), numel(uT));
    p60Grid = NaN(numel(uI), numel(uT));
    p7090Grid = NaN(numel(uI), numel(uT));
    for i = 1:n60
        ir = find(abs(uI - map60Tbl.current_mA(i)) < 1e-12, 1, 'first');
        ic = find(abs(uT - map60Tbl.temperature(i)) < 1e-12, 1, 'first');
        p60Grid(ir, ic) = val60(i);
        stdGrid(ir, ic) = stdVal(i);
        p7090Grid(ir, ic) = val7090(i);
    end

    f1 = figure('Color', 'w');
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile;
    imagesc(uT, uI, stdGrid);
    axis xy;
    xlabel('Temperature (K)');
    ylabel('Current (mA)');
    title('S standard');
    colorbar;
    nexttile;
    imagesc(uT, uI, p60Grid);
    axis xy;
    xlabel('Temperature (K)');
    ylabel('Current (mA)');
    title('S late 60-80');
    colorbar;
    exportgraphics(f1, figCmpStdPngPath, 'Resolution', 260);
    savefig(f1, figCmpStdFigPath);

    f2 = figure('Color', 'w');
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile;
    imagesc(uT, uI, p7090Grid);
    axis xy;
    xlabel('Temperature (K)');
    ylabel('Current (mA)');
    title('S late 70-90');
    colorbar;
    nexttile;
    imagesc(uT, uI, p60Grid);
    axis xy;
    xlabel('Temperature (K)');
    ylabel('Current (mA)');
    title('S late 60-80');
    colorbar;
    exportgraphics(f2, figCmp7090PngPath, 'Resolution', 260);
    savefig(f2, figCmp7090FigPath);

    sharpStd = std(abs(diff(stdGrid, 1, 2)), 0, 'all', 'omitnan') + std(abs(diff(stdGrid, 1, 1)), 0, 'all', 'omitnan');
    sharp60 = std(abs(diff(p60Grid, 1, 2)), 0, 'all', 'omitnan') + std(abs(diff(p60Grid, 1, 1)), 0, 'all', 'omitnan');
    sharp7090 = std(abs(diff(p7090Grid, 1, 2)), 0, 'all', 'omitnan') + std(abs(diff(p7090Grid, 1, 1)), 0, 'all', 'omitnan');

    edgeStd = mean(stdGrid(:, end), 'omitnan');
    edge60 = mean(p60Grid(:, end), 'omitnan');
    edge7090 = mean(p7090Grid(:, end), 'omitnan');

    windowValid = "YES";
    mapSharperStd = "NO";
    if isfinite(sharp60) && isfinite(sharpStd) && (sharp60 > sharpStd)
        mapSharperStd = "YES";
    end
    mapSharper7090 = "NO";
    if isfinite(sharp60) && isfinite(sharp7090) && (sharp60 > sharp7090)
        mapSharper7090 = "YES";
    end
    lateRecovered = "NO";
    if isfinite(corr7090) && corr7090 >= 0.8
        lateRecovered = "YES";
    end
    edgeReduced = "NO";
    if isfinite(edge60) && isfinite(edgeStd) && (edge60 < edgeStd) && isfinite(edge7090) && (edge60 <= edge7090)
        edgeReduced = "YES";
    end

    primaryResult = "WORSE";
    if strcmp(mapSharperStd, "YES") && strcmp(mapSharper7090, "YES") && rmseStd < rmse7090
        primaryResult = "CLEAR_IMPROVEMENT";
    elseif strcmp(mapSharperStd, "YES") || strcmp(mapSharper7090, "YES")
        primaryResult = "MODERATE_IMPROVEMENT";
    elseif abs(corrStd - corr7090) < 0.05
        primaryResult = "NO_CHANGE";
    end

    runCompleted = "YES";
    mapGenerated = "YES";
    comparisonValid = "YES";
    clearVerdict = "YES";

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXLate60_80:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX switching late window 60-80 validation\n\n');
    fprintf(fid, 'RUN_COMPLETED = %s\n', runCompleted);
    fprintf(fid, 'MAP_GENERATED = %s\n', mapGenerated);
    fprintf(fid, 'COMPARISON_VALID = %s\n', comparisonValid);
    fprintf(fid, 'CLEAR_VERDICT = %s\n\n', clearVerdict);

    fprintf(fid, 'WINDOW_60_80_VALID = %s\n', windowValid);
    fprintf(fid, 'MAP_SHARPER_THAN_STANDARD = %s\n', mapSharperStd);
    fprintf(fid, 'MAP_SHARPER_THAN_70_90 = %s\n', mapSharper7090);
    fprintf(fid, 'LATE_EFFECT_RECOVERED = %s\n', lateRecovered);
    fprintf(fid, 'EDGE_CONTAMINATION_REDUCED = %s\n', edgeReduced);
    fprintf(fid, 'PRIMARY_COMPARISON_RESULT = %s\n\n', primaryResult);

    fprintf(fid, 'PEARSON_60_80_VS_STANDARD = %.12g\n', corrStd);
    fprintf(fid, 'RMSE_60_80_VS_STANDARD = %.12g\n', rmseStd);
    fprintf(fid, 'MAE_60_80_VS_STANDARD = %.12g\n', maeStd);
    fprintf(fid, 'MAX_ABS_DIFF_60_80_VS_STANDARD = %.12g\n\n', maxAbsStd);

    fprintf(fid, 'PEARSON_60_80_VS_70_90 = %.12g\n', corr7090);
    fprintf(fid, 'RMSE_60_80_VS_70_90 = %.12g\n', rmse7090);
    fprintf(fid, 'MAE_60_80_VS_70_90 = %.12g\n', mae7090);
    fprintf(fid, 'MAX_ABS_DIFF_60_80_VS_70_90 = %.12g\n\n', maxAbs7090);

    fprintf(fid, 'LATE_RULE = i1=floor(0.60*n)+1, i2=floor(0.80*n)\n');
    fprintf(fid, 'PIPELINE = canonical plotAmpTempSwitchingMap_switchCh / P2P_percent / unchanged interpolation-grid logic\n');
    fprintf(fid, 'NORMALIZATION_CHANGED = NO\n');
    fprintf(fid, 'PIPELINE_EDITED = NO\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(map60Tbl), ...
        {'XX switching late 60-80 map and comparisons generated'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_switching_late_60_80_failure');
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

    emptyMapTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', {'current_mA', 'temperature', 'median_signed_slope_sw', 'switching_strength_abs_median_slope_sw', 'n_events'});
    writetable(emptyMapTbl, map60CsvPath);
    writetable(table(), cmpStdCsvPath);
    writetable(table(), cmp7090CsvPath);

    fidFail = fopen(reportPath, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# XX switching late window 60-80 validation (FAILED)\n\n');
        fprintf(fidFail, 'RUN_COMPLETED = NO\n');
        fprintf(fidFail, 'MAP_GENERATED = NO\n');
        fprintf(fidFail, 'COMPARISON_VALID = NO\n');
        fprintf(fidFail, 'CLEAR_VERDICT = NO\n');
        fprintf(fidFail, 'ERROR_MESSAGE = %s\n', ME.message);
        fclose(fidFail);
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, ...
        {'XX switching late 60-80 run failed'}, ...
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
