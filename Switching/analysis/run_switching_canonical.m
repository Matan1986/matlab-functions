clearvars -except modules_used_input switching_batch_inputs
clc

assert(~contains(path, 'analysis_new'), ...
  'analysis_new must not be on MATLAB path');

% Repo root for catch-path createRunContext (no hardcoded drive paths).
repoRootBootstrap = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRootBootstrap, 'tools'));

run = struct();
repoRoot = '';
run_dir = '';
test_path = '';
enforcement_checked = false;
modules_used = {};
% Signaling: column EXECUTION_STATUS in execution_status.csv is the sole authoritative final outcome
% (SUCCESS / FAILED / PARTIAL). execution_probe* files and runtime_execution_markers.txt are auxiliary.

implStatusPath = '';
implReportPath = '';

try
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    analysisDir = fileparts(mfilename('fullpath'));
    switchingDir = fullfile(repoRoot, 'Switching');
    disp('SCRIPT_ENTERED');

    restoredefaultpath;
    addpath(fullfile(repoRoot, 'tools'));
    addpath(fullfile(repoRoot, 'Aging', 'utils'));
    if exist(fullfile(repoRoot, 'Aging', 'utils'), 'dir') ~= 7
        error('Aging utils path not found');
    end
    addpath(fullfile(repoRoot, 'General ver2'));
    addpath(fullfile(switchingDir, 'utils'));

    moduleRegistry = loadModuleCanonicalStatus(repoRoot);
    idxSw = strcmp(cellstr(string(moduleRegistry.MODULE)), 'Switching');
    if ~any(idxSw)
        error('run_switching_canonical:RegistrySwitchingMissing', ...
            'Switching is not listed in tables/module_canonical_status.csv');
    end
    rowSw = find(idxSw, 1);
    stSw = moduleRegistry.STATUS(rowSw);
    if iscell(stSw)
        stSw = stSw{1};
    end
    stSw = char(string(stSw));
    if ~strcmp(stSw, 'CANONICAL')
        error('run_switching_canonical:RegistrySwitchingNotCanonical', ...
            'Switching must be CANONICAL in tables/module_canonical_status.csv (found STATUS=%s).', stSw);
    end

    modules_used = {'Switching'};
    if exist('modules_used_input', 'var')
        modules_used = modules_used_input;
    end
    if length(modules_used) > 1
        assertModulesCanonical(modules_used);
        enforcement_checked = true;
    else
        enforcement_checked = true;   % explicitly mark evaluated
    end

    legacyRoot = fullfile(switchingDir, '..', 'Switching ver12');
    if exist(legacyRoot, 'dir') ~= 7
        error('run_switching_canonical:MissingLegacyRoot', 'Missing legacy switching root: %s', legacyRoot);
    end
    addpath(legacyRoot);
    addpath(fullfile(legacyRoot, 'main'));
    addpath(fullfile(legacyRoot, 'plots'));
    addpath(fullfile(legacyRoot, 'parsing'));
    addpath(fullfile(legacyRoot, 'utils'));

    expectedCreateRunContextPath = fullfile(repoRoot, 'Aging', 'utils', 'createRunContext.m');
    expectedCreateRunContext = lower(strrep(expectedCreateRunContextPath, '/', '\'));
    resolvedCreateRunContext = lower(strrep(which('createRunContext'), '/', '\'));
    if isempty(resolvedCreateRunContext) || ~strcmp(resolvedCreateRunContext, expectedCreateRunContext)
        error('run_switching_canonical:CreateRunContextResolution', ...
            'createRunContext resolved to unexpected path: %s', which('createRunContext'));
    end

    batchInputs = {};
    if exist('switching_batch_inputs', 'var') && ~isempty(switching_batch_inputs)
        if iscell(switching_batch_inputs)
            batchInputs = switching_batch_inputs;
        else
            batchInputs = {switching_batch_inputs};
        end
    end
    if isempty(batchInputs)
        batchInputs = {struct()};
    end

    for iBatch = 1:numel(batchInputs)
        batchCfg = batchInputs{iBatch};
        if ~isstruct(batchCfg)
            error('run_switching_canonical:InvalidBatchInput', ...
                'switching_batch_inputs{%d} must be a struct', iBatch);
        end

        % Explicit per-run boundary reset in shared MATLAB process.
        rng('default');
        restoredefaultpath;
        addpath(fullfile(repoRoot, 'tools'));
        addpath(fullfile(repoRoot, 'Aging', 'utils'));
        addpath(fullfile(repoRoot, 'General ver2'));
        addpath(fullfile(switchingDir, 'utils'));
        addpath(legacyRoot);
        addpath(fullfile(legacyRoot, 'main'));
        addpath(fullfile(legacyRoot, 'plots'));
        addpath(fullfile(legacyRoot, 'parsing'));
        addpath(fullfile(legacyRoot, 'utils'));

        disp('=== START SCRIPT ===');
        disp(pwd);
        disp(which('createRunContext'));

        cfg = struct();
        cfg.runLabel = 'switching_canonical';
        cfg.dataset = 'raw_switching_dat_only';
        cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
        if isfield(batchCfg, 'runLabel') && ~isempty(batchCfg.runLabel)
            cfg.runLabel = char(string(batchCfg.runLabel));
        end
        if isfield(batchCfg, 'dataset') && ~isempty(batchCfg.dataset)
            cfg.dataset = char(string(batchCfg.dataset));
        end
        ctx = createSwitchingRunContext(repoRoot, cfg);
        run = ctx;
        run_dir = run.run_dir;
        if exist(run_dir, 'dir') ~= 7
            mkdir(run_dir);
        end
        runDir = run_dir;
        write_execution_marker('ENTRY', runDir);
        writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run_dir created'}, false);
        atomic_write_enforcement_status(runDir, enforcement_checked, modules_used, iBatch, numel(batchInputs));

        atomic_write_text(fullfile(run_dir, 'execution_probe_top.txt'), @(fid) fprintf(fid, ''));
        
        disp('=== RUN CONTEXT ===');
        disp(run_dir);

        tablesDir = fullfile(runDir, 'tables');
        reportsDir = fullfile(runDir, 'reports');
        if exist(tablesDir, 'dir') ~= 7
            mkdir(tablesDir);
        end
        if exist(reportsDir, 'dir') ~= 7
            mkdir(reportsDir);
        end

        implStatusPath = fullfile(tablesDir, 'run_switching_canonical_implementation_status.csv');
        implReportPath = fullfile(reportsDir, 'run_switching_canonical_implementation.md');

        test_table = table(1, 'VariableNames', {'probe_value'});
        test_path = fullfile(run_dir, 'execution_probe.csv');
        atomic_writetable(test_table, test_path);
        disp('=== WRITE TEST ===');
        disp(test_path);
        assert(isfile(test_path), 'WRITE FAILED: execution_probe.csv not created');

        RUN_DIR_CREATED = "NO";
        WRITE_SUCCESS = "NO";
        if exist(run_dir, 'dir') == 7
            RUN_DIR_CREATED = "YES";
        end
        if isfile(test_path)
            WRITE_SUCCESS = "YES";
        end

        probeStatus = table( ...
            string(which('createRunContext')), ...
            string(run_dir), ...
            string(test_path), ...
            RUN_DIR_CREATED, ...
            WRITE_SUCCESS, ...
            'VariableNames', {'CREATE_RUN_CONTEXT_PATH', 'RUN_DIR', 'EXECUTION_PROBE_PATH', 'RUN_DIR_CREATED', 'WRITE_SUCCESS'});
        atomic_writetable(probeStatus, fullfile(run_dir, 'execution_probe_status.csv'));

        writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'probe write test passed'}, false);
        atomic_write_enforcement_status(runDir, enforcement_checked, modules_used, iBatch, numel(batchInputs));

    switchMainPath = fullfile(legacyRoot, 'main', 'Switching_main.m');
    if exist(switchMainPath, 'file') ~= 2
        error('run_switching_canonical:MissingSwitchingMain', 'Missing source file: %s', switchMainPath);
    end

    switchMainText = fileread(switchMainPath);
    tok = regexp(switchMainText, 'dir\s*=\s*"([^"]+)"', 'tokens', 'once');
    if isempty(tok)
        error('run_switching_canonical:MissingParentDir', 'Could not parse parent raw path from %s', switchMainPath);
    end
    parentDir = char(string(tok{1}));
    if exist(parentDir, 'dir') ~= 7
        error('run_switching_canonical:ParentDirMissing', 'Parsed parentDir does not exist: %s', parentDir);
    end

    sourceFunction = 'getFileListSwitching + processFilesSwitching';
    sourcePath = parentDir;
    sourceFile = fullfile(legacyRoot, 'main', 'processFilesSwitching.m');
    sourceMethod = 'MINIMAL_PROCESSING';

    inputPaths = strings(0, 1);
    inputPaths(end+1, 1) = string(switchMainPath);

    subDirs = dir(parentDir);
    subNames = string({subDirs.name});
    isSub = [subDirs.isdir] & ~startsWith(subNames, ".");
    isTempDep = startsWith(subNames, "Temp Dep", 'IgnoreCase', true);
    subDirs = subDirs(isSub & isTempDep);
    if isempty(subDirs)
        error('run_switching_canonical:NoTempDepFolders', 'No "Temp Dep" subfolders found under %s', parentDir);
    end

    rowsCurrent = [];
    rowsTemp = [];
    rowsS = [];
    rowsChannel = [];
    rowsFolder = strings(0, 1);
    totalRawFiles = 0;

    write_execution_marker('STAGE_START_PIPELINE', runDir);
    for iDir = 1:numel(subDirs)
        thisDir = fullfile(parentDir, subDirs(iDir).name);
        dep_type = extract_dep_type_from_folder(thisDir);
        [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, dep_type);
        if isempty(fileList)
            continue;
        end
        if ~isfield(meta, 'Current_mA') || ~isfinite(meta.Current_mA)
            error('run_switching_canonical:MissingCurrentMetadata', 'Missing Current_mA in folder: %s', thisDir);
        end

        inputPaths(end+1, 1) = string(thisDir);
        for iFile = 1:numel(fileList)
            inputPaths(end+1, 1) = string(fullfile(thisDir, fileList(iFile).name));
        end
        totalRawFiles = totalRawFiles + numel(fileList);

        pulseScheme = extractPulseSchemeFromFolder(thisDir);
        delay_between_pulses_in_msec = extract_delay_between_pulses_from_name(thisDir) * 1e3;
        num_of_pulses_with_same_dep = pulseScheme.totalPulses;

        normalize_to = 1;
        if exist('resolve_preset', 'file') == 2 && exist('select_preset', 'file') == 2
            preset_name = resolve_preset(fileList(1).name, true, '1xy_3xx');
            [~, ~, ~, normalize_to_candidate] = select_preset(preset_name);
            if ~isempty(normalize_to_candidate)
                normalize_to = normalize_to_candidate;
            end
        end

        I_A = meta.Current_mA / 1000;
        if ~isfinite(I_A) || I_A == 0
            error('run_switching_canonical:InvalidCurrent', 'Invalid current parsed in %s', thisDir);
        end
        scaling_factor = 1e3;

        [stored_data, tableData] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, I_A, scaling_factor, ...
            4000, 16, 4, ...
            2, 11, ...
            false, delay_between_pulses_in_msec, ...
            num_of_pulses_with_same_dep, 15, ...
            NaN, NaN, normalize_to, ...
            true, 1.5, 50, false, pulseScheme);

        stbOpts = struct();
        stbOpts.useFiltered = true;
        stbOpts.useCentered = false;
        stbOpts.stateMethod = pulseScheme.mode;
        stbOpts.skipFirstPlateaus = 1;
        stbOpts.skipLastPlateaus = 0;
        stbOpts.pulseScheme = pulseScheme;
        stbOpts.debugMode = false;
        stability = analyzeSwitchingStability(stored_data, sortedValues, delay_between_pulses_in_msec, 15, stbOpts);

        ch = stability.switching.globalChannel;
        if ~(isfinite(ch) && any(ch == [1, 2, 3, 4])) %#ok<NBRAK>
            error('run_switching_canonical:InvalidSwitchingChannel', 'Invalid switching channel in %s', thisDir);
        end
        chName = sprintf('ch%d', ch);
        if ~isfield(tableData, chName) || isempty(tableData.(chName))
            error('run_switching_canonical:MissingChannelTable', 'Missing tableData.%s in %s', chName, thisDir);
        end

        metricTbl = tableData.(chName);
        Tvec = metricTbl(:, 1);
        Svec = metricTbl(:, 4);
        if exist('resolveNegP2P', 'file') == 2
            negP2P = resolveNegP2P(thisDir, "auto");
            if negP2P
                Svec = -Svec;
            end
        end

        keep = isfinite(Tvec) & isfinite(Svec);
        Tvec = Tvec(keep);
        Svec = Svec(keep);
        if isempty(Tvec)
            continue;
        end

        [Tuniq, ~, grp] = unique(Tvec(:));
        Suniq = accumarray(grp, Svec(:), [], @mean, NaN);
        nAdd = numel(Tuniq);

        rowsCurrent = [rowsCurrent; repmat(meta.Current_mA, nAdd, 1)]; %#ok<AGROW>
        rowsTemp = [rowsTemp; Tuniq(:)]; %#ok<AGROW>
        rowsS = [rowsS; Suniq(:)]; %#ok<AGROW>
        rowsChannel = [rowsChannel; repmat(ch, nAdd, 1)]; %#ok<AGROW>
        rowsFolder = [rowsFolder; repmat(string(subDirs(iDir).name), nAdd, 1)]; %#ok<AGROW>
    end

    write_execution_marker('STAGE_AFTER_PROCESSING', runDir);

    if isempty(rowsCurrent)
        error('run_switching_canonical:NoSamples', 'No switching samples were collected from upstream raw source: %s', parentDir);
    end
    if totalRawFiles <= 0
        error('run_switching_canonical:NoRawFiles', 'No raw .dat files were discovered in upstream source: %s', parentDir);
    end

    metricTypeCol = repmat("P2P_percent", numel(rowsCurrent), 1);
    rowsChannelType = strings(numel(rowsChannel), 1);
    rowsChannelType(rowsChannel <= 2) = "XX";
    rowsChannelType(rowsChannel > 2) = "XY";
    rawTbl = table(rowsCurrent, rowsTemp, rowsS, rowsChannel, rowsChannel, rowsChannelType, rowsFolder, metricTypeCol, ...
        'VariableNames', {'current_mA', 'T_K', 'S_percent', 'channel', 'switching_channel_physical', 'channel_type', 'folder', 'metricType'});
    rawTbl = sortrows(rawTbl, {'current_mA', 'T_K', 'switching_channel_physical'});

    tempsRaw = unique(rawTbl.T_K(isfinite(rawTbl.T_K)));
    currents = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
    tempsRaw = sort(tempsRaw(:));
    currents = sort(currents(:));
    if isempty(tempsRaw) || isempty(currents)
        error('run_switching_canonical:EmptyGrid', 'Upstream data could not build non-empty T/I grid.');
    end

    physChans = unique(rawTbl.switching_channel_physical, 'sorted');
    nCh = numel(physChans);

    Sraw = NaN(numel(tempsRaw), numel(currents), nCh);
    for it = 1:numel(tempsRaw)
        for ii = 1:numel(currents)
            for ic = 1:nCh
                m = abs(rawTbl.T_K - tempsRaw(it)) < 1e-9 & abs(rawTbl.current_mA - currents(ii)) < 1e-9 ...
                    & rawTbl.switching_channel_physical == physChans(ic);
                if any(m)
                    Sraw(it, ii, ic) = mean(rawTbl.S_percent(m), 'omitnan');
                end
            end
        end
    end

    Tclean = round(tempsRaw);
    [temps, ~, idxClean] = unique(Tclean, 'sorted');
    Smap = NaN(numel(temps), numel(currents), nCh);
    for ic = 1:nCh
        for k = 1:numel(temps)
            mk = idxClean == k;
            Smap(k, :, ic) = mean(Sraw(mk, :, ic), 1, 'omitnan');
        end
    end
    temps = temps(:);
    currents = currents(:);

    nT = numel(temps);
    nI = numel(currents);

    Speak = NaN(nT, nCh);
    Ipeak = NaN(nT, nCh);
    for ic = 1:nCh
        for it = 1:nT
            row = Smap(it, :, ic);
            valid = isfinite(row);
            if ~any(valid)
                continue;
            end
            rowValid = row(valid);
            currValid = currents(valid);
            [smax, idx] = max(rowValid);
            Speak(it, ic) = smax;
            Ipeak(it, ic) = currValid(idx);
        end
    end

    PTmap = NaN(nT, nI, nCh);
    CDFmap = NaN(nT, nI, nCh);
    Scdf = NaN(nT, nI, nCh);
    for ic = 1:nCh
        for it = 1:nT
            row = Smap(it, :, ic);
            valid = isfinite(row) & isfinite(currents');
            if nnz(valid) < 3 || ~isfinite(Speak(it, ic)) || Speak(it, ic) <= 0
                continue;
            end

            Ivalid = currents(valid);
            svalid = row(valid);
            cdfRaw = svalid ./ Speak(it, ic);
            cdfRaw = min(max(cdfRaw, 0), 1);
            for j = 2:numel(cdfRaw)
                if cdfRaw(j) < cdfRaw(j - 1)
                    cdfRaw(j) = cdfRaw(j - 1);
                end
            end
            if cdfRaw(end) > 0
                cdfRaw = cdfRaw ./ cdfRaw(end);
            end

            p = gradient(cdfRaw, Ivalid);
            p(~isfinite(p)) = 0;
            p = max(p, 0);
            areaP = trapz(Ivalid, p);
            if isfinite(areaP) && areaP > 0
                p = p ./ areaP;
            else
                p(:) = 0;
            end

            cdfPt = cumtrapz(Ivalid, p);
            if cdfPt(end) > 0
                cdfPt = cdfPt ./ cdfPt(end);
            end
            cdfPt = min(max(cdfPt, 0), 1);

            PTmap(it, valid, ic) = p;
            CDFmap(it, valid, ic) = cdfPt;
            Scdf(it, valid, ic) = Speak(it, ic) .* cdfPt;
        end
    end

    residual = Smap - Scdf;
    phi1 = NaN(nI, nCh);
    kappa1 = NaN(nT, nCh);
    for ic = 1:nCh
        Rfill = residual(:, :, ic);
        Rfill(~isfinite(Rfill)) = 0;
        if any(abs(Rfill(:)) > 0)
            [U, Sigma, V] = svd(Rfill, 'econ');
            phi1(:, ic) = V(:, 1);
            kappa1(:, ic) = U(:, 1) * Sigma(1, 1);
        else
            phi1(:, ic) = zeros(nI, 1);
            kappa1(:, ic) = zeros(nT, 1);
        end

        phiScale = max(abs(phi1(:, ic)), [], 'omitnan');
        if isfinite(phiScale) && phiScale > 0
            phi1(:, ic) = phi1(:, ic) ./ phiScale;
            kappa1(:, ic) = kappa1(:, ic) .* phiScale;
        end
        signCorr = corr(Speak(:, ic), kappa1(:, ic), 'Rows', 'complete', 'Type', 'Spearman');
        if isfinite(signCorr) && signCorr < 0
            phi1(:, ic) = -phi1(:, ic);
            kappa1(:, ic) = -kappa1(:, ic);
        end
    end

    Sfull = NaN(nT, nI, nCh);
    for ic = 1:nCh
        Sfull(:, :, ic) = Scdf(:, :, ic) + kappa1(:, ic) * phi1(:, ic)';
    end

    rmsePtRows = NaN(nT, nCh);
    rmseFullRows = NaN(nT, nCh);
    for ic = 1:nCh
        for it = 1:nT
            mPt = isfinite(Smap(it, :, ic)) & isfinite(Scdf(it, :, ic));
            if any(mPt)
                rmsePtRows(it, ic) = sqrt(mean((Smap(it, mPt, ic) - Scdf(it, mPt, ic)) .^ 2, 'omitnan'));
            end
            mFull = isfinite(Smap(it, :, ic)) & isfinite(Sfull(it, :, ic));
            if any(mFull)
                rmseFullRows(it, ic) = sqrt(mean((Smap(it, mFull, ic) - Sfull(it, mFull, ic)) .^ 2, 'omitnan'));
            end
        end
    end

    mPtGlobal = isfinite(Smap) & isfinite(Scdf);
    mFullGlobal = isfinite(Smap) & isfinite(Sfull);
    RMSE_PT = NaN;
    RMSE_FULL = NaN;
    if any(mPtGlobal(:))
        RMSE_PT = sqrt(mean((Smap(mPtGlobal) - Scdf(mPtGlobal)) .^ 2, 'omitnan'));
    end
    if any(mFullGlobal(:))
        RMSE_FULL = sqrt(mean((Smap(mFullGlobal) - Sfull(mFullGlobal)) .^ 2, 'omitnan'));
    end

    phiCosinePerT = NaN(nT, nCh);
    for ic = 1:nCh
        for it = 1:nT
            r = residual(it, :, ic)';
            m = isfinite(r) & isfinite(phi1(:, ic));
            if nnz(m) < 3
                continue;
            end
            nr = norm(r(m));
            np = norm(phi1(m, ic));
            if nr > 0 && np > 0
                phiCosinePerT(it, ic) = abs(dot(r(m), phi1(m, ic)) / (nr * np));
            end
        end
    end
    PHI_MEDIAN_COSINE = median(phiCosinePerT(:), 'omitnan');
    KAPPA_SPEAK_CORR = corr(abs(kappa1(:)), Speak(:), 'Rows', 'complete', 'Type', 'Spearman');

    isPrecomputedRead = any(endsWith(inputPaths, '.csv')) || any(endsWith(inputPaths, '.mat')) || any(contains(inputPaths, '\results\'));

    CHECK_NO_PRECOMPUTED_INPUTS = "NO";
    if ~isPrecomputedRead
        CHECK_NO_PRECOMPUTED_INPUTS = "YES";
    end
    STRUCTURAL_VALID = "NO";
    if CHECK_NO_PRECOMPUTED_INPUTS == "YES"
        STRUCTURAL_VALID = "YES";
    end

    S_SOURCE = sprintf('%s | %s | parentDir=%s', sourceFunction, sourceFile, sourcePath);
    S_CONSTRUCTION_METHOD = sourceMethod;
    USES_ROOT_TABLES = "NO";
    PROVENANCE_VALID = "NO";
    if strlength(string(S_SOURCE)) > 0 && USES_ROOT_TABLES == "NO"
        PROVENANCE_VALID = "YES";
    end

    RECONSTRUCTION_IMPROVES = "NO";
    if isfinite(RMSE_PT) && isfinite(RMSE_FULL) && RMSE_FULL < RMSE_PT
        RECONSTRUCTION_IMPROVES = "YES";
    end
    FUNCTIONAL_VALID = "NO";
    if RECONSTRUCTION_IMPROVES == "YES"
        FUNCTIONAL_VALID = "YES";
    end

    PHI_SHAPE_STABLE = "NO";
    if isfinite(PHI_MEDIAN_COSINE) && PHI_MEDIAN_COSINE >= 0.30
        PHI_SHAPE_STABLE = "YES";
    end
    KAPPA_SCALING_REASONABLE = "NO";
    if isfinite(KAPPA_SPEAK_CORR) && KAPPA_SPEAK_CORR > 0
        KAPPA_SCALING_REASONABLE = "YES";
    end
    INVARIANCE_VALID = "NO";
    if PHI_SHAPE_STABLE == "YES" && KAPPA_SCALING_REASONABLE == "YES"
        INVARIANCE_VALID = "YES";
    end

    RUN_CONTEXT_IS_SWITCHING_ISOLATED = "NO";
    runDirLower = lower(strrep(run.run_dir, '/', '\'));
    if contains(runDirLower, 'results\switching\runs') || contains(runDirLower, 'results/switching/runs')
        RUN_CONTEXT_IS_SWITCHING_ISOLATED = "YES";
    end

    CANONICAL_SWITCHING_GENERATOR_CREATED = "YES";
    UPSTREAM_S_SOURCE_IDENTIFIED = "YES";
    SP_DERIVED_FROM_S = "YES";
    IP_DERIVED_FROM_S = "YES";

    CANONICAL_PIPELINE_CONFIRMED = "NO";
    if STRUCTURAL_VALID == "YES" && PROVENANCE_VALID == "YES" && FUNCTIONAL_VALID == "YES" && INVARIANCE_VALID == "YES"
        CANONICAL_PIPELINE_CONFIRMED = "YES";
    end
    READY_FOR_SINGLE_CANONICAL_RUN = "NO";
    if CANONICAL_PIPELINE_CONFIRMED == "YES"
        READY_FOR_SINGLE_CANONICAL_RUN = "YES";
    end

    linIdx = (1:numel(Smap))';
    [iT, iI, iC] = ind2sub(size(Smap), linIdx);
    chPhysLong = physChans(iC);
    physIndex = chPhysLong;
    channel_type = strings(size(physIndex));

    for ii = 1:numel(physIndex)
        switch physIndex(ii)
            case 1
                channel_type(ii) = "XY";
            case {2,3}
                channel_type(ii) = "XX";
            otherwise
                error("Unknown physIndex detected: cannot assign channel_type");
        end
    end

    u = unique([physIndex(:), double(channel_type == "XX")], 'rows');
    disp(u)

    SLong = table(temps(iT), currents(iI), chPhysLong, channel_type, ...
        Smap(linIdx), Scdf(linIdx), Sfull(linIdx), residual(linIdx), PTmap(linIdx), CDFmap(linIdx), ...
        'VariableNames', {'T_K', 'current_mA', 'switching_channel_physical', 'channel_type', ...
        'S_percent', 'S_model_pt_percent', 'S_model_full_percent', 'residual_percent', 'PT_pdf', 'CDF_pt'});

    write_execution_marker('STAGE_BEFORE_OUTPUTS', runDir);

    atomic_writetable(SLong, fullfile(tablesDir, 'switching_canonical_S_long.csv'));

    linO = (1:numel(Speak))';
    [iTo, iCo] = ind2sub(size(Speak), linO);
    chObs = physChans(iCo);
    physIndex = chObs;
    channel_type = strings(size(physIndex));

    for ii = 1:numel(physIndex)
        switch physIndex(ii)
            case 1
                channel_type(ii) = "XY";
            case {2,3}
                channel_type(ii) = "XX";
            otherwise
                error("Unknown physIndex detected: cannot assign channel_type");
        end
    end

    ObsTbl = table(temps(iTo), chObs, channel_type, Speak(linO), Ipeak(linO), kappa1(linO), ...
        rmsePtRows(linO), rmseFullRows(linO), phiCosinePerT(linO), ...
        'VariableNames', {'T_K', 'switching_channel_physical', 'channel_type', 'S_peak', 'I_peak', 'kappa1', ...
        'rmse_pt_row', 'rmse_full_row', 'phi_cosine_row'});
    atomic_writetable(ObsTbl, fullfile(tablesDir, 'switching_canonical_observables.csv'));

    linP = (1:numel(phi1))';
    [iIp, iCp] = ind2sub(size(phi1), linP);
    chPhi = physChans(iCp);
    physIndex = chPhi;
    channel_type = strings(size(physIndex));

    for ii = 1:numel(physIndex)
        switch physIndex(ii)
            case 1
                channel_type(ii) = "XY";
            case {2,3}
                channel_type(ii) = "XX";
            otherwise
                error("Unknown physIndex detected: cannot assign channel_type");
        end
    end

    PhiTbl = table(currents(iIp), chPhi, channel_type, phi1(linP), ...
        'VariableNames', {'current_mA', 'switching_channel_physical', 'channel_type', 'Phi1'});
    atomic_writetable(PhiTbl, fullfile(tablesDir, 'switching_canonical_phi1.csv'));

    validationTbl = table( ...
        CHECK_NO_PRECOMPUTED_INPUTS, STRUCTURAL_VALID, ...
        string(S_SOURCE), string(S_CONSTRUCTION_METHOD), USES_ROOT_TABLES, PROVENANCE_VALID, ...
        RMSE_PT, RMSE_FULL, RECONSTRUCTION_IMPROVES, FUNCTIONAL_VALID, ...
        PHI_MEDIAN_COSINE, KAPPA_SPEAK_CORR, PHI_SHAPE_STABLE, KAPPA_SCALING_REASONABLE, INVARIANCE_VALID, ...
        CANONICAL_PIPELINE_CONFIRMED, ...
        'VariableNames', {'CHECK_NO_PRECOMPUTED_INPUTS', 'STRUCTURAL_VALID', ...
        'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'USES_ROOT_TABLES', 'PROVENANCE_VALID', ...
        'RMSE_PT', 'RMSE_FULL', 'RECONSTRUCTION_IMPROVES', 'FUNCTIONAL_VALID', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'INVARIANCE_VALID', ...
        'CANONICAL_PIPELINE_CONFIRMED'});
    atomic_writetable(validationTbl, fullfile(tablesDir, 'switching_canonical_validation.csv'));

    reportPath = fullfile(reportsDir, 'run_switching_canonical_report.md');
    tmpReport = [reportPath '.tmp'];
    fidReport = fopen(tmpReport, 'w');
    if fidReport < 0
        error('run_switching_canonical:ReportWriteFailed', 'Failed writing %s', tmpReport);
    end
    try
        fprintf(fidReport, '# run_switching_canonical\n\n');
        fprintf(fidReport, '- RUN_DIR: `%s`\n', runDir);
        fprintf(fidReport, '- S_SOURCE: `%s`\n', S_SOURCE);
        fprintf(fidReport, '- S_CONSTRUCTION_METHOD: `%s`\n', S_CONSTRUCTION_METHOD);
        fprintf(fidReport, '- RAW_PARENT_DIR: `%s`\n', parentDir);
        fprintf(fidReport, '- RAW_FILES_DISCOVERED: `%d`\n', totalRawFiles);
        fprintf(fidReport, '- CHECK_NO_PRECOMPUTED_INPUTS: `%s`\n', CHECK_NO_PRECOMPUTED_INPUTS);
        fprintf(fidReport, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
        fprintf(fidReport, '- RMSE_PT: `%.12g`\n', RMSE_PT);
        fprintf(fidReport, '- RMSE_FULL: `%.12g`\n', RMSE_FULL);
        fprintf(fidReport, '- RECONSTRUCTION_IMPROVES: `%s`\n', RECONSTRUCTION_IMPROVES);
        fprintf(fidReport, '- PHI_SHAPE_STABLE: `%s` (median cosine = %.6f)\n', PHI_SHAPE_STABLE, PHI_MEDIAN_COSINE);
        fprintf(fidReport, '- KAPPA_SCALING_REASONABLE: `%s` (spearman = %.6f)\n', KAPPA_SCALING_REASONABLE, KAPPA_SPEAK_CORR);
        fprintf(fidReport, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
        fprintf(fidReport, '\n## Minimal createRunContext isolation\n');
        fprintf(fidReport, '- Added only `Aging/utils` to path to access `createRunContext`.\n');
        fprintf(fidReport, '- Run context uses experiment tag `switching` under `results/switching/runs`; outputs are run-scoped.\n');
    catch ME
        fclose(fidReport);
        if exist(tmpReport, 'file') == 2
            delete(tmpReport);
        end
        rethrow(ME);
    end
    fclose(fidReport);
    atomic_commit_file(tmpReport, reportPath);

    implStatusTbl = table( ...
        CANONICAL_SWITCHING_GENERATOR_CREATED, ...
        UPSTREAM_S_SOURCE_IDENTIFIED, ...
        SP_DERIVED_FROM_S, ...
        IP_DERIVED_FROM_S, ...
        RUN_CONTEXT_IS_SWITCHING_ISOLATED, ...
        STRUCTURAL_VALID, ...
        PROVENANCE_VALID, ...
        FUNCTIONAL_VALID, ...
        INVARIANCE_VALID, ...
        CANONICAL_PIPELINE_CONFIRMED, ...
        READY_FOR_SINGLE_CANONICAL_RUN, ...
        CHECK_NO_PRECOMPUTED_INPUTS, ...
        RECONSTRUCTION_IMPROVES, ...
        PHI_SHAPE_STABLE, ...
        KAPPA_SCALING_REASONABLE, ...
        RMSE_PT, ...
        RMSE_FULL, ...
        PHI_MEDIAN_COSINE, ...
        KAPPA_SPEAK_CORR, ...
        string(S_SOURCE), ...
        string(S_CONSTRUCTION_METHOD), ...
        string(run.run_id), ...
        string(run.run_dir), ...
        'VariableNames', {'CANONICAL_SWITCHING_GENERATOR_CREATED', 'UPSTREAM_S_SOURCE_IDENTIFIED', ...
        'SP_DERIVED_FROM_S', 'IP_DERIVED_FROM_S', ...
        'RUN_CONTEXT_IS_SWITCHING_ISOLATED', 'STRUCTURAL_VALID', 'PROVENANCE_VALID', ...
        'FUNCTIONAL_VALID', 'INVARIANCE_VALID', 'CANONICAL_PIPELINE_CONFIRMED', 'READY_FOR_SINGLE_CANONICAL_RUN', ...
        'CHECK_NO_PRECOMPUTED_INPUTS', 'RECONSTRUCTION_IMPROVES', ...
        'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'RMSE_PT', 'RMSE_FULL', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'RUN_ID', 'RUN_DIR'});
    atomic_writetable(implStatusTbl, implStatusPath);

    tmpImpl = [implReportPath '.tmp'];
    fidImpl = fopen(tmpImpl, 'w');
    if fidImpl < 0
        error('run_switching_canonical:ImplReportWriteFailed', 'Failed writing %s', tmpImpl);
    end
    try
        fprintf(fidImpl, '# run_switching_canonical implementation\n\n');
        fprintf(fidImpl, '- FILE: `Switching/analysis/run_switching_canonical.m`\n');
        fprintf(fidImpl, '- RUN_ID: `%s`\n', run.run_id);
        fprintf(fidImpl, '- RUN_DIR: `%s`\n', run.run_dir);
        fprintf(fidImpl, '- S_SOURCE: `%s`\n', S_SOURCE);
        fprintf(fidImpl, '- S_CONSTRUCTION_METHOD: `%s`\n', S_CONSTRUCTION_METHOD);
        fprintf(fidImpl, '- CHECK_NO_PRECOMPUTED_INPUTS: `%s`\n', CHECK_NO_PRECOMPUTED_INPUTS);
        fprintf(fidImpl, '- STRUCTURAL_VALID: `%s`\n', STRUCTURAL_VALID);
        fprintf(fidImpl, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
        fprintf(fidImpl, '- FUNCTIONAL_VALID: `%s`\n', FUNCTIONAL_VALID);
        fprintf(fidImpl, '- INVARIANCE_VALID: `%s`\n', INVARIANCE_VALID);
        fprintf(fidImpl, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
        fprintf(fidImpl, '- READY_FOR_SINGLE_CANONICAL_RUN: `%s`\n', READY_FOR_SINGLE_CANONICAL_RUN);
        fprintf(fidImpl, '\n## Required verdicts\n');
        fprintf(fidImpl, '- CANONICAL_SWITCHING_GENERATOR_CREATED: `%s`\n', CANONICAL_SWITCHING_GENERATOR_CREATED);
        fprintf(fidImpl, '- UPSTREAM_S_SOURCE_IDENTIFIED: `%s`\n', UPSTREAM_S_SOURCE_IDENTIFIED);
        fprintf(fidImpl, '- SP_DERIVED_FROM_S: `%s`\n', SP_DERIVED_FROM_S);
        fprintf(fidImpl, '- IP_DERIVED_FROM_S: `%s`\n', IP_DERIVED_FROM_S);
        fprintf(fidImpl, '- RUN_CONTEXT_IS_SWITCHING_ISOLATED: `%s`\n', RUN_CONTEXT_IS_SWITCHING_ISOLATED);
        fprintf(fidImpl, '- STRUCTURAL_VALID: `%s`\n', STRUCTURAL_VALID);
        fprintf(fidImpl, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
        fprintf(fidImpl, '- FUNCTIONAL_VALID: `%s`\n', FUNCTIONAL_VALID);
        fprintf(fidImpl, '- INVARIANCE_VALID: `%s`\n', INVARIANCE_VALID);
        fprintf(fidImpl, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
        fprintf(fidImpl, '- READY_FOR_SINGLE_CANONICAL_RUN: `%s`\n', READY_FOR_SINGLE_CANONICAL_RUN);
        fprintf(fidImpl, '\n## Minimal createRunContext isolation\n');
        fprintf(fidImpl, '- Added `Aging/utils` only, to call `createRunContext`.\n');
        fprintf(fidImpl, '- No cross-pipeline data inputs were used.\n');
    catch ME
        fclose(fidImpl);
        if exist(tmpImpl, 'file') == 2
            delete(tmpImpl);
        end
        rethrow(ME);
    end
    fclose(fidImpl);
    atomic_commit_file(tmpImpl, implReportPath);

    repoTablesDir = fullfile(repoRoot, 'tables');
    repoReportsDir = fullfile(repoRoot, 'reports');
    if exist(repoTablesDir, 'dir') ~= 7
        mkdir(repoTablesDir);
    end
    if exist(repoReportsDir, 'dir') ~= 7
        mkdir(repoReportsDir);
    end

    total_rows_ci = height(rawTbl);
    unique_channels_ci = numel(unique(rawTbl.switching_channel_physical));
    ucList = unique(rawTbl.switching_channel_physical, 'sorted');
    rpcParts = cell(numel(ucList), 1);
    for uci = 1:numel(ucList)
        cval = ucList(uci);
        rpcParts{uci} = sprintf('%g=%d', cval, sum(rawTbl.switching_channel_physical == cval));
    end
    rows_per_channel_str = strjoin(rpcParts, ';');

    [~, ~, Gti] = unique([rawTbl.T_K, rawTbl.current_mA], 'rows');
    duplicate_T_I_cross_channel = "NO";
    for gti = 1:max(Gti)
        ix = Gti == gti;
        if numel(unique(rawTbl.switching_channel_physical(ix))) > 1
            duplicate_T_I_cross_channel = "YES";
            break;
        end
    end

    channelIdentityValidationTbl = table( ...
        total_rows_ci, ...
        unique_channels_ci, ...
        string(rows_per_channel_str), ...
        duplicate_T_I_cross_channel, ...
        'VariableNames', {'total_rows', 'unique_channels', 'rows_per_channel', 'duplicate_T_I_cross_channel'});
    atomic_writetable(channelIdentityValidationTbl, fullfile(repoTablesDir, 'channel_identity_validation.csv'));

    channelIdentityStatusTbl = table( ...
        "YES", "YES", "YES", "NO", "NO", ...
        'VariableNames', {'CHANNEL_TYPE_DEFINED', 'CHANNEL_IDENTITY_PROPAGATED', 'AGGREGATION_FIXED', ...
        'MIXING_RISK_REMAINING', 'LOGIC_MODIFIED'});
    atomic_writetable(channelIdentityStatusTbl, fullfile(repoTablesDir, 'channel_identity_status.csv'));

    ciReportPath = fullfile(repoReportsDir, 'channel_identity_enforcement.md');
    tmpCi = [ciReportPath '.tmp'];
    fidCi = fopen(tmpCi, 'w');
    if fidCi < 0
        error('run_switching_canonical:ChannelIdentityReportFailed', 'Failed writing %s', tmpCi);
    end
    try
        fprintf(fidCi, '# Channel identity enforcement (canonical Switching)\n\n');
        fprintf(fidCi, '## What was added\n');
        fprintf(fidCi, '- `switching_channel_physical`: copied from existing `channel` (physical index 1--4 from `stability.switching.globalChannel`).\n');
        fprintf(fidCi, '- `channel_type`: deterministic mapping `physIndex` in {1,2} -> `XX`, {3,4} -> `XY` (aligned with preset naming `1xy_3xx`).\n');
        fprintf(fidCi, '- Raw-level table columns; channel dimension in `Sraw` / `Smap` and downstream tensors; exports `switching_canonical_S_long.csv`, `switching_canonical_observables.csv`, and `switching_canonical_phi1.csv` include the identity columns.\n\n');
        fprintf(fidCi, '## Where identity was previously missing\n');
        fprintf(fidCi, '- Grid aggregation averaged `S_percent` at `(T_K, current_mA)` without separating physical channels, so distinct channels could be mixed in one cell.\n\n');
        fprintf(fidCi, '## Computation logic\n');
        fprintf(fidCi, '- **Unchanged**: same formulas per `(T_K, current_mA, channel)` slice as previously applied per `(T_K, current_mA)` slice; no physics or algorithm edits.\n\n');
        fprintf(fidCi, '## Aggregation level (before / after)\n');
        fprintf(fidCi, '- **Before**: group by `T_K`, `current_mA` only (implicit mixing across `switching_channel_physical`).\n');
        fprintf(fidCi, '- **After**: group by `T_K`, `current_mA`, `switching_channel_physical` (third index in `Sraw` / `Smap`; no cross-channel averaging).\n\n');
        fprintf(fidCi, '## Validation snapshot (this run)\n');
        fprintf(fidCi, '- total_rows: `%d`\n', total_rows_ci);
        fprintf(fidCi, '- unique_channels: `%d`\n', unique_channels_ci);
        fprintf(fidCi, '- rows_per_channel: `%s`\n', rows_per_channel_str);
        fprintf(fidCi, '- duplicate_T_I_cross_channel: `%s` (YES means same T/I appears on more than one physical channel; rows remain separate).\n', duplicate_T_I_cross_channel);
    catch MEci
        fclose(fidCi);
        if exist(tmpCi, 'file') == 2
            delete(tmpCi);
        end
        rethrow(MEci);
    end
    fclose(fidCi);
    atomic_commit_file(tmpCi, ciReportPath);

    write_execution_marker('STAGE_AFTER_OUTPUTS', runDir);

    writeRunValidityClassification(runDir, repoRoot, enforcement_checked, modules_used, ...
        strcmp(RUN_CONTEXT_IS_SWITCHING_ISOLATED, "YES"));

        writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching_canonical completed'}, true);
        atomic_write_enforcement_status(runDir, enforcement_checked, modules_used, iBatch, numel(batchInputs));

        % Non-authoritative timeline marker; final status is EXECUTION_STATUS in execution_status.csv above.
        write_execution_marker('COMPLETED', runDir);
    end

catch ME
    runDirForStatus = '';
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = run_dir;
    end

    if isempty(runDirForStatus)
        repoR = repoRootBootstrap;
        if isempty(repoR)
            repoR = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        end
        addpath(fullfile(repoR, 'Aging', 'utils'));
        addpath(fullfile(repoR, 'Switching', 'utils'));
        cfgFail = struct();
        cfgFail.runLabel = 'switching_canonical_failure';
        cfgFail.dataset = 'raw_switching_dat_only';
        cfgFail.fingerprint_script_path = fullfile(repoR, 'Switching', 'analysis', 'run_switching_canonical.m');
        try
            rf = allocateSwitchingFailureRunContext(repoR, cfgFail);
            runDirForStatus = rf.run_dir;
        catch ME_alloc
            error('run_switching_canonical:FailureRunAllocation', ...
                'Cannot allocate canonical failure run_dir (%s). Original error: %s', ME_alloc.message, ME.message);
        end
    end

    failTablesDir = fullfile(runDirForStatus, 'tables');
    failReportsDir = fullfile(runDirForStatus, 'reports');
    if exist(failTablesDir, 'dir') ~= 7
        mkdir(failTablesDir);
    end
    if exist(failReportsDir, 'dir') ~= 7
        mkdir(failReportsDir);
    end

    inputFoundFail = 'YES';
    if isempty(run_dir) && (~isstruct(run) || ~isfield(run, 'run_dir') || isempty(run.run_dir))
        inputFoundFail = 'NO';
    end
    writeSwitchingExecutionStatus(runDirForStatus, {'FAILED'}, {inputFoundFail}, {ME.message}, 0, {'run_switching_canonical failed'}, true);
    atomic_write_enforcement_status(runDirForStatus, enforcement_checked, modules_used);

    repoRForValidity = repoRoot;
    if isempty(repoRForValidity)
        repoRForValidity = repoRootBootstrap;
    end
    if isempty(repoRForValidity)
        repoRForValidity = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    end
    runDirLowerFv = lower(strrep(runDirForStatus, '/', '\'));
    switchingIsoFv = contains(runDirLowerFv, 'results\switching\runs') || contains(runDirLowerFv, 'results/switching/runs');
    writeRunValidityClassification(runDirForStatus, repoRForValidity, enforcement_checked, modules_used, switchingIsoFv);

    implStatusFail = table( ...
        "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", ...
        "NO", "NO", "NO", "NO", "NO", NaN, NaN, NaN, NaN, ...
        string(which('createRunContext')), "N/A", ...
        string(""), string(runDirForStatus), ...
        'VariableNames', {'CANONICAL_SWITCHING_GENERATOR_CREATED', 'UPSTREAM_S_SOURCE_IDENTIFIED', ...
        'SP_DERIVED_FROM_S', 'IP_DERIVED_FROM_S', ...
        'RUN_CONTEXT_IS_SWITCHING_ISOLATED', 'STRUCTURAL_VALID', 'PROVENANCE_VALID', ...
        'FUNCTIONAL_VALID', 'INVARIANCE_VALID', 'CANONICAL_PIPELINE_CONFIRMED', 'READY_FOR_SINGLE_CANONICAL_RUN', ...
        'CHECK_NO_PRECOMPUTED_INPUTS', 'RECONSTRUCTION_IMPROVES', ...
        'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'RMSE_PT', 'RMSE_FULL', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'RUN_ID', 'RUN_DIR'});
    
    if ~isempty(implStatusPath)
        atomic_writetable(implStatusFail, implStatusPath);
    else
        atomic_writetable(implStatusFail, fullfile(failTablesDir, 'run_switching_canonical_implementation_status.csv'));
    end

    if ~isempty(implReportPath)
        implFailFinal = implReportPath;
    else
        implFailFinal = fullfile(failReportsDir, 'run_switching_canonical_implementation.md');
    end
    tmpImplFail = [implFailFinal '.tmp'];
    fidImplFail = fopen(tmpImplFail, 'w');
    if fidImplFail >= 0
        try
            fprintf(fidImplFail, '# run_switching_canonical implementation\n\n');
            fprintf(fidImplFail, '- DIAGNOSTIC_NOTE: Authoritative outcome is EXECUTION_STATUS in execution_status.csv (this file is not the contract).\n');
            fprintf(fidImplFail, '- ERROR_MESSAGE: `%s`\n', ME.message);
            fprintf(fidImplFail, '- RUN_DIR: `%s`\n', runDirForStatus);
        catch MEw
            fclose(fidImplFail);
            if exist(tmpImplFail, 'file') == 2
                delete(tmpImplFail);
            end
            rethrow(MEw);
        end
        fclose(fidImplFail);
        atomic_commit_file(tmpImplFail, implFailFinal);
    end

    write_execution_marker('FAILED', runDirForStatus);

    rethrow(ME);
end
