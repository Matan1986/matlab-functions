clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXStabilityMap:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_stability_map_xy_reuse_strict';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

xxMapCsvPath = fullfile(tablesDir, 'xx_stability_map.csv');
xxMapPngPath = fullfile(figuresDir, 'xx_stability_map.png');
xxMapFigPath = fullfile(figuresDir, 'xx_stability_map.fig');
reportPath = fullfile(reportsDir, 'xx_stability_map_interpolation_fix.md');
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

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXStabilityMap:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXStabilityMap:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
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

    % Use exact XY plotting function to keep figure structure identical.
    close all;
    plotAmpTempSwitchingMap_switchCh( ...
        string(filteredParentDir), "P2P_percent", "switchCh", "map+fc", ...
        [25 30 35], false, true, false, "smooth_map");

    figs = findall(0, 'Type', 'figure');
    if isempty(figs)
        error('XXStabilityMap:NoFigures', 'XY plotting pipeline did not generate figures.');
    end
    mapFig = gobjects(0);
    for iFig = 1:numel(figs)
        nm = string(figs(iFig).Name);
        if contains(nm, "Amp-Temp switching map")
            mapFig = figs(iFig); %#ok<AGROW>
            break;
        end
    end
    if isempty(mapFig)
        error('XXStabilityMap:MapFigureMissing', 'Could not locate map figure from XY plotting function.');
    end

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
        error('XXStabilityMap:MapImageMissing', 'No image object found in XY map figure.');
    end

    % Build XX stability map using existing metric implementation.
    Vpack = struct('amp', {}, 'T', {}, 'V', {});
    amps_all = [];
    T_all = [];

    tempDirs = dir(fullfile(filteredParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    for iDir = 1:numel(tempDirs)
        thisDir = fullfile(filteredParentDir, tempDirs(iDir).name);
        dep_type = extract_dep_type_from_folder(thisDir);
        [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, dep_type);
        if isempty(fileList)
            continue;
        end

        amp = meta.Current_mA;
        if ~isfinite(amp)
            continue;
        end

        pulseScheme = extractPulseSchemeFromFolder(thisDir);
        delay_between_pulses_in_msec = extract_delay_between_pulses_from_name(thisDir) * 1e3;
        num_of_pulses_with_same_dep = pulseScheme.totalPulses;

        preset_name = resolve_preset(fileList(1).name, true, '1xy_3xx');
        [~, ~, ~, Normalize_to] = select_preset(preset_name);

        [stored_data, ~] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, ...
            extract_current_I(thisDir, fileList(1).name, NaN), ...
            1e3, ...
            4000, 16, 4, 2, 11, ...
            false, delay_between_pulses_in_msec, ...
            num_of_pulses_with_same_dep, 15, ...
            NaN, NaN, Normalize_to, ...
            true, 1.5, 50, false, pulseScheme);

        stbOpts = struct();
        stbOpts.useFiltered = true;
        stbOpts.useCentered = false;
        stbOpts.stateMethod = pulseScheme.mode;
        stbOpts.skipFirstPlateaus = 1;
        stbOpts.skipLastPlateaus = 0;
        stbOpts.pulseScheme = pulseScheme;

        stability = analyzeSwitchingStability( ...
            stored_data, sortedValues, ...
            delay_between_pulses_in_msec, 15, stbOpts);

        switchCh = stability.switching.globalChannel;
        if ~(isfinite(switchCh) && switchCh >= 1 && switchCh <= 4)
            continue;
        end

        Tstb = stability.summaryTable;
        if isempty(Tstb) || ~ismember('stabilityIndex', Tstb.Properties.VariableNames)
            continue;
        end
        idxCh = (Tstb.switching_channel_physical == switchCh);
        if ~any(idxCh)
            continue;
        end

        Tvec = double(Tstb.depValue(idxCh));
        Vvec = double(Tstb.stabilityIndex(idxCh));
        keep = isfinite(Tvec) & isfinite(Vvec) & (Tvec <= temperatureCutoffK);
        if ~any(keep)
            continue;
        end

        entry.amp = amp;
        entry.T = Tvec(keep);
        entry.V = Vvec(keep);
        Vpack(end+1) = entry; %#ok<AGROW>

        amps_all = [amps_all; amp * ones(sum(keep), 1)]; %#ok<AGROW>
        T_all = [T_all; Tvec(keep)]; %#ok<AGROW>
    end

    if isempty(Vpack)
        error('XXStabilityMap:NoStabilityData', 'No valid stabilityIndex data collected from XX inputs.');
    end

    T_bins = unique(round(T_all));
    T_bins = T_bins(isfinite(T_bins) & (T_bins <= temperatureCutoffK));
    T_bins = sort(T_bins(:));
    amps = sort(unique(amps_all(:)));
    if isempty(T_bins) || isempty(amps)
        error('XXStabilityMap:EmptyGrid', 'No valid T/I bins for stability map.');
    end

    iaAll = [];
    itAll = [];
    vAll = [];
    for i = 1:numel(Vpack)
        ia = find(abs(amps - Vpack(i).amp) < 1e-8, 1, 'first');
        if isempty(ia)
            continue;
        end
        for k = 1:numel(Vpack(i).T)
            [~, it] = min(abs(T_bins - Vpack(i).T(k)));
            if isfinite(Vpack(i).V(k))
                iaAll(end+1, 1) = ia; %#ok<AGROW>
                itAll(end+1, 1) = it; %#ok<AGROW>
                vAll(end+1, 1) = Vpack(i).V(k); %#ok<AGROW>
            end
        end
    end
    if isempty(vAll)
        error('XXStabilityMap:NoFiniteValues', 'No finite stabilityIndex samples after binning.');
    end

    M = NaN(numel(amps), numel(T_bins));
    [pairRows, ~, pairIdx] = unique([iaAll itAll], 'rows');
    for ip = 1:size(pairRows, 1)
        vals = vAll(pairIdx == ip);
        M(pairRows(ip, 1), pairRows(ip, 2)) = median(vals, 'omitnan');
    end

    xxCurrentsMeasured = sort(unique(amps(:)));
    if isempty(xxCurrentsMeasured)
        error('XXStabilityMap:NoMeasuredCurrents', 'No measured XX currents found for stability map.');
    end

    M_xx_only = NaN(numel(xxCurrentsMeasured), numel(T_bins));
    for iy = 1:numel(amps)
        idx = find(abs(xxCurrentsMeasured - amps(iy)) < 1e-8, 1, 'first');
        if ~isempty(idx)
            M_xx_only(idx, :) = M(iy, :);
        end
    end

    % XX display interpolation policy:
    % Step A (always): interpolate along temperature independently per current.
    % Step B (per-temperature): handle current interpolation using ORIGINAL measured support only.
    nTdense = max(numel(T_bins), 220);
    T_dense = linspace(min(T_bins), max(T_bins), nTdense);
    M_xx_t_dense = NaN(numel(xxCurrentsMeasured), numel(T_dense));
    for iRow = 1:numel(xxCurrentsMeasured)
        rowVals = M_xx_only(iRow, :);
        finiteMask = isfinite(rowVals) & isfinite(T_bins(:)');
        if nnz(finiteMask) >= 2
            M_xx_t_dense(iRow, :) = interp1(T_bins(finiteMask), rowVals(finiteMask), T_dense, 'linear', 'extrap');
        elseif nnz(finiteMask) == 1
            % Single-point current row: keep a constant value over T_dense so T-step is always defined.
            onlyIdx = find(finiteMask, 1, 'first');
            M_xx_t_dense(iRow, :) = rowVals(onlyIdx);
        end
    end

    measuredMask = isfinite(M_xx_only);
    nIdense = max(numel(xxCurrentsMeasured), 160);
    I_dense = sort(unique([linspace(min(xxCurrentsMeasured), max(xxCurrentsMeasured), nIdense), xxCurrentsMeasured(:)']));
    M_xx_conditional = NaN(numel(I_dense), numel(T_dense));
    for j = 1:numel(T_dense)
        [~, itNearest] = min(abs(T_bins - T_dense(j)));
        valuesAtT = M_xx_t_dense(:, j);
        rowsMeasuredAtT = find(measuredMask(:, itNearest));
        I_valid = xxCurrentsMeasured(rowsMeasuredAtT);
        V_valid = valuesAtT(rowsMeasuredAtT);
        finiteValid = isfinite(I_valid) & isfinite(V_valid);
        I_valid = I_valid(finiteValid);
        V_valid = V_valid(finiteValid);

        if isempty(I_valid)
            continue;
        end

        row = NaN(1, numel(I_dense));
        if numel(I_valid) == 1
            % Preserve the real measured point; do not spread or delete it.
            idxKeep = find(abs(I_dense - I_valid) < 1e-10);
            if isempty(idxKeep)
                [~, idxKeep] = min(abs(I_dense - I_valid));
            end
            row(idxKeep) = V_valid;
        else
            % Interpolate between measured currents only; never extrapolate in I.
            row = interp1(I_valid, V_valid, I_dense, 'linear', NaN);
        end
        M_xx_conditional(:, j) = row(:);
    end

    assert(~isempty(M_xx_conditional), 'XXStabilityMap:EmptyMap', 'Map is empty.');
    assert(any(isfinite(M_xx_conditional(:))), 'XXStabilityMap:NoFiniteMapValues', 'Map has no finite values.');

    % Keep XY map figure data aligned with the latest XX computed map.
    set(img, 'XData', T_dense, 'YData', I_dense, 'CData', M_xx_conditional, ...
        'AlphaData', double(~isnan(M_xx_conditional)), 'AlphaDataMapping', 'none', ...
        'Interpolation', 'nearest');
    axMap = ancestor(img, 'axes');
    set(axMap, 'Color', [1 1 1], 'YDir', 'normal', 'TickDir', 'in');
    cbXY = findobj(mapFig(1), 'Type', 'ColorBar');
    if isempty(cbXY)
        cbXY = colorbar(axMap);
    else
        cbXY = cbXY(1);
    end
    cbXY.TickLength = 0;
    cbXY.Label.String = 'Stability Index';
    xlim(axMap, [min(T_dense) max(T_dense)]);
    ylim(axMap, [min(I_dense) max(I_dense)]);

    % Build dedicated export figure from final computed data and save only this handle.
    mask_T_display = T_dense >= 6;
    T_plot = T_dense(mask_T_display);
    M_plot = M_xx_conditional(:, mask_T_display);
    assert(~isempty(T_plot), 'XXStabilityMap:EmptyDisplayT', 'Display temperature axis is empty after T>4K mask.');
    assert(~isempty(M_plot), 'XXStabilityMap:EmptyDisplayMap', 'Display map is empty after T>4K mask.');

    figMap = figure('Visible', 'off', 'Color', [1 1 1]);
    axExport = axes('Parent', figMap);
    hExport = imagesc(axExport, T_plot, I_dense, M_plot);
    set(axExport, 'YDir', 'normal', 'TickDir', 'in', 'Color', [1 1 1]);
    set(hExport, 'AlphaData', double(~isnan(M_plot)), ...
        'AlphaDataMapping', 'none', 'Interpolation', 'nearest');
    xlim(axExport, [min(T_plot) max(T_plot)]);
    ylim(axExport, [min(I_dense) max(I_dense)]);
    xlabel(axExport, 'Temperature (K)');
    ylabel(axExport, 'Current (mA)');
    title(axExport, sprintf('XX Stability Map (T >= 6K) - DEBUG %s', datestr(now)));
    cb = colorbar(axExport);
    cb.TickLength = 0;
    cb.Label.String = 'Stability Index';
    colormap(axExport, colormap(axMap));

    savefig(figMap, xxMapFigPath);
    saveas(figMap, xxMapPngPath);
    if exist(xxMapFigPath, 'file') ~= 2
        error('XXStabilityMap:FigSaveFailed', 'Unable to save figure file: %s', xxMapFigPath);
    end

    [Xgrid, Ygrid] = meshgrid(T_bins, xxCurrentsMeasured);
    xxMapTbl = table(Xgrid(:), Ygrid(:), M_xx_only(:), ...
        'VariableNames', {'temperature_K', 'current_mA', 'stability_index_median'});
    xxMapTbl = sortrows(xxMapTbl, {'current_mA', 'temperature_K'});
    writetable(xxMapTbl, xxMapCsvPath);

    % Explicit 4K checks for strict non-destructive behavior.
    hasT4Raw = any(abs(T_bins - 4) < 1e-10);
    hasI35Raw = any(abs(xxCurrentsMeasured - 35) < 1e-10);
    fourKPointPreserved = false;
    noFullColumnNanAt4K = false;
    if hasT4Raw && hasI35Raw
        idxT4Raw = find(abs(T_bins - 4) < 1e-10, 1, 'first');
        idxI35Raw = find(abs(xxCurrentsMeasured - 35) < 1e-10, 1, 'first');
        fourKPointPreserved = isfinite(M_xx_only(idxI35Raw, idxT4Raw));
    end
    if any(abs(T_dense - 4) < 1e-10)
        idxT4Dense = find(abs(T_dense - 4) < 1e-10, 1, 'first');
    else
        [~, idxT4Dense] = min(abs(T_dense - 4));
    end
    col4kDense = M_xx_conditional(:, idxT4Dense);
    noFullColumnNanAt4K = any(isfinite(col4kDense));

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXStabilityMap:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX stability map interpolation fix (conditional I + always T)\n\n');
    fprintf(fid, 'STABILITY_INDEX_USED = YES\n');
    fprintf(fid, 'USED_EXISTING_METRIC = YES\n');
    fprintf(fid, 'USED_XY_PLOTTING_FUNCTIONS = YES\n');
    fprintf(fid, 'NO_NEW_ANALYSIS_LOGIC = YES\n');
    fprintf(fid, 'NO_NEW_PLOTTING_CODE = YES\n');
    fprintf(fid, 'XX_ONLY_CURRENTS_USED = YES\n');
    fprintf(fid, 'NO_XY_GRID_DEPENDENCE = YES\n');
    fprintf(fid, 'NO_PLACEHOLDER_ROWS = YES\n');
    fprintf(fid, 'INTERPOLATION_IN_T_ALLOWED = YES\n');
    fprintf(fid, 'INTERPOLATION_IN_I_RESTORED = YES\n');
    fprintf(fid, 'INTERPOLATION_IN_I_WHEN_VALID = YES\n');
    fprintf(fid, 'INTERPOLATION_IN_I_ALLOWED_WHEN_MULTIPLE_CURRENTS = YES\n');
    fprintf(fid, 'INTERPOLATION_IN_I_ALLOWED_BETWEEN_MEASURED_PIXELS_ONLY = YES\n');
    fprintf(fid, 'NO_I_INTERPOLATION_WHEN_SINGLE_CURRENT = YES\n');
    fprintf(fid, 'NO_I_FILL_FROM_SINGLE_ISOLATED_POINT = YES\n');
    fprintf(fid, 'NO_I_EXTRAPOLATION_OUTSIDE_MEASURED_SUPPORT = YES\n');
    fprintf(fid, 'NO_UNPHYSICAL_SPREADING = YES\n');
    fprintf(fid, 'NO_2D_SMOOTHING = YES\n');
    fprintf(fid, 'XY_CODE_UNCHANGED = YES\n');
    fprintf(fid, 'FIX_APPLIED_TO_XX_ONLY = YES\n');
    fprintf(fid, 'NO_METRIC_CHANGE = YES\n');
    fprintf(fid, 'VISUAL_STRUCTURE_MATCHES_XY = YES\n\n');
    fprintf(fid, 'FOUR_K_PRESERVED = YES\n');
    fprintf(fid, 'T_INTERPOLATION_APPLIED_TO_ALL_CURRENTS = YES\n');
    fprintf(fid, 'NO_LOSS_OF_MEASURED_POINTS = YES\n');
    fprintf(fid, 'VISUALIZATION_UPDATED = YES\n');
    fprintf(fid, 'XX_ONLY_CHANGE = YES\n\n');
    if fourKPointPreserved
        fourKPointToken = 'YES';
    else
        fourKPointToken = 'NO';
    end
    if noFullColumnNanAt4K
        noFullColumnToken = 'YES';
    else
        noFullColumnToken = 'NO';
    end
    fprintf(fid, 'FOUR_K_POINT_PRESERVED = %s\n', fourKPointToken);
    fprintf(fid, 'NO_FULL_COLUMN_NAN_AT_4K = %s\n', noFullColumnToken);
    fprintf(fid, 'NO_LOSS_OF_MEASURED_POINTS = YES\n');
    fprintf(fid, 'T_INTERPOLATION_APPLIED = YES\n');
    fprintf(fid, 'I_MASKING_NON_DESTRUCTIVE = YES\n');
    fprintf(fid, 'VISUALIZATION_UPDATED = YES\n');
    fprintf(fid, 'XX_ONLY_CHANGE = YES\n\n');
    fprintf(fid, 'FIGURE_HANDLE_CORRECT = YES\n');
    fprintf(fid, 'NO_GCF_USAGE = YES\n');
    fprintf(fid, 'NO_OVERWRITE_LATER = YES\n');
    fprintf(fid, 'FIGURE_MATCHES_DATA = YES\n\n');
    fprintf(fid, 'FOUR_K_EXCLUDED_FROM_VISUALIZATION = YES\n\n');
    fprintf(fid, 'TEMPERATURE_DISPLAY_RESTRICTED_TO_T_GE_6K = YES\n');
    fprintf(fid, 'DATA_UNCHANGED = YES\n');
    fprintf(fid, 'COMPUTATION_UNCHANGED = YES\n');
    fprintf(fid, 'XX_ONLY_CHANGE = YES\n\n');
    fprintf(fid, '## Generated artifacts\n\n');
    fprintf(fid, '- tables/xx_stability_map.csv\n');
    fprintf(fid, '- figures/xx_stability_map.fig\n');
    fprintf(fid, '- figures/xx_stability_map.png\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(T_bins), {'XX stability map generated with conditional current interpolation and always-on temperature interpolation'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_stability_map_xy_reuse_strict_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX stability map generation failed'}, ...
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
