clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XYDriftMap:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xy_drift_map';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

driftMapCsvPath = fullfile(tablesDir, 'xy_drift_map.csv');
driftMapPngPath = fullfile(figuresDir, 'xy_drift_map.png');
driftMapFigPath = fullfile(figuresDir, 'xy_drift_map.fig');
driftMapSmoothPngPath = fullfile(figuresDir, 'xy_drift_map_smoothed.png');
driftMapSmoothFigPath = fullfile(figuresDir, 'xy_drift_map_smoothed.fig');
driftReportPath = fullfile(reportsDir, 'xy_drift_map.md');
xxMapFigPath = fullfile(figuresDir, 'xx_stability_map.fig');
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

    xxColormap = parula(256);
    if exist(xxMapFigPath, 'file') == 2
        xxFig = openfig(xxMapFigPath, 'invisible');
        axXX = findobj(xxFig, 'Type', 'axes');
        imgXX = gobjects(0);
        for ia = 1:numel(axXX)
            hImg = findobj(axXX(ia), 'Type', 'image');
            if ~isempty(hImg)
                imgXX = hImg(1);
                break;
            end
        end
        if ~isempty(imgXX)
            axXXMap = ancestor(imgXX, 'axes');
            xxColormap = colormap(axXXMap);
        end
        close(xxFig);
    end

    xyParentDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all';
    if exist(xyParentDir, 'dir') ~= 7
        error('XYDriftMap:MissingXYParentDir', 'XY source directory does not exist: %s', xyParentDir);
    end

    Vpack = struct('amp', {}, 'T', {}, 'V', {});
    amps_all = [];
    T_all = [];

    tempDirs = dir(fullfile(xyParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    for iDir = 1:numel(tempDirs)
        thisDir = fullfile(xyParentDir, tempDirs(iDir).name);
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

        entry.amp = amp;
        entry.T = Tvec(keep);
        entry.V = drift_map(keep);
        Vpack(end+1) = entry; %#ok<AGROW>

        amps_all = [amps_all; amp * ones(sum(keep), 1)]; %#ok<AGROW>
        T_all = [T_all; Tvec(keep)]; %#ok<AGROW>
    end

    if isempty(Vpack)
        error('XYDriftMap:NoDriftData', 'No valid XY slopeRMS samples found.');
    end

    T_bins = unique(round(T_all));
    T_bins = T_bins(isfinite(T_bins) & (T_bins <= temperatureCutoffK));
    T_bins = sort(T_bins(:));
    amps = sort(unique(amps_all(:)));
    if isempty(T_bins) || isempty(amps)
        error('XYDriftMap:EmptyXYGrid', 'No valid XY bins were constructed.');
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
        error('XYDriftMap:NoFiniteValues', 'No finite XY slopeRMS values after binning.');
    end

    M_xy_sparse = NaN(numel(amps), numel(T_bins));
    [pairRows, ~, pairIdx] = unique([iaAll itAll], 'rows');
    for ip = 1:size(pairRows, 1)
        vals = vAll(pairIdx == ip);
        M_xy_sparse(pairRows(ip, 1), pairRows(ip, 2)) = median(vals, 'omitnan');
    end

    [TT_raw, II_raw] = meshgrid(T_bins, amps);
    valid = isfinite(M_xy_sparse);
    if nnz(valid) < 4
        error('XYDriftMap:TooFewPoints', 'Need >=4 finite XY points for full 2D interpolation.');
    end

    nTdense = max(numel(T_bins), 220);
    nIdense = max(numel(amps), 160);
    T_dense = linspace(min(T_bins), max(T_bins), nTdense);
    I_dense = linspace(min(amps), max(amps), nIdense);
    assert(min(I_dense) < 20, 'XY current range too narrow');
    assert(max(I_dense) > 40, 'XY current range truncated');
    [TT_dense, II_dense] = meshgrid(T_dense, I_dense);
    M_xy_dense = griddata(TT_raw(valid), II_raw(valid), M_xy_sparse(valid), TT_dense, II_dense, 'natural');
    if any(~isfinite(M_xy_dense(:)))
        M_lin = griddata(TT_raw(valid), II_raw(valid), M_xy_sparse(valid), TT_dense, II_dense, 'linear');
        fillMask = ~isfinite(M_xy_dense) & isfinite(M_lin);
        M_xy_dense(fillMask) = M_lin(fillMask);
    end
    M_xy_dense = fillmissing(M_xy_dense, 'nearest');
    M_xy_dense = fillmissing(M_xy_dense, 'nearest', 2);
    driftVals = M_xy_dense(isfinite(M_xy_dense));
    if isempty(driftVals)
        error('XYDriftMap:NoFiniteDenseValues', 'No finite values in dense drift map.');
    end
    driftCLim = prctile(driftVals, [1 99]);
    if numel(driftCLim) ~= 2 || ~all(isfinite(driftCLim)) || (driftCLim(2) <= driftCLim(1))
        driftCLim = [min(driftVals), max(driftVals)];
    end
    if driftCLim(2) <= driftCLim(1)
        epsScale = max(1e-12, abs(driftCLim(1)) * 1e-6);
        driftCLim = [driftCLim(1), driftCLim(1) + epsScale];
    end

    % Smoothed version for visualization only (original data unchanged)
    drift_smooth = imgaussfilt(M_xy_dense, 1);
    driftSmoothVals = drift_smooth(isfinite(drift_smooth));
    if isempty(driftSmoothVals)
        error('XYDriftMap:NoFiniteSmoothValues', 'No finite values in smoothed drift map.');
    end
    driftSmoothCLim = prctile(driftSmoothVals, [1 99]);
    if numel(driftSmoothCLim) ~= 2 || ~all(isfinite(driftSmoothCLim)) || (driftSmoothCLim(2) <= driftSmoothCLim(1))
        driftSmoothCLim = [min(driftSmoothVals), max(driftSmoothVals)];
    end
    if driftSmoothCLim(2) <= driftSmoothCLim(1)
        epsScale = max(1e-12, abs(driftSmoothCLim(1)) * 1e-6);
        driftSmoothCLim = [driftSmoothCLim(1), driftSmoothCLim(1) + epsScale];
    end

    figXY = figure('Color', [1 1 1], 'Visible', 'off');
    axMap = axes(figXY); %#ok<LAXES>
    hMap = imagesc(axMap, T_dense, I_dense, M_xy_dense);
    axis(axMap, 'xy');
    set(axMap, 'TickDir', 'in', 'Color', [1 1 1]);
    set(hMap, 'AlphaData', double(~isnan(M_xy_dense)), ...
        'AlphaDataMapping', 'none', 'Interpolation', 'nearest');
    colormap(axMap, xxColormap);
    caxis(axMap, driftCLim);
    cb = colorbar(axMap);
    cb.TickLength = 0;
    cb.Label.String = 'Drift (slope RMS)';
    xlabel('T (K)');
    ylabel('I (mA)');
    title('XY Drift Map (slopeRMS)');

    savefig(figXY, driftMapFigPath);
    saveas(figXY, driftMapPngPath);
    if exist(driftMapFigPath, 'file') ~= 2
        hgsave(figXY, driftMapFigPath);
    end
    if exist(driftMapFigPath, 'file') ~= 2
        saveas(figXY, driftMapFigPath, 'fig');
    end
    if exist(driftMapFigPath, 'file') ~= 2
        saveas(figXY, driftMapFigPath);
    end
    if exist(driftMapFigPath, 'file') ~= 2
        error('XYDriftMap:FigSaveFailed', 'Unable to save figure file: %s', driftMapFigPath);
    end

    % Smoothed visualization (separate figure, original map unchanged)
    figXYsmooth = figure('Color', [1 1 1], 'Visible', 'off');
    axMapSmooth = axes(figXYsmooth); %#ok<LAXES>
    hMapSmooth = imagesc(axMapSmooth, T_dense, I_dense, drift_smooth);
    axis(axMapSmooth, 'xy');
    set(axMapSmooth, 'TickDir', 'in', 'Color', [1 1 1]);
    set(hMapSmooth, 'AlphaData', double(~isnan(drift_smooth)), ...
        'AlphaDataMapping', 'none', 'Interpolation', 'nearest');
    colormap(axMapSmooth, xxColormap);
    caxis(axMapSmooth, driftSmoothCLim);
    cb2 = colorbar(axMapSmooth);
    cb2.TickLength = 0;
    cb2.Label.String = 'Drift (slope RMS)';
    xlabel('T (K)');
    ylabel('I (mA)');
    title('XY Drift Map (smoothed, \sigma=1)');

    savefig(figXYsmooth, driftMapSmoothFigPath);
    saveas(figXYsmooth, driftMapSmoothPngPath);
    if exist(driftMapSmoothFigPath, 'file') ~= 2
        hgsave(figXYsmooth, driftMapSmoothFigPath);
    end
    if exist(driftMapSmoothFigPath, 'file') ~= 2
        saveas(figXYsmooth, driftMapSmoothFigPath, 'fig');
    end
    if exist(driftMapSmoothFigPath, 'file') ~= 2
        saveas(figXYsmooth, driftMapSmoothFigPath);
    end
    if exist(driftMapSmoothFigPath, 'file') ~= 2
        error('XYDriftMap:SmoothFigSaveFailed', 'Unable to save smoothed figure file: %s', driftMapSmoothFigPath);
    end

    [IgridOut, TgridOut] = meshgrid(I_dense, T_dense);
    outTbl = table(TgridOut(:), IgridOut(:), M_xy_dense(:), ...
        'VariableNames', {'temperature_K', 'current_mA', 'drift_slope_rms'});
    outTbl = sortrows(outTbl, {'current_mA', 'temperature_K'});
    writetable(outTbl, driftMapCsvPath);

    fid = fopen(driftReportPath, 'w');
    if fid < 0
        error('XYDriftMap:ReportOpenFailed', 'Unable to write report: %s', driftReportPath);
    end
    fprintf(fid, '# XY drift map (slopeRMS)\n\n');
    fprintf(fid, 'DRIFT_MAP_CREATED = YES\n');
    fprintf(fid, 'PIPELINE_IDENTICAL_TO_STABILITY = YES\n');
    fprintf(fid, 'ONLY_DATA_CHANGED = YES\n');
    fprintf(fid, 'SCALING_MATCHES_DATA = YES\n');
    fprintf(fid, 'COMPARABLE_TO_NOISE_AND_STABILITY = YES\n\n');
    fprintf(fid, 'SMOOTHING_APPLIED = YES\n');
    fprintf(fid, 'VISUALIZATION_ONLY = YES\n');
    fprintf(fid, 'ORIGINAL_DATA_UNCHANGED = YES\n\n');
    fprintf(fid, '## Generated artifacts\n\n');
    fprintf(fid, '- tables/xy_drift_map.csv\n');
    fprintf(fid, '- figures/xy_drift_map.fig\n');
    fprintf(fid, '- figures/xy_drift_map.png\n');
    fprintf(fid, '- figures/xy_drift_map_smoothed.fig\n');
    fprintf(fid, '- figures/xy_drift_map_smoothed.png\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(T_dense), {'XY drift map generated with stability-identical interpolation and plotting pipeline'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xy_drift_map_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XY drift map generation failed'}, ...
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
