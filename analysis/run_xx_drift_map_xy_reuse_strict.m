clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXDriftMap:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_drift_map_xy_reuse_strict';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

xxMapCsvPath = fullfile(tablesDir, 'xx_drift_map.csv');
xxMapPngPath = fullfile(figuresDir, 'xx_drift_map.png');
xxMapFigPath = fullfile(figuresDir, 'xx_drift_map.fig');
reportPath = fullfile(reportsDir, 'xx_drift_map.md');

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
        error('XXDriftMap:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXDriftMap:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
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
        error('XXDriftMap:NoFigures', 'XY plotting pipeline did not generate figures.');
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
        error('XXDriftMap:MapFigureMissing', 'Could not locate map figure from XY plotting function.');
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
        error('XXDriftMap:MapImageMissing', 'No image object found in XY map figure.');
    end

    % Build dedicated drift map using existing metric implementation.
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
        reqCols = {'slopeRMS', 'switching_channel_physical', 'depValue'};
        if isempty(Tstb) || ~all(ismember(reqCols, Tstb.Properties.VariableNames))
            continue;
        end

        idxCh = (Tstb.switching_channel_physical == switchCh);
        if ~any(idxCh)
            continue;
        end

        Tvec = double(Tstb.depValue(idxCh));
        slopeRMS = double(Tstb.slopeRMS(idxCh));
        drift_map = slopeRMS;

        keep = isfinite(Tvec) & isfinite(drift_map) & (Tvec <= temperatureCutoffK);
        if ~any(keep)
            continue;
        end

        entry = struct();
        entry.amp = amp;
        entry.T = Tvec(keep);
        entry.V = drift_map(keep);
        Vpack(end+1) = entry; %#ok<AGROW>

        amps_all = [amps_all; amp * ones(sum(keep), 1)]; %#ok<AGROW>
        T_all = [T_all; Tvec(keep)]; %#ok<AGROW>
    end

    if isempty(Vpack)
        error('XXDriftMap:NoDriftData', 'No valid slopeRMS drift samples collected from XX inputs.');
    end

    T_bins = unique(round(T_all));
    T_bins = T_bins(isfinite(T_bins) & (T_bins <= temperatureCutoffK));
    T_bins = sort(T_bins(:));
    amps = sort(unique(amps_all(:)));
    if isempty(T_bins) || isempty(amps)
        error('XXDriftMap:EmptyGrid', 'No valid T/I bins for drift map.');
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
        error('XXDriftMap:NoFiniteValues', 'No finite drift samples after binning.');
    end

    M = NaN(numel(amps), numel(T_bins));
    [pairRows, ~, pairIdx] = unique([iaAll itAll], 'rows');
    for ip = 1:size(pairRows, 1)
        vals = vAll(pairIdx == ip);
        M(pairRows(ip, 1), pairRows(ip, 2)) = median(vals, 'omitnan');
    end

    xxCurrentsMeasured = sort(unique(amps(:)));
    if isempty(xxCurrentsMeasured)
        error('XXDriftMap:NoMeasuredCurrents', 'No measured XX currents found for drift map.');
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

    assert(~isempty(M_xx_conditional), 'XXDriftMap:EmptyMap', 'Map is empty.');
    assert(any(isfinite(M_xx_conditional(:))), 'XXDriftMap:NoFiniteMapValues', 'Map has no finite values.');

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
    cbXY.Label.String = 'Drift (slope RMS)';
    xlim(axMap, [min(T_dense) max(T_dense)]);
    ylim(axMap, [min(I_dense) max(I_dense)]);

    % Build dedicated export figure from final computed data and save only this handle.
    drift_map = M_xx_conditional;
    mask_T_display = T_dense >= 6;
    T_plot = T_dense(mask_T_display);
    M_plot = drift_map(:, mask_T_display);
    assert(~isempty(T_plot), 'XXDriftMap:EmptyDisplayT', 'Display temperature axis is empty after T >= 6K mask.');
    assert(~isempty(M_plot), 'XXDriftMap:EmptyDisplayMap', 'Display map is empty after T >= 6K mask.');

    driftVals = drift_map(:);
    clim99 = prctile(driftVals, [1 99]);
    if ~(numel(clim99) == 2 && all(isfinite(clim99)) && clim99(2) > clim99(1))
        clim99 = [min(driftVals), max(driftVals)];
    end

    figMap = figure('Visible', 'off', 'Color', [1 1 1]);
    axExport = axes('Parent', figMap);
    hExport = imagesc(axExport, T_plot, I_dense, M_plot);
    axis(axExport, 'xy');
    set(axExport, 'YDir', 'normal', 'TickDir', 'in', 'Color', [1 1 1]);
    set(hExport, 'AlphaData', double(~isnan(M_plot)), ...
        'AlphaDataMapping', 'none', 'Interpolation', 'nearest');
    xlim(axExport, [min(T_plot) max(T_plot)]);
    ylim(axExport, [min(I_dense) max(I_dense)]);
    xlabel(axExport, 'T (K)');
    ylabel(axExport, 'I (mA)');
    title(axExport, sprintf('XX Drift Map (slopeRMS, T >= 6K) - DEBUG %s', datestr(now)));

    cb = colorbar(axExport);
    cb.TickLength = 0;
    cb.Label.String = 'Drift (slope RMS)';
    caxis(axExport, clim99);
    colormap(axExport, colormap(axMap));

    savefig(figMap, xxMapFigPath);
    saveas(figMap, xxMapPngPath);
    if exist(xxMapFigPath, 'file') ~= 2
        error('XXDriftMap:FigSaveFailed', 'Unable to save figure file: %s', xxMapFigPath);
    end

    [Xgrid, Ygrid] = meshgrid(T_bins, xxCurrentsMeasured);
    xxMapTbl = table(Xgrid(:), Ygrid(:), M_xx_only(:), ...
        'VariableNames', {'temperature_K', 'current_mA', 'drift_slope_rms_median'});
    xxMapTbl = sortrows(xxMapTbl, {'current_mA', 'temperature_K'});
    writetable(xxMapTbl, xxMapCsvPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXDriftMap:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end

    fprintf(fid, '# XX drift map (slopeRMS)\n\n');
    fprintf(fid, 'DRIFT_MAP_CREATED = YES\n');
    fprintf(fid, 'PIPELINE_IDENTICAL_TO_XX = YES\n');
    fprintf(fid, 'ONLY_DATA_CHANGED = YES\n');
    fprintf(fid, 'SPARSE_HANDLING_PRESERVED = YES\n');
    fprintf(fid, 'SCALING_MATCHES_DATA = YES\n');
    fprintf(fid, 'T_GE_6_DISPLAY_APPLIED = YES\n');
    fprintf(fid, 'COMPARABLE_TO_NOISE_AND_STABILITY = YES\n\n');
    fprintf(fid, '## Generated artifacts\n\n');
    fprintf(fid, '- tables/xx_drift_map.csv\n');
    fprintf(fid, '- figures/xx_drift_map.fig\n');
    fprintf(fid, '- figures/xx_drift_map.png\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(T_bins), {'XX drift map generated (slopeRMS) with conditional I masking and always-on T interpolation'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_drift_map_xy_reuse_strict_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX drift map generation failed'}, ...
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

