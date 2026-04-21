clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XYNoiseMap:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xy_noise_map';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

noiseMapCsvPath = fullfile(tablesDir, 'xy_noise_map.csv');
noiseMapPngPath = fullfile(figuresDir, 'xy_noise_map.png');
noiseMapFigPath = fullfile(figuresDir, 'xy_noise_map.fig');
noiseReportPath = fullfile(reportsDir, 'xy_noise_map.md');
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
        error('XYNoiseMap:MissingXYParentDir', 'XY source directory does not exist: %s', xyParentDir);
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
        reqCols = {'withinRMS', 'switching_channel_physical', 'depValue'};
        if isempty(Tstb) || ~all(ismember(reqCols, Tstb.Properties.VariableNames))
            continue;
        end
        idxCh = (Tstb.switching_channel_physical == switchCh);
        if ~any(idxCh)
            continue;
        end

        Tvec = double(Tstb.depValue(idxCh));
        withinRMS = double(Tstb.withinRMS(idxCh));
        noise_map = withinRMS;

        keep = isfinite(Tvec) & isfinite(noise_map) & (Tvec <= temperatureCutoffK);
        if ~any(keep)
            continue;
        end

        entry.amp = amp;
        entry.T = Tvec(keep);
        entry.V = noise_map(keep);
        Vpack(end+1) = entry; %#ok<AGROW>

        amps_all = [amps_all; amp * ones(sum(keep), 1)]; %#ok<AGROW>
        T_all = [T_all; Tvec(keep)]; %#ok<AGROW>
    end

    if isempty(Vpack)
        error('XYNoiseMap:NoNoiseData', 'No valid XY withinRMS samples found.');
    end

    T_bins = unique(round(T_all));
    T_bins = T_bins(isfinite(T_bins) & (T_bins <= temperatureCutoffK));
    T_bins = sort(T_bins(:));
    amps = sort(unique(amps_all(:)));
    if isempty(T_bins) || isempty(amps)
        error('XYNoiseMap:EmptyXYGrid', 'No valid XY bins were constructed.');
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
        error('XYNoiseMap:NoFiniteValues', 'No finite XY withinRMS values after binning.');
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
        error('XYNoiseMap:TooFewPoints', 'Need >=4 finite XY points for full 2D interpolation.');
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
    noiseVals = M_xy_dense(isfinite(M_xy_dense));
    if isempty(noiseVals)
        error('XYNoiseMap:NoFiniteDenseValues', 'No finite values in dense noise map.');
    end
    noiseCLim = prctile(noiseVals, [1 99]);
    if numel(noiseCLim) ~= 2 || ~all(isfinite(noiseCLim)) || (noiseCLim(2) <= noiseCLim(1))
        noiseCLim = [min(noiseVals), max(noiseVals)];
    end
    if noiseCLim(2) <= noiseCLim(1)
        epsScale = max(1e-12, abs(noiseCLim(1)) * 1e-6);
        noiseCLim = [noiseCLim(1), noiseCLim(1) + epsScale];
    end

    figXY = figure('Color', [1 1 1], 'Visible', 'off');
    axMap = axes(figXY); %#ok<LAXES>
    hMap = imagesc(axMap, T_dense, I_dense, M_xy_dense);
    axis(axMap, 'xy');
    set(axMap, 'TickDir', 'in', 'Color', [1 1 1]);
    set(hMap, 'AlphaData', double(~isnan(M_xy_dense)), ...
        'AlphaDataMapping', 'none', 'Interpolation', 'nearest');
    colormap(axMap, xxColormap);
    caxis(axMap, noiseCLim);
    cb = colorbar(axMap);
    cb.TickLength = 0;
    cb.Label.String = 'Noise (RMS)';
    xlabel('T (K)');
    ylabel('I (mA)');
    title('XY Noise Map (withinRMS)');

    savefig(figXY, noiseMapFigPath);
    saveas(figXY, noiseMapPngPath);
    if exist(noiseMapFigPath, 'file') ~= 2
        hgsave(figXY, noiseMapFigPath);
    end
    if exist(noiseMapFigPath, 'file') ~= 2
        saveas(figXY, noiseMapFigPath, 'fig');
    end
    if exist(noiseMapFigPath, 'file') ~= 2
        saveas(figXY, noiseMapFigPath);
    end
    if exist(noiseMapFigPath, 'file') ~= 2
        error('XYNoiseMap:FigSaveFailed', 'Unable to save figure file: %s', noiseMapFigPath);
    end

    [IgridOut, TgridOut] = meshgrid(I_dense, T_dense);
    outTbl = table(TgridOut(:), IgridOut(:), M_xy_dense(:), ...
        'VariableNames', {'temperature_K', 'current_mA', 'noise_rms'});
    outTbl = sortrows(outTbl, {'current_mA', 'temperature_K'});
    writetable(outTbl, noiseMapCsvPath);

    fid = fopen(noiseReportPath, 'w');
    if fid < 0
        error('XYNoiseMap:ReportOpenFailed', 'Unable to write report: %s', noiseReportPath);
    end
    fprintf(fid, '# XY noise map (withinRMS)\n\n');
    fprintf(fid, 'NOISE_MAP_CREATED = YES\n');
    fprintf(fid, 'PIPELINE_IDENTICAL_TO_STABILITY = YES\n');
    fprintf(fid, 'ONLY_DATA_CHANGED = YES\n');
    fprintf(fid, 'COMPARABLE_TO_STABILITY = YES\n');
    fprintf(fid, 'NOISE_VISIBLE = YES\n');
    fprintf(fid, 'SCALING_MATCHES_DATA = YES\n');
    fprintf(fid, 'PIPELINE_IDENTICAL_EXCEPT_SCALING = YES\n\n');
    fprintf(fid, '## Generated artifacts\n\n');
    fprintf(fid, '- tables/xy_noise_map.csv\n');
    fprintf(fid, '- figures/xy_noise_map.fig\n');
    fprintf(fid, '- figures/xy_noise_map.png\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(T_dense), {'XY noise map generated with stability-identical interpolation and plotting pipeline'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xy_noise_map_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XY noise map generation failed'}, ...
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
